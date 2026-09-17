import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import 'bundled_database_manifest.dart';

const int _copyPieceBytes = 8 * 1024 * 1024;

/// Opens the bundled asset [dbName] from its copy on disk, copying it out of
/// the bundle first unless the copy matches the build's manifest.
///
/// If the OS deletes the copy, the next open copies from the bundle again.
Future<QueryExecutor> openBundledExecutor(String dbName) async {
  final sha256 = await bundledDatabaseSha256(dbName);
  // Android clears its cache folder whenever the phone needs space, and a
  // recopy there unpacks the whole compressed asset. So Android keeps the
  // copies in its files folder, left out of backups by `res/xml/`.
  final base = Platform.isAndroid
      ? await getApplicationSupportDirectory()
      : await getApplicationCacheDirectory();
  final directory = Directory(join(base.path, 'databases'));
  await directory.create(recursive: true);
  final file = File(join(directory.path, dbName));
  // Holds the SHA-256 of the asset the copy was made from.
  final stamp = File('${file.path}.sha256');

  // Both files are checked: the OS can delete one of the pair.
  final isCurrent = await file.exists() &&
      await stamp.exists() &&
      await stamp.readAsString() == sha256;
  if (!isCurrent) {
    // The stamp goes first: it may already hold this hash, and a copy cut
    // short must not look current.
    if (await stamp.exists()) await stamp.delete();
    // Frees the old copy's space before the new one is written.
    if (await file.exists()) await file.delete();
    try {
      await _copyAsset(dbName, file);
      // Written last, so a copy cut short is redone on the next open.
      await stamp.writeAsString(sha256, flush: true);
    } catch (_) {
      // A failed copy (say, on a full phone) gives its space back. Nothing
      // else would: Android never clears the files folder.
      if (await file.exists()) await file.delete();
      rethrow;
    }
  }

  // Queries run on a background isolate, off the UI thread. No migrations:
  // the shipped files keep `user_version` 0, and Drift would otherwise write it.
  return NativeDatabase.createInBackground(file, enableMigrations: false);
}

Future<void> _copyAsset(String dbName, File file) async {
  final data = await rootBundle.load('assets/databases/$dbName');
  final output = await file.open(mode: FileMode.write);
  try {
    // Written in pieces so dart:io copies 8 MB per write. Given the whole
    // buffer, even with a range, it hands all of it to the IO thread.
    for (var start = 0; start < data.lengthInBytes; start += _copyPieceBytes) {
      final end = min(start + _copyPieceBytes, data.lengthInBytes);
      await output.writeFrom(Uint8List.sublistView(data, start, end));
    }
    await output.flush();
  } finally {
    await output.close();
  }
}
