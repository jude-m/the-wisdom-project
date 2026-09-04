import 'package:test/test.dart';
import 'package:wisdom_shared/wisdom_shared.dart';

/// The one question both surfaces ask of [SitePlan]: **which URL names exactly
/// this node, and nothing else?** The site writes that answer into its HTML
/// through [SitePlan.urlFor], the app hands it to a copy button through
/// [SitePlan.servingLink], and the search index derives it a third time. Three
/// callers, one rule — which has already come apart once, when `urlFor` learned
/// that a chapter anchored on its first leaf needs `<key>#<key>` and
/// `servingLink`, ten lines below it, kept returning the bare URL.
///
/// Runs on the synthetic tree below rather than the vendored corpus: the four
/// page shapes are what matter, and each is three or four nodes. Whether the
/// frozen snapshot still describes the real tree is asked by
/// `static_site_generator/tool/plan_corpus.dart`.
void main() {
  group('the fixture produces all four page shapes', () {
    // Every invariant below loops over whatever the plan happened to build, so
    // a change that quietly stopped producing leaf-anchored chapters would
    // leave those loops passing while covering nothing. This fails instead.
    test('one page per shape, at the key each shape sits on', () {
      expect(
        {for (final page in _plan.pages) page.nodeKey: page.kind},
        {
          'sp': PageKind.toc,
          'sp-whole': PageKind.chapter, // whole vagga, at the container's URL
          'sp-mid': PageKind.toc,
          'sp-mid-1': PageKind.sutta, // owns its file
          'sp-mid-2': PageKind.chapter, // a run starting below the container
          'sp-lone': PageKind.chapter, // container merged with its only leaf
        },
      );
    });

    test('exactly one of them is anchored on a leaf', () {
      // A whole-vagga chapter and a lone-child chapter both sit at a
      // *container's* URL, where the bare form is already right.
      expect(
        _plan.pages.where((p) => p.anchorsRunOnLeaf).map((p) => p.nodeKey),
        ['sp-mid-2'],
      );
    });
  });

  group('one address per node, whichever surface is asked', () {
    // A loop rather than a table: the interesting failures are the ones nobody
    // thought to write a row for.
    for (final key in _servedKeys) {
      test(key, () {
        final url = _plan.urlFor(key);
        final page = _plan.pageOf(key)!;

        // 1. The site's HTML and the app's copy button write the same string —
        //    the assertion the `servingLink` regression failed.
        expect(
          _plan.servingLink(TipitakaLink(nodeKey: key)).toUri(_base),
          Uri.parse('$_base$url'),
          reason: 'urlFor and servingLink disagree about $key',
        );

        // 2. The URL parses back to the node the reader asked for, never the
        //    page carrying it. For a folded leaf the path names the chapter, so
        //    reading the path alone opens the wrong sutta.
        expect(TipitakaLink.parse(Uri.parse('$_base$url'))!.nodeKey, key);

        // 3. A fragment always names a section the page really renders; a bare
        //    URL is only written when the page *is* that node, whole. Between
        //    them: no fragment pointing at nothing, no bare URL answering with
        //    more text than was asked for.
        if (url.contains('#')) {
          expect(page.suttas.map((s) => s.nodeKey), contains(key));
        } else {
          expect(page.nodeKey, key);
          expect(page.anchorsRunOnLeaf, isFalse);
        }
      });
    }
  });

  group('servingLink decides the page key rather than passing it through', () {
    // The constructor used to drop a page key repeating the node key, which
    // made `<key>#<key>` a state no link could hold. That had to go when the
    // anchor leaves started needing exactly that form — so the codec can now
    // hand `servingLink` a page key the site would never write, and an early
    // return would hand it straight back out.
    for (final key in _servedKeys) {
      test('$key is addressed the same however the link arrived', () {
        final fromNodeKeyAlone = _plan.servingLink(TipitakaLink(nodeKey: key));
        // The shape `parse` now produces for `/tipitaka/<key>#<key>`.
        expect(
          _plan.servingLink(TipitakaLink(nodeKey: key, pageKey: key)),
          fromNodeKeyAlone,
        );
        // And a page key that is simply wrong — a stale link, a hand-written
        // one — must not survive either.
        expect(
          _plan.servingLink(TipitakaLink(nodeKey: key, pageKey: 'sp')),
          fromNodeKeyAlone,
        );
      });
    }

    test('an origin link keeps its door instead of being given a page', () {
      // `sp-mid-2` is the one key whose own page still wants `<key>#<key>`, so
      // it is the only place the two fragments can collide. The door has to
      // win: the page key would only repeat what the path already says, while
      // dropping the door loses the vaṇṇanā the reader clicked and lands them
      // on the anchor sutta — silently, and on a page that returns 200.
      const link = TipitakaLink(nodeKey: 'sp-mid-2', originKey: 'sp-mid-3');
      expect(_plan.servingLink(link), link);
      expect(
        _plan.servingLink(link).toUri(_base).toString(),
        '$_base/tipitaka/sp-mid-2#via_sp-mid-3',
      );
    });

    test('the round trip a shared link actually takes', () {
      // Copy a URL off the site, paste it into the app, share it again. It is
      // `sp-mid-1` — a leaf owning its page — that used to come back with a
      // fragment bolted on.
      final pasted =
          TipitakaLink.tryParse('$_base/tipitaka/sp-mid-1#sp-mid-1')!;
      expect(pasted.pageKey, 'sp-mid-1', reason: 'the codec holds this now');
      expect(
        _plan.servingLink(pasted).toUri(_base).toString(),
        '$_base/tipitaka/sp-mid-1',
      );
    });
  });

  group('resolveTarget reads back what servingLink writes', () {
    for (final key in _servedKeys) {
      test('$key survives the trip out and back', () {
        // The invariant the whole URL contract rests on, and the one the two
        // surfaces could previously only be trusted to share: the site writes
        // a URL for a node, and reading it back names that node again. Every
        // key here; every key in the corpus in `verify_corpus_invariants.dart`.
        final link = TipitakaLink.tryParse('$_base${_plan.urlFor(key)}')!;
        expect(_plan.resolveTarget(link), key);
      });
    }

    test('a fragment the page does not serve opens the page', () {
      // `sp-mid-1` is a real node — it just owns its own page, so this page
      // carries no section for it. "Is this a real node" would open it; the
      // site, finding nothing to target, shows `sp-mid-2`. Asking the plan is
      // what stops the two surfaces disagreeing about a URL neither of them is
      // locally wrong about.
      final link = TipitakaLink.tryParse('$_base/tipitaka/sp-mid-2#sp-mid-1')!;
      expect(_plan.resolveTarget(link), 'sp-mid-2');
    });

    test('a fragment naming no node at all opens the page', () {
      // `#top` is nodeKey-shaped, so the codec cannot rule it out — only the
      // plan can say the page serves no such section.
      final link = TipitakaLink.tryParse('$_base/tipitaka/sp-mid-2#top')!;
      expect(_plan.resolveTarget(link), 'sp-mid-2');
    });

    test('a door opens the vaṇṇanā, not the chapter carrying it', () {
      // `atta-ck-2` answers for three suttas, so its own key names only the
      // first of them. It is folded as well, so the path can name nothing
      // finer than the chapter — the fragment is the only part of the URL that
      // can say which sutta the reader left.
      expect(canonKeysCoveredBy(_mergedTree, 'atta-ck-2'),
          ['ck-2', 'ck-3', 'ck-4']);

      final link = TipitakaLink.tryParse('$_base/tipitaka/atta-ck#via_ck-3')!;
      expect(_mergedPlan.resolveTarget(link), 'atta-ck-2');
    });

    test('a door on a page that does not carry the vaṇṇanā opens the page', () {
      // The same marker, moved onto a page that has no such marker in it — a
      // hand-edited fragment, or a link kept across a re-sync that moved a key.
      // The tree alone still answers `atta-ck-2`, and following it would put
      // the app on a text the browser cannot show: `ck` carries no `via_ck-3`,
      // so the site shows `ck`. The door is a claim about *this* page.
      final link = TipitakaLink.tryParse('$_base/tipitaka/ck#via_ck-3')!;
      expect(_mergedPlan.resolveTarget(link), 'ck');
    });

    test('a door into a vaṇṇanā this build has no page for opens the page', () {
      // A plan over the canon alone — the shape a subtree build produces. The
      // commentary is still in the tree, so `crossLinkTargetKey` answers; what
      // is missing is a page, and a plan cannot vouch for a page it never made.
      final canonOnly = SitePlan.build(
        tree: _mergedTree,
        rootKeys: const ['ck'],
        foldedLeafKeys: const {'ck-3', 'ck-4'},
        textBearingContainerKeys: const {},
      );
      expect(crossLinkTargetKey(_mergedTree, 'ck-3'), 'atta-ck-2',
          reason: 'the tree still knows; only the plan does not');

      final link = TipitakaLink.tryParse('$_base/tipitaka/atta-ck#via_ck-3')!;
      expect(canonOnly.resolveTarget(link), 'atta-ck');
    });
  });

  group('the leaf-anchored chapter', () {
    // Named as well as looped, so a regression reads as a sentence rather than
    // as "key sp-mid-2 failed".
    test('the anchor asks its own page for itself alone', () {
      // Not one address written twice: bare, that URL serves the whole run;
      // with the fragment, the `:has(:target)` CSS filters it to one sutta.
      expect(_plan.urlFor('sp-mid-2'), '/tipitaka/sp-mid-2#sp-mid-2');
    });

    test('a leaf that owns its page keeps the bare URL', () {
      expect(_plan.urlFor('sp-mid-1'), '/tipitaka/sp-mid-1');
    });

    test('a folded leaf is served by its sibling, never by its parent', () {
      // The tempting failure: `node.parentNodeKey` answers `sp-mid` here, which
      // exists and renders — a TOC listing the sutta rather than the sutta.
      expect(_plan.urlFor('sp-mid-3'), '/tipitaka/sp-mid-2#sp-mid-3');
      expect(_plan.pageOf('sp-mid-3')!.nodeKey, 'sp-mid-2');
    });

    test('a chapter at a container URL needs no fragment for itself', () {
      expect(_plan.urlFor('sp-whole'), '/tipitaka/sp-whole');
      expect(_plan.urlFor('sp-whole-1'), '/tipitaka/sp-whole#sp-whole-1');
    });

    test('a lone child is folded onto the container it was merged with', () {
      expect(_plan.urlFor('sp-lone'), '/tipitaka/sp-lone');
      expect(_plan.urlFor('sp-lone-1'), '/tipitaka/sp-lone#sp-lone-1');
    });
  });

  group('speaksForRun — one cross-link for the run, or one per sutta', () {
    test('a chapter named after its container speaks for the whole run', () {
      // `atta-ck` folded both its vaṇṇanā, so the page is the container and its
      // twin `ck` is the container the sections' own twins sit under. One
      // `අට්ඨකථා` answers the question the bare URL asked.
      final page = _mergedPlan.pageOf('atta-ck')!;
      expect(page.kind, PageKind.chapter);
      expect(page.anchorsRunOnLeaf, isFalse);
      expect(_mergedPlan.speaksForRun(page), isTrue);
    });

    test('a run anchored on its own first leaf does not', () {
      // The clause that is not implied by the subtree test below: `ck-2` and
      // the leaves folded behind it all resolve to `atta-ck-2`, so they *agree*
      // — and the page would still be claiming the run under sutta two's name,
      // whose own URL is `<page>#<key>`.
      final page = _mergedPlan.pageOf('ck-3')!;
      expect(page.nodeKey, 'ck-2');
      expect(page.anchorsRunOnLeaf, isTrue);
      for (final key in ['ck-2', 'ck-3', 'ck-4']) {
        expect(crossLinkTargetKey(_mergedTree, key), 'atta-ck-2',
            reason: 'fixture no longer isolates the anchor clause');
      }
      expect(_mergedPlan.speaksForRun(page), isFalse);
    });

    test('a lone-child chapter has no run to speak for', () {
      // One sutta wearing its container's URL. Built on `_mergedTree` and not
      // on `sp-lone`, which has no commentary side at all: there the predicate
      // would refuse on the null target and the test would pass with the clause
      // deleted. Here every earlier clause *accepts* — the node is a container,
      // its twin `ck` exists, and the one section's twin `ck-1` sits under it,
      // so the subtree test is satisfied — and only the count refuses.
      final lone = SitePage(
        kind: PageKind.chapter,
        node: _mergedTree['atta-ck']!,
        suttas: [_mergedTree['atta-ck-1']!],
      );
      expect(lone.anchorsRunOnLeaf, isFalse);
      expect(crossLinkTargetKey(_mergedTree, 'atta-ck'), 'ck');
      expect(crossLinkTargetKey(_mergedTree, 'atta-ck-1'), 'ck-1');
      expect(_mergedTree.isAncestorOf('ck', 'ck-1'), isTrue,
          reason: 'fixture no longer isolates the lone-child clause');
      expect(_mergedPlan.speaksForRun(lone), isFalse,
          reason: 'the coarse link would be the container TOC, and the one '
              'section already has a nearer answer');
    });

    test('a lone child still speaks where its own link carries markers', () {
      // The exception, and the reason the lone-child clause is a condition
      // rather than a flat refusal. `atta-mk-1` answers for a run of two
      // *containers* while its one section answers for a *sutta* inside the
      // first — disjoint sets at different levels, both addressed by id from
      // the canon side. Suppress this link as "the coarser one" and the markers
      // it prints go with it, while the canon pages keep aiming at them.
      expect(canonKeysCoveredBy(_markerTree, 'atta-mk-1'), ['mk-1', 'mk-2'],
          reason: 'fixture no longer declares a range');
      expect(linksThroughOriginMarkers(_markerTree, 'atta-mk-1'), isTrue);
      final lone = SitePage(
        kind: PageKind.chapter,
        node: _markerTree['atta-mk-1']!,
        suttas: [_markerTree['atta-mk-1-1']!],
      );
      expect(lone.anchorsRunOnLeaf, isFalse);
      // Every other clause would suppress it: one section, and that section's
      // twin `mk-1-1` sits under the run's twin `mk-1`.
      expect(crossLinkTargetKey(_markerTree, 'atta-mk-1-1'), 'mk-1-1');
      expect(_markerTree.isAncestorOf('mk-1', 'mk-1-1'), isTrue);
      expect(_markerPlan.speaksForRun(lone), isTrue);
      // Unordered on purpose — see [SitePlan.crossLinkedNodes]. What matters is
      // that the page's own node is in there beside its section.
      expect(_markerPlan.crossLinkedNodes(lone).map((n) => n.nodeKey),
          unorderedEquals(['atta-mk-1', 'atta-mk-1-1']));
    });

    test('a lone child speaks where its coarse link is its section\'s page',
        () {
      // The same-file exception, mirroring `atta-sn-4-1-17`: one vaṇṇanā on a
      // whole vagga, whose own link (`wr-1`) and its section's (`wr-1-1`) name
      // one file — so the coarse link is that page unfiltered, and a reader
      // taking it loses nothing.
      final lone = _wholeRunPlan.pageOf('atta-wr-1')!;
      expect(lone.kind, PageKind.chapter);
      expect(lone.suttas.map((s) => s.nodeKey), ['atta-wr-1-1']);
      // Every earlier clause would suppress it: one section, no markers, and
      // that section's twin sits under the run's.
      expect(linksThroughOriginMarkers(_wholeRunTree, 'atta-wr-1'), isFalse,
          reason: 'the marker exception would mask the clause under test');
      expect(_wholeRunTree.isAncestorOf('wr-1', 'wr-1-1'), isTrue);
      // The two halves of the exception, stated rather than implied.
      expect(
          _wholeRunPlan.pageOf('wr-1'), same(_wholeRunPlan.pageOf('wr-1-1')));
      expect(_wholeRunPlan.pageOf('wr-1')!.needsFragmentFor('wr-1'), isFalse);
      expect(_wholeRunPlan.speaksForRun(lone), isTrue);
    });

    test('and refuses once those canon leaves own their own files', () {
      // The same tree with nothing folded. `wr-1-1` is now its own page, so the
      // coarse link is no longer the section's page and the reader would be
      // handed a different file. Grouping alone flips the answer, which is why
      // the predicate needs the plan rather than the page.
      final lone = SitePage(
        kind: PageKind.chapter,
        node: _wholeRunTree['atta-wr-1']!,
        suttas: [_wholeRunTree['atta-wr-1-1']!],
      );
      expect(_unfoldedRunPlan.pageOf('wr-1-1')!.nodeKey, 'wr-1-1');
      expect(_unfoldedRunPlan.speaksForRun(lone), isFalse);
    });

    test('a chapter with no sections answers rather than throwing', () {
      // `SitePlan.build` never emits one, but `SitePage` is public and both
      // suites hand-build pages — as does the app, which reads the same plan.
      // The lone-child clause reads `suttas.single`, so a `< 2` guard lets a
      // sectionless page reach it and blow up on `Bad state: No element`.
      final empty = SitePage(
        kind: PageKind.chapter,
        node: _markerTree['atta-mk-1']!,
        suttas: const [],
      );
      expect(crossLinkTargetKey(_markerTree, 'atta-mk-1'), isNotNull,
          reason: 'an early null target would mask the throw');
      expect(_markerPlan.speaksForRun(empty), isTrue);
      expect(_markerPlan.crossLinkedNodes(empty).map((n) => n.nodeKey),
          ['atta-mk-1']);
    });

    test('a section whose commentary escapes the run keeps its own link', () {
      // The subtree clause. `ck-1`'s twin is `atta-ck-1`, which sits under
      // `atta-ck` — so a page whose own twin were `atta-ck-1` could not speak
      // for it. Built by hand: no grouping produces this shape, which is why
      // the corpus has almost none of it.
      final escaping = SitePage(
        kind: PageKind.chapter,
        node: _mergedTree['atta-ck-1']!,
        suttas: [_mergedTree['atta-ck-2']!],
      );
      expect(crossLinkTargetKey(_mergedTree, 'atta-ck-1'), 'ck-1');
      expect(crossLinkTargetKey(_mergedTree, 'atta-ck-2'), 'ck-2');
      expect(_mergedPlan.speaksForRun(escaping), isFalse,
          reason: '`ck-2` does not sit under `ck-1`, so one link cannot reach '
              'both');
    });

    test('a TOC and a sutta page never speak for a run', () {
      // The predicate is a chapter's question. Both other kinds answer their
      // own cross-link at page level already, and a second one would double it.
      expect(_mergedPlan.speaksForRun(_mergedPlan.pageOf('ck-1')!), isFalse);
      expect(_plan.pageOf('sp-mid')!.kind, PageKind.toc);
      expect(_plan.speaksForRun(_plan.pageOf('sp-mid')!), isFalse);
    });
  });

  group('a key this build never heard of', () {
    // A plan is built per subtree, and a single-book build does not walk the
    // root a commentary lives under. The bare URL is right on a whole-corpus
    // build and the best available otherwise.
    test('resolves to its own URL rather than throwing', () {
      expect(_plan.urlFor('atta-an-1'), '/tipitaka/atta-an-1');
      expect(_plan.pageOf('atta-an-1'), isNull);
    });

    test('is one of the two cases servingLink leaves alone', () {
      // Including the page key it arrived with: there is no plan answer to
      // substitute, so passing it through beats inventing one.
      const link = TipitakaLink(nodeKey: 'atta-an-1', pageKey: 'atta-an');
      expect(_plan.servingLink(link), link);
    });
  });
}

/// Any host works — [TipitakaLink.parse] accepts them all.
const String _base = 'https://sammaditthi.net';

/// The smallest tree carrying every shape the split rule produces.
///
/// ```text
/// sp                    TOC
///   sp-whole            chapter — first child folded, so the whole vagga folds
///     sp-whole-1          folded
///     sp-whole-2          folded
///   sp-mid              TOC — mixed, which is what makes the anchor case
///     sp-mid-1            its own page (its next sibling is unfolded)
///     sp-mid-2            unfolded, and anchors the run below it
///     sp-mid-3            folded onto sp-mid-2
///     sp-mid-4            folded onto sp-mid-2
///   sp-lone             chapter — a container with one folded child
///     sp-lone-1           folded
/// ```
///
/// `sp-mid` is the shape worth reading twice: the run starts at the *second*
/// child, so its page sits at a leaf's URL rather than the container's — the
/// vagga's own URL is already the TOC listing all four suttas and cannot also
/// be a run starting halfway down it.
final TipitakaTree _tree = TipitakaTree.fromJson({
  'sp': _row(null),
  'sp-whole': _row('sp'),
  'sp-whole-1': _row('sp-whole'),
  'sp-whole-2': _row('sp-whole'),
  'sp-mid': _row('sp'),
  'sp-mid-1': _row('sp-mid'),
  'sp-mid-2': _row('sp-mid'),
  'sp-mid-3': _row('sp-mid'),
  'sp-mid-4': _row('sp-mid'),
  'sp-lone': _row('sp'),
  'sp-lone-1': _row('sp-lone'),
});

/// Hand-made, never the shipped snapshot: these keys are not in the corpus, and
/// a test reading the real set would measure the corpus instead of the rule.
final SitePlan _plan = SitePlan.build(
  tree: _tree,
  rootKeys: const ['sp'],
  foldedLeafKeys: const {
    'sp-whole-1',
    'sp-whole-2',
    'sp-mid-3',
    'sp-mid-4',
    'sp-lone-1',
  },
  textBearingContainerKeys: const {},
);

/// Every key the plan can answer for. A `Set` because a sutta page's own node
/// and a leaf-anchored chapter's anchor each appear in both `node` and
/// `suttas`, so a flat walk would run those tests twice under one name.
final List<String> _servedKeys = <String>{
  for (final page in _plan.pages) ...[
    page.nodeKey,
    ...page.suttas.map((s) => s.nodeKey),
  ],
}.toList();

/// The commentary shape `_tree` has no side for: one vaṇṇanā answering for a
/// run of suttas, which is what makes a door necessary in the first place.
///
/// ```text
/// ck                  TOC
///   ck-1                its own page
///   ck-2                unfolded, and anchors the run below it
///   ck-3                folded onto ck-2
///   ck-4                folded onto ck-2
/// atta-ck             chapter — every child folded, so it carries both
///   atta-ck-1           "1." — answers for ck-1 alone
///   atta-ck-2           "2-4." — answers for ck-2, ck-3 and ck-4
/// ```
final TipitakaTree _mergedTree = TipitakaTree.fromJson({
  'ck': _row(null),
  'ck-1': _row('ck'),
  'ck-2': _row('ck'),
  'ck-3': _row('ck'),
  'ck-4': _row('ck'),
  'atta-ck': _row(null),
  'atta-ck-1': _row('atta-ck', '1. පඨමසුත්තවණ්ණනා'),
  'atta-ck-2': _row('atta-ck', '2-4. දුතියසුත්තාදිවණ්ණනා'),
});

/// A lone-child chapter whose *own* vaṇṇanā answers for a run, mirroring
/// `atta-sn-5-1-7`: the container's link and its one section's link carry
/// disjoint marker sets at different levels of the tree, so neither can stand
/// in for the other.
///
/// ```text
/// mk                  TOC
///   mk-1                answered by atta-mk-1 …
///     mk-1-1              … while this is answered by its leaf
///   mk-2                also answered by atta-mk-1, which declares "1-2."
/// atta-mk             TOC
///   atta-mk-1           chapter — a container with one folded child
///     atta-mk-1-1         folded
/// ```
final TipitakaTree _markerTree = TipitakaTree.fromJson({
  'mk': _row(null),
  'mk-1': _row('mk'),
  'mk-1-1': _row('mk-1'),
  'mk-2': _row('mk'),
  'atta-mk': _row(null),
  'atta-mk-1': _row('atta-mk', '1-2. පඨමවග්ගාදිවණ්ණනා'),
  'atta-mk-1-1': _row('atta-mk-1', '1. පඨමසුත්තවණ්ණනා'),
});

/// A vaṇṇanā covering a whole vagga, mirroring `atta-sn-4-1-17`: the
/// commentary container's link and its one section's link land on the same
/// canon file, one bare and one on a fragment.
///
/// ```text
/// wr                  TOC
///   wr-1                chapter — both leaves folded, so it carries both
///     wr-1-1              folded
///     wr-1-2              folded
/// atta-wr             TOC
///   atta-wr-1           chapter — a container merged with its only child
///     atta-wr-1-1         folded — "1-2.", the whole vagga in one vaṇṇanā
/// ```
final TipitakaTree _wholeRunTree = TipitakaTree.fromJson({
  'wr': _row(null),
  'wr-1': _row('wr'),
  'wr-1-1': _row('wr-1'),
  'wr-1-2': _row('wr-1'),
  'atta-wr': _row(null),
  'atta-wr-1': _row('atta-wr'),
  'atta-wr-1-1': _row('atta-wr-1', '1-2. පඨමසුත්තාදිවණ්ණනා'),
});

final SitePlan _wholeRunPlan = SitePlan.build(
  tree: _wholeRunTree,
  rootKeys: const ['wr', 'atta-wr'],
  foldedLeafKeys: const {'wr-1-1', 'wr-1-2', 'atta-wr-1-1'},
  textBearingContainerKeys: const {},
);

/// [_wholeRunTree] with nothing folded, so every canon leaf owns its own file.
/// The commentary page is hand-built there — unfolded, its container is a TOC.
final SitePlan _unfoldedRunPlan = SitePlan.build(
  tree: _wholeRunTree,
  rootKeys: const ['wr', 'atta-wr'],
  foldedLeafKeys: const {},
  textBearingContainerKeys: const {},
);

final SitePlan _mergedPlan = SitePlan.build(
  tree: _mergedTree,
  rootKeys: const ['ck', 'atta-ck'],
  foldedLeafKeys: const {'ck-3', 'ck-4', 'atta-ck-1', 'atta-ck-2'},
  textBearingContainerKeys: const {},
);

/// A plan over [_markerTree], so that fixture's hand-built pages can be asked
/// [SitePlan.speaksForRun].
final SitePlan _markerPlan = SitePlan.build(
  tree: _markerTree,
  rootKeys: const ['mk', 'atta-mk'],
  foldedLeafKeys: const {},
  textBearingContainerKeys: const {},
);

/// One `tree.json` row: `[pali, sinh, level, [page, entry], parent, fileId]`.
/// Placeholder names — [SitePlan] reads only keys and parentage.
List<dynamic> _row(String? parent, [String title = 'pali']) => [
      title,
      title,
      1,
      const <int>[0, 0],
      parent ?? 'root',
      'f'
    ];
