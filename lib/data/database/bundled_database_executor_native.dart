import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

/// Opens the bundled asset [dbName] from the app's documents directory,
/// copying it out of the bundle first when no copy is there.
Future<QueryExecutor> openBundledExecutor(String dbName) async {
  final documentsDirectory = await getApplicationDocumentsDirectory();
  final file = File(join(documentsDirectory.path, dbName));

  // Copied only when absent, so an app update never replaces an existing copy.
  if (!await file.exists()) {
    final ByteData data = await rootBundle.load('assets/databases/$dbName');
    await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
  }

  // Queries run on a background isolate, off the UI thread. No migrations:
  // the shipped files keep `user_version` 0, and Drift would otherwise write it.
  return NativeDatabase.createInBackground(file, enableMigrations: false);
}
