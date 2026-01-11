import 'package:dartz/dartz.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:the_wisdom_project/core/constants/constants.dart';
import 'package:the_wisdom_project/domain/entities/failure.dart';
import 'package:the_wisdom_project/domain/entities/search/grouped_search_result.dart';
import 'package:the_wisdom_project/domain/entities/search/recent_search.dart';
import 'package:the_wisdom_project/domain/entities/search/search_result_type.dart';
import 'package:the_wisdom_project/domain/entities/search/search_result.dart';
import 'package:the_wisdom_project/domain/entities/search/search_scope_chip.dart';
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
        expect(notifier.state.rawQueryText, equals('dhamma'));
      });

      test('should clear results for empty queries', () {
        // ARRANGE - first set up some results
        notifier.updateQuery('dhamma');

        // ACT - clear to empty
        notifier.updateQuery('');

        // ASSERT
        expect(notifier.state.groupedResults, isNull);
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

    group('selectResultType', () {
      test('should update selected category', () async {
        // ARRANGE
        when(mockSearchRepository.searchByResultType(any, any))
            .thenAnswer((_) async => const Right([]));

        notifier.updateQuery('test');

        // ACT
        await notifier.selectResultType(SearchResultType.fullText);

        // ASSERT
        expect(notifier.state.selectedResultType,
            equals(SearchResultType.fullText));
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
        await notifier.selectResultType(SearchResultType.title);
        clearInteractions(mockSearchRepository);

        // ACT - Switch back to "all" category
        await notifier.selectResultType(SearchResultType.topResults);

        // ASSERT
        verify(mockSearchRepository.searchTopResults(any)).called(1);
      });

      test('should load full results for specific category', () async {
        // ARRANGE
        when(mockSearchRepository.searchByResultType(any, any))
            .thenAnswer((_) async => const Right([]));

        notifier.updateQuery('test');

        // ACT
        await notifier.selectResultType(SearchResultType.fullText);

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
        await notifier.selectResultType(SearchResultType.topResults);

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
      test('should toggle isExactMatch flag on and off', () {
        // ARRANGE - Initial state has isExactMatch=false
        expect(notifier.state.isExactMatch, isFalse);

        // ACT - Toggle to true
        notifier.toggleExactMatch();

        // ASSERT
        expect(notifier.state.isExactMatch, isTrue);

        // ACT - Toggle back to false
        notifier.toggleExactMatch();

        // ASSERT
        expect(notifier.state.isExactMatch, isFalse);
      });

      test('should refresh search when toggling with active query', () {
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

          notifier.updateQuery('dhamma');
          async.elapse(const Duration(milliseconds: 350)); // Wait for debounce
          clearInteractions(mockSearchRepository);

          // ACT - Toggle exact match
          notifier.toggleExactMatch();

          // ASSERT - Should trigger new search
          verify(mockSearchRepository.searchTopResults(any)).called(1);
        });
      });

      test('should not refresh search when toggling with empty query', () {
        // ARRANGE - Empty query
        expect(notifier.state.rawQueryText, isEmpty);

        // ACT - Toggle exact match
        notifier.toggleExactMatch();

        // ASSERT - No search triggered
        verifyNever(mockSearchRepository.searchTopResults(any));
      });

      test('should include isExactMatch in built SearchQuery', () {
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

          // Use Sinhala input directly to avoid transliteration dependency
          notifier.updateQuery('ධම්ම');
          notifier.toggleExactMatch(); // Set isExactMatch to true

          async.elapse(const Duration(milliseconds: 350)); // Wait for debounce

          // ASSERT - Verify the SearchQuery passed has isExactMatch=true
          final captured = verify(
            mockSearchRepository.searchTopResults(captureAny),
          ).captured;

          expect(captured.length, greaterThan(0));
          final query = captured.last;
          expect(query.isExactMatch, isTrue);
          expect(query.queryText, equals('ධම්ම'));
        });
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

      test('setScope should set scope filter', () {
        // ACT
        notifier.setScope(
            {TipitakaNodeKeys.suttaPitaka, TipitakaNodeKeys.vinayaPitaka});

        // ASSERT
        expect(
          notifier.state.scope,
          containsAll(
              [TipitakaNodeKeys.suttaPitaka, TipitakaNodeKeys.vinayaPitaka]),
        );
      });

      test('setScope should replace existing scope', () {
        // ARRANGE
        notifier.setScope(
            {TipitakaNodeKeys.suttaPitaka, TipitakaNodeKeys.vinayaPitaka});

        // ACT
        notifier.setScope({TipitakaNodeKeys.dighaNikaya});

        // ASSERT
        expect(notifier.state.scope, contains(TipitakaNodeKeys.dighaNikaya));
        expect(notifier.state.scope,
            isNot(contains(TipitakaNodeKeys.suttaPitaka)));
        expect(notifier.state.scope,
            isNot(contains(TipitakaNodeKeys.vinayaPitaka)));
      });

      test('clearFilters should reset all filters', () {
        // ARRANGE
        notifier.toggleEdition('sc');
        notifier.setLanguageFilter(pali: false);
        notifier.setScope({TipitakaNodeKeys.suttaPitaka});

        // ACT
        notifier.clearFilters();

        // ASSERT
        expect(notifier.state.selectedEditions, isEmpty);
        expect(notifier.state.searchInPali, isTrue);
        expect(notifier.state.searchInSinhala, isTrue);
        expect(notifier.state.scope, isEmpty);
      });
    });

    group('Scope selection (Pattern 2: All as default)', () {
      // Test 1: Default state is "All" selected (empty set)
      test('should have empty scope by default (All selected)', () {
        expect(notifier.state.scope, isEmpty);
        expect(notifier.state.isAllSelected, isTrue);
      });

      // Test 2: setScope sets scope and triggers search
      test('should set scope when setScope is called', () {
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

          notifier.updateQuery('test');
          async.elapse(const Duration(milliseconds: 350));
          clearInteractions(mockSearchRepository);

          // ACT
          notifier.setScope({TipitakaNodeKeys.suttaPitaka});

          // ASSERT
          expect(notifier.state.scope, contains(TipitakaNodeKeys.suttaPitaka));
          expect(notifier.state.isAllSelected, isFalse);
          verify(mockSearchRepository.searchTopResults(any)).called(1);
        });
      });

      // Test 3: Setting empty scope means "All"
      test('should treat empty scope as All', () {
        // ARRANGE
        notifier.setScope({TipitakaNodeKeys.suttaPitaka});

        // ACT - Set to empty
        notifier.setScope({});

        // ASSERT - Should be "All"
        expect(notifier.state.scope, isEmpty);
        expect(notifier.state.isAllSelected, isTrue);
      });

      // Test 4: setScope replaces existing scope
      test('should replace existing scope with new scope', () {
        // ARRANGE
        notifier.setScope(
            {TipitakaNodeKeys.suttaPitaka, TipitakaNodeKeys.vinayaPitaka});
        expect(notifier.state.scope.length, equals(2));

        // ACT
        notifier.setScope({TipitakaNodeKeys.dighaNikaya});

        // ASSERT
        expect(notifier.state.scope, contains(TipitakaNodeKeys.dighaNikaya));
        expect(notifier.state.scope,
            isNot(contains(TipitakaNodeKeys.suttaPitaka)));
        expect(notifier.state.scope.length, equals(1));
      });

      // Test 5: selectAll clears scope
      test('should clear scope when selectAll is called', () {
        // ARRANGE
        notifier.setScope(
            {TipitakaNodeKeys.suttaPitaka, TipitakaNodeKeys.vinayaPitaka});
        expect(notifier.state.scope, isNotEmpty);

        // ACT
        notifier.selectAll();

        // ASSERT
        expect(notifier.state.scope, isEmpty);
        expect(notifier.state.isAllSelected, isTrue);
      });

      // Test 6: Scope included in SearchQuery
      test('should include scope in built SearchQuery', () {
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

          notifier.setScope(
              {TipitakaNodeKeys.suttaPitaka, TipitakaNodeKeys.vinayaPitaka});
          notifier.updateQuery('ධම්ම'); // Use Sinhala to avoid transliteration
          async.elapse(const Duration(milliseconds: 350));

          // ASSERT - Verify SearchQuery has correct scope
          final captured = verify(
            mockSearchRepository.searchTopResults(captureAny),
          ).captured;

          expect(captured.length, greaterThan(0));
          final query = captured.last;
          expect(
              query.scope,
              containsAll([
                TipitakaNodeKeys.suttaPitaka,
                TipitakaNodeKeys.vinayaPitaka
              ]));
        });
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
        expect(notifier.state.rawQueryText, isEmpty);
        expect(notifier.state.groupedResults, isNull);
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
        expect(notifier.state.rawQueryText, equals('test'));
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
                  RecentSearch(
                      queryText: 'test query', timestamp: DateTime.now()),
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
        expect(notifier.state.rawQueryText,
            equals('test query')); // Text preserved
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
        expect(
            notifier.state.recentSearches[0].queryText, equals('test query'));
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
        expect(notifier.state.rawQueryText, equals('dhamma'));
        expect(notifier.state.isResultsPanelVisible, isTrue);
        verify(mockSearchRepository.searchTopResults(any)).called(1);
        verify(mockRecentSearchesRepository.addRecentSearch('dhamma'))
            .called(1);
      });
    });

    group('Error handling', () {
      test('should clear results when categorized search fails', () {
        fakeAsync((async) {
          // ARRANGE
          const failure = Failure.dataLoadFailure(
            message: 'Database connection failed',
          );
          when(mockSearchRepository.searchTopResults(any))
              .thenAnswer((_) async => const Left(failure));

          // ACT
          notifier.updateQuery('test');
          async.elapse(const Duration(milliseconds: 350)); // Wait for debounce

          // ASSERT
          expect(notifier.state.isLoading, isFalse);
          expect(notifier.state.groupedResults, isNull);
          expect(notifier.state.rawQueryText,
              equals('test')); // Query text preserved
        });
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
        await notifier.selectResultType(SearchResultType.fullText);

        // ASSERT
        expect(notifier.state.isLoading, isFalse);

        // Check that fullResults is in error state
        final results = notifier.state.fullResults;
        expect(results, isA<AsyncError<List<SearchResult>?>>());

        // Access error from AsyncError
        if (results is AsyncError<List<SearchResult>?>) {
          expect(results.error, isA<Failure>());
          final error = results.error as Failure;
          expect(error.userMessage, contains('Failed to load data'));
        }
      });

      test('should handle search failure gracefully without crashing', () {
        fakeAsync((async) {
          // ARRANGE
          const failure = Failure.unexpectedFailure(
            message: 'Unexpected error occurred',
          );
          when(mockSearchRepository.searchTopResults(any))
              .thenAnswer((_) async => const Left(failure));

          // ACT - Should not throw
          notifier.updateQuery('test');
          async.elapse(const Duration(milliseconds: 350));

          // ASSERT - App should continue functioning
          expect(notifier.state.isLoading, isFalse);
          expect(notifier.state.rawQueryText, equals('test'));

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
          async.elapse(const Duration(milliseconds: 350));

          expect(notifier.state.groupedResults, isNotNull);
        });
      });

      test('should cancel debounced search when query changes rapidly', () {
        fakeAsync((async) {
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
          async.elapse(const Duration(milliseconds: 100));

          notifier.updateQuery('ab');
          async.elapse(const Duration(milliseconds: 100));

          notifier.updateQuery('abc');
          async.elapse(
              const Duration(milliseconds: 350)); // Wait for final debounce

          // ASSERT - Should only search once (for 'abc'), not three times
          expect(callCount, equals(1));
          expect(notifier.state.rawQueryText, equals('abc'));
        });
      });

      test('should handle concurrent filter changes without race conditions',
          () {
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

          notifier.updateQuery('dhamma');
          async.elapse(const Duration(milliseconds: 350));
          clearInteractions(mockSearchRepository);

          // ACT - Rapidly toggle filters
          notifier.toggleExactMatch();
          notifier.setLanguageFilter(pali: false);
          notifier.setScope({TipitakaNodeKeys.suttaPitaka});

          // Wait for all searches to complete
          async.elapse(const Duration(milliseconds: 50));

          // ASSERT - All filter changes should be reflected in final state
          expect(notifier.state.isExactMatch, isTrue);
          expect(notifier.state.searchInPali, isFalse);
          expect(notifier.state.scope, contains(TipitakaNodeKeys.suttaPitaka));

          // Should have triggered searches (one per filter change)
          verify(mockSearchRepository.searchTopResults(any))
              .called(greaterThan(0));
        });
      });
    });

    group('setPhraseSearch', () {
      test('should have isPhraseSearch=true by default', () {
        expect(notifier.state.isPhraseSearch, isTrue);
      });

      test('should update isPhraseSearch state', () {
        // ACT
        notifier.setPhraseSearch(false);

        // ASSERT
        expect(notifier.state.isPhraseSearch, isFalse);
      });

      test('should trigger search refresh when query is active', () {
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

          notifier.updateQuery('dhamma');
          async.elapse(const Duration(milliseconds: 350));
          clearInteractions(mockSearchRepository);

          // ACT
          notifier.setPhraseSearch(false);

          // ASSERT
          verify(mockSearchRepository.searchTopResults(any)).called(1);
        });
      });

      test('should include isPhraseSearch in built SearchQuery', () {
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

          notifier.setPhraseSearch(false);
          notifier.updateQuery('ධම්ම');
          async.elapse(const Duration(milliseconds: 350));

          // ASSERT
          final captured = verify(
            mockSearchRepository.searchTopResults(captureAny),
          ).captured;

          expect(captured.length, greaterThan(0));
          final query = captured.last;
          expect(query.isPhraseSearch, isFalse);
        });
      });
    });

    group('setAnywhereInText', () {
      test('should have isAnywhereInText=false by default', () {
        expect(notifier.state.isAnywhereInText, isFalse);
      });

      test('should update isAnywhereInText state', () {
        // ACT
        notifier.setAnywhereInText(true);

        // ASSERT
        expect(notifier.state.isAnywhereInText, isTrue);
      });

      test('should trigger search refresh when query is active', () {
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

          notifier.updateQuery('dhamma');
          async.elapse(const Duration(milliseconds: 350));
          clearInteractions(mockSearchRepository);

          // ACT
          notifier.setAnywhereInText(true);

          // ASSERT
          verify(mockSearchRepository.searchTopResults(any)).called(1);
        });
      });

      test('should include isAnywhereInText in built SearchQuery', () {
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

          notifier.setAnywhereInText(true);
          notifier.updateQuery('ධම්ම');
          async.elapse(const Duration(milliseconds: 350));

          // ASSERT
          final captured = verify(
            mockSearchRepository.searchTopResults(captureAny),
          ).captured;

          expect(captured.length, greaterThan(0));
          final query = captured.last;
          expect(query.isAnywhereInText, isTrue);
        });
      });
    });

    group('setProximityDistance', () {
      test('should have proximityDistance=10 by default', () {
        expect(notifier.state.proximityDistance, equals(10));
      });

      test('should update proximityDistance state', () {
        // ACT
        notifier.setProximityDistance(5);

        // ASSERT
        expect(notifier.state.proximityDistance, equals(5));
      });

      test('should trigger search refresh when query is active', () {
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

          notifier.updateQuery('dhamma');
          async.elapse(const Duration(milliseconds: 350));
          clearInteractions(mockSearchRepository);

          // ACT
          notifier.setProximityDistance(5);

          // ASSERT
          verify(mockSearchRepository.searchTopResults(any)).called(1);
        });
      });

      test('should include proximityDistance in built SearchQuery', () {
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

          notifier.setProximityDistance(25);
          notifier.updateQuery('ධම්ම');
          async.elapse(const Duration(milliseconds: 350));

          // ASSERT
          final captured = verify(
            mockSearchRepository.searchTopResults(captureAny),
          ).captured;

          expect(captured.length, greaterThan(0));
          final query = captured.last;
          expect(query.proximityDistance, equals(25));
        });
      });
    });

    group('toggleChipScope', () {
      test('should add chip nodeKeys when chip is not selected', () {
        // ARRANGE
        expect(notifier.state.scope, isEmpty);
        final suttaChip = searchScopeChips.firstWhere((c) => c.id == 'sutta');

        // ACT
        notifier.toggleChipScope(suttaChip);

        // ASSERT
        expect(notifier.state.scope, containsAll(suttaChip.nodeKeys));
      });

      test('should remove chip nodeKeys when chip is already selected', () {
        // ARRANGE
        final suttaChip = searchScopeChips.firstWhere((c) => c.id == 'sutta');
        notifier.toggleChipScope(suttaChip);
        expect(notifier.state.scope, isNotEmpty);

        // ACT
        notifier.toggleChipScope(suttaChip);

        // ASSERT
        expect(notifier.state.scope, isEmpty);
      });

      test('should allow multi-select of chips', () {
        // ARRANGE
        final suttaChip = searchScopeChips.firstWhere((c) => c.id == 'sutta');
        final vinayaChip = searchScopeChips.firstWhere((c) => c.id == 'vinaya');

        // ACT
        notifier.toggleChipScope(suttaChip);
        notifier.toggleChipScope(vinayaChip);

        // ASSERT - Both chips should be selected
        expect(notifier.state.scope, containsAll(suttaChip.nodeKeys));
        expect(notifier.state.scope, containsAll(vinayaChip.nodeKeys));
      });
    });
  });
}
