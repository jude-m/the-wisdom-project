import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/navigation/tipitaka_tree_node.dart';
import '../models/reader_tab.dart';
import 'fts_highlight_provider.dart';
import 'in_page_search_provider.dart';
import 'navigator_sync_provider.dart';
import 'tab_provider.dart';

/// Provider to navigate the active tab to the previous sutta in tree order.
///
/// Updates the tab in-place using [ReaderTab.fromNode], preserving the user's
/// column mode and split ratio preferences from the current tab.
///
/// Extracted to a separate file (like [syncNavigatorToActiveTabProvider]) to
/// avoid circular imports between tab_provider, fts_highlight_provider, and
/// in_page_search_provider.
final navigateToPreviousSuttaProvider =
    Provider<void Function(TipitakaTreeNode)>((ref) {
  return (TipitakaTreeNode previousNode) {
    final activeIndex = ref.read(activeTabIndexProvider);
    final tabs = ref.read(tabsProvider);
    if (activeIndex < 0 || activeIndex >= tabs.length) return;

    final currentTab = tabs[activeIndex];

    // Clear stale FTS highlights and close in-page search from old sutta
    ref.read(ftsHighlightProvider.notifier).clearForActiveTab();
    ref.read(inPageSearchStatesProvider.notifier).closeSearch();

    // Save scroll position as 0 for this tab (new sutta starts at top)
    ref.read(saveTabScrollPositionProvider)(activeIndex, 0);

    // Build from the canonical factory, then preserve the user's display
    // preferences (layout, splitRatio) from the current tab.
    final baseTab = ReaderTab.fromNode(
      nodeKey: previousNode.nodeKey,
      paliName: previousNode.paliName,
      sinhalaName: previousNode.sinhalaName,
      contentFileId: previousNode.contentFileId,
      pageIndex: previousNode.entryPageIndex,
      entryStart: previousNode.entryIndexInPage,
      layout: currentTab.layout,
    );
    final updatedTab = baseTab.copyWith(splitRatio: currentTab.splitRatio);
    ref.read(tabsProvider.notifier).updateTab(activeIndex, updatedTab);

    // Sync navigator tree to highlight the new sutta
    ref.read(syncNavigatorToActiveTabProvider)();
  };
});
