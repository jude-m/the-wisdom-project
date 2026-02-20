import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tab_provider.dart';

/// State for highlighting search terms in the reader after clicking an FTS result.
///
/// This is transient UI state that is:
/// - Set when opening a tab from a search result
/// - Cleared when the user taps anywhere in the reader
///
/// Separate from dictionary highlight (which uses `dictionaryHighlightProvider`).
class FtsHighlightState {
  /// The search query text (already sanitized + Singlish converted).
  final String queryText;

  /// Phrase mode: words must appear adjacent. Otherwise within proximity.
  final bool isPhraseSearch;

  /// Exact mode: exact token match. Otherwise prefix matching.
  final bool isExactMatch;

  const FtsHighlightState({
    required this.queryText,
    required this.isPhraseSearch,
    required this.isExactMatch,
  });
}

/// Manages per-tab FTS highlight state.
///
/// State is a Map<int, FtsHighlightState> keyed by tab index,
/// following the same pattern as [InPageSearchNotifier] and
/// [tabScrollPositionsProvider].
class FtsHighlightNotifier extends StateNotifier<Map<int, FtsHighlightState>> {
  final Ref _ref;

  FtsHighlightNotifier(this._ref) : super({});

  /// Sets highlight state for a specific tab.
  void setForTab(int tabIndex, FtsHighlightState highlight) {
    state = {...state, tabIndex: highlight};
  }

  /// Clears highlight state for the currently active tab.
  ///
  /// Widgets call this instead of [clearForTab] so they don't need to
  /// know about [activeTabIndexProvider] themselves.
  void clearForActiveTab() {
    final tabIndex = _ref.read(activeTabIndexProvider);
    clearForTab(tabIndex);
  }

  /// Clears highlight state for a specific tab.
  void clearForTab(int tabIndex) {
    if (!state.containsKey(tabIndex)) return;
    state = Map.from(state)..remove(tabIndex);
  }

  /// Removes state for a closed tab and re-indexes remaining tabs.
  ///
  /// Same pattern as [InPageSearchNotifier.onTabClosed].
  void onTabClosed(int tabIndex) {
    final updated = <int, FtsHighlightState>{};
    state.forEach((key, value) {
      if (key < tabIndex) {
        updated[key] = value;
      } else if (key > tabIndex) {
        updated[key - 1] = value;
      }
      // key == tabIndex is removed
    });
    state = updated;
  }

  /// Removes all highlight state (e.g., when all tabs are closed).
  void clearAll() {
    state = {};
  }
}

/// Per-tab FTS highlight state map (tab index → highlight state).
final ftsHighlightProvider =
    StateNotifierProvider<FtsHighlightNotifier, Map<int, FtsHighlightState>>(
  (ref) => FtsHighlightNotifier(ref),
);

/// Derived provider: the FTS highlight state for the currently active tab.
///
/// Returns null if no FTS highlight is set for the active tab.
/// Same pattern as [activeInPageSearchStateProvider].
final activeFtsHighlightProvider = Provider<FtsHighlightState?>((ref) {
  final tabIndex = ref.watch(activeTabIndexProvider);
  final states = ref.watch(ftsHighlightProvider);
  return states[tabIndex];
});
