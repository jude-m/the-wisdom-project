import 'package:drift/drift.dart';

/// Web still reads the canon through the server, so nothing opens a local
/// database there yet.
Future<QueryExecutor> openLocalExecutor(String dbName) =>
    throw UnsupportedError('Local databases are not opened on web: $dbName');
