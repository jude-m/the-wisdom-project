import 'package:wisdom_shared/wisdom_shared.dart';

import 'content_slicer.dart';
import 'grouping_policy.dart';

/// Decides which leaves lose their own file.
///
/// **A container groups its leaves only when every one of its children is a
/// leaf and all of them live in one content file.** Inside such a container: a
/// leaf at or above its line ([GroupingPolicy]) gets its own page, and each
/// contiguous run of two or more shorter leaves becomes one page carrying them
/// all. A container holding exactly one leaf merges with it, unconditionally.
///
/// The unit is the **leaf**, not the container. The rule this replaces decided
/// a whole vagga at once, so one substantial sibling exploded everything around
/// it: of the 3,707 sutta pages under 1,500 characters it shipped, 2,304 were
/// blocked by exactly one big sibling. It rejected splitting per leaf on the
/// grounds that big and micro suttas interleave (`an-4-2-3` runs `..D..D.DDD`)
/// and hoisting the substantial ones out would leave non-contiguous chapters.
/// The observation is right; the conclusion is not — the answer to a
/// non-contiguous run is *more than one chapter*, not zero.
///
/// Contiguity is still a requirement rather than a preference: a chapter page
/// is read by scrolling, so a page that skipped a sutta inside its own range
/// would drop it from the reading order silently. Every run this emits is
/// maximal and contiguous.
///
/// The output is one flat set of folded leaf keys, and that is enough to
/// rebuild every page — see `SitePlan.build`, which is the only reader of it.
/// After the snapshot is frozen this class stops running at build time and
/// becomes a sync-time advisor: the tool that regenerates the snapshot, and the
/// report that says what the rule *would* do to newly synced content.
class GroupingPlanner {
  final TipitakaTree tree;

  /// Slicers are built per content file and reused — a file is parsed once
  /// even though its containers are planned independently.
  final ContentSlicer Function(String fileId) slicerFor;

  const GroupingPlanner({required this.tree, required this.slicerFor});

  /// Every leaf in the tree that does not get its own page.
  ///
  /// Walks containers grouped by content file rather than in tree order,
  /// because [SlicerCache] holds exactly one parsed file and a container's
  /// leaves are always in a single one. Order is deterministic — file ids
  /// sorted, tree document order within each — so the emitted snapshot is
  /// byte-stable across runs (build plan §11.8).
  Set<String> foldedLeaves() {
    final containersByFile = <String, List<TipitakaNode>>{};
    final orphans = <TipitakaNode>[];
    for (final node in tree.allNodes) {
      if (node.isLeaf) continue;
      final fileId = node.contentFileId;
      if (fileId == null) {
        orphans.add(node);
      } else {
        (containersByFile[fileId] ??= []).add(node);
      }
    }

    final folded = <String>{};
    for (final fileId in containersByFile.keys.toList()..sort()) {
      for (final container in containersByFile[fileId]!) {
        folded.addAll(foldedLeavesOf(container));
      }
    }
    // None in the vendored corpus. Planned anyway rather than skipped: a
    // container with no text of its own still has leaves that do.
    for (final container in orphans) {
      folded.addAll(foldedLeavesOf(container));
    }
    return folded;
  }

  /// The leaves of one container that lose their file. Empty when it groups
  /// nothing — which includes every container the two preconditions exclude.
  Set<String> foldedLeavesOf(TipitakaNode container) {
    final children = tree.childrenOf(container.nodeKey);
    if (children.isEmpty) return const {};

    // Precondition 1: every child is a leaf. A container that also holds
    // sub-containers is a TOC, and a TOC is pure links — letting it grow a
    // chapter as well would produce a half-text-half-navigation page. Blocks 45
    // runs covering 186 leaves.
    if (children.any((child) => !child.isLeaf)) return const {};

    // Precondition 2: all in one content file. A chapter page cannot splice two
    // sources. Blocks 4 more runs covering 9 leaves.
    final fileIds = {for (final child in children) child.contentFileId};
    if (fileIds.length != 1 || fileIds.first == null) return const {};

    // The lone child merges with its container: one page instead of two. Not a
    // merge of two texts — the container's slice is its preamble (heading,
    // `namo tassa`) and the leaf's slice is the text, and they already belonged
    // on adjacent pages.
    //
    // **Unconditional, outranking both the size line and promotion.** 62 of the
    // 159 hold a leaf at or above its own line, including the largest in the
    // corpus (`atta-kn-mn-2-1`, 333,558 chars). Nothing is buried in any of
    // them: promotion protects a named work from being lost *among siblings*,
    // and a lone child has none — its text keeps a whole page and simply
    // answers at the container's URL.
    if (children.length == 1) return {children.first.nodeKey};

    final slicer = slicerFor(fileIds.first!);
    final isShort = [
      for (final child in children) _isShort(child, slicer),
    ];

    // Every leaf short: the chapter covers the whole vagga and sits at the
    // container's own URL, so the first leaf folds too. This is the *only*
    // shape in which an index-0 leaf folds, and `SitePlan.build` relies on it.
    if (!isShort.contains(false)) {
      return {for (final child in children) child.nodeKey};
    }

    // Mixed. Each maximal run of short leaves long enough to be worth a page
    // folds all but its first, which anchors the chapter at its own URL — the
    // vagga's URL is already the TOC listing all of its suttas, so a run cannot
    // ride on it. A run of one is just a sutta and folds nothing.
    final folded = <String>{};
    var runStart = -1;
    for (var i = 0; i <= children.length; i++) {
      if (i < children.length && isShort[i]) {
        if (runStart == -1) runStart = i;
        continue;
      }
      if (runStart != -1) {
        if (i - runStart >= GroupingPolicy.minRunLength) {
          for (var j = runStart + 1; j < i; j++) {
            folded.add(children[j].nodeKey);
          }
        }
        runStart = -1;
      }
    }
    return folded;
  }

  /// Whether one leaf is short enough to share a page with its neighbours.
  ///
  /// The line is per *leaf*, not per container: [LeafPolicy.ownPage] is never
  /// short at any size, and the two lines differ by a factor of ten.
  bool _isShort(TipitakaNode leaf, ContentSlicer slicer) {
    final line = GroupingPolicy.lineFor(leaf);
    if (line == null) return false;
    return slicer.sliceFor(leaf.nodeKey).rawCharCount < line;
  }
}
