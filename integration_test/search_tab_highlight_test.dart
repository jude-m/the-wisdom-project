/// Search + Tab + FTS Highlight Lifecycle Integration Test
///
/// Verifies the full lifecycle of FTS highlights across tab operations:
/// searching, opening FTS/Title results, navigator-based opening,
/// switching tabs, clearing highlights via tap, and closing tabs.
///
/// Run with:
///   flutter test integration_test/search_tab_highlight_test.dart -d macos
///
/// Or via all_tests.dart:
///   flutter test integration_test/all_tests.dart -d macos
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_wisdom_project/core/localization/l10n/app_localizations.dart';
import 'package:the_wisdom_project/data/datasources/bjt_document_local_datasource.dart';
import 'package:the_wisdom_project/domain/entities/search/search_result_type.dart';
import 'package:the_wisdom_project/presentation/providers/document_provider.dart';
import 'package:the_wisdom_project/presentation/providers/fts_highlight_provider.dart';
import 'package:the_wisdom_project/presentation/providers/navigation_tree_provider.dart';
import 'package:the_wisdom_project/presentation/providers/search_provider.dart';
import 'package:the_wisdom_project/presentation/providers/tab_provider.dart';
import 'package:the_wisdom_project/presentation/widgets/multi_pane_reader_widget.dart';
import 'package:the_wisdom_project/presentation/widgets/search/search_bar.dart'
    as app;
import 'package:the_wisdom_project/presentation/widgets/search/search_results_panel.dart';
import 'package:the_wisdom_project/presentation/widgets/tab_bar_widget.dart';
import 'package:the_wisdom_project/presentation/widgets/tree_navigator_widget.dart';

import 'test_overrides.dart';

// ---------------------------------------------------------------------------
// Test widget: Combines Search + Reader + TabBar with highlight logic
// ---------------------------------------------------------------------------

/// Mirrors ReaderScreen's layout and highlight logic for testing the
/// search → tab → FTS highlight lifecycle.
class _SearchTabTestWidget extends ConsumerStatefulWidget {
  const _SearchTabTestWidget();

  @override
  ConsumerState<_SearchTabTestWidget> createState() =>
      _SearchTabTestWidgetState();
}

class _SearchTabTestWidgetState extends ConsumerState<_SearchTabTestWidget> {
  /// Replicates ReaderScreen._handleSearchResultTap():
  /// Opens a tab from search result, sets FTS highlight for fullText results,
  /// then saves recent search and dismisses the panel.
  void _handleSearchResultTap(result) {
    // Open tab from search result
    ref.read(openTabFromSearchResultProvider)(result);

    // Set FTS highlight only for full text results
    if (result.resultType == SearchResultType.fullText) {
      final tabIndex = ref.read(activeTabIndexProvider);
      final searchState = ref.read(searchStateProvider);
      ref.read(ftsHighlightProvider.notifier).setForTab(
        tabIndex,
        FtsHighlightState(
          queryText: searchState.effectiveQueryText,
          isPhraseSearch: searchState.isPhraseSearch,
          isExactMatch: searchState.isExactMatch,
        ),
      );
    }

    // Save to recent searches and dismiss panel
    ref.read(searchStateProvider.notifier).saveRecentSearchAndDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchStateProvider);

    return Scaffold(
      appBar: AppBar(
        actions: const [app.SearchBar(width: 400)],
      ),
      body: Stack(
        children: [
          // Base layer: tree navigator + tabs + reader
          const Row(
            children: [
              SizedBox(width: 250, child: TreeNavigatorWidget()),
              Expanded(
                child: Column(
                  children: [
                    TabBarWidget(),
                    Expanded(child: MultiPaneReaderWidget()),
                  ],
                ),
              ),
            ],
          ),

          // Search results overlay
          if (searchState.isResultsPanelVisible)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 400,
              child: SearchResultsPanel(
                onClose: () => ref
                    .read(searchStateProvider.notifier)
                    .dismissResultsPanel(),
                onResultTap: _handleSearchResultTap,
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helper: wait for search results to finish loading
// ---------------------------------------------------------------------------

/// Polls until the CircularProgressIndicator disappears (30 s timeout).
Future<void> _waitForSearchResults(WidgetTester tester) async {
  const maxWait = Duration(seconds: 30);
  final deadline = DateTime.now().add(maxWait);

  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
      return;
    }
  }
  fail('_waitForSearchResults timed out after $maxWait');
}

// ---------------------------------------------------------------------------
// Test
// ---------------------------------------------------------------------------

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('Search + Tab + FTS Highlight Lifecycle', () {
    testWidgets(
      'FTS highlight lifecycle across search, tabs, and close',
      (tester) async {
        // ---- SETUP ----
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              bjtDocumentDataSourceProvider
                  .overrideWithValue(BJTDocumentLocalDataSourceImpl()),
              keyValueStoreOverride(),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: _SearchTabTestWidget(),
            ),
          ),
        );

        final container = ProviderScope.containerOf(
          tester.element(find.byType(MaterialApp)),
        );

        // Wait for the navigation tree to load (needed for nodeByKeyProvider)
        await container.read(navigationTreeProvider.future);
        await tester.pumpAndSettle();

        // ================================================================
        // STEP 1: Search "mahaasathi" → verify counts
        // ================================================================
        await tester.enterText(find.byType(TextField), 'mahaasathi');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await _waitForSearchResults(tester);

        final counts = container.read(searchStateProvider).countByResultType;
        expect(
          counts[SearchResultType.fullText],
          greaterThan(0),
          reason: 'Step 1: FTS count should be > 0',
        );
        expect(
          counts[SearchResultType.title],
          greaterThan(0),
          reason: 'Step 1: Title count should be > 0',
        );

        // ================================================================
        // STEP 2: Switch to "Full text" tab, tap first result
        //         → FTS highlight set for tab 0, 1 tab open
        // ================================================================
        await tester.tap(find.text('Full text'));
        await tester.pumpAndSettle();
        await _waitForSearchResults(tester);

        // Tap the first ListTile (search result)
        final ftsListTiles = find.byType(ListTile);
        expect(ftsListTiles, findsWidgets, reason: 'Step 2: FTS results visible');
        await tester.tap(ftsListTiles.first);
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Verify: 1 tab open, FTS highlight set for tab 0
        expect(
          container.read(tabsProvider).length,
          1,
          reason: 'Step 2: Should have 1 tab',
        );
        expect(
          container.read(ftsHighlightProvider).containsKey(0),
          isTrue,
          reason: 'Step 2: ftsHighlightProvider should have entry for tab 0',
        );

        // ================================================================
        // STEP 3: Reopen search panel, switch to "Titles", tap first result
        //         → 2 tabs, ftsHighlight has key 0 only
        // ================================================================

        // Panel was dismissed in step 2 but results are still loaded.
        // Re-focus the search bar to reopen the panel (sets isPanelDismissed: false).
        await tester.tap(find.byType(TextField));
        await tester.pumpAndSettle();

        // Switch to Titles tab in search results (results already loaded)
        await tester.tap(find.text('Titles'));
        await tester.pumpAndSettle();
        await _waitForSearchResults(tester);

        // Tap the first Title result
        final titleListTiles = find.byType(ListTile);
        expect(
          titleListTiles,
          findsWidgets,
          reason: 'Step 3: Title results visible',
        );
        await tester.tap(titleListTiles.first);
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Verify: 2 tabs open
        expect(
          container.read(tabsProvider).length,
          2,
          reason: 'Step 3: Should have 2 tabs',
        );

        // FTS highlight map should have key 0 only (not key 1, since title
        // results don't set FTS highlights)
        final highlightMap3 = container.read(ftsHighlightProvider);
        expect(
          highlightMap3.containsKey(0),
          isTrue,
          reason: 'Step 3: Tab 0 (FTS) should still have highlight',
        );
        expect(
          highlightMap3.containsKey(1),
          isFalse,
          reason: 'Step 3: Tab 1 (Title) should NOT have highlight',
        );

        // ================================================================
        // STEP 4: Switch to FTS tab (tab 0) via switchTabProvider
        //         → activeFtsHighlightProvider != null
        // ================================================================
        container.read(switchTabProvider)(0);
        await tester.pumpAndSettle();

        expect(
          container.read(activeTabIndexProvider),
          0,
          reason: 'Step 4: Active tab should be 0',
        );
        expect(
          container.read(activeFtsHighlightProvider),
          isNotNull,
          reason: 'Step 4: Active FTS highlight should exist for FTS tab',
        );

        // ================================================================
        // STEP 5: Open "dn-2-9" (Mahasatipatthana Sutta) via
        //         openTabFromNodeKeyProvider → 3 tabs, no active FTS highlight
        // ================================================================
        final newIndex =
            container.read(openTabFromNodeKeyProvider)('dn-2-9');
        expect(
          newIndex,
          greaterThanOrEqualTo(0),
          reason: 'Step 5: Node dn-2-9 should be found in tree',
        );
        await tester.pumpAndSettle(const Duration(seconds: 2));

        expect(
          container.read(tabsProvider).length,
          3,
          reason: 'Step 5: Should have 3 tabs',
        );
        expect(
          container.read(activeFtsHighlightProvider),
          isNull,
          reason:
              'Step 5: Navigator-opened tab should have no FTS highlight',
        );

        // ================================================================
        // STEP 6: Switch back to FTS tab (tab 0)
        //         → activeFtsHighlightProvider != null (highlight persisted)
        // ================================================================
        container.read(switchTabProvider)(0);
        await tester.pumpAndSettle();

        expect(
          container.read(activeFtsHighlightProvider),
          isNotNull,
          reason: 'Step 6: FTS tab highlight should persist after switching back',
        );

        // ================================================================
        // STEP 7: Clear highlight for active tab (simulates reader tap)
        //         → activeFtsHighlightProvider == null, map empty
        // ================================================================
        container.read(ftsHighlightProvider.notifier).clearForActiveTab();
        await tester.pump();

        expect(
          container.read(activeFtsHighlightProvider),
          isNull,
          reason: 'Step 7: Active FTS highlight should be null after clear',
        );
        expect(
          container.read(ftsHighlightProvider),
          isEmpty,
          reason: 'Step 7: FTS highlight map should be empty',
        );

        // ================================================================
        // STEP 8: Close FTS tab (tab 0) via close button in TabBarWidget
        //         → map empty, 2 remaining tabs, active index in bounds
        // ================================================================

        // Tab 0 is active. Find close buttons — one per tab (3 tabs).
        // The first close button corresponds to tab 0.
        final closeButtons = find.byIcon(Icons.close);
        expect(
          closeButtons,
          findsNWidgets(3),
          reason: 'Step 8: Should find 3 close buttons (one per tab)',
        );
        await tester.tap(closeButtons.first);
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Verify: 2 tabs remaining, map still empty, active index in bounds
        final remainingTabs = container.read(tabsProvider);
        expect(
          remainingTabs.length,
          2,
          reason: 'Step 8: Should have 2 tabs after closing FTS tab',
        );
        expect(
          container.read(ftsHighlightProvider),
          isEmpty,
          reason: 'Step 8: FTS highlight map should still be empty',
        );

        final activeIndex = container.read(activeTabIndexProvider);
        expect(
          activeIndex,
          greaterThanOrEqualTo(0),
          reason: 'Step 8: Active index should be >= 0',
        );
        expect(
          activeIndex,
          lessThan(remainingTabs.length),
          reason: 'Step 8: Active index should be within bounds',
        );
      },
    );
  });
}
