import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/constants.dart';
import '../models/column_display_mode.dart';
import '../models/reader_tab.dart';
import '../../domain/entities/search/search_result.dart';
import 'in_page_search_provider.dart';
import 'navigation_tree_provider.dart';
import 'navigator_sync_provider.dart';

/// State notifier for managing the list of reader tabs
class TabsNotifier extends StateNotifier<List<ReaderTab>> {
  TabsNotifier() : super([]);

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
}

/// Provider for the list of reader tabs
final tabsProvider =
    StateNotifierProvider<TabsNotifier, List<ReaderTab>>((ref) {
  return TabsNotifier();
});

/// Provider for the currently active tab index (-1 means no tab selected)
final activeTabIndexProvider = StateProvider<int>((ref) => -1);

/// Provider for in-memory scroll positions (Map<tabIndex, scrollOffset>)
final tabScrollPositionsProvider = StateProvider<Map<int, double>>((ref) => {});

/// Provider to save scroll position for a tab
final saveTabScrollPositionProvider =
    Provider<void Function(int, double)>((ref) {
  return (int tabIndex, double scrollOffset) {
    final positions = ref.read(tabScrollPositionsProvider);
    ref.read(tabScrollPositionsProvider.notifier).state = {
      ...positions,
      tabIndex: scrollOffset,
    };
  };
});

/// Provider to get scroll position for a tab (returns 0.0 if not found)
final getTabScrollPositionProvider = Provider<double Function(int)>((ref) {
  return (int tabIndex) {
    final positions = ref.read(tabScrollPositionsProvider);
    return positions[tabIndex] ?? 0.0;
  };
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

/// Derived provider for active tab's column display mode
/// Returns paliOnly if no tab is selected (default for portrait mode)
final activeColumnModeProvider = Provider<ColumnDisplayMode>((ref) {
  final activeIndex = ref.watch(activeTabIndexProvider);
  final tabs = ref.watch(tabsProvider);
  if (activeIndex >= 0 && activeIndex < tabs.length) {
    return tabs[activeIndex].columnMode;
  }
  return ColumnDisplayMode.paliOnly;
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

/// Provider to update the column display mode of the active tab
/// Used when user changes column mode in settings menu
final updateActiveTabColumnModeProvider =
    Provider<void Function(ColumnDisplayMode)>((ref) {
  return (ColumnDisplayMode mode) {
    final activeIndex = ref.read(activeTabIndexProvider);
    final tabs = ref.read(tabsProvider);
    if (activeIndex >= 0 && activeIndex < tabs.length) {
      final updatedTab = tabs[activeIndex].copyWith(columnMode: mode);
      ref.read(tabsProvider.notifier).updateTab(activeIndex, updatedTab);
    }
  };
});

/// Derived provider for active tab's split ratio (for "both" column mode)
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
/// Used when user drags the resizable divider in "both" column mode
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

/// Provider to close a tab
/// Content state is derived automatically from the active tab
final closeTabProvider = Provider<void Function(int)>((ref) {
  return (int tabIndex) {
    final tabs = ref.read(tabsProvider);
    final currentTabIndex = ref.read(activeTabIndexProvider);
    final isClosingActiveTab = tabIndex == currentTabIndex;

    // Remove the tab
    ref.read(tabsProvider.notifier).removeTab(tabIndex);

    // Remove in-page search state for this tab and re-index remaining tabs
    ref.read(inPageSearchStatesProvider.notifier).onTabClosed(tabIndex);

    // Remove scroll position for this tab
    final positions = ref.read(tabScrollPositionsProvider);
    final updatedPositions = Map<int, double>.from(positions);
    updatedPositions.remove(tabIndex);

    // Adjust scroll positions for tabs after the closed tab
    final newPositions = <int, double>{};
    updatedPositions.forEach((key, value) {
      if (key < tabIndex) {
        newPositions[key] = value;
      } else {
        newPositions[key - 1] = value;
      }
    });
    ref.read(tabScrollPositionsProvider.notifier).state = newPositions;

    // Update active tab index
    if (isClosingActiveTab) {
      // If we closed the active tab, switch to the previous tab or -1 if no tabs left
      final newActiveIndex =
          tabIndex > 0 ? tabIndex - 1 : (tabs.length > 1 ? 0 : -1);

      // Set to -1 first to force the activeTabIndexProvider listener to fire
      // This ensures the widget properly resets scroll position when the new
      // active tab ends up at the same index as the closed tab
      ref.read(activeTabIndexProvider.notifier).state = -1;
      ref.read(activeTabIndexProvider.notifier).state = newActiveIndex;

      // Content is derived automatically from the new active tab
      // No explicit loading needed - activeContentFileIdProvider and
      // activePageIndexProvider will update based on the new active tab

      if (newActiveIndex < 0) {
        // No tabs left - reset to initial state
        ref.read(tabScrollPositionsProvider.notifier).state = {};
        ref.read(inPageSearchStatesProvider.notifier).clearAll();
        ref.read(selectedNodeProvider.notifier).state = null;
        ref.read(expandedNodesProvider.notifier).state = {TipitakaNodeKeys.suttaPitaka};
      } else {
        // Sync navigator to the new active tab
        ref.read(syncNavigatorToActiveTabProvider)();
      }
    } else if (tabIndex < currentTabIndex) {
      // If we closed a tab before the active one, adjust the active index
      ref.read(activeTabIndexProvider.notifier).state = currentTabIndex - 1;

      // Sync navigator to the adjusted active tab
      ref.read(syncNavigatorToActiveTabProvider)();
    }
  };
});

/// Provider to open a new tab from a search result
/// Centralizes the tab creation and navigation logic used across search widgets
/// All state (contentFileId, pageIndex, pagination, columnMode) is derived from the tab entity
final openTabFromSearchResultProvider =
    Provider<void Function(SearchResult, {bool isPortraitMode})>((ref) {
  return (SearchResult result, {bool isPortraitMode = false}) {
    // Determine column mode based on result language
    // In portrait mode: show the language matching the search result
    // In landscape mode: show both columns
    final ColumnDisplayMode columnMode;
    if (isPortraitMode) {
      columnMode = result.language == 'sinhala'
          ? ColumnDisplayMode.sinhalaOnly
          : ColumnDisplayMode.paliOnly;
    } else {
      columnMode = ColumnDisplayMode.both;
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
      entryStart: result.entryIndex,
      columnMode: columnMode,
    );

    // Add tab and make it active
    // Content and pagination state are derived automatically from the tab via:
    // - activeContentFileIdProvider
    // - activePageIndexProvider
    // - activePageStartProvider, activePageEndProvider, activeEntryStartProvider
    // - activeColumnModeProvider
    final newIndex = ref.read(tabsProvider.notifier).addTab(newTab);
    ref.read(activeTabIndexProvider.notifier).state = newIndex;

    // Sync navigator to the new active tab
    ref.read(syncNavigatorToActiveTabProvider)();
  };
});
