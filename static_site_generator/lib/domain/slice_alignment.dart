import 'package:wisdom_shared/wisdom_shared.dart';

import 'content_file.dart';
import 'content_slicer.dart';
import 'document.dart';
import 'preamble_planner.dart';

/// Which way a leaf's slice opens on text that is not its own.
enum SliceMisalignment {
  /// The slice opens with the leaf's **own name**, which BJT printed *after*
  /// the text it names. Everything below that line belongs to the next leaf,
  /// so the page is a whole sutta out: right title, wrong sutta.
  trailingColophon,

  /// The slice opens with a label that names neither this leaf nor what
  /// follows — a `භාණවාරං` recitation marker closing the division above. One
  /// stray row; the rest of the page is this leaf's own text.
  strayDivider,

  /// The slice holds **no running text at all** — a label, perhaps a second
  /// label, and nothing a reader reads.
  ///
  /// **Not a misalignment**, and counted apart from the two above for that
  /// reason. Two different causes reach this shape and the slice alone cannot
  /// tell them apart: a coordinate shifted off its own text (the last leaf of a
  /// trailing-colophon run, whose body sits in the slice above), and a node
  /// upstream really did print as a bare heading.
  ///
  /// Reading the pages separated them completely (2026-08-19). The shifted ones
  /// were the tail of a run whose other leaves were provably colophon-shifted,
  /// and `correctedTreeCoordinates` moved them. **Every leaf still reported
  /// here is correct**: its name matches the heading its slice opens on, and the
  /// rows below belong to a sibling correctly named for them. What upstream
  /// printed is a group title whose content is split across its siblings
  /// (`දුක්ඛසච්චනිද්දෙසවණ්ණනා` over `ජාතිනිද්දෙසො`), one of BJT's own
  /// abbreviations standing in for two sections at once
  /// (`ආසව ගොච්ඡක කුසල දුකතික සදිසං`), or a recitation marker modelled as a
  /// node (`සන්ථතභාණවාරො`).
  ///
  /// **`ap-vbh-18-1` is the one exception today** (2026-08-20). It is a section
  /// number over an empty page, and the rows below it belong to a sibling that
  /// is *not* correctly named for them: it heads a run whose coordinates each
  /// start one section early. The slice alone cannot say so — no body is no
  /// body — and it surfaced here at all only because question 1 is now asked
  /// ahead of the numeric exemption that used to pass it over.
  ///
  /// So it is reported and never warned about: the section renders with a title
  /// and no body because that is what the book has. It stays in this enum
  /// because one walk over one set of rows answers all three questions, and a
  /// second walk asking this one separately is a second answer able to
  /// disagree.
  headingOnlyLeaf,
}

/// Finds leaves whose slice does not hold the text the leaf is named for.
///
/// ## The defect
///
/// [ContentSlicer] gives a node every row from its own coordinate to the next
/// node's. That is right whenever the coordinate sits on the *leading* label of
/// what it names, which is the shape almost the whole corpus is printed in:
///
/// ```text
///   8. 1. 2.            ← the leaf's coordinate: a bare number
///   පඨමසික්ඛාපදං         a heading naming it
///   තෙන සමයෙන …          its text
/// ```
///
/// But BJT prints some sections' names as a **colophon** — after the text,
/// closing it — and there the coordinate lands on the closing line instead:
///
/// ```text
///   8. 1. 1.            ← swallowed by the *container's* preamble
///   පරිමණ්ඩලං නිවාසෙස්සාමීති …    the first rule's text
///   පඨමසික්ඛාපදං.        ← vp-pct-1-3-1-1's coordinate — its own name, at the end
///   8. 1. 2.            the *second* rule's number
///   පරිමණ්ඩලං පාරුපිස්සාමීති …    the second rule's text
/// ```
///
/// The page then carries the first rule's title over the second rule's text,
/// and its `#fragment` lands one sutta early — **a page that is wrong without
/// looking wrong.** Nothing downstream can notice: the rows are all present, in
/// order, on a page that renders and links like any other.
///
/// ## The rule
///
/// Asked only of a slice that **opens on a label** — a heading or a centred
/// line rather than a body row. From there two questions settle it, and the
/// second is only reached when the first says there is text to reason about:
///
/// 1. **Does the slice hold any running text?** If not, whatever the leaf is
///    named for is not on its page — [SliceMisalignment.headingOnlyLeaf],
///    whatever the rows below say, because there are none that could say
///    anything. This is the branch the 2026-07-28 analysis and the first cut of
///    this class both missed: the *last* leaf of a colophon run has no number
///    below it (the run has ended) and so answered "aligned" while holding its
///    own closing label and nothing else.
///
///    Asked **first**, ahead of reading the label itself. The numeric exemption
///    below used to come before it, which exempted a leaf whose slice is a bare
///    number and nothing else — `ap-vbh-18-1` (found 2026-08-20), a section
///    number printed over an empty page. A leading number leads something; a
///    slice with nothing under it is the one place that is not true, and the
///    exemption was answering a question nobody had asked yet.
///
/// 2. **Is the first label below it a bare number?** That second row is the
///    real leading label — the one the coordinate should have pointed at — so
///    whatever sits above it was printed for the text further up. Reached only
///    when the slice's *own* opening label is not a number: that is the
///    ordinary shape and is never misaligned.
///
/// **Except when the slice closes itself.** Some books print a leading title
/// *above* the number rather than below it, which reads as exactly question 2's
/// shape and is correct:
///
/// ```text
///   1. අකුසලපෙය්‍යාලං      ← an-2-17-1's coordinate: a leading title
///   1-50.                its own number
///   ද්වෙමෙ භික්ඛවෙ …        its own text
///   අකුසලපෙය්‍යාලං නිට්ඨිතං   and its own closing colophon, inside the slice
/// ```
///
/// A slice that ends on its own closing label is a slice that contains a whole
/// unit, so the label it opened with was that unit's title. A trailing-colophon
/// slice cannot end that way: its closing line is the *next* node's coordinate,
/// so it ends in the middle of a body. Measured over the corpus the test
/// separates them completely — every candidate is either a `vp-pct-1-2` leaf
/// ending mid-body or a leaf closing with its own `නිට්ඨිතං`/`සමත්තො`, with
/// nothing in between. Without it the rule over-reports by five, which is the
/// error the 2026-07-28 hand analysis made and this class inherited until the
/// pages were read.
///
/// The check applies to the colophon branch only. A [SliceMisalignment
/// .strayDivider] opens on a label that is *not* this leaf's name, so there is
/// no leading-title reading to rule out — and all four in the corpus do close
/// with their own colophon, which is what proves the intruder is the opening
/// row and nothing else.
///
/// Asked of leaves only. A *container's* coordinate sitting on its own title
/// above its first child's number is the ordinary shape of every vagga in the
/// corpus, and reads as this same pattern; the question only means anything
/// where the rows below the label are supposed to be the node's own text.
///
/// Read off the **Pali** side, because both halves of the test are Pali: the
/// leaf's own `paliName`, and BJT's numbering. The Sinhala side would be
/// comparing a translation against a Pali name. The one exception is question 1
/// — "is there running text here" is a question about the row, and a row
/// printed on the Sinhala side alone is still text somebody reads, so that test
/// takes either side (the same rule, and the same reason, as
/// [PreamblePlanner.ownsRunningText]).
///
/// [SliceMisalignment] then splits the shapes by asking whether the opening
/// label is the leaf's own name. Two of the three are defects and are counted
/// as `FIGURES.misalignedSlices`; [SliceMisalignment.headingOnlyLeaf] is not
/// one and is counted on its own, because the leaf is where it should be and
/// the book simply has no body under that heading.
///
/// ## What it does *not* do
///
/// It does not move the boundary, and it does not read
/// [correctedTreeCoordinates] either — it is asked of the tree the build
/// actually loaded, whichever that is. Run against the raw upstream tree it
/// reports the defect; run against the corrected one it reports what the
/// correction did not reach, which is the only way to tell that a correction is
/// still doing its job after a re-sync. Deciding what a coordinate *should* be
/// is [CoordinatePlanner]'s question, and shipping the answer is the frozen
/// map's.
///
/// The app owes the same detector at strict parity — continuous scroll hides
/// this defect today and bounded reading units expose it (reading-units plan,
/// B5). Nothing here touches the filesystem, so the rule lifts into
/// `wisdom_shared` with the content model when that lands; the *correction* is
/// there already.
class SliceAlignment {
  final TipitakaTree tree;

  /// Slicers are built per content file and reused — see [ContentSlicer].
  final ContentSlicer Function(String fileId) slicerFor;

  const SliceAlignment({required this.tree, required this.slicerFor});

  /// Every misaligned slice, keyed by the leaf that owns it.
  ///
  /// Grouped by content file and in tree order within each — the order
  /// [ContentSlicer.nodesByFile] hands back, which visits each file once and
  /// keeps a book's findings contiguous. Deterministic, so a report built from
  /// it can be diffed run to run.
  Map<String, SliceMisalignment> misalignedSlices() {
    final found = <String, SliceMisalignment>{};
    ContentSlicer.nodesByFile(tree).forEach((fileId, nodes) {
      final slicer = slicerFor(fileId);
      for (final node in nodes) {
        if (!node.isLeaf) continue;
        final verdict = verdictFor(node, slicer.sliceFor(node.nodeKey));
        if (verdict != null) found[node.nodeKey] = verdict;
      }
    });
    return found;
  }

  /// Whether [verdict] is a defect rather than a shape of the book.
  ///
  /// One predicate, read by the build's warning, `FIGURES.misalignedSlices` and
  /// the report — three places that each have to know which verdicts are worth
  /// raising, and must not be able to disagree about it. Everything except
  /// [SliceMisalignment.headingOnlyLeaf] is a defect; see that value for why it
  /// is not one.
  static bool isDefect(SliceMisalignment verdict) =>
      verdict != SliceMisalignment.headingOnlyLeaf;

  /// The verdict for one leaf, or null when its slice opens where it should.
  ///
  /// Static, and taking the slice rather than fetching it, so the build can ask
  /// the question of a slice it already holds — the check then costs a build
  /// nothing beyond a few string tests.
  static SliceMisalignment? verdictFor(TipitakaNode leaf, NodeSlice slice) {
    if (slice.rows.isEmpty) return null;

    final opening = slice.rows[0].pali;
    if (opening == null) return null;

    // `chromeTypes` rather than a second copy of {heading, centered}: "is this
    // row a label or is it text" is one question, and `PreamblePlanner` already
    // holds the answer — together with the check that it still partitions
    // `ContentEntry.knownTypes`, which is what keeps either rule honest when
    // upstream invents a type.
    if (!PreamblePlanner.chromeTypes.contains(opening.type)) return null;

    // An empty opening row is not a label at all, and [isBareNumbering] is
    // false for it — without this the row below would decide the verdict on its
    // own.
    if (opening.text.trim().isEmpty) return null;

    // Question 1. Nothing a reader reads, so nothing below can argue: the text
    // this leaf is named for is somewhere else. Answered before the rows below
    // are consulted, because a slice like `[දසමසික්ඛාපදං.] [පරිමණ්ඩලවග්ගො පඨමො.]`
    // has no number below it, closes on a label, and would otherwise read as a
    // whole self-contained unit — the one reading that is certainly wrong when
    // the unit is empty.
    //
    // Asked before the opening label is *read*, not only before the rows below
    // it. The numeric exemption underneath used to come first, which made "the
    // coordinate is on a leading number" an answer to a question nobody had
    // asked yet — a leading number leads something, and a slice with nothing
    // under it is the one place that is not true.
    if (!_holdsRunningText(slice)) return SliceMisalignment.headingOnlyLeaf;

    // The ordinary shape: the coordinate is on the leading number of text that
    // is really there.
    if (isBareNumbering(opening.text)) return null;

    // Question 2. The first label *carrying text* below the opening row, not
    // literally row 1: a row can be an empty counterpart cell, and an empty row
    // is neither a leading label nor a body line. `_closesItself` has skipped
    // them from the other end since it was written; this end has to skip them
    // too, or a blank between a colophon and its number hides the defect.
    final below = _firstTextBelow(slice);
    if (below == null) return null;

    // No leading label below, so the opening row is this leaf's own title
    // printed where a title belongs.
    if (!isBareNumbering(below.text)) return null;

    // Whether the label the slice opens on is this leaf's own name — the only
    // thing separating a colophon from an intruder, and so the last question
    // asked rather than the first: it walks both names through
    // [parseContentMarkers], and every early return above reaches its verdict
    // without it.
    final ownName = _nameKey(opening.text) == _nameKey(leaf.paliName);
    if (!ownName) return SliceMisalignment.strayDivider;

    // A leading title, printed above its own number rather than below it — see
    // the class comment. The slice holds a whole unit, closing colophon and
    // all, so nothing here belongs to the text above.
    if (_closesItself(slice)) return null;
    return SliceMisalignment.trailingColophon;
  }

  /// Whether [slice] holds a row of running text on either side.
  ///
  /// Either side is enough, and each is judged on its own type rather than
  /// through the row — the same rule as [PreamblePlanner.ownsRunningText], for
  /// the same reason: a row printed on one side only is still text a reader in
  /// that language reads, and taking the Pali type when the Pali cell is blank
  /// would read those rows off the wrong side.
  static bool _holdsRunningText(NodeSlice slice) {
    for (final row in slice.rows) {
      if (_isRunningText(row.pali) || _isRunningText(row.sinhala)) return true;
    }
    return false;
  }

  static bool _isRunningText(ContentEntry? entry) =>
      entry != null &&
      PreamblePlanner.runningTextTypes.contains(entry.type) &&
      entry.text.trim().isNotEmpty;

  /// The first Pali entry below the opening row that carries any text.
  static ContentEntry? _firstTextBelow(NodeSlice slice) {
    for (var i = 1; i < slice.rows.length; i++) {
      final entry = slice.rows[i].pali;
      if (entry == null || entry.text.trim().isEmpty) continue;
      return entry;
    }
    return null;
  }

  /// Whether [slice] ends on a closing label of its own.
  ///
  /// The last row carrying text, not the last row: a slice can end on an empty
  /// counterpart cell, and an empty row is neither a colophon nor a body line.
  ///
  /// Any label will do, and it deliberately does **not** have to name the leaf.
  /// BJT closes a unit however the book closes it — `අකුසලපෙය්‍යාලං නිට්ඨිතං`
  /// names the section, `දුතියො පණ්ණාසකො සමත්තො.` names the fifty it completes —
  /// and a name test would reject the second while the first passes, for a
  /// distinction that means nothing here. What matters is that the slice
  /// finished something instead of stopping mid-body.
  static bool _closesItself(NodeSlice slice) {
    for (var i = slice.rows.length - 1; i > 0; i--) {
      final entry = slice.rows[i].pali;
      if (entry == null || entry.text.trim().isEmpty) continue;
      return PreamblePlanner.chromeTypes.contains(entry.type) &&
          !isBareNumbering(entry.text);
    }
    return false;
  }

  /// True when [text] is one of BJT's bare numbers rather than a name —
  /// `8. 1. 2.`, `1-50.`, `1. 16. 8. 9-24`.
  ///
  /// Also the test behind `FIGURES.numericOnlyLeafTitles`, which asks the same
  /// question of a node's name instead of a row's text. One predicate: the two
  /// are the same statement about what BJT printed, and a second copy is a
  /// second answer able to disagree.
  static bool isBareNumbering(String text) =>
      text.trim().isNotEmpty && !_hasLetter.hasMatch(text);

  /// A name reduced to what a comparison should see.
  ///
  /// Markers come off through [parseContentMarkers] rather than a regex, so the
  /// grammar is the renderer's — a colophon carrying `{2}` is the same name
  /// without it. Then whitespace, full stops and the zero-width joiners: a
  /// colophon is printed `පඨමපාටිදෙසනීය සික්ඛාපදං.` against a tree name of
  /// `පඨම පාටිදෙසනීය සික්ඛාපදං`, and two spellings of one ligature are one
  /// name. Nothing else is stripped — this and a much broader normaliser
  /// (commas, colons, dashes, brackets, every quote) were measured over the
  /// whole corpus and agree key for key, so it takes the narrow one.
  static String _nameKey(String raw) {
    final buffer = StringBuffer();
    for (final segment in parseContentMarkers(raw)) {
      if (segment.isFootnote) continue;
      buffer.write(segment.text);
    }
    return buffer.toString().replaceAll(_ignoredInNames, '');
  }
}

/// Anything that is not whitespace, a digit, a full stop or a dash — i.e. the
/// evidence that a string is a name and not a number.
final RegExp _hasLetter = RegExp(r'[^\s0-9.\-–]');

/// Whitespace, the full stop, and the three zero-width characters — space,
/// non-joiner, joiner — written as escapes because a literal one is invisible
/// in the source and the next editor deletes it without knowing.
final RegExp _ignoredInNames = RegExp('[\\s.\\u200B\\u200C\\u200D]');
