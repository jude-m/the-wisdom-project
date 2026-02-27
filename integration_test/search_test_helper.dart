import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_wisdom_project/core/localization/l10n/app_localizations.dart';
import 'package:the_wisdom_project/domain/entities/search/search_result_type.dart';
import 'package:the_wisdom_project/presentation/providers/search_provider.dart';
import 'package:the_wisdom_project/presentation/providers/search_state.dart';
import 'package:the_wisdom_project/presentation/widgets/search/search_bar.dart'
    as app;
import 'package:the_wisdom_project/presentation/widgets/search/search_results_panel.dart';

// ---------------------------------------------------------------------------
// Test widget: Combines SearchBar + SearchResultsPanel with real providers
// ---------------------------------------------------------------------------

/// A minimal widget tree that wires up the search bar and results panel,
/// driven by the same real providers the production app uses.
class _SearchTestWidget extends ConsumerWidget {
  const _SearchTestWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVisible = ref.watch(
      searchStateProvider.select((s) => s.isResultsPanelVisible),
    );

    return Column(
      children: [
        const app.SearchBar(width: 400),
        if (isVisible)
          Expanded(
            child: SearchResultsPanel(
              onClose: () =>
                  ref.read(searchStateProvider.notifier).dismissResultsPanel(),
            ),
          ),
        if (!isVisible) const Expanded(child: SizedBox()),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Extension on WidgetTester with all search-specific helpers
// ---------------------------------------------------------------------------

extension SearchTestHelpers on WidgetTester {
  // ---- Setup ----

  /// Pump the search test widget with real providers.
  ///
  /// All search providers use their real implementations (FTS database,
  /// navigation tree, dictionary). Only SharedPreferences is overridden.
  Future<void> pumpSearchApp(SharedPreferences prefs) async {
    await pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: _SearchTestWidget()),
        ),
      ),
    );
    // Let the tree and providers initialise.
    await pumpAndSettle();
  }

  // ---- Core search actions ----

  /// Type a query into the search bar and wait for results to load.
  ///
  /// Handles the full lifecycle:
  /// 1. Enter text in the TextField
  /// 2. Wait for the 300 ms debounce
  /// 3. Wait for the async search (FTS + tree + dictionary) to finish
  Future<void> searchFor(String query) async {
    await enterText(find.byType(TextField), query);
    // Trigger the onChanged callback and UI rebuild.
    await pump();
    // Wait for debounce (300 ms) + a safety margin.
    await pump(const Duration(milliseconds: 400));
    // Wait for search results to load (async I/O).
    await waitForSearchResults();
  }

  /// Poll until the loading spinner disappears (or timeout after 30 s).
  Future<void> waitForSearchResults() async {
    const maxWait = Duration(seconds: 30);
    final deadline = DateTime.now().add(maxWait);

    while (DateTime.now().isBefore(deadline)) {
      await pump(const Duration(milliseconds: 250));
      // Search is done when no spinner is visible.
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
        // One more settle to let any pending rebuilds finish.
        await pumpAndSettle(const Duration(milliseconds: 200));
        return;
      }
    }
    // Explicitly fail so the error message points here, not at a
    // downstream assertion that would produce a confusing message.
    fail('waitForSearchResults timed out after $maxWait — '
        'CircularProgressIndicator still visible');
  }

  // ---- Reading state ----

  /// Read the current result counts from the search state provider.
  Map<SearchResultType, int> getResultCounts() {
    final container = ProviderScope.containerOf(
      element(find.byType(MaterialApp)),
    );
    return container.read(searchStateProvider).countByResultType;
  }

  /// Read the full [SearchState] from the provider.
  SearchState getSearchState() {
    final container = ProviderScope.containerOf(
      element(find.byType(MaterialApp)),
    );
    return container.read(searchStateProvider);
  }

  // ---- UI interactions ----

  /// Toggle the exact match button (ABC icon in the search bar).
  Future<void> toggleExactMatch() async {
    await tap(find.byIcon(Icons.abc));
    await pump();
    // Wait for debounce + search.
    await pump(const Duration(milliseconds: 400));
    await waitForSearchResults();
  }

  /// Switch to a result tab by its display name (e.g., "Titles", "Full text").
  Future<void> switchToTab(String tabName) async {
    await tap(find.text(tabName));
    await pumpAndSettle();
    await waitForSearchResults();
  }

  /// Clear the search field and reset state.
  Future<void> clearSearch() async {
    // Clear the text field.
    await enterText(find.byType(TextField), '');
    await pump();
    await pumpAndSettle();
  }

  /// Tap a scope filter chip by its label (e.g., "Sutta", "Commentaries").
  Future<void> tapScopeChip(String chipLabel) async {
    await tap(find.text(chipLabel));
    await pump();
    await waitForSearchResults();
  }

  // ---- Proximity dialog ----

  /// Open the proximity dialog, apply settings, and wait for the new search.
  ///
  /// Pass [isPhraseSearch] to choose the radio button:
  ///   - `true`  → "Search as complete phrase"
  ///   - `false` → "Search as separate words"
  ///
  /// [isAnywhereInText]: check/uncheck the "Anywhere in the same text" checkbox.
  /// [proximityDistance]: drag the slider to the given value (1–100).
  Future<void> setProximitySettings({
    bool? isPhraseSearch,
    bool? isAnywhereInText,
    int? proximityDistance,
  }) async {
    // Open the dialog via the space_bar icon.
    await tap(find.byIcon(Icons.space_bar));
    await pumpAndSettle();

    // Select phrase / separate-words radio.
    if (isPhraseSearch != null) {
      if (isPhraseSearch) {
        await tap(find.text('Search as complete phrase'));
      } else {
        await tap(find.text('Search as separate words'));
      }
      await pump();
    }

    // Adjust the slider if a proximity distance is requested.
    if (proximityDistance != null) {
      final slider = find.byType(Slider);
      if (slider.evaluate().isNotEmpty) {
        // Slider range: 1–100, 99 divisions.
        // Calculate the relative position (0.0–1.0).
        // NOTE: This pixel-based approach may be slightly imprecise at
        // extreme values (1 or 100) due to slider thumb padding.
        // Mid-range values (used in current tests) work reliably.
        final fraction = (proximityDistance - 1) / 99;
        final sliderBox = getRect(slider);
        // Tap at the corresponding horizontal position on the slider.
        final tapX = sliderBox.left + sliderBox.width * fraction;
        final tapY = sliderBox.center.dy;
        await tapAt(Offset(tapX, tapY));
        await pump();
      }
    }

    // Toggle the "Anywhere in the same text" checkbox.
    if (isAnywhereInText != null) {
      final anywhereText = find.text('Anywhere in the same text');
      if (anywhereText.evaluate().isNotEmpty) {
        await tap(anywhereText);
        await pump();
      }
    }

    // Tap "Apply" to close the dialog and trigger a new search.
    await tap(find.text('Apply'));
    await pumpAndSettle();
    await waitForSearchResults();
  }

  // ---- Refine dialog ----

  /// Open the Refine dialog, select tree nodes by their Sinhala names,
  /// then close the dialog with "Done".
  ///
  /// [nodeNames]: Sinhala names of tree nodes to toggle (click their checkbox).
  /// [clearFirst]: If true, tap "Clear" before selecting nodes.
  Future<void> refineScope(
    List<String> nodeNames, {
    bool clearFirst = false,
  }) async {
    // Open the Refine dialog.
    await tap(find.text('Refine'));
    await pumpAndSettle();

    // Optionally clear existing scope.
    if (clearFirst) {
      final clearButton = find.text('Clear');
      if (clearButton.evaluate().isNotEmpty) {
        await tap(clearButton);
        await pumpAndSettle();
      }
    }

    // For each target node, expand tree parents until the node is visible,
    // then tap its checkbox.
    for (final name in nodeNames) {
      // If the node isn't visible yet, expand collapsed parents one by one.
      if (find.text(name).evaluate().isEmpty) {
        // Keep expanding collapsed nodes until our target appears.
        // Safety limit prevents infinite loops.
        // NOTE: This expands top-down, which works for shallow targets
        // (1-2 levels deep). Deeply nested targets may need a smarter
        // ancestor-first expansion strategy.
        for (var attempt = 0; attempt < 10; attempt++) {
          final collapsed = find.byIcon(Icons.chevron_right);
          if (collapsed.evaluate().isEmpty) break;
          await tap(collapsed.first);
          await pumpAndSettle();
          if (find.text(name).evaluate().isNotEmpty) break;
        }
      }

      // Find the node text and tap its checkbox.
      final nodeText = find.text(name);
      expect(
        nodeText,
        findsWidgets,
        reason: 'Tree node "$name" should be visible after expansion',
      );

      // The closest Row ancestor of the text contains [Icon, Checkbox, Text].
      final parentRow = find.ancestor(
        of: nodeText,
        matching: find.byType(Row),
      );
      final checkbox = find.descendant(
        of: parentRow.first,
        matching: find.byType(Checkbox),
      );
      expect(
        checkbox,
        findsWidgets,
        reason: 'Checkbox for "$name" should exist',
      );
      await tap(checkbox.first);
      await pumpAndSettle();
    }

    // Close the dialog.
    await tap(find.text('Done'));
    await pumpAndSettle();
    await waitForSearchResults();
  }

  // ---- Assertion helpers ----

  /// Assert that the result counts match the expected values.
  ///
  /// Use [greaterThan100] for counts expected to exceed 100
  /// (the badge shows "100+" so we can't know the exact number from UI).
  void expectCounts({
    int? titles,
    int? fullText,
    int? definitions,
    bool fullTextGreaterThan100 = false,
    bool definitionsGreaterThan100 = false,
  }) {
    final counts = getResultCounts();
    if (titles != null) {
      expect(
        counts[SearchResultType.title],
        equals(titles),
        reason: 'Expected $titles titles',
      );
    }
    if (fullText != null) {
      expect(
        counts[SearchResultType.fullText],
        equals(fullText),
        reason: 'Expected $fullText full text results',
      );
    }
    if (fullTextGreaterThan100) {
      expect(
        counts[SearchResultType.fullText] ?? 0,
        greaterThan(100),
        reason: 'Expected more than 100 full text results',
      );
    }
    if (definitions != null) {
      expect(
        counts[SearchResultType.definition],
        equals(definitions),
        reason: 'Expected $definitions definitions',
      );
    }
    if (definitionsGreaterThan100) {
      expect(
        counts[SearchResultType.definition] ?? 0,
        greaterThan(100),
        reason: 'Expected more than 100 definitions',
      );
    }
  }
}
