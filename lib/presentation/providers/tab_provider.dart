import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/constants.dart';
import '../../core/storage/key_value_store.dart';
import '../../core/storage/key_value_store_provider.dart';
import '../../core/storage/storage_keys.dart';
import '../../domain/entities/search/search_result.dart';
import '../models/reader_layout.dart';
import '../models/reader_tab.dart';
import 'navigation_tree_provider.dart';
import 'navigator_sync_provider.dart';

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

  /// Updates the page index of a tab
  void updateTabPage(int tabIndex, int pageIndex) {
    if (tabIndex >= 0 && tabIndex < state.length) {
      final updatedTab = state[tabIndex].copyWith(pageIndex: pageIndex);
      updateTab(tabIndex, updatedTab);
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

/// Derived provider for active tab's content file ID
/// Returns null if no tab is selected or tab has no content
final activeContentFileIdProvider = Provider<String?>((ref) {
  final activeIndex = ref.watch(activeTabIndexProvider);
  final tabs = ref.watch(tabsProvider);
  if (activeIndex >= 0 && activeIndex < tabs.length) {
    return tabs[activeIndex].contentFileId;
  }
  return null;
});

/// Derived provider for active tab's node key
/// Returns null if no tab is selected or tab has no nodeKey
/// Use this when you need the specific node (e.g., 'mn-2-3-6' for a sutta)
/// rather than the content file (e.g., 'mn-2-3' shared by multiple suttas)
final activeNodeKeyProvider = Provider<String?>((ref) {
  final activeIndex = ref.watch(activeTabIndexProvider);
  final tabs = ref.watch(tabsProvider);
  if (activeIndex >= 0 && activeIndex < tabs.length) {
    return tabs[activeIndex].nodeKey;
  }
  return null;
});

/// Derived provider for active tab's page index
/// Returns 0 if no tab is selected
final activePageIndexProvider = Provider<int>((ref) {
  final activeIndex = ref.watch(activeTabIndexProvider);
  final tabs = ref.watch(tabsProvider);
  if (activeIndex >= 0 && activeIndex < tabs.length) {
    return tabs[activeIndex].pageIndex;
  }
  return 0;
});

/// Derived provider for active tab's pageStart
/// Returns 0 if no tab is selected
final activePageStartProvider = Provider<int>((ref) {
  final activeIndex = ref.watch(activeTabIndexProvider);
  final tabs = ref.watch(tabsProvider);
  if (activeIndex >= 0 && activeIndex < tabs.length) {
    return tabs[activeIndex].pageStart;
  }
  return 0;
});

/// Derived provider for active tab's pageEnd
/// Returns 1 if no tab is selected (default single page)
final activePageEndProvider = Provider<int>((ref) {
  final activeIndex = ref.watch(activeTabIndexProvider);
  final tabs = ref.watch(tabsProvider);
  if (activeIndex >= 0 && activeIndex < tabs.length) {
    return tabs[activeIndex].pageEnd;
  }
  return 1;
});

/// Derived provider for active tab's entryStart
/// Returns 0 if no tab is selected
final activeEntryStartProvider = Provider<int>((ref) {
  final activeIndex = ref.watch(activeTabIndexProvider);
  final tabs = ref.watch(tabsProvider);
  if (activeIndex >= 0 && activeIndex < tabs.length) {
    return tabs[activeIndex].entryStart;
  }
  return 0;
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

/// Provider to update pagination state for the active tab
/// Used when loading more pages during scrolling
final updateActiveTabPaginationProvider =
    Provider<void Function({int? pageStart, int? pageEnd, int? entryStart})>(
        (ref) {
  return ({int? pageStart, int? pageEnd, int? entryStart}) {
    final activeIndex = ref.read(activeTabIndexProvider);
    final tabs = ref.read(tabsProvider);
    if (activeIndex >= 0 && activeIndex < tabs.length) {
      final currentTab = tabs[activeIndex];
      final updatedTab = currentTab.copyWith(
        pageStart: pageStart ?? currentTab.pageStart,
        pageEnd: pageEnd ?? currentTab.pageEnd,
        entryStart: entryStart ?? currentTab.entryStart,
      );
      ref.read(tabsProvider.notifier).updateTab(activeIndex, updatedTab);
    }
  };
});

/// Provider to update the page index of the active tab
/// Used for next/previous page navigation
final updateActiveTabPageIndexProvider = Provider<void Function(int)>((ref) {
  return (int pageIndex) {
    final activeIndex = ref.read(activeTabIndexProvider);
    ref.read(tabsProvider.notifier).updateTabPage(activeIndex, pageIndex);
  };
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
      // Clamp ratio to allowed range
      final clampedRatio = ratio.clamp(
        PaneWidthConstants.readerSplitMin,
        PaneWidthConstants.readerSplitMax,
      );
      final updatedTab = tabs[activeIndex].copyWith(splitRatio: clampedRatio);
      ref.read(tabsProvider.notifier).updateTab(activeIndex, updatedTab);
    }
  };
});

/// Provider to handle tab switching
/// Content and pagination state are derived automatically from the active tab via:
/// - activeContentFileIdProvider
/// - activePageIndexProvider
/// - activePageStartProvider, activePageEndProvider, activeEntryStartProvider
final switchTabProvider = Provider<void Function(int)>((ref) {
  return (int newTabIndex) {
    // Just update the active tab index - all content state is derived automatically
    ref.read(activeTabIndexProvider.notifier).state = newTabIndex;

    // Sync navigator to the new active tab
    ref.read(syncNavigatorToActiveTabProvider)();
  };
});

/// Provider to open a new tab from a search result
/// Centralizes the tab creation and navigation logic used across search widgets
/// All state (contentFileId, pageIndex, pagination, layout) is derived from the tab entity
final openTabFromSearchResultProvider =
    Provider<void Function(SearchResult, {bool isPortraitMode})>((ref) {
  return (SearchResult result, {bool isPortraitMode = false}) {
    // Determine layout based on result language
    // In portrait mode: show the language matching the search result
    // In landscape mode: show side by side
    final ReaderLayout layout;
    if (isPortraitMode) {
      layout = result.language == 'sinhala'
          ? ReaderLayout.sinhalaOnly
          : ReaderLayout.paliOnly;
    } else {
      layout = ReaderLayout.sideBySide;
    }

    // Snap entryStart to sutta beginning if the FTS match is near the start.
    // This prevents showing a misleading "Scroll to beginning" button when
    // the match is only 1-2 entries after the sutta's true start (e.g., the
    // sutta number row "1. 2. 9." is skipped).
    int entryStart = result.entryIndex;
    final node = ref.read(nodeByKeyProvider(result.nodeKey));
    if (node != null &&
        result.pageIndex == node.entryPageIndex &&
        result.entryIndex - node.entryIndexInPage <= 2) {
      entryStart = node.entryIndexInPage;
    }

    // Create a new tab for the search result with entryStart for proper positioning
    // This ensures the sutta title appears at the top, not content from a previous
    // sutta that happens to share the same page
    final newTab = ReaderTab.fromNode(
      nodeKey: result.nodeKey,
      paliName:
          result.title, // For search results, title may differ by language
      sinhalaName: result.title,
      contentFileId: result.contentFileId,
      pageIndex: result.pageIndex,
      entryStart: entryStart,
      layout: layout,
    );

    // Add tab and make it active
    // Content and pagination state are derived automatically from the tab via:
    // - activeContentFileIdProvider
    // - activePageIndexProvider
    // - activePageStartProvider, activePageEndProvider, activeEntryStartProvider
    // - activeReaderLayoutProvider
    final newIndex = ref.read(tabsProvider.notifier).addTab(newTab);
    ref.read(activeTabIndexProvider.notifier).state = newIndex;

    // Sync navigator to the new active tab
    ref.read(syncNavigatorToActiveTabProvider)();
  };
});

/// Opens a new tab for the given tree node key.
///
/// Centralizes the tab-from-node creation used by the tree navigator and
/// breadcrumb widget. Callers pass [isPortraitMode] (derived from
/// BuildContext) since providers can't access context.
///
/// Returns the new tab index, or -1 if the node was not found.
///
/// **Side effects NOT included** (caller-specific):
/// - Tree navigator: calls `selectNodeProvider` before, closes nav on mobile after
/// - Breadcrumb: calls `syncNavigatorToActiveTabProvider` after
final openTabFromNodeKeyProvider =
    Provider<int Function(String nodeKey, {bool isPortraitMode})>((ref) {
  return (String nodeKey, {bool isPortraitMode = false}) {
    final node = ref.read(nodeByKeyProvider(nodeKey));
    if (node == null) return -1;

    final layout = isPortraitMode
        ? ReaderLayout.paliOnly
        : ReaderLayout.sideBySide;

    final newTab = ReaderTab.fromNode(
      nodeKey: node.nodeKey,
      paliName: node.paliName,
      sinhalaName: node.sinhalaName,
      contentFileId: node.isReadableContent ? node.contentFileId : null,
      pageIndex: node.isReadableContent ? node.entryPageIndex : 0,
      entryStart: node.isReadableContent ? node.entryIndexInPage : 0,
      layout: layout,
    );

    final newIndex = ref.read(tabsProvider.notifier).addTab(newTab);
    ref.read(activeTabIndexProvider.notifier).state = newIndex;
    return newIndex;
  };
});
