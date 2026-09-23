import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' show basenameWithoutExtension;
import 'package:web/web.dart' as web;

import '../datasources/suttacentral_concordance_datasource.dart';
import '../datasources/tree_local_datasource.dart';
import 'database_install_status.dart';
import 'database_manifest.dart';
import 'local_database.dart';

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
/// All or nothing: [status] turns ready only once every database is installed
/// and open and the app's other files are in hand, so nothing the app shows
/// depends on a download that might still fail.
///
/// Reached through [DatabaseInstallation] rather than directly, so the
/// first-visit screen stays platform-neutral.
class WebDatabaseInstaller {
  WebDatabaseInstaller._();

  static final WebDatabaseInstaller instance = WebDatabaseInstaller._();

  /// Downloaded one at a time, in this order.
  static const List<String> databases = ['bjt.db', 'dict.db'];

  /// The app's other reads over the network, fetched before the screen lifts.
  /// `rootBundle` keeps each in its string cache, where the app reads it from.
  static const List<String> _appFiles = [
    TreeLocalDataSourceImpl.treeJsonPath,
    SuttaCentralConcordanceDataSourceImpl.assetPath,
  ];

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

  DatabaseInstallStatus _status =
      const DatabaseInstallStatus(phase: DatabaseInstallPhase.checking);

  /// Both kept after a failure, so a query that follows one fails at once
  /// instead of starting the downloads again. Only [retry] clears them.
  Future<void>? _started;
  Future<WasmProbeResult>? _installed;

  final Map<String, DatabaseManifestEntry> _manifest = {};

  /// The versions this tab holds an in-use marker for. A shared lock taken
  /// twice is held twice, and [retry] runs preparation again.
  final Set<String> _markersHeld = {};

  /// What the first-visit screen shows right now.
  DatabaseInstallStatus get status => _status;

  /// Every change to [status]. Broadcast, and it does not replay.
  Stream<DatabaseInstallStatus> get changes => _changes.stream;

  /// Installs every database, then opens them and fetches the app's other
  /// files.
  ///
  /// Idempotent, and it never throws: a failure lands in [status] for the
  /// screen to show.
  Future<void> start() => _started ??= _run();

  /// Starts again from the top after a failure.
  ///
  /// An unsupported browser is not retried — nothing about it would change.
  Future<void> retry() {
    if (_status.phase != DatabaseInstallPhase.failed ||
        _status.failure?.kind ==
            DatabaseInstallFailureKind.unsupportedBrowser) {
      return Future<void>.value();
    }
    _installed = null;
    _emit(const DatabaseInstallStatus(phase: DatabaseInstallPhase.checking));
    // Never the reload shortcut: the databases may be in and the step that
    // failed the one after them.
    return _started = _run(reloadShortcut: false);
  }

  /// Opens [dbName] from OPFS, waiting for the install first.
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
    final probe = await _install();
    return probe.open(
      WasmStorageImplementation.opfsLocks,
      _opfsName(dbName, _manifest[dbName]!.sha256),
      // The shipped files keep `user_version` 0; drift would otherwise write it.
      enableMigrations: false,
    );
  }

  Future<void> _run({bool reloadShortcut = true}) async {
    try {
      await _readManifest();
      // A reload: every database is already here, so the app shows now rather
      // than after the probe, which costs two workers and a wasm module. The
      // probe still runs — open() waits for it — and the app's other files
      // load when it asks for them, as on any reload.
      final reload = reloadShortcut && (await _missing()).isEmpty;
      if (reload) {
        _emit(const DatabaseInstallStatus(phase: DatabaseInstallPhase.ready));
      }
      await _install();
      if (!reload) await _openAndFetch();
      // Again after a reload too: a tab on another build can delete a version
      // before this one marks it in use, and the download that follows moves
      // the screen off ready.
      _emit(const DatabaseInstallStatus(phase: DatabaseInstallPhase.ready));
    } catch (error, stack) {
      final failure = _asFailure(error, 'Installing the databases failed');
      debugPrint('[db] $failure\n$stack');
      _emit(DatabaseInstallStatus(
        phase: DatabaseInstallPhase.failed,
        failure: failure,
      ));
    }
  }

  Future<void> _readManifest() async {
    for (final dbName in databases) {
      _manifest[dbName] ??= await databaseManifestEntry(dbName);
    }
  }

  /// Opens every database and fetches [_appFiles].
  ///
  /// Opening goes through [LocalDatabase.open], so the connections made here
  /// are the ones the app goes on to use, `sqlite3.wasm` is already loaded
  /// into them, and a file that will not open fails here rather than in the
  /// first book.
  Future<void> _openAndFetch() async {
    for (final dbName in databases) {
      try {
        await LocalDatabase.open(dbName);
      } catch (error) {
        throw DatabaseInstallFailure(
          DatabaseInstallFailureKind.other,
          'Opening $dbName failed: $error',
        );
      }
    }
    for (final path in _appFiles) {
      try {
        await rootBundle.loadString(path);
      } catch (error) {
        // The cache keeps a failed load too, which would fail every retry.
        rootBundle.evict(path);
        throw DatabaseInstallFailure(
          DatabaseInstallFailureKind.download,
          'GET $path failed: $error',
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Preparing: probe, feature check, tab markers, cleanup
  // ---------------------------------------------------------------------------

  Future<WasmProbeResult> _prepare() async {
    // Relative, because Flutter copies `web/` to the build root.
    final probe = await WasmDatabase.probe(
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.js'),
    );

    // By feature, not by browser name, and before anything is downloaded.
    // Naming the storage mode also stops drift falling back to IndexedDB with
    // the whole library in it.
    final missing = <String>[
      if (!probe.availableStorages
          .contains(WasmStorageImplementation.opfsLocks))
        'OPFS with synchronous locks',
      if (!_supportsCreateWritable()) 'writable file streams',
    ];
    if (missing.isNotEmpty) throw await _storageUnavailable(probe, missing);

    // A hint about eviction that nothing here depends on, so its own catch: a
    // browser that refuses it must not fail the install. Chrome decides from
    // how much the site is used, at the time of asking, so a first-visit
    // `false` can become `true` on a later start.
    try {
      final persisted = await web.window.navigator.storage.persist().toDart;
      debugPrint('[db] storage persisted: ${persisted.toDart}');
    } catch (error) {
      debugPrint('[db] could not ask for persistent storage: $error');
    }

    await _holdInUseMarkers();
    await _deleteOtherVersions(probe);
    return probe;
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
    final needed = _manifest.values.fold(0, (sum, entry) => sum + entry.bytes);
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

  /// The databases not yet installed at the version this build wants.
  Future<List<String>> _missing() async => [
        for (final dbName in databases)
          if (!await _isInstalled(dbName)) dbName,
      ];

  /// Whether [dbName] is already installed at the version this build wants.
  ///
  /// The stamp is written last, so it standing for the manifest's hash means
  /// the download finished. False on anything unexpected: the install behind
  /// this reports what went wrong.
  Future<bool> _isInstalled(String dbName) async {
    try {
      final sha256 = _manifest[dbName]!.sha256;
      final drift = await _driftRoot();
      // Not `create: true`: a missing folder is the answer here, not something
      // to make.
      final folder =
          await drift.getDirectoryHandle(_opfsName(dbName, sha256)).toDart;
      return await _readStamp(folder) == sha256;
    } catch (_) {
      return false;
    }
  }

  Future<WasmProbeResult> _install() => _installed ??= _runInstall();

  Future<WasmProbeResult> _runInstall() async {
    // Read here as well as in _run(), because open() can arrive first.
    await _readManifest();
    final probe = await _prepare();

    final missing = await _missing();
    // Only what this start downloads, so a new dictionary on its own counts up
    // to its own size.
    final total =
        missing.fold(0, (sum, dbName) => sum + _manifest[dbName]!.bytes);
    var done = 0;
    for (final dbName in missing) {
      final entry = _manifest[dbName]!;
      final name = _opfsName(dbName, entry.sha256);
      await _withLock(
        _downloadLock(name),
        // A second tab waits here rather than downloading the same file.
        body: () async {
          final folder = await _folder(name);
          if (await _readStamp(folder) == entry.sha256) {
            debugPrint('[db] $dbName already installed as $name');
            return;
          }
          await _download(dbName, entry, folder, done: done, total: total);
          await _writeStamp(folder, entry.sha256);
        },
      );
      done += entry.bytes;
    }
    return probe;
  }

  /// Streams the file into `<folder>/database`, counting what arrives on top
  /// of the [done] bytes of the databases before it.
  ///
  /// The chunks go to the sink as they come off the network, so the peak stays
  /// at one chunk rather than the whole database. `createWritable` commits on
  /// close, so a cut download leaves no half file behind.
  Future<void> _download(
    String dbName,
    DatabaseManifestEntry entry,
    web.FileSystemDirectoryHandle folder, {
    required int done,
    required int total,
  }) async {
    final url = _downloadUrl(dbName, entry.sha256);
    debugPrint('[db] downloading $dbName from $url');
    _emitProgress(done, total);

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
          _emitProgress(done + received, total);
        }
      }
      await sink.close().toDart;
      // The last part-megabyte, so the bar does not jump at the next file.
      _emitProgress(done + received, total);
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

  void _emitProgress(int received, int total) => _emit(DatabaseInstallStatus(
        phase: DatabaseInstallPhase.installing,
        received: received,
        total: total,
      ));

  void _emit(DatabaseInstallStatus status) {
    _status = status;
    _changes.add(status);
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
