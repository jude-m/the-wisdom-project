import 'package:test/test.dart';
import 'package:wisdom_shared/wisdom_shared.dart';

/// Tests the REAL shared `buildFtsQuery` — the #1 function in the package
/// (a bug here silently breaks ALL full-text search on both the Flutter client
/// and the Dart server).
///
/// This replaces the old `test/data/datasources/fts_datasource_test.dart`, which
/// tested a hand-copied reimplementation of the logic (a "test smell": the copy
/// could pass while the real function drifted/broke). Here we import and exercise
/// the actual `package:wisdom_shared` function, so the matrix genuinely guards it.
void main() {
  group('buildFtsQuery — single word', () {
    test('prefix match adds a trailing wildcard (default)', () {
      // Pali is written in Sinhala script in this app (අනාථ, not "anatha").
      expect(buildFtsQuery('අනාථ'), 'අනාථ*');
    });

    test('exact match has no wildcard', () {
      expect(buildFtsQuery('අනාථ', isExactMatch: true), 'අනාථ');
    });

    test('single word bypasses phrase logic even with isPhraseSearch: true', () {
      expect(
        buildFtsQuery('singleword', isPhraseSearch: true, isExactMatch: false),
        'singleword*',
      );
    });
  });

  group('buildFtsQuery — empty / whitespace', () {
    test('empty query → empty quoted string (valid FTS5 no-op)', () {
      expect(buildFtsQuery(''), '""');
    });

    test('collapses repeated inner spaces (split + filter empties)', () {
      expect(
        buildFtsQuery('word1  word2', isPhraseSearch: true, isExactMatch: true),
        '"word1 word2"',
      );
    });

    test('trims leading/trailing spaces', () {
      expect(
        buildFtsQuery('  word1 word2  ',
            isPhraseSearch: true, isExactMatch: true),
        '"word1 word2"',
      );
    });
  });

  // The 6-row matrix from the function's own doc-comment table. Each row is the
  // contract a search mode relies on; assert the EXACT FTS5 string.
  group('buildFtsQuery — the 6 multi-word modes', () {
    const twoWords = 'term1 term2';

    test('phrase + exact → "term1 term2"', () {
      expect(
        buildFtsQuery(twoWords, isPhraseSearch: true, isExactMatch: true),
        '"term1 term2"',
      );
    });

    test('phrase + prefix → NEAR(term1* term2*, 1)', () {
      // FTS5 forbids wildcards inside phrase quotes; NEAR/1 approximates it.
      expect(
        buildFtsQuery(twoWords, isPhraseSearch: true, isExactMatch: false),
        'NEAR(term1* term2*, 1)',
      );
    });

    test('separate + anywhere + exact → implicit AND "term1 term2"', () {
      expect(
        buildFtsQuery(twoWords,
            isPhraseSearch: false, isAnywhereInText: true, isExactMatch: true),
        'term1 term2',
      );
    });

    test('separate + anywhere + prefix → "term1* term2*"', () {
      expect(
        buildFtsQuery(twoWords,
            isPhraseSearch: false, isAnywhereInText: true, isExactMatch: false),
        'term1* term2*',
      );
    });

    test('separate + proximity + exact → NEAR(term1 term2, n)', () {
      expect(
        buildFtsQuery(twoWords,
            isPhraseSearch: false,
            isAnywhereInText: false,
            isExactMatch: true,
            proximityDistance: 10),
        'NEAR(term1 term2, 10)',
      );
    });

    test('separate + proximity + prefix → NEAR(term1* term2*, n)', () {
      expect(
        buildFtsQuery(twoWords,
            isPhraseSearch: false,
            isAnywhereInText: false,
            isExactMatch: false,
            proximityDistance: 10),
        'NEAR(term1* term2*, 10)',
      );
    });
  });

  group('buildFtsQuery — proximity distance is threaded through', () {
    test('custom distance (50)', () {
      expect(
        buildFtsQuery('word1 word2',
            isPhraseSearch: false, isExactMatch: true, proximityDistance: 50),
        'NEAR(word1 word2, 50)',
      );
    });

    test('minimum distance (1)', () {
      expect(
        buildFtsQuery('word1 word2',
            isPhraseSearch: false, isExactMatch: true, proximityDistance: 1),
        'NEAR(word1 word2, 1)',
      );
    });

    test('maximum distance (100)', () {
      expect(
        buildFtsQuery('word1 word2',
            isPhraseSearch: false, isExactMatch: true, proximityDistance: 100),
        'NEAR(word1 word2, 100)',
      );
    });
  });

  group('buildFtsQuery — three-word phrase with prefix', () {
    test('wildcards every token inside NEAR/1', () {
      expect(
        buildFtsQuery('word1 word2 word3',
            isPhraseSearch: true, isExactMatch: false),
        'NEAR(word1* word2* word3*, 1)',
      );
    });
  });
}
