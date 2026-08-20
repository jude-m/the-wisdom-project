import 'package:wisdom_shared/wisdom_shared.dart';

import 'content_slicer.dart';
import 'document.dart';
import 'preamble_planner.dart';
import 'slice_alignment.dart';

/// One leaf's corrected coordinate, with the evidence for it.
class CoordinateCorrection {
  final String nodeKey;

  /// Where `tree.json` points today.
  final ({int page, int entry}) from;

  /// Where it should point: the leading number that opens this leaf's own text.
  final ({int page, int entry}) to;

  /// The text of the row [to] names, kept for the review line. A corrected
  /// coordinate is only reviewable against what is actually printed there.
  final String openingRow;

  const CoordinateCorrection({
    required this.nodeKey,
    required this.from,
    required this.to,
    required this.openingRow,
  });
}

/// Raised when the correction cannot be derived without guessing.
///
/// Thrown rather than skipped, and it aborts the whole run rather than dropping
/// one row. A partial map is the one outcome worse than no map: it would leave
/// a container half corrected, which is a *new* misalignment inside a run that
/// used to be uniformly wrong — and uniformly wrong is at least
/// diagnosable.
class CoordinateDerivationFailure implements Exception {
  final String message;
  const CoordinateDerivationFailure(this.message);
  @override
  String toString() => 'CoordinateDerivationFailure: $message';
}

/// Derives where a shifted leaf's coordinate should have pointed.
///
/// ## What it corrects
///
/// [SliceAlignment] finds leaves whose slice does not open where the leaf's own
/// text does. Two of its shapes shift a whole run, in opposite directions, and
/// each gets a rule here.
///
/// **Too late.** [SliceMisalignment.trailingColophon]: BJT closes those units
/// with their name instead of opening them with it, and upstream took the
/// closing line for the opening one. Every leaf under that container is one
/// unit late, and the container's preamble has swallowed the first leaf's text.
///
/// **Too early.** [SliceMisalignment.strandedLeadingNumber]: upstream anchored
/// each leaf one row past the *previous* section's number, so every leaf is one
/// unit early and its own number is stranded at the foot of its slice. The
/// first leaf's coordinate is correct and starved — the sibling below it opened
/// on its text.
///
/// ## Whole containers, not the flagged leaves
///
/// The detector cannot flag the *last* leaf of such a run on the colophon test:
/// there is no number below it, because the run has ended. It reports that leaf
/// as [SliceMisalignment.headingOnlyLeaf] instead, which is true but is also
/// true of nodes upstream simply printed as a bare heading — so the shape alone
/// cannot say which. What can say is the company it keeps: a leaf holding no
/// text of its own, at the end of a container whose *other* leaves are provably
/// colophon-shifted, is the tail of that shift and nothing else.
///
/// The stranded rule has the same hole at the same end, for the same reason:
/// `ap-vbh-18-10`'s slice runs to the close of the book, so it ends on
/// `විභඞ්ගප්පකරණං සමත්තං.` rather than on a stranded number, and the detector
/// cannot see it. Its nine siblings convict the container.
///
/// So the unit of correction is the **container**. One shifted child convicts
/// it, and then every leaf under it is corrected — the detected ones, the tail,
/// and any middle leaf the name test happened to miss because a colophon was
/// spelled differently from the tree's name for it. Correcting a run in part
/// would be worse than not correcting it: the leaves either all shift or the
/// boundaries between them stop lining up.
///
/// ## The derivation
///
/// Each leaf's text is opened by a bare number — `8. 1. 2.` — and the shift put
/// that number inside the *previous* node's slice, one row below its
/// coordinate. So for leaf `i` the corrected coordinate is the bare-numbering
/// label inside the slice of leaf `i-1`, and for the first leaf it is the one
/// inside the container's own preamble, which is exactly where its text went.
///
/// The derivation asks for **exactly one** such row in that window and refuses
/// the run otherwise. That is the check that keeps this mechanical rather than
/// interpretive: it is not looking for a plausible row, it is confirming that
/// the window contains one candidate and therefore no decision to make. A body
/// row cannot be mistaken for it — bodies are `runningTextTypes`, and this asks
/// for a chrome row — and the rule quote BJT centres inside each unit has
/// letters in it, so [SliceAlignment.isBareNumbering] rejects it.
///
/// The mirrored shape is the same walk with that window moved: a stranded run
/// reads each leaf's number out of its *own* slice instead of the previous
/// one's, through the same one-candidate contract. One function takes both —
/// [_correctShiftedRun] — because which slice to read is the only thing they
/// disagree about, and two copies of the walk would be two places for the
/// contract to drift.
///
/// ## The third rule: one row, not one unit
///
/// [SliceMisalignment.strayDivider] is a recitation marker closing the division
/// above, which lands at the top of the next leaf's slice. Everything under it
/// is already that leaf's own text, so the repair is to start one row later, on
/// its own number — see [_correctDivider]. Kept as its own rule because the
/// leaves around a divider are correct, where both run shapes move as a body.
///
/// ## What it deliberately leaves alone
///
/// [SliceMisalignment.headingOnlyLeaf] is not a misalignment and there is
/// nothing here to move. Those leaves point exactly where they should — the
/// leaf's name matches the heading its slice opens on, and the rows below
/// belong to a sibling correctly named for them. Upstream simply printed a
/// heading with no body under it: a group title whose content is split across
/// its siblings, or one of BJT's own abbreviations
/// (`ආසව ගොච්ඡක කුසල දුකතික සදිසං` — "as in the āsava-gocchaka" — standing in
/// for two sections at once). Moving one would take text from the neighbour
/// that owns it, which is the defect this class exists to remove.
class CoordinatePlanner {
  final TipitakaTree tree;

  /// Slicers are built per content file and reused — see [ContentSlicer].
  final ContentSlicer Function(String fileId) slicerFor;

  const CoordinatePlanner({required this.tree, required this.slicerFor});

  /// Every correction, in reading order.
  ///
  /// Grouped by content file and in tree order within each, so the generated
  /// file diffs the way the other snapshots do — a book's rows stay contiguous
  /// and one moved coordinate is one changed line.
  List<CoordinateCorrection> corrections() {
    // Both the detector and [_soleLeadingNumber] read `PreamblePlanner`'s two
    // type sets, and this is the run that *freezes* what they conclude. The
    // check lives with the sets; `--write-alignment` returns long before
    // anything plans a preamble, so it has to be asked here too.
    PreamblePlanner.assertTypesPartitioned();

    final verdicts =
        SliceAlignment(tree: tree, slicerFor: slicerFor).misalignedSlices();

    // Containers convicted by at least one shifted child, kept apart by which
    // rule convicted them — the two read their numbers out of different
    // windows. A `Set` keyed on the parent rather than a walk over containers:
    // the detector has already visited every leaf, and asking the question a
    // second way is a second answer able to disagree.
    final colophonRuns = <String>{};
    final strandedRuns = <String>{};
    for (final entry in verdicts.entries) {
      final parent = tree[entry.key]?.parentNodeKey;
      if (parent == null) continue;
      switch (entry.value) {
        case SliceMisalignment.trailingColophon:
          colophonRuns.add(parent);
        case SliceMisalignment.strandedLeadingNumber:
          strandedRuns.add(parent);
        case SliceMisalignment.strayDivider:
        case SliceMisalignment.headingOnlyLeaf:
          break;
      }
    }

    // One container, two rules. They disagree by construction — a colophon run
    // reads each leaf's number out of the *previous* node's slice and a
    // stranded one out of the leaf's own — so a container convicted by both is
    // a container whose shape neither rule was written for. Refused rather than
    // resolved by precedence: picking a winner here would ship whichever
    // reading happened to be listed first.
    final both = colophonRuns.intersection(strandedRuns);
    if (both.isNotEmpty) {
      throw CoordinateDerivationFailure(
        '${both.length} container(s) hold both a colophon-shifted and a '
        'stranded-number leaf, so two rules claim one run: '
        '${both.join(', ')}. Read the pages before regenerating.',
      );
    }
    final convicted = colophonRuns.union(strandedRuns);

    final out = <CoordinateCorrection>[];
    final visited = <String>{};
    ContentSlicer.nodesByFile(tree).forEach((fileId, nodes) {
      final slicer = slicerFor(fileId);
      for (final node in nodes) {
        // One walk, every rule, so the file stays in reading order however
        // many shapes end up being corrected. A container carries its whole
        // run; a divider leaf carries only itself.
        //
        // Which run shape it is picks the window and nothing else. The two sets
        // are disjoint — refused above if they are not — so reading the flag
        // off `colophonRuns` cannot be answering for a container the other rule
        // also claims.
        if (!node.isLeaf && convicted.contains(node.nodeKey)) {
          out.addAll(_correctShiftedRun(node, slicer,
              numberInPreviousSlice: colophonRuns.contains(node.nodeKey)));
          visited.add(node.nodeKey);
        } else if (node.isLeaf &&
            verdicts[node.nodeKey] == SliceMisalignment.strayDivider) {
          out.add(_correctDivider(node, slicer));
        }
      }
    });

    // The walk above is over `nodesByFile`, which is keyed on `contentFileId` —
    // so a convicted container without one is never visited, and its whole run
    // would be dropped without a word. Nothing in the vendored corpus is shaped
    // that way (every node carries a file), but `tree.json` is re-synced from
    // upstream, and a silent skip here produces exactly the half-corrected run
    // [CoordinateDerivationFailure] exists to refuse. The convicting leaf was
    // found by a different walk, so this is the one shape the loop itself
    // cannot notice.
    final missed = convicted.difference(visited);
    if (missed.isNotEmpty) {
      throw CoordinateDerivationFailure(
        '${missed.length} container(s) hold a shifted leaf but no content file '
        'of their own, so their runs were never read: ${missed.join(', ')}.',
      );
    }

    // Two rules, one leaf. `_correctShiftedRun` corrects every child of a
    // convicted container and `_correctDivider` corrects a leaf on its own, so
    // a divider sitting inside a shifted run would be corrected twice — two
    // coordinates for one key, from two rules that cannot both be right.
    // Nothing in the corpus is shaped that way (the dividers are in
    // `kn-vv`/`kn-pv`, the colophon runs in `vp-pct`, the stranded one in
    // `ap-vbh`), and the writer would emit both as duplicate keys in a `const`
    // map, which the compiler refuses. But that refusal names a Dart error in a
    // generated file rather than the run that produced it, and keeping either
    // row is the half-corrected outcome [CoordinateDerivationFailure] exists to
    // refuse.
    final seen = <String>{};
    final duplicated = <String>{
      for (final correction in out)
        if (!seen.add(correction.nodeKey)) correction.nodeKey,
    };
    if (duplicated.isNotEmpty) {
      throw CoordinateDerivationFailure(
        '${duplicated.length} leaf(s) corrected twice — once inside their '
        "container's run and once as a stray divider — so the map would hold "
        'two coordinates for one key: ${duplicated.join(', ')}.',
      );
    }
    return out;
  }

  /// Moves one leaf off the recitation marker that closes the division above.
  ///
  /// A `භාණවාරං` line names the bhāṇavāra it *ends*, so it belongs at the foot
  /// of the leaf before this one — which is where it lands once this leaf starts
  /// one row later, on its own number. That is the whole repair: one row, and
  /// no text changes hands, because everything below the marker was already
  /// this leaf's.
  ///
  /// Deliberately **not** folded into [_correctShiftedRun]. That rule shifts a
  /// whole container because a shifted run moves as a body; here the leaves
  /// around it are correct and only this one row is misplaced, so correcting
  /// its neighbours would be the error rather than the fix.
  CoordinateCorrection _correctDivider(
      TipitakaNode leaf, ContentSlicer slicer) {
    final slice = slicer.sliceFor(leaf.nodeKey);
    for (var i = 1; i < slice.rows.length; i++) {
      final row = slice.rows[i];
      final entry = row.pali;
      if (entry == null || entry.text.trim().isEmpty) continue;
      // The same row [SliceAlignment] already proved is a bare number — asked
      // again here because this is where it becomes a coordinate, and a rule
      // that trusts another rule's reasoning is a rule that breaks when the
      // other one is edited.
      if (!SliceAlignment.isBareNumbering(entry.text)) {
        throw CoordinateDerivationFailure(
          '"${leaf.nodeKey}" opens on a stray divider, but the row below it is '
          '"${entry.text.trim()}" rather than its own number. Read the page '
          'before regenerating.',
        );
      }
      return CoordinateCorrection(
        nodeKey: leaf.nodeKey,
        from: (page: leaf.entryPageIndex, entry: leaf.entryIndexInPage),
        to: (page: row.pageIndex, entry: row.entryIndex),
        openingRow: entry.text.trim(),
      );
    }
    throw CoordinateDerivationFailure(
      '"${leaf.nodeKey}" opens on a stray divider and has nothing below it, so '
      'there is no row to move it onto.',
    );
  }

  /// Shifts one container's whole run of leaves onto their own numbers.
  ///
  /// One walk for both run shapes, which differ in exactly one thing: **which
  /// slice holds the number a leaf should open on.** A colophon run starts each
  /// leaf too *late*, so that number is in the slice of the node before it —
  /// the container's own preamble for the first leaf, which is where its text
  /// went. A stranded run starts each leaf too *early*, so the number is at the
  /// foot of the leaf's **own** slice, the row
  /// [SliceMisalignment.strandedLeadingNumber] proved is there. Either way it
  /// is found again here through [_soleLeadingNumber] rather than by trusting
  /// the detector's reasoning, and everything else about the two — the whole
  /// container, the one-candidate contract, the refusals — is the same rule.
  ///
  /// **A leaf already on its number emits nothing.** The stranded shape reaches
  /// that routinely: there the first leaf's coordinate is correct and only its
  /// text is missing, taken by a sibling that started one row too soon, and it
  /// gets that text back the moment the sibling moves. A colophon run all but
  /// cannot — [ContentSlicer.sliceFor] runs to the next *boundary* after the
  /// start, so the previous node's slice holds this leaf's own row only where
  /// the two share a coordinate, the case that method's own doc names, and no
  /// colophon run in the corpus does. Written unconditionally rather than
  /// branched for exactly that reason: the skip is right on both sides — one
  /// line per leaf whose text *moves* — and a branch would suggest the two
  /// rules disagree about what to emit when they do not. A row that moves a
  /// coordinate onto itself is a line in the review diff with nothing in it to
  /// review.
  List<CoordinateCorrection> _correctShiftedRun(
      TipitakaNode container, ContentSlicer slicer,
      {required bool numberInPreviousSlice}) {
    final children = tree.childrenOf(container.nodeKey);
    if (children.any((child) => !child.isLeaf)) {
      final readFrom =
          numberInPreviousSlice ? 'its own preamble' : 'their own slices';
      throw CoordinateDerivationFailure(
        '"${container.nodeKey}" holds a sub-container, so its leaves are not '
        'one printed run and the shift cannot be read off $readFrom.',
      );
    }

    final out = <CoordinateCorrection>[];
    // The node whose slice holds the *next* leaf's opening number, for the
    // colophon shape. Starts as the container, whose preamble swallowed the
    // first leaf's text, and then walks the run. Unread in the stranded shape,
    // where every leaf's number is inside its own slice.
    var previous = container;
    for (final leaf in children) {
      final fileId = leaf.contentFileId;
      if (fileId == null || fileId != container.contentFileId) {
        throw CoordinateDerivationFailure(
          '"${leaf.nodeKey}" does not share "${container.nodeKey}"\'s content '
          'file, so the run is not one slice sequence.',
        );
      }
      final window = slicer
          .sliceFor(numberInPreviousSlice ? previous.nodeKey : leaf.nodeKey);
      final row = _soleLeadingNumber(window, leaf.nodeKey);
      // Advanced before the skip below, not after it: a leaf that emits nothing
      // is still the next leaf's window, and stepping over it would read the
      // wrong slice for every leaf after it.
      previous = leaf;
      if (row.pageIndex == leaf.entryPageIndex &&
          row.entryIndex == leaf.entryIndexInPage) {
        continue;
      }
      out.add(CoordinateCorrection(
        nodeKey: leaf.nodeKey,
        from: (page: leaf.entryPageIndex, entry: leaf.entryIndexInPage),
        to: (page: row.pageIndex, entry: row.entryIndex),
        openingRow: row.pali?.text.trim() ?? '',
      ));
    }
    return out;
  }

  /// The one bare-numbering label in [window], or a refusal.
  static DocRow _soleLeadingNumber(NodeSlice window, String forLeaf) {
    final found = <DocRow>[];
    for (final row in window.rows) {
      final entry = row.pali;
      if (entry == null) continue;
      if (!PreamblePlanner.chromeTypes.contains(entry.type)) continue;
      if (!SliceAlignment.isBareNumbering(entry.text)) continue;
      found.add(row);
    }
    if (found.length != 1) {
      throw CoordinateDerivationFailure(
        '"$forLeaf" should open on the leading number inside '
        '"${window.nodeKey}", but that slice holds ${found.length} of them. '
        'The run is not the shape this rule was written for; read the pages '
        'before regenerating.',
      );
    }
    return found.first;
  }
}
