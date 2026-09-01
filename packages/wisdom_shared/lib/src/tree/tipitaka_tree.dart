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

import '../constants/tipitaka_node_keys.dart';
import 'tree_coordinate_corrections.dart';

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
  /// ancestor — some containers hold leaves whose text sits in a different file
  /// (`FIGURES.containersWhoseLeavesSitElsewhere`).
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

  /// An aṭṭhakathā node — every commentary key carries the `atta-` prefix.
  ///
  /// Here rather than at each call site because a commentary is treated
  /// differently in five places and counting: the grouping line it is measured
  /// against, the අට්ඨකථා title marker, the canon ↔ commentary cross-link, the
  /// search index's own flag, and the self-canonical URL policy. The app has
  /// carried this getter since `tipitaka_tree_node.dart:69`; the generator was
  /// inlining the same `startsWith` twice.
  bool get isCommentary => nodeKey.startsWith(TipitakaNodeKeys.commentary);

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
  /// **Document order is the explicit tiebreak.** That reproduces what the app
  /// renders, but as a guarantee instead of an accident — and the generator
  /// needs the guarantee, because byte-identical output across builds is what
  /// keeps Cloudflare's hash-incremental deploys from re-uploading every file
  /// (see the build plan, §11.8).
  ///
  /// The app used to compare those keys as *equal* and let `List.sort` decide,
  /// which is unspecified — `List.sort` is explicitly not stable — and only
  /// produced the right answer because Dart falls back to insertion sort below
  /// 32 elements and the largest of those 18 parents (`atta-ap-vbh-6`) has 23
  /// children: a 9-element margin against an *undocumented* VM implementation
  /// detail. (The tree's widest parent, `ap-pat-2` at 90 children, was well past
  /// that threshold but safe anyway — all 90 keys carry a trailing integer, so
  /// the comparator is total there and stability never arises.) The app adopted
  /// the same tiebreak on 2026-08-03 as a hand-kept copy, and now has no copy
  /// at all: `tree_local_datasource.dart` decodes through this factory, so
  /// there is one comparator and nothing left to drift.
  ///
  /// One residual: the comparator is only a *total*
  /// order while every indexed sibling sits in ascending document order
  /// relative to its index-less siblings. Verified on the vendored asset — 8
  /// parents out of `FIGURES.containers` mix the two kinds and none is
  /// intransitive — but `tree.json` is re-synced from upstream, so a re-sync
  /// that reorders one of those 8 puts `List.sort` back in unspecified
  /// territory. Re-run the check when the asset moves.
  ///
  /// [corrections] overrides the coordinate of the leaves upstream points at
  /// the wrong row — see [correctedTreeCoordinates], which is the default and
  /// the only value any *reader* of the tree should pass. Pass `const {}` to
  /// decode the asset exactly as it is written, which is what the tool that
  /// **writes** that map needs: the defect it measures is invisible in a tree
  /// that has already had it corrected.
  factory TipitakaTree.fromJson(
    Map<String, dynamic> json, {
    Map<String, ({int page, int entry})> corrections = correctedTreeCoordinates,
  }) {
    final nodes = <String, _MutableNode>{};
    final documentOrder = <String, int>{};
    final childrenOf = <String, List<String>>{};
    final roots = <String>[];

    var ordinal = 0;
    json.forEach((nodeKey, value) {
      // Shape is checked before it is indexed. Every row in the vendored
      // asset is well-formed, but the asset is re-synced from upstream
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

      // Applied here rather than at any reader, so that *everything* derived
      // from the tree — the slicer's boundaries, the reading order
      // `nodesByFile` sorts into, the app's own walk — sees one coordinate and
      // not two. A correction applied further down would leave the sort keys
      // disagreeing with the slices they order.
      final corrected = corrections[nodeKey];

      documentOrder[nodeKey] = ordinal++;
      nodes[nodeKey] = _MutableNode(
        nodeKey: nodeKey,
        paliName: data[0] as String,
        sinhalaName: data[1] as String,
        hierarchyLevel: data[2] as int,
        entryPageIndex: corrected?.page ?? coordinates[0] as int,
        entryIndexInPage: corrected?.entry ?? coordinates[1] as int,
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
      final ai = trailingIndexOf(a);
      final bi = trailingIndexOf(b);
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
        entry.key:
            entry.value.freeze(childrenOf[entry.key] ?? const <String>[]),
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

  /// The node one level up, or null for a root or an unknown key.
  ///
  /// The same node as `ancestorsOf(nodeKey).firstOrNull`, without building the
  /// chain to reach it — `firstOrNull` and not `first`, since that list is empty
  /// on a root, which is exactly where this returns null. It is also the one
  /// place the `parentNodeKey`-then-index dance is written, so callers that want
  /// a single step up cannot each spell it differently.
  TipitakaNode? parentOf(String nodeKey) {
    final parentKey = _nodes[nodeKey]?.parentNodeKey;
    return parentKey == null ? null : _nodes[parentKey];
  }

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

  /// Whether [maybeAncestor] lies somewhere above [key] — the containment
  /// question, without building the chain to answer it.
  ///
  /// `ancestorsOf(key).any((a) => a.nodeKey == maybeAncestor)` says the same
  /// thing and allocates a list of nodes to say it. This walks parent keys and
  /// stops at the first match, which is worth having where it is asked once per
  /// section of every chapter page.
  ///
  /// Strict: a key is never its own ancestor, so a caller that also accepts the
  /// node itself writes `key == maybeAncestor ||` out loud. Cyclic data
  /// terminates rather than hanging, on the same rule as [ancestorsOf] — the
  /// three hand-rolled copies this replaced each walked `parentNodeKey` with no
  /// such guard, and each spelled the argument order differently.
  bool isAncestorOf(String maybeAncestor, String key) {
    final seen = <String>{key};
    var at = _nodes[key]?.parentNodeKey;
    // Guard before the match, exactly as [ancestorsOf] adds before it appends.
    // Tested the other way round it still terminates, but it answers `true` for
    // `isAncestorOf(a, a)` on a self-parent or a cycle, where the chain
    // [ancestorsOf] builds does not contain `a` at all — two spellings of one
    // question disagreeing on the malformed data the guard is here for.
    while (at != null && seen.add(at)) {
      if (at == maybeAncestor) return true;
      at = _nodes[at]?.parentNodeKey;
    }
    return false;
  }

  /// The "book" [nodeKey] belongs to — `an` (අඞ්ගුත්තරනිකායො), `vp-pct`
  /// (පාචිත්තියපාළි), `kn` (ඛුද්දකනිකායො).
  ///
  /// Defined as the highest ancestor *below* the root-level pitaka node, which
  /// is the level BJT itself titles its volumes at. Used as the last part of
  /// every page title, where it does the disambiguating work:
  /// `FIGURES.leavesSharingATitle` leaves share a name with another leaf, and
  /// the collection plus the parent vagga separates almost all of them.
  ///
  /// A method here rather than a free function beside `SitePlan`, where it used
  /// to live: it reads [ancestorsOf] and returns a [TipitakaNode], and no part
  /// of it knows what a page is.
  TipitakaNode? collectionOf(String nodeKey) {
    final ancestors = ancestorsOf(nodeKey);
    if (ancestors.isEmpty) return null;
    return ancestors.length >= 2
        ? ancestors[ancestors.length - 2]
        : ancestors.last;
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
///
/// Public because sibling ordering is not the only question that needs it:
/// `crossLinkTargetKey` reads the same index to decide whether a vaṇṇanā's
/// declared range reaches a sutta, and a second copy of this could drift.
int? trailingIndexOf(String nodeKey) {
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
