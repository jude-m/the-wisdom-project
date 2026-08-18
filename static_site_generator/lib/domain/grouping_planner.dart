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
/// it: most of the thin sutta pages it shipped were blocked by exactly one big
/// sibling. It rejected splitting per leaf on the
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
///
/// **It does not run at build time.** Since S2 the verdicts are frozen into
/// `foldedLeafKeys`, a `const` in `wisdom_shared`, and this class runs only
/// from `tool/plan_corpus.dart`: as the writer behind `--write-snapshot`, and
/// as the advisor whose disagreements the report prints after a re-sync. The
/// snapshot wins over both — a measurement on a knife edge is why it exists.
class GroupingPlanner {
  final TipitakaTree tree;

  /// Slicers are built per content file and reused — a file is parsed once
  /// even though its containers are planned independently.
  final ContentSlicer Function(String fileId) slicerFor;

  const GroupingPlanner({required this.tree, required this.slicerFor});

  /// Every leaf in the tree that does not get its own page.
  ///
  /// Walks containers file by file rather than in tree order — see
  /// [ContentSlicer.containersByFile], which is the same scaffolding
  /// [PreamblePlanner] walks.
  Set<String> foldedLeaves() {
    final folded = <String>{};
    for (final containers in ContentSlicer.containersByFile(tree).values) {
      for (final container in containers) {
        folded.addAll(foldedLeavesOf(container));
      }
    }
    // Containers with no content file are absent from that map. None in the
    // vendored corpus. Planned anyway rather than skipped: a container with no
    // text of its own still has leaves that do.
    for (final node in tree.allNodes) {
      if (!node.isLeaf && node.contentFileId == null) {
        folded.addAll(foldedLeavesOf(node));
      }
    }
    return folded;
  }

  /// The leaves of one container that lose their file. Empty when it groups
  /// nothing — which includes every container the two preconditions exclude.
  Set<String> foldedLeavesOf(TipitakaNode container) {
    final children = tree.childrenOf(container.nodeKey);
    if (children.isEmpty) return const {};

    // Precondition 1: every child is a leaf. A container that also holds
    // sub-containers is a TOC, and folding a chapter into it would print a
    // *leaf's* text beside a list of links to the pages its other children own.
    // A TOC carrying its own preamble (`textBearingContainerKeys`) is a
    // different thing and is allowed: that text is the container's, at the
    // container's URL, and it links to nothing it also prints.
    if (children.any((child) => !child.isLeaf)) return const {};

    // Precondition 2: all in one content file. A chapter page cannot splice two
    // sources. Blocks a handful more.
    final fileIds = {for (final child in children) child.contentFileId};
    if (fileIds.length != 1 || fileIds.first == null) return const {};

    // The lone child merges with its container: one page instead of two. Not a
    // merge of two texts — the container's slice is its preamble (heading,
    // `namo tassa`) and the leaf's slice is the text, and they already belonged
    // on adjacent pages.
    //
    // **Unconditional, outranking both the size line and promotion.**
    // `FIGURES.loneChildChaptersNotFoldedOnSize` of the merges hold a leaf the
    // size rule would not have folded, up to `FIGURES.largestLoneChildChars`.
    // Nothing is buried in any of them: promotion protects a named work from
    // being lost *among siblings*, and a lone child has none — its text keeps a
    // whole page and simply answers at the container's URL.
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
