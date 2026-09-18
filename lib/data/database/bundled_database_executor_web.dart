import 'package:drift/drift.dart';

/// Web still reads the canon through the server, so nothing opens a bundled
/// database there yet.
Future<QueryExecutor> openBundledExecutor(String dbName) =>
    throw UnsupportedError('Bundled databases are not opened on web: $dbName');
