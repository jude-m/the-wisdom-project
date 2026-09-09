import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'navigation_tree_provider.dart';
import 'tab_provider.dart';

/// Syncs navigator selection to match the currently active tab.
///
/// Extracted to a separate file to avoid a circular import between
/// navigation_tree_provider.dart and tab_provider.dart — it reads from both.
final syncNavigatorToActiveTabProvider = Provider<void Function()>((ref) {
  return () {
    // Nothing to sync when there is no active tab, or it holds no node.
    final nodeKey = ref.read(activeTabProvider)?.nodeKey;
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
