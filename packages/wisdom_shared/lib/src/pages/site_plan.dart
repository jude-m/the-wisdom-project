// Prefixed because the two frozen sets are also the names of the parameters
// they default to on `SitePlan.build`, and a parameter shadows a top-level
// const of the same name.
import '../grouping/grouping_snapshot.dart' as snapshot;
import '../grouping/preamble_snapshot.dart' as snapshot;
import '../links/tipitaka_link.dart';
import '../tree/tipitaka_tree.dart';

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

  /// A higher container, whose page is the list of links to its children.
  ///
  /// **Not necessarily links alone.** A TOC also prints its own preamble — the
  /// rows between its coordinate and its first child's — and on
  /// `FIGURES.readableContainerTocs` of them that preamble is the book's
  /// introduction to the chapter rather than a title and `namo tassa`. Those
  /// pages are readable: see [SitePage.isReadable]. What no TOC ever carries is
  /// a *leaf's* text, which is what `GroupingPlanner`'s first precondition
  /// holds off.
  toc,
}

/// One output file.
class SitePage {
  final PageKind kind;
  final TipitakaNode node;

  /// Leaves rendered inside this page. One entry for [PageKind.sutta], the
  /// whole run for [PageKind.chapter], empty for a TOC.
  final List<TipitakaNode> suttas;

  /// True when this page's own node opens with an introduction rather than a
  /// heading — see [PreamblePlanner] and `textBearingContainerKeys`.
  ///
  /// Only ever set on a [PageKind.toc]. A sutta page's node is a leaf and has
  /// no preamble at all; a chapter's preamble is already rendered on a page
  /// that is readable whatever it holds. The TOC is the one kind where the
  /// answer changes what the page *does*, so it is the one kind that carries
  /// the flag.
  final bool ownsRunningText;

  /// Not `const`, because [suttas] is frozen on the way in — the same stance
  /// [TipitakaTree] takes on `childKeys`. A plan now outlives the build that
  /// made it (the app caches one for its whole run and hands pages to the UI),
  /// so "nobody mutates it" stopped being something one file could promise.
  SitePage({
    required this.kind,
    required this.node,
    required List<TipitakaNode> suttas,
    this.ownsRunningText = false,
  }) : suttas = List.unmodifiable(suttas);

  String get nodeKey => node.nodeKey;

  /// `/tipitaka/an-1-1` — the same grammar the app's deep links use, so one URL
  /// serves both surfaces.
  String get url => tipitakaUrl(nodeKey);

  /// True when this page carries body text — the pages prev/next walks, and
  /// the ones that get a layout switcher and the reading measure.
  ///
  /// **Not "is it a TOC".** It was, from P1 until the container preambles were
  /// measured, and it was wrong for every container whose preamble is the
  /// book's introduction to the chapter: those pages carry running text and
  /// were served as pure navigation, skipped by prev/next so that nothing but a
  /// click down the tree could reach them. The predicate now says what its name
  /// always claimed.
  ///
  /// Membership in the chain, not what a page draws: a readable container is a
  /// stop for its neighbours but prints "prev" alone — see
  /// `PageTemplate.render`.
  bool get isReadable => kind != PageKind.toc || ownsRunningText;

  /// True when the page's own node has a slice to render above its contents.
  ///
  /// It is exactly *"is this page anchored on a container"*: a TOC node is
  /// always a container and a sutta node always a leaf, so [kind] adds nothing.
  /// A leaf-anchored chapter has no preamble — the container's slice belongs to
  /// its TOC page, and repeating it below would print the vagga title twice.
  bool get hasPreamble => !node.isLeaf;

  /// True when this page's *own* key still needs a fragment to name its own
  /// node — the one case where `<key>#<key>` is not a redundant address.
  ///
  /// A chapter anchored on its first leaf (`FIGURES.midVaggaChapters`) is the
  /// only page whose key is not the whole of what it serves: bare, its URL
  /// prints the entire run, and the anchor sutta alone is what the
  /// `:has(:target)` CSS filters to. A chapter sitting at its container's URL
  /// is the opposite case — the container *is* the run, so the bare URL is
  /// already the right answer, and so is a lone-child chapter's (its node is
  /// the container it was merged with).
  ///
  /// Read through [needsFragmentFor] wherever a link is being built — the site's
  /// HTML, a link copied out of the app, a search hit — so none of them can name
  /// the anchor sutta differently. Read directly by `PageBudget`, which counts
  /// exactly these pages as the `FIGURES.midVaggaChapters` this doc names: the
  /// figure and the predicate define each other, so they must not be two
  /// separate spellings of `node.isLeaf`.
  bool get anchorsRunOnLeaf => kind == PageKind.chapter && node.isLeaf;

  /// True when a link to [nodeKey] needs a fragment to name only that node on
  /// this page.
  ///
  /// The question every link builder is actually asking, kept here rather than
  /// spelled out at each of them. Its two clauses look unrelated — *is the
  /// target something this page merely carries*, and *is this page a run
  /// anchored on the target itself* — and they are one test: does the bare URL
  /// already name nothing but what was asked for. Written out separately they
  /// drifted within ten lines of each other, [SitePlan.urlFor] answering the
  /// second clause and [SitePlan.servingLink] skipping it.
  ///
  /// Every sutta on a chapter page returns true here: the folded ones on the
  /// first clause, the anchor on the second. That is why `buildSearchIndex`
  /// needs no guard when it writes a chapter's `chapterOf` rows.
  bool needsFragmentFor(String nodeKey) =>
      nodeKey != this.nodeKey || anchorsRunOnLeaf;
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

  /// Every nodeKey this plan can answer for → the page that serves it.
  ///
  /// A page's own key maps to itself; a folded leaf maps to the chapter
  /// carrying it. Built here and nowhere else: this is the only place that
  /// knows which page a folded leaf ended up on, so anything deriving that
  /// answer independently would eventually disagree with it. Read through
  /// [pageOf] (which page) or [urlFor] (which URL) — the two questions the two
  /// surfaces ask of the same map, which is why it is one map and not two.
  final Map<String, SitePage> _owningPage;

  /// Both public lists are frozen here for the same reason [SitePage] freezes
  /// its own — one plan is cached for the app's lifetime and read from the UI,
  /// where an accidental `sort` would silently rewrite prev/next for everyone.
  SitePlan._(
    List<SitePage> pages,
    List<SitePage> readablePages,
    this._readableIndex,
    this._owningPage,
  )   : pages = List.unmodifiable(pages),
        readablePages = List.unmodifiable(readablePages);

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
  /// ## The second frozen set
  ///
  /// [textBearingContainerKeys] answers a different question about the same
  /// walk: which of the containers that stayed TOCs open with an introduction
  /// rather than a heading, and so belong in the reading chain. It moves no
  /// URL — every page it names already existed at the same address — and is
  /// read here rather than measured for the same reason the first set is: this
  /// factory reads no text, and a page's prev/next depends on whether its
  /// *neighbours* are readable, so the answer has to be known before the first
  /// page renders. See [PreamblePlanner].
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
  /// **The two frozen sets default to the snapshot**, so an app or a tool that
  /// only wants "the site as it ships" cannot accidentally plan a different
  /// one. They stay parameters because the planners that *write* the snapshot
  /// build a plan from freshly measured sets to check them before they are
  /// frozen (`plan_corpus.dart --write-snapshot`), and because a test needs a
  /// hand-made set over a hand-made tree.
  factory SitePlan.build({
    required TipitakaTree tree,
    required List<String> rootKeys,
    Set<String> foldedLeafKeys = snapshot.foldedLeafKeys,
    Set<String> textBearingContainerKeys = snapshot.textBearingContainerKeys,
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

      pages.add(SitePage(
        kind: PageKind.toc,
        node: node,
        suttas: const [],
        ownsRunningText: textBearingContainerKeys.contains(node.nodeKey),
      ));
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

    // Which page serves which key — see [_owningPage]. Every page answers for
    // its own key and for every leaf it swallowed; a sutta page's single entry
    // is both at once, and a TOC answers only for itself.
    final owning = <String, SitePage>{};
    for (final page in pages) {
      owning[page.nodeKey] = page;
      for (final sutta in page.suttas) {
        owning[sutta.nodeKey] = page;
      }
    }

    final readable = pages.where((page) => page.isReadable).toList();
    return SitePlan._(
      pages,
      readable,
      {for (var i = 0; i < readable.length; i++) readable[i].nodeKey: i},
      owning,
    );
  }

  /// Where a link to [nodeKey] must point.
  ///
  /// A folded leaf has no file of its own, so it resolves to
  /// `<chapter>#<nodeKey>` — the page carrying it, which the `:has(:target)`
  /// CSS then filters to single view. So does the leaf a chapter is *anchored*
  /// on, whose fragment repeats the path: see [SitePage.anchorsRunOnLeaf].
  /// Everything else is its own bare URL.
  ///
  /// **Never `node.parentNodeKey`.** `FIGURES.midVaggaChapters` anchor on a
  /// sibling leaf rather than the container, so the parent shortcut is wrong
  /// for roughly half the folded leaves — and wrong *silently*, because it
  /// resolves to a container that exists.
  String urlFor(String nodeKey) {
    final page = _owningPage[nodeKey];
    // Not in this build at all — a subtree build's out-of-tree commentary
    // twin, say. Its own URL is the best answer available and the right one on
    // a whole-corpus build, where every key has a page.
    if (page == null) return tipitakaUrl(nodeKey);
    return page.needsFragmentFor(nodeKey) ? '${page.url}#$nodeKey' : page.url;
  }

  /// The same link, addressed the way the site actually serves it.
  ///
  /// A link the app builds names the node the reader is looking at, which for a
  /// folded leaf is not a page: shared as-is it would point at a URL the site
  /// has no file for. This fills in [TipitakaLink.pageKey] so the URL names the
  /// chapter and the fragment names the leaf — the same answer [urlFor] writes
  /// into the site's own HTML, from the same map, so a link copied out of the
  /// app and a link copied off the site are the same string.
  ///
  /// The page key is **decided here, never passed through**, so the result is a
  /// function of [TipitakaLink.nodeKey] and this plan alone: a link that owns
  /// its URL comes back with no page key even if it arrived carrying one. That
  /// used to be guaranteed further down, by a constructor that dropped a page
  /// key repeating the node key — which is also what made `<key>#<key>`
  /// unholdable, so it had to go when the anchor leaves started needing that
  /// form. Deciding rather than short-circuiting is what replaces it: a link
  /// parsed off a URL can now carry a page key the site would not have written,
  /// and an early return would hand it straight back out.
  ///
  /// Unchanged in two cases. When this build has never heard of the key (a plan
  /// is built per-subtree; only a whole-corpus plan knows every one), there is
  /// no answer to substitute. And when the link came through an origin marker,
  /// it is *already* addressed the way the site writes it: `_commentaryLink`
  /// drops the page fragment before appending `#via_…`, so the path names the
  /// page and the fragment names the door. A [TipitakaLink] holds one fragment,
  /// so filling in a page key there would have to drop the door — landing the
  /// reader on the chapter's anchor sutta rather than the vaṇṇanā they clicked,
  /// which is the one thing the marker exists to say.
  TipitakaLink servingLink(TipitakaLink link) {
    if (link.originKey != null) return link;
    final page = _owningPage[link.nodeKey];
    if (page == null) return link;
    return TipitakaLink(
      nodeKey: link.nodeKey,
      pageKey: page.needsFragmentFor(link.nodeKey) ? page.nodeKey : null,
      pageIndex: link.pageIndex,
      entryIndex: link.entryIndex,
    );
  }

  /// The page a reader lands on when they ask for [nodeKey], or null when this
  /// build has no page for it.
  ///
  /// The app's question, where [urlFor] is the site's: a folded leaf resolves
  /// to the chapter that carries it, so the app can open that unit and scroll
  /// to the leaf rather than opening the leaf as if it owned a page. Same map,
  /// same answer, so the two surfaces cannot disagree about which page a key
  /// belongs to.
  ///
  /// **Never `node.parentNodeKey`** — see [urlFor]. The
  /// `FIGURES.midVaggaChapters` chapters anchor on a sibling leaf, so for every
  /// leaf they carry the parent shortcut is wrong, and wrong while resolving to
  /// a container that exists.
  SitePage? pageOf(String nodeKey) => _owningPage[nodeKey];

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
