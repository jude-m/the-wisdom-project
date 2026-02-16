import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/search_match_finder.dart';
import '../../core/utils/search_query_utils.dart';
import '../../domain/entities/bjt/bjt_document.dart';
import '../../domain/entities/navigation/tipitaka_tree_node.dart';
import '../models/column_display_mode.dart';
import '../models/in_page_search_state.dart';
import 'document_provider.dart';
import 'navigation_tree_provider.dart';
import 'tab_provider.dart';

/// Manages in-page search state for all tabs.
///
/// State is a Map<int, InPageSearchState> keyed by tab index,
/// following the same pattern as [tabScrollPositionsProvider].
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
  void openSearch() {
    final tabIndex = _ref.read(activeTabIndexProvider);
    if (tabIndex < 0) return;

    final tabState = _getTabState(tabIndex);
    _setTabState(tabIndex, tabState.copyWith(isVisible: true));
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

    // Capture the tab's content file ID, column mode, and node key at call
    // time, so the debounce callback uses the correct values even if the user
    // switches tabs before it fires.
    final tabs = _ref.read(tabsProvider);
    if (tabIndex >= tabs.length) return;
    final contentFileId = tabs[tabIndex].contentFileId;
    final columnMode = tabs[tabIndex].columnMode;
    final nodeKey = tabs[tabIndex].nodeKey;

    // Debounce the expensive match computation
    _debounceTimers[tabIndex] = Timer(const Duration(milliseconds: 300), () {
      _computeAndSetMatches(
        tabIndex, effectiveQuery, contentFileId, columnMode, nodeKey,
      );
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

  /// Searches the sutta's pages for matches (scoped by navigation tree bounds).
  ///
  /// Uses tab-specific [contentFileId], [columnMode], and [nodeKey] (captured
  /// at call time) to avoid reading stale state if the active tab changed
  /// during debounce.
  ///
  /// Note: Match counts are computed against `entry.plainText`. The
  /// `TextEntryWidget` computes highlight ranges against `_displayText`
  /// (which may have ZWJ conjuncts for Pali). These produce identical match
  /// counts because `SearchMatchFinder` normalizes text (strips ZWJ, lowercases)
  /// internally via `NormalizedTextMatcher`.
  void _computeAndSetMatches(
    int tabIndex,
    String effectiveQuery,
    String? contentFileId,
    ColumnDisplayMode columnMode,
    String? nodeKey,
  ) {
    if (!mounted) return;
    if (contentFileId == null || contentFileId.isEmpty) return;

    // Read the specific tab's document (not the active tab's)
    final contentAsync = _ref.read(bjtDocumentProvider(contentFileId));

    contentAsync.whenData((document) {
      if (!mounted) return;

      // Compute sutta boundaries from the navigation tree so we only
      // search entries belonging to this sutta, not the entire document.
      final bounds = _computeSuttaBounds(
        nodeKey, contentFileId, document.pageCount,
      );

      final matches = _findAllMatches(
        document, effectiveQuery, columnMode, bounds,
      );

      _setTabState(
        tabIndex,
        _getTabState(tabIndex).copyWith(
          matches: matches,
          currentMatchIndex: matches.isNotEmpty ? 0 : -1,
        ),
      );
    });
  }

  /// Scans pages within [bounds] for the query, respecting column mode.
  ///
  /// Only searches entries that belong to the current sutta (bounded by the
  /// next sibling's start position in the navigation tree).
  List<InPageMatch> _findAllMatches(
    BJTDocument document,
    String effectiveQuery,
    ColumnDisplayMode columnMode,
    _SuttaBounds bounds,
  ) {
    final matches = <InPageMatch>[];
    final finder = SearchMatchFinder(
      queryText: effectiveQuery,
      isPhraseSearch: true,
      isExactMatch: true,
    );

    for (var pageIndex = bounds.startPage;
        pageIndex < document.pages.length;
        pageIndex++) {
      // Stop if we've passed the sutta's end boundary.
      // endEntry == 0 means the next sutta starts at the beginning of endPage,
      // so endPage itself is fully excluded.
      if (pageIndex > bounds.endPage ||
          (pageIndex == bounds.endPage && bounds.endEntry == 0)) {
        break;
      }

      final page = document.pages[pageIndex];

      // Search Pali entries if column mode includes Pali
      if (columnMode != ColumnDisplayMode.sinhalaOnly) {
        final paliEntries = page.paliSection.entries;
        final firstEntry =
            (pageIndex == bounds.startPage) ? bounds.startEntry : 0;
        final lastEntry =
            (pageIndex == bounds.endPage) ? bounds.endEntry : paliEntries.length;

        for (var entryIndex = firstEntry;
            entryIndex < lastEntry;
            entryIndex++) {
          final ranges =
              finder.findMatchRanges(paliEntries[entryIndex].plainText);
          for (var matchIdx = 0; matchIdx < ranges.length; matchIdx++) {
            matches.add(InPageMatch(
              pageIndex: pageIndex,
              entryIndex: entryIndex,
              languageCode: 'pi',
              matchIndexInEntry: matchIdx,
            ));
          }
        }
      }

      // Search Sinhala entries if column mode includes Sinhala
      if (columnMode != ColumnDisplayMode.paliOnly) {
        final sinhalaEntries = page.sinhalaSection.entries;
        final firstEntry =
            (pageIndex == bounds.startPage) ? bounds.startEntry : 0;
        final lastEntry = (pageIndex == bounds.endPage)
            ? bounds.endEntry
            : sinhalaEntries.length;

        for (var entryIndex = firstEntry;
            entryIndex < lastEntry;
            entryIndex++) {
          final ranges =
              finder.findMatchRanges(sinhalaEntries[entryIndex].plainText);
          for (var matchIdx = 0; matchIdx < ranges.length; matchIdx++) {
            matches.add(InPageMatch(
              pageIndex: pageIndex,
              entryIndex: entryIndex,
              languageCode: 'si',
              matchIndexInEntry: matchIdx,
            ));
          }
        }
      }
    }

    return matches;
  }

  // ===========================================================================
  // Sutta boundary helpers
  // ===========================================================================

  /// Computes the page/entry boundaries for a sutta within its document.
  ///
  /// Uses the navigation tree to find where this sutta starts and where
  /// the next sibling sutta (with the same [contentFileId]) begins.
  /// The end boundary is exclusive (the next sutta's start position).
  ///
  /// Falls back to the entire document if the node can't be found.
  _SuttaBounds _computeSuttaBounds(
    String? nodeKey,
    String contentFileId,
    int totalPages,
  ) {
    final fullDocument = _SuttaBounds(
      startPage: 0,
      startEntry: 0,
      endPage: totalPages,
      endEntry: 0,
    );

    if (nodeKey == null || nodeKey.isEmpty) return fullDocument;

    final treeAsync = _ref.read(navigationTreeProvider);

    return treeAsync.when(
      data: (rootNodes) {
        // Single traversal: find both the node and its parent in one pass
        final result = _findNodeWithParent(rootNodes, nodeKey);
        if (result == null) return fullDocument;

        final (node, parent) = result;
        final startPage = node.entryPageIndex;
        final startEntry = node.entryIndexInPage;

        // No parent → can't determine siblings, search to end of document
        if (parent == null) {
          return _SuttaBounds(
            startPage: startPage,
            startEntry: startEntry,
            endPage: totalPages,
            endEntry: 0,
          );
        }

        // Find the next sibling with the same contentFileId.
        // Its start position marks the end of the current sutta.
        final siblings = parent.childNodes;
        bool foundCurrent = false;
        for (final sibling in siblings) {
          if (foundCurrent && sibling.contentFileId == contentFileId) {
            return _SuttaBounds(
              startPage: startPage,
              startEntry: startEntry,
              endPage: sibling.entryPageIndex,
              endEntry: sibling.entryIndexInPage,
            );
          }
          if (sibling.nodeKey == nodeKey) {
            foundCurrent = true;
          }
        }

        // No next sibling with same contentFileId → sutta extends to end
        return _SuttaBounds(
          startPage: startPage,
          startEntry: startEntry,
          endPage: totalPages,
          endEntry: 0,
        );
      },
      loading: () => fullDocument,
      error: (_, __) => fullDocument,
    );
  }

  /// Recursively finds a node and its parent in a single tree traversal.
  ///
  /// Returns (node, parent) where parent is null for root-level nodes.
  /// This avoids the duplicate traversal of finding the node first and
  /// then searching again for its parent.
  (TipitakaTreeNode, TipitakaTreeNode?)? _findNodeWithParent(
    List<TipitakaTreeNode> nodes,
    String key, [
    TipitakaTreeNode? parent,
  ]) {
    for (final node in nodes) {
      if (node.nodeKey == key) return (node, parent);
      final found = _findNodeWithParent(node.childNodes, key, node);
      if (found != null) return found;
    }
    return null;
  }
}

/// Inclusive start / exclusive end boundaries for a sutta within a document.
///
/// [endPage]/[endEntry] mark where the NEXT sutta begins:
/// - If endEntry == 0, entries on endPage belong to the next sutta.
/// - If endEntry > 0, entries 0..endEntry-1 on endPage belong to this sutta.
class _SuttaBounds {
  final int startPage;
  final int startEntry;
  final int endPage;
  final int endEntry;

  const _SuttaBounds({
    required this.startPage,
    required this.startEntry,
    required this.endPage,
    required this.endEntry,
  });
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
