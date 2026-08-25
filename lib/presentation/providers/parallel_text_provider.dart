import 'package:flutter_riverpod/flutter_riverpod.dart';
// `TipitakaNodeKeys` comes from here, not the app's constants.dart, which
// re-exports the same shared one — importing both is what the analyzer flags.
import 'package:wisdom_shared/wisdom_shared.dart';
import '../models/reader_tab.dart';
import 'last_reader_layout_provider.dart';
import 'navigation_tree_provider.dart';
import 'navigator_sync_provider.dart';
import 'tab_provider.dart';

/// Checks if the current content is a commentary (atthakatha).
/// Returns true if nodeKey starts with 'atta-'.
final isCommentaryProvider = Provider<bool>((ref) {
  final nodeKey = ref.watch(activeNodeKeyProvider);
  return nodeKey?.startsWith(TipitakaNodeKeys.commentary) ?? false;
});

/// Gets the parallel text node for navigation between root text and commentary.
/// - If viewing root text (e.g., 'mn-2-3-6'), returns the vaṇṇanā that treats
///   it — usually 'atta-mn-2-3-6', but a merged vaṇṇanā covers several suttas
///   under the key of the first, and then that is the answer.
/// - If viewing commentary (e.g., 'atta-mn-2-3-6'), returns the node holding
///   its root text, which is always reachable: the canon is complete, so a
///   missing key means the book merged suttas, never that text is absent.
/// Returns null when nothing should be offered — for a sutta, that means no
/// vaṇṇanā claims it, which is an answer and not a gap.
///
/// This is the primary provider for parallel text linking - use it to:
/// - Check if navigation is available (non-null means button should show)
/// - Get all target node details (name, position, etc.)
///
/// **The rule is [crossLinkTargetKey], shared with the static site**, which
/// emits the same link as `අට්ඨකථා` / `මූල පාඨය` on every page. Flipping the
/// `atta-` prefix and testing the key — what this provider did — offered no
/// link at all wherever a merge filed the other side under a neighbour's key
/// (`FIGURES.commentaryLinksResolvedByNeighbour`).
///
/// What no rule can repair, here or on the site: where a vaṇṇanā is keyed to a
/// sutta it does not treat, the wrong answer is a key that exists and looks
/// exactly like a right one. `UPSTREAM_DEFECTS.md` §4 lists them.
final parallelTextNodeProvider = Provider.autoDispose((ref) {
  final nodeKey = ref.watch(activeNodeKeyProvider);
  if (nodeKey == null || nodeKey.isEmpty) {
    return null;
  }

  // Null while the tree is still decoding, so the button appears with the
  // text rather than before it. `nodeIndexProvider` beside it does the same.
  final targetKey = ref.watch(sharedTreeProvider).maybeWhen(
        data: (tree) => crossLinkTargetKey(tree, nodeKey),
        orElse: () => null,
      );
  if (targetKey == null) {
    return null;
  }

  return ref.watch(nodeByKeyProvider(targetKey));
});

/// Action provider to open the parallel text in a new tab.
/// Creates a new tab from the target node and makes it active.
///
/// Callers pass [isPortraitMode] (derived from BuildContext) since providers
/// can't access context — used only as the fallback when the user has no saved
/// layout preference yet.
final openParallelTextProvider =
    Provider<void Function({bool isPortraitMode})>((ref) {
  return ({bool isPortraitMode = false}) {
    final targetNode = ref.read(parallelTextNodeProvider);
    if (targetNode == null) {
      return;
    }

    // Seed the new tab's layout from the user's last selection, falling back to
    // the orientation default. Shared with the tree/breadcrumb/search paths via
    // the single [resolveSeedLayout] helper.
    final layout = resolveSeedLayout(ref, isPortraitMode: isPortraitMode);

    // Create a new tab from the target node
    final newTab = ReaderTab.fromNode(
      nodeKey: targetNode.nodeKey,
      paliName: targetNode.paliName,
      sinhalaName: targetNode.sinhalaName,
      contentFileId: targetNode.contentFileId,
      pageIndex: targetNode.entryPageIndex,
      entryStart: targetNode.entryIndexInPage,
      layout: layout,
    );

    // Add tab and make it active
    final newIndex = ref.read(tabsProvider.notifier).addTab(newTab);
    ref.read(activeTabIndexProvider.notifier).state = newIndex;

    // Sync navigator to the new active tab
    ref.read(syncNavigatorToActiveTabProvider)();
  };
});
