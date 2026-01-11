import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:the_wisdom_project/core/constants/constants.dart';
import 'package:the_wisdom_project/data/repositories/text_search_repository_impl.dart';
import 'package:the_wisdom_project/domain/entities/failure.dart';
import 'package:the_wisdom_project/domain/entities/search/search_result_type.dart';
import 'package:the_wisdom_project/domain/entities/search/search_query.dart';
import 'package:the_wisdom_project/data/datasources/fts_datasource.dart';
import 'package:the_wisdom_project/domain/entities/navigation/tipitaka_tree_node.dart';

import '../../helpers/mocks.mocks.dart';

void main() {
  late TextSearchRepositoryImpl repository;
  late MockFTSDataSource mockFTSDataSource;
  late MockNavigationTreeRepository mockTreeRepository;

  setUp(() {
    mockFTSDataSource = MockFTSDataSource();
    mockTreeRepository = MockNavigationTreeRepository();
    repository = TextSearchRepositoryImpl(
      mockFTSDataSource,
      mockTreeRepository,
    );
  });

  group('TextSearchRepositoryImpl -', () {
    group('getSuggestions', () {
      final sampleSuggestions = [
        FTSSuggestion(word: 'dhamma', language: 'pali', frequency: 100),
        FTSSuggestion(word: 'dhammapada', language: 'pali', frequency: 50),
      ];

      test('should return suggestions from FTS data source', () async {
        // ARRANGE
        when(mockFTSDataSource.getSuggestions(
          any,
          editionIds: anyNamed('editionIds'),
          language: anyNamed('language'),
          limit: anyNamed('limit'),
        )).thenAnswer((_) async => sampleSuggestions);

        // ACT
        final result = await repository.getSuggestions('dham');

        // ASSERT
        expect(result.isRight(), true);

        result.fold(
          (failure) => fail('Expected success but got failure'),
          (words) {
            expect(words.length, equals(2));
            expect(words[0], equals('dhamma'));
            expect(words[1], equals('dhammapada'));
          },
        );

        verify(mockFTSDataSource.getSuggestions(
          'dham',
          editionIds: {'bjt'},
          language: null,
          limit: 10,
        )).called(1);
      });

      test('should filter suggestions by language', () async {
        // ARRANGE
        when(mockFTSDataSource.getSuggestions(
          any,
          editionIds: anyNamed('editionIds'),
          language: anyNamed('language'),
          limit: anyNamed('limit'),
        )).thenAnswer((_) async => sampleSuggestions);

        // ACT
        final result =
            await repository.getSuggestions('dham', language: 'pali');

        // ASSERT
        expect(result.isRight(), true);

        verify(mockFTSDataSource.getSuggestions(
          'dham',
          editionIds: {'bjt'},
          language: 'pali',
          limit: 10,
        )).called(1);
      });

      test('should return failure when suggestions fetch throws', () async {
        // ARRANGE
        when(mockFTSDataSource.getSuggestions(
          any,
          editionIds: anyNamed('editionIds'),
          language: anyNamed('language'),
          limit: anyNamed('limit'),
        )).thenThrow(Exception('Database error'));

        // ACT
        final result = await repository.getSuggestions('dham');

        // ASSERT
        expect(result.isLeft(), true);

        result.fold(
          (failure) {
            expect(failure, isA<DataLoadFailure>());
            expect(failure.userMessage, contains('Failed to get suggestions'));
          },
          (words) => fail('Expected failure but got success'),
        );
      });
    });

    group('searchTopResults', () {
      final sampleTree = [
        const TipitakaTreeNode(
          nodeKey: TipitakaNodeKeys.dighaNikaya,
          paliName: 'Dīgha Nikāya',
          sinhalaName: 'දීඝනිකාය',
          hierarchyLevel: 0,
          entryPageIndex: 0,
          entryIndexInPage: 0,
          parentNodeKey: null,
          childNodes: [
            TipitakaTreeNode(
              nodeKey: 'dn-1',
              paliName: 'Brahmajālasutta',
              sinhalaName: 'බ්‍රහ්මජාලසූත්‍රය',
              hierarchyLevel: 2,
              entryPageIndex: 0,
              entryIndexInPage: 0,
              parentNodeKey: TipitakaNodeKeys.dighaNikaya,
              contentFileId: 'dn-1',
            ),
            TipitakaTreeNode(
              nodeKey: 'dn-2',
              paliName: 'Sāmaññaphalasutta',
              sinhalaName: 'සාමඤ්ඤඵලසූත්‍රය',
              hierarchyLevel: 2,
              entryPageIndex: 0,
              entryIndexInPage: 0,
              parentNodeKey: TipitakaNodeKeys.dighaNikaya,
              contentFileId: 'dn-2',
            ),
          ],
        ),
      ];

      test('should return categorized results with title matches', () async {
        // ARRANGE - 'brahma' matches 'Brahmajālasutta' in Pali (case-insensitive)
        const query = SearchQuery(queryText: 'brahma');

        when(mockTreeRepository.loadNavigationTree())
            .thenAnswer((_) async => Right(sampleTree));

        when(mockFTSDataSource.searchFullText(
          any,
          editionIds: anyNamed('editionIds'),
          language: anyNamed('language'),
          scope: anyNamed('scope'),
          isExactMatch: anyNamed('isExactMatch'),
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        )).thenAnswer((_) async => []);

        // ACT
        final result = await repository.searchTopResults(query);

        // ASSERT
        expect(result.isRight(), true);

        result.fold(
          (failure) => fail('Expected success but got failure'),
          (categorized) {
            expect(
                categorized.resultsByType.containsKey(SearchResultType.title),
                true);
            expect(
                categorized.resultsByType
                    .containsKey(SearchResultType.fullText),
                true);
            expect(
                categorized.resultsByType
                    .containsKey(SearchResultType.definition),
                true);

            final titleResults =
                categorized.resultsByType[SearchResultType.title]!;
            expect(titleResults.length, equals(1));
            // 'brahma' matches Pali name 'Brahmajālasutta' directly
            expect(titleResults[0].title, equals('Brahmajālasutta'));
            expect(titleResults[0].resultType, equals(SearchResultType.title));
            expect(titleResults[0].language, equals('pali'));
          },
        );
      });

      test('should limit results per category by maxPerCategory', () async {
        // ARRANGE
        const query = SearchQuery(queryText: 'sutta');

        // Add more suttas to tree for testing limit
        final largeTree = [
          const TipitakaTreeNode(
            nodeKey: TipitakaNodeKeys.dighaNikaya,
            paliName: 'Dīgha Nikāya',
            sinhalaName: 'දීඝනිකාය',
            hierarchyLevel: 0,
            entryPageIndex: 0,
            entryIndexInPage: 0,
            parentNodeKey: null,
            childNodes: [
              TipitakaTreeNode(
                nodeKey: 'dn-1',
                paliName: 'Brahmajālasutta',
                sinhalaName: 'බ්‍රහ්මජාලසූත්‍රය',
                hierarchyLevel: 2,
                entryPageIndex: 0,
                entryIndexInPage: 0,
                parentNodeKey: TipitakaNodeKeys.dighaNikaya,
                contentFileId: 'dn-1',
              ),
              TipitakaTreeNode(
                nodeKey: 'dn-2',
                paliName: 'Sāmaññaphalasutta',
                sinhalaName: 'සාමඤ්ඤඵලසූත්‍රය',
                hierarchyLevel: 2,
                entryPageIndex: 0,
                entryIndexInPage: 0,
                parentNodeKey: TipitakaNodeKeys.dighaNikaya,
                contentFileId: 'dn-2',
              ),
              TipitakaTreeNode(
                nodeKey: 'dn-3',
                paliName: 'Ambaṭṭhasutta',
                sinhalaName: 'අම්බට්ඨසූත්‍රය',
                hierarchyLevel: 2,
                entryPageIndex: 0,
                entryIndexInPage: 0,
                parentNodeKey: TipitakaNodeKeys.dighaNikaya,
                contentFileId: 'dn-3',
              ),
              TipitakaTreeNode(
                nodeKey: 'dn-4',
                paliName: 'Soṇadaṇḍasutta',
                sinhalaName: 'සොණදණ්ඩසූත්‍රය',
                hierarchyLevel: 2,
                entryPageIndex: 0,
                entryIndexInPage: 0,
                parentNodeKey: TipitakaNodeKeys.dighaNikaya,
                contentFileId: 'dn-4',
              ),
            ],
          ),
        ];

        when(mockTreeRepository.loadNavigationTree())
            .thenAnswer((_) async => Right(largeTree));

        when(mockFTSDataSource.searchFullText(
          any,
          editionIds: anyNamed('editionIds'),
          language: anyNamed('language'),
          scope: anyNamed('scope'),
          isExactMatch: anyNamed('isExactMatch'),
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        )).thenAnswer((_) async => []);

        // ACT
        final result =
            await repository.searchTopResults(query, maxPerCategory: 2);

        // ASSERT
        expect(result.isRight(), true);

        result.fold(
          (failure) => fail('Expected success but got failure'),
          (categorized) {
            final titleResults =
                categorized.resultsByType[SearchResultType.title]!;
            // Should be limited to 2 even though 4 suttas match "sutta"
            expect(titleResults.length, lessThanOrEqualTo(2));
          },
        );
      });

      test('should include content results from FTS', () async {
        // ARRANGE
        const query = SearchQuery(queryText: 'dhamma');

        final ftsMatches = [
          FTSMatch(
            editionId: 'bjt',
            rowid: 1,
            filename: 'dn-1',
            eind: '0-5',
            language: 'pali',
            type: 'paragraph',
            level: 0,
          ),
        ];

        when(mockTreeRepository.loadNavigationTree())
            .thenAnswer((_) async => Right(sampleTree));

        when(mockFTSDataSource.searchFullText(
          any,
          editionIds: anyNamed('editionIds'),
          language: anyNamed('language'),
          scope: anyNamed('scope'),
          isExactMatch: anyNamed('isExactMatch'),
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        )).thenAnswer((_) async => ftsMatches);

        // ACT
        final result = await repository.searchTopResults(query);

        // ASSERT
        expect(result.isRight(), true);

        result.fold(
          (failure) => fail('Expected success but got failure'),
          (categorized) {
            final contentResults =
                categorized.resultsByType[SearchResultType.fullText]!;
            expect(contentResults.length, equals(1));
            expect(contentResults[0].resultType,
                equals(SearchResultType.fullText));
            expect(contentResults[0].contentFileId, equals('dn-1'));
          },
        );
      });

      test(
          'should pass isExactMatch=true to FTS when query has isExactMatch enabled',
          () async {
        // ARRANGE
        const query = SearchQuery(queryText: 'dhamma', isExactMatch: true);

        when(mockTreeRepository.loadNavigationTree())
            .thenAnswer((_) async => Right(sampleTree));

        when(mockFTSDataSource.searchFullText(
          any,
          editionIds: anyNamed('editionIds'),
          language: anyNamed('language'),
          scope: anyNamed('scope'),
          isExactMatch: anyNamed('isExactMatch'),
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        )).thenAnswer((_) async => []);

        // ACT
        await repository.searchTopResults(query);

        // ASSERT - Verify isExactMatch was passed to FTS datasource
        verify(mockFTSDataSource.searchFullText(
          any,
          editionIds: anyNamed('editionIds'),
          language: anyNamed('language'),
          scope: anyNamed('scope'),
          isExactMatch: true, // Should pass isExactMatch from query
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        )).called(1);
      });

      test('should pass isExactMatch=false to FTS by default', () async {
        // ARRANGE
        const query =
            SearchQuery(queryText: 'dhamma'); // isExactMatch defaults to false

        when(mockTreeRepository.loadNavigationTree())
            .thenAnswer((_) async => Right(sampleTree));

        when(mockFTSDataSource.searchFullText(
          any,
          editionIds: anyNamed('editionIds'),
          language: anyNamed('language'),
          scope: anyNamed('scope'),
          isExactMatch: anyNamed('isExactMatch'),
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        )).thenAnswer((_) async => []);

        // ACT
        await repository.searchTopResults(query);

        // ASSERT - Verify isExactMatch defaults to false
        verify(mockFTSDataSource.searchFullText(
          any,
          editionIds: anyNamed('editionIds'),
          language: anyNamed('language'),
          scope: anyNamed('scope'),
          isExactMatch: false, // Default value
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        )).called(1);
      });

      test('should return failure when tree loading fails', () async {
        // ARRANGE
        const query = SearchQuery(queryText: 'dhamma');

        when(mockTreeRepository.loadNavigationTree()).thenAnswer(
          (_) async => const Left(
            Failure.dataLoadFailure(message: 'Failed to load tree'),
          ),
        );

        // ACT
        final result = await repository.searchTopResults(query);

        // ASSERT
        expect(result.isLeft(), true);

        result.fold(
          (failure) {
            expect(failure, isA<DataLoadFailure>());
          },
          (results) => fail('Expected failure but got success'),
        );
      });

      test('should return failure when FTS throws', () async {
        // ARRANGE
        const query = SearchQuery(queryText: 'dhamma');

        when(mockTreeRepository.loadNavigationTree())
            .thenAnswer((_) async => Right(sampleTree));

        when(mockFTSDataSource.searchFullText(
          any,
          editionIds: anyNamed('editionIds'),
          language: anyNamed('language'),
          scope: anyNamed('scope'),
          isExactMatch: anyNamed('isExactMatch'),
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        )).thenThrow(Exception('Database error'));

        // ACT
        final result = await repository.searchTopResults(query);

        // ASSERT
        expect(result.isLeft(), true);

        result.fold(
          (failure) {
            expect(failure, isA<DataLoadFailure>());
            expect(failure.userMessage,
                contains('Failed to perform categorized search'));
          },
          (results) => fail('Expected failure but got success'),
        );
      });

      test('should return empty definition category (placeholder)', () async {
        // ARRANGE
        const query = SearchQuery(queryText: 'test');

        when(mockTreeRepository.loadNavigationTree())
            .thenAnswer((_) async => Right(sampleTree));

        when(mockFTSDataSource.searchFullText(
          any,
          editionIds: anyNamed('editionIds'),
          language: anyNamed('language'),
          scope: anyNamed('scope'),
          isExactMatch: anyNamed('isExactMatch'),
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        )).thenAnswer((_) async => []);

        // ACT
        final result = await repository.searchTopResults(query);

        // ASSERT
        expect(result.isRight(), true);

        result.fold(
          (failure) => fail('Expected success but got failure'),
          (categorized) {
            final definitionResults =
                categorized.resultsByType[SearchResultType.definition]!;
            expect(definitionResults, isEmpty);
          },
        );
      });

      test('should normalize query by removing zero-width characters',
          () async {
        // ARRANGE - Query with Zero-Width Joiner (common in Sinhala input)
        const queryWithZWJ =
            SearchQuery(queryText: 'සති\u200Dය'); // Contains ZWJ

        final treeWithSatiMatch = [
          const TipitakaTreeNode(
            nodeKey: 'sati-1',
            paliName: 'Satipaṭṭhānasutta',
            sinhalaName: 'සතිය', // No ZWJ - should still match
            hierarchyLevel: 2,
            entryPageIndex: 0,
            entryIndexInPage: 0,
            parentNodeKey: null,
            contentFileId: 'sati-1',
          ),
        ];

        when(mockTreeRepository.loadNavigationTree())
            .thenAnswer((_) async => Right(treeWithSatiMatch));

        when(mockFTSDataSource.searchFullText(
          any,
          editionIds: anyNamed('editionIds'),
          language: anyNamed('language'),
          scope: anyNamed('scope'),
          isExactMatch: anyNamed('isExactMatch'),
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        )).thenAnswer((_) async => []);

        // ACT
        final result = await repository.searchTopResults(queryWithZWJ);

        // ASSERT
        expect(result.isRight(), true);

        result.fold(
          (failure) => fail('Expected success but got failure'),
          (categorized) {
            final titleResults =
                categorized.resultsByType[SearchResultType.title]!;
            expect(titleResults.length, equals(1));
            expect(titleResults[0].title, equals('සතිය'));
          },
        );
      });

      test('should return sinhala name when only sinhala matches query',
          () async {
        // ARRANGE
        const query = SearchQuery(queryText: 'සතිපට්ඨාන');

        final treeWithSinhalaMatch = [
          const TipitakaTreeNode(
            nodeKey: 'sati-1',
            paliName: 'Satipaṭṭhānasutta', // Pali - does NOT contain query
            sinhalaName: 'සතිපට්ඨානසූත්‍රය', // Sinhala - DOES contain query
            hierarchyLevel: 2,
            entryPageIndex: 0,
            entryIndexInPage: 0,
            parentNodeKey: null,
            contentFileId: 'sati-1',
          ),
        ];

        when(mockTreeRepository.loadNavigationTree())
            .thenAnswer((_) async => Right(treeWithSinhalaMatch));

        when(mockFTSDataSource.searchFullText(
          any,
          editionIds: anyNamed('editionIds'),
          language: anyNamed('language'),
          scope: anyNamed('scope'),
          isExactMatch: anyNamed('isExactMatch'),
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        )).thenAnswer((_) async => []);

        // ACT
        final result = await repository.searchTopResults(query);

        // ASSERT
        expect(result.isRight(), true);

        result.fold(
          (failure) => fail('Expected success but got failure'),
          (categorized) {
            final titleResults =
                categorized.resultsByType[SearchResultType.title]!;
            expect(titleResults.length, equals(1));
            // Should show Sinhala name since that matched
            expect(titleResults[0].title, equals('සතිපට්ඨානසූත්‍රය'));
            expect(titleResults[0].language, equals('sinhala'));
          },
        );
      });

      test('should return pali name when only pali matches query', () async {
        // ARRANGE - Use a Sinhala query that matches only the Pali name
        // Real data has both names in Sinhala script
        const query = SearchQuery(queryText: 'විනයපිටක');

        final treeWithPaliMatch = [
          const TipitakaTreeNode(
            nodeKey: 'pali-match-1',
            paliName: 'විනයපිටක', // Pali name - matches query
            sinhalaName: 'විනය පිටකය', // Sinhala name - does NOT match query
            hierarchyLevel: 1,
            entryPageIndex: 0,
            entryIndexInPage: 0,
            parentNodeKey: null,
            contentFileId: 'pali-match-1',
          ),
        ];

        when(mockTreeRepository.loadNavigationTree())
            .thenAnswer((_) async => Right(treeWithPaliMatch));

        when(mockFTSDataSource.searchFullText(
          any,
          editionIds: anyNamed('editionIds'),
          language: anyNamed('language'),
          scope: anyNamed('scope'),
          isExactMatch: anyNamed('isExactMatch'),
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        )).thenAnswer((_) async => []);

        // ACT
        final result = await repository.searchTopResults(query);

        // ASSERT
        expect(result.isRight(), true);

        result.fold(
          (failure) => fail('Expected success but got failure'),
          (categorized) {
            final titleResults =
                categorized.resultsByType[SearchResultType.title]!;
            expect(titleResults.length, equals(1));
            // Should show Pali name since only Pali matched
            expect(titleResults[0].title, equals('විනයපිටක'));
            expect(titleResults[0].language, equals('pali'));
          },
        );
      });

      test('should prefer sinhala name when both pali and sinhala match',
          () async {
        // ARRANGE - Use Sinhala query that matches both names directly
        const query = SearchQuery(queryText: 'සූත්‍ර');

        final treeWithBothMatch = [
          const TipitakaTreeNode(
            nodeKey: 'both-1',
            paliName: 'Suttaසූත්‍ර', // Contains the query
            sinhalaName: 'සූත්‍රය', // Also contains the query
            hierarchyLevel: 2,
            entryPageIndex: 0,
            entryIndexInPage: 0,
            parentNodeKey: null,
            contentFileId: 'both-1',
          ),
        ];

        when(mockTreeRepository.loadNavigationTree())
            .thenAnswer((_) async => Right(treeWithBothMatch));

        when(mockFTSDataSource.searchFullText(
          any,
          editionIds: anyNamed('editionIds'),
          language: anyNamed('language'),
          scope: anyNamed('scope'),
          isExactMatch: anyNamed('isExactMatch'),
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        )).thenAnswer((_) async => []);

        // ACT
        final result = await repository.searchTopResults(query);

        // ASSERT
        expect(result.isRight(), true);

        result.fold(
          (failure) => fail('Expected success but got failure'),
          (categorized) {
            final titleResults =
                categorized.resultsByType[SearchResultType.title]!;
            expect(titleResults.length, equals(1));
            // Should prefer Sinhala when both match
            expect(titleResults[0].title, equals('සූත්‍රය'));
            expect(titleResults[0].language, equals('sinhala'));
          },
        );
      });

      // ========================================================================
      // CONTAINS MATCHING TESTS (isExactMatch=false)
      // ========================================================================

      test(
          'should match query in middle of title with contains matching (isExactMatch=false)',
          () async {
        // ARRANGE - Query "jāla" should match "Brahmajālasutta" (middle position)
        const query = SearchQuery(queryText: 'jāla', isExactMatch: false);

        final treeWithMiddleMatch = [
          const TipitakaTreeNode(
            nodeKey: 'dn-1',
            paliName: 'Brahmajālasutta', // Contains "jāla" in the middle
            sinhalaName: 'බ්‍රහ්මජාලසූත්‍රය',
            hierarchyLevel: 2,
            entryPageIndex: 0,
            entryIndexInPage: 0,
            parentNodeKey: null,
            contentFileId: 'dn-1',
          ),
        ];

        when(mockTreeRepository.loadNavigationTree())
            .thenAnswer((_) async => Right(treeWithMiddleMatch));

        when(mockFTSDataSource.searchFullText(
          any,
          editionIds: anyNamed('editionIds'),
          language: anyNamed('language'),
          scope: anyNamed('scope'),
          isExactMatch: anyNamed('isExactMatch'),
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        )).thenAnswer((_) async => []);

        // ACT
        final result = await repository.searchTopResults(query);

        // ASSERT
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Expected success but got failure'),
          (categorized) {
            final titleResults =
                categorized.resultsByType[SearchResultType.title]!;
            expect(titleResults.length, equals(1));
            expect(titleResults[0].title, equals('Brahmajālasutta'));
          },
        );
      });

      test('should match with case insensitivity in contains mode', () async {
        // ARRANGE - Uppercase query should match lowercase/mixed case title
        const query = SearchQuery(queryText: 'JĀLA', isExactMatch: false);

        final treeWithCaseVariation = [
          const TipitakaTreeNode(
            nodeKey: 'dn-1',
            paliName: 'Brahmajālasutta', // Mixed case
            sinhalaName: 'බ්‍රහ්මජාලසූත්‍රය',
            hierarchyLevel: 2,
            entryPageIndex: 0,
            entryIndexInPage: 0,
            parentNodeKey: null,
            contentFileId: 'dn-1',
          ),
        ];

        when(mockTreeRepository.loadNavigationTree())
            .thenAnswer((_) async => Right(treeWithCaseVariation));

        when(mockFTSDataSource.searchFullText(
          any,
          editionIds: anyNamed('editionIds'),
          language: anyNamed('language'),
          scope: anyNamed('scope'),
          isExactMatch: anyNamed('isExactMatch'),
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        )).thenAnswer((_) async => []);

        // ACT
        final result = await repository.searchTopResults(query);

        // ASSERT
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Expected success but got failure'),
          (categorized) {
            final titleResults =
                categorized.resultsByType[SearchResultType.title]!;
            expect(titleResults.length, equals(1));
            expect(titleResults[0].title, equals('Brahmajālasutta'));
          },
        );
      });

      test('should match Sinhala substring with contains matching', () async {
        // ARRANGE - Sinhala query substring should match Sinhala title
        const query = SearchQuery(queryText: 'මජාල', isExactMatch: false);

        final treeWithSinhalaSubstring = [
          const TipitakaTreeNode(
            nodeKey: 'dn-1',
            paliName: 'Brahmajālasutta',
            sinhalaName: 'බ්‍රහ්මජාලසූත්‍රය', // Contains "මජාල"
            hierarchyLevel: 2,
            entryPageIndex: 0,
            entryIndexInPage: 0,
            parentNodeKey: null,
            contentFileId: 'dn-1',
          ),
        ];

        when(mockTreeRepository.loadNavigationTree())
            .thenAnswer((_) async => Right(treeWithSinhalaSubstring));

        when(mockFTSDataSource.searchFullText(
          any,
          editionIds: anyNamed('editionIds'),
          language: anyNamed('language'),
          scope: anyNamed('scope'),
          isExactMatch: anyNamed('isExactMatch'),
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        )).thenAnswer((_) async => []);

        // ACT
        final result = await repository.searchTopResults(query);

        // ASSERT
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Expected success but got failure'),
          (categorized) {
            final titleResults =
                categorized.resultsByType[SearchResultType.title]!;
            expect(titleResults.length, equals(1));
            expect(titleResults[0].title, equals('බ්‍රහ්මජාලසූත්‍රය'));
            expect(titleResults[0].language, equals('sinhala'));
          },
        );
      });

      // ========================================================================
      // WORD BOUNDARY MATCHING TESTS (isExactMatch=true)
      // ========================================================================

      test(
          'should match complete word only with word boundary (isExactMatch=true)',
          () async {
        // ARRANGE - Test all 4 boundary conditions
        const query = SearchQuery(queryText: 'Dhamma', isExactMatch: true);

        final treeWithWordBoundaries = [
          // Should match: exact match
          const TipitakaTreeNode(
            nodeKey: 'exact-1',
            paliName: 'Dhamma',
            sinhalaName: '',
            hierarchyLevel: 2,
            entryPageIndex: 0,
            entryIndexInPage: 0,
            parentNodeKey: null,
            contentFileId: 'exact-1',
          ),
          // Should match: word at start with space after
          const TipitakaTreeNode(
            nodeKey: 'start-1',
            paliName: 'Dhamma Sutta',
            sinhalaName: '',
            hierarchyLevel: 2,
            entryPageIndex: 0,
            entryIndexInPage: 0,
            parentNodeKey: null,
            contentFileId: 'start-1',
          ),
          // Should match: word at end with space before
          const TipitakaTreeNode(
            nodeKey: 'end-1',
            paliName: 'The Dhamma',
            sinhalaName: '',
            hierarchyLevel: 2,
            entryPageIndex: 0,
            entryIndexInPage: 0,
            parentNodeKey: null,
            contentFileId: 'end-1',
          ),
          // Should match: word in middle with spaces
          const TipitakaTreeNode(
            nodeKey: 'middle-1',
            paliName: 'Teaching Dhamma Today',
            sinhalaName: '',
            hierarchyLevel: 2,
            entryPageIndex: 0,
            entryIndexInPage: 0,
            parentNodeKey: null,
            contentFileId: 'middle-1',
          ),
          // Should NOT match: part of a larger word
          const TipitakaTreeNode(
            nodeKey: 'no-match-1',
            paliName: 'Dhammasutta',
            sinhalaName: '',
            hierarchyLevel: 2,
            entryPageIndex: 0,
            entryIndexInPage: 0,
            parentNodeKey: null,
            contentFileId: 'no-match-1',
          ),
        ];

        when(mockTreeRepository.loadNavigationTree())
            .thenAnswer((_) async => Right(treeWithWordBoundaries));

        when(mockFTSDataSource.searchFullText(
          any,
          editionIds: anyNamed('editionIds'),
          language: anyNamed('language'),
          scope: anyNamed('scope'),
          isExactMatch: anyNamed('isExactMatch'),
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        )).thenAnswer((_) async => []);

        // ACT
        final result = await repository.searchTopResults(query);

        // ASSERT
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Expected success but got failure'),
          (categorized) {
            final titleResults =
                categorized.resultsByType[SearchResultType.title]!;
            // Should match up to 3 (default maxPerCategory) word boundary matches
            // but NOT the compound word "Dhammasutta"
            expect(titleResults.length, equals(3));

            final titles = titleResults.map((r) => r.title).toList();
            // Verify compound word is NOT matched (key assertion)
            expect(titles, isNot(contains('Dhammasutta')));
            // Verify matches are from valid word boundary results
            for (final title in titles) {
              expect(
                [
                  'Dhamma',
                  'Dhamma Sutta',
                  'The Dhamma',
                  'Teaching Dhamma Today'
                ],
                contains(title),
              );
            }
          },
        );
      });

      test(
          'should respect word boundaries at all positions (isExactMatch=true)',
          () async {
        // ARRANGE - Test specific boundary scenarios
        const query = SearchQuery(queryText: 'sutta', isExactMatch: true);

        final treeWithBoundaryTests = [
          // Match: Exact word "sutta"
          const TipitakaTreeNode(
            nodeKey: 'b1',
            paliName: 'sutta',
            sinhalaName: '',
            hierarchyLevel: 2,
            entryPageIndex: 0,
            entryIndexInPage: 0,
            parentNodeKey: null,
            contentFileId: 'b1',
          ),
          // Match: "sutta " at beginning
          const TipitakaTreeNode(
            nodeKey: 'b2',
            paliName: 'sutta pitaka',
            sinhalaName: '',
            hierarchyLevel: 2,
            entryPageIndex: 0,
            entryIndexInPage: 0,
            parentNodeKey: null,
            contentFileId: 'b2',
          ),
          // Match: " sutta" at end
          const TipitakaTreeNode(
            nodeKey: 'b3',
            paliName: 'brahmajāla sutta',
            sinhalaName: '',
            hierarchyLevel: 2,
            entryPageIndex: 0,
            entryIndexInPage: 0,
            parentNodeKey: null,
            contentFileId: 'b3',
          ),
          // Match: " sutta " in middle
          const TipitakaTreeNode(
            nodeKey: 'b4',
            paliName: 'first sutta text',
            sinhalaName: '',
            hierarchyLevel: 2,
            entryPageIndex: 0,
            entryIndexInPage: 0,
            parentNodeKey: null,
            contentFileId: 'b4',
          ),
        ];

        when(mockTreeRepository.loadNavigationTree())
            .thenAnswer((_) async => Right(treeWithBoundaryTests));

        when(mockFTSDataSource.searchFullText(
          any,
          editionIds: anyNamed('editionIds'),
          language: anyNamed('language'),
          scope: anyNamed('scope'),
          isExactMatch: anyNamed('isExactMatch'),
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        )).thenAnswer((_) async => []);

        // ACT
        final result = await repository.searchTopResults(query);

        // ASSERT
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Expected success but got failure'),
          (categorized) {
            final titleResults =
                categorized.resultsByType[SearchResultType.title]!;
            // All 4 nodes match word boundary, limited to 3 by default maxPerCategory
            expect(titleResults.length, equals(3));
          },
        );
      });

      test(
          'should NOT match across punctuation without spaces (isExactMatch=true)',
          () async {
        // ARRANGE - Test that punctuation is NOT treated as word boundary
        // Current implementation only uses spaces as boundaries
        const query = SearchQuery(queryText: 'sutta', isExactMatch: true);

        final treeWithPunctuation = [
          // Should NOT match: hyphen is not a word boundary (no space)
          const TipitakaTreeNode(
            nodeKey: 'hyphen-1',
            paliName: 'Brahma-sutta',
            sinhalaName: '',
            hierarchyLevel: 2,
            entryPageIndex: 0,
            entryIndexInPage: 0,
            parentNodeKey: null,
            contentFileId: 'hyphen-1',
          ),
          // Should match: space before 'sutta' is a word boundary
          const TipitakaTreeNode(
            nodeKey: 'space-1',
            paliName: 'Brahma sutta',
            sinhalaName: '',
            hierarchyLevel: 2,
            entryPageIndex: 0,
            entryIndexInPage: 0,
            parentNodeKey: null,
            contentFileId: 'space-1',
          ),
          // Should NOT match: period is not a word boundary (no space)
          const TipitakaTreeNode(
            nodeKey: 'period-1',
            paliName: 'First.sutta',
            sinhalaName: '',
            hierarchyLevel: 2,
            entryPageIndex: 0,
            entryIndexInPage: 0,
            parentNodeKey: null,
            contentFileId: 'period-1',
          ),
        ];

        when(mockTreeRepository.loadNavigationTree())
            .thenAnswer((_) async => Right(treeWithPunctuation));

        when(mockFTSDataSource.searchFullText(
          any,
          editionIds: anyNamed('editionIds'),
          language: anyNamed('language'),
          scope: anyNamed('scope'),
          isExactMatch: anyNamed('isExactMatch'),
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        )).thenAnswer((_) async => []);

        // ACT
        final result = await repository.searchTopResults(query);

        // ASSERT
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Expected success but got failure'),
          (categorized) {
            final titleResults =
                categorized.resultsByType[SearchResultType.title]!;
            // Should only match 'Brahma sutta', not punctuation-separated ones
            expect(titleResults.length, equals(1));
            expect(titleResults[0].title, equals('Brahma sutta'));
            expect(titleResults[0].nodeKey, equals('space-1'));
          },
        );
      });

      // ========================================================================
      // DUAL-CRITERIA SORTING TESTS
      // ========================================================================

      test(
          'should sort with dual criteria: startsWith before contains, leaf before parent',
          () async {
        // ARRANGE - Create 4 node types to test both sort criteria
        const query = SearchQuery(queryText: 'sutta', isExactMatch: false);

        final treeWithSortingTest = [
          // Priority 4 (lowest): contains + parent
          const TipitakaTreeNode(
            nodeKey: 'parent-contains',
            paliName: 'Brahmajālasutta Collection',
            sinhalaName: '',
            hierarchyLevel: 1,
            entryPageIndex: 0,
            entryIndexInPage: 0,
            parentNodeKey: null,
            contentFileId: 'parent-contains',
            childNodes: [
              TipitakaTreeNode(
                nodeKey: 'child-dummy',
                paliName: 'Child',
                sinhalaName: '',
                hierarchyLevel: 2,
                entryPageIndex: 0,
                entryIndexInPage: 0,
                parentNodeKey: 'parent-contains',
                contentFileId: 'child-dummy',
              ),
            ],
          ),
          // Priority 3: contains + leaf
          const TipitakaTreeNode(
            nodeKey: 'leaf-contains',
            paliName: 'Brahmajālasutta',
            sinhalaName: '',
            hierarchyLevel: 2,
            entryPageIndex: 0,
            entryIndexInPage: 0,
            parentNodeKey: null,
            contentFileId: 'leaf-contains',
          ),
          // Priority 2: startsWith + parent
          const TipitakaTreeNode(
            nodeKey: 'parent-starts',
            paliName: 'Sutta Pitaka',
            sinhalaName: '',
            hierarchyLevel: 1,
            entryPageIndex: 0,
            entryIndexInPage: 0,
            parentNodeKey: null,
            contentFileId: 'parent-starts',
            childNodes: [
              TipitakaTreeNode(
                nodeKey: 'child-dummy2',
                paliName: 'Child',
                sinhalaName: '',
                hierarchyLevel: 2,
                entryPageIndex: 0,
                entryIndexInPage: 0,
                parentNodeKey: 'parent-starts',
                contentFileId: 'child-dummy2',
              ),
            ],
          ),
          // Priority 1 (highest): startsWith + leaf
          const TipitakaTreeNode(
            nodeKey: 'leaf-starts',
            paliName: 'Suttanipāta',
            sinhalaName: '',
            hierarchyLevel: 2,
            entryPageIndex: 0,
            entryIndexInPage: 0,
            parentNodeKey: null,
            contentFileId: 'leaf-starts',
          ),
        ];

        when(mockTreeRepository.loadNavigationTree())
            .thenAnswer((_) async => Right(treeWithSortingTest));

        when(mockFTSDataSource.searchFullText(
          any,
          editionIds: anyNamed('editionIds'),
          language: anyNamed('language'),
          scope: anyNamed('scope'),
          isExactMatch: anyNamed('isExactMatch'),
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        )).thenAnswer((_) async => []);

        // ACT
        final result =
            await repository.searchTopResults(query, maxPerCategory: 10);

        // ASSERT
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Expected success but got failure'),
          (categorized) {
            final titleResults =
                categorized.resultsByType[SearchResultType.title]!;
            expect(titleResults.length, equals(4));

            // Verify correct sort order
            expect(titleResults[0].nodeKey,
                equals('leaf-starts')); // 1st: startsWith + leaf
            expect(titleResults[1].nodeKey,
                equals('parent-starts')); // 2nd: startsWith + parent
            expect(titleResults[2].nodeKey,
                equals('leaf-contains')); // 3rd: contains + leaf
            expect(titleResults[3].nodeKey,
                equals('parent-contains')); // 4th: contains + parent
          },
        );
      });

      test('should apply limit after sorting (not before)', () async {
        // ARRANGE - Ensure limit gets top priority results, not just first N found
        const query = SearchQuery(queryText: 'sutta', isExactMatch: false);

        final treeWithLimitTest = [
          // Lower priority: contains match
          const TipitakaTreeNode(
            nodeKey: 'contains-1',
            paliName: 'Brahmajālasutta',
            sinhalaName: '',
            hierarchyLevel: 2,
            entryPageIndex: 0,
            entryIndexInPage: 0,
            parentNodeKey: null,
            contentFileId: 'contains-1',
          ),
          // Higher priority: startsWith match
          const TipitakaTreeNode(
            nodeKey: 'starts-1',
            paliName: 'Suttanipāta',
            sinhalaName: '',
            hierarchyLevel: 2,
            entryPageIndex: 0,
            entryIndexInPage: 0,
            parentNodeKey: null,
            contentFileId: 'starts-1',
          ),
          // Higher priority: startsWith match
          const TipitakaTreeNode(
            nodeKey: 'starts-2',
            paliName: 'Sutta Pitaka',
            sinhalaName: '',
            hierarchyLevel: 2,
            entryPageIndex: 0,
            entryIndexInPage: 0,
            parentNodeKey: null,
            contentFileId: 'starts-2',
          ),
        ];

        when(mockTreeRepository.loadNavigationTree())
            .thenAnswer((_) async => Right(treeWithLimitTest));

        when(mockFTSDataSource.searchFullText(
          any,
          editionIds: anyNamed('editionIds'),
          language: anyNamed('language'),
          scope: anyNamed('scope'),
          isExactMatch: anyNamed('isExactMatch'),
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        )).thenAnswer((_) async => []);

        // ACT - Limit to 2 results
        final result =
            await repository.searchTopResults(query, maxPerCategory: 2);

        // ASSERT
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Expected success but got failure'),
          (categorized) {
            final titleResults =
                categorized.resultsByType[SearchResultType.title]!;

            // Should return TOP 2 by priority (both startsWith), not first 2 found
            expect(titleResults.length, equals(2));
            expect(titleResults[0].nodeKey, equals('starts-1'));
            expect(titleResults[1].nodeKey, equals('starts-2'));
            // The contains match should be excluded by limit
            expect(titleResults.map((r) => r.nodeKey),
                isNot(contains('contains-1')));
          },
        );
      });

      // ========================================================================
      // SCOPE FILTERING INTEGRATION TESTS
      // ========================================================================

      test('should filter title search results by scope', () async {
        // ARRANGE - Create nodes in different scopes
        const query = SearchQuery(
          queryText: 'sutta',
          scope: {TipitakaNodeKeys.suttaPitaka}, // Only search in Sutta Pitaka
        );

        final treeWithMultipleScopes = [
          // In Sutta scope - should match
          const TipitakaTreeNode(
            nodeKey: 'sutta-1',
            paliName: 'Brahmajālasutta',
            sinhalaName: '',
            hierarchyLevel: 2,
            entryPageIndex: 0,
            entryIndexInPage: 0,
            parentNodeKey: null,
            contentFileId: 'dn-1', // Sutta file
          ),
          // In Vinaya scope - should NOT match
          const TipitakaTreeNode(
            nodeKey: 'vinaya-1',
            paliName: 'Vinayasutta',
            sinhalaName: '',
            hierarchyLevel: 2,
            entryPageIndex: 0,
            entryIndexInPage: 0,
            parentNodeKey: null,
            contentFileId: 'vin-1', // Vinaya file
          ),
        ];

        when(mockTreeRepository.loadNavigationTree())
            .thenAnswer((_) async => Right(treeWithMultipleScopes));

        when(mockFTSDataSource.searchFullText(
          any,
          editionIds: anyNamed('editionIds'),
          language: anyNamed('language'),
          scope: anyNamed('scope'),
          isExactMatch: anyNamed('isExactMatch'),
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        )).thenAnswer((_) async => []);

        // ACT
        final result = await repository.searchTopResults(query);

        // ASSERT
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Expected success but got failure'),
          (categorized) {
            final titleResults =
                categorized.resultsByType[SearchResultType.title]!;
            // Should only return Sutta scope results
            expect(titleResults.length, equals(1));
            expect(titleResults[0].contentFileId, startsWith('dn-'));
            expect(titleResults[0].nodeKey, equals('sutta-1'));
          },
        );
      });

      test('should pass scope filter to FTS datasource for full text search',
          () async {
        // ARRANGE
        const query = SearchQuery(
          queryText: 'dhamma',
          scope: {TipitakaNodeKeys.vinayaPitaka}, // Only search Vinaya Pitaka
        );

        final sampleTree = [
          const TipitakaTreeNode(
            nodeKey: 'test-1',
            paliName: 'Test',
            sinhalaName: '',
            hierarchyLevel: 2,
            entryPageIndex: 0,
            entryIndexInPage: 0,
            parentNodeKey: null,
            contentFileId: 'test-1',
          ),
        ];

        when(mockTreeRepository.loadNavigationTree())
            .thenAnswer((_) async => Right(sampleTree));

        when(mockFTSDataSource.searchFullText(
          any,
          editionIds: anyNamed('editionIds'),
          language: anyNamed('language'),
          scope: anyNamed('scope'),
          isExactMatch: anyNamed('isExactMatch'),
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        )).thenAnswer((_) async => []);

        // ACT
        await repository.searchTopResults(query);

        // ASSERT - Verify scope was passed to FTS datasource
        verify(mockFTSDataSource.searchFullText(
          'dhamma',
          editionIds: anyNamed('editionIds'),
          language: anyNamed('language'),
          scope: {
            TipitakaNodeKeys.vinayaPitaka
          }, // Scope should be passed through
          isExactMatch: false,
          isPhraseSearch: anyNamed('isPhraseSearch'),
          isAnywhereInText: anyNamed('isAnywhereInText'),
          proximityDistance: anyNamed('proximityDistance'),
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        )).called(1);
      });

      // ========================================================================
      // EDGE CASE TESTS
      // ========================================================================

      test('should exclude nodes without contentFileId from results', () async {
        // ARRANGE - Node matches query but has no contentFileId
        const query = SearchQuery(queryText: 'pitaka');

        final treeWithNullContentFileId = [
          // Parent node with no contentFileId - should be excluded
          const TipitakaTreeNode(
            nodeKey: 'root-1',
            paliName: 'Sutta Pitaka',
            sinhalaName: '',
            hierarchyLevel: 0,
            entryPageIndex: 0,
            entryIndexInPage: 0,
            parentNodeKey: null,
            contentFileId: null, // No content file - can't display
            childNodes: [
              TipitakaTreeNode(
                nodeKey: 'child-1',
                paliName: 'Child Pitaka',
                sinhalaName: '',
                hierarchyLevel: 1,
                entryPageIndex: 0,
                entryIndexInPage: 0,
                parentNodeKey: 'root-1',
                contentFileId: 'child-1', // Has content file - should match
              ),
            ],
          ),
        ];

        when(mockTreeRepository.loadNavigationTree())
            .thenAnswer((_) async => Right(treeWithNullContentFileId));

        when(mockFTSDataSource.searchFullText(
          any,
          editionIds: anyNamed('editionIds'),
          language: anyNamed('language'),
          scope: anyNamed('scope'),
          isExactMatch: anyNamed('isExactMatch'),
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        )).thenAnswer((_) async => []);

        // ACT
        final result = await repository.searchTopResults(query);

        // ASSERT
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Expected success but got failure'),
          (categorized) {
            final titleResults =
                categorized.resultsByType[SearchResultType.title]!;
            // Should only include the child with contentFileId
            expect(titleResults.length, equals(1));
            expect(titleResults[0].nodeKey, equals('child-1'));
            expect(titleResults[0].contentFileId, isNotNull);
          },
        );
      });

      test('should handle empty query string gracefully', () async {
        // ARRANGE - Empty query
        const query = SearchQuery(queryText: '');

        final sampleTree = [
          const TipitakaTreeNode(
            nodeKey: 'test-1',
            paliName: 'Test Sutta',
            sinhalaName: '',
            hierarchyLevel: 2,
            entryPageIndex: 0,
            entryIndexInPage: 0,
            parentNodeKey: null,
            contentFileId: 'test-1',
          ),
        ];

        when(mockTreeRepository.loadNavigationTree())
            .thenAnswer((_) async => Right(sampleTree));

        when(mockFTSDataSource.searchFullText(
          any,
          editionIds: anyNamed('editionIds'),
          language: anyNamed('language'),
          scope: anyNamed('scope'),
          isExactMatch: anyNamed('isExactMatch'),
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        )).thenAnswer((_) async => []);

        // ACT
        final result = await repository.searchTopResults(query);

        // ASSERT - Should not throw, return empty or all results depending on business logic
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Expected success but got failure'),
          (categorized) {
            final titleResults =
                categorized.resultsByType[SearchResultType.title]!;
            // Empty query behavior: currently matches all (contains logic)
            // This test documents current behavior
            expect(titleResults, isA<List>());
          },
        );
      });

      test('should handle nodes with empty names gracefully', () async {
        // ARRANGE - Node with empty Pali name but valid Sinhala name
        const query = SearchQuery(queryText: 'සූත්‍ර');

        final treeWithEmptyPaliName = [
          const TipitakaTreeNode(
            nodeKey: 'empty-pali-1',
            paliName: '', // Empty Pali name
            sinhalaName: 'සූත්‍රය', // Matches query
            hierarchyLevel: 2,
            entryPageIndex: 0,
            entryIndexInPage: 0,
            parentNodeKey: null,
            contentFileId: 'test-1',
          ),
        ];

        when(mockTreeRepository.loadNavigationTree())
            .thenAnswer((_) async => Right(treeWithEmptyPaliName));

        when(mockFTSDataSource.searchFullText(
          any,
          editionIds: anyNamed('editionIds'),
          language: anyNamed('language'),
          scope: anyNamed('scope'),
          isExactMatch: anyNamed('isExactMatch'),
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        )).thenAnswer((_) async => []);

        // ACT
        final result = await repository.searchTopResults(query);

        // ASSERT - Should match Sinhala name even when Pali is empty
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Expected success but got failure'),
          (categorized) {
            final titleResults =
                categorized.resultsByType[SearchResultType.title]!;
            expect(titleResults.length, equals(1));
            expect(titleResults[0].title, equals('සූත්‍රය'));
          },
        );
      });
    });

    group('searchByResultType', () {
      final sampleTree = [
        const TipitakaTreeNode(
          nodeKey: TipitakaNodeKeys.dighaNikaya,
          paliName: 'Dīgha Nikāya',
          sinhalaName: 'දීඝනිකාය',
          hierarchyLevel: 0,
          entryPageIndex: 0,
          entryIndexInPage: 0,
          parentNodeKey: null,
          childNodes: [
            TipitakaTreeNode(
              nodeKey: 'dn-1',
              paliName: 'Brahmajālasutta',
              sinhalaName: 'බ්‍රහ්මජාලසූත්‍රය',
              hierarchyLevel: 2,
              entryPageIndex: 0,
              entryIndexInPage: 0,
              parentNodeKey: TipitakaNodeKeys.dighaNikaya,
              contentFileId: 'dn-1',
            ),
          ],
        ),
      ];

      test('should search by title category in node names', () async {
        // ARRANGE - Use Sinhala query to avoid transliteration complexity
        const query = SearchQuery(queryText: 'බ්‍රහ්ම');

        when(mockTreeRepository.loadNavigationTree())
            .thenAnswer((_) async => Right(sampleTree));

        // ACT
        final result =
            await repository.searchByResultType(query, SearchResultType.title);

        // ASSERT
        expect(result.isRight(), true);

        result.fold(
          (failure) => fail('Expected success but got failure'),
          (results) {
            expect(results.length, equals(1));
            // Now matches Sinhala name since query is in Sinhala
            expect(results[0].title, equals('බ්‍රහ්මජාලසූත්‍රය'));
            expect(results[0].resultType, equals(SearchResultType.title));
          },
        );
      });

      test('should search by content category using FTS', () async {
        // ARRANGE - Use Sinhala query to avoid transliteration
        const query = SearchQuery(queryText: 'ධම්ම');

        final ftsMatches = [
          FTSMatch(
            editionId: 'bjt',
            rowid: 1,
            filename: 'dn-1',
            eind: '0-5',
            language: 'pali',
            type: 'paragraph',
            level: 0,
          ),
        ];

        when(mockTreeRepository.loadNavigationTree())
            .thenAnswer((_) async => Right(sampleTree));

        when(mockFTSDataSource.searchFullText(
          any,
          editionIds: anyNamed('editionIds'),
          language: anyNamed('language'),
          scope: anyNamed('scope'),
          isExactMatch: anyNamed('isExactMatch'),
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        )).thenAnswer((_) async => ftsMatches);

        // ACT
        final result = await repository.searchByResultType(
            query, SearchResultType.fullText);

        // ASSERT
        expect(result.isRight(), true);

        result.fold(
          (failure) => fail('Expected success but got failure'),
          (results) {
            expect(results.length, equals(1));
            expect(results[0].resultType, equals(SearchResultType.fullText));
            expect(results[0].contentFileId, equals('dn-1'));
          },
        );
        // Verify FTS was called with the Sinhala query (no transliteration)
        verify(mockFTSDataSource.searchFullText(
          'ධම්ම',
          editionIds: {'bjt'},
          language: null,
          scope: {},
          isExactMatch: false,
          limit: 50,
          offset: 0,
        )).called(1);
      });

      test('should support pagination with offset parameter', () async {
        // ARRANGE
        const query = SearchQuery(queryText: 'ධම්ම');

        // First page results
        final firstPageMatches = [
          FTSMatch(
            editionId: 'bjt',
            rowid: 1,
            filename: 'dn-1',
            eind: '0-5',
            language: 'pali',
            type: 'paragraph',
            level: 0,
          ),
        ];

        // Second page results (different rowid)
        final secondPageMatches = [
          FTSMatch(
            editionId: 'bjt',
            rowid: 51,
            filename: 'dn-2',
            eind: '10-15',
            language: 'pali',
            type: 'paragraph',
            level: 0,
          ),
        ];

        when(mockTreeRepository.loadNavigationTree())
            .thenAnswer((_) async => Right(sampleTree));

        // Mock first page (offset: 0)
        when(mockFTSDataSource.searchFullText(
          any,
          editionIds: anyNamed('editionIds'),
          language: anyNamed('language'),
          scope: anyNamed('scope'),
          isExactMatch: anyNamed('isExactMatch'),
          limit: 50,
          offset: 0,
        )).thenAnswer((_) async => firstPageMatches);

        // Mock second page (offset: 50)
        when(mockFTSDataSource.searchFullText(
          any,
          editionIds: anyNamed('editionIds'),
          language: anyNamed('language'),
          scope: anyNamed('scope'),
          isExactMatch: anyNamed('isExactMatch'),
          limit: 50,
          offset: 50,
        )).thenAnswer((_) async => secondPageMatches);

        // ACT - Get first page
        final firstPageResult = await repository.searchByResultType(
            query, SearchResultType.fullText);

        // ASSERT - First page
        expect(firstPageResult.isRight(), true);
        firstPageResult.fold(
          (failure) => fail('Expected success but got failure'),
          (results) {
            expect(results.length, equals(1));
            expect(results[0].contentFileId, equals('dn-1'));
          },
        );

        // Verify first page call
        verify(mockFTSDataSource.searchFullText(
          'ධම්ම',
          editionIds: {'bjt'},
          language: null,
          scope: {},
          isExactMatch: false,
          limit: 50,
          offset: 0,
        )).called(1);
      });

      test('should pass custom limit and offset from query to FTS datasource',
          () async {
        // ARRANGE - Query with custom limit and offset for pagination
        const query = SearchQuery(
          queryText: 'ධම්ම',
          limit: 20, // Smaller page size
          offset: 40, // Third page (if page size is 20)
        );

        when(mockTreeRepository.loadNavigationTree())
            .thenAnswer((_) async => Right(sampleTree));

        when(mockFTSDataSource.searchFullText(
          any,
          editionIds: anyNamed('editionIds'),
          language: anyNamed('language'),
          scope: anyNamed('scope'),
          isExactMatch: anyNamed('isExactMatch'),
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        )).thenAnswer((_) async => []);

        // ACT
        await repository.searchByResultType(query, SearchResultType.fullText);

        // ASSERT - Verify custom limit and offset from query were passed through
        verify(mockFTSDataSource.searchFullText(
          'ධම්ම',
          editionIds: {'bjt'},
          language: null,
          scope: {},
          isExactMatch: false,
          limit: 20, // Custom limit from query
          offset: 40, // Custom offset from query
        )).called(1);
      });

      test('should return failure when definition search is attempted',
          () async {
        // ARRANGE
        const query = SearchQuery(queryText: 'dhamma');

        when(mockTreeRepository.loadNavigationTree())
            .thenAnswer((_) async => Right(sampleTree));

        // ACT
        final result = await repository.searchByResultType(
            query, SearchResultType.definition);

        // ASSERT - StateError is caught and wrapped in Failure
        expect(result.isLeft(), true);
        result.fold(
          (failure) {
            expect(failure, isA<DataLoadFailure>());
            expect(failure.userMessage, contains('Failed to search by type'));
          },
          (_) => fail('Expected failure but got success'),
        );
      });

      test(
          'should return failure when topResults type is used with searchByResultType',
          () async {
        // ARRANGE
        const query = SearchQuery(queryText: 'dhamma');

        when(mockTreeRepository.loadNavigationTree())
            .thenAnswer((_) async => Right(sampleTree));

        // ACT
        final result = await repository.searchByResultType(
            query, SearchResultType.topResults);

        // ASSERT - StateError is caught and wrapped in Failure
        expect(result.isLeft(), true);
        result.fold(
          (failure) {
            expect(failure, isA<DataLoadFailure>());
            expect(failure.userMessage, contains('Failed to search by type'));
          },
          (_) => fail('Expected failure but got success'),
        );
      });

      test('should return failure when tree loading fails', () async {
        // ARRANGE
        const query = SearchQuery(queryText: 'test');

        when(mockTreeRepository.loadNavigationTree()).thenAnswer(
          (_) async => const Left(
            Failure.dataLoadFailure(message: 'Failed to load tree'),
          ),
        );

        // ACT
        final result =
            await repository.searchByResultType(query, SearchResultType.title);

        // ASSERT
        expect(result.isLeft(), true);

        result.fold(
          (failure) {
            expect(failure, isA<DataLoadFailure>());
          },
          (results) => fail('Expected failure but got success'),
        );
      });

      test('should return failure when FTS throws for content category',
          () async {
        // ARRANGE - Use Sinhala query to avoid transliteration
        const query = SearchQuery(queryText: 'ධම්ම');

        when(mockTreeRepository.loadNavigationTree())
            .thenAnswer((_) async => Right(sampleTree));

        when(mockFTSDataSource.searchFullText(
          any,
          editionIds: anyNamed('editionIds'),
          language: anyNamed('language'),
          scope: anyNamed('scope'),
          isExactMatch: anyNamed('isExactMatch'),
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        )).thenThrow(Exception('Database error'));

        // ACT
        final result = await repository.searchByResultType(
            query, SearchResultType.fullText);

        // ASSERT
        expect(result.isLeft(), true);

        result.fold(
          (failure) {
            expect(failure, isA<DataLoadFailure>());
            expect(failure.userMessage, contains('Failed to search by type'));
          },
          (results) => fail('Expected failure but got success'),
        );
      });
    });
  });
}
