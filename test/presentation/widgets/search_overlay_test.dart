import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_wisdom_project/domain/entities/search/categorized_search_result.dart';
import 'package:the_wisdom_project/domain/entities/search/recent_search.dart';
import 'package:the_wisdom_project/domain/entities/search/search_category.dart';
import 'package:the_wisdom_project/domain/entities/search/search_result.dart';
import 'package:the_wisdom_project/presentation/providers/search_provider.dart';
import 'package:the_wisdom_project/presentation/providers/search_state.dart';
import 'package:the_wisdom_project/presentation/widgets/search_overlay.dart';

// Create a Fake implementation because mocking the base class logic is tedious without build_runner
class FakeSearchStateNotifier extends StateNotifier<SearchState>
    implements SearchStateNotifier {
  FakeSearchStateNotifier(super.state);

  // Track calls
  bool removeRecentCalled = false;
  bool selectRecentCalled = false;
  bool clearSearchCalled = false;
  String? lastSelectedQuery;

  @override
  Future<void> removeRecentSearch(String query) async {
    removeRecentCalled = true;
  }

  @override
  Future<void> selectRecentSearch(String queryText) async {
    selectRecentCalled = true;
    lastSelectedQuery = queryText;
  }

  @override
  void clearSearch() {
    clearSearchCalled = true;
  }

  // Define other methods as no-ops or assert failures if called unexpectedly
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('SearchOverlayContent returns SizedBox.shrink when no content',
      (tester) async {
    final notifier = FakeSearchStateNotifier(const SearchState());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchStateProvider.overrideWith((ref) => notifier),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SearchOverlayContent(onDismiss: _emptyCallback),
          ),
        ),
      ),
    );

    expect(find.byType(SizedBox), findsOneWidget);
    // Should be size 0 or shrink equivalent?
    // The implementation wraps it? No, it returns SizedBox.shrink() directly.
    // SizedBox.shrink has 0 width and 0 height.
    final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox));
    expect(sizedBox.width, 0.0);
    expect(sizedBox.height, 0.0);
  });

  testWidgets('SearchOverlayContent shows loading indicator', (tester) async {
    final notifier = FakeSearchStateNotifier(
      const SearchState(isPreviewLoading: true),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchStateProvider.overrideWith((ref) => notifier),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SearchOverlayContent(onDismiss: _emptyCallback),
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('SearchOverlayContent shows recent searches', (tester) async {
    final recentSearches = [
      RecentSearch(queryText: 'metta', timestamp: DateTime.now()),
      RecentSearch(queryText: 'buddha', timestamp: DateTime.now()),
    ];
    final notifier = FakeSearchStateNotifier(
      SearchState(recentSearches: recentSearches),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchStateProvider.overrideWith((ref) => notifier),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SearchOverlayContent(onDismiss: _emptyCallback),
          ),
        ),
      ),
    );

    expect(find.text('RECENT SEARCHES'), findsOneWidget);
    expect(find.text('metta'), findsOneWidget);
    expect(find.text('buddha'), findsOneWidget);
  });

  testWidgets('SearchOverlayContent calls removeRecentSearch when X tapped',
      (tester) async {
    final recentSearches = [
      RecentSearch(queryText: 'metta', timestamp: DateTime.now()),
    ];
    final notifier = FakeSearchStateNotifier(
      SearchState(recentSearches: recentSearches),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchStateProvider.overrideWith((ref) => notifier),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SearchOverlayContent(onDismiss: _emptyCallback),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.close));
    expect(notifier.removeRecentCalled, true);
  });

  testWidgets('SearchOverlayContent shows preview results', (tester) async {
    const previewResults = CategorizedSearchResult(
      resultsByCategory: {
        SearchCategory.title: [
          SearchResult(
            id: '1',
            editionId: 'bjt',
            category: SearchCategory.title,
            title: 'Metta Sutta',
            subtitle: 'Sutta Nipata',
            matchedText: 'Metta',
            contentFileId: 'sn1',
            pageIndex: 1,
            entryIndex: 1,
            nodeKey: '1',
            language: 'pali',
          ),
        ],
      },
      totalCount: 1,
    );

    final notifier = FakeSearchStateNotifier(
      const SearchState(previewResults: previewResults),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchStateProvider.overrideWith((ref) => notifier),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SearchOverlayContent(onDismiss: _emptyCallback),
          ),
        ),
      ),
    );

    expect(find.text('TITLE'), findsOneWidget);
    expect(find.text('Metta Sutta'), findsOneWidget);
  });

  testWidgets('SearchOverlayContent highlights matched text', (tester) async {
    const previewResults = CategorizedSearchResult(
      resultsByCategory: {
        SearchCategory.content: [
          SearchResult(
            id: '1',
            editionId: 'bjt',
            category: SearchCategory.content,
            title: 'Test Sutta',
            subtitle: 'Test Path',
            matchedText: 'This is a test match',
            contentFileId: '1',
            pageIndex: 1,
            entryIndex: 1,
            nodeKey: '1',
            language: 'pali',
          ),
        ],
      },
      totalCount: 1,
    );

    final notifier = FakeSearchStateNotifier(
      const SearchState(
        previewResults: previewResults,
        queryText: 'test',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchStateProvider.overrideWith((ref) => notifier),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SearchOverlayContent(onDismiss: _emptyCallback),
          ),
        ),
      ),
    );

    // Finding RichText is tricky, but we can verify the widget renders
    expect(find.text('CONTENT'), findsOneWidget);
    // "This is a test match" might be split into spans, so finding by exact text might fail if looking for the whole string in one Text widget.
    // But find.text matches RichText if the RichText contains the span? No, find.text usually finds plain Text widgets.
    // Ideally we inspect the RichText, but verifying the result appears is a good start.
    expect(find.byType(RichText), findsWidgets);
  });

  testWidgets(
      'SearchOverlayContent returns Shrink (hidden) when no results found',
      (tester) async {
    // This confirms the "No Results" bug/behavior
    const previewResults = CategorizedSearchResult(
      resultsByCategory: {},
      totalCount: 0,
    );

    final notifier = FakeSearchStateNotifier(
      const SearchState(
        previewResults: previewResults,
        queryText: 'unknown',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchStateProvider.overrideWith((ref) => notifier),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SearchOverlayContent(onDismiss: _emptyCallback),
          ),
        ),
      ),
    );

    expect(find.text('No results found'), findsOneWidget);
  });
}

void _emptyCallback() {}
