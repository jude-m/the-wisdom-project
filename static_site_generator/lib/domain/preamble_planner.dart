import 'package:wisdom_shared/wisdom_shared.dart';

import 'content_file.dart';
import 'content_slicer.dart';

/// Decides which containers open with an introduction rather than a heading.
///
/// A container's slice is its **preamble** — the rows between its own
/// coordinate and its first child's ([ContentSlicer]). On most containers that
/// is the title, `namo tassa`, and a pitaka banner: three lines of chrome that
/// the page's `<h1>` and breadcrumb already say. On a few it is the book's
/// actual introduction to the chapter, running to tens of thousands of
/// characters, and on `atta-vp-prj-1` to six figures.
///
/// The site treats a container page as pure navigation — no layout switcher, no
/// prev/next, and the narrow `.nav` column instead of the reading measure. That
/// is right for the first kind and wrong for the second, where it leaves real
/// text out of the reading order entirely: a page prev/next skips cannot be
/// reached by reading, only by clicking down the tree. This class names the
/// second kind so [SitePage.isReadable] can tell them apart.
///
/// ## The rule
///
/// **A container owns running text when its preamble carries at least
/// [minIntroductionChars] characters of paragraph, verse or unindented text.**
/// Both sides combined, raw, markers left in — the convention
/// [DocRow.rawCharCount] counts in.
///
/// Stated as the types that *are* running text rather than the two that are
/// not, which is the safe direction on a re-sync: `ContentEntry.fromJson` maps
/// an unrecognised type to `paragraph`, so a type upstream invents arrives as
/// body text and is counted, where a "not heading, not centered" phrasing would
/// have to be taught about it.
///
/// That argument holds only for types the parser does *not* know. Teaching
/// `ContentEntry.knownTypes` a new one — the natural first step when upstream
/// introduces it — would take it out of `paragraph` and, with a bare list here,
/// quietly out of running text: the unsafe direction, and the exact failure
/// this class exists to prevent. So every run that reads either set checks that
/// the two halves still partition [ContentEntry.knownTypes] —
/// [assertTypesPartitioned] — and refuses to go on if they do not.
///
/// ## Why a floor and not the bare type test
///
/// The rule was the type test alone, and it read one-line formulas as
/// introductions — the pātimokkha's section opener, the `[සාවත්ථිනිදානං]`
/// elision marker, the line announcing a niddesa. A body *type* is not the
/// claim the rule needs to make; a size is. The cases, and what the corpus
/// types each line elsewhere, are in `UPSTREAM_DEFECTS.md`
/// (`plan_corpus.dart --write-upstream`).
///
/// ## It does not run at build time
///
/// Like [GroupingPlanner], the verdicts are frozen — into
/// `textBearingContainerKeys` — and this class runs only from
/// `tool/plan_corpus.dart`. The reason is the same one: `SitePlan.build` reads
/// no text, and prev/next on *any* page depends on which of its neighbours are
/// readable, so answering this at render time would need a second pass over the
/// corpus. That is the pass S2 removed (see [SlicerCache]).
///
/// The frozen set errs the other way from `foldedLeafKeys`, and deliberately.
/// An absent key means "not readable", so a container that gains an
/// introduction upstream keeps its current page until someone regenerates —
/// costing the reading affordances the text should have had. The opposite
/// default would put a bare link list into the reading chain, which every
/// reader walking prev/next would meet. Neither moves a URL.
class PreamblePlanner {
  final TipitakaTree tree;

  /// Slicers are built per content file and reused — a file is parsed once even
  /// though its containers are planned independently.
  final ContentSlicer Function(String fileId) slicerFor;

  const PreamblePlanner({required this.tree, required this.slicerFor});

  /// Running-text characters a preamble needs before it counts as an
  /// introduction rather than a formula. Combined Pali + Sinhala, raw.
  ///
  /// **An input, not a measurement** — the same standing as
  /// `GroupingPolicy.shortLineChars`. It moves no URL; all it settles is
  /// whether a container page joins the reading chain. It sits inside a wide
  /// band every value of which gives the same verdict on today's corpus; the
  /// band is measured in `docs/todo/web-strategy/reading-units-and-grouping.md`
  /// and what lives here is the choice.
  static const int minIntroductionChars = 200;

  /// The entry types that carry running text.
  static const Set<String> runningTextTypes = {
    'paragraph',
    'gatha',
    'unindented',
  };

  /// The two that do not: a title, and a centred banner or `namo tassa`.
  ///
  /// Named first so the partition check in [textBearingContainers] has both
  /// halves to compare, and now read directly by `SliceAlignment`, which asks
  /// the same question from the other side — *is this row a label rather than
  /// text* — of the row a leaf's slice opens on. One set, so a type upstream
  /// invents cannot be chrome to one rule and text to the other.
  static const Set<String> chromeTypes = {'heading', 'centered'};

  /// Refuses the run unless the two sets above still partition
  /// [ContentEntry.knownTypes].
  ///
  /// Checked here rather than at a declaration because a `const` cannot
  /// compute. Thrown rather than asserted because every caller runs under
  /// `dart run`, which runs with asserts *off* — an `assert` would be a guard
  /// against silent drift that itself drifts silently. These are the sync runs
  /// that would freeze the wrong answer, and the only moment it could still be
  /// fixed cheaply.
  ///
  /// A static of its own rather than a line inside [textBearingContainers],
  /// because the partition is not this class's private business. Every entry
  /// point that reads either set asks for itself, because none of them reaches
  /// the others: [textBearingContainers], `SliceAlignment.misalignedSlices`
  /// (`--misaligned`), `CoordinatePlanner.corrections` (`--write-alignment`,
  /// which freezes a snapshot without ever planning a preamble),
  /// `computeCorpusFigures` (`--write-figures`) and the build in `sitegen.dart`,
  /// which calls `SliceAlignment.verdictFor` straight. Two set comparisons per
  /// run, so every one of them can afford it — and a new reader that assumes an
  /// earlier call covered it is exactly the drift this exists to catch, so add
  /// the call.
  static void assertTypesPartitioned() {
    if (ContentEntry.knownTypes.length !=
            runningTextTypes.length + chromeTypes.length ||
        !ContentEntry.knownTypes.containsAll(runningTextTypes) ||
        !ContentEntry.knownTypes.containsAll(chromeTypes)) {
      throw StateError(
        'runningTextTypes and chromeTypes must partition '
        'ContentEntry.knownTypes. A type was added to the parser without '
        'deciding whether it is running text; leaving it out would silently '
        'stop counting it.',
      );
    }
  }

  /// Every container whose preamble is an introduction.
  ///
  /// **Every container, not only the ones that become TOC pages.** A container
  /// that grouped into a whole-vagga chapter is readable already and its key
  /// changes nothing today. Asking the question of all of them is what keeps
  /// this set independent of `foldedLeafKeys`: the two answer different
  /// questions about the same tree, and a grouping change that turns a chapter
  /// back into a TOC must not depend on this file having been regenerated with
  /// it.
  ///
  /// Walks containers file by file rather than in tree order — see
  /// [ContentSlicer.containersByFile], which is the same scaffolding
  /// [GroupingPlanner] walks. A container with no content file has no preamble
  /// to read and is absent from it; `plan_corpus.dart` reports any that appear
  /// as an integrity violation, rather than leaving it to be inferred from a
  /// page that renders empty.
  Set<String> textBearingContainers() {
    assertTypesPartitioned();

    final bearing = <String>{};
    ContentSlicer.containersByFile(tree).forEach((fileId, containers) {
      final slicer = slicerFor(fileId);
      for (final container in containers) {
        if (ownsRunningText(container, slicer)) bearing.add(container.nodeKey);
      }
    });
    return bearing;
  }

  /// Whether one container's preamble is an introduction.
  bool ownsRunningText(TipitakaNode container, ContentSlicer slicer) =>
      runningTextChars(container, slicer) >= minIntroductionChars;

  /// How many characters of running text one container's preamble holds.
  ///
  /// The size, not the verdict, because `--write-upstream` prints it beside
  /// every container the floor rejects.
  int runningTextChars(TipitakaNode container, ContentSlicer slicer) {
    var total = 0;
    for (final row in slicer.sliceFor(container.nodeKey).rows) {
      // Each side is judged on its own type rather than through the row. A row
      // printed on one side only is still text a reader in that language reads
      // — `FIGURES.rowsSinhalaWithEmptyPali` rows across the corpus carry
      // Sinhala against an empty Pali cell, and taking the Pali type when the
      // Pali cell is blank would read those pages off the wrong side.
      for (final entry in [row.pali, row.sinhala]) {
        if (entry == null) continue;
        if (runningTextTypes.contains(entry.type)) total += entry.text.length;
      }
    }
    return total;
  }
}
