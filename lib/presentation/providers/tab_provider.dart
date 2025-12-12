import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/reader_tab.dart';
import '../../domain/entities/search/search_result.dart';
import 'document_provider.dart';

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

/// Provider to handle tab switching (saves scroll position and loads new tab)
final switchTabProvider = Provider<void Function(int)>((ref) {
  return (int newTabIndex) {
    // Update active tab index
    ref.read(activeTabIndexProvider.notifier).state = newTabIndex;

    // Load content for the new tab
    final tabs = ref.read(tabsProvider);
    if (newTabIndex >= 0 && newTabIndex < tabs.length) {
      final tab = tabs[newTabIndex];
      if (tab.hasContent) {
        // Set the content file ID and page index
        ref.read(currentContentFileIdProvider.notifier).state =
            tab.contentFileId;
        ref.read(currentPageIndexProvider.notifier).state = tab.pageIndex;

        // Restore pagination state from the tab (don't reset it)
        ref.read(pageStartProvider.notifier).state = tab.pageStart;
        ref.read(pageEndProvider.notifier).state = tab.pageEnd;
      }
    }
  };
});

/// Provider to close a tab
final closeTabProvider = Provider<void Function(int)>((ref) {
  return (int tabIndex) {
    final tabs = ref.read(tabsProvider);
    final currentTabIndex = ref.read(activeTabIndexProvider);
    final isClosingActiveTab = tabIndex == currentTabIndex;

    // Remove the tab
    ref.read(tabsProvider.notifier).removeTab(tabIndex);

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

      // Load content for the new active tab
      if (newActiveIndex >= 0) {
        final newTabs = ref.read(tabsProvider);
        if (newActiveIndex < newTabs.length) {
          final newActiveTab = newTabs[newActiveIndex];
          if (newActiveTab.hasContent) {
            ref.read(loadContentForNodeProvider)(
              newActiveTab.contentFileId,
              newActiveTab.pageIndex,
            );
          }
        }
      } else {
        // No tabs left - clear the content to show "Select a sutta..." message
        ref.read(loadContentForNodeProvider)(null, 0);
        // Also clear all scroll positions since no tabs exist
        ref.read(tabScrollPositionsProvider.notifier).state = {};
      }
    } else if (tabIndex < currentTabIndex) {
      // If we closed a tab before the active one, adjust the active index
      ref.read(activeTabIndexProvider.notifier).state = currentTabIndex - 1;
    }
  };
});

/// Provider to open a new tab from a search result
/// Centralizes the tab creation and navigation logic used across search widgets
final openTabFromSearchResultProvider =
    Provider<void Function(SearchResult)>((ref) {
  return (SearchResult result) {
    // Create a new tab for the search result
    final newTab = ReaderTab.fromNode(
      nodeKey: result.nodeKey,
      paliName:
          result.title, // For search results, title may differ by language
      sinhalaName: result.title,
      contentFileId: result.contentFileId,
      pageIndex: result.pageIndex,
    );

    // Add tab and make it active
    final newIndex = ref.read(tabsProvider.notifier).addTab(newTab);
    ref.read(activeTabIndexProvider.notifier).state = newIndex;

    // Set the content file and page index
    ref.read(currentContentFileIdProvider.notifier).state =
        result.contentFileId;
    ref.read(currentPageIndexProvider.notifier).state = result.pageIndex;

    // Set pagination state from the new tab (consistent with tree navigation)
    ref.read(pageStartProvider.notifier).state = newTab.pageStart;
    ref.read(pageEndProvider.notifier).state = newTab.pageEnd;
  };
});
