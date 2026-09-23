import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';
import 'package:wisdom_shared/wisdom_shared.dart';

/// Server-side coverage for the FTS language filter.
///
/// The server's `FtsHandler` has its OWN SQL assembly (it can't reuse the
/// client datasource), but it shares the WHERE-clause builders with the client
/// via `wisdom_shared`'s [ScopeFilterSql]. This test proves two things the
/// client tests can't, because they run against a different SQLite engine:
///
///   1. The shared `m.language = ?` clause + bound param actually filter rows
///      when run against the server's real `package:sqlite3` (FTS5) engine.
///   2. The handler's language whitelist degrades an unknown value to "no
///      filter" (both languages) rather than `m.language = '<garbage>'` (which
///      would silently return zero rows).
///
/// `FtsHandler` opens real DB files via `DatabaseManager` and has no injection
/// seam, so rather than add a production-only test shim we seed an in-memory
/// DB and run the SAME SQL skeleton the handler builds, using the REAL shared
/// builders for the part under test (the language clause/params).
void main() {
  late Database db;

  setUp(() {
    // In-memory mirror of the server's bjt_fts (FTS5) + bjt_meta schema.
    db = sqlite3.openInMemory();
    db.execute('CREATE VIRTUAL TABLE bjt_fts USING fts5(text);');
    db.execute('''
      CREATE TABLE bjt_meta (
        id INTEGER PRIMARY KEY,
        filename TEXT, eind TEXT, language TEXT,
        type TEXT, level INTEGER, nodeKey TEXT
      );
    ''');

    // Two rows for the same logical entry: one Pali, one Sinhala. Both contain
    // the search term, so only the language filter can tell them apart.
    // (DB stores Sinhala as 'sinh', NOT 'sinhala' — the contract under guard.)
    db.execute("INSERT INTO bjt_fts(rowid, text) VALUES (1, 'dhamma pali');");
    db.execute(
      "INSERT INTO bjt_meta VALUES (1, 'dn-1', '0-0', 'pali', 'p', 0, 'dn-1');",
    );
    db.execute("INSERT INTO bjt_fts(rowid, text) VALUES (2, 'dhamma sinh');");
    db.execute(
      "INSERT INTO bjt_meta VALUES (2, 'dn-1', '0-0', 'sinh', 'p', 0, 'dn-1');",
    );
  });

  tearDown(() => db.dispose());

  // Mirrors the handler's COUNT skeleton, but uses the REAL shared builders for
  // the language clause/params (the logic under test).
  int countWith(String? effectiveLanguage) {
    final sql = StringBuffer()
      ..write('SELECT COUNT(*) AS count FROM bjt_fts t '
          'JOIN bjt_meta m ON t.rowid = m.id WHERE bjt_fts MATCH ?');
    final args = <Object>['dhamma'];

    final clause = ScopeFilterSql.buildLanguageClause(effectiveLanguage);
    if (clause != null) {
      sql.write(' AND $clause');
      args.addAll(ScopeFilterSql.getLanguageParams(effectiveLanguage));
    }
    return db.select(sql.toString(), args).first['count'] as int;
  }

  // Mirrors the handler's SEARCH skeleton; returns the matched rows' languages.
  List<String> searchLanguagesWith(String? effectiveLanguage) {
    final sql = StringBuffer()
      ..write('SELECT m.language FROM bjt_fts '
          'JOIN bjt_meta m ON bjt_fts.rowid = m.id WHERE bjt_fts MATCH ?');
    final args = <Object>['dhamma'];

    final clause = ScopeFilterSql.buildLanguageClause(effectiveLanguage);
    if (clause != null) {
      sql.write(' AND $clause');
      args.addAll(ScopeFilterSql.getLanguageParams(effectiveLanguage));
    }
    return db
        .select(sql.toString(), args)
        .map((r) => r['language'] as String)
        .toList();
  }

  group('shared language clause filters real sqlite3 rows', () {
    test('null → both languages counted', () {
      expect(countWith(null), 2);
    });

    test("'pali' → only the Pali row", () {
      expect(countWith('pali'), 1);
      expect(searchLanguagesWith('pali'), ['pali']);
    });

    test("'sinh' → only the Sinhala row (the 'sinh' DB code, not 'sinhala')",
        () {
      expect(countWith('sinh'), 1);
      expect(searchLanguagesWith('sinh'), ['sinh']);
    });
  });

  group('handler language whitelist degrades unknown → no filter', () {
    // Duplicate the handler's whitelist literal here (rather than reach into a
    // private const): the rule is small and stable, and the test should fail if
    // the contract changes.
    const allowedLanguages = {'pali', 'sinh'};

    String? effectiveLanguage(String? raw) =>
        (raw != null && allowedLanguages.contains(raw)) ? raw : null;

    test('unknown language value → searches BOTH (count 2), not zero', () {
      // A bad value must NOT become `m.language = 'xx'` (which would count 0).
      expect(effectiveLanguage('xx'), isNull);
      expect(countWith(effectiveLanguage('xx')), 2);
    });

    test('whitelisted value passes through and filters', () {
      expect(effectiveLanguage('sinh'), 'sinh');
      expect(countWith(effectiveLanguage('sinh')), 1);
    });
  });
}
