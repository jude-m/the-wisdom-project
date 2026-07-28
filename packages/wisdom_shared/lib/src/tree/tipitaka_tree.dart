/// Pure-Dart decode of `assets/data/tree.json` — the BJT navigation tree.
///
/// The app's `TreeLocalDataSourceImpl` mixes two concerns: loading bytes
/// (`rootBundle`, Flutter) and decoding them (pure). Only the decode lives
/// here, so the Flutter client, the shelf server and the static-site generator
/// can share one definition of what the tree *is* while each keeps its own byte
/// source.
///
/// ## Wire format
///
/// A flat `{nodeKey: [...]}` map — the hierarchy is implied by each node
/// naming its parent, not by nesting:
///
/// ```json
/// "an-1": ["අඞ්ගුත්තරනිකායො", "අඞ්ගුත්තර සඟිය", 6, [0, 0], "sp", "an-1"]
/// //         [0] pali        [1] sinhala      [2]  [3]      [4]    [5]
/// ```
///
/// `[3]` is the `[pageIndex, entryIndexInPage]` coordinate where the node's
/// text starts; `[4]` is the parent (`"root"` for the **seven** top-level
/// nodes — `vp`, `sp`, `ap`, `atta-vp`, `atta-sp`, `atta-ap` and `anya`, the
/// last being easy to forget since it sits outside the three-pitaka pattern);
/// `[5]` is the id of the `assets/text/<id>.json` file holding the text — note
/// a node's content often lives in an ancestor's file, so this is *not*
/// derivable from the key.
///
/// Every row is exactly six fields; [TipitakaTree.fromJson] rejects anything
/// else rather than reading past the end.
library;

/// One node of the navigation tree.
///
/// Children are held as keys rather than objects so the structure stays a flat,
/// cycle-free map that is cheap to build and safe to serialise.
class TipitakaNode {
  /// Stable identity, e.g. `sn-2-3-1-3`. Also the URL path segment.
  final String nodeKey;

  /// Title in Pali (written in Sinhala script), e.g. `අඞ්ගුත්තරනිකායො`.
  final String paliName;

  /// Title in Sinhala, e.g. `අඞ්ගුත්තර සඟිය`.
  final String sinhalaName;

  /// Depth marker from the source data: 7 = pitaka … 1 = leaf-ish.
  /// Higher is broader. Not the same as distance from the root.
  final int hierarchyLevel;

  /// Page index (0-based, into the content file's `pages` array) where this
  /// node's text begins.
  final int entryPageIndex;

  /// Index of the first entry within that page.
  final int entryIndexInPage;

  /// Parent key, or null for a root node.
  final String? parentNodeKey;

  /// `assets/text/<id>.json` holding this node's text. May belong to an
  /// ancestor — 10 containers hold leaves whose text sits in a different file.
  final String? contentFileId;

  /// Child keys in display order (see [TipitakaTree.fromJson] for the rule).
  final List<String> childKeys;

  const TipitakaNode({
    required this.nodeKey,
    required this.paliName,
    required this.sinhalaName,
    required this.hierarchyLevel,
    required this.entryPageIndex,
    required this.entryIndexInPage,
    required this.parentNodeKey,
    required this.contentFileId,
    required this.childKeys,
  });

  /// A node with no children — a sutta, or the smallest addressable unit.
  bool get isLeaf => childKeys.isEmpty;

  @override
  String toString() => 'TipitakaNode($nodeKey, "$paliName", '
      'level $hierarchyLevel, ${childKeys.length} children)';
}

/// The decoded tree: every node, plus parent/child navigation.
class TipitakaTree {
  final Map<String, TipitakaNode> _nodes;

  /// Root keys in display order (`vp`, `sp`, `ap`, `atta-vp`, …).
  final List<String> rootKeys;

  const TipitakaTree._(this._nodes, this.rootKeys);

  /// Decodes the `{nodeKey: [...]}` map from `tree.json`.
  ///
  /// ## Sibling order is deterministic by construction
  ///
  /// Siblings sort by the trailing number of their key (`sp-1-2-13` → 13),
  /// matching the Vue app's `childInd`. But 113 keys have no trailing number —
  /// `vp`, `sp`, `ap`, `kn-khp`, and every dotted commentary key such as
  /// `atta-ap-dhs-2-1-1.1`, whose last hyphen-segment `1.1` is not an integer.
  /// They cluster under 18 parents, including `root`, `sp`, `kn`, `ap` and
  /// `anya`: the app's most visible navigation.
  ///
  /// The app compares those as *equal* and lets `List.sort` decide. That is
  /// unspecified — `List.sort` is explicitly not stable — and it only produces
  /// the right answer today because Dart falls back to insertion sort below 32
  /// elements and the largest of those 18 parents (`atta-ap-vbh-6`) has 23
  /// children. Note the tree's widest parent is `ap-pat-2` at 90 children, well
  /// past the threshold; it is safe only because all 90 keys carry a trailing
  /// integer, so the comparator is total there and stability never arises. The
  /// margin protecting the other 18 is 9 elements, against an *undocumented*
  /// VM implementation detail.
  ///
  /// Here, **document order is the explicit tiebreak**. That reproduces what
  /// the app renders today, but as a guarantee instead of an accident — and the
  /// generator needs the guarantee, because byte-identical output across builds
  /// is what keeps Cloudflare's hash-incremental deploys from re-uploading all
  /// 16,356 files (see the build plan, §11.8).
  factory TipitakaTree.fromJson(Map<String, dynamic> json) {
    final nodes = <String, _MutableNode>{};
    final documentOrder = <String, int>{};
    final childrenOf = <String, List<String>>{};
    final roots = <String>[];

    var ordinal = 0;
    json.forEach((nodeKey, value) {
      // Shape is checked before it is indexed. All 16,355 rows in the vendored
      // asset are well-formed, but the asset is re-synced from upstream
      // tipitaka.lk, so a shape change is a real scenario — and a named
      // FormatException beats a RangeError thrown from `data[3][0]`.
      if (value is! List) {
        throw FormatException(
          'tree.json row "$nodeKey" is ${value.runtimeType}, expected a List.',
        );
      }
      if (value.length != _fieldsPerRow) {
        throw FormatException(
          'tree.json row "$nodeKey" has ${value.length} fields, '
          'expected $_fieldsPerRow.',
        );
      }
      final data = value;
      final coordinates = data[3];
      if (coordinates is! List || coordinates.length < 2) {
        throw FormatException(
          'tree.json row "$nodeKey" has a malformed [pageIndex, entryIndex] '
          'coordinate: ${data[3]}.',
        );
      }
      final rawParent = data[4];
      // "root" is a sentinel in the data, not a real node.
      final parent = (rawParent == 'root' || rawParent == null)
          ? null
          : rawParent as String;

      documentOrder[nodeKey] = ordinal++;
      nodes[nodeKey] = _MutableNode(
        nodeKey: nodeKey,
        paliName: data[0] as String,
        sinhalaName: data[1] as String,
        hierarchyLevel: data[2] as int,
        entryPageIndex: coordinates[0] as int,
        entryIndexInPage: coordinates[1] as int,
        parentNodeKey: parent,
        contentFileId: data[5] as String?,
      );

      if (parent == null) {
        roots.add(nodeKey);
      } else {
        (childrenOf[parent] ??= <String>[]).add(nodeKey);
      }
    });

    int compare(String a, String b) {
      final ai = _childIndex(a);
      final bi = _childIndex(b);
      if (ai != null && bi != null) {
        final byIndex = ai.compareTo(bi);
        if (byIndex != 0) return byIndex;
      }
      return documentOrder[a]!.compareTo(documentOrder[b]!);
    }

    roots.sort(compare);
    for (final siblings in childrenOf.values) {
      siblings.sort(compare);
    }

    // A node naming a parent that isn't in the data would strand its whole
    // subtree: the children would sit in `childrenOf` under a key no node ever
    // reads, so they'd vanish from navigation with no error. Fail loudly
    // instead — a tree missing a branch is worse than a build that stops.
    final missingParents = childrenOf.keys.where((k) => !nodes.containsKey(k));
    if (missingParents.isNotEmpty) {
      throw FormatException(
        'tree.json names ${missingParents.length} parent(s) that do not '
        'exist: ${missingParents.take(5).join(', ')}',
      );
    }

    final resolved = <String, TipitakaNode>{
      for (final entry in nodes.entries)
        entry.key: entry.value.freeze(childrenOf[entry.key] ?? const <String>[]),
    };

    return TipitakaTree._(Map.unmodifiable(resolved), List.unmodifiable(roots));
  }

  /// The node for [nodeKey], or null when nothing is registered under it.
  TipitakaNode? operator [](String nodeKey) => _nodes[nodeKey];

  /// Every node, in `tree.json` document order.
  Iterable<TipitakaNode> get allNodes => _nodes.values;

  /// How many nodes the tree holds.
  int get length => _nodes.length;

  /// Root nodes, in display order.
  List<TipitakaNode> get roots => [for (final key in rootKeys) _nodes[key]!];

  /// Children of [nodeKey] in display order; empty for a leaf or unknown key.
  List<TipitakaNode> childrenOf(String nodeKey) {
    final node = _nodes[nodeKey];
    if (node == null) return const [];
    return [for (final key in node.childKeys) _nodes[key]!];
  }

  /// Ancestors of [nodeKey], nearest parent first, root last.
  ///
  /// Reverse it for a breadcrumb. Self-parenting or cyclic data terminates
  /// rather than hanging, since each key is visited at most once.
  List<TipitakaNode> ancestorsOf(String nodeKey) {
    final chain = <TipitakaNode>[];
    final seen = <String>{nodeKey};
    var current = _nodes[nodeKey]?.parentNodeKey;
    while (current != null && seen.add(current)) {
      final node = _nodes[current];
      if (node == null) break;
      chain.add(node);
      current = node.parentNodeKey;
    }
    return chain;
  }

  /// Every leaf at or below [nodeKey], in reading order.
  ///
  /// A leaf node returns itself, which keeps callers from special-casing the
  /// "already a sutta" input.
  List<TipitakaNode> leavesUnder(String nodeKey) {
    final node = _nodes[nodeKey];
    if (node == null) return const [];
    if (node.isLeaf) return [node];

    final leaves = <TipitakaNode>[];
    void walk(TipitakaNode current) {
      if (current.isLeaf) {
        leaves.add(current);
        return;
      }
      for (final key in current.childKeys) {
        final child = _nodes[key];
        if (child != null) walk(child);
      }
    }

    walk(node);
    return leaves;
  }
}

/// Fields in one `tree.json` row — see the library docs for the layout.
const int _fieldsPerRow = 6;

/// Trailing number of a node key: `sp-1-2-13` → 13, `kn-khp` → null.
///
/// Mirrors `childInd` in the Vue app (`tree.js:7`) and the Flutter datasource's
/// `_extractChildIndex`, including its blind spot for dotted keys — parity is
/// the point, so navigation order matches across surfaces.
int? _childIndex(String nodeKey) {
  final lastSeparator = nodeKey.lastIndexOf('-');
  if (lastSeparator == -1) return null;
  return int.tryParse(nodeKey.substring(lastSeparator + 1));
}

/// Scratch node used only while children are still being collected.
class _MutableNode {
  final String nodeKey;
  final String paliName;
  final String sinhalaName;
  final int hierarchyLevel;
  final int entryPageIndex;
  final int entryIndexInPage;
  final String? parentNodeKey;
  final String? contentFileId;

  const _MutableNode({
    required this.nodeKey,
    required this.paliName,
    required this.sinhalaName,
    required this.hierarchyLevel,
    required this.entryPageIndex,
    required this.entryIndexInPage,
    required this.parentNodeKey,
    required this.contentFileId,
  });

  TipitakaNode freeze(List<String> childKeys) => TipitakaNode(
        nodeKey: nodeKey,
        paliName: paliName,
        sinhalaName: sinhalaName,
        hierarchyLevel: hierarchyLevel,
        entryPageIndex: entryPageIndex,
        entryIndexInPage: entryIndexInPage,
        parentNodeKey: parentNodeKey,
        contentFileId: contentFileId,
        childKeys: List.unmodifiable(childKeys),
      );
}
