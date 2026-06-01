import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:the_wisdom_project/data/services/scope_filter_service.dart';

/// Proves the FTS `m.language = ?` filter actually returns only the right rows
/// when run against a REAL SQLite (FTS5) engine — something the string-level
/// `ScopeFilterSql` test can't show.
///
/// `FTSDataSourceImpl` opens the bundled 114 MB DB via path_provider/rootBundle
/// and exposes no seam to inject a database, so (rather than add a production
/// test shim) we seed a tiny in-memory mirror of its `bjt_fts` + `bjt_meta`
/// schema and drive the SAME shared clause builder the datasource uses
/// (`ScopeFilterService`, which delegates to `wisdom_shared`'s `ScopeFilterSql`).
/// The SELECT/COUNT skeletons mirror the datasource's `searchFullText` /
/// `countFullTextMatches`.
void main() {
  late Database db;

  setUpAll(() {
    // Use the FFI SQLite implementation (pure Dart, runs on the test VM).
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute('CREATE VIRTUAL TABLE bjt_fts USING fts5(text);');
    await db.execute('''
      CREATE TABLE bjt_meta (
        id INTEGER PRIMARY KEY,
        filename TEXT, eind TEXT, language TEXT,
        type TEXT, level INTEGER, nodeKey TEXT
      );
    ''');

    // Same logical entry in two languages; both contain the search term, so
    // only the language filter distinguishes them. DB stores Sinhala as 'sinh'.
    await db.execute("INSERT INTO bjt_fts(rowid, text) VALUES (1, 'dhamma pali');");
    await db.execute(
      "INSERT INTO bjt_meta VALUES (1, 'dn-1', '0-0', 'pali', 'p', 0, 'dn-1');",
    );
    await db.execute("INSERT INTO bjt_fts(rowid, text) VALUES (2, 'dhamma sinh');");
    await db.execute(
      "INSERT INTO bjt_meta VALUES (2, 'dn-1', '0-0', 'sinh', 'p', 0, 'dn-1');",
    );
  });

  tearDown(() async => db.close());

  // Mirrors searchFullText's JOIN + optional language clause.
  Future<List<String>> matchedLanguages(String? language) async {
    final sql = StringBuffer()
      ..write('SELECT m.language FROM bjt_fts '
          'JOIN bjt_meta m ON bjt_fts.rowid = m.id WHERE bjt_fts MATCH ?');
    final args = <Object>['dhamma'];

    final clause = ScopeFilterService.buildLanguageClause(language);
    if (clause != null) {
      sql.write(' AND $clause');
      args.addAll(ScopeFilterService.getLanguageParams(language));
    }
    final rows = await db.rawQuery(sql.toString(), args);
    return rows.map((r) => r['language'] as String).toList();
  }

  // Mirrors countFullTextMatches, including its `needsMetaJoin` branch: a bare
  // MATCH count when there's no filter, a joined count when a language is set.
  Future<int> countMatches(String? language) async {
    final buffer = StringBuffer();
    final args = <Object>['dhamma'];
    final needsMetaJoin = language != null;

    if (needsMetaJoin) {
      buffer.write('SELECT COUNT(*) as count FROM bjt_fts t '
          'JOIN bjt_meta m ON t.rowid = m.id WHERE bjt_fts MATCH ?');
      final clause = ScopeFilterService.buildLanguageClause(language);
      if (clause != null) {
        buffer.write(' AND $clause');
        args.addAll(ScopeFilterService.getLanguageParams(language));
      }
    } else {
      buffer.write('SELECT COUNT(*) as count FROM bjt_fts WHERE bjt_fts MATCH ?');
    }
    final rows = await db.rawQuery(buffer.toString(), args);
    return rows.first['count'] as int;
  }

  // Mirrors countFullTextMatches' COMBINED branch (fts_local_datasource.dart):
  // when BOTH a scope and a language are set it joins meta once and ANDs the two
  // clauses together. Re-runs the real shared builders for each clause.
  Future<int> countScopedLang(Set<String> scope, String? language) async {
    final buffer = StringBuffer()
      ..write('SELECT COUNT(*) as count FROM bjt_fts t '
          'JOIN bjt_meta m ON t.rowid = m.id WHERE bjt_fts MATCH ?');
    final args = <Object>['dhamma'];

    final scopeClause = ScopeFilterService.buildWhereClause(scope);
    if (scopeClause != null) {
      buffer.write(' AND $scopeClause');
      args.addAll(ScopeFilterService.getWhereParams(scope));
    }
    final languageClause = ScopeFilterService.buildLanguageClause(language);
    if (languageClause != null) {
      buffer.write(' AND $languageClause');
      args.addAll(ScopeFilterService.getLanguageParams(language));
    }

    final rows = await db.rawQuery(buffer.toString(), args);
    return rows.first['count'] as int;
  }

  group('searchFullText language clause against real SQLite', () {
    test('null → returns rows in BOTH languages', () async {
      expect((await matchedLanguages(null)).toSet(), {'pali', 'sinh'});
    });

    test("'pali' → returns only the Pali row", () async {
      expect(await matchedLanguages('pali'), ['pali']);
    });

    test("'sinh' → returns only the Sinhala row", () async {
      expect(await matchedLanguages('sinh'), ['sinh']);
    });
  });

  group('countFullTextMatches language clause against real SQLite', () {
    test('null → bare MATCH count of both rows (no join)', () async {
      expect(await countMatches(null), 2);
    });

    test("'pali' → joined count of just the Pali row "
        '(guards the needsMetaJoin branch)', () async {
      expect(await countMatches('pali'), 1);
    });

    test("'sinh' → joined count of just the Sinhala row", () async {
      expect(await countMatches('sinh'), 1);
    });
  });

  group('countFullTextMatches scope + language (both clauses ANDed)', () {
    test('intersects scope AND language — proves BOTH filters apply', () async {
      // Add a third 'dhamma' row: Pali, but in a DIFFERENT location (mn-1).
      //   row 1: pali / dn-1     row 2: sinh / dn-1     row 3: pali / mn-1
      await db
          .execute("INSERT INTO bjt_fts(rowid, text) VALUES (3, 'dhamma pali');");
      await db.execute(
        "INSERT INTO bjt_meta VALUES (3, 'mn-1', '0-0', 'pali', 'p', 0, 'mn-1');",
      );

      // scope {dn} alone → both dn-1 rows (the Pali + the Sinhala one).
      expect(await countScopedLang({'dn'}, null), 2);
      // language 'pali' alone → both Pali rows (dn-1 + mn-1).
      expect(await countScopedLang(const {}, 'pali'), 2);
      // scope {dn} AND language 'pali' → only their INTERSECTION: the dn-1 Pali
      // row. Strictly fewer than either filter alone, so a dropped clause (→ 2)
      // or an OR instead of AND (→ 3) would fail this.
      expect(await countScopedLang({'dn'}, 'pali'), 1);
    });
  });
}
