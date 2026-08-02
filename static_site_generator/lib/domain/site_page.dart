import 'package:wisdom_shared/wisdom_shared.dart';

import 'grouping_classifier.dart';

/// `/tipitaka/<nodeKey>` — the site-root-relative URL of any node's page.
///
/// Built from [TipitakaLink.pathSegment] rather than written out, because that
/// constant is what `TipitakaLink.parse` matches on when the app resolves a
/// deep link. The two surfaces share one URL grammar (build plan C4); spelling
/// it here as a literal is how they would quietly stop sharing it.
///
/// Takes a bare key, not a [SitePage], because most links on a page point at
/// nodes that have no page object in hand — breadcrumb ancestors, TOC children,
/// the commentary twin.
String tipitakaUrl(String nodeKey) => '/${TipitakaLink.pathSegment}/$nodeKey';

/// What kind of page a tree node becomes.
enum PageKind {
  /// A leaf of an exploded vagga: one sutta, its own file, its own `<title>`
  /// and canonical URL. The unit that ranks for a name search.
  sutta,

  /// A grouped vagga: the whole formulaic run in one file, each sutta a
  /// `<section id="<nodeKey>">` filtered into single view by the URL fragment.
  chapter,

  /// A higher container: links only, no body text.
  toc,
}

/// One output file.
class SitePage {
  final PageKind kind;
  final TipitakaNode node;

  /// Leaves rendered inside this page. One entry for [PageKind.sutta], the
  /// whole run for [PageKind.chapter], empty for a TOC.
  final List<TipitakaNode> suttas;

  const SitePage({
    required this.kind,
    required this.node,
    required this.suttas,
  });

  String get nodeKey => node.nodeKey;

  /// `/tipitaka/an-1-1` — the same grammar the app's deep links use, so one URL
  /// serves both surfaces.
  String get url => tipitakaUrl(nodeKey);

  /// Flat `<key>.html`, never `<key>/index.html`: the directory form would give
  /// containers a second URL shape (`…/an-1-1/` plus a 308 hop) and break the
  /// uniform `/tipitaka/<nodeKey>` grammar the codec relies on.
  String get outputPath => '${TipitakaLink.pathSegment}/$nodeKey.html';

  /// True when this page carries body text — the pages prev/next walks.
  bool get isReadable => kind != PageKind.toc;
}

/// Every page for a subtree, in reading order, with prev/next resolved.
class SitePlan {
  final List<SitePage> pages;

  /// Reading-order position of each *readable* page, for prev/next.
  final Map<String, int> _readableIndex;
  final List<SitePage> readablePages;

  SitePlan._(this.pages, this.readablePages, this._readableIndex);

  /// Walks each of [rootKeys] top-down and decides what every node becomes.
  ///
  /// A grouped container swallows its leaves: they produce no file of their own
  /// (their clean URLs become redirect stubs at the P6 gate, never a second
  /// copy of the text). That is the no-duplication rule made structural — a
  /// leaf is either its own page or inside a chapter, never both.
  ///
  /// **A list, not one key**, because the corpus has seven disjoint roots
  /// (`vp`, `sp`, `ap`, `atta-vp`, `atta-sp`, `atta-ap`, `anya`) with no common
  /// ancestor. A single-root build is therefore never a whole site and often
  /// not even a coherent subtree: `an-1` sits under `sp` while its commentary
  /// `atta-an-1` sits under `atta-sp`, so the අට්ඨකථා cross-link every canon
  /// page emits (`PageTemplate._commentaryLink`) points outside the build. On
  /// the `an-1` subtree that was 32 dead links out of 144.
  ///
  /// Roots are walked in the order given and the order is preserved, so §11.8
  /// byte-determinism holds: the same list always yields the same manifest.
  ///
  /// One behavioural consequence: prev/next chains *across* roots, so the last
  /// `an-1` sutta's "next" is the first `atta-an-1` page. That is the right
  /// reading for a continuous corpus walk, and on a partial build it just means
  /// the pager runs off one subtree into the next rather than dead-ending.
  factory SitePlan.build({
    required TipitakaTree tree,
    required List<String> rootKeys,
    required GroupingVerdict Function(TipitakaNode container) classify,
  }) {
    final pages = <SitePage>[];

    void walk(TipitakaNode node) {
      if (node.isLeaf) {
        pages.add(SitePage(
          kind: PageKind.sutta,
          node: node,
          suttas: [node],
        ));
        return;
      }

      final children = tree.childrenOf(node.nodeKey);
      if (classify(node).grouped) {
        pages.add(SitePage(
          kind: PageKind.chapter,
          node: node,
          suttas: children,
        ));
        return; // children are inside the chapter file
      }

      pages.add(SitePage(kind: PageKind.toc, node: node, suttas: const []));
      for (final child in children) {
        walk(child);
      }
    }

    if (rootKeys.isEmpty) {
      throw StateError('No roots to build.');
    }

    bool isAncestorOf(String maybeAncestor, String key) {
      for (String? at = tree[key]?.parentNodeKey;
          at != null;
          at = tree[at]?.parentNodeKey) {
        if (at == maybeAncestor) return true;
      }
      return false;
    }

    // The whole list is validated before any of it is walked, so a bad key
    // fails on itself rather than after a partial site has been planned.
    //
    // Roots must also be *disjoint*. A repeat (`--root sp,sp`) or a nested pair
    // (`--root sp,an-1`, in either order) walks the same subtree twice: every
    // page is written twice, and because `_readableIndex` below is a map
    // literal, the repeated nodeKey silently keeps the LAST index — so prev/next
    // threads through the second copy. Refusing is the same call as defaulting
    // to the whole corpus: a build that looks finished but isn't is the failure
    // mode worth being loud about.
    for (final rootKey in rootKeys) {
      if (tree[rootKey] == null) {
        throw StateError('Unknown root "$rootKey".');
      }
    }
    for (var i = 0; i < rootKeys.length; i++) {
      for (var j = i + 1; j < rootKeys.length; j++) {
        final a = rootKeys[i];
        final b = rootKeys[j];
        if (a == b) {
          throw StateError('Root "$a" is listed twice.');
        }
        if (isAncestorOf(a, b) || isAncestorOf(b, a)) {
          throw StateError('Roots "$a" and "$b" overlap — one contains the '
              'other. Roots must not repeat or nest.');
        }
      }
    }

    for (final rootKey in rootKeys) {
      walk(tree[rootKey]!);
    }

    final readable = pages.where((page) => page.isReadable).toList();
    return SitePlan._(
      pages,
      readable,
      {for (var i = 0; i < readable.length; i++) readable[i].nodeKey: i},
    );
  }

  /// The page a reader reaches by continuing backwards, or null at the start.
  ///
  /// Walks *readable* pages only, so a reader crossing a vagga boundary lands
  /// on the next sutta rather than on a table of contents (C7). Chapter files
  /// count as one stop.
  SitePage? previousOf(SitePage page) {
    final index = _readableIndex[page.nodeKey];
    if (index == null || index == 0) return null;
    return readablePages[index - 1];
  }

  SitePage? nextOf(SitePage page) {
    final index = _readableIndex[page.nodeKey];
    if (index == null || index + 1 >= readablePages.length) return null;
    return readablePages[index + 1];
  }
}

/// The "book" a node belongs to — `an` (අඞ්ගුත්තරනිකායො), `vp-pct`
/// (පාචිත්තියපාළි), `kn` (ඛුද්දකනිකායො).
///
/// Defined as the highest ancestor *below* the root-level pitaka node, which is
/// the level BJT itself titles its volumes at. Used as the last part of every
/// page title, where it does the disambiguating work: 2,216 leaves share a name
/// with another leaf, and the collection plus the parent vagga separates all
/// but 377 of them.
TipitakaNode? collectionOf(TipitakaTree tree, String nodeKey) {
  final ancestors = tree.ancestorsOf(nodeKey);
  if (ancestors.isEmpty) return null;
  return ancestors.length >= 2
      ? ancestors[ancestors.length - 2]
      : ancestors.last;
}
