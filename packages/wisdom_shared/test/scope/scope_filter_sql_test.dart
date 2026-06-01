import 'package:test/test.dart';
import 'package:wisdom_shared/wisdom_shared.dart';

// Guards the SHARED language-filter SQL helpers used by both the Flutter client
// (via ScopeFilterService) and the Dart server (directly). These single-source
// the `m.language = ?` clause + its bound parameter, so the 'pali' / 'sinh'
// column contract lives in exactly one tested place.
void main() {
  group('ScopeFilterSql.buildLanguageClause', () {
    test('null language → null clause (search both languages)', () {
      expect(ScopeFilterSql.buildLanguageClause(null), isNull);
    });

    test('pali → parameterised clause on the default meta alias', () {
      expect(ScopeFilterSql.buildLanguageClause('pali'), 'm.language = ?');
    });

    test('sinh → same clause shape; the value is bound, never inlined', () {
      final clause = ScopeFilterSql.buildLanguageClause('sinh');
      expect(clause, 'm.language = ?');
      // The language value MUST travel as a bound '?' parameter — never spliced
      // into the SQL string. Inlining it would be an injection vector and would
      // also desync the prepared-statement argument order.
      expect(clause, isNot(contains('sinh')));
    });

    test('honours a custom table alias and column name', () {
      expect(
        ScopeFilterSql.buildLanguageClause(
          'pali',
          tableAlias: 't',
          columnName: 'lang',
        ),
        't.lang = ?',
      );
    });
  });

  group('ScopeFilterSql.getLanguageParams', () {
    test('null → no params', () {
      expect(ScopeFilterSql.getLanguageParams(null), isEmpty);
    });

    test('pali → single-element param list', () {
      expect(ScopeFilterSql.getLanguageParams('pali'), ['pali']);
    });

    test('sinh passes through verbatim — the DB code, not "sinhala"', () {
      // Guards the 'sinh' vs 'sinhala' contract right at the SQL boundary.
      expect(ScopeFilterSql.getLanguageParams('sinh'), ['sinh']);
    });
  });

  // The cardinal rule of these queries: the number of '?' placeholders in the
  // clause must equal the number of bound args. This is the exact bug class the
  // single-sourcing refactor could otherwise introduce.
  group('clause and params stay in lock-step (one ? ⇔ one arg)', () {
    test('filtered: exactly one placeholder and one bound arg', () {
      const language = 'sinh';
      final clause = ScopeFilterSql.buildLanguageClause(language);
      final params = ScopeFilterSql.getLanguageParams(language);
      expect(clause, isNotNull);
      expect('?'.allMatches(clause!).length, 1);
      expect(params.length, 1);
    });

    test('unfiltered: no placeholder and no args', () {
      expect(ScopeFilterSql.buildLanguageClause(null), isNull);
      expect(ScopeFilterSql.getLanguageParams(null), isEmpty);
    });
  });
}
