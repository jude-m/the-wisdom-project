import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_wisdom_project/domain/entities/search/categorized_search_result.dart';
import 'package:the_wisdom_project/domain/entities/search/recent_search.dart';
import 'package:the_wisdom_project/domain/entities/search/search_category.dart';
import 'package:the_wisdom_project/domain/entities/search/search_result.dart';
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

      // Enter text
      await tester.enterText(find.byType(TextField), 'dhamma');
      await tester.pump();

      // ACT - Press clear button
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();

      // ASSERT
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, isEmpty);
    });

    testWidgets('should call onResultTap when result is tapped',
        (tester) async {
      // ARRANGE
      SearchResult? tappedResult;
      final result = SearchResult(
        id: 'test_id',
        editionId: 'bjt',
        category: SearchCategory.title,
        title: 'Brahmajālasutta',
        subtitle: 'Dīgha Nikāya',
        matchedText: '',
        contentFileId: 'dn-1',
        pageIndex: 0,
        entryIndex: 0,
        nodeKey: 'dn-1',
        language: 'pali',
      );

      final previewResults = CategorizedSearchResult(
        resultsByCategory: {
          SearchCategory.title: [result],
          SearchCategory.content: [],
          SearchCategory.definition: [],
        },
        totalCount: 1,
      );

      when(mockRecentSearchesRepository.getRecentSearches())
          .thenAnswer((_) async => []);
      when(mockSearchRepository.searchCategorizedPreview(any))
          .thenAnswer((_) async => Right(previewResults));

      await tester.pumpApp(
        app_search.SearchBar(
          onResultTap: (r) => tappedResult = r,
        ),
        overrides: [
          TestProviderOverrides.sharedPreferences(prefs),
          TestProviderOverrides.textSearchRepository(mockSearchRepository),
          TestProviderOverrides.recentSearchesRepository(
              mockRecentSearchesRepository),
        ],
      );
      await tester.pumpAndSettle();

      // Focus and enter search
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'brahma');
      await tester.pumpAndSettle(
          const Duration(milliseconds: 400)); // Wait for debounce

      // ACT - Tap on result
      await tester.tap(find.text('Brahmajālasutta'));
      await tester.pumpAndSettle();

      // ASSERT
      expect(tappedResult, isNotNull);
      expect(tappedResult?.title, equals('Brahmajālasutta'));
    });
  });
}
