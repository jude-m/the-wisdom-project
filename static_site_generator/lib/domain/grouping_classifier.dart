import 'package:wisdom_shared/wisdom_shared.dart';

import 'content_slicer.dart';

/// Why a container was exploded or grouped.
///
/// Kept on every verdict because the alternative — a bare bool — makes the
/// committed `grouping.json` unreviewable, which is exactly how the original
/// classifier's off-by-one survived: only its CSV output was in the repo.
enum GroupingReason {
  /// A uniform micro run: enough leaves, none of them substantial.
  uniformMicroRun,

  /// Under [GroupingClassifier.minLeaves] — too short to be a formulaic run.
  /// "All tiny" is not the fingerprint; *length* is, and 87 of the real groups
  /// are the classic vagga-of-ten.
  tooFewLeaves,

  /// At least one leaf is [GroupingClassifier.maxLeafChars] or longer. This is
  /// the SEO guard: one substantial sutta in the vagga explodes the whole
  /// vagga so that sutta keeps its own rankable page.
  hasSubstantialLeaf,

  /// The container holds sub-containers, so it is not a vagga — it is a TOC.
  notDeepest,

  /// The container's leaves live in more than one content file, so a chapter
  /// page would have to splice two sources. Ten containers do this (`dn-1`,
  /// `vp-mv`, `ap-pat-2` …); none of them would have grouped anyway.
  spansContentFiles,
}

/// What the generator does with one container.
class GroupingVerdict {
  final String containerKey;
  final bool grouped;
  final GroupingReason reason;

  /// Number of direct children. Recorded so a reviewer can sanity-check the
  /// verdict without re-running the corpus.
  final int leafCount;

  /// Longest leaf in combined raw characters, or null when not measured
  /// (`notDeepest` / `spansContentFiles` short-circuit before counting).
  final int? maxLeafChars;

  const GroupingVerdict({
    required this.containerKey,
    required this.grouped,
    required this.reason,
    required this.leafCount,
    required this.maxLeafChars,
  });
}

/// Decides which containers become one chapter page and which explode into a
/// page per sutta.
///
/// **Group iff the container is a deepest container (all children are leaves,
/// all in one content file) with at least [minLeaves] children, none of them
/// [maxLeafChars] or longer.** Otherwise explode.
///
/// Verdicts are per *container*, never per leaf: a vagga is wholly grouped or
/// wholly exploded. On real data the big and micro suttas interleave
/// (`an-4-2-3` runs `..D..D.DDD`), so hoisting the substantial ones out would
/// leave non-contiguous chapter files.
///
/// The error asymmetry is deliberate. A wrong *explode* costs a few thin pages
/// nobody searches for; a wrong *group* buries a named text that someone does.
/// So grouping stays the rare, high-confidence verdict.
class GroupingClassifier {
  /// Minimum children for a run to count as formulaic.
  ///
  /// Six, not ten, because commentary echo-vaggas legitimately run 6–9.
  /// Dropping the gate entirely would group 138 more containers, 85 of them
  /// single-leaf nodes where BJT already collapsed the run itself.
  static const int minLeaves = 6;

  /// A leaf this long or longer forces its whole vagga to explode.
  ///
  /// **Strictly less-than, and the margin is one character.** `kn-thig-6`'s
  /// longest leaf measures exactly 1,500, so `<=` here would group a vagga of
  /// eight *named* elders' verses. Combined Pali + Sinhala, raw text with
  /// markers left in — the convention the locked threshold was measured under.
  static const int maxLeafChars = 1500;

  final TipitakaTree tree;

  /// Slicers are built per content file and reused — a file is parsed once even
  /// though its containers are classified independently.
  final ContentSlicer Function(String fileId) slicerFor;

  const GroupingClassifier({required this.tree, required this.slicerFor});

  /// The verdict for one container.
  ///
  /// One container at a time, with no subtree-walking convenience wrapper: both
  /// callers drive the order themselves and want it grouped by *content file*
  /// rather than by tree position, so a walker here would only ever be the
  /// slower way round.
  GroupingVerdict classify(TipitakaNode container) {
    final children = tree.childrenOf(container.nodeKey);

    if (children.any((child) => !child.isLeaf)) {
      return GroupingVerdict(
        containerKey: container.nodeKey,
        grouped: false,
        reason: GroupingReason.notDeepest,
        leafCount: children.where((child) => child.isLeaf).length,
        maxLeafChars: null,
      );
    }

    if (children.length < minLeaves) {
      return GroupingVerdict(
        containerKey: container.nodeKey,
        grouped: false,
        reason: GroupingReason.tooFewLeaves,
        leafCount: children.length,
        maxLeafChars: null,
      );
    }

    final fileIds = {for (final child in children) child.contentFileId};
    if (fileIds.length != 1 || fileIds.first == null) {
      return GroupingVerdict(
        containerKey: container.nodeKey,
        grouped: false,
        reason: GroupingReason.spansContentFiles,
        leafCount: children.length,
        maxLeafChars: null,
      );
    }

    final slicer = slicerFor(fileIds.first!);
    var longest = 0;
    for (final child in children) {
      final chars = slicer.sliceFor(child.nodeKey).rawCharCount;
      if (chars > longest) longest = chars;
    }

    final grouped = longest < maxLeafChars;
    return GroupingVerdict(
      containerKey: container.nodeKey,
      grouped: grouped,
      reason: grouped
          ? GroupingReason.uniformMicroRun
          : GroupingReason.hasSubstantialLeaf,
      leafCount: children.length,
      maxLeafChars: longest,
    );
  }
}
