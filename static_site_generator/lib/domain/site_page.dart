import 'package:wisdom_shared/wisdom_shared.dart';

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

  /// A contiguous run of short leaves in one file, each a
  /// `<section id="<nodeKey>">` filtered into single view by the URL fragment.
  ///
  /// **The run may start mid-vagga**, in which case [SitePage.node] is its
  /// first *leaf* rather than the container — the vagga's own URL is already
  /// the TOC listing all of its suttas, so a run starting at sutta 3 cannot
  /// ride on it. `FIGURES.wholeVaggaChapters` cover a whole vagga and sit at
  /// the container's URL; `FIGURES.midVaggaChapters` start below one.
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

  /// True when the page's own node has a slice to render above its contents.
  ///
  /// It is exactly *"is this page anchored on a container"*: a TOC node is
  /// always a container and a sutta node always a leaf, so [kind] adds nothing.
  /// A leaf-anchored chapter has no preamble — the container's slice belongs to
  /// its TOC page, and repeating it below would print the vagga title twice.
  bool get hasPreamble => !node.isLeaf;
}

/// Resolves a nodeKey to the URL that actually serves it — [SitePlan.urlFor].
///
/// Threaded into the renderers as a function rather than the whole [SitePlan],
/// so a template declares the one thing it needs and cannot quietly grow a
/// dependency on prev/next or the page list.
typedef UrlResolver = String Function(String nodeKey);

/// Every page for a subtree, in reading order, with prev/next resolved.
class SitePlan {
  final List<SitePage> pages;

  /// Reading-order position of each *readable* page, for prev/next.
  final Map<String, int> _readableIndex;
  final List<SitePage> readablePages;

  /// Folded leaf → `<chapter>#<nodeKey>`. Only folded leaves are in here; see
  /// [urlFor], the only way to read it.
  final Map<String, String> _servingUrl;

  SitePlan._(
    this.pages,
    this.readablePages,
    this._readableIndex,
    this._servingUrl,
  );

  /// Walks each of [rootKeys] top-down and decides what every node becomes.
  ///
  /// A chapter swallows the leaves it carries: they produce no file of their
  /// own (their clean URLs become redirect stubs at the P5 gate, never a second
  /// copy of the text). That is the no-duplication rule made structural — a
  /// leaf is either its own page or inside a chapter, never both.
  ///
  /// ## Reconstruction from [foldedLeafKeys] alone
  ///
  /// The grouping rule is not re-measured here; it is *read*. Every leaf named
  /// in the set lost its file, and that one flat set carries enough to rebuild
  /// the whole page structure:
  ///
  /// ```text
  /// a container whose FIRST child is folded → the container IS the chapter,
  ///                                            holding every leaf below it
  /// otherwise                                → the container is a TOC, and
  ///    a leaf NOT in foldedLeafKeys          → starts a page
  ///    a leaf IN foldedLeafKeys              → appends to the page started by
  ///                                            its nearest preceding unfolded
  ///                                            sibling
  /// ```
  ///
  /// The first line works because of an invariant the rule guarantees by
  /// construction: **a leaf at index 0 is folded only when the whole vagga is
  /// folded.** A run that starts at the first sutta anchors on that leaf, which
  /// stays unfolded and owns the URL. Every container with a folded first leaf
  /// (`FIGURES.wholeVaggaChapters`) has no unfolded sibling in it. That is
  /// checked rather than assumed, because a hand-edited snapshot violating it
  /// would otherwise produce a page that is half text and half navigation.
  ///
  /// Absent key = owns a page, which errs in the safe direction: a wrong
  /// explode costs a thin page, a wrong fold hides a named text behind a
  /// fragment.
  ///
  /// **A list, not one key**, because the corpus has seven disjoint roots
  /// (`vp`, `sp`, `ap`, `atta-vp`, `atta-sp`, `atta-ap`, `anya`) with no common
  /// ancestor. A single-root build is therefore never a whole site and often
  /// not even a coherent subtree: `an-1` sits under `sp` while its commentary
  /// `atta-an-1` sits under `atta-sp`, so the අට්ඨකථා cross-link every canon
  /// page emits (`PageTemplate._commentaryLink`) points outside the build —
  /// on a single-book subtree, a large fraction of its links.
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
    required Set<String> foldedLeafKeys,
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

      if (children.isNotEmpty &&
          foldedLeafKeys.contains(children.first.nodeKey)) {
        final unfolded = [
          for (final child in children)
            if (!foldedLeafKeys.contains(child.nodeKey)) child.nodeKey,
        ];
        if (unfolded.isNotEmpty) {
          throw StateError(
            'Container "${node.nodeKey}" has a folded first child but '
            '${unfolded.length} unfolded sibling(s) (${unfolded.first}). That '
            'is a page half text and half navigation, which the rule cannot '
            'produce — the snapshot has been hand-edited.',
          );
        }
        final containers = [
          for (final child in children)
            if (!child.isLeaf) child.nodeKey,
        ];
        if (containers.isNotEmpty) {
          throw StateError(
            'Container "${node.nodeKey}" folds wholesale but '
            '${containers.length} of its children '
            '${containers.length == 1 ? 'is a container' : 'are containers'} '
            '(${containers.first}). Their own subtrees would be swallowed '
            'unrendered — the snapshot has been hand-edited.',
          );
        }
        pages.add(SitePage(
          kind: PageKind.chapter,
          node: node,
          suttas: children,
        ));
        return; // children are inside the chapter file
      }

      pages.add(SitePage(kind: PageKind.toc, node: node, suttas: const []));
      // Every folded child has to end up inside some run. A leaf whose nearest
      // preceding sibling is a *container* has none to join — runs only extend
      // forwards from an unfolded leaf — so it would otherwise be dropped from
      // the site in silence, and `urlFor` would hand out a URL with no file.
      // The rule cannot produce that (a container groups only if all its
      // children are leaves), but 94 mixed containers exist for a hand-edit to
      // land in, and the aggregate counts cannot see it: the derivation
      // identity reads a run's end index, not its members.
      final attached = <String>{};
      for (var i = 0; i < children.length; i++) {
        final child = children[i];
        if (!child.isLeaf) {
          walk(child);
          continue;
        }
        // Attached to the page an earlier sibling started, on the pass below.
        if (foldedLeafKeys.contains(child.nodeKey)) continue;

        final run = <TipitakaNode>[child];
        for (var j = i + 1; j < children.length; j++) {
          if (!foldedLeafKeys.contains(children[j].nodeKey)) break;
          run.add(children[j]);
          attached.add(children[j].nodeKey);
        }
        pages.add(SitePage(
          kind: run.length == 1 ? PageKind.sutta : PageKind.chapter,
          node: child,
          suttas: run,
        ));
      }
      final stranded = [
        for (final child in children)
          if (foldedLeafKeys.contains(child.nodeKey) &&
              !attached.contains(child.nodeKey))
            child.nodeKey,
      ];
      if (stranded.isNotEmpty) {
        throw StateError(
          'Container "${node.nodeKey}" has ${stranded.length} folded '
          'child(ren) (${stranded.first}) that no run picked up, so they would '
          'appear on no page at all — the snapshot has been hand-edited.',
        );
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

    // Where a folded leaf is actually served. Built here and nowhere else:
    // this is the only place that knows which page a folded leaf ended up on,
    // so anything deriving that answer independently would eventually disagree
    // with it.
    final serving = <String, String>{};
    for (final page in pages) {
      if (page.kind != PageKind.chapter) continue;
      for (final sutta in page.suttas) {
        // The anchor of a mid-vagga chapter is not folded — the chapter's own
        // URL *is* its URL, and giving it a fragment would be a second URL for
        // the same page.
        if (sutta.nodeKey == page.nodeKey) continue;
        serving[sutta.nodeKey] = '${page.url}#${sutta.nodeKey}';
      }
    }

    final readable = pages.where((page) => page.isReadable).toList();
    return SitePlan._(
      pages,
      readable,
      {for (var i = 0; i < readable.length; i++) readable[i].nodeKey: i},
      serving,
    );
  }

  /// Where a link to [nodeKey] must point.
  ///
  /// A folded leaf has no file of its own, so it resolves to
  /// `<chapter>#<nodeKey>` — the page carrying it, which the `:has(:target)`
  /// CSS then filters to single view. Everything else is its own URL.
  ///
  /// **Never `node.parentNodeKey`.** `FIGURES.midVaggaChapters` anchor on a
  /// sibling leaf rather than the container, so the parent shortcut is wrong
  /// for roughly half the folded leaves — and wrong *silently*, because it
  /// resolves to a container that exists.
  String urlFor(String nodeKey) => _servingUrl[nodeKey] ?? tipitakaUrl(nodeKey);

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
/// page title, where it does the disambiguating work:
/// `FIGURES.leavesSharingATitle` leaves share a name with another leaf, and the
/// collection plus the parent vagga separates almost all of them.
TipitakaNode? collectionOf(TipitakaTree tree, String nodeKey) {
  final ancestors = tree.ancestorsOf(nodeKey);
  if (ancestors.isEmpty) return null;
  return ancestors.length >= 2
      ? ancestors[ancestors.length - 2]
      : ancestors.last;
}
