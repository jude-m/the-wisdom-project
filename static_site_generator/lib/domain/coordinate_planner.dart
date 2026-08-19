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

/// Derives where a trailing-colophon leaf's coordinate should have pointed.
///
/// ## What it corrects
///
/// [SliceAlignment] finds leaves whose slice opens on a label belonging to the
/// text above. Where that label is the leaf's **own name**, the cause is a
/// colophon: BJT closes those units with their name instead of opening them
/// with it, and upstream took the closing line for the opening one. The run
/// then shifts as a body — every leaf under that container is one unit late,
/// and the container's preamble has swallowed the first leaf's text.
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
/// So the unit of correction is the **container**. One `trailingColophon` child
/// convicts it, and then every leaf under it is corrected — the detected ones,
/// the tail, and any middle leaf the name test happened to miss because a
/// colophon was spelled differently from the tree's name for it. Correcting a
/// run in part would be worse than not correcting it: the leaves either all
/// shift or the boundaries between them stop lining up.
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
/// ## The second rule: one row, not one unit
///
/// [SliceMisalignment.strayDivider] is a recitation marker closing the division
/// above, which lands at the top of the next leaf's slice. Everything under it
/// is already that leaf's own text, so the repair is to start one row later, on
/// its own number — see [_correctDivider]. Kept as its own rule because the
/// leaves around a divider are correct, where a colophon run moves as a body.
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
    final verdicts =
        SliceAlignment(tree: tree, slicerFor: slicerFor).misalignedSlices();

    // Containers convicted by at least one colophon child. A `Set` keyed on the
    // parent rather than a walk over containers: the detector has already
    // visited every leaf, and asking the question a second way is a second
    // answer able to disagree.
    final convicted = <String>{};
    for (final entry in verdicts.entries) {
      if (entry.value != SliceMisalignment.trailingColophon) continue;
      final parent = tree[entry.key]?.parentNodeKey;
      if (parent != null) convicted.add(parent);
    }

    final out = <CoordinateCorrection>[];
    final visited = <String>{};
    ContentSlicer.nodesByFile(tree).forEach((fileId, nodes) {
      final slicer = slicerFor(fileId);
      for (final node in nodes) {
        // One walk, both rules, so the file stays in reading order however many
        // shapes end up being corrected. A container carries its whole run; a
        // divider leaf carries only itself.
        if (!node.isLeaf && convicted.contains(node.nodeKey)) {
          out.addAll(_correctRun(node, slicer));
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
        '${missed.length} container(s) hold a colophon-shifted leaf but no '
        'content file of their own, so their runs were never read: '
        '${missed.join(', ')}.',
      );
    }

    // Two rules, one leaf. `_correctRun` corrects every child of a convicted
    // container and `_correctDivider` corrects a leaf on its own, so a divider
    // sitting inside a colophon run would be corrected twice — two coordinates
    // for one key, from two rules that cannot both be right. Nothing in the
    // corpus is shaped that way (the dividers are in `kn-vv`/`kn-pv`, the
    // colophon runs in `vp-pct`), and the writer would emit both as duplicate
    // keys in a `const` map, which the compiler refuses. But that refusal names
    // a Dart error in a generated file rather than the run that produced it,
    // and keeping either row is the half-corrected outcome
    // [CoordinateDerivationFailure] exists to refuse.
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
  /// Deliberately **not** folded into [_correctRun]. That rule shifts a whole
  /// container because a colophon run moves as a body; here the leaves around it
  /// are correct and only this one row is misplaced, so correcting its
  /// neighbours would be the error rather than the fix.
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

  /// Shifts one container's whole run of leaves back onto their own text.
  List<CoordinateCorrection> _correctRun(
      TipitakaNode container, ContentSlicer slicer) {
    final children = tree.childrenOf(container.nodeKey);
    if (children.any((child) => !child.isLeaf)) {
      throw CoordinateDerivationFailure(
        '"${container.nodeKey}" holds a sub-container, so its leaves are not '
        'one printed run and the shift cannot be read off its own preamble.',
      );
    }

    final out = <CoordinateCorrection>[];
    // The node whose slice holds the *next* leaf's opening number. Starts as
    // the container, whose preamble swallowed the first leaf's text, and then
    // walks the run.
    var previous = container;
    for (final leaf in children) {
      final fileId = leaf.contentFileId;
      if (fileId == null || fileId != container.contentFileId) {
        throw CoordinateDerivationFailure(
          '"${leaf.nodeKey}" does not share "${container.nodeKey}"\'s content '
          'file, so the run is not one slice sequence.',
        );
      }
      final window = slicer.sliceFor(previous.nodeKey);
      final row = _soleLeadingNumber(window, leaf.nodeKey);
      out.add(CoordinateCorrection(
        nodeKey: leaf.nodeKey,
        from: (page: leaf.entryPageIndex, entry: leaf.entryIndexInPage),
        to: (page: row.pageIndex, entry: row.entryIndex),
        openingRow: row.pali?.text.trim() ?? '',
      ));
      previous = leaf;
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
