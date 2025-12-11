import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_wisdom_project/domain/entities/search/recent_search.dart';
import 'package:the_wisdom_project/presentation/providers/search_provider.dart';
import 'package:the_wisdom_project/presentation/providers/search_state.dart';
import 'package:the_wisdom_project/presentation/widgets/search_overlay.dart';

import '../../helpers/mocks.mocks.dart';
import '../../helpers/pump_app.dart';

void main() {
  late MockTextSearchRepository mockSearchRepository;
  late MockRecentSearchesRepository mockRecentSearchesRepository;
  late SharedPreferences prefs;

  setUp(() async {
    mockSearchRepository = MockTextSearchRepository();
    mockRecentSearchesRepository = MockRecentSearchesRepository();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('SearchOverlayContent -', () {
    testWidgets('should show SizedBox.shrink when empty state', (tester) async {
      // ARRANGE - Empty state: no recent searches, no preview results, not loading
      final notifier = SearchStateNotifier(
        mockSearchRepository,
        mockRecentSearchesRepository,
      );

      await tester.pumpApp(
        SearchOverlayContent(
          onDismiss: () {},
        ),
        overrides: [
          TestProviderOverrides.sharedPreferences(prefs),
          TestProviderOverrides.textSearchRepository(mockSearchRepository),
          TestProviderOverrides.recentSearchesRepository(
              mockRecentSearchesRepository),
          searchStateProvider.overrideWith((ref) => notifier),
        ],
      );
      await tester.pumpAndSettle();

      // ASSERT - The SearchOverlayContent widget should be in the tree
      expect(find.byType(SearchOverlayContent), findsOneWidget);
      // In empty state, it should NOT contain the overlay-specific Material (elevation: 8)
      expect(
          find.byWidgetPredicate(
            (widget) => widget is Material && widget.elevation == 8,
          ),
          findsNothing);
    });

    testWidgets('should show loading indicator when isPreviewLoading',
        (tester) async {
      // ARRANGE - Set up loading state
      when(mockRecentSearchesRepository.getRecentSearches())
          .thenAnswer((_) async => []);

      final notifier = SearchStateNotifier(
        mockSearchRepository,
        mockRecentSearchesRepository,
      );
      // Trigger loading state by typing (this sets isPreviewLoading to true)
      notifier.updateQuery('dhamma');

      await tester.pumpApp(
        SearchOverlayContent(
          onDismiss: () {},
        ),
        overrides: [
          TestProviderOverrides.sharedPreferences(prefs),
          TestProviderOverrides.textSearchRepository(mockSearchRepository),
          TestProviderOverrides.recentSearchesRepository(
              mockRecentSearchesRepository),
          searchStateProvider.overrideWith((ref) => notifier),
        ],
      );
      await tester.pump();

      // ASSERT
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should show recent searches when recentSearches not empty',
        (tester) async {
      // ARRANGE
      final recentSearches = [
        RecentSearch(queryText: 'dhamma', timestamp: DateTime.now()),
        RecentSearch(queryText: 'buddha', timestamp: DateTime.now()),
      ];
      when(mockRecentSearchesRepository.getRecentSearches())
          .thenAnswer((_) async => recentSearches);

      final notifier = SearchStateNotifier(
        mockSearchRepository,
        mockRecentSearchesRepository,
      );
      await notifier.onFocus(); // This loads recent searches

      await tester.pumpApp(
        SearchOverlayContent(
          onDismiss: () {},
        ),
        overrides: [
          TestProviderOverrides.sharedPreferences(prefs),
          TestProviderOverrides.textSearchRepository(mockSearchRepository),
          TestProviderOverrides.recentSearchesRepository(
              mockRecentSearchesRepository),
          searchStateProvider.overrideWith((ref) => notifier),
        ],
      );
      await tester.pumpAndSettle();

      // ASSERT
      expect(find.text('RECENT SEARCHES'), findsOneWidget);
      expect(find.text('dhamma'), findsOneWidget);
      expect(find.text('buddha'), findsOneWidget);
      expect(find.byIcon(Icons.history), findsNWidgets(2));
    });

    testWidgets('should call removeRecentSearch on delete button tap',
        (tester) async {
      // ARRANGE
      final recentSearches = [
        RecentSearch(queryText: 'dhamma', timestamp: DateTime.now()),
      ];
      when(mockRecentSearchesRepository.getRecentSearches())
          .thenAnswer((_) async => recentSearches);
      when(mockRecentSearchesRepository.removeRecentSearch(any))
          .thenAnswer((_) async {});

      final notifier = SearchStateNotifier(
        mockSearchRepository,
        mockRecentSearchesRepository,
      );
      await notifier.onFocus();

      await tester.pumpApp(
        SearchOverlayContent(
          onDismiss: () {},
        ),
        overrides: [
          TestProviderOverrides.sharedPreferences(prefs),
          TestProviderOverrides.textSearchRepository(mockSearchRepository),
          TestProviderOverrides.recentSearchesRepository(
              mockRecentSearchesRepository),
          searchStateProvider.overrideWith((ref) => notifier),
        ],
      );
      await tester.pumpAndSettle();

      // ACT - Tap delete button (close icon)
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // ASSERT
      verify(mockRecentSearchesRepository.removeRecentSearch('dhamma'))
          .called(1);
    });

    testWidgets('should call selectRecentSearch when tapping recent search',
        (tester) async {
      // ARRANGE
      final recentSearches = [
        RecentSearch(queryText: 'dhamma', timestamp: DateTime.now()),
      ];
      when(mockRecentSearchesRepository.getRecentSearches())
          .thenAnswer((_) async => recentSearches);
      when(mockRecentSearchesRepository.addRecentSearch(any))
          .thenAnswer((_) async {});
      when(mockSearchRepository.searchByCategory(any, any))
          .thenAnswer((_) async => const Right([]));

      final notifier = SearchStateNotifier(
        mockSearchRepository,
        mockRecentSearchesRepository,
      );
      await notifier.onFocus();

      await tester.pumpApp(
        SearchOverlayContent(
          onDismiss: () {},
        ),
        overrides: [
          TestProviderOverrides.sharedPreferences(prefs),
          TestProviderOverrides.textSearchRepository(mockSearchRepository),
          TestProviderOverrides.recentSearchesRepository(
              mockRecentSearchesRepository),
          searchStateProvider.overrideWith((ref) => notifier),
        ],
      );
      await tester.pumpAndSettle();

      // ACT - Tap on recent search text
      await tester.tap(find.text('dhamma'));
      await tester.pumpAndSettle();

      // ASSERT - Should have triggered selectRecentSearch which adds to recent
      verify(mockRecentSearchesRepository.addRecentSearch('dhamma')).called(1);
    });
  });
}
