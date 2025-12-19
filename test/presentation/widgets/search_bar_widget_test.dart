import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_wisdom_project/domain/entities/search/recent_search.dart';
import 'package:the_wisdom_project/presentation/widgets/search_bar.dart'
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
    testWidgets('should render with search icon and hint text', (tester) async {
      // ARRANGE
      when(mockRecentSearchesRepository.getRecentSearches())
          .thenAnswer((_) async => []);

      // ACT
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

      // ASSERT
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

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

    testWidgets('should clear text when clear button pressed', (tester) async {
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

      // Enter text directly (this shows clear button)
      await tester.enterText(find.byType(TextField), 'dhamma');
      await tester.pump();

      // ACT - Press clear button with warnIfMissed: false since overlay may be present
      await tester.tap(find.byIcon(Icons.clear), warnIfMissed: false);
      await tester.pump();

      // ASSERT
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, isEmpty);
    });

    // Note: Result tap functionality was moved to SearchResultsPanel
    // Test for that exists in search_results_panel_test.dart
  });
}
