import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/constants.dart';
import 'fts_highlight_provider.dart';
import 'in_page_search_provider.dart';
import 'navigation_tree_provider.dart';
import 'navigator_sync_provider.dart';
import 'tab_provider.dart';

/// Provider to close a tab.
///
/// This provider is extracted to a separate file to avoid circular imports
/// between tab_provider.dart, fts_highlight_provider.dart, and
/// in_page_search_provider.dart. It acts as a coordinator that depends on
/// all three providers.
final closeTabProvider = Provider<void Function(int)>((ref) {
  return (int tabIndex) {
    final tabs = ref.read(tabsProvider);
    final currentTabIndex = ref.read(activeTabIndexProvider);
    final isClosingActiveTab = tabIndex == currentTabIndex;

    // Remove the tab
    ref.read(tabsProvider.notifier).removeTab(tabIndex);

    // Remove per-tab state for this tab and re-index remaining tabs
    ref.read(inPageSearchStatesProvider.notifier).onTabClosed(tabIndex);
    ref.read(ftsHighlightProvider.notifier).onTabClosed(tabIndex);

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
        ref.read(ftsHighlightProvider.notifier).clearAll();
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
