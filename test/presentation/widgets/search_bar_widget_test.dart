import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_wisdom_project/domain/entities/search/recent_search.dart';
import 'package:the_wisdom_project/presentation/providers/search_provider.dart';
import 'package:the_wisdom_project/presentation/providers/search_state.dart';
import 'package:the_wisdom_project/presentation/widgets/search/search_bar.dart'
    as app_search;

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

  group('SearchBar -', () {
    testWidgets('should show clear button when text is entered',
        (tester) async {
      // ARRANGE
      when(mockRecentSearchesRepository.getRecentSearches())
          .thenAnswer((_) async => []);

      await tester.pumpApp(
        const app_search.SearchBar(),
        overrides: [
          TestProviderOverrides.sharedPreferences(prefs),
          TestProviderOverrides.textSearchRepository(mockSearchRepository),
          TestProviderOverrides.recentSearchesRepository(
              mockRecentSearchesRepository),
        ],
      );
      await tester.pumpAndSettle();

      // Initially no clear button
      expect(find.byIcon(Icons.clear), findsNothing);

      // ACT - Enter text
      await tester.enterText(find.byType(TextField), 'dhamma');
      await tester.pump();

      // ASSERT
      expect(find.byIcon(Icons.clear), findsOneWidget);
    });

    testWidgets('should open overlay on focus', (tester) async {
      // ARRANGE
      final recentSearches = [
        RecentSearch(queryText: 'dhamma', timestamp: DateTime.now()),
      ];
      when(mockRecentSearchesRepository.getRecentSearches())
          .thenAnswer((_) async => recentSearches);

      await tester.pumpApp(
        const app_search.SearchBar(),
        overrides: [
          TestProviderOverrides.sharedPreferences(prefs),
          TestProviderOverrides.textSearchRepository(mockSearchRepository),
          TestProviderOverrides.recentSearchesRepository(
              mockRecentSearchesRepository),
        ],
      );
      await tester.pumpAndSettle();

      // ACT - Focus the text field
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      // ASSERT - Recent search should be visible in overlay
      expect(find.text('dhamma'), findsOneWidget);
    });

    testWidgets('should clear search state when clear button pressed',
        (tester) async {
      // ARRANGE
      when(mockRecentSearchesRepository.getRecentSearches())
          .thenAnswer((_) async => []);

      // Create a test helper to access provider state
      SearchState? capturedState;

      await tester.pumpApp(
        ProviderTestWidget(
          onBuild: (ref) {
            // Capture the current state on each rebuild
            capturedState = ref.watch(searchStateProvider);
          },
          child: const app_search.SearchBar(),
        ),
        overrides: [
          TestProviderOverrides.sharedPreferences(prefs),
          TestProviderOverrides.textSearchRepository(mockSearchRepository),
          TestProviderOverrides.recentSearchesRepository(
              mockRecentSearchesRepository),
        ],
      );
      await tester.pumpAndSettle();

      // Enter text directly (this shows clear button and triggers search state)
      await tester.enterText(find.byType(TextField), 'dhamma');
      await tester.pump();

      // Verify state is set
      expect(capturedState?.rawQueryText, equals('dhamma'));
      expect(capturedState?.isResultsPanelVisible, isTrue);

      // ACT - Press clear button with warnIfMissed: false since overlay may be present
      await tester.tap(find.byIcon(Icons.clear), warnIfMissed: false);
      await tester.pump();

      // ASSERT - Verify search state is cleared
      expect(capturedState?.rawQueryText, isEmpty);
      expect(capturedState?.groupedResults, isNull);
      expect(capturedState?.isResultsPanelVisible, isFalse);
    });

    testWidgets('should toggle exact match when toggle button pressed',
        (tester) async {
      // ARRANGE
      when(mockRecentSearchesRepository.getRecentSearches())
          .thenAnswer((_) async => []);

      // Create a test helper to access provider state
      SearchState? capturedState;

      await tester.pumpApp(
        ProviderTestWidget(
          onBuild: (ref) {
            // Capture the current state on each rebuild
            capturedState = ref.watch(searchStateProvider);
          },
          child: const app_search.SearchBar(),
        ),
        overrides: [
          TestProviderOverrides.sharedPreferences(prefs),
          TestProviderOverrides.textSearchRepository(mockSearchRepository),
          TestProviderOverrides.recentSearchesRepository(
              mockRecentSearchesRepository),
        ],
      );
      await tester.pumpAndSettle();

      // Initial state: isExactMatch should be false
      expect(capturedState?.isExactMatch, isFalse);

      // Find the exact match toggle button
      final toggleButton = find.byIcon(Icons.abc);
      expect(toggleButton, findsOneWidget);

      // ACT - Tap the toggle button
      await tester.tap(toggleButton);
      await tester.pumpAndSettle();

      // ASSERT - isExactMatch state should now be true
      expect(capturedState?.isExactMatch, isTrue);

      // ACT - Tap again to toggle off
      await tester.tap(toggleButton);
      await tester.pumpAndSettle();

      // ASSERT - isExactMatch should return to false
      expect(capturedState?.isExactMatch, isFalse);
    });

    testWidgets('should show tooltip on exact match toggle button hover',
        (tester) async {
      // ARRANGE
      when(mockRecentSearchesRepository.getRecentSearches())
          .thenAnswer((_) async => []);

      await tester.pumpApp(
        const app_search.SearchBar(),
        overrides: [
          TestProviderOverrides.sharedPreferences(prefs),
          TestProviderOverrides.textSearchRepository(mockSearchRepository),
          TestProviderOverrides.recentSearchesRepository(
              mockRecentSearchesRepository),
        ],
      );
      await tester.pumpAndSettle();

      // ACT - Long press to show tooltip (simulates hover on mobile)
      final toggleButton = find.byIcon(Icons.abc);
      await tester.longPress(toggleButton);
      await tester.pump(const Duration(milliseconds: 500));

      // ASSERT - Tooltip should be visible with localized text
      expect(find.text('Exact word match'), findsOneWidget);
    });

    // Note: Result tap functionality was moved to SearchResultsPanel
    // Test for that exists in search_results_panel_test.dart
  });
}
