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
const String _base = 'https://sammaditthi.app';

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

/// One `tree.json` row: `[pali, sinh, level, [page, entry], parent, fileId]`.
/// Placeholder names — [SitePlan] reads only keys and parentage.
List<dynamic> _row(String? parent) => [
      'pali',
      'sinh',
      1,
      const <int>[0, 0],
      parent ?? 'root',
      'f'
    ];
