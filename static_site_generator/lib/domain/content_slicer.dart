import 'dart:collection';

import 'package:wisdom_shared/wisdom_shared.dart';

import 'content_file.dart';
import 'document.dart';

/// Cuts one content file into the slices its tree nodes own.
///
/// The rule itself — a node owns every row from its own coordinate up to the
/// next node's, containers being boundaries exactly like leaves — lives in
/// [SliceIndex], which needs no text to answer it. This class is the half that
/// does: it flattens the file into [DocRow]s and maps a coordinate range onto
/// them. The app maps the same range onto its `BJTDocument`, so neither surface
/// carries a second reading of the rule.
class ContentSlicer {
  /// Every row of the file, flattened across printed pages, in reading order.
  final List<DocRow> rows;

  /// Where each node starts and stops, in coordinates.
  final SliceIndex index;

  /// Row index of every coordinate in the file — how a coordinate range becomes
  /// a `sublist`.
  final Map<SliceCoordinate, int> _rowAt;

  ContentSlicer._(this.rows, this.index, this._rowAt);

  /// Builds a slicer for [file] from every tree node whose text lives in it.
  ///
  /// [nodesInFile] must be *all* of them, containers included, in the order
  /// [nodesByFile] produces.
  factory ContentSlicer.forFile(
      ContentFile file, List<TipitakaNode> nodesInFile) {
    final rows = <DocRow>[];
    final rowAt = <SliceCoordinate, int>{};

    for (var pageIndex = 0; pageIndex < file.pages.length; pageIndex++) {
      final page = file.pages[pageIndex];
      for (var entryIndex = 0; entryIndex < page.entryCount; entryIndex++) {
        rowAt[SliceCoordinate(pageIndex, entryIndex)] = rows.length;
        rows.add(DocRow(
          pageIndex: pageIndex,
          pageNum: page.pageNum,
          entryIndex: entryIndex,
          pali: page.paliAt(entryIndex),
          sinhala: page.sinhalaAt(entryIndex),
        ));
      }
    }

    for (final node in nodesInFile) {
      final at = SliceCoordinate(node.entryPageIndex, node.entryIndexInPage);
      if (!rowAt.containsKey(at)) {
        // Cannot fire on the vendored corpus (verified across every node).
        // Throws because dropping the node would quietly delete a sutta.
        throw StateError(
          'Node "${node.nodeKey}" points at page ${node.entryPageIndex}, '
          'entry ${node.entryIndexInPage} of ${file.fileId}, which does not '
          'exist (file has ${file.pages.length} pages).',
        );
      }
    }

    return ContentSlicer._(
      rows,
      SliceIndex.forFile(file.fileId, nodesInFile),
      rowAt,
    );
  }

  /// The rows owned by [nodeKey].
  NodeSlice sliceFor(String nodeKey) {
    final range = index.rangeFor(nodeKey);
    final start = _rowAt[range.start]!;
    final end = range.end == null ? rows.length : _rowAt[range.end]!;
    return NodeSlice(
      nodeKey: nodeKey,
      rows: rows.sublist(start, end),
      startIndex: start,
    );
  }

  /// See [SliceIndex.nodesByFile] — kept here as the name the generator's
  /// callers already use.
  static Map<String, List<TipitakaNode>> nodesByFile(TipitakaTree tree) =>
      SliceIndex.nodesByFile(tree);

  /// Every **container** that has a content file, grouped by that file.
  ///
  /// The scaffolding both planners walk: [SlicerCache] holds exactly one parsed
  /// file, so a rule that asks a question of every container has to visit them
  /// file by file rather than in tree order.
  ///
  /// A [SplayTreeMap], so the walk is in sorted file-id order however the
  /// caller iterates. That order reaches no file — the snapshot writers re-sort
  /// into reading order — but it is what the advisors print, and a report whose
  /// first five keys change between identical runs is a report nobody trusts.
  ///
  /// Containers with no content file are **absent**, and the two callers differ
  /// on what that means: `GroupingPlanner` still plans them (their leaves have
  /// text even when they do not), `PreamblePlanner` cannot (there is no
  /// preamble to read). Neither exists in the vendored corpus, and
  /// `plan_corpus.dart` reports any that appear.
  static Map<String, List<TipitakaNode>> containersByFile(TipitakaTree tree) {
    final byFile = <String, List<TipitakaNode>>{};
    for (final node in tree.allNodes) {
      if (node.isLeaf) continue;
      final fileId = node.contentFileId;
      if (fileId == null) continue;
      (byFile[fileId] ??= <TipitakaNode>[]).add(node);
    }
    return SplayTreeMap<String, List<TipitakaNode>>.from(byFile);
  }
}
