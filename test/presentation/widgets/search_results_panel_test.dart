import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_wisdom_project/domain/entities/search/grouped_search_result.dart';
import 'package:the_wisdom_project/domain/entities/search/search_result_type.dart';
import 'package:the_wisdom_project/domain/entities/search/search_result.dart';
import 'package:the_wisdom_project/presentation/providers/search_provider.dart';
import 'package:the_wisdom_project/presentation/providers/search_state.dart';
import 'package:the_wisdom_project/presentation/widgets/search_results_panel.dart';

/// Fake implementation for testing
class FakeSearchStateNotifier extends StateNotifier<SearchState>
    implements SearchStateNotifier {
  FakeSearchStateNotifier(super.state);

  SearchResultType? lastSelectedResultType;

  @override
  Future<void> selectResultType(SearchResultType category) async {
    lastSelectedResultType = category;
    state = state.copyWith(selectedResultType: category);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('SearchResultsPanel -', () {
    testWidgets('should render header with query text', (tester) async {
      // ARRANGE
      final notifier = FakeSearchStateNotifier(
        const SearchState(queryText: 'metta'),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            searchStateProvider.overrideWith((ref) => notifier),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SearchResultsPanel(
                onClose: () {},
              ),
            ),
          ),
        ),
      );

      // ASSERT
      expect(find.text('Results for "metta"'), findsOneWidget);
    });

    testWidgets('should show loading indicator when isLoading is true',
        (tester) async {
      // ARRANGE - "All" tab uses isLoading, not fullResults.loading()
      final notifier = FakeSearchStateNotifier(
        const SearchState(
          queryText: 'test',
          isLoading: true,
          selectedResultType: SearchResultType.topResults,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            searchStateProvider.overrideWith((ref) => notifier),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SearchResultsPanel(
                onClose: () {},
              ),
            ),
          ),
        ),
      );

      // ASSERT
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets(
        'should show loading indicator when fullResults is loading for specific category',
        (tester) async {
      // ARRANGE - Specific category tabs use fullResults
      final notifier = FakeSearchStateNotifier(
        const SearchState(
          queryText: 'test',
          selectedResultType: SearchResultType.title,
          fullResults: AsyncValue.loading(),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            searchStateProvider.overrideWith((ref) => notifier),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SearchResultsPanel(
                onClose: () {},
              ),
            ),
          ),
        ),
      );

      // ASSERT
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should show error state with retry button', (tester) async {
      // ARRANGE - Use a specific category since "All" tab doesn't use fullResults
      final notifier = FakeSearchStateNotifier(
        SearchState(
          queryText: 'test',
          selectedResultType: SearchResultType.title,
          fullResults: AsyncValue.error(
            Exception('Test error'),
            StackTrace.current,
          ),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            searchStateProvider.overrideWith((ref) => notifier),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SearchResultsPanel(
                onClose: () {},
              ),
            ),
          ),
        ),
      );

      // ASSERT
      expect(find.text('Failed to load results'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('should show empty state when no results for "All" tab',
        (tester) async {
      // ARRANGE - "All" tab uses categorizedResults
      final notifier = FakeSearchStateNotifier(
        const SearchState(
          queryText: 'test',
          selectedResultType: SearchResultType.topResults,
          groupedResults: GroupedSearchResult(
            resultsByType: {},
          ),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            searchStateProvider.overrideWith((ref) => notifier),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SearchResultsPanel(
                onClose: () {},
              ),
            ),
          ),
        ),
      );

      // ASSERT
      expect(find.text('No results found'), findsOneWidget);
      expect(find.byIcon(Icons.search_off), findsOneWidget);
    });

    testWidgets('should show empty state when no results for specific category',
        (tester) async {
      // ARRANGE
      final notifier = FakeSearchStateNotifier(
        const SearchState(
          queryText: 'test',
          fullResults: AsyncValue.data([]),
          selectedResultType: SearchResultType.title,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            searchStateProvider.overrideWith((ref) => notifier),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SearchResultsPanel(
                onClose: () {},
              ),
            ),
          ),
        ),
      );

      // ASSERT - uses displayName.toLowerCase(): 'No titles found'
      expect(find.text('No titles found'), findsOneWidget);
      expect(find.byIcon(Icons.search_off), findsOneWidget);
    });

    testWidgets('should render category tab bar with 4 tabs', (tester) async {
      // ARRANGE
      final notifier = FakeSearchStateNotifier(
        const SearchState(queryText: 'test'),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            searchStateProvider.overrideWith((ref) => notifier),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SearchResultsPanel(
                onClose: () {},
              ),
            ),
          ),
        ),
      );

      // ASSERT - Now 4 tabs: Top Results, Titles, Full text, Definitions
      expect(find.text('Top Results'), findsOneWidget);
      expect(find.text('Titles'), findsOneWidget);
      expect(find.text('Full text'), findsOneWidget);
      expect(find.text('Definitions'), findsOneWidget);
    });

    testWidgets('should call selectResultType when tab is tapped',
        (tester) async {
      // ARRANGE
      final notifier = FakeSearchStateNotifier(
        const SearchState(
          queryText: 'test',
          selectedResultType: SearchResultType.topResults,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            searchStateProvider.overrideWith((ref) => notifier),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SearchResultsPanel(
                onClose: () {},
              ),
            ),
          ),
        ),
      );

      // ACT - Tap on Full text tab
      await tester.tap(find.text('Full text'));
      await tester.pumpAndSettle();

      // ASSERT
      expect(notifier.lastSelectedResultType, equals(SearchResultType.fullText));
    });

    testWidgets('should call onClose when close button tapped', (tester) async {
      // ARRANGE
      bool closeCalled = false;
      final notifier = FakeSearchStateNotifier(
        const SearchState(queryText: 'test'),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            searchStateProvider.overrideWith((ref) => notifier),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SearchResultsPanel(
                onClose: () => closeCalled = true,
              ),
            ),
          ),
        ),
      );

      // ACT - Tap close button
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      // ASSERT
      expect(closeCalled, isTrue);
    });

    testWidgets('should call onResultTap when result is tapped',
        (tester) async {
      // ARRANGE
      SearchResult? tappedResult;
      const result = SearchResult(
        id: 'test_id',
        editionId: 'bjt',
        resultType: SearchResultType.title,
        title: 'Metta Sutta',
        subtitle: 'Sutta Nipata',
        matchedText: '',
        contentFileId: 'sn-1',
        pageIndex: 0,
        entryIndex: 0,
        nodeKey: 'sn-1',
        language: 'pali',
      );

      final notifier = FakeSearchStateNotifier(
        const SearchState(
          queryText: 'metta',
          fullResults: AsyncValue.data([result]),
          selectedResultType: SearchResultType.title,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            searchStateProvider.overrideWith((ref) => notifier),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SearchResultsPanel(
                onClose: () {},
                onResultTap: (r) => tappedResult = r,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // ACT - Tap on the ListTile (result tile)
      await tester.tap(find.byType(ListTile));
      await tester.pump();

      // ASSERT
      expect(tappedResult, isNotNull);
      expect(tappedResult?.title, equals('Metta Sutta'));
    });

    testWidgets('should render search result tiles correctly', (tester) async {
      // ARRANGE
      const result = SearchResult(
        id: 'test_id',
        editionId: 'bjt',
        resultType: SearchResultType.fullText,
        title: 'Brahmajālasutta',
        subtitle: 'Dīgha Nikāya',
        matchedText: 'This is matched text',
        contentFileId: 'dn-1',
        pageIndex: 0,
        entryIndex: 5,
        nodeKey: 'dn-1',
        language: 'pali',
      );

      final notifier = FakeSearchStateNotifier(
        const SearchState(
          queryText: 'test',
          fullResults: AsyncValue.data([result]),
          selectedResultType: SearchResultType.fullText,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            searchStateProvider.overrideWith((ref) => notifier),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SearchResultsPanel(
                onClose: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // ASSERT - verify the result tile is rendered
      expect(find.byType(ListTile), findsOneWidget);
      expect(find.text('Dīgha Nikāya'),
          findsOneWidget); // Subtitle is regular Text
      expect(find.text('BJT'), findsOneWidget); // Edition badge
    });

    testWidgets('should render "All" tab with categorized results',
        (tester) async {
      // ARRANGE
      const titleResult = SearchResult(
        id: 'title_1',
        editionId: 'bjt',
        resultType: SearchResultType.title,
        title: 'Metta Sutta',
        subtitle: 'Sutta Nipata',
        matchedText: '',
        contentFileId: 'sn-1',
        pageIndex: 0,
        entryIndex: 0,
        nodeKey: 'sn-1',
        language: 'pali',
      );

      const contentResult = SearchResult(
        id: 'content_1',
        editionId: 'bjt',
        resultType: SearchResultType.fullText,
        title: 'Brahmajālasutta',
        subtitle: 'Dīgha Nikāya',
        matchedText: 'Metta karuna text',
        contentFileId: 'dn-1',
        pageIndex: 0,
        entryIndex: 5,
        nodeKey: 'dn-1',
        language: 'pali',
      );

      final notifier = FakeSearchStateNotifier(
        const SearchState(
          queryText: 'metta',
          selectedResultType: SearchResultType.topResults,
          groupedResults: GroupedSearchResult(
            resultsByType: {
              SearchResultType.title: [titleResult],
              SearchResultType.fullText: [contentResult],
            },
          ),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            searchStateProvider.overrideWith((ref) => notifier),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SearchResultsPanel(
                onClose: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // ASSERT - Both results should be visible with section headers
      expect(find.text('TITLES'), findsOneWidget);
      expect(find.text('FULL TEXT'), findsOneWidget);
      // Two ListTiles for the two results
      expect(find.byType(ListTile), findsNWidgets(2));
    });
  });
}
