import 'package:flutter_test/flutter_test.dart';

/// Tests for FTS query building logic in FTSDataSourceImpl.
///
/// Since `_buildFtsQuery` is private, we test it indirectly through a
/// testable wrapper or by making the method @visibleForTesting.
/// For now, these tests document the expected FTS5 query syntax.
void main() {
  group('FTS Query Building -', () {
    // Helper to simulate _buildFtsQuery behavior for testing
    // This mirrors the implementation in fts_datasource.dart:185-247
    String buildFtsQuery(
      String queryText, {
      bool isExactMatch = false,
      bool isPhraseSearch = true,
      bool isAnywhereInText = false,
      int proximityDistance = 10,
    }) {
      if (queryText.isEmpty) {
        return '""';
      }

      final words = queryText.split(' ').where((w) => w.isNotEmpty).toList();

      if (words.length == 1) {
        return isExactMatch ? words[0] : '${words[0]}*';
      }

      // Multi-word handling
      if (isPhraseSearch) {
        if (isExactMatch) {
          return '"${words.join(' ')}"';
        } else {
          return 'NEAR(${words.map((w) => '$w*').join(' ')}, 1)';
        }
      } else {
        if (isAnywhereInText) {
          if (isExactMatch) {
            return words.join(' ');
          } else {
            return words.map((w) => '$w*').join(' ');
          }
        } else {
          if (isExactMatch) {
            return 'NEAR(${words.join(' ')}, $proximityDistance)';
          } else {
            return 'NEAR(${words.map((w) => '$w*').join(' ')}, $proximityDistance)';
          }
        }
      }
    }

    group('Single word queries -', () {
      test('prefix match adds wildcard', () {
        // ARRANGE
        const query = 'අනාථ';

        // ACT
        final result = buildFtsQuery(query, isExactMatch: false);

        // ASSERT - prefix matching uses wildcard
        expect(result, equals('අනාථ*'));
      });

      test('exact match has no wildcard', () {
        // ARRANGE
        const query = 'අනාථ';

        // ACT
        final result = buildFtsQuery(query, isExactMatch: true);

        // ASSERT - exact token matching, no wildcard
        expect(result, equals('අනාථ'));
      });
    });

    group('Phrase search (isPhraseSearch=true) -', () {
      test('exact phrase uses double quotes', () {
        // ARRANGE
        const query = 'අනාථ පිණ්ඩික';

        // ACT
        final result = buildFtsQuery(
          query,
          isPhraseSearch: true,
          isExactMatch: true,
        );

        // ASSERT - FTS5 phrase syntax with double quotes
        expect(result, equals('"අනාථ පිණ්ඩික"'));
      });

      test('phrase with prefix uses NEAR with distance 1', () {
        // ARRANGE
        const query = 'අනාථ පිණ්ඩික';

        // ACT
        final result = buildFtsQuery(
          query,
          isPhraseSearch: true,
          isExactMatch: false,
        );

        // ASSERT - FTS5 workaround: wildcards not supported in phrases
        // Use NEAR(word1* word2*, 1) to approximate phrase+prefix
        expect(result, equals('NEAR(අනාථ* පිණ්ඩික*, 1)'));
      });

      test('three word phrase with prefix', () {
        // ARRANGE
        const query = 'word1 word2 word3';

        // ACT
        final result = buildFtsQuery(
          query,
          isPhraseSearch: true,
          isExactMatch: false,
        );

        // ASSERT
        expect(result, equals('NEAR(word1* word2* word3*, 1)'));
      });
    });

    group('Separate-word search with anywhere in text -', () {
      test('exact tokens uses implicit AND', () {
        // ARRANGE
        const query = 'word1 word2';

        // ACT
        final result = buildFtsQuery(
          query,
          isPhraseSearch: false,
          isAnywhereInText: true,
          isExactMatch: true,
        );

        // ASSERT - space-separated = AND query in FTS5
        expect(result, equals('word1 word2'));
      });

      test('prefix tokens uses implicit AND with wildcards', () {
        // ARRANGE
        const query = 'word1 word2';

        // ACT
        final result = buildFtsQuery(
          query,
          isPhraseSearch: false,
          isAnywhereInText: true,
          isExactMatch: false,
        );

        // ASSERT - both words must exist with prefix matching
        expect(result, equals('word1* word2*'));
      });
    });

    group('Proximity search (isPhraseSearch=false, isAnywhereInText=false) -', () {
      test('exact tokens with default proximity distance', () {
        // ARRANGE
        const query = 'word1 word2';

        // ACT
        final result = buildFtsQuery(
          query,
          isPhraseSearch: false,
          isAnywhereInText: false,
          isExactMatch: true,
          proximityDistance: 10,
        );

        // ASSERT - NEAR with specified distance
        expect(result, equals('NEAR(word1 word2, 10)'));
      });

      test('prefix tokens with proximity distance', () {
        // ARRANGE
        const query = 'word1 word2';

        // ACT
        final result = buildFtsQuery(
          query,
          isPhraseSearch: false,
          isAnywhereInText: false,
          isExactMatch: false,
          proximityDistance: 10,
        );

        // ASSERT - NEAR with wildcards
        expect(result, equals('NEAR(word1* word2*, 10)'));
      });

      test('custom proximity distance is respected', () {
        // ARRANGE
        const query = 'word1 word2';

        // ACT
        final result = buildFtsQuery(
          query,
          isPhraseSearch: false,
          isAnywhereInText: false,
          isExactMatch: true,
          proximityDistance: 50,
        );

        // ASSERT - custom distance of 50
        expect(result, equals('NEAR(word1 word2, 50)'));
      });

      test('minimum proximity distance (1)', () {
        // ARRANGE
        const query = 'word1 word2';

        // ACT
        final result = buildFtsQuery(
          query,
          isPhraseSearch: false,
          isAnywhereInText: false,
          isExactMatch: true,
          proximityDistance: 1,
        );

        // ASSERT
        expect(result, equals('NEAR(word1 word2, 1)'));
      });

      test('maximum proximity distance (100)', () {
        // ARRANGE
        const query = 'word1 word2';

        // ACT
        final result = buildFtsQuery(
          query,
          isPhraseSearch: false,
          isAnywhereInText: false,
          isExactMatch: true,
          proximityDistance: 100,
        );

        // ASSERT
        expect(result, equals('NEAR(word1 word2, 100)'));
      });
    });

    group('Edge cases -', () {
      test('empty query returns empty quoted string', () {
        // ACT
        final result = buildFtsQuery('');

        // ASSERT - empty string is valid FTS query
        expect(result, equals('""'));
      });

      test('query with extra spaces between words is handled', () {
        // ARRANGE - extra spaces should be normalized
        const query = 'word1  word2';

        // ACT
        final result = buildFtsQuery(
          query,
          isPhraseSearch: true,
          isExactMatch: true,
        );

        // ASSERT - split + filter removes empty strings
        expect(result, equals('"word1 word2"'));
      });

      test('query with leading/trailing spaces is handled', () {
        // ARRANGE
        const query = '  word1 word2  ';

        // ACT
        final result = buildFtsQuery(
          query,
          isPhraseSearch: true,
          isExactMatch: true,
        );

        // ASSERT - split + filter handles whitespace
        expect(result, equals('"word1 word2"'));
      });

      test('single word treated as single even when phrase mode enabled', () {
        // ARRANGE
        const query = 'singleword';

        // ACT
        final result = buildFtsQuery(
          query,
          isPhraseSearch: true,
          isExactMatch: false,
        );

        // ASSERT - single word bypasses phrase logic
        expect(result, equals('singleword*'));
      });
    });

    group('All 6 search mode combinations -', () {
      // Comprehensive test covering the table from the implementation
      const twoWords = 'term1 term2';

      test('phrase + exact → "term1 term2"', () {
        final result = buildFtsQuery(
          twoWords,
          isPhraseSearch: true,
          isExactMatch: true,
        );
        expect(result, equals('"term1 term2"'));
      });

      test('phrase + prefix → NEAR(term1* term2*, 1)', () {
        final result = buildFtsQuery(
          twoWords,
          isPhraseSearch: true,
          isExactMatch: false,
        );
        expect(result, equals('NEAR(term1* term2*, 1)'));
      });

      test('separate + anywhere + exact → term1 term2', () {
        final result = buildFtsQuery(
          twoWords,
          isPhraseSearch: false,
          isAnywhereInText: true,
          isExactMatch: true,
        );
        expect(result, equals('term1 term2'));
      });

      test('separate + anywhere + prefix → term1* term2*', () {
        final result = buildFtsQuery(
          twoWords,
          isPhraseSearch: false,
          isAnywhereInText: true,
          isExactMatch: false,
        );
        expect(result, equals('term1* term2*'));
      });

      test('separate + proximity + exact → NEAR(term1 term2, n)', () {
        final result = buildFtsQuery(
          twoWords,
          isPhraseSearch: false,
          isAnywhereInText: false,
          isExactMatch: true,
          proximityDistance: 10,
        );
        expect(result, equals('NEAR(term1 term2, 10)'));
      });

      test('separate + proximity + prefix → NEAR(term1* term2*, n)', () {
        final result = buildFtsQuery(
          twoWords,
          isPhraseSearch: false,
          isAnywhereInText: false,
          isExactMatch: false,
          proximityDistance: 10,
        );
        expect(result, equals('NEAR(term1* term2*, 10)'));
      });
    });
  });
}
