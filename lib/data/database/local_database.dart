import 'package:drift/drift.dart';

import 'local_database_executor.dart';

/// A read-only SQLite database on this device, one shared connection per file.
///
/// Drift adopted thin — no tables are declared and every read is raw SQL
/// through [rawQuery], so the database files and their SQL stay as they are.
class LocalDatabase extends GeneratedDatabase {
  LocalDatabase(super.executor);

  static final Map<String, Future<LocalDatabase>> _open = {};

  @override
  Iterable<TableInfo> get allTables => const [];

  @override
  int get schemaVersion => 1;

  /// The connection to [dbName], opened on first use and shared by every
  /// reader after, so two first-launch readers never copy the same asset.
  static Future<LocalDatabase> open(String dbName) =>
      _open[dbName] ??= _connect(dbName);

  /// Closes [dbName] for every reader of it; the next [open] reconnects.
  ///
  /// For app shutdown only: the FTS index and `bjt_content` share one
  /// connection, so closing search also closes the page text.
  static Future<void> closeShared(String dbName) async {
    final opening = _open.remove(dbName);
    if (opening != null) await (await opening).close();
  }

  /// Runs [sql], binding its `?` placeholders to [args] in order.
  Future<List<Map<String, dynamic>>> rawQuery(
    String sql,
    List<Object> args,
  ) async {
    final rows = await customSelect(
      sql,
      variables: [for (final arg in args) Variable<Object>(arg)],
    ).get();
    return [for (final row in rows) row.data];
  }

  static Future<LocalDatabase> _connect(String dbName) async {
    // Drift warns about a second instance of one database class, because two
    // on the same executor race. Each of these owns its own file and executor.
    // The switch is global, so it silences that warning for every class.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

    LocalDatabase? database;
    try {
      database = LocalDatabase(await openLocalExecutor(dbName));
      // Drift connects lazily. Connect now, so a bad file fails here and the
      // next open retries instead of keeping a broken connection.
      await database.customSelect('SELECT 1').get();
      return database;
    } catch (_) {
      _open.remove(dbName);
      await database?.close().catchError((Object _) {});
      rethrow;
    }
  }
}
