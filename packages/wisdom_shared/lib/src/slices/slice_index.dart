import '../tree/tipitaka_tree.dart';

/// A `[pageIndex, entryIndexInPage]` position in a content file — the `<page>`
/// and `<entry>` halves of a node coordinate and of a `?e=` deep link.
class SliceCoordinate implements Comparable<SliceCoordinate> {
  final int pageIndex;
  final int entryIndex;

  const SliceCoordinate(this.pageIndex, this.entryIndex);

  @override
  int compareTo(SliceCoordinate other) {
    final byPage = pageIndex.compareTo(other.pageIndex);
    return byPage != 0 ? byPage : entryIndex.compareTo(other.entryIndex);
  }

  @override
  bool operator ==(Object other) =>
      other is SliceCoordinate &&
      other.pageIndex == pageIndex &&
      other.entryIndex == entryIndex;

  @override
  int get hashCode => Object.hash(pageIndex, entryIndex);

  @override
  String toString() => '($pageIndex,$entryIndex)';
}

/// The span one node owns: [start] inclusive, [end] exclusive.
class SliceRange {
  final String nodeKey;
  final SliceCoordinate start;

  /// Where the next node begins, or null when this node runs to the end of the
  /// file. It is the file's last *coordinate* that ends that way, so two nodes
  /// sharing it both do. Only the caller holding the text knows where the end
  /// is — the generator's parsed rows, the app's `BJTDocument`.
  final SliceCoordinate? end;

  const SliceRange({required this.nodeKey, required this.start, this.end});
}

/// Where each node's text starts and stops inside one content file.
///
/// ## The rule
///
/// A node owns every row from **its own coordinate up to the coordinate of the
/// next node — of any kind — anywhere in the file.** Containers are boundaries
/// exactly like leaves.
///
/// That "of any kind" is load-bearing. The obvious reading — run to the next
/// *readable* node — sounds equivalent, because containers usually sit right on
/// top of their first child. They do not always: roughly a tenth of the
/// corpus's leaves would get a different slice, and the worst would swallow the
/// *following* container's entire preamble and print it under the wrong sutta's
/// title.
///
/// Treating containers as boundaries also produces the preamble rule for free.
/// The rows between a container's coordinate and its first child's are simply
/// the container's own slice — the pitaka heading, `namo tassa`, the vagga
/// title. Every row lands in exactly one slice, so nothing renders twice and
/// nothing is dropped.
///
/// ## Why coordinates and not rows
///
/// The boundary between two nodes *is* the next node's coordinate, so this
/// needs `tree.json` and nothing else — no content file is read to build it.
/// That is what lets a caller hold the index for the whole corpus at once and
/// skip the one-file-at-a-time discipline the parsed-rows side needs.
///
/// ## Both directions
///
/// The generator only ever asks *key → range*. The app also asks *row → key*,
/// for an FTS hit, a `?e=<page>.<entry>` deep link, and following the section a
/// reader has scrolled into. [keyAt] is the same sorted array read the other
/// way.
class SliceIndex {
  /// The `assets/text/<id>.json` this index describes.
  final String fileId;

  /// Distinct node coordinates, ascending. These are the slice boundaries.
  final List<SliceCoordinate> _boundaries;

  /// Which node [keyAt] answers with for each boundary, parallel to it.
  final List<String> _ownerOf;

  final Map<String, SliceCoordinate> _startOf;

  SliceIndex._(
    this.fileId,
    this._boundaries,
    this._ownerOf,
    this._startOf,
  );

  /// Builds the index for [fileId] from every tree node whose text lives in it.
  ///
  /// [nodesInFile] must be *all* of them, containers included, in the order
  /// [nodesByFile] produces — passing only the leaves silently reintroduces the
  /// mis-slicing described above, and passing them unsorted throws.
  factory SliceIndex.forFile(String fileId, List<TipitakaNode> nodesInFile) {
    if (nodesInFile.isEmpty) {
      throw ArgumentError('No tree node has its text in "$fileId".');
    }

    final startOf = <String, SliceCoordinate>{};
    final boundaries = <SliceCoordinate>[];
    final ownerOf = <String>[];
    final sharing = <TipitakaNode>[];

    // Two nodes may share a coordinate — a pitaka root and the nikāya root
    // printed under the same heading block. [rangeFor] gives them the same
    // range, which is what the site has always rendered, but a row can only
    // belong to one of them, so the deepest wins: the shallower one is another
    // of the tied nodes' parent, which is all the test needs to know.
    //
    // Two corners neither the corpus nor the rule reaches. `deepest` cannot
    // come back empty — that would need every tied node to be another's parent,
    // a cycle in a finite tree — so the fallback is belt and braces against a
    // malformed one rather than a case. And if it ever holds more than one,
    // two independent subtrees tied on a coordinate, the last in document
    // order wins for want of anything better to say.
    void closeRun() {
      final parents = {for (final node in sharing) node.parentNodeKey};
      final deepest =
          sharing.where((node) => !parents.contains(node.nodeKey)).toList();
      ownerOf.add((deepest.isEmpty ? sharing : deepest).last.nodeKey);
    }

    for (final node in nodesInFile) {
      final at = SliceCoordinate(node.entryPageIndex, node.entryIndexInPage);
      startOf[node.nodeKey] = at;

      if (boundaries.isEmpty) {
        boundaries.add(at);
        sharing.add(node);
        continue;
      }

      final order = at.compareTo(boundaries.last);
      if (order < 0) {
        throw ArgumentError(
          'Nodes for "$fileId" are out of reading order: "${node.nodeKey}" '
          'at $at follows ${boundaries.last}. Use SliceIndex.nodesByFile.',
        );
      }
      if (order == 0) {
        sharing.add(node);
      } else {
        closeRun();
        boundaries.add(at);
        sharing
          ..clear()
          ..add(node);
      }
    }
    closeRun();

    return SliceIndex._(
      fileId,
      List.unmodifiable(boundaries),
      List.unmodifiable(ownerOf),
      Map.unmodifiable(startOf),
    );
  }

  /// One index per content file, for the whole tree.
  static Map<String, SliceIndex> forTree(TipitakaTree tree) => {
        for (final entry in nodesByFile(tree).entries)
          entry.key: SliceIndex.forFile(entry.key, entry.value),
      };

  /// Every node in the tree, grouped by the content file its text lives in and
  /// sorted into reading order within each group.
  ///
  /// Sorted by coordinate, then by the tree's own document order so nodes
  /// sharing a coordinate keep a stable sequence — the site's output must be
  /// byte-stable, and an unstable order here would reshuffle page content
  /// between builds.
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

  /// True when [nodeKey]'s text lives in this file.
  bool contains(String nodeKey) => _startOf.containsKey(nodeKey);

  /// The span [nodeKey] owns.
  ///
  /// Two nodes sharing a coordinate get the same range — the outer one simply
  /// has no preamble the inner one does not also carry.
  SliceRange rangeFor(String nodeKey) {
    final start = _startOf[nodeKey];
    if (start == null) {
      throw StateError('"$nodeKey" has no text in "$fileId".');
    }
    final after = _countAtOrBefore(start);
    return SliceRange(
      nodeKey: nodeKey,
      start: start,
      end: after < _boundaries.length ? _boundaries[after] : null,
    );
  }

  /// The node owning the row at `(pageIndex, entryIndex)`.
  ///
  /// Two edges, both real in the corpus: a row **above** the file's first
  /// coordinate belongs to that first node — book front matter, which the site
  /// renders nowhere — and a coordinate two nodes share resolves to the deeper
  /// one.
  String keyAt(int pageIndex, int entryIndex) {
    final at = _countAtOrBefore(SliceCoordinate(pageIndex, entryIndex));
    return _ownerOf[at == 0 ? 0 : at - 1];
  }

  /// How many boundaries are at or before [at] — so `_boundaries[result]` is
  /// the first one strictly after it, and `result - 1` the last one at or
  /// before. Binary search rather than a scan: the widest file holds ~29,000
  /// rows against ~1,000 nodes.
  int _countAtOrBefore(SliceCoordinate at) {
    var low = 0;
    var high = _boundaries.length;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (_boundaries[mid].compareTo(at) <= 0) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }
}
