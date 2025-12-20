import 'package:dartz/dartz.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:the_wisdom_project/domain/entities/search/categorized_search_result.dart';
import 'package:the_wisdom_project/domain/entities/search/recent_search.dart';
import 'package:the_wisdom_project/domain/entities/search/search_category.dart';
import 'package:the_wisdom_project/presentation/providers/search_state.dart';

import '../../helpers/mocks.mocks.dart';

void main() {
  late SearchStateNotifier notifier;
  late MockTextSearchRepository mockSearchRepository;
  late MockRecentSearchesRepository mockRecentSearchesRepository;

  setUp(() {
    mockSearchRepository = MockTextSearchRepository();
    mockRecentSearchesRepository = MockRecentSearchesRepository();
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
          const categorizedResult = CategorizedSearchResult(
            resultsByCategory: {
              SearchCategory.title: [],
              SearchCategory.content: [],
              SearchCategory.definition: [],
            },
            totalCount: 0,
          );
          when(mockSearchRepository.searchCategorizedPreview(any))
              .thenAnswer((_) async => const Right(categorizedResult));

          // ACT
          notifier.updateQuery('test');

          // ASSERT - Should not have called search yet
          verifyNever(mockSearchRepository.searchCategorizedPreview(any));

          // Fast forward less than 300ms
          async.elapse(const Duration(milliseconds: 200));
          verifyNever(mockSearchRepository.searchCategorizedPreview(any));

          // Fast forward past 300ms
          async.elapse(const Duration(milliseconds: 150));
          verify(mockSearchRepository.searchCategorizedPreview(any)).called(1);
        });
      });
    });


    group('selectCategory', () {
      test('should update selected category', () async {
        // ARRANGE
        when(mockSearchRepository.searchByCategory(any, any))
            .thenAnswer((_) async => const Right([]));

        notifier.updateQuery('test');

        // ACT
        await notifier.selectCategory(SearchCategory.content);

        // ASSERT
        expect(notifier.state.selectedCategory, equals(SearchCategory.content));
      });

      test('should load categorized results for "all" category', () async {
        // ARRANGE
        const categorizedResult = CategorizedSearchResult(
          resultsByCategory: {
            SearchCategory.title: [],
            SearchCategory.content: [],
            SearchCategory.definition: [],
          },
          totalCount: 0,
        );
        when(mockSearchRepository.searchCategorizedPreview(any))
            .thenAnswer((_) async => const Right(categorizedResult));
        when(mockSearchRepository.searchByCategory(any, any))
            .thenAnswer((_) async => const Right([]));

        notifier.updateQuery('test');

        // First switch to a different category
        await notifier.selectCategory(SearchCategory.title);
        clearInteractions(mockSearchRepository);

        // ACT - Switch back to "all" category
        await notifier.selectCategory(SearchCategory.all);

        // ASSERT
        verify(mockSearchRepository.searchCategorizedPreview(any)).called(1);
      });

      test('should load full results for specific category', () async {
        // ARRANGE
        when(mockSearchRepository.searchByCategory(any, any))
            .thenAnswer((_) async => const Right([]));

        notifier.updateQuery('test');

        // ACT
        await notifier.selectCategory(SearchCategory.content);

        // ASSERT
        verify(mockSearchRepository.searchByCategory(
                any, SearchCategory.content))
            .called(1);
      });

      test('should not reload if same category selected', () async {
        // ARRANGE
        const categorizedResult = CategorizedSearchResult(
          resultsByCategory: {
            SearchCategory.title: [],
            SearchCategory.content: [],
            SearchCategory.definition: [],
          },
          totalCount: 0,
        );
        when(mockSearchRepository.searchCategorizedPreview(any))
            .thenAnswer((_) async => const Right(categorizedResult));

        notifier.updateQuery('test');
        clearInteractions(mockSearchRepository);

        // ACT - Select same category (default is all)
        await notifier.selectCategory(SearchCategory.all);

        // ASSERT
        verifyNever(mockSearchRepository.searchCategorizedPreview(any));
        verifyNever(mockSearchRepository.searchByCategory(any, any));
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
        const categorizedResult = CategorizedSearchResult(
          resultsByCategory: {
            SearchCategory.title: [],
            SearchCategory.content: [],
            SearchCategory.definition: [],
          },
          totalCount: 0,
        );
        when(mockSearchRepository.searchCategorizedPreview(any))
            .thenAnswer((_) async => const Right(categorizedResult));
        when(mockRecentSearchesRepository.addRecentSearch(any))
            .thenAnswer((_) async {});

        // ACT
        await notifier.selectRecentSearch('dhamma');

        // ASSERT
        expect(notifier.state.queryText, equals('dhamma'));
        expect(notifier.state.isResultsPanelVisible, isTrue);
        verify(mockSearchRepository.searchCategorizedPreview(any)).called(1);
        verify(mockRecentSearchesRepository.addRecentSearch('dhamma'))
            .called(1);
      });
    });
  });
}
