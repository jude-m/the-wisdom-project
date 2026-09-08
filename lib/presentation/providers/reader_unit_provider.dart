import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/navigation/tipitaka_tree_node.dart';
import '../../domain/entities/reader/reader_unit.dart';
import 'navigation_tree_provider.dart';

/// The resolver every entry point must go through — see [ReaderUnitResolver].
///
/// Built from the shared tree, not the [sitePlanProvider]: the reader's unit is
/// the node's own subtree, so the site's frozen grouping has no say in it. The
/// plan stays loaded for the link codec, which does still speak the site's URL
/// grammar.
///
/// Kept apart from the providers that *use* it (`document_provider.dart`,
/// `tab_provider.dart`) for the reason `navigator_sync_provider` was — those
/// two already import each other's neighbourhood, and a resolver they both
/// reach would close the loop.
final readerUnitResolverProvider =
    FutureProvider<ReaderUnitResolver>((ref) async {
  final tree = await ref.watch(sharedTreeProvider.future);
  return ReaderUnitResolver(tree);
});

/// Which way [neighbourLeafProvider] steps.
enum ReaderStep { previous, next }

/// The sutta before or after the unit rooted at a node key, in reading order.
///
/// Replaces the old `previousReadableNodeProvider`, which walked to the
/// previous *readable* node and so landed on a vagga's title block. Containers
/// are units here, not stops: leaving one goes to the sutta on the other side
/// of it.
final neighbourLeafProvider = Provider.autoDispose
    .family<TipitakaTreeNode?, (String, ReaderStep)>((ref, arg) {
  final (nodeKey, step) = arg;
  final resolver = ref.watch(readerUnitResolverProvider).valueOrNull;
  if (resolver == null) return null;

  final leaf = switch (step) {
    ReaderStep.previous => resolver.leafBefore(nodeKey),
    ReaderStep.next => resolver.leafAfter(nodeKey),
  };
  // The nested `TipitakaTreeNode` is what the reader's callers pass around;
  // the shared tree's node is a different type carrying no children.
  return leaf == null ? null : ref.watch(nodeByKeyProvider(leaf.nodeKey));
});
