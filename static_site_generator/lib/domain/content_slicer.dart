import 'package:wisdom_shared/wisdom_shared.dart';

import 'content_file.dart';
import 'document.dart';

/// Cuts one content file into the slices its tree nodes own.
///
/// ## The rule
///
/// A node owns every row from **its own start coordinate up to the start of the
/// next node — of any kind — anywhere in the file.** Containers are boundaries
/// exactly like leaves.
///
/// That "of any kind" is load-bearing and was the single most expensive thing
/// to get wrong. The obvious reading — run to the next *readable* node — sounds
/// equivalent, because containers usually sit right on top of their first
/// child. They do not always: **roughly a tenth of the corpus's leaves** would
/// get a different slice, and the worst (`atta-kn-nett-3-3`) would swallow the
/// *following* container's entire preamble — hundreds of thousands of
/// characters — and print it under the wrong sutta's title.
///
/// Treating containers as boundaries also produces the preamble rule for free.
/// The rows between a container's coordinate and its first child's are simply
/// the container's own slice — the pitaka heading, `namo tassa`, the vagga
/// title. They belong on the container's page, and because every row lands in
/// exactly one slice, nothing is rendered twice and nothing is dropped.
///
/// ```text
///   [ an-1-1  ]  vagga heading, namo tassa      <- an-1-1's preamble
///   [ an-1-1-1]  1. 1. 1.  + two paragraphs     <- leaf slice
///   [ an-1-1-2]  1. 1. 2.  + one paragraph      <- leaf slice
/// ```
class ContentSlicer {
  /// Every row of the file, flattened across printed pages, in reading order.
  final List<DocRow> rows;

  /// Row index each node starts at, keyed by nodeKey.
  final Map<String, int> _startOf;

  /// Sorted row indices that end a slice — one per node in this file.
  final List<int> _boundaries;

  ContentSlicer._(this.rows, this._startOf, this._boundaries);

  /// Builds a slicer for [file] from every tree node whose text lives in it.
  ///
  /// [nodesInFile] must be *all* of them, containers included. Passing only the
  /// leaves silently reintroduces the mis-slicing bug described above, so the
  /// caller is expected to use [nodesByFile].
  factory ContentSlicer.forFile(
      ContentFile file, Iterable<TipitakaNode> nodesInFile) {
    final rows = <DocRow>[];
    final rowIndexOf = <({int page, int entry}), int>{};

    for (var pageIndex = 0; pageIndex < file.pages.length; pageIndex++) {
      final page = file.pages[pageIndex];
      for (var entryIndex = 0; entryIndex < page.entryCount; entryIndex++) {
        rowIndexOf[(page: pageIndex, entry: entryIndex)] = rows.length;
        rows.add(DocRow(
          pageIndex: pageIndex,
          pageNum: page.pageNum,
          entryIndex: entryIndex,
          pali: page.paliAt(entryIndex),
          sinhala: page.sinhalaAt(entryIndex),
        ));
      }
    }

    final startOf = <String, int>{};
    final boundaries = <int>{};
    for (final node in nodesInFile) {
      final index = rowIndexOf[(
        page: node.entryPageIndex,
        entry: node.entryIndexInPage,
      )];
      if (index == null) {
        // Cannot fire on the vendored corpus (verified across every node).
        // Throws because dropping the node would quietly delete a sutta.
        throw StateError(
          'Node "${node.nodeKey}" points at page ${node.entryPageIndex}, '
          'entry ${node.entryIndexInPage} of ${file.fileId}, which does not '
          'exist (file has ${file.pages.length} pages).',
        );
      }
      startOf[node.nodeKey] = index;
      boundaries.add(index);
    }

    return ContentSlicer._(rows, startOf, boundaries.toList()..sort());
  }

  /// The rows owned by [nodeKey].
  ///
  /// Returns an empty slice for a node that shares its coordinate with an
  /// earlier one — two containers in the corpus do, which just means the outer
  /// one has no preamble of its own.
  NodeSlice sliceFor(String nodeKey) {
    final start = _startOf[nodeKey];
    if (start == null) {
      throw StateError('"$nodeKey" has no text in this file.');
    }
    final end = _nextBoundaryAfter(start);
    return NodeSlice(
      nodeKey: nodeKey,
      rows: rows.sublist(start, end),
      startIndex: start,
    );
  }

  /// First boundary strictly after [start], or the end of the file.
  ///
  /// Binary search rather than a linear scan: the widest file holds ~29,000
  /// rows against ~1,000 nodes, and this runs once per node.
  int _nextBoundaryAfter(int start) {
    var low = 0;
    var high = _boundaries.length;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (_boundaries[mid] <= start) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low < _boundaries.length ? _boundaries[low] : rows.length;
  }

  /// Every node in the tree, grouped by the content file its text lives in and
  /// sorted into reading order within each group.
  ///
  /// Sorted by coordinate, then by the tree's own document order so nodes
  /// sharing a coordinate keep a stable sequence — §11.8 requires byte-stable
  /// output, and an unstable order here would reshuffle page content between
  /// builds.
  ///
  /// Built for the **whole tree at once**, deliberately. The per-file form this
  /// replaces walked every node to number them on each call, and it is called
  /// once per content file — one full-tree walk per file across a build, for an
  /// ordering that never changes. One pass, one map, done.
  ///
  /// Nodes with no `contentFileId` are absent from the result — they have no
  /// text to slice. There are none in the vendored corpus.
  static Map<String, List<TipitakaNode>> nodesByFile(TipitakaTree tree) {
    final ordinals = <String, int>{};
    final byFile = <String, List<TipitakaNode>>{};
    var ordinal = 0;
    for (final node in tree.allNodes) {
      ordinals[node.nodeKey] = ordinal++;
      final fileId = node.contentFileId;
      if (fileId != null) (byFile[fileId] ??= <TipitakaNode>[]).add(node);
    }
    for (final nodes in byFile.values) {
      nodes.sort((a, b) {
        final byPage = a.entryPageIndex.compareTo(b.entryPageIndex);
        if (byPage != 0) return byPage;
        final byEntry = a.entryIndexInPage.compareTo(b.entryIndexInPage);
        if (byEntry != 0) return byEntry;
        return ordinals[a.nodeKey]!.compareTo(ordinals[b.nodeKey]!);
      });
    }
    return byFile;
  }
}
