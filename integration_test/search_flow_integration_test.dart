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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_wisdom_project/core/utils/pali_conjunct_transformer.dart';
import 'package:the_wisdom_project/core/utils/pali_letter_options.dart';
import 'package:the_wisdom_project/domain/entities/content/content_language.dart';
import 'package:the_wisdom_project/domain/entities/search/search_result_type.dart';
import 'package:the_wisdom_project/presentation/providers/content_language_provider.dart';
import 'package:the_wisdom_project/presentation/providers/navigation_tree_provider.dart';
import 'package:the_wisdom_project/presentation/utils/content_text_formatter.dart';
import 'package:the_wisdom_project/presentation/widgets/search/dictionary_search_result_tile.dart';
import 'package:the_wisdom_project/presentation/widgets/search/search_results_panel.dart';
import 'package:the_wisdom_project/presentation/widgets/search/highlighted_fts_search_text.dart';

import 'search_test_helper.dart';
import 'test_overrides.dart';

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

        // Search-result titles are re-derived from the matched tree node in the
        // active Content Language (see `searchResultLabels`) — not taken from
        // the repository's query-matched string. So the *same* title result is
        // verified against BOTH language branches off its node: first Sinhala
        // (the default), then Pali after an in-place language switch.
        final container = ProviderScope.containerOf(
          tester.element(find.byType(MaterialApp)),
        );

        final titleResults =
            grouped.getResultsByType(SearchResultType.title);
        final paliTitleResult =
            titleResults.where((r) => r.language == 'pali').firstOrNull;
        if (paliTitleResult != null) {
          // The node is language-independent (it carries both names), so read
          // it once and reuse it for both branches.
          final node =
              container.read(nodeByKeyProvider(paliTitleResult.nodeKey));

          // --- Sinhala branch (the default Content Language) ---
          // The app boots in Sinhala, so the title must show the node's Sinhala
          // name verbatim. formatContentLabel must NOT apply Pali conjunct
          // ligatures to Sinhala text, so the stored name appears exactly as-is
          // — this guards against conjuncts incorrectly leaking onto Sinhala.
          if (node != null) {
            final expectedSinhalaTitle = formatContentLabel(
              node.getDisplayName(ContentLanguage.sinhala),
              ContentLanguage.sinhala,
              PaliLetterOptions.defaults,
            );
            expect(find.textContaining(expectedSinhalaTitle), findsWidgets,
                reason:
                    'In the default (Sinhala) Content Language, the title '
                    'should show the node\'s Sinhala name, unchanged');
          }

          // --- Pali branch ---
          // Switch the Content Language to Pali; the tiles watch the language
          // provider, so they re-render in place. Pali-script sutta names must
          // now render with their consonant ligatures (ZWJ, U+200D).
          container
              .read(contentLanguageProvider.notifier)
              .setLanguage(ContentLanguage.pali);
          await pumpForSettle(tester);

          // Mirror the production pipeline exactly: the tile shows the node's
          // name in the active Content Language, run through formatContentLabel
          // (which applies Pali conjuncts on the Pali branch). Fall back to the
          // repo title only if the node isn't in the tree.
          final expectedPaliTitle = node != null
              ? formatContentLabel(
                  node.getDisplayName(ContentLanguage.pali),
                  ContentLanguage.pali,
                  PaliLetterOptions.defaults,
                )
              : beautifyPaliText(
                  paliTitleResult.title, PaliLetterOptions.defaults);
          expect(find.textContaining(expectedPaliTitle), findsWidgets,
              reason:
                  'Pali title results should display with conjunct '
                  'transformation');
        }
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
          await pumpForSettle(tester);
        }

        // Clear and refocus the search bar to show recent searches.
        await tester.clearSearch();
        await tester.tap(find.byType(TextField));
        await pumpForSettle(tester);

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

  // ==========================================================================
  // GROUP 8: Conjunct Transformation in Search Results
  // ==========================================================================

  group('Group 8 - Conjunct transformation in search results', () {
    testWidgets(
      'C1 Definitions tab shows dictionary word titles with Pali conjuncts',
      (tester) async {
        await tester.pumpSearchApp(prefs);
        await tester.searchFor('waasawa');

        // Switch to Definitions tab
        await tester.switchToTab('Definitions');

        // Verify DictionarySearchResultTile widgets are rendered
        expect(find.byType(DictionarySearchResultTile), findsWidgets,
            reason: 'Definitions tab should show dictionary result tiles');

        // Dictionary word titles are always Pali and should have conjunct
        // transformation applied. Read the full results from provider state
        // after switching to Definitions tab.
        final state = tester.getSearchState();
        final defResults = state.fullResults.value;
        expect(defResults, isNotNull, reason: 'Should have definition results');
        expect(defResults, isNotEmpty, reason: 'Should have definition results');

        // Use the first result — it's always rendered by ListView (top of list).
        // Results further down may not be built due to lazy rendering.
        final firstResult = defResults!.first;
        final transformedTitle =
            beautifyPaliText(firstResult.title, PaliLetterOptions.defaults);
        expect(find.textContaining(transformedTitle), findsWidgets,
            reason:
                'First dictionary result title should display with Pali '
                'conjunct transformation applied by the tile widget');
      },
    );
  });

  // ==========================================================================
  // GROUP 9: Snippet Text (the string the result tile actually shows)
  // ==========================================================================

  group('Group 9 - Snippet text goldens', () {
    // Groups 1-8 pin how MANY results a query returns. Nothing pinned what any
    // of them SAYS, so an empty or wrong snippet passed green. That matters
    // now: the snippet text is about to stop coming from `assets/text/*.json`
    // and start coming from a compressed row in `bjt_content`, and the
    // migration's contract is that the string does not change by one byte.
    //
    // Rows are addressed by (file, page, entry, language), not by position:
    // BM25 may reorder ties, and `SearchResult.id` omits the language, so a
    // Pali entry and its Sinhala twin can share one id.
    //
    // To re-record after a DELIBERATE change, print `matchedText` for these
    // rows and paste the values back. Do not hand-edit them: several carry
    // zero-width joiners that do not survive retyping.
    for (final (index, golden) in _snippetGoldens.entries.indexed) {
      testWidgets(
        '9.${index + 1} "${golden.key}" - snippets are byte-for-byte unchanged',
        (tester) async {
          await tester.pumpSearchApp(prefs);
          await tester.searchFor(golden.key);
          await tester.switchToTab('Full text');
          await tester.waitForSearchResults();

          final results = tester.getSearchState().fullResults.value;
          expect(results, isNotNull,
              reason: 'Full text results should have loaded');

          // The whole-set invariant: a snippet that fails to load degrades to
          // '' rather than failing the search, which is right at runtime and
          // invisible to a test that only counts rows.
          expect(
            results!.where((r) => r.matchedText.isEmpty).map((r) => r.id),
            isEmpty,
            reason: 'Every full-text result must carry snippet text',
          );

          for (final row in golden.value) {
            final where = '${row.fileId} page ${row.page} '
                'entry ${row.entry} (${row.language})';
            final matches = results.where((r) =>
                r.contentFileId == row.fileId &&
                r.pageIndex == row.page &&
                r.entryIndex == row.entry &&
                r.language == row.language);

            // Membership and text are separate failures, and only the second
            // is what this group exists for. The set is capped (overfetch,
            // then `_limitToGroups`), so a row can drop out of it with every
            // snippet still byte-identical — a ranking or corpus change.
            expect(matches, isNotEmpty,
                reason: '$where is no longer in the returned set. That is a '
                    'ranking or corpus change, NOT a snippet regression — '
                    'pick a different row rather than re-recording the text.');
            expect(matches, hasLength(1),
                reason: '$where matched ${matches.length} results; '
                    '(file, page, entry, language) is meant to be unique');
            expect(matches.first.matchedText, equals(row.text),
                reason: 'Snippet text changed for $where');
          }
        },
      );
    }
  });
}

/// One recorded snippet: the row it came from, and the exact text the snippet
/// path produced for it.
typedef _Snippet = ({
  /// `atta-sn-3` — a content file id, which is what `bjt_meta.filename` and
  /// `SearchResult.contentFileId` both hold despite the older column's name.
  String fileId,
  int page,
  int entry,
  String language,
  String text,
});

/// Recorded 2026-09-11, before the `bjt_content` migration, against the
/// bundled FTS database and `assets/text/*.json`.
const Map<String, List<_Snippet>> _snippetGoldens = {
    'සොතාපත්ති': [
      // plain text, no markers
      (fileId: 'atta-sn-3', page: 70, entry: 1, language: 'pali',
       text: "1. සොතාපත්තිවග්ගො"),
      // same row, other language
      (fileId: 'atta-sn-3', page: 70, entry: 1, language: 'sinhala',
       text: "1. සොතාපත්ති වර්ගය"),
      // **bold** survives
      (fileId: 'ap-kvu-15', page: 11, entry: 9, language: 'pali',
       text: "**2.** ස. පු: සොතාපත්තිමග්ගස්ස ජරාමරණං සොතාපත්තිමග්ගොති."),
      // {1} footnote ref survives
      (fileId: 'ap-kvu-15', page: 79, entry: 9, language: 'pali',
       text: "ස. අනු: සොතාපත්තිමග්ගෙනාති.{1}"),
    ],
    'මහාසති': [
      // embedded newline survives
      (fileId: 'atta-dn-2-4', page: 164, entry: 2, language: 'pali',
       text: "ඉති සුමඞ්ගලවිලාසිනියා දීඝනිකායට්ඨකථායං\nමහාසතිපට්ඨානසුත්තවණ්ණනා නිට්ඨිතා."),
      // zero-width joiner survives
      (fileId: 'atta-dn-2-4', page: 110, entry: 0, language: 'sinhala',
       text: "9. මහාසතිපට්ඨාන සූත්‍ර වර්ණනාව"),
      // **bold** mid-sentence
      (fileId: 'anya-vm', page: 255, entry: 4, language: 'pali',
       text: "එවං තික්ඛපඤ්ඤස්ස ධාතුකම්මට්ඨානිකස්ස වසෙන **මහාසතිපට්ඨානෙ** (දී· නි· 2.378) සඞ්ඛෙපතො ආගතං."),
    ],
    'waasawa': [
      // footnote ref AND newline
      (fileId: 'sn-1-7', page: 67, entry: 3, language: 'pali',
       text: "කින්නු තෙසං පිහයසි අනාගාරාන වාසව,\nආචාරං ඉසිනං{4} බ්රූහි තං සුණොම වචො තවාති."),
      // gatha, two lines
      (fileId: 'atta-kn-jat-22', page: 85, entry: 12, language: 'pali',
       text: "“සො පුට්ඨො නරදෙවෙන, වාසවො අවචා නිමිං; \nවිපාකං බ්රහ්මචරියස්ස, ජානං අක්ඛාසිජානතො."),
      // same row, other language
      (fileId: 'atta-kn-jat-22', page: 85, entry: 12, language: 'sinhala',
       text: "සො ඵුට්ඨො නර දෙවෙන, වාසවො අවචා නිමිං, \nවිපාකං බ්‍රහ්මචරියස්ස, ජානං අක්ඛාස ජානතො"),
    ],
    'බුද්ධ': [
      // three footnote refs in one entry
      (fileId: 'kn-ap-2', page: 33, entry: 11, language: 'pali',
       text: "400. බුද්ධො බුද්ධස්ස නිබ්බානෙ{5} නොපදිස්සති{6} භික්ඛවො\nබුද්ධො ගොතමිනිබ්බානෙ සාරිපුත්තාදිකා{7} තථා."),
      // leading bold marker
      (fileId: 'ap-kvu-3', page: 69, entry: 16, language: 'pali',
       text: "**16.** ස. පු: අතීතාය බොධියා බුද්ධො, අනාගතාය බොධියා බුද්ධො, පච්චුප්පන්නාය බොධියා බුද්ධො’ති."),
    ],
    'මෙත්තා': [
      // footnote ref AND newline
      (fileId: 'kn-bv', page: 23, entry: 0, language: 'pali',
       text: "159. තථෙ’ව ත්වම්පි හිතාහිතෙ{1} සමං මෙත්තාය භාවය\nමෙත්තාපාරමිතං ගන්ත්වා සම්බොධිං පාපුණිස්සසි."),
      // **bold** mid-sentence
      (fileId: 'atta-ap-dhs', page: 56, entry: 23, language: 'pali',
       text: "එවං ජීවිතං අනපලොකෙත්වා මෙත්තායන්තස්ස **මෙත්තාපාරමිතා** පරමත්ථපාරමී නාම ජාතා."),
    ],
};
