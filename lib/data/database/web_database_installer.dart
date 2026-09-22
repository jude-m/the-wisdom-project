import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' show basenameWithoutExtension;
import 'package:web/web.dart' as web;

import 'database_install_status.dart';
import 'database_manifest.dart';

/// Downloads this build's databases into OPFS and opens them there.
///
/// Native copies its databases out of the app bundle on first launch
/// (`local_database_executor_native.dart`); the browser has no bundle big
/// enough, so it downloads instead. Everything else matches: the version comes
/// from the build's `manifest.json`, and a stamp written last says the copy
/// finished.
///
/// The one difference is that each version gets its own folder,
/// `drift_db/<db>-<first 16 hex of its SHA-256>/`, rather than overwriting the
/// old file — an old tab may still be reading it.
///
/// Reached through [DatabaseInstallation] rather than directly, so the
/// first-visit screen stays platform-neutral.
class WebDatabaseInstaller {
  WebDatabaseInstaller._();

  static final WebDatabaseInstaller instance = WebDatabaseInstaller._();

  /// Installed in this order, and `bjt.db` blocks the app: every book in the
  /// tree opens its text from it. The dictionary waits for `dict.db` on its own.
  static const List<String> databases = ['bjt.db', 'dict.db'];

  /// Where the bytes come from. Empty (the default, and every local run) means
  /// the app's own asset copy; a build sets it to the R2 bucket's public URL.
  static const String _baseUrl = String.fromEnvironment('DATABASE_BASE_URL');

  /// Drift's own folder under OPFS, mirrored from `driftOpfsRoot` in
  /// `drift/src/web/wasm_setup/shared.dart`, which the package does not export.
  /// Check it against drift on a version bump.
  static const String _driftFolder = 'drift_db';

  /// Drift opens `<folder>/database`, so the stamp is the only other file we
  /// put in there. Written last: no stamp, not finished.
  static const String _stampFile = 'install.sha256';

  /// Chrome asks the OS for space in bursts, so a chunk-by-chunk progress
  /// stream would fire thousands of times. One update per megabyte is plenty.
  static const int _progressStepBytes = 1024 * 1024;

  final StreamController<DatabaseInstallStatus> _changes =
      StreamController<DatabaseInstallStatus>.broadcast();

  /// One status per database, so a failed dictionary does not read as a failed
  /// app. [status] hands out the blocking one.
  final Map<String, DatabaseInstallStatus> _statuses = {
    for (final dbName in databases)
      dbName: DatabaseInstallStatus(
        phase: DatabaseInstallPhase.checking,
        database: dbName,
        blocking: dbName == databases.first,
      ),
  };

  Future<WasmProbeResult>? _prepared;
  final Map<String, Future<void>> _installs = {};
  final Map<String, DatabaseManifestEntry> _manifest = {};

  /// The versions this tab holds an in-use marker for. A shared lock taken
  /// twice is held twice, and [retry] can run preparation again.
  final Set<String> _markersHeld = {};

  /// What failed, `null` standing for the preparation step, which stops every
  /// database at once. Emptied by [retry].
  final Set<String?> _failed = {};

  /// Only one database downloads at a time, so a first visit does not run two
  /// hundred-megabyte transfers against each other.
  Future<void> _queue = Future<void>.value();

  /// What a first-visit screen shows right now: the state of the database the
  /// app cannot start without.
  DatabaseInstallStatus get status => _statuses[databases.first]!;

  /// Every change, each naming its own database — read `blocking` to know
  /// whether it concerns the whole app. Broadcast, and it does not replay.
  Stream<DatabaseInstallStatus> get changes => _changes.stream;

  /// Installs every database, `bjt.db` first and the rest behind it.
  ///
  /// Idempotent, and it never throws: failures land in [status] for the screen
  /// to show, and in [open] for the caller that needed the database.
  Future<void> start() async {
    try {
      await _prepare();
      await _install(databases.first);
    } catch (_) {
      // Already recorded in _statuses.
      return;
    }
    for (final dbName in databases.skip(1)) {
      unawaited(_install(dbName).catchError((Object _) {}));
    }
  }

  /// Tries everything that failed again, preparation included.
  ///
  /// An unsupported browser is not retried — nothing about it would change.
  Future<void> retry() async {
    if (status.failure?.kind == DatabaseInstallFailureKind.unsupportedBrowser) {
      return;
    }
    final retrying = _failed.toList();
    _failed.clear();
    for (final dbName in retrying) {
      // A failed install has already forgotten itself (see [_runInstall]);
      // preparation is the only thing still cached across a failure.
      if (dbName == null) _prepared = null;
      // Only the failed ones go back to checking: a database that installed
      // before the failure is still installed.
      _emit(_statusFor(dbName, DatabaseInstallPhase.checking));
    }
    await start();
  }

  /// Opens [dbName] from OPFS, waiting for its install to finish first.
  ///
  /// It starts no download of its own, but an install that failed has forgotten
  /// itself ([_runInstall]) — so the wait here can become a fresh download of
  /// the whole file. That is `dict.db`'s only way back, and it means a caller
  /// waits as long as a download takes rather than failing straight away.
  Future<QueryExecutor> open(String dbName) async {
    if (!databases.contains(dbName)) {
      // A new edition means a new `<editionId>.db`
      // (`docs/todo/multi_edition_architecture.md`). On web it also has to be
      // installed, which is this list plus a file to download it from.
      throw DatabaseInstallFailure(
        DatabaseInstallFailureKind.other,
        '$dbName is not one of the databases this build installs '
        '(${databases.join(', ')}). Web needs it added to '
        'WebDatabaseInstaller.databases and published beside the others.',
      );
    }
    final probe = await _prepare();
    await _install(dbName);
    return probe.open(
      WasmStorageImplementation.opfsLocks,
      _opfsName(dbName, _manifest[dbName]!.sha256),
      // The shipped files keep `user_version` 0; drift would otherwise write it.
      enableMigrations: false,
    );
  }

  // ---------------------------------------------------------------------------
  // Preparing: probe, feature check, tab markers, cleanup
  // ---------------------------------------------------------------------------

  Future<WasmProbeResult> _prepare() => _prepared ??= _runPrepare();

  Future<WasmProbeResult> _runPrepare() async {
    try {
      for (final dbName in databases) {
        _manifest[dbName] = await databaseManifestEntry(dbName);
      }

      // Relative, because Flutter copies `web/` to the build root.
      final probe = await WasmDatabase.probe(
        sqlite3Uri: Uri.parse('sqlite3.wasm'),
        driftWorkerUri: Uri.parse('drift_worker.js'),
      );

      // By feature, not by browser name, and before anything is downloaded.
      // Naming the storage mode also stops drift falling back to IndexedDB
      // with the whole library in it.
      final missing = <String>[
        if (!probe.availableStorages
            .contains(WasmStorageImplementation.opfsLocks))
          'OPFS with synchronous locks',
        if (!_supportsCreateWritable()) 'writable file streams',
      ];
      if (missing.isNotEmpty) throw await _storageUnavailable(probe, missing);

      // A hint about eviction that nothing here depends on, so its own catch:
      // a browser that refuses it must not fail the install. Chrome decides
      // from how much the site is used, at the time of asking, so a
      // first-visit `false` can become `true` on a later start.
      try {
        final persisted = await web.window.navigator.storage.persist().toDart;
        debugPrint('[db] storage persisted: ${persisted.toDart}');
      } catch (error) {
        debugPrint('[db] could not ask for persistent storage: $error');
      }

      await _holdInUseMarkers();
      await _deleteOtherVersions(probe);
      return probe;
    } catch (error, stack) {
      _fail(null, error, stack);
      rethrow;
    }
  }

  /// Why the storage the databases need is unavailable.
  ///
  /// Drift decides OPFS is available by creating a file in it and swallows
  /// whatever goes wrong, so a worker that never started and a device with no
  /// room both arrive looking like a browser without OPFS. Only one of the
  /// three is worth telling someone to change browsers over; the other two are
  /// worth a retry button.
  Future<DatabaseInstallFailure> _storageUnavailable(
    WasmProbeResult probe,
    List<String> missing,
  ) async {
    if (probe.missingFeatures.contains(MissingBrowserFeature.workerError)) {
      // Our own file rather than the browser's doing: `drift_worker.js` ships
      // in `web/`, so a cut connection or a deploy that dropped it lands here.
      // The download kind carries the detail line that names it.
      return const DatabaseInstallFailure(
        DatabaseInstallFailureKind.download,
        'The database worker did not start, so drift_worker.js may not have '
        'loaded.',
      );
    }
    if (await _outOfSpace()) {
      return const DatabaseInstallFailure(
        DatabaseInstallFailureKind.outOfSpace,
        'There is not enough space on this device for the texts.',
      );
    }
    return DatabaseInstallFailure(
      DatabaseInstallFailureKind.unsupportedBrowser,
      'This browser is missing ${missing.join(' and ')}. '
      'Chrome and Edge are supported today.',
    );
  }

  /// Whether the browser has less room left than the databases need.
  ///
  /// Advisory, and deliberately used for nothing else: browsers pad the
  /// estimate and the quota moves with the free disk. It only tells a full
  /// device apart from a browser that never had OPFS.
  Future<bool> _outOfSpace() async {
    final needed = _allBytes;
    try {
      final estimate = await web.window.navigator.storage.estimate().toDart;
      // Both are optional in the spec, and a browser that omits either has
      // told us nothing.
      if (!estimate.has('quota') || !estimate.has('usage')) return false;
      final free = estimate.quota - estimate.usage;
      debugPrint('[db] $free bytes free, $needed needed');
      return free < needed;
    } catch (error) {
      debugPrint('[db] could not estimate free space: $error');
      return false;
    }
  }

  /// Marks every version this tab uses as in use, for as long as the tab lives.
  ///
  /// A shared lock the browser drops when the tab closes or crashes. Without it
  /// one tab would delete a file an idle old tab still reads: Chrome's storage
  /// mode closes a database 150 ms after its last query, so "nothing has it
  /// open" is not the same as "nobody is using it".
  Future<void> _holdInUseMarkers() async {
    for (final dbName in databases) {
      final name = _opfsName(dbName, _manifest[dbName]!.sha256);
      // A marker is held for the tab's life, so a retry must not take a second
      // one. `add` is false when this tab already holds it.
      if (!_markersHeld.add(name)) continue;
      final granted = Completer<void>();
      // Held until the tab goes: the callback's promise never settles.
      final forever = Completer<void>();
      unawaited(
        web.window.navigator.locks
            .request(
              _inUseLock(name),
              web.LockOptions(mode: 'shared'),
              ((web.Lock? lock) {
                if (!granted.isCompleted) granted.complete();
                return forever.future.toJS;
              }).toJS,
            )
            .toDart
            .then((_) {}, onError: (Object _) {
          if (!granted.isCompleted) granted.complete();
        }),
      );
      await granted.future;
    }
  }

  /// Deletes the versions of our databases that no tab is using.
  ///
  /// Before the new download, not after, so the old version's space is freed
  /// first — the same order native uses. A version another tab still holds is
  /// left for a later start.
  Future<void> _deleteOtherVersions(WasmProbeResult probe) async {
    final current = {
      for (final dbName in databases)
        _opfsName(dbName, _manifest[dbName]!.sha256),
    };
    // Only other versions of our own databases: the set of files is fixed, so
    // anything else under `drift_db/` belongs to something we don't know about.
    final ours = RegExp(
      '^(${databases.map((d) => basenameWithoutExtension(d)).join('|')})'
      r'-[0-9a-f]{16}$',
    );

    for (final existing in probe.existingDatabases) {
      final (storage, name) = existing;
      if (storage != WebStorageApi.opfs) continue;
      if (current.contains(name) || !ours.hasMatch(name)) continue;
      try {
        final asked = await _withLock(
          _inUseLock(name),
          ifAvailable: true,
          body: () => probe.deleteDatabase(existing),
        );
        if (!asked) {
          debugPrint('[db] kept $name — another tab is still using it');
        } else if (await _folderExists(name)) {
          // Drift's worker swallows a failed delete, and Chrome can hold a
          // file for 150 ms after its last query. A later start tries again.
          debugPrint('[db] asked to delete $name, and it is still there');
        } else {
          debugPrint('[db] deleted old version $name');
        }
      } catch (error) {
        // A later start tries again; a failed delete must not stop the install.
        debugPrint('[db] could not delete $name: $error');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Installing
  // ---------------------------------------------------------------------------

  Future<void> _install(String dbName) {
    return _installs[dbName] ??= () {
      final next = _queue.then((_) => _runInstall(dbName));
      // The queue only orders the downloads; one failure must not block the
      // database behind it.
      _queue = next.catchError((Object _) {});
      return next;
    }();
  }

  Future<void> _runInstall(String dbName) async {
    final entry = _manifest[dbName]!;
    final name = _opfsName(dbName, entry.sha256);
    try {
      await _withLock(
        _downloadLock(name),
        // A second tab waits here rather than downloading the same file.
        body: () async {
          final folder = await _folder(name);
          if (await _readStamp(folder) == entry.sha256) {
            debugPrint('[db] $dbName already installed as $name');
            return;
          }
          await _download(dbName, entry, folder);
          await _writeStamp(folder, entry.sha256);
        },
      );
      _failed.remove(dbName);
      _emit(_statusFor(dbName, DatabaseInstallPhase.ready));
    } catch (error, stack) {
      // Forgotten, so the next caller tries again instead of being handed this
      // same failure for the rest of the session. `dict.db` has no other way
      // back: [retry] belongs to the screen, which only covers `bjt.db`.
      _installs.remove(dbName);
      _fail(dbName, error, stack);
      rethrow;
    }
  }

  /// Streams the file into `<folder>/database`, counting what arrives.
  ///
  /// The chunks go to the sink as they come off the network, so the peak stays
  /// at one chunk rather than the whole database. `createWritable` commits on
  /// close, so a cut download leaves no half file behind.
  Future<void> _download(
    String dbName,
    DatabaseManifestEntry entry,
    web.FileSystemDirectoryHandle folder,
  ) async {
    final url = _downloadUrl(dbName, entry.sha256);
    debugPrint('[db] downloading $dbName from $url');
    _emit(_statusFor(
      dbName,
      DatabaseInstallPhase.installing,
      total: entry.bytes,
    ));

    // `no-store`, so Chrome keeps no second copy of the file in its HTTP cache.
    final response = await web.window
        .fetch(url.toJS, web.RequestInit(cache: 'no-store'))
        .toDart;
    if (!response.ok) {
      throw DatabaseInstallFailure(
        DatabaseInstallFailureKind.download,
        'GET $url returned ${response.status} ${response.statusText}',
      );
    }
    final body = response.body;
    if (body == null) {
      throw DatabaseInstallFailure(
        DatabaseInstallFailureKind.download,
        'GET $url had no body',
      );
    }

    final file = await folder
        .getFileHandle('database', web.FileSystemGetFileOptions(create: true))
        .toDart;
    // Truncating, not appending: a retried download must replace what the last
    // attempt left, not add to it.
    final sink = await file
        .createWritable(
          web.FileSystemCreateWritableOptions(keepExistingData: false),
        )
        .toDart;
    final reader = web.ReadableStreamDefaultReader(body);
    var received = 0;
    var reported = 0;

    try {
      while (true) {
        final chunk = await reader.read().toDart;
        if (chunk.done) break;
        final data = chunk.value! as JSUint8Array;
        // Written unconverted — turning it into a Dart list first would copy
        // every byte through the Dart heap. Its size is read off the JS object
        // for the same reason.
        await sink.write(data).toDart;
        received += data.getProperty<JSNumber>('byteLength'.toJS).toDartInt;
        if (received - reported >= _progressStepBytes) {
          reported = received;
          _emit(_statusFor(
            dbName,
            DatabaseInstallPhase.installing,
            received: received,
            total: entry.bytes,
          ));
        }
      }
      await sink.close().toDart;
      // The last part-megabyte, so the bar reaches the end instead of jumping.
      _emit(_statusFor(
        dbName,
        DatabaseInstallPhase.installing,
        received: received,
        total: entry.bytes,
      ));
    } catch (error) {
      // Cancelled as well as aborted: the sink alone leaves the network
      // connection open until the reader is collected.
      await reader.cancel().toDart.catchError((Object _) => null);
      await sink.abort().toDart.catchError((Object _) => null);
      throw _asFailure(error, 'Downloading $dbName failed');
    }

    if (received != entry.bytes) {
      // The folder goes, so "try again" starts from nothing rather than
      // opening a database that is the wrong length.
      await _remove(_opfsName(dbName, entry.sha256));
      throw DatabaseInstallFailure(
        DatabaseInstallFailureKind.download,
        '$dbName arrived as $received bytes, not the ${entry.bytes} this '
        'build expects.',
      );
    }
    debugPrint('[db] installed $dbName — $received bytes');
  }

  String _downloadUrl(String dbName, String sha256) {
    if (_baseUrl.isEmpty) {
      // The app's own asset copy, uncompressed — what every local run uses.
      // Which also means `flutter build web` bundles both databases, ~350 MB,
      // unless the deploy strips them and sets DATABASE_BASE_URL. Nothing does
      // that yet: the script that used to strip them is in `deprecated/`, and
      // the requirement is recorded in `docs/todo/web-strategy/web-release.md`
      // §6.
      return 'assets/$databaseAssetFolder/$dbName';
    }
    final base = _baseUrl.endsWith('/')
        ? _baseUrl.substring(0, _baseUrl.length - 1)
        : _baseUrl;
    // Stored gzipped with `Content-Encoding: gzip`, so the browser un-gzips as
    // it downloads and the bytes reaching the sink are the database's own.
    return '$base/${_opfsName(dbName, sha256)}.db.gz';
  }

  // ---------------------------------------------------------------------------
  // OPFS and locks
  // ---------------------------------------------------------------------------

  static String _opfsName(String dbName, String sha256) =>
      '${basenameWithoutExtension(dbName)}-${sha256.substring(0, 16)}';

  /// Held shared for a tab's life; taken exclusively to check a version is free.
  /// Not prefixed `drift-db-`, which drift uses for its own per-query lock.
  static String _inUseLock(String name) => 'wisdom-db-in-use:$name';

  static String _downloadLock(String name) => 'wisdom-db-download:$name';

  Future<web.FileSystemDirectoryHandle> _driftRoot() async {
    final root = await web.window.navigator.storage.getDirectory().toDart;
    return root
        .getDirectoryHandle(
          _driftFolder,
          web.FileSystemGetDirectoryOptions(create: true),
        )
        .toDart;
  }

  Future<web.FileSystemDirectoryHandle> _folder(String name) async {
    final drift = await _driftRoot();
    return drift
        .getDirectoryHandle(
            name, web.FileSystemGetDirectoryOptions(create: true))
        .toDart;
  }

  Future<bool> _folderExists(String name) async {
    final drift = await _driftRoot();
    try {
      await drift.getDirectoryHandle(name).toDart;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _remove(String name) async {
    final drift = await _driftRoot();
    await drift
        .removeEntry(name, web.FileSystemRemoveOptions(recursive: true))
        .toDart;
  }

  Future<String?> _readStamp(web.FileSystemDirectoryHandle folder) async {
    try {
      final handle = await folder.getFileHandle(_stampFile).toDart;
      final text = await (await handle.getFile().toDart).text().toDart;
      return text.toDart.trim();
    } catch (_) {
      // No stamp: either nothing was installed, or a download was cut short.
      return null;
    }
  }

  Future<void> _writeStamp(
    web.FileSystemDirectoryHandle folder,
    String sha256,
  ) async {
    final handle = await folder
        .getFileHandle(_stampFile, web.FileSystemGetFileOptions(create: true))
        .toDart;
    // Truncating: an older, longer hash must not be left in the tail.
    final sink = await handle
        .createWritable(
          web.FileSystemCreateWritableOptions(keepExistingData: false),
        )
        .toDart;
    await sink.write(sha256.toJS).toDart;
    await sink.close().toDart;
  }

  /// Runs [body] holding [name] exclusively. With [ifAvailable], skips [body]
  /// and returns false when another tab holds it right now.
  Future<bool> _withLock(
    String name, {
    bool ifAvailable = false,
    required Future<void> Function() body,
  }) async {
    var ran = false;
    Object? error;
    StackTrace? stack;

    await web.window.navigator.locks
        .request(
          name,
          web.LockOptions(mode: 'exclusive', ifAvailable: ifAvailable),
          ((web.Lock? lock) {
            if (lock == null) return Future<void>.value().toJS;
            ran = true;
            return () async {
              try {
                await body();
              } catch (thrown, thrownStack) {
                // Carried out rather than thrown: a Dart error crossing the JS
                // promise boundary comes back as an opaque JS value.
                error = thrown;
                stack = thrownStack;
              }
            }()
                .toJS;
          }).toJS,
        )
        .toDart;

    if (error != null) Error.throwWithStackTrace(error!, stack!);
    return ran;
  }

  static bool _supportsCreateWritable() {
    if (!globalContext.has('FileSystemFileHandle')) return false;
    final prototype =
        (globalContext['FileSystemFileHandle']! as JSObject)['prototype'];
    return prototype.isA<JSObject>() &&
        (prototype as JSObject).has('createWritable');
  }

  // ---------------------------------------------------------------------------
  // Status
  // ---------------------------------------------------------------------------

  /// What a first visit costs in all, or 0 before the manifest is read — the
  /// screen says it up front, while the bar tracks one database at a time.
  int get _allBytes => _manifest.length < databases.length
      ? 0
      : _manifest.values.fold(0, (sum, entry) => sum + entry.bytes);

  /// A status for [dbName], or for every database when it is null.
  DatabaseInstallStatus _statusFor(
    String? dbName,
    DatabaseInstallPhase phase, {
    int received = 0,
    int total = 0,
    DatabaseInstallFailure? failure,
  }) {
    return DatabaseInstallStatus(
      phase: phase,
      database: dbName,
      blocking: dbName == null || dbName == databases.first,
      received: received,
      total: total,
      allTotal: _allBytes,
      failure: failure,
    );
  }

  void _emit(DatabaseInstallStatus status) {
    final dbName = status.database;
    if (dbName == null) {
      // The browser check and the cleanup stop, or clear, all of them at once.
      for (final name in databases) {
        _statuses[name] = status;
      }
    } else {
      _statuses[dbName] = status;
    }
    _changes.add(status);
  }

  void _fail(String? dbName, Object error, StackTrace stack) {
    _failed.add(dbName);
    final failure = _asFailure(
      error,
      dbName == null
          ? 'Preparing the databases failed'
          : 'Installing $dbName failed',
    );
    debugPrint('[db] $failure\n$stack');
    _emit(_statusFor(dbName, DatabaseInstallPhase.failed, failure: failure));
  }

  static DatabaseInstallFailure _asFailure(Object error, String fallback) {
    if (error is DatabaseInstallFailure) return error;
    // A full disk, or a private window refusing 351 MB, arrives as this.
    if (error.isA<web.DOMException>() &&
        (error as web.DOMException).name == 'QuotaExceededError') {
      return const DatabaseInstallFailure(
        DatabaseInstallFailureKind.outOfSpace,
        'There is not enough space on this device for the texts.',
      );
    }
    return DatabaseInstallFailure(
      DatabaseInstallFailureKind.other,
      '$fallback: $error',
    );
  }
}
