import 'dart:async';

import 'package:drift/drift.dart';

import 'web_database_installer.dart';

/// Opens [dbName] from its copy in OPFS, waiting for the download to finish.
///
/// See [WebDatabaseInstaller] for how the copy gets there. Installing is not
/// opening: this never downloads on its own, because a failed open is retried
/// on the next query and would otherwise start the whole file again each time.
Future<QueryExecutor> openLocalExecutor(String dbName) {
  final installer = WebDatabaseInstaller.instance;
  // Idempotent, and never throws. Usually the first-visit screen has already
  // called it; a plain app start otherwise reads nothing until this point.
  unawaited(installer.start());
  return installer.open(dbName);
}
