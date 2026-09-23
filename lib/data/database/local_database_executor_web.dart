import 'package:drift/drift.dart';

import 'web_database_installer.dart';

/// Opens [dbName] from its copy in OPFS, waiting for the install to finish.
///
/// See [WebDatabaseInstaller] for how the copy gets there.
Future<QueryExecutor> openLocalExecutor(String dbName) =>
    WebDatabaseInstaller.instance.open(dbName);
