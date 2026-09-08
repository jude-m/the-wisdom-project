import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/constants.dart';
import '../../core/storage/key_value_store.dart';
import '../../core/storage/key_value_store_provider.dart';
import '../../core/storage/storage_keys.dart';
import '../../domain/entities/reader/reader_unit.dart';
import '../../domain/entities/search/search_result.dart';
import '../models/reader_layout.dart';
import '../models/reader_tab.dart';
import 'last_reader_layout_provider.dart';
import 'navigation_tree_provider.dart';
import 'navigator_sync_provider.dart';
import 'reader_unit_provider.dart';

/// State notifier for managing the list of reader tabs.
///
/// Hydrates from [KeyValueStore] on construction so previously open tabs
/// come back across app reloads. Every state change schedules a debounced
/// disk write — fast scroll updates that mutate [ReaderTab.scrollOffset]
/// coalesce into a single write.
///
/// Serialization is intentionally inlined here rather than hidden behind
/// a Repository<T> indirection. Tabs persistence is a pass-through over
/// [KeyValueStore]; an extra interface would be ceremony with no payoff.
class TabsNotifier extends StateNotifier<List<ReaderTab>> {
  TabsNotifier(this._store) : super(_loadTabs(_store)) {
    // fireImmediately:false — don't write back the value we just read.
    // Capture the RemoveListener so dispose() can detach explicitly. Not
    // strictly required (the notifier itself is being disposed), but it
    // future-proofs against accidental re-entrancy if dispose grows.
    _removeStateListener =
        addListener(_onStateChanged, fireImmediately: false);
  }

  final KeyValueStore _store;
  Timer? _saveDebounce;
  late final RemoveListener _removeStateListener;

  static const _saveDebounceDelay = Duration(milliseconds: 500);

  /// Reads and decodes the persisted tab list. On corruption (wrong
  /// shape, parse failure) the bad entry is removed and we start clean —
  /// same defensive posture as `RecentSearchesRepositoryImpl`.
  static List<ReaderTab> _loadTabs(KeyValueStore store) {
    final raw = store.getJsonList(StorageKeys.openTabs);
    if (raw == null) return const [];
    try {
      return raw
          .whereType<Map<String, dynamic>>()
          .map(ReaderTab.fromJson)
          .toList(growable: false);
    } catch (_) {
      store.remove(StorageKeys.openTabs);
      return const [];
    }
  }

  /// Encodes the current state and writes it to the KV store. Shared by
  /// the debounced auto-save path and the dispose-time flush so the JSON
  /// shape stays in lockstep.
  void _persistNow() {
    final list = state.map((t) => t.toJson()).toList(growable: false);
    _store.setJson(StorageKeys.openTabs, list);
  }

  void _onStateChanged(List<ReaderTab> _) {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(_saveDebounceDelay, _persistNow);
  }

  /// Adds a new tab and returns its index
  int addTab(ReaderTab tab) {
    state = [...state, tab];
    return state.length - 1;
  }

  /// Removes a tab at the specified index
  void removeTab(int index) {
    if (index >= 0 && index < state.length) {
      state = [
        ...state.sublist(0, index),
        ...state.sublist(index + 1),
      ];
    }
  }

  /// Updates a tab at the specified index
  void updateTab(int index, ReaderTab tab) {
    if (index >= 0 && index < state.length) {
      state = [
        ...state.sublist(0, index),
        tab,
        ...state.sublist(index + 1),
      ];
    }
  }

  /// Updates only the scroll offset for a tab.
  /// No-op if the offset hasn't changed (avoids spamming the debounce timer
  /// from `_onScroll` ticks that didn't actually move).
  void updateTabScrollOffset(int tabIndex, double offset) {
    if (tabIndex < 0 || tabIndex >= state.length) return;
    if (state[tabIndex].scrollOffset == offset) return;
    final updatedTab = state[tabIndex].copyWith(scrollOffset: offset);
    updateTab(tabIndex, updatedTab);
  }

  /// Drops the tab's landing row, which is a one-shot.
  ///
  /// The reader calls this the moment it applies the landing. [scrollOffset]
  /// cannot stand in for it: scrolling back to the beginning saves an offset
  /// of 0, and 0 is exactly what makes a landing apply — so without this the
  /// tab would snap back to the search hit on every re-activation, and again
  /// after a restart.
  void clearTabLanding(int tabIndex) {
    if (tabIndex < 0 || tabIndex >= state.length) return;
    final tab = state[tabIndex];
    if (tab.landingPageIndex == null && tab.landingEntryIndex == null) return;
    updateTab(
      tabIndex,
      tab.copyWith(landingPageIndex: null, landingEntryIndex: null),
    );
  }

  /// Clears all tabs
  void clearAll() {
    state = [];
  }

  /// Gets a tab by index
  ReaderTab? getTab(int index) {
    if (index >= 0 && index < state.length) {
      return state[index];
    }
    return null;
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _removeStateListener();
    // Best-effort flush of any pending state on shutdown. Fire-and-forget
    // is intentional: dispose() is sync, so awaiting the SharedPreferences
    // write is impossible. On web a `beforeunload` may not give the write
    // time to land — worst case the user loses up to ~500ms of edits, which
    // is the same window the debounced auto-save already permits.
    _persistNow();
    super.dispose();
  }
}

/// Provider for the list of reader tabs.
///
/// Uses `ref.read` for [keyValueStoreProvider] (not `watch`) — the store
/// is a service-like singleton overridden once in main.dart and never
/// replaced. `watch` would otherwise rebuild the entire [TabsNotifier]
/// (rehydrating from disk and dropping any pending debounced writes) if
/// the override ever changed.
final tabsProvider =
    StateNotifierProvider<TabsNotifier, List<ReaderTab>>((ref) {
  return TabsNotifier(ref.read(keyValueStoreProvider));
});

/// Provider for the currently active tab index (-1 means no tab selected).
///
/// Initial value is hydrated from disk so the previously active tab is
/// re-focused on launch. Falls back to 0 if the persisted index is out of
/// range relative to the currently loaded tabs, or to -1 if there are no
/// tabs at all. Uses `ref.read` (not `watch`) so future changes to
/// `tabsProvider` don't reset the user's selection.
final activeTabIndexProvider = StateProvider<int>((ref) {
  final store = ref.read(keyValueStoreProvider);
  final tabs = ref.read(tabsProvider);
  final stored = store.getInt(StorageKeys.activeTabIndex) ?? -1;
  if (stored >= 0 && stored < tabs.length) return stored;
  return tabs.isEmpty ? -1 : 0;
});

/// Listens to [activeTabIndexProvider] and writes every change to disk.
///
/// Must be instantiated once at app start (read it from main.dart) so the
/// listener is alive for the whole session. The save itself is fire-and-
/// forget — SharedPreferences is fast and a missed write would just mean
/// we restore one tab earlier on next launch.
///
/// Coalesces synchronous back-to-back changes (e.g. the deliberate
/// `-1` → `newIndex` flip in `closeTabProvider` used to force the
/// listener to fire) via a zero-duration timer so disk only sees the
/// final value per microtask batch.
final activeTabIndexPersistenceProvider = Provider<void>((ref) {
  Timer? debounce;
  ref.listen<int>(activeTabIndexProvider, (_, next) {
    debounce?.cancel();
    debounce = Timer(Duration.zero, () {
      ref.read(keyValueStoreProvider).setInt(StorageKeys.activeTabIndex, next);
    });
  });
  ref.onDispose(() => debounce?.cancel());
});

// ============================================================================
// DERIVED PROVIDERS
// These read from the active tab's state, providing reactive updates without
// duplicating state. When the active tab or its properties change, widgets
// watching these providers will automatically rebuild.
// ============================================================================

/// Derived provider for the active tab's node key.
///
/// The tab's whole identity: `activeReaderUnitProvider` turns it into the
/// content file and the row span the reader renders.
/// Returns null if no tab is selected or the tab has no node.
final activeNodeKeyProvider = Provider<String?>((ref) {
  final activeIndex = ref.watch(activeTabIndexProvider);
  final tabs = ref.watch(tabsProvider);
  if (activeIndex >= 0 && activeIndex < tabs.length) {
    return tabs[activeIndex].nodeKey;
  }
  return null;
});

/// Derived provider for active tab's reader layout mode
/// Returns paliOnly if no tab is selected (default for portrait mode)
final activeReaderLayoutProvider = Provider<ReaderLayout>((ref) {
  final activeIndex = ref.watch(activeTabIndexProvider);
  final tabs = ref.watch(tabsProvider);
  if (activeIndex >= 0 && activeIndex < tabs.length) {
    return tabs[activeIndex].layout;
  }
  return ReaderLayout.paliOnly;
});

/// Provider to update the reader layout of the active tab
/// Used when user changes layout in settings menu
final updateActiveTabLayoutProvider =
    Provider<void Function(ReaderLayout)>((ref) {
  return (ReaderLayout layout) {
    final activeIndex = ref.read(activeTabIndexProvider);
    final tabs = ref.read(tabsProvider);
    if (activeIndex >= 0 && activeIndex < tabs.length) {
      final updatedTab = tabs[activeIndex].copyWith(layout: layout);
      ref.read(tabsProvider.notifier).updateTab(activeIndex, updatedTab);
    }
    // Remember this choice (per device) so newly opened tabs seed their
    // layout from it. This is the single chokepoint both the layout pill and
    // the FAB selector call, so persisting here covers both entry points.
    ref.read(lastReaderLayoutProvider.notifier).set(layout);
  };
});

/// Derived provider for active tab's split ratio (for side-by-side layout)
/// Returns default ratio (0.5) if no tab is selected
final activeSplitRatioProvider = Provider<double>((ref) {
  final activeIndex = ref.watch(activeTabIndexProvider);
  final tabs = ref.watch(tabsProvider);
  if (activeIndex >= 0 && activeIndex < tabs.length) {
    return tabs[activeIndex].splitRatio;
  }
  return PaneWidthConstants.readerSplitDefault;
});

/// Provider to update the split ratio of the active tab
/// Used when user drags the resizable divider in side-by-side layout
final updateActiveTabSplitRatioProvider = Provider<void Function(double)>((ref) {
  return (double ratio) {
    final activeIndex = ref.read(activeTabIndexProvider);
    final tabs = ref.read(tabsProvider);
    if (activeIndex >= 0 && activeIndex < tabs.length) {
      // Snap to a 0.002 grid (≈2 logical pixels on a 1200px pane) so
      // sub-pixel drag deltas collapse into the same value. Coarser than
      // 0.001 to claw back fast-drag savings; finer than 0.005 so a
      // slow drag doesn't develop a perceptible dead zone.
      final quantized = (ratio * 500).round() / 500;
      final clampedRatio = quantized.clamp(
        PaneWidthConstants.readerSplitMin,
        PaneWidthConstants.readerSplitMax,
      );
      // Skip the state mutation when the snapped value matches the current
      // one — this is what actually drops the rebuild cascade.
      final current = tabs[activeIndex].splitRatio;
      if ((current - clampedRatio).abs() < 1e-9) return;
      final updatedTab = tabs[activeIndex].copyWith(splitRatio: clampedRatio);
      ref.read(tabsProvider.notifier).updateTab(activeIndex, updatedTab);
    }
  };
});

/// Provider to handle tab switching
/// Content state is derived automatically from the active tab via
/// [activeNodeKeyProvider] → `activeReaderUnitProvider`.
final switchTabProvider = Provider<void Function(int)>((ref) {
  return (int newTabIndex) {
    // Just update the active tab index - all content state is derived automatically
    ref.read(activeTabIndexProvider.notifier).state = newTabIndex;

    // Sync navigator to the new active tab
    ref.read(syncNavigatorToActiveTabProvider)();
  };
});

/// Provider to open a new tab from a search result.
///
/// **The unit comes from the row the hit is on, not from the result's stored
/// `nodeKey`.** `bjt-fts.db` implements the slicing rule against the *raw*
/// tree, so for the corrected coordinates its column names an adjacent
/// sibling — 244 rows corpus-wide open a unit the matched line is not in.
/// `ReaderUnitResolver.keyAt` derives the owner from the coordinate instead,
/// which also gives the tab and the breadcrumb the right sutta's name. It is
/// the one producer here that needs the resolver, and so the one that is
/// async.
///
/// Returns the new tab's index, or -1 if nothing opened. Callers must **await**
/// it before touching [activeTabIndexProvider] — reading that synchronously
/// after the call lands on the tab the user came from, which is where the FTS
/// highlight would then be set.
final openTabFromSearchResultProvider =
    Provider<Future<int> Function(SearchResult, {bool isPortraitMode})>((ref) {
  return (SearchResult result, {bool isPortraitMode = false}) async {
    // Seed the new tab's layout from the user's last selection, falling back to
    // the orientation default (see [resolveSeedLayout]). We no longer pick a
    // single-language mode based on result.language — both orientation defaults
    // show the matched language alongside its translation.
    final layout = resolveSeedLayout(ref, isPortraitMode: isPortraitMode);

    final resolver = await _resolver(ref);
    final hitKey = resolver?.keyAt(
          result.contentFileId,
          result.pageIndex,
          result.entryIndex,
        ) ??
        result.nodeKey;
    final node = ref.read(nodeByKeyProvider(hitKey));
    final newIndex = _openTab(
      ref,
      ReaderTab.fromNode(
        nodeKey: hitKey,
        // Seed both names from the tree node so the tab label can follow the
        // Content Language setting (just like tree-opened tabs). Fall back to
        // the result's matched title only when the node isn't in the tree.
        paliName: (node != null && node.paliName.isNotEmpty)
            ? node.paliName
            : result.title,
        sinhalaName: (node != null && node.sinhalaName.isNotEmpty)
            ? node.sinhalaName
            : result.title,
        // Land on the matched row, not on the sutta's first line — the whole
        // unit renders either way, so this is scroll position and nothing more.
        landingPageIndex: result.pageIndex,
        landingEntryIndex: result.entryIndex,
        layout: layout,
      ),
    );

    // Sync navigator to the new active tab
    ref.read(syncNavigatorToActiveTabProvider)();
    return newIndex;
  };
});

/// Opens a new tab for the given tree node key.
///
/// Centralizes the tab-from-node creation used by the tree navigator,
/// breadcrumb widget and deep links. Callers pass [isPortraitMode] (derived
/// from BuildContext) since providers can't access context.
///
/// [pageIndex]/[entryStart] optionally name a landing row inside the unit —
/// used by deep links carrying an entry-level position (`?e=<page>.<entry>`).
/// They never decide *which* unit opens; that is always [nodeKey]'s own.
///
/// Returns the new tab index, or -1 if the node is not in the tree.
///
/// **Side effects NOT included** (caller-specific):
/// - Tree navigator: calls `selectNodeProvider` before, closes nav on mobile after
/// - Breadcrumb: calls `syncNavigatorToActiveTabProvider` after
final openTabFromNodeKeyProvider = Provider<
    int Function(String nodeKey,
        {bool isPortraitMode, int? pageIndex, int? entryStart})>((ref) {
  return (String nodeKey,
      {bool isPortraitMode = false, int? pageIndex, int? entryStart}) {
    final node = ref.read(nodeByKeyProvider(nodeKey));
    if (node == null) return -1;

    // Seed from the user's last layout choice, falling back to the orientation
    // default (see [resolveSeedLayout]).
    final layout = resolveSeedLayout(ref, isPortraitMode: isPortraitMode);

    return _openTab(
      ref,
      ReaderTab.fromNode(
        nodeKey: nodeKey,
        paliName: node.paliName,
        sinhalaName: node.sinhalaName,
        landingPageIndex: pageIndex,
        // A page override with no entry means "start of that page" — never
        // the node's own entry, which pairs with the node's page.
        landingEntryIndex: pageIndex == null ? null : (entryStart ?? 0),
        layout: layout,
      ),
    );
  };
});

/// The unit resolver, or null when it will not load.
///
/// Answers "no tab" rather than throwing: opening a tab must not become the one
/// place a tree problem surfaces as a crash.
Future<ReaderUnitResolver?> _resolver(Ref ref) async {
  try {
    return await ref.read(readerUnitResolverProvider.future);
  } catch (_) {
    return null;
  }
}

/// Appends [tab] and focuses it. The last two lines of every producer.
int _openTab(Ref ref, ReaderTab tab) {
  final newIndex = ref.read(tabsProvider.notifier).addTab(tab);
  ref.read(activeTabIndexProvider.notifier).state = newIndex;
  return newIndex;
}
