import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:the_wisdom_project/data/repositories/text_search_repository_impl.dart';
import 'package:the_wisdom_project/domain/entities/failure.dart';
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
    group('search', () {
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

      final sampleFTSMatches = [
        FTSMatch(
          editionId: 'bjt',
          rowid: 1,
          filename: 'dn-1',
          eind: '0-5',
          language: 'pali',
          type: 'paragraph',
          level: 0,
        ),
        FTSMatch(
          editionId: 'sc',
          rowid: 2,
          filename: 'dn-1',
          eind: '1-3',
          language: 'pali',
          type: 'paragraph',
          level: 0,
        ),
      ];

      test('should return search results from single edition', () async {
        // ARRANGE
        const query = SearchQuery(
          queryText: 'dhamma',
          editionIds: {'bjt'},
        );

        when(mockFTSDataSource.searchContent(
          any,
          editionIds: anyNamed('editionIds'),
          language: anyNamed('language'),
          nikayaFilter: anyNamed('nikayaFilter'),
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        )).thenAnswer((_) async => [sampleFTSMatches[0]]);

        when(mockTreeRepository.loadNavigationTree())
            .thenAnswer((_) async => Right(sampleTree));

        // ACT
        final result = await repository.search(query);

        // ASSERT
        expect(result.isRight(), true);

        result.fold(
          (failure) => fail('Expected success but got failure'),
          (results) {
            expect(results.length, equals(1));
            expect(results[0].editionId, equals('bjt'));
            expect(results[0].contentFileId, equals('dn-1'));
            expect(results[0].pageIndex, equals(0));
            expect(results[0].entryIndex, equals(5));
            expect(results[0].title, equals('Brahmajālasutta'));
          },
        );

        verify(mockFTSDataSource.searchContent(
          'dhamma',
          editionIds: {'bjt'},
          language: null,
          nikayaFilter: null,
          limit: 50,
          offset: 0,
        )).called(1);

        verify(mockTreeRepository.loadNavigationTree()).called(1);
      });

      test('should return search results from multiple editions', () async {
        // ARRANGE
        const query = SearchQuery(
          queryText: 'dhamma',
          editionIds: {'bjt', 'sc'},
        );

        when(mockFTSDataSource.searchContent(
          any,
          editionIds: anyNamed('editionIds'),
          language: anyNamed('language'),
          nikayaFilter: anyNamed('nikayaFilter'),
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        )).thenAnswer((_) async => sampleFTSMatches);

        when(mockTreeRepository.loadNavigationTree())
            .thenAnswer((_) async => Right(sampleTree));

        // ACT
        final result = await repository.search(query);

        // ASSERT
        expect(result.isRight(), true);

        result.fold(
          (failure) => fail('Expected success but got failure'),
          (results) {
            expect(results.length, equals(2));
            expect(results[0].editionId, equals('bjt'));
            expect(results[1].editionId, equals('sc'));
            expect(results.every((r) => r.contentFileId == 'dn-1'), true);
          },
        );

        verify(mockFTSDataSource.searchContent(
          'dhamma',
          editionIds: {'bjt', 'sc'},
          language: null,
          nikayaFilter: null,
          limit: 50,
          offset: 0,
        )).called(1);
      });

      test('should filter by language (Pali only)', () async {
        // ARRANGE
        const query = SearchQuery(
          queryText: 'dhamma',
          searchInPali: true,
          searchInSinhala: false,
        );

        when(mockFTSDataSource.searchContent(
          any,
          editionIds: anyNamed('editionIds'),
          language: anyNamed('language'),
          nikayaFilter: anyNamed('nikayaFilter'),
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        )).thenAnswer((_) async => [sampleFTSMatches[0]]);

        when(mockTreeRepository.loadNavigationTree())
            .thenAnswer((_) async => Right(sampleTree));

        // ACT
        final result = await repository.search(query);

        // ASSERT
        expect(result.isRight(), true);

        verify(mockFTSDataSource.searchContent(
          'dhamma',
          editionIds: anyNamed('editionIds'),
          language: 'pali',
          nikayaFilter: null,
          limit: 50,
          offset: 0,
        )).called(1);
      });

      test('should filter by Nikaya', () async {
        // ARRANGE
        const query = SearchQuery(
          queryText: 'dhamma',
          nikayaFilters: ['dn', 'mn'],
        );

        when(mockFTSDataSource.searchContent(
          any,
          editionIds: anyNamed('editionIds'),
          language: anyNamed('language'),
          nikayaFilter: anyNamed('nikayaFilter'),
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        )).thenAnswer((_) async => [sampleFTSMatches[0]]);

        when(mockTreeRepository.loadNavigationTree())
            .thenAnswer((_) async => Right(sampleTree));

        // ACT
        final result = await repository.search(query);

        // ASSERT
        expect(result.isRight(), true);

        verify(mockFTSDataSource.searchContent(
          'dhamma',
          editionIds: anyNamed('editionIds'),
          language: null,
          nikayaFilter: ['dn', 'mn'],
          limit: 50,
          offset: 0,
        )).called(1);
      });

      test('should return failure when tree loading fails', () async {
        // ARRANGE
        const query = SearchQuery(queryText: 'dhamma');

        when(mockFTSDataSource.searchContent(
          any,
          editionIds: anyNamed('editionIds'),
          language: anyNamed('language'),
          nikayaFilter: anyNamed('nikayaFilter'),
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        )).thenAnswer((_) async => [sampleFTSMatches[0]]);

        when(mockTreeRepository.loadNavigationTree()).thenAnswer(
          (_) async => const Left(
            Failure.dataLoadFailure(message: 'Failed to load tree'),
          ),
        );

        // ACT
        final result = await repository.search(query);

        // ASSERT
        expect(result.isLeft(), true);

        result.fold(
          (failure) {
            expect(failure, isA<DataLoadFailure>());
          },
          (results) => fail('Expected failure but got success'),
        );
      });

      test('should return failure when FTS search throws', () async {
        // ARRANGE
        const query = SearchQuery(queryText: 'dhamma');

        when(mockFTSDataSource.searchContent(
          any,
          editionIds: anyNamed('editionIds'),
          language: anyNamed('language'),
          nikayaFilter: anyNamed('nikayaFilter'),
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        )).thenThrow(Exception('Database error'));

        // ACT
        final result = await repository.search(query);

        // ASSERT
        expect(result.isLeft(), true);

        result.fold(
          (failure) {
            expect(failure, isA<DataLoadFailure>());
            expect(failure.userMessage, contains('Failed to perform search'));
          },
          (results) => fail('Expected failure but got success'),
        );
      });

      test('should default to BJT edition when no editions specified',
          () async {
        // ARRANGE
        const query = SearchQuery(
          queryText: 'dhamma',
          editionIds: {}, // Empty set
        );

        when(mockFTSDataSource.searchContent(
          any,
          editionIds: anyNamed('editionIds'),
          language: anyNamed('language'),
          nikayaFilter: anyNamed('nikayaFilter'),
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        )).thenAnswer((_) async => [sampleFTSMatches[0]]);

        when(mockTreeRepository.loadNavigationTree())
            .thenAnswer((_) async => Right(sampleTree));

        // ACT
        final result = await repository.search(query);

        // ASSERT
        expect(result.isRight(), true);

        // Verify BJT was used as default
        verify(mockFTSDataSource.searchContent(
          'dhamma',
          editionIds: {'bjt'},
          language: null,
          nikayaFilter: null,
          limit: 50,
          offset: 0,
        )).called(1);
      });
    });

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
  });
}
