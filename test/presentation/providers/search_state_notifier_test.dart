import 'package:dartz/dartz.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:the_wisdom_project/domain/entities/failure.dart';
import 'package:the_wisdom_project/domain/entities/search/grouped_search_result.dart';
import 'package:the_wisdom_project/domain/entities/search/recent_search.dart';
import 'package:the_wisdom_project/domain/entities/search/search_result_type.dart';
import 'package:the_wisdom_project/domain/entities/search/search_result.dart';
import 'package:the_wisdom_project/presentation/providers/search_state.dart';

import '../../helpers/mocks.mocks.dart';

void main() {
  late SearchStateNotifier notifier;
  late MockTextSearchRepository mockSearchRepository;
  late MockRecentSearchesRepository mockRecentSearchesRepository;

  setUp(() {
    mockSearchRepository = MockTextSearchRepository();
    mockRecentSearchesRepository = MockRecentSearchesRepository();

    // Default stub for countByResultType (called by _loadCounts in parallel)
    when(mockSearchRepository.countByResultType(any))
        .thenAnswer((_) async => const Right({}));

    notifier = SearchStateNotifier(
      mockSearchRepository,
      mockRecentSearchesRepository,
    );
  });

  tearDown(() {
    notifier.dispose();
  });

  group('SearchStateNotifier -', () {
    group('onFocus', () {
      test('should load recent searches', () async {
        // ARRANGE
        final recentSearches = [
          RecentSearch(queryText: 'dhamma', timestamp: DateTime.now()),
          RecentSearch(queryText: 'buddha', timestamp: DateTime.now()),
        ];
        when(mockRecentSearchesRepository.getRecentSearches())
            .thenAnswer((_) async => recentSearches);

        // ACT
        await notifier.onFocus();

        // ASSERT
        expect(notifier.state.recentSearches.length, equals(2));
        expect(notifier.state.recentSearches[0].queryText, equals('dhamma'));
        verify(mockRecentSearchesRepository.getRecentSearches()).called(1);
      });

      test('should set empty recent searches when none stored', () async {
        // ARRANGE
        when(mockRecentSearchesRepository.getRecentSearches())
            .thenAnswer((_) async => []);

        // ACT
        await notifier.onFocus();

        // ASSERT
        expect(notifier.state.recentSearches, isEmpty);
      });
    });

    group('isResultsPanelVisible', () {
      test('should be false for empty query', () {
        expect(notifier.state.isResultsPanelVisible, isFalse);
      });

      test('should be true for any non-empty query', () {
        notifier.updateQuery('d');
        expect(notifier.state.isResultsPanelVisible, isTrue);
      });

      test('should be false for whitespace-only query', () {
        notifier.updateQuery('   ');
        expect(notifier.state.isResultsPanelVisible, isFalse);
      });

      test('should be false when panel is dismissed', () {
        notifier.updateQuery('test');
        expect(notifier.state.isResultsPanelVisible, isTrue);

        notifier.dismissResultsPanel();
        expect(notifier.state.isResultsPanelVisible, isFalse);
      });
    });

    group('updateQuery', () {
      test('should update query text', () {
        // ACT
        notifier.updateQuery('dhamma');

        // ASSERT
        expect(notifier.state.queryText, equals('dhamma'));
      });

      test('should clear results for empty queries', () {
        // ARRANGE - first set up some results
        notifier.updateQuery('dhamma');

        // ACT - clear to empty
        notifier.updateQuery('');

        // ASSERT
        expect(notifier.state.categorizedResults, isNull);
        expect(notifier.state.isLoading, isFalse);
      });

      test('should set loading for any non-empty query', () {
        // ACT
        notifier.updateQuery('d');

        // ASSERT - even single char triggers loading
        expect(notifier.state.isLoading, isTrue);
      });

      test('should debounce search (300ms)', () {
        fakeAsync((async) {
          // ARRANGE
          const categorizedResult = GroupedSearchResult(
            resultsByType: {
              SearchResultType.title: [],
              SearchResultType.fullText: [],
              SearchResultType.definition: [],
            },
          );
          when(mockSearchRepository.searchTopResults(any))
              .thenAnswer((_) async => const Right(categorizedResult));

          // ACT
          notifier.updateQuery('test');

          // ASSERT - Should not have called search yet
          verifyNever(mockSearchRepository.searchTopResults(any));

          // Fast forward less than 300ms
          async.elapse(const Duration(milliseconds: 200));
          verifyNever(mockSearchRepository.searchTopResults(any));

          // Fast forward past 300ms
          async.elapse(const Duration(milliseconds: 150));
          verify(mockSearchRepository.searchTopResults(any)).called(1);
        });
      });
    });


    group('selectCategory', () {
      test('should update selected category', () async {
        // ARRANGE
        when(mockSearchRepository.searchByResultType(any, any))
            .thenAnswer((_) async => const Right([]));

        notifier.updateQuery('test');

        // ACT
        await notifier.selectCategory(SearchResultType.fullText);

        // ASSERT
        expect(notifier.state.selectedCategory, equals(SearchResultType.fullText));
      });

      test('should load categorized results for "all" category', () async {
        // ARRANGE
        const categorizedResult = GroupedSearchResult(
          resultsByType: {
            SearchResultType.title: [],
            SearchResultType.fullText: [],
            SearchResultType.definition: [],
          },
        );
        when(mockSearchRepository.searchTopResults(any))
            .thenAnswer((_) async => const Right(categorizedResult));
        when(mockSearchRepository.searchByResultType(any, any))
            .thenAnswer((_) async => const Right([]));

        notifier.updateQuery('test');

        // First switch to a different category
        await notifier.selectCategory(SearchResultType.title);
        clearInteractions(mockSearchRepository);

        // ACT - Switch back to "all" category
        await notifier.selectCategory(SearchResultType.topResults);

        // ASSERT
        verify(mockSearchRepository.searchTopResults(any)).called(1);
      });

      test('should load full results for specific category', () async {
        // ARRANGE
        when(mockSearchRepository.searchByResultType(any, any))
            .thenAnswer((_) async => const Right([]));

        notifier.updateQuery('test');

        // ACT
        await notifier.selectCategory(SearchResultType.fullText);

        // ASSERT
        verify(mockSearchRepository.searchByResultType(
                any, SearchResultType.fullText))
            .called(1);
      });

      test('should not reload if same category selected', () async {
        // ARRANGE
        const categorizedResult = GroupedSearchResult(
          resultsByType: {
            SearchResultType.title: [],
            SearchResultType.fullText: [],
            SearchResultType.definition: [],
          },
        );
        when(mockSearchRepository.searchTopResults(any))
            .thenAnswer((_) async => const Right(categorizedResult));

        notifier.updateQuery('test');
        clearInteractions(mockSearchRepository);

        // ACT - Select same category (default is all)
        await notifier.selectCategory(SearchResultType.topResults);

        // ASSERT
        verifyNever(mockSearchRepository.searchTopResults(any));
        verifyNever(mockSearchRepository.searchByResultType(any, any));
      });
    });

    group('removeRecentSearch', () {
      test('should remove search and refresh list', () async {
        // ARRANGE
        final initial = [
          RecentSearch(queryText: 'dhamma', timestamp: DateTime.now()),
          RecentSearch(queryText: 'buddha', timestamp: DateTime.now()),
        ];
        final afterRemoval = [
          RecentSearch(queryText: 'buddha', timestamp: DateTime.now()),
        ];

        when(mockRecentSearchesRepository.getRecentSearches())
            .thenAnswer((_) async => initial);
        await notifier.onFocus();

        when(mockRecentSearchesRepository.removeRecentSearch('dhamma'))
            .thenAnswer((_) async {});
        when(mockRecentSearchesRepository.getRecentSearches())
            .thenAnswer((_) async => afterRemoval);

        // ACT
        await notifier.removeRecentSearch('dhamma');

        // ASSERT
        expect(notifier.state.recentSearches.length, equals(1));
        expect(notifier.state.recentSearches[0].queryText, equals('buddha'));
        verify(mockRecentSearchesRepository.removeRecentSearch('dhamma'))
            .called(1);
      });
    });

    group('clearRecentSearches', () {
      test('should clear all recent searches', () async {
        // ARRANGE
        when(mockRecentSearchesRepository.getRecentSearches())
            .thenAnswer((_) async => [
                  RecentSearch(queryText: 'dhamma', timestamp: DateTime.now()),
                ]);
        await notifier.onFocus();
        expect(notifier.state.recentSearches, isNotEmpty);

        when(mockRecentSearchesRepository.clearRecentSearches())
            .thenAnswer((_) async {});

        // ACT
        await notifier.clearRecentSearches();

        // ASSERT
        expect(notifier.state.recentSearches, isEmpty);
        verify(mockRecentSearchesRepository.clearRecentSearches()).called(1);
      });
    });

    group('toggleExactMatch', () {
      test('should toggle exactMatch flag on and off', () {
        // ARRANGE - Initial state has exactMatch=false
        expect(notifier.state.exactMatch, isFalse);

        // ACT - Toggle to true
        notifier.toggleExactMatch();

        // ASSERT
        expect(notifier.state.exactMatch, isTrue);

        // ACT - Toggle back to false
        notifier.toggleExactMatch();

        // ASSERT
        expect(notifier.state.exactMatch, isFalse);
      });

      test('should refresh search when toggling with active query', () async {
        // ARRANGE
        const categorizedResult = GroupedSearchResult(
          resultsByType: {
            SearchResultType.title: [],
            SearchResultType.fullText: [],
            SearchResultType.definition: [],
          },
        );
        when(mockSearchRepository.searchTopResults(any))
            .thenAnswer((_) async => const Right(categorizedResult));

        notifier.updateQuery('dhamma');
        await Future.delayed(const Duration(milliseconds: 350)); // Wait for debounce
        clearInteractions(mockSearchRepository);

        // ACT - Toggle exact match
        notifier.toggleExactMatch();

        // ASSERT - Should trigger new search
        verify(mockSearchRepository.searchTopResults(any)).called(1);
      });

      test('should not refresh search when toggling with empty query', () {
        // ARRANGE - Empty query
        expect(notifier.state.queryText, isEmpty);

        // ACT - Toggle exact match
        notifier.toggleExactMatch();

        // ASSERT - No search triggered
        verifyNever(mockSearchRepository.searchTopResults(any));
      });

      test('should include exactMatch in built SearchQuery', () async {
        // ARRANGE
        const categorizedResult = GroupedSearchResult(
          resultsByType: {
            SearchResultType.title: [],
            SearchResultType.fullText: [],
            SearchResultType.definition: [],
          },
        );
        when(mockSearchRepository.searchTopResults(any))
            .thenAnswer((_) async => const Right(categorizedResult));

        // Use Sinhala input directly to avoid transliteration dependency
        notifier.updateQuery('ධම්ම');
        notifier.toggleExactMatch(); // Set exactMatch to true

        await Future.delayed(const Duration(milliseconds: 350)); // Wait for debounce

        // ASSERT - Verify the SearchQuery passed has exactMatch=true
        final captured = verify(
          mockSearchRepository.searchTopResults(captureAny),
        ).captured;

        expect(captured.length, greaterThan(0));
        final query = captured.last;
        expect(query.exactMatch, isTrue);
        expect(query.queryText, equals('ධම්ම'));
      });
    });

    group('Filter methods', () {
      test('toggleEdition should add/remove edition', () {
        // ACT - Add edition
        notifier.toggleEdition('sc');
        expect(notifier.state.selectedEditions, contains('sc'));

        // ACT - Remove edition
        notifier.toggleEdition('sc');
        expect(notifier.state.selectedEditions, isNot(contains('sc')));
      });

      test('setLanguageFilter should update language filters', () {
        // ACT
        notifier.setLanguageFilter(pali: false, sinhala: true);

        // ASSERT
        expect(notifier.state.searchInPali, isFalse);
        expect(notifier.state.searchInSinhala, isTrue);
      });

      test('addNikayaFilter should add nikaya filter', () {
        // ACT
        notifier.addNikayaFilter('dn');
        notifier.addNikayaFilter('mn');

        // ASSERT
        expect(notifier.state.nikayaFilters, containsAll(['dn', 'mn']));
      });

      test('removeNikayaFilter should remove nikaya filter', () {
        // ARRANGE
        notifier.addNikayaFilter('dn');
        notifier.addNikayaFilter('mn');

        // ACT
        notifier.removeNikayaFilter('dn');

        // ASSERT
        expect(notifier.state.nikayaFilters, contains('mn'));
        expect(notifier.state.nikayaFilters, isNot(contains('dn')));
      });

      test('clearFilters should reset all filters', () {
        // ARRANGE
        notifier.toggleEdition('sc');
        notifier.setLanguageFilter(pali: false);
        notifier.addNikayaFilter('dn');

        // ACT
        notifier.clearFilters();

        // ASSERT
        expect(notifier.state.selectedEditions, isEmpty);
        expect(notifier.state.searchInPali, isTrue);
        expect(notifier.state.searchInSinhala, isTrue);
        expect(notifier.state.nikayaFilters, isEmpty);
      });
    });

    group('clearSearch', () {
      test('should reset to initial state', () async {
        // ARRANGE
        when(mockRecentSearchesRepository.getRecentSearches())
            .thenAnswer((_) async => []);
        await notifier.onFocus();
        notifier.updateQuery('test');

        // ACT
        notifier.clearSearch();

        // ASSERT
        expect(notifier.state.queryText, isEmpty);
        expect(notifier.state.categorizedResults, isNull);
        expect(notifier.state.isResultsPanelVisible, isFalse);
      });
    });

    group('dismissResultsPanel', () {
      test('should hide panel but keep query text', () async {
        // ARRANGE
        notifier.updateQuery('test');
        expect(notifier.state.isResultsPanelVisible, isTrue);

        // ACT
        notifier.dismissResultsPanel();

        // ASSERT - query text is kept, but panel is hidden
        expect(notifier.state.queryText, equals('test'));
        expect(notifier.state.isPanelDismissed, isTrue);
        expect(notifier.state.isResultsPanelVisible, isFalse);
      });
    });

    group('saveRecentSearchAndDismiss', () {
      test('should save to recent searches and dismiss panel', () async {
        // ARRANGE
        when(mockRecentSearchesRepository.addRecentSearch(any))
            .thenAnswer((_) async {});
        when(mockRecentSearchesRepository.getRecentSearches())
            .thenAnswer((_) async => [
                  RecentSearch(queryText: 'test query', timestamp: DateTime.now()),
                ]);

        notifier.updateQuery('test query');
        expect(notifier.state.isResultsPanelVisible, isTrue);

        // ACT
        await notifier.saveRecentSearchAndDismiss();

        // ASSERT
        verify(mockRecentSearchesRepository.addRecentSearch('test query'))
            .called(1);
        expect(notifier.state.isPanelDismissed, isTrue);
        expect(notifier.state.isResultsPanelVisible, isFalse);
        expect(notifier.state.queryText, equals('test query')); // Text preserved
      });

      test('should not save for empty queries', () async {
        // ARRANGE
        notifier.updateQuery('');

        // ACT
        await notifier.saveRecentSearchAndDismiss();

        // ASSERT - empty queries should not be saved
        verifyNever(mockRecentSearchesRepository.addRecentSearch(any));
      });

      test('should update recent searches list after saving', () async {
        // ARRANGE
        final updatedRecent = [
          RecentSearch(queryText: 'test query', timestamp: DateTime.now()),
          RecentSearch(queryText: 'old query', timestamp: DateTime.now()),
        ];
        when(mockRecentSearchesRepository.addRecentSearch(any))
            .thenAnswer((_) async {});
        when(mockRecentSearchesRepository.getRecentSearches())
            .thenAnswer((_) async => updatedRecent);

        notifier.updateQuery('test query');

        // ACT
        await notifier.saveRecentSearchAndDismiss();

        // ASSERT
        expect(notifier.state.recentSearches.length, equals(2));
        expect(notifier.state.recentSearches[0].queryText, equals('test query'));
      });
    });

    group('selectRecentSearch', () {
      test('should set query and trigger search', () async {
        // ARRANGE
        const categorizedResult = GroupedSearchResult(
          resultsByType: {
            SearchResultType.title: [],
            SearchResultType.fullText: [],
            SearchResultType.definition: [],
          },
        );
        when(mockSearchRepository.searchTopResults(any))
            .thenAnswer((_) async => const Right(categorizedResult));
        when(mockRecentSearchesRepository.addRecentSearch(any))
            .thenAnswer((_) async {});

        // ACT
        await notifier.selectRecentSearch('dhamma');

        // ASSERT
        expect(notifier.state.queryText, equals('dhamma'));
        expect(notifier.state.isResultsPanelVisible, isTrue);
        verify(mockSearchRepository.searchTopResults(any)).called(1);
        verify(mockRecentSearchesRepository.addRecentSearch('dhamma'))
            .called(1);
      });
    });

    group('Error handling', () {
      test('should clear results when categorized search fails', () async {
        // ARRANGE
        const failure = Failure.dataLoadFailure(
          message: 'Database connection failed',
        );
        when(mockSearchRepository.searchTopResults(any))
            .thenAnswer((_) async => const Left(failure));

        // ACT
        notifier.updateQuery('test');
        await Future.delayed(const Duration(milliseconds: 350)); // Wait for debounce

        // ASSERT
        expect(notifier.state.isLoading, isFalse);
        expect(notifier.state.categorizedResults, isNull);
        expect(notifier.state.queryText, equals('test')); // Query text preserved
      });

      test('should set error state when category search fails', () async {
        // ARRANGE
        const failure = Failure.dataLoadFailure(
          message: 'Failed to load content results',
        );
        when(mockSearchRepository.searchByResultType(any, any))
            .thenAnswer((_) async => const Left(failure));

        notifier.updateQuery('test');

        // ACT
        await notifier.selectCategory(SearchResultType.fullText);

        // ASSERT
        expect(notifier.state.isLoading, isFalse);

        // Check that fullResults is in error state
        final results = notifier.state.fullResults;
        expect(results, isA<AsyncError<List<SearchResult>>>());

        // Access error from AsyncError
        if (results is AsyncError<List<SearchResult>>) {
          expect(results.error, isA<Failure>());
          final error = results.error as Failure;
          expect(error.userMessage, contains('Failed to load data'));
        }
      });

      test('should handle search failure gracefully without crashing',
          () async {
        // ARRANGE
        const failure = Failure.unexpectedFailure(
          message: 'Unexpected error occurred',
        );
        when(mockSearchRepository.searchTopResults(any))
            .thenAnswer((_) async => const Left(failure));

        // ACT - Should not throw
        notifier.updateQuery('test');
        await Future.delayed(const Duration(milliseconds: 350));

        // ASSERT - App should continue functioning
        expect(notifier.state.isLoading, isFalse);
        expect(notifier.state.queryText, equals('test'));

        // User can try another search
        const successResult = GroupedSearchResult(
          resultsByType: {
            SearchResultType.title: [],
            SearchResultType.fullText: [],
            SearchResultType.definition: [],
          },
        );
        when(mockSearchRepository.searchTopResults(any))
            .thenAnswer((_) async => const Right(successResult));

        notifier.updateQuery('dhamma');
        await Future.delayed(const Duration(milliseconds: 350));

        expect(notifier.state.categorizedResults, isNotNull);
      });

      test('should cancel debounced search when query changes rapidly',
          () async {
        // ARRANGE
        var callCount = 0;
        when(mockSearchRepository.searchTopResults(any))
            .thenAnswer((_) async {
          callCount++;
          return const Right(GroupedSearchResult(
            resultsByType: {
              SearchResultType.title: [],
              SearchResultType.fullText: [],
              SearchResultType.definition: [],
            },
          ));
        });

        // ACT - Rapidly change query three times
        notifier.updateQuery('a');
        await Future.delayed(const Duration(milliseconds: 100));

        notifier.updateQuery('ab');
        await Future.delayed(const Duration(milliseconds: 100));

        notifier.updateQuery('abc');
        await Future.delayed(const Duration(milliseconds: 350)); // Wait for final debounce

        // ASSERT - Should only search once (for 'abc'), not three times
        expect(callCount, equals(1));
        expect(notifier.state.queryText, equals('abc'));
      });

      test('should handle concurrent filter changes without race conditions',
          () async {
        // ARRANGE
        const categorizedResult = GroupedSearchResult(
          resultsByType: {
            SearchResultType.title: [],
            SearchResultType.fullText: [],
            SearchResultType.definition: [],
          },
        );
        when(mockSearchRepository.searchTopResults(any))
            .thenAnswer((_) async => const Right(categorizedResult));

        notifier.updateQuery('dhamma');
        await Future.delayed(const Duration(milliseconds: 350));
        clearInteractions(mockSearchRepository);

        // ACT - Rapidly toggle filters
        notifier.toggleExactMatch();
        notifier.setLanguageFilter(pali: false);
        notifier.addNikayaFilter('dn');

        // Wait for all searches to complete
        await Future.delayed(const Duration(milliseconds: 50));

        // ASSERT - All filter changes should be reflected in final state
        expect(notifier.state.exactMatch, isTrue);
        expect(notifier.state.searchInPali, isFalse);
        expect(notifier.state.nikayaFilters, contains('dn'));

        // Should have triggered searches (one per filter change)
        verify(mockSearchRepository.searchTopResults(any))
            .called(greaterThan(0));
      });
    });
  });
}
