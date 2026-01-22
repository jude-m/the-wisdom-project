import 'package:flutter_test/flutter_test.dart';
import 'package:the_wisdom_project/domain/entities/search/grouped_fts_match.dart';
import 'package:the_wisdom_project/domain/entities/search/search_result.dart';
import 'package:the_wisdom_project/domain/entities/search/search_result_type.dart';

void main() {
  group('GroupedFTSMatch -', () {
    // Helper to create SearchResult for testing
    SearchResult createSearchResult({
      required String nodeKey,
      required int pageIndex,
      required int entryIndex,
      String contentFileId = 'dn-1',
      String id = 'test-id',
      String editionId = 'bjt',
      String title = 'Test Title',
      String subtitle = 'Test Subtitle',
      String matchedText = 'matched text',
      String language = 'pali',
      double? relevanceScore,
    }) {
      return SearchResult(
        id: '$id-$nodeKey-$pageIndex-$entryIndex',
        editionId: editionId,
        resultType: SearchResultType.fullText,
        title: title,
        subtitle: subtitle,
        matchedText: matchedText,
        contentFileId: contentFileId,
        pageIndex: pageIndex,
        entryIndex: entryIndex,
        nodeKey: nodeKey,
        language: language,
        relevanceScore: relevanceScore,
      );
    }

    group('fromSearchResults -', () {
      group('Empty and single result handling -', () {
        test('returns empty list for empty input', () {
          // ACT
          final result = GroupedFTSMatch.fromSearchResults([]);

          // ASSERT
          expect(result, isEmpty);
        });

        test('single result creates group with no secondary matches', () {
          // ARRANGE
          final results = [
            createSearchResult(nodeKey: 'dn-1', pageIndex: 0, entryIndex: 0),
          ];

          // ACT
          final grouped = GroupedFTSMatch.fromSearchResults(results);

          // ASSERT
          expect(grouped, hasLength(1));
          expect(grouped[0].primaryMatch.nodeKey, equals('dn-1'));
          expect(grouped[0].secondaryMatches, isEmpty);
          expect(grouped[0].hasSecondaryMatches, isFalse);
        });
      });

      group('Grouping by nodeKey -', () {
        test('results with same nodeKey are grouped together', () {
          // ARRANGE - 3 results from same sutta
          final results = [
            createSearchResult(nodeKey: 'dn-1', pageIndex: 0, entryIndex: 0),
            createSearchResult(nodeKey: 'dn-1', pageIndex: 1, entryIndex: 0),
            createSearchResult(nodeKey: 'dn-1', pageIndex: 2, entryIndex: 0),
          ];

          // ACT
          final grouped = GroupedFTSMatch.fromSearchResults(results);

          // ASSERT - all 3 in one group
          expect(grouped, hasLength(1));
          expect(grouped[0].allMatches, hasLength(3));
          expect(grouped[0].secondaryMatchCount, equals(2));
        });

        test('results with different nodeKeys create separate groups', () {
          // ARRANGE - 3 results from different suttas
          final results = [
            createSearchResult(nodeKey: 'dn-1', pageIndex: 0, entryIndex: 0),
            createSearchResult(nodeKey: 'dn-2', pageIndex: 0, entryIndex: 0),
            createSearchResult(nodeKey: 'mn-1', pageIndex: 0, entryIndex: 0),
          ];

          // ACT
          final grouped = GroupedFTSMatch.fromSearchResults(results);

          // ASSERT - 3 separate groups
          expect(grouped, hasLength(3));
          expect(grouped.every((g) => g.secondaryMatches.isEmpty), isTrue);
        });

        test('mixed results group correctly', () {
          // ARRANGE - 2 from dn-1, 1 from dn-2, 2 from mn-1
          final results = [
            createSearchResult(nodeKey: 'dn-1', pageIndex: 0, entryIndex: 0),
            createSearchResult(nodeKey: 'dn-2', pageIndex: 0, entryIndex: 0),
            createSearchResult(nodeKey: 'dn-1', pageIndex: 1, entryIndex: 0),
            createSearchResult(nodeKey: 'mn-1', pageIndex: 0, entryIndex: 0),
            createSearchResult(nodeKey: 'mn-1', pageIndex: 0, entryIndex: 1),
          ];

          // ACT
          final grouped = GroupedFTSMatch.fromSearchResults(results);

          // ASSERT - 3 groups
          expect(grouped, hasLength(3));

          final dn1Group = grouped.firstWhere((g) => g.nodeKey == 'dn-1');
          final dn2Group = grouped.firstWhere((g) => g.nodeKey == 'dn-2');
          final mn1Group = grouped.firstWhere((g) => g.nodeKey == 'mn-1');

          expect(dn1Group.allMatches, hasLength(2));
          expect(dn2Group.allMatches, hasLength(1));
          expect(mn1Group.allMatches, hasLength(2));
        });
      });

      group('Primary/secondary match selection -', () {
        test('first match by page order becomes primary', () {
          // ARRANGE - results NOT in page order
          final results = [
            createSearchResult(nodeKey: 'dn-1', pageIndex: 2, entryIndex: 0),
            createSearchResult(nodeKey: 'dn-1', pageIndex: 0, entryIndex: 0),
            createSearchResult(nodeKey: 'dn-1', pageIndex: 1, entryIndex: 0),
          ];

          // ACT
          final grouped = GroupedFTSMatch.fromSearchResults(results);

          // ASSERT - page 0 becomes primary after sorting
          expect(grouped[0].primaryMatch.pageIndex, equals(0));
        });

        test('entry order breaks tie when page is same', () {
          // ARRANGE - same page, different entries
          final results = [
            createSearchResult(nodeKey: 'dn-1', pageIndex: 0, entryIndex: 5),
            createSearchResult(nodeKey: 'dn-1', pageIndex: 0, entryIndex: 1),
            createSearchResult(nodeKey: 'dn-1', pageIndex: 0, entryIndex: 3),
          ];

          // ACT
          final grouped = GroupedFTSMatch.fromSearchResults(results);

          // ASSERT - entry 1 becomes primary (lowest entry index)
          expect(grouped[0].primaryMatch.entryIndex, equals(1));
          expect(grouped[0].secondaryMatches[0].entryIndex, equals(3));
          expect(grouped[0].secondaryMatches[1].entryIndex, equals(5));
        });
      });

      group('Sorting within groups -', () {
        test('secondary matches are sorted by pageIndex then entryIndex', () {
          // ARRANGE - unsorted results
          final results = [
            createSearchResult(nodeKey: 'dn-1', pageIndex: 3, entryIndex: 0),
            createSearchResult(nodeKey: 'dn-1', pageIndex: 1, entryIndex: 2),
            createSearchResult(nodeKey: 'dn-1', pageIndex: 1, entryIndex: 0),
            createSearchResult(nodeKey: 'dn-1', pageIndex: 0, entryIndex: 0),
            createSearchResult(nodeKey: 'dn-1', pageIndex: 2, entryIndex: 1),
          ];

          // ACT
          final grouped = GroupedFTSMatch.fromSearchResults(results);

          // ASSERT - sorted order: (0,0), (1,0), (1,2), (2,1), (3,0)
          final allMatches = grouped[0].allMatches;
          expect(allMatches[0].pageIndex, equals(0));
          expect(allMatches[1].pageIndex, equals(1));
          expect(allMatches[1].entryIndex, equals(0));
          expect(allMatches[2].pageIndex, equals(1));
          expect(allMatches[2].entryIndex, equals(2));
          expect(allMatches[3].pageIndex, equals(2));
          expect(allMatches[4].pageIndex, equals(3));
        });
      });

      group('Edge cases for indices -', () {
        test('zero indices are handled correctly', () {
          // ARRANGE
          final results = [
            createSearchResult(nodeKey: 'dn-1', pageIndex: 0, entryIndex: 0),
          ];

          // ACT
          final grouped = GroupedFTSMatch.fromSearchResults(results);

          // ASSERT
          expect(grouped[0].primaryMatch.pageIndex, equals(0));
          expect(grouped[0].primaryMatch.entryIndex, equals(0));
        });

        test('large indices are handled correctly', () {
          // ARRANGE
          final results = [
            createSearchResult(nodeKey: 'dn-1', pageIndex: 999, entryIndex: 999),
            createSearchResult(nodeKey: 'dn-1', pageIndex: 0, entryIndex: 0),
          ];

          // ACT
          final grouped = GroupedFTSMatch.fromSearchResults(results);

          // ASSERT - (0,0) is primary, (999,999) is secondary
          expect(grouped[0].primaryMatch.pageIndex, equals(0));
          expect(grouped[0].secondaryMatches[0].pageIndex, equals(999));
        });

        test('negative indices sort before positive (if they occur)', () {
          // ARRANGE - this tests sorting behavior with invalid data
          // In production, negative indices should not occur, but if they do,
          // the sort should still work predictably
          final results = [
            createSearchResult(nodeKey: 'dn-1', pageIndex: 1, entryIndex: 0),
            createSearchResult(nodeKey: 'dn-1', pageIndex: -1, entryIndex: 0),
            createSearchResult(nodeKey: 'dn-1', pageIndex: 0, entryIndex: 0),
          ];

          // ACT
          final grouped = GroupedFTSMatch.fromSearchResults(results);

          // ASSERT - -1 sorts first (this is a defensive test)
          expect(grouped[0].primaryMatch.pageIndex, equals(-1));
          expect(grouped[0].allMatches.map((m) => m.pageIndex).toList(),
              equals([-1, 0, 1]));
        });
      });

      group('Metadata preservation -', () {
        test('group preserves metadata from primary match', () {
          // ARRANGE
          final results = [
            createSearchResult(
              nodeKey: 'dn-1',
              pageIndex: 0,
              entryIndex: 0,
              contentFileId: 'dn-1-file',
              title: 'Brahmajāla Sutta',
              subtitle: 'Dīgha Nikāya',
              editionId: 'bjt',
            ),
            createSearchResult(
              nodeKey: 'dn-1',
              pageIndex: 1,
              entryIndex: 0,
              contentFileId: 'dn-1-file',
              title: 'Brahmajāla Sutta',
              subtitle: 'Dīgha Nikāya',
              editionId: 'bjt',
            ),
          ];

          // ACT
          final grouped = GroupedFTSMatch.fromSearchResults(results);

          // ASSERT - group metadata comes from primary match
          expect(grouped[0].contentFileId, equals('dn-1-file'));
          expect(grouped[0].title, equals('Brahmajāla Sutta'));
          expect(grouped[0].subtitle, equals('Dīgha Nikāya'));
          expect(grouped[0].editionId, equals('bjt'));
          expect(grouped[0].nodeKey, equals('dn-1'));
        });
      });
    });

    group('Computed properties -', () {
      test('hasSecondaryMatches returns true when there are secondary matches', () {
        // ARRANGE
        final results = [
          createSearchResult(nodeKey: 'dn-1', pageIndex: 0, entryIndex: 0),
          createSearchResult(nodeKey: 'dn-1', pageIndex: 1, entryIndex: 0),
        ];

        // ACT
        final grouped = GroupedFTSMatch.fromSearchResults(results);

        // ASSERT
        expect(grouped[0].hasSecondaryMatches, isTrue);
      });

      test('hasSecondaryMatches returns false when no secondary matches', () {
        // ARRANGE
        final results = [
          createSearchResult(nodeKey: 'dn-1', pageIndex: 0, entryIndex: 0),
        ];

        // ACT
        final grouped = GroupedFTSMatch.fromSearchResults(results);

        // ASSERT
        expect(grouped[0].hasSecondaryMatches, isFalse);
      });

      test('secondaryMatchCount returns correct count', () {
        // ARRANGE
        final results = [
          createSearchResult(nodeKey: 'dn-1', pageIndex: 0, entryIndex: 0),
          createSearchResult(nodeKey: 'dn-1', pageIndex: 1, entryIndex: 0),
          createSearchResult(nodeKey: 'dn-1', pageIndex: 2, entryIndex: 0),
          createSearchResult(nodeKey: 'dn-1', pageIndex: 3, entryIndex: 0),
        ];

        // ACT
        final grouped = GroupedFTSMatch.fromSearchResults(results);

        // ASSERT - 1 primary + 3 secondary
        expect(grouped[0].secondaryMatchCount, equals(3));
      });

      test('allMatches returns primary + secondary in order', () {
        // ARRANGE
        final results = [
          createSearchResult(nodeKey: 'dn-1', pageIndex: 2, entryIndex: 0),
          createSearchResult(nodeKey: 'dn-1', pageIndex: 0, entryIndex: 0),
          createSearchResult(nodeKey: 'dn-1', pageIndex: 1, entryIndex: 0),
        ];

        // ACT
        final grouped = GroupedFTSMatch.fromSearchResults(results);

        // ASSERT
        final allMatches = grouped[0].allMatches;
        expect(allMatches, hasLength(3));
        expect(allMatches[0], equals(grouped[0].primaryMatch));
        expect(allMatches.sublist(1), equals(grouped[0].secondaryMatches));
      });
    });
  });
}
