import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/navigation/tipitaka_tree_node.dart';
import '../models/reader_tab.dart';
import 'fts_highlight_provider.dart';
import 'in_page_search_provider.dart';
import 'navigator_sync_provider.dart';
import 'tab_provider.dart';

/// Provider to move the active tab to another sutta.
///
/// Updates the tab in-place using [ReaderTab.fromNode], preserving the user's
/// column mode and split ratio preferences from the current tab.
///
/// Direction-free: which node is the neighbour is `neighbourLeafProvider`'s
/// answer, not this one's, so the same call serves the reader's previous and
/// next buttons. Leaving a container unit steps to the sutta on the other side
/// of the whole subtree, so a vagga is one stop rather than as many as it
/// holds.
///
/// Extracted to a separate file (like [syncNavigatorToActiveTabProvider]) to
/// avoid circular imports between tab_provider, fts_highlight_provider, and
/// in_page_search_provider.
final navigateToSuttaProvider =
    Provider<void Function(TipitakaTreeNode)>((ref) {
  return (TipitakaTreeNode target) {
    final activeIndex = ref.read(activeTabIndexProvider);
    final tabs = ref.read(tabsProvider);
    if (activeIndex < 0 || activeIndex >= tabs.length) return;

    final currentTab = tabs[activeIndex];

    // Clear stale FTS highlights and close in-page search from old sutta
    ref.read(ftsHighlightProvider.notifier).clearForActiveTab();
    ref.read(inPageSearchStatesProvider.notifier).closeSearch();

    // Build from the canonical factory, then preserve the user's display
    // preferences (layout, splitRatio) from the current tab.
    // ReaderTab.fromNode produces scrollOffset:0 and no landing row, so the
    // new sutta starts at its own top.
    final baseTab = ReaderTab.fromNode(
      nodeKey: target.nodeKey,
      paliName: target.paliName,
      sinhalaName: target.sinhalaName,
      layout: currentTab.layout,
    );
    final updatedTab = baseTab.copyWith(splitRatio: currentTab.splitRatio);
    ref.read(tabsProvider.notifier).updateTab(activeIndex, updatedTab);

    // Sync navigator tree to highlight the new sutta
    ref.read(syncNavigatorToActiveTabProvider)();
  };
});
