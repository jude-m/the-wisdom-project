import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/search_match_finder.dart';
import '../../core/utils/search_query_utils.dart';
import '../../domain/entities/content/entry.dart';
import '../../domain/entities/reader/document_slice.dart';
import '../models/reader_layout.dart';
import '../models/in_page_search_state.dart';
import 'document_provider.dart';
import 'reader_unit_provider.dart';
import 'tab_provider.dart';

/// Manages in-page search state for all tabs.
///
/// State is a Map<int, InPageSearchState> keyed by tab index — one
/// search state per tab, re-indexed on tab close.
class InPageSearchNotifier extends StateNotifier<Map<int, InPageSearchState>> {
  final Ref _ref;

  /// Per-tab debounce timers to avoid cross-tab interference.
  /// Each tab gets its own timer so typing in one tab doesn't cancel
  /// the debounce for another tab.
  final Map<int, Timer> _debounceTimers = {};

  InPageSearchNotifier(this._ref) : super({});

  /// Gets the state for a specific tab, or a default empty state.
  InPageSearchState _getTabState(int tabIndex) {
    return state[tabIndex] ?? InPageSearchState();
  }

  /// Updates state for a specific tab.
  void _setTabState(int tabIndex, InPageSearchState tabState) {
    state = {...state, tabIndex: tabState};
  }

  /// Opens the search bar for the active tab.
  ///
  /// If a query was retained from a previous session but matches were dropped
  /// (because the bar was closed when a layout switch invalidated them — see
  /// [recomputeActiveTabMatches]), this kicks a fresh compute so the reopened
  /// bar reflects the *current* layout and pagination.
  void openSearch() {
    final tabIndex = _ref.read(activeTabIndexProvider);
    if (tabIndex < 0) return;

    final tabState = _getTabState(tabIndex);
    _setTabState(tabIndex, tabState.copyWith(isVisible: true));

    // Retained query but no matches → recompute against current state.
    // The recompute runs against the freshly-flipped isVisible=true state,
    // so it takes the compute branch (not the drop-matches branch).
    if (tabState.effectiveQuery.isNotEmpty && tabState.matches.isEmpty) {
      recomputeActiveTabMatches();
    }
  }

  /// Hides the search bar for the active tab.
  /// Query and results are retained (per requirements).
  void closeSearch() {
    final tabIndex = _ref.read(activeTabIndexProvider);
    if (tabIndex < 0) return;

    final tabState = _getTabState(tabIndex);
    _setTabState(tabIndex, tabState.copyWith(isVisible: false));
  }

  /// Updates the query for the active tab with debounce.
  ///
  /// Sanitizes the raw input, applies Singlish conversion if needed,
  /// and computes matches after a 300ms debounce.
  void updateQuery(String rawQuery) {
    final tabIndex = _ref.read(activeTabIndexProvider);
    if (tabIndex < 0) return;

    // Cancel previous debounce for THIS tab only
    _debounceTimers[tabIndex]?.cancel();

    // Compute effective query immediately (cheap operation)
    final effectiveQuery = _computeEffectiveQuery(rawQuery);

    if (effectiveQuery.isEmpty) {
      // Empty query - clear matches immediately
      _setTabState(
        tabIndex,
        _getTabState(tabIndex).copyWith(
          rawQuery: rawQuery,
          effectiveQuery: '',
          matches: const [],
          currentMatchIndex: -1,
        ),
      );
      return;
    }

    // Update rawQuery + effectiveQuery immediately (for UI responsiveness)
    _setTabState(
      tabIndex,
      _getTabState(tabIndex).copyWith(
        rawQuery: rawQuery,
        effectiveQuery: effectiveQuery,
      ),
    );

    // Capture the tab's node key and layout at call time, so the debounce
    // callback uses the correct values even if the user switches tabs before it
    // fires. The content file is not captured — it is derived from the node's
    // unit inside [_computeAndSetMatches].
    final tabs = _ref.read(tabsProvider);
    if (tabIndex >= tabs.length) return;
    final nodeKey = tabs[tabIndex].nodeKey;
    final layout = tabs[tabIndex].layout;

    // Debounce the expensive match computation
    _debounceTimers[tabIndex] = Timer(const Duration(milliseconds: 300), () {
      _computeAndSetMatches(tabIndex, effectiveQuery, nodeKey, layout);
    });
  }

  /// Clears the query and results for the active tab.
  void clearQuery() {
    final tabIndex = _ref.read(activeTabIndexProvider);
    if (tabIndex < 0) return;

    _debounceTimers[tabIndex]?.cancel();
    _setTabState(
      tabIndex,
      _getTabState(tabIndex).copyWith(
        rawQuery: '',
        effectiveQuery: '',
        matches: const [],
        currentMatchIndex: -1,
      ),
    );
  }

  /// Re-runs the match scan for the active tab against its current layout.
  /// Call after a layout change; no-ops if no active query.
  ///
  /// Layout switches re-scope which entries are searchable
  /// (Pali ↔ Sinhala ↔ both), so any cached match set goes stale.
  /// While the bar is visible, refresh it. While closed, drop the stale set —
  /// recomputing silently wastes work the user can't see. [openSearch]
  /// computes fresh on reopen.
  void recomputeActiveTabMatches() {
    final tabIndex = _ref.read(activeTabIndexProvider);
    if (tabIndex < 0) return;

    final tabState = _getTabState(tabIndex);
    if (tabState.effectiveQuery.isEmpty) return;

    _debounceTimers[tabIndex]?.cancel();

    if (!tabState.isVisible) {
      // Drop stale matches; openSearch will recompute against current state.
      _setTabState(
        tabIndex,
        tabState.copyWith(matches: const [], currentMatchIndex: -1),
      );
      return;
    }

    final tabs = _ref.read(tabsProvider);
    if (tabIndex >= tabs.length) return;
    final tab = tabs[tabIndex];

    _computeAndSetMatches(
      tabIndex,
      tabState.effectiveQuery,
      tab.nodeKey,
      tab.layout,
    );
  }

  /// Navigates to the next match (wraps around).
  void nextMatch() {
    final tabIndex = _ref.read(activeTabIndexProvider);
    if (tabIndex < 0) return;

    final tabState = _getTabState(tabIndex);
    if (tabState.matches.isEmpty) return;

    final nextIndex = (tabState.currentMatchIndex + 1) % tabState.matchCount;
    _setTabState(tabIndex, tabState.copyWith(currentMatchIndex: nextIndex));
  }

  /// Navigates to the previous match (wraps around).
  void previousMatch() {
    final tabIndex = _ref.read(activeTabIndexProvider);
    if (tabIndex < 0) return;

    final tabState = _getTabState(tabIndex);
    if (tabState.matches.isEmpty) return;

    final prevIndex = (tabState.currentMatchIndex - 1 + tabState.matchCount) %
        tabState.matchCount;
    _setTabState(tabIndex, tabState.copyWith(currentMatchIndex: prevIndex));
  }

  /// Removes search state for a closed tab and re-indexes remaining tabs.
  void onTabClosed(int tabIndex) {
    // Cancel and remove the debounce timer for this tab
    _debounceTimers[tabIndex]?.cancel();
    _debounceTimers.remove(tabIndex);

    // Re-index debounce timers (shift keys above closed tab down by 1)
    final updatedTimers = <int, Timer>{};
    _debounceTimers.forEach((key, value) {
      if (key < tabIndex) {
        updatedTimers[key] = value;
      } else {
        updatedTimers[key - 1] = value;
      }
    });
    _debounceTimers
      ..clear()
      ..addAll(updatedTimers);

    // Re-index search state
    final updatedState = <int, InPageSearchState>{};
    state.forEach((key, value) {
      if (key < tabIndex) {
        updatedState[key] = value;
      } else if (key > tabIndex) {
        updatedState[key - 1] = value;
      }
      // key == tabIndex is removed
    });
    state = updatedState;
  }

  /// Removes all search state (e.g., when all tabs are closed).
  void clearAll() {
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
    state = {};
  }

  @override
  void dispose() {
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
    super.dispose();
  }

  // ===========================================================================
  // Private helpers
  // ===========================================================================

  /// Delegates to shared [computeEffectiveQuery] for consistent
  /// query processing across FTS and in-page search.
  String _computeEffectiveQuery(String rawQuery) =>
      computeEffectiveQuery(rawQuery);

  /// Searches the tab's unit for matches.
  ///
  /// Uses the tab's own [nodeKey] and [layout] (captured at call time) so a
  /// tab switch during the debounce cannot make this answer for the wrong tab.
  ///
  /// **Scoped to the rendered unit, and to nothing else.** The bounds are the
  /// same [DocumentSlice] the panes build from, so every match is on screen
  /// somewhere and the scroll-to-match never has to widen anything. What this
  /// replaces walked the tree for the next *sibling* with the same content
  /// file — a second reading of the slicing rule, wrong for roughly a tenth of
  /// the corpus's leaves, and giving a container the whole file.
  ///
  /// Note: Match counts are computed against `entry.plainText`. The
  /// `TextEntryWidget` computes highlight ranges against `_displayText`
  /// (which may have ZWJ conjuncts for Pali). These produce identical match
  /// counts because `SearchMatchFinder` normalizes text (strips ZWJ, lowercases)
  /// internally via `NormalizedTextMatcher`.
  void _computeAndSetMatches(
    int tabIndex,
    String effectiveQuery,
    String? nodeKey,
    ReaderLayout layout,
  ) {
    if (!mounted) return;

    final unit = (nodeKey == null || nodeKey.isEmpty)
        ? null
        : _ref.read(readerUnitResolverProvider).valueOrNull?.unitFor(nodeKey);

    // Read the specific tab's document (not the active tab's). Loading or
    // errored is as unanswerable as a missing unit, and is why this reads the
    // value rather than using `whenData` — that quietly did nothing on those
    // two states and left the old query's matches standing.
    final document = unit == null
        ? null
        : _ref.read(bjtDocumentProvider(unit.contentFileId)).valueOrNull;

    if (unit == null || document == null) {
      // The query has already been committed to state, so leaving the previous
      // one's matches would show a count for text nobody searched for and let
      // next/prev walk it.
      _setMatches(tabIndex, const []);
      return;
    }

    _setMatches(
      tabIndex,
      _findAllMatches(
        DocumentSlice.of(document, unit.range),
        effectiveQuery,
        layout,
      ),
    );
  }

  /// Installs a match set, parking the cursor on the first hit or nowhere.
  void _setMatches(int tabIndex, List<InPageMatch> matches) {
    _setTabState(
      tabIndex,
      _getTabState(tabIndex).copyWith(
        matches: matches,
        currentMatchIndex: matches.isNotEmpty ? 0 : -1,
      ),
    );
  }

  /// Scans [slice] for the query, respecting reader layout.
  List<InPageMatch> _findAllMatches(
    DocumentSlice slice,
    String effectiveQuery,
    ReaderLayout layout,
  ) {
    final matches = <InPageMatch>[];
    final finder = SearchMatchFinder(
      queryText: effectiveQuery,
      isPhraseSearch: true,
      isExactMatch: true,
    );

    void scan(int localPage, List<Entry> entries, String languageCode) {
      final (first, last) = slice.entriesOn(localPage, entries.length);
      for (var entryIndex = first; entryIndex < last; entryIndex++) {
        final ranges = finder.findMatchRanges(entries[entryIndex].plainText);
        for (var matchIdx = 0; matchIdx < ranges.length; matchIdx++) {
          matches.add(InPageMatch(
            pageIndex: slice.absolutePageStart + localPage,
            entryIndex: entryIndex,
            languageCode: languageCode,
            matchIndexInEntry: matchIdx,
          ));
        }
      }
    }

    for (var localPage = 0; localPage < slice.pages.length; localPage++) {
      final page = slice.pages[localPage];
      if (layout != ReaderLayout.sinhalaOnly) {
        scan(localPage, page.paliSection.entries, 'pi');
      }
      if (layout != ReaderLayout.paliOnly) {
        scan(localPage, page.sinhalaSection.entries, 'si');
      }
    }

    return matches;
  }
}

/// Provider for the in-page search state map (tab index -> search state).
final inPageSearchStatesProvider =
    StateNotifierProvider<InPageSearchNotifier, Map<int, InPageSearchState>>(
  (ref) => InPageSearchNotifier(ref),
);

/// Derived provider: the search state for the currently active tab.
///
/// Returns a default empty state if no search has been initiated for this tab.
final activeInPageSearchStateProvider = Provider<InPageSearchState>((ref) {
  final tabIndex = ref.watch(activeTabIndexProvider);
  final states = ref.watch(inPageSearchStatesProvider);
  return states[tabIndex] ?? InPageSearchState();
});
