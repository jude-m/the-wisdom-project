import 'package:wisdom_shared/wisdom_shared.dart';

/// How many pages of each kind a plan produces, and the identity that proves
/// the tally is self-consistent.
///
/// **Tree and plan only — no text is read.** That is the whole reason this is
/// its own type rather than part of `corpus_figures.dart`: `plan_corpus.dart
/// --check` runs unattended and must stay at about a second, so it may not
/// touch the corpus. Everything here answers from `tree.json` and
/// `foldedLeafKeys`, which is also why a subtree build and a whole-corpus build
/// can both produce one.
///
/// Two callers, one walk each and one definition between them: the `--check`
/// and default reports print it, and `computeCorpusFigures` publishes it as
/// `FIGURES.realPages` and its neighbours. They used to count these separately,
/// which is exactly the duplication `CORPUS_FIGURES.md` exists to end — two
/// hand-written tallies can disagree, and only one of them would have been the
/// number the docs quote.
class PageBudget {
  /// Leaves and containers in the tree, before the plan decides anything.
  final int leaves;
  final int containers;

  /// Leaves that own a file.
  final int suttaPages;

  /// Chapters sitting at a container's own URL, because the whole container
  /// folded.
  final int wholeVaggaChapters;

  /// Chapters anchored on a leaf, because the run starts below the container.
  final int midVaggaChapters;

  /// Container pages — links, and on a few of them an introduction above them.
  final int containerTocs;

  /// Of those, the ones whose preamble is the book's introduction to the
  /// chapter rather than its title (`textBearingContainerKeys`). They are
  /// readable: layout switcher, reading measure, and a place in prev/next.
  final int readableTocs;

  /// Leaves with no page of their own, from the frozen snapshot.
  final int foldedLeaves;

  const PageBudget({
    required this.leaves,
    required this.containers,
    required this.suttaPages,
    required this.wholeVaggaChapters,
    required this.midVaggaChapters,
    required this.containerTocs,
    required this.readableTocs,
    required this.foldedLeaves,
  });

  /// Counts one plan. O(pages), no allocation beyond the counters.
  factory PageBudget.of({
    required TipitakaTree tree,
    required SitePlan plan,
    required Set<String> folded,
  }) {
    var suttaPages = 0;
    var wholeVaggaChapters = 0;
    var midVaggaChapters = 0;
    var containerTocs = 0;
    var readableTocs = 0;
    for (final page in plan.pages) {
      switch (page.kind) {
        case PageKind.sutta:
          suttaPages++;
        case PageKind.chapter:
          page.node.isLeaf ? midVaggaChapters++ : wholeVaggaChapters++;
        case PageKind.toc:
          containerTocs++;
          if (page.isReadable) readableTocs++;
      }
    }
    final leaves = tree.allNodes.where((n) => n.isLeaf).length;
    return PageBudget(
      leaves: leaves,
      containers: tree.length - leaves,
      suttaPages: suttaPages,
      wholeVaggaChapters: wholeVaggaChapters,
      midVaggaChapters: midVaggaChapters,
      containerTocs: containerTocs,
      readableTocs: readableTocs,
      foldedLeaves: folded.length,
    );
  }

  /// `/`. Counted here rather than added at each call site, which is how the
  /// two tallies could have drifted by one without either looking wrong.
  ///
  /// It is not in `plan.pages`: `LandingPage` renders it, not `PageTemplate`,
  /// and `SitePlan.build`'s walk only ever emits the three [PageKind]s.
  static const int rootIndex = 1;

  int get chapterPages => wholeVaggaChapters + midVaggaChapters;

  /// Files the build writes.
  int get realPages => suttaPages + chapterPages + containerTocs + rootIndex;

  /// The count if every folded leaf also got a redirect stub (the P5 gate).
  int get pagesWithStubs => realPages + foldedLeaves;

  /// What [suttaPages] must be, reached from the corpus totals instead of the
  /// walk: every leaf either folds, anchors a mid-vagga chapter, or owns a page.
  int get derivedSuttaPages => leaves - foldedLeaves - midVaggaChapters;

  /// What [containerTocs] must be: every container is either a whole-vagga
  /// chapter or a TOC.
  int get derivedContainerTocs => containers - wholeVaggaChapters;

  /// Whether both identities close.
  ///
  /// A mismatch is not an arithmetic slip — the two sides are counted from
  /// different places, so it means the walk never reached part of the tree.
  /// After `_integrity` has passed, the only shape left that does that is a
  /// parent cycle in a re-synced `tree.json`, which nothing else in the
  /// pipeline notices.
  bool get derivationHolds =>
      derivedSuttaPages == suttaPages && derivedContainerTocs == containerTocs;
}
