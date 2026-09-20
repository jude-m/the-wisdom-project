import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:path/path.dart';

/// Where both databases and their manifest are declared in `pubspec.yaml`.
/// Web serves the same files one level down, under `assets/`.
const String databaseAssetFolder = 'assets/databases';

const String _manifestAsset = '$databaseAssetFolder/manifest.json';

/// What `tools/db-finalize.js` recorded for one database.
///
/// [bytes] is how web knows a download finished: hashing 179 MB in the browser
/// costs seconds of main-isolate CPU, a byte count nothing. It also drives the
/// progress bar, which cannot use `Content-Length` — the file is served gzipped.
typedef DatabaseManifestEntry = ({String sha256, int bytes});

/// [dbName]'s entry in this build's manifest. Throws a [StateError] naming the
/// command to run when the manifest has no usable entry.
Future<DatabaseManifestEntry> databaseManifestEntry(String dbName) async {
  final manifest =
      jsonDecode(await rootBundle.loadString(_manifestAsset)) as Map;
  final entry = manifest[dbName] as Map?;
  final sha256 = entry?['sha256'];
  final bytes = entry?['bytes'];
  if (sha256 is! String) {
    throw StateError(
      '$_manifestAsset has no entry for $dbName. Rebuild the database: '
      'cd tools && npm run generate-${basenameWithoutExtension(dbName)}',
    );
  }
  if (bytes is! int) {
    // Two different repairs, so two different messages: a missing entry needs
    // the database built, a missing byte count only needs the manifest redone
    // — it was written before web needed one.
    throw StateError(
      "$_manifestAsset has $dbName's hash but no byte count, so an older "
      'tools/db-finalize.js wrote it. Refresh the manifest without rebuilding: '
      "cd tools && node -e \"require('./db-finalize')"
      ".writeManifestEntry('../$databaseAssetFolder/$dbName')\"",
    );
  }
  return (sha256: sha256, bytes: bytes);
}
