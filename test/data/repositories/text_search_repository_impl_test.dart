import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:the_wisdom_project/data/repositories/text_search_repository_impl.dart';
import 'package:the_wisdom_project/domain/entities/failure.dart';
import 'package:the_wisdom_project/domain/entities/search/search_result_type.dart';
import 'package:the_wisdom_project/domain/entities/search/search_query.dart';
import 'package:the_wisdom_project/data/datasources/fts_datasource.dart';
import 'package:the_wisdom_project/domain/entities/tipitaka_tree_node.dart';

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
          nodeKey: 'dn',
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
              parentNodeKey: 'dn',
              contentFileId: 'dn-1',
            ),
            TipitakaTreeNode(
              nodeKey: 'dn-2',
              paliName: 'Sāmaññaphalasutta',
              sinhalaName: 'සාමඤ්ඤඵලසූත්‍රය',
              hierarchyLevel: 2,
              entryPageIndex: 0,
              entryIndexInPage: 0,
              parentNodeKey: 'dn',
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
            nodeKey: 'dn',
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
                parentNodeKey: 'dn',
                contentFileId: 'dn-1',
              ),
              TipitakaTreeNode(
                nodeKey: 'dn-2',
                paliName: 'Sāmaññaphalasutta',
                sinhalaName: 'සාමඤ්ඤඵලසූත්‍රය',
                hierarchyLevel: 2,
                entryPageIndex: 0,
                entryIndexInPage: 0,
                parentNodeKey: 'dn',
                contentFileId: 'dn-2',
              ),
              TipitakaTreeNode(
                nodeKey: 'dn-3',
                paliName: 'Ambaṭṭhasutta',
                sinhalaName: 'අම්බට්ඨසූත්‍රය',
                hierarchyLevel: 2,
                entryPageIndex: 0,
                entryIndexInPage: 0,
                parentNodeKey: 'dn',
                contentFileId: 'dn-3',
              ),
              TipitakaTreeNode(
                nodeKey: 'dn-4',
                paliName: 'Soṇadaṇḍasutta',
                sinhalaName: 'සොණදණ්ඩසූත්‍රය',
                hierarchyLevel: 2,
                entryPageIndex: 0,
                entryIndexInPage: 0,
                parentNodeKey: 'dn',
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
            expect(contentResults[0].resultType, equals(SearchResultType.fullText));
            expect(contentResults[0].contentFileId, equals('dn-1'));
          },
        );
      });

      test('should pass isExactMatch=true to FTS when query has isExactMatch enabled',
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
        const query = SearchQuery(queryText: 'dhamma'); // isExactMatch defaults to false

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
    });

    group('searchByCategory', () {
      final sampleTree = [
        const TipitakaTreeNode(
          nodeKey: 'dn',
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
              parentNodeKey: 'dn',
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
        final result =
            await repository.searchByResultType(query, SearchResultType.fullText);

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
        final firstPageResult =
            await repository.searchByResultType(query, SearchResultType.fullText);

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

      test('should return empty for definition category (placeholder)',
          () async {
        // ARRANGE - Use non-romanized query
        const query = SearchQuery(queryText: '123');

        when(mockTreeRepository.loadNavigationTree())
            .thenAnswer((_) async => Right(sampleTree));

        // ACT
        final result =
            await repository.searchByResultType(query, SearchResultType.definition);

        // ASSERT
        expect(result.isRight(), true);

        result.fold(
          (failure) => fail('Expected success but got failure'),
          (results) {
            expect(results, isEmpty);
          },
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
        final result =
            await repository.searchByResultType(query, SearchResultType.fullText);

        // ASSERT
        expect(result.isLeft(), true);

        result.fold(
          (failure) {
            expect(failure, isA<DataLoadFailure>());
            expect(
                failure.userMessage, contains('Failed to search by category'));
          },
          (results) => fail('Expected failure but got success'),
        );
      });
    });
  });
}
