import 'package:dartz/dartz.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:the_wisdom_project/domain/entities/search/categorized_search_result.dart';
import 'package:the_wisdom_project/domain/entities/search/recent_search.dart';
import 'package:the_wisdom_project/domain/entities/search/search_category.dart';
import 'package:the_wisdom_project/presentation/providers/search_mode.dart';
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
      test('should load recent searches and set mode to recentSearches',
          () async {
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
        expect(notifier.state.mode, equals(SearchMode.recentSearches));
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
        expect(notifier.state.mode, equals(SearchMode.recentSearches));
        expect(notifier.state.recentSearches, isEmpty);
      });
    });

    group('onBlur', () {
      test('should reset to idle when not in fullResults mode', () async {
        // ARRANGE
        when(mockRecentSearchesRepository.getRecentSearches())
            .thenAnswer((_) async => []);
        await notifier.onFocus();
        expect(notifier.state.mode, equals(SearchMode.recentSearches));

        // ACT
        notifier.onBlur();

        // ASSERT
        expect(notifier.state.mode, equals(SearchMode.idle));
        expect(notifier.state.previewResults, isNull);
      });

      test('should stay in fullResults mode when in fullResults', () async {
        // ARRANGE - Manually set state to fullResults
        when(mockRecentSearchesRepository.getRecentSearches())
            .thenAnswer((_) async => []);
        when(mockRecentSearchesRepository.addRecentSearch(any))
            .thenAnswer((_) async {});
        when(mockSearchRepository.searchByCategory(any, any)).thenAnswer(
          (_) async => const Right([]),
        );

        await notifier.onFocus();
        notifier.updateQuery('test query');
        await notifier.submitQuery();

        expect(notifier.state.mode, equals(SearchMode.fullResults));

        // ACT
        notifier.onBlur();

        // ASSERT - Should remain in fullResults
        expect(notifier.state.mode, equals(SearchMode.fullResults));
      });
    });

    group('updateQuery', () {
      test('should update query text', () {
        // ACT
        notifier.updateQuery('dhamma');

        // ASSERT
        expect(notifier.state.queryText, equals('dhamma'));
      });

      test('should show recentSearches for short queries (< 2 chars)', () {
        // ACT
        notifier.updateQuery('d');

        // ASSERT
        expect(notifier.state.mode, equals(SearchMode.recentSearches));
        expect(notifier.state.previewResults, isNull);
        expect(notifier.state.isPreviewLoading, isFalse);
      });

      test('should set previewLoading for valid queries', () {
        // ACT
        notifier.updateQuery('dhamma');

        // ASSERT
        expect(notifier.state.mode, equals(SearchMode.previewResults));
        expect(notifier.state.isPreviewLoading, isTrue);
      });

      test('should debounce preview search (300ms)', () {
        fakeAsync((async) {
          // ARRANGE
          final categorizedResult = CategorizedSearchResult(
            resultsByCategory: {
              SearchCategory.title: [],
              SearchCategory.content: [],
              SearchCategory.definition: [],
            },
            totalCount: 0,
          );
          when(mockSearchRepository.searchCategorizedPreview(any))
              .thenAnswer((_) async => Right(categorizedResult));

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

    group('submitQuery', () {
      test('should save to recent searches and switch to fullResults mode',
          () async {
        // ARRANGE
        when(mockRecentSearchesRepository.addRecentSearch(any))
            .thenAnswer((_) async {});
        when(mockSearchRepository.searchByCategory(any, any))
            .thenAnswer((_) async => const Right([]));

        notifier.updateQuery('test query');

        // ACT
        await notifier.submitQuery();

        // ASSERT
        expect(notifier.state.mode, equals(SearchMode.fullResults));
        verify(mockRecentSearchesRepository.addRecentSearch('test query'))
            .called(1);
        verify(mockSearchRepository.searchByCategory(any, SearchCategory.title))
            .called(1);
      });

      test('should not submit for queries < 2 chars', () async {
        // ARRANGE
        notifier.updateQuery('d');

        // ACT
        await notifier.submitQuery();

        // ASSERT
        expect(notifier.state.mode, isNot(equals(SearchMode.fullResults)));
        verifyNever(mockRecentSearchesRepository.addRecentSearch(any));
      });
    });

    group('selectCategory', () {
      test('should update selected category and load results', () async {
        // ARRANGE
        when(mockRecentSearchesRepository.addRecentSearch(any))
            .thenAnswer((_) async {});
        when(mockSearchRepository.searchByCategory(any, any))
            .thenAnswer((_) async => const Right([]));

        notifier.updateQuery('test');
        await notifier.submitQuery();

        // ACT
        await notifier.selectCategory(SearchCategory.content);

        // ASSERT
        expect(notifier.state.selectedCategory, equals(SearchCategory.content));
        verify(mockSearchRepository.searchByCategory(
                any, SearchCategory.content))
            .called(1);
      });

      test('should not reload if same category selected', () async {
        // ARRANGE
        when(mockRecentSearchesRepository.addRecentSearch(any))
            .thenAnswer((_) async {});
        when(mockSearchRepository.searchByCategory(any, any))
            .thenAnswer((_) async => const Right([]));

        notifier.updateQuery('test');
        await notifier.submitQuery();
        clearInteractions(mockSearchRepository);

        // ACT - Select same category (default is title)
        await notifier.selectCategory(SearchCategory.title);

        // ASSERT
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
        expect(notifier.state.mode, equals(SearchMode.idle));
        expect(notifier.state.previewResults, isNull);
      });
    });

    group('exitFullResults', () {
      test('should reset to idle and clear query', () async {
        // ARRANGE
        when(mockRecentSearchesRepository.addRecentSearch(any))
            .thenAnswer((_) async {});
        when(mockSearchRepository.searchByCategory(any, any))
            .thenAnswer((_) async => const Right([]));

        notifier.updateQuery('test');
        await notifier.submitQuery();
        expect(notifier.state.mode, equals(SearchMode.fullResults));

        // ACT
        notifier.exitFullResults();

        // ASSERT
        expect(notifier.state.mode, equals(SearchMode.idle));
        expect(notifier.state.queryText, isEmpty);
      });
    });
  });
}
