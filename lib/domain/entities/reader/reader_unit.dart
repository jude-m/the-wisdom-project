import 'package:wisdom_shared/wisdom_shared.dart';

/// One bounded thing the reader renders — the node the reader tapped, and the
/// span of one content file it owns.
///
/// [range] is what replaced run-to-the-end-of-the-file pagination: a unit has
/// an end. For a leaf that is the sutta's own slice; for a container it is its
/// preamble through the last descendant living in the same file.
class ReaderUnit {
  final TipitakaNode node;

  /// The `assets/text/<id>.json` holding this unit's rows.
  final String contentFileId;

  final SliceRange range;

  const ReaderUnit({
    required this.node,
    required this.contentFileId,
    required this.range,
  });

  String get nodeKey => node.nodeKey;

  /// By value, because this is rebuilt on every tab touch and handed to a
  /// `Provider`: a resolve that landed on the same span must not notify, or the
  /// reader would re-scroll on every unrelated tab change. [nodeKey] stands for
  /// [node] — within one tree a key names exactly one node.
  @override
  bool operator ==(Object other) =>
      other is ReaderUnit &&
      other.nodeKey == nodeKey &&
      other.contentFileId == contentFileId &&
      other.range == range;

  @override
  int get hashCode => Object.hash(nodeKey, contentFileId, range);
}

/// Resolves a node key to the bounded unit the reader shows for it.
///
/// **The one place the app answers "what does tapping this show".** Deep links,
/// citations, search hits, tree taps, prev/next and restored tabs all come
/// through here.
///
/// The rule is the node's own subtree, and nothing else decides it — in
/// particular not `SitePlan`. The site groups short suttas into shared chapter
/// files so its URLs never serve the same text twice; that is an SEO
/// constraint, and adopting it here turned every vagga into a list of links
/// with no text. The two surfaces agree on where a unit *ends* and disagree
/// about what gets its own address, which is the whole of the divergence.
///
/// Holds a [SliceIndex] per content file plus one reading-order walk of the
/// tree. No text is read, so there is nothing here to build lazily.
class ReaderUnitResolver {
  final TipitakaTree tree;
  final Map<String, SliceIndex> _indexByFile;

  /// Every node in reading order, and each key's position in it. A subtree is
  /// a contiguous run here, which is what makes [_subtreeEnd] a slice rather
  /// than a search.
  final List<TipitakaNode> _order;
  final Map<String, int> _position;

  /// How many nodes each subtree spans, itself included.
  final Map<String, int> _subtreeSize;

  /// Leaves alone, in the same order — the stops prev/next walks.
  final Map<String, int> _leafPosition;
  final List<TipitakaNode> _leaves;

  factory ReaderUnitResolver(TipitakaTree tree) {
    final order = <TipitakaNode>[];
    final size = <String, int>{};

    void walk(TipitakaNode node) {
      final start = order.length;
      order.add(node);
      for (final child in tree.childrenOf(node.nodeKey)) {
        walk(child);
      }
      size[node.nodeKey] = order.length - start;
    }

    for (final root in tree.roots) {
      walk(root);
    }

    final leaves = [
      for (final node in order)
        if (node.isLeaf) node,
    ];

    return ReaderUnitResolver._(
      tree,
      SliceIndex.forTree(tree),
      order,
      {for (var i = 0; i < order.length; i++) order[i].nodeKey: i},
      size,
      {for (var i = 0; i < leaves.length; i++) leaves[i].nodeKey: i},
      leaves,
    );
  }

  ReaderUnitResolver._(
    this.tree,
    this._indexByFile,
    this._order,
    this._position,
    this._subtreeSize,
    this._leafPosition,
    this._leaves,
  );

  /// The unit shown for [nodeKey], or null when it has no text.
  ReaderUnit? unitFor(String nodeKey) {
    final node = tree[nodeKey];
    final fileId = node?.contentFileId;
    final index = fileId == null ? null : _indexByFile[fileId];
    if (node == null || fileId == null || index == null) return null;
    if (!index.contains(nodeKey)) return null;

    final last = _subtreeEnd(node, fileId).lastNode;
    return ReaderUnit(
      node: node,
      contentFileId: fileId,
      range: SliceRange(
        nodeKey: nodeKey,
        start: index.rangeFor(nodeKey).start,
        end: index.rangeFor(last.nodeKey).end,
      ),
    );
  }

  /// The last node of [node]'s subtree that lives in [fileId], and the last
  /// leaf among them.
  ///
  /// The first bounds the unit; the second is where "next" steps off from.
  /// They differ on the 101 containers whose subtree crosses content files —
  /// tapping අඞ්ගුත්තරනිකායො renders what sits in `an-1` and stops, so its next
  /// stop is the first sutta of දුකනිපාතො rather than whatever follows AN.
  ({TipitakaNode lastNode, TipitakaNode? lastLeaf}) _subtreeEnd(
    TipitakaNode node,
    String fileId,
  ) {
    final start = _position[node.nodeKey]!;
    final end = start + _subtreeSize[node.nodeKey]!;

    var lastNode = node;
    TipitakaNode? lastLeaf = node.isLeaf ? node : null;
    for (var i = start + 1; i < end; i++) {
      final candidate = _order[i];
      if (candidate.contentFileId != fileId) continue;
      lastNode = candidate;
      if (candidate.isLeaf) lastLeaf = candidate;
    }
    return (lastNode: lastNode, lastLeaf: lastLeaf);
  }

  /// The sutta before [nodeKey]'s unit, or null at the start of the corpus.
  TipitakaNode? leafBefore(String nodeKey) {
    final first = _firstLeafIn(nodeKey);
    final at = first == null ? null : _leafPosition[first.nodeKey];
    return at == null || at == 0 ? null : _leaves[at - 1];
  }

  /// The sutta after [nodeKey]'s unit, or null at the end of the corpus.
  ///
  /// Steps off the last leaf actually *rendered*, so leaving a unit never skips
  /// text it did not show.
  TipitakaNode? leafAfter(String nodeKey) {
    final node = tree[nodeKey];
    final fileId = node?.contentFileId;
    if (node == null || fileId == null) return null;
    final last = _subtreeEnd(node, fileId).lastLeaf;
    final at = last == null ? null : _leafPosition[last.nodeKey];
    if (at == null) return null;
    return at + 1 < _leaves.length ? _leaves[at + 1] : null;
  }

  /// The first leaf inside [nodeKey]'s subtree — itself when it is one.
  TipitakaNode? _firstLeafIn(String nodeKey) {
    final start = _position[nodeKey];
    if (start == null) return null;
    final end = start + _subtreeSize[nodeKey]!;
    for (var i = start; i < end; i++) {
      if (_order[i].isLeaf) return _order[i];
    }
    return null;
  }

  /// Which node owns the row at [pageIndex]/[entryIndex] of [contentFileId].
  ///
  /// Derived from the row, never read off a stored `nodeKey` column: the search
  /// database implements the slicing rule against the *raw* tree, so for the
  /// corrected coordinates its answer names an adjacent sibling.
  String? keyAt(String contentFileId, int pageIndex, int entryIndex) =>
      _indexByFile[contentFileId]?.keyAt(pageIndex, entryIndex);
}
