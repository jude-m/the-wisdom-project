// Throwaway proof for step 3 of
// `docs/todo/retiring-dart-server/move-web-onto-drift.md`: Drift opens the
// real `bjt.db` from OPFS in a browser. No locks, no stamp, no progress bar —
// step 4 owns those. Nothing imports this file; it goes at the end of step 4.
//
//   flutter run -d web-server --release --no-web-resources-cdn \
//     -t lib/dev/web_drift_probe.dart
//
// `crypto` and `web` arrive transitively. A file that is about to be deleted
// does not earn a pubspec entry, so the lint is silenced here instead.
// ignore_for_file: depend_on_referenced_packages

import 'dart:convert';
import 'dart:js_interop';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/wasm.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;
import 'package:wisdom_shared/wisdom_shared.dart';

import '../data/database/database_manifest.dart';
import '../data/database/local_database.dart';

/// Where `flutter run` serves the bundled asset from.
const String _assetUrl = 'assets/assets/databases/bjt.db';
const String _dbFile = 'bjt.db';

/// What macOS gives for the same file, taken with the sqlite3 CLI on
/// 2026-09-20. The browser has to match these exactly.
const int _macCount = 27850;
const List<int> _macTopIds = [267827, 410827, 359950, 359951, 298421];
const String _macFirstEntry = 'සුත්තන්තපිටකෙ';
/// The JSON as stored, not re-serialised — a pretty-printer's separators would
/// add 55 characters here.
const int _macFirstPageJsonLength = 1629;
const int _macDn1Rows = 148;

void main() => runApp(const _ProbeApp());

class _ProbeApp extends StatefulWidget {
  const _ProbeApp();

  @override
  State<_ProbeApp> createState() => _ProbeAppState();
}

class _ProbeAppState extends State<_ProbeApp> {
  final List<String> _lines = [];
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  void _log(String line) {
    debugPrint(line);
    if (mounted) setState(() => _lines.add(line));
  }

  Future<void> _run({bool fresh = false}) async {
    setState(() {
      _lines.clear();
      _finished = false;
    });
    try {
      if (fresh) await _removeFromOpfs(_log);
      await _probe(_log);
      _log('--- probe finished ---');
    } catch (error, stack) {
      _log('!!! FAILED: $error');
      _log('$stack');
    }
    if (mounted) setState(() => _finished = true);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Drift on web — step 3 probe'),
          actions: [
            IconButton(
              tooltip: 'Copy the report',
              icon: const Icon(Icons.copy),
              onPressed: () => Clipboard.setData(
                ClipboardData(text: _lines.join('\n')),
              ),
            ),
            IconButton(
              tooltip: 'Delete the OPFS copy and download again',
              icon: const Icon(Icons.refresh),
              onPressed: _finished ? () => _run(fresh: true) : null,
            ),
          ],
          bottom: _finished
              ? null
              : const PreferredSize(
                  preferredSize: Size.fromHeight(4),
                  child: LinearProgressIndicator(),
                ),
        ),
        body: SelectionArea(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _lines.length,
            itemBuilder: (context, index) => Text(
              _lines[index],
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _probe(void Function(String) log) async {
  // Web reads the same bundled manifest native does, so the version in the
  // OPFS folder name comes from the build, not from the server.
  final String sha256Hex = await databaseSha256(_dbFile);
  final String name = 'bjt-${sha256Hex.substring(0, 16)}';
  log('manifest sha256: $sha256Hex');
  log('OPFS name:       $name');
  log('crossOriginIsolated: ${web.window.crossOriginIsolated}');

  final WasmProbeResult probe = await WasmDatabase.probe(
    sqlite3Uri: Uri.parse('sqlite3.wasm'),
    driftWorkerUri: Uri.parse('drift_worker.js'),
  );
  log('availableStorages: ${probe.availableStorages}');
  log('missingFeatures:   ${probe.missingFeatures}');
  log('existingDatabases: ${probe.existingDatabases}');

  if (!probe.availableStorages.contains(WasmStorageImplementation.opfsLocks)) {
    throw StateError('opfsLocks is not available — the headers did not land');
  }

  final bool installed = probe.existingDatabases
      .any((db) => db.$1 == WebStorageApi.opfs && db.$2 == name);
  if (installed) {
    log('already in OPFS — skipping the download');
  } else {
    await _download(name, log);
  }

  // A DatabaseConnection is a QueryExecutor, so LocalDatabase wraps it as it
  // wraps the native one. `enableMigrations: false` because the shipped file
  // keeps user_version 0.
  final db = LocalDatabase(
    await probe.open(
      WasmStorageImplementation.opfsLocks,
      name,
      enableMigrations: false,
    ),
  );

  await _search(db, log);
  await _readPages(db, log);
  await db.close();
}

/// Drops `drift_db/<name>` so the next run measures a real download.
Future<void> _removeFromOpfs(void Function(String) log) async {
  final String name = 'bjt-${(await databaseSha256(_dbFile)).substring(0, 16)}';
  // Chrome's opfsLocks mode lets go of a file up to 150 ms after the last
  // query (sqlite3's `asyncIdleWaitTimeMs`), so a delete straight after the
  // previous run's close can still meet an open handle.
  await Future<void>.delayed(const Duration(milliseconds: 500));

  final web.FileSystemDirectoryHandle root =
      await web.window.navigator.storage.getDirectory().toDart;
  final web.FileSystemDirectoryHandle driftDir = await root
      .getDirectoryHandle(
        'drift_db',
        web.FileSystemGetDirectoryOptions(create: true),
      )
      .toDart;
  await driftDir
      .removeEntry(name, web.FileSystemRemoveOptions(recursive: true))
      .toDart;
  log('removed drift_db/$name');
}

/// Streams the asset into `drift_db/<name>/database`, the path Drift opens.
Future<void> _download(String name, void Function(String) log) async {
  log('downloading $_assetUrl …');

  final web.FileSystemDirectoryHandle root =
      await web.window.navigator.storage.getDirectory().toDart;
  final web.FileSystemDirectoryHandle driftDir = await root
      .getDirectoryHandle(
        'drift_db',
        web.FileSystemGetDirectoryOptions(create: true),
      )
      .toDart;
  final web.FileSystemDirectoryHandle dbDir = await driftDir
      .getDirectoryHandle(
        name,
        web.FileSystemGetDirectoryOptions(create: true),
      )
      .toDart;
  final web.FileSystemFileHandle file = await dbDir
      .getFileHandle('database', web.FileSystemGetFileOptions(create: true))
      .toDart;
  final web.FileSystemWritableFileStream sink =
      await file.createWritable().toDart;

  final web.Response response = await web.window
      .fetch(_assetUrl.toJS, web.RequestInit(cache: 'no-store'))
      .toDart;
  if (!response.ok) {
    throw StateError('GET $_assetUrl returned ${response.status}');
  }
  final web.ReadableStream? body = response.body;
  if (body == null) throw StateError('GET $_assetUrl had no body');

  Digest? digest;
  final ByteConversionSink hasher = sha256.startChunkedConversion(
    ChunkedConversionSink<Digest>.withCallback((all) => digest = all.single),
  );

  final reader = web.ReadableStreamDefaultReader(body);
  final wall = Stopwatch()..start();
  // Only the SHA-256 calls are inside this watch, so its total is the hash's
  // own CPU cost rather than the network's.
  final hashing = Stopwatch();
  var bytes = 0;

  while (true) {
    final web.ReadableStreamReadResult chunk = await reader.read().toDart;
    if (chunk.done) break;
    final JSUint8Array data = chunk.value! as JSUint8Array;
    await sink.write(data).toDart;
    final dart = data.toDart;
    bytes += dart.length;
    hashing.start();
    hasher.add(dart);
    hashing.stop();
  }
  hashing.start();
  hasher.close();
  hashing.stop();
  await sink.close().toDart;
  wall.stop();

  log('wrote $bytes bytes in ${wall.elapsedMilliseconds} ms');
  log('SHA-256 over $bytes bytes: ${hashing.elapsedMilliseconds} ms');
  log('SHA-256: $digest');
}

Future<void> _search(LocalDatabase db, void Function(String) log) async {
  // Mirrors fts_local_datasource.dart: bm25 in the CTE, `id` breaking ties.
  const String rankedSql = '''
    WITH ranked AS (
      SELECT m.id, m.filename, m.eind, m.language, m.type, m.level, m.nodeKey,
        bm25(bjt_fts) AS score
      FROM bjt_fts
      JOIN bjt_meta m ON bjt_fts.rowid = m.id
      WHERE bjt_fts MATCH ?
    )
    SELECT * FROM ranked ORDER BY score, id LIMIT ? OFFSET ?
  ''';
  const String countSql =
      'SELECT COUNT(*) as count FROM bjt_fts WHERE bjt_fts MATCH ?';

  final String ftsQuery = buildFtsQuery('එවං');
  log('--- search: MATCH \'$ftsQuery\' ---');

  final cold = Stopwatch()..start();
  final rows = await db.rawQuery(rankedSql, [ftsQuery, 50, 0]);
  cold.stop();
  final warm = Stopwatch()..start();
  await db.rawQuery(rankedSql, [ftsQuery, 50, 0]);
  warm.stop();

  final counting = Stopwatch()..start();
  final count = (await db.rawQuery(countSql, [ftsQuery])).first['count'] as int;
  counting.stop();

  final ids = [for (final row in rows.take(5)) row['id'] as int];
  log('top 50 rows: ${rows.length} '
      '(${cold.elapsedMilliseconds} ms cold, ${warm.elapsedMilliseconds} ms warm)');
  log('top 5 ids:   $ids');
  log('  macOS:     $_macTopIds  ${_listEquals(ids, _macTopIds) ? "MATCH" : "DIFFERENT"}');
  log('count:       $count in ${counting.elapsedMilliseconds} ms');
  log('  macOS:     $_macCount  ${count == _macCount ? "MATCH" : "DIFFERENT"}');
}

Future<void> _readPages(LocalDatabase db, void Function(String) log) async {
  // Mirrors bjt_content_local_datasource.dart's loadPages span query.
  const String sql =
      'SELECT pageIndex, language, pageNum, CAST(blob AS BLOB) AS blob '
      'FROM bjt_content WHERE filename = ? AND pageIndex >= ? ORDER BY pageIndex';

  log('--- page read: dn-1 ---');
  final rows = await db.rawQuery(sql, ['dn-1', 0]);
  log('rows: ${rows.length}');
  log('  macOS: $_macDn1Rows '
      '${rows.length == _macDn1Rows ? "MATCH" : "DIFFERENT"}');

  // The same pure-Dart decoder the datasource uses. If this is slow, step 4
  // swaps only this call for the browser's DecompressionStream.
  final inflating = Stopwatch();
  var compressed = 0;
  var plain = 0;
  String? firstPageJson;

  for (final row in rows) {
    final blob = row['blob'] as List<int>;
    compressed += blob.length;
    inflating.start();
    final bytes = const ZLibDecoder().decodeBytes(blob, verify: true);
    inflating.stop();
    plain += bytes.length;
    if (row['pageIndex'] == 0 && row['language'] == 'pali') {
      firstPageJson = utf8.decode(bytes);
    }
  }

  log('zlib inflate: ${rows.length} blobs, $compressed → $plain bytes, '
      '${inflating.elapsedMilliseconds} ms '
      '(${(inflating.elapsedMicroseconds / rows.length).round()} µs per blob)');

  final page = json.decode(firstPageJson!) as Map<String, dynamic>;
  final entries = page['entries'] as List<dynamic>;
  final first = (entries.first as Map<String, dynamic>)['text'] as String;
  log('dn-1 page 0 pali: ${firstPageJson.length} chars of JSON, '
      '${entries.length} entries');
  log('  macOS:          $_macFirstPageJsonLength chars '
      '${firstPageJson.length == _macFirstPageJsonLength ? "MATCH" : "DIFFERENT"}');
  log('first entry: $first');
  log('  macOS:     $_macFirstEntry '
      '${first == _macFirstEntry ? "MATCH" : "DIFFERENT"}');
}

bool _listEquals(List<int> a, List<int> b) =>
    a.length == b.length && !a.indexed.any((e) => b[e.$1] != e.$2);
