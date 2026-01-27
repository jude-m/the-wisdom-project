import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/reader_tab.dart';
import 'navigation_tree_provider.dart';
import 'navigator_sync_provider.dart';
import 'tab_provider.dart';

/// Checks if the current content is a commentary (atthakatha).
/// Returns true if nodeKey starts with 'atta-'.
final isCommentaryProvider = Provider<bool>((ref) {
  final nodeKey = ref.watch(activeNodeKeyProvider);
  return nodeKey?.startsWith('atta-') ?? false;
});

/// Gets the parallel text node for navigation between root text and commentary.
/// - If viewing root text (e.g., 'mn-2-3-6'), returns commentary node ('atta-mn-2-3-6')
/// - If viewing commentary (e.g., 'atta-mn-2-3-6'), returns root text node ('mn-2-3-6')
/// Returns null if no valid parallel text exists in the navigation tree.
///
/// This is the primary provider for parallel text linking - use it to:
/// - Check if navigation is available (non-null means button should show)
/// - Get all target node details (name, position, etc.)
final parallelTextNodeProvider = Provider.autoDispose((ref) {
  final nodeKey = ref.watch(activeNodeKeyProvider);
  if (nodeKey == null || nodeKey.isEmpty) {
    return null;
  }

  // Compute target key: toggle between root text and commentary
  final targetKey = nodeKey.startsWith('atta-')
      ? nodeKey.substring(5) // Remove 'atta-' prefix
      : 'atta-$nodeKey'; // Add 'atta-' prefix

  // Return the node directly (null if doesn't exist in tree)
  return ref.watch(nodeByKeyProvider(targetKey));
});

/// Action provider to open the parallel text in a new tab.
/// Creates a new tab from the target node and makes it active.
final openParallelTextProvider = Provider<void Function()>((ref) {
  return () {
    final targetNode = ref.read(parallelTextNodeProvider);
    if (targetNode == null) {
      return;
    }

    // Create a new tab from the target node
    final newTab = ReaderTab.fromNode(
      nodeKey: targetNode.nodeKey,
      paliName: targetNode.paliName,
      sinhalaName: targetNode.sinhalaName,
      contentFileId: targetNode.contentFileId,
      pageIndex: targetNode.entryPageIndex,
      entryStart: targetNode.entryIndexInPage,
    );

    // Add tab and make it active
    final newIndex = ref.read(tabsProvider.notifier).addTab(newTab);
    ref.read(activeTabIndexProvider.notifier).state = newIndex;

    // Sync navigator to the new active tab
    ref.read(syncNavigatorToActiveTabProvider)();
  };
});
