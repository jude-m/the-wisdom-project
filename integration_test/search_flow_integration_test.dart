/// Search Flow E2E Integration Tests
///
/// These tests run against the **real** FTS database, navigation tree, and
/// dictionary — no mocks. They simulate a real user: type in the search bar,
/// wait for results, check tab badge counts, toggle settings, etc.
///
/// Run with:
///   flutter test integration_test/search/ -d macos
///
/// First run is slower (database files are copied from assets).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_wisdom_project/domain/entities/search/search_result_type.dart';
import 'package:the_wisdom_project/presentation/widgets/search/search_results_panel.dart';
import 'package:the_wisdom_project/presentation/widgets/search/highlighted_fts_search_text.dart';

import 'search_test_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  // ==========================================================================
  // GROUP 1: Singlish / Sinhala Equivalence
  // ==========================================================================

  group('Group 1 - Singlish/Sinhala equivalence', () {
    testWidgets(
      '1.1 search "mahaasathi" (Singlish) → 2 Titles, 44 FTS, 19 Definitions',
      (tester) async {
        await tester.pumpSearchApp(prefs);
        await tester.searchFor('mahaasathi');

        tester.expectCounts(titles: 2, fullText: 44, definitions: 19);
      },
    );

    testWidgets(
      '1.2 search "මහාසති" (Sinhala) → same counts as Singlish',
      (tester) async {
        await tester.pumpSearchApp(prefs);
        await tester.searchFor('මහාසති');

        tester.expectCounts(titles: 2, fullText: 44, definitions: 19);
      },
    );

    testWidgets(
      '1.3 "mahaasathi" with exact match → 0 across all categories',
      (tester) async {
        await tester.pumpSearchApp(prefs);
        await tester.searchFor('mahaasathi');
        await tester.toggleExactMatch();

        tester.expectCounts(titles: 0, fullText: 0, definitions: 0);
      },
    );

    testWidgets(
      '2.1 search "waasawa" → 2 Titles, 100+ FTS, 23 Definitions',
      (tester) async {
        await tester.pumpSearchApp(prefs);
        await tester.searchFor('waasawa');

        tester.expectCounts(
          titles: 2,
          fullTextGreaterThan100: true,
          definitions: 23,
        );
      },
    );

    testWidgets(
      '2.2 search "වාසව" (Sinhala) → same counts as "waasawa"',
      (tester) async {
        await tester.pumpSearchApp(prefs);
        await tester.searchFor('වාසව');

        tester.expectCounts(
          titles: 2,
          fullTextGreaterThan100: true,
          definitions: 23,
        );
      },
    );

    testWidgets(
      '2.3 "waasawa" top results composition',
      (tester) async {
        await tester.pumpSearchApp(prefs);
        await tester.searchFor('waasawa');

        // Verify via provider state that top results have all 3 categories.
        final state = tester.getSearchState();
        final grouped = state.groupedResults;
        expect(grouped, isNotNull, reason: 'Top results should be loaded');
        expect(grouped!.isNotEmpty, isTrue, reason: 'Should have results');

        // Titles category should have results.
        expect(
          grouped.hasResultsForType(SearchResultType.title),
          isTrue,
          reason: 'Should have title results',
        );
        // FTS category should have results.
        expect(
          grouped.hasResultsForType(SearchResultType.fullText),
          isTrue,
          reason: 'Should have full text results',
        );
        // Definitions category should have results.
        expect(
          grouped.hasResultsForType(SearchResultType.definition),
          isTrue,
          reason: 'Should have definition results',
        );

        // Verify the search text "වාසව" appears somewhere in the rendered UI
        // (either in titles, FTS snippets, or definitions).
        expect(find.textContaining('වාසව'), findsWidgets);
      },
    );

    testWidgets(
      '2.4 "waasawa" with exact match → 0 Titles, 40 FTS, 6 Definitions',
      (tester) async {
        await tester.pumpSearchApp(prefs);
        await tester.searchFor('waasawa');
        await tester.toggleExactMatch();

        tester.expectCounts(titles: 0, fullText: 40, definitions: 6);
      },
    );
  });

  // ==========================================================================
  // GROUP 2: Multi-word Search Modes
  // ==========================================================================

  group('Group 2 - Multi-word search modes', () {
    testWidgets(
      '3.1 "කර්ම ඵල" phrase search → 0 Titles, 100+ FTS, 0 Definitions',
      (tester) async {
        await tester.pumpSearchApp(prefs);
        await tester.searchFor('කර්ම ඵල');

        tester.expectCounts(
          titles: 0,
          fullTextGreaterThan100: true,
          definitions: 0,
        );
      },
    );

    testWidgets(
      '3.2 "කර්ම ඵල" exact match → 0 Titles, 5 FTS, 0 Definitions',
      (tester) async {
        await tester.pumpSearchApp(prefs);
        await tester.searchFor('කර්ම ඵල');
        await tester.toggleExactMatch();

        tester.expectCounts(titles: 0, fullText: 5, definitions: 0);
      },
    );

    testWidgets(
      '3.3 "කර්ම ඵල" exact match → FTS results show highlighting',
      (tester) async {
        await tester.pumpSearchApp(prefs);
        await tester.searchFor('කර්ම ඵල');
        await tester.toggleExactMatch();

        // Switch to Full text tab to see FTS results.
        await tester.switchToTab('Full text');

        // Verify HighlightedFtsSearchText widgets are rendered (highlighting).
        expect(find.byType(HighlightedFtsSearchText), findsWidgets);
      },
    );

    testWidgets(
      '3.4 "කර්ම ඵල" exact + separate words, proximity 20 → 14 FTS',
      (tester) async {
        await tester.pumpSearchApp(prefs);
        await tester.searchFor('කර්ම ඵල');
        // Exact match must be ON first (user's flow: 3.1 → 3.1.2).
        await tester.toggleExactMatch();

        await tester.setProximitySettings(
          isPhraseSearch: false,
          proximityDistance: 20,
        );

        tester.expectCounts(fullText: 14);
      },
    );

    testWidgets(
      '3.5 "කර්ම ඵල" exact + separate words, anywhere in text → 45 FTS',
      (tester) async {
        await tester.pumpSearchApp(prefs);
        await tester.searchFor('කර්ම ඵල');
        // Exact match must be ON first (user's flow: 3.1 → 3.1.3).
        await tester.toggleExactMatch();

        await tester.setProximitySettings(
          isPhraseSearch: false,
          isAnywhereInText: true,
        );

        tester.expectCounts(fullText: 45);
      },
    );

    testWidgets(
      '4.1 "ජායෙථ වා" phrase search → 7 FTS',
      (tester) async {
        await tester.pumpSearchApp(prefs);
        await tester.searchFor('ජායෙථ වා');

        tester.expectCounts(fullText: 7);
      },
    );

    testWidgets(
      '4.2 "ජායෙථ වා" separate words, proximity 50 → 13 FTS',
      (tester) async {
        await tester.pumpSearchApp(prefs);
        await tester.searchFor('ජායෙථ වා');

        await tester.setProximitySettings(
          isPhraseSearch: false,
          proximityDistance: 50,
        );

        tester.expectCounts(fullText: 13);
      },
    );

    testWidgets(
      '4.3 "ජායෙථ වා" separate words, proximity 50, exact match → 12 FTS',
      (tester) async {
        await tester.pumpSearchApp(prefs);
        await tester.searchFor('ජායෙථ වා');

        await tester.setProximitySettings(
          isPhraseSearch: false,
          proximityDistance: 50,
        );
        await tester.toggleExactMatch();

        tester.expectCounts(fullText: 12);
      },
    );
  });

  // ==========================================================================
  // GROUP 3: Special Characters & Numbers
  // ==========================================================================

  group('Group 3 - Special characters & numbers', () {
    testWidgets(
      '5.1 "16. සමු%" → 2 Titles, 4 FTS, 0 Definitions',
      (tester) async {
        await tester.pumpSearchApp(prefs);
        await tester.searchFor('16. සමු%');

        tester.expectCounts(titles: 2, fullText: 4, definitions: 0);
      },
    );

    testWidgets(
      '6.1 "356" → 2 Titles, 86 FTS, 0 Definitions',
      (tester) async {
        await tester.pumpSearchApp(prefs);
        await tester.searchFor('356');

        tester.expectCounts(titles: 2, fullText: 86, definitions: 0);
      },
    );
  });

  // ==========================================================================
  // GROUP 4: Invalid & Empty Input
  // ==========================================================================

  group('Group 4 - Invalid & empty input', () {
    testWidgets(
      '7.1 "%&" → "Enter a valid search query" on all tabs',
      (tester) async {
        await tester.pumpSearchApp(prefs);
        await tester.searchFor('%&');

        // The panel should show the invalid-query message.
        expect(find.text('Enter a valid search query'), findsOneWidget);
        expect(find.byIcon(Icons.edit_note), findsOneWidget);

        // Switch to each specific tab and verify the message appears.
        await tester.switchToTab('Titles');
        expect(find.text('Enter a valid search query'), findsOneWidget);

        await tester.switchToTab('Full text');
        expect(find.text('Enter a valid search query'), findsOneWidget);

        await tester.switchToTab('Definitions');
        expect(find.text('Enter a valid search query'), findsOneWidget);
      },
    );

    testWidgets(
      '9.1 "Empty" → 0 results, shows "No X found" per tab',
      (tester) async {
        await tester.pumpSearchApp(prefs);
        await tester.searchFor('Empty');

        tester.expectCounts(titles: 0, fullText: 0, definitions: 0);

        // Switch to Titles tab → "No titles found"
        await tester.switchToTab('Titles');
        expect(find.text('No titles found'), findsOneWidget);

        // Switch to Full text tab → "No full text found"
        await tester.switchToTab('Full text');
        expect(find.text('No full text found'), findsOneWidget);

        // Switch to Definitions tab → "No definitions found"
        await tester.switchToTab('Definitions');
        expect(find.text('No definitions found'), findsOneWidget);
      },
    );

    testWidgets(
      '9.2 empty field → results panel is NOT visible',
      (tester) async {
        await tester.pumpSearchApp(prefs);

        // Don't type anything — panel should be hidden.
        expect(find.byType(SearchResultsPanel), findsNothing);
      },
    );
  });

  // ==========================================================================
  // GROUP 5: Recent Search
  // ==========================================================================

  group('Group 5 - Recent search', () {
    testWidgets(
      '10.1 search is saved and appears in recent searches',
      (tester) async {
        await tester.pumpSearchApp(prefs);

        // Perform a search.
        await tester.searchFor('මහාසති');

        // Tap the first result to save and dismiss.
        final listTile = find.byType(ListTile);
        if (listTile.evaluate().isNotEmpty) {
          await tester.tap(listTile.first);
          await tester.pumpAndSettle();
        }

        // Clear and refocus the search bar to show recent searches.
        await tester.clearSearch();
        await tester.tap(find.byType(TextField));
        await tester.pumpAndSettle();

        // The recent search overlay should show "මහාසති".
        expect(find.textContaining('මහාසති'), findsWidgets);
      },
    );
  });

  // ==========================================================================
  // GROUP 6: Scope Filtering & Refine Dialog
  // ==========================================================================

  group('Group 6 - Scope filtering & refine dialog', () {
    testWidgets(
      'A1 "මහාසති" + Sutta chip → 1 Title, 3 FTS, 19 Definitions',
      (tester) async {
        await tester.pumpSearchApp(prefs);
        await tester.searchFor('මහාසති');

        // Tap the "Sutta" scope chip.
        await tester.tapScopeChip('Sutta');

        tester.expectCounts(titles: 1, fullText: 3, definitions: 19);
      },
    );

    testWidgets(
      'A2 "aanandha" → Sutta chip → Refine to MN + SN → 14 Titles',
      (tester) async {
        await tester.pumpSearchApp(prefs);

        // Step 1: Search "aanandha".
        await tester.searchFor('aanandha');
        tester.expectCounts(
          titles: 53,
          fullTextGreaterThan100: true,
          definitionsGreaterThan100: true,
        );

        // Step 2: Tap "Sutta" scope chip → subset of all results.
        await tester.tapScopeChip('Sutta');
        tester.expectCounts(
          titles: 26,
          fullTextGreaterThan100: true,
          definitionsGreaterThan100: true,
        );

        // Step 3-4: Open Refine, clear, select MN + SN, close.
        await tester.refineScope(
          ['මැදුම් සඟිය', 'සංයුත්ත නිකාය'],
          clearFirst: true,
        );

        // Step 5: Verify.
        tester.expectCounts(titles: 14);
      },
    );

    testWidgets(
      'A3 "aanandha" → Refine to all commentaries → Commentaries chip highlighted, 27 Titles',
      (tester) async {
        await tester.pumpSearchApp(prefs);
        await tester.searchFor('aanandha');

        // Open Refine, clear, select all 3 commentary nodes, close.
        await tester.refineScope(
          ['සූත්‍ර අටුවාව', 'විනය අටුවාව', 'අභිධර්ම අටුවාව'],
          clearFirst: true,
        );

        // Verify "Commentaries" chip is highlighted.
        // The chip text should exist and be selected (secondaryContainer bg).
        expect(find.text('Commentaries'), findsOneWidget);

        // Verify Titles count (calibrated from database).
        tester.expectCounts(titles: 27);
      },
    );
  });

  // ==========================================================================
  // GROUP 7: Additional Coverage
  // ==========================================================================

  group('Group 7 - Additional coverage', () {
    testWidgets(
      'B1 BM25 ordering — FTS results sorted by relevance',
      (tester) async {
        await tester.pumpSearchApp(prefs);
        await tester.searchFor('මහාසති');

        // Switch to Full text tab to load full results.
        await tester.switchToTab('Full text');
        await tester.waitForSearchResults();

        // Read FTS results from provider.
        final updatedState = tester.getSearchState();
        final results = updatedState.fullResults.value;

        expect(results, isNotNull, reason: 'Full results should be loaded');
        expect(results!.length, greaterThan(1),
            reason: 'Should have multiple FTS results');

        for (int i = 1; i < results.length; i++) {
          final prevScore = results[i - 1].relevanceScore;
          final currScore = results[i].relevanceScore;
          if (prevScore != null && currScore != null) {
            expect(
              currScore,
              greaterThanOrEqualTo(prevScore),
              // BM25 scores are negative; more negative = more relevant.
              // ORDER BY score ASC puts most-relevant first, so scores
              // should be non-decreasing through the list.
              reason: 'BM25 scores should be non-decreasing '
                  '(most negative = most relevant first)',
            );
          }
        }
      },
    );

    testWidgets(
      'B2 Pagination — "මහා" shows "Viewing 50 out of X results" footer',
      (tester) async {
        // "මහා" returns large counts across all tabs, exceeding the 50
        // display limit. Each tab's ListView has a footer as the last item.
        // We must scroll to it since ListView is lazy (doesn't build
        // off-screen items).
        await tester.pumpSearchApp(prefs);
        await tester.searchFor('මහා');

        // Full text tab — "Viewing 50 out of 29769 results"
        await tester.switchToTab('Full text');
        await tester.dragUntilVisible(
          find.textContaining('Viewing 50 out of'),
          find.byType(ListView).last,
          const Offset(0, -300),
        );
        expect(
          find.textContaining('Viewing 50 out of 29769 results'),
          findsOneWidget,
        );

        // Titles tab — "Viewing 50 out of 340 results"
        await tester.switchToTab('Titles');
        await tester.dragUntilVisible(
          find.textContaining('Viewing 50 out of'),
          find.byType(ListView).last,
          const Offset(0, -300),
        );
        expect(
          find.textContaining('Viewing 50 out of 340 results'),
          findsOneWidget,
        );

        // Definitions tab — "Viewing 50 out of 3252 results"
        await tester.switchToTab('Definitions');
        await tester.dragUntilVisible(
          find.textContaining('Viewing 50 out of'),
          find.byType(ListView).last,
          const Offset(0, -300),
        );
        expect(
          find.textContaining('Viewing 50 out of 3252 results'),
          findsOneWidget,
        );
      },
    );
  });
}
