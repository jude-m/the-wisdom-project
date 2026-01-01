import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'navigation_tree_provider.dart';
import 'tab_provider.dart';

/// Syncs navigator selection to match the currently active tab.
///
/// This provider is extracted to a separate file to avoid circular imports
/// between navigation_tree_provider.dart and tab_provider.dart.
/// It acts as a coordinator that depends on both providers.
final syncNavigatorToActiveTabProvider = Provider<void Function()>((ref) {
  return () {
    final activeIndex = ref.read(activeTabIndexProvider);
    final tabs = ref.read(tabsProvider);

    // Edge case: no active tab or invalid index
    if (activeIndex < 0 || activeIndex >= tabs.length) {
      return;
    }

    final activeTab = tabs[activeIndex];
    final nodeKey = activeTab.nodeKey;

    // Edge case: tab has no nodeKey
    if (nodeKey == null || nodeKey.isEmpty) {
      return;
    }

    // Collapse all nodes first for a clean view
    ref.read(expandedNodesProvider.notifier).state = {};

    // Expand path to make node visible
    ref.read(expandPathToNodeProvider)(nodeKey);

    // Null-then-set pattern: Forces Riverpod listeners to fire even when
    // re-selecting the same node. Without this, ref.listen won't trigger
    // if the value hasn't changed (e.g., clicking the same tab twice).
    ref.read(selectedNodeProvider.notifier).state = null;
    ref.read(selectNodeProvider)(nodeKey);

    // Same pattern for scroll request - ensures scroll happens even if
    // the same node is already selected
    ref.read(scrollToNodeRequestProvider.notifier).state = null;
    ref.read(scrollToNodeRequestProvider.notifier).state = nodeKey;
  };
});
