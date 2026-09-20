import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:path/path.dart';

const String _manifestAsset = 'assets/databases/manifest.json';

/// The SHA-256 `tools/db-finalize.js` recorded for [dbName]. Throws a
/// [StateError] naming the command to run when the manifest has no entry.
Future<String> databaseSha256(String dbName) async {
  final manifest =
      jsonDecode(await rootBundle.loadString(_manifestAsset)) as Map;
  final sha256 = (manifest[dbName] as Map?)?['sha256'];
  if (sha256 is! String) {
    throw StateError(
      '$_manifestAsset has no entry for $dbName. Rebuild the database: '
      'cd tools && npm run generate-${basenameWithoutExtension(dbName)}',
    );
  }
  return sha256;
}
