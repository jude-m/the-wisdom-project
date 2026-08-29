import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_wisdom_project/domain/entities/navigation/tipitaka_tree_node.dart';
import 'package:the_wisdom_project/presentation/providers/app_section_provider.dart';
import 'package:the_wisdom_project/presentation/providers/deep_link_provider.dart';
import 'package:the_wisdom_project/presentation/providers/navigation_tree_provider.dart';
import 'package:the_wisdom_project/presentation/providers/navigator_sync_provider.dart';
import 'package:the_wisdom_project/presentation/providers/tab_provider.dart';
import 'package:wisdom_shared/wisdom_shared.dart';

/// The app half of the static site's URL contract.
///
/// The site's side is pinned already — `wiring_contract_test` for the markup,
/// `tipitaka_link_test` for the grammar, `site_plan_test` for the URL each key
/// is written as. None of them can say whether the *app* lands on the same text
/// the browser does, and that is the half that has actually broken: a
/// cross-link that named the file instead of the text, and a `servingLink` that
/// dropped the door on the way out.
///
/// So every URL below is one the generator really writes, and the assertion is
/// always the same question — **which node opens** — asked through the public
/// provider, because the resolver itself is private.
void main() {
  group('opening a link -', () {
    test('a leaf that owns its page opens itself', () async {
      // The URL with nothing to disambiguate — no fragment, no override — and
      // the shape every test below is a departure from. It is also the one the
      // plan has to leave alone: `pageOf(k).nodeKey == k`, so the path is
      // already the whole address and nothing may be substituted for it.
      final opened = _Opened();
      final container = _containerFor(opened);

      await container.read(openTipitakaLinkProvider)(
        TipitakaLink.tryParse('$_base/tipitaka/dl-mid-1')!,
      );

      expect(opened.nodeKey, 'dl-mid-1');
    });

    test('an origin marker opens the vaṇṇanā, not the chapter carrying it',
        () async {
      // The URL `_commentaryLink` writes for the *second* sutta of a merged
      // run. `atta-dl-mid-2` is a folded leaf, so the path can only name the
      // chapter — the fragment is the sole part of the URL that says which of
      // the three suttas the reader left, and dropping it lands them on a run
      // of commentaries instead of the one they clicked.
      final opened = _Opened();
      final container = _containerFor(opened);
      container.read(selectedAppSectionProvider.notifier).state =
          AppSection.research;

      final link =
          TipitakaLink.tryParse('$_base/tipitaka/atta-dl-mid#via_dl-mid-3')!;
      expect(link.originKey, 'dl-mid-3', reason: 'the door, not the room');

      final didOpen = await container.read(openTipitakaLinkProvider)(link);

      expect(didOpen, isTrue);
      expect(opened.nodeKey, 'atta-dl-mid-2',
          reason: 'without the origin branch this is the chapter, atta-dl-mid');
      expect(container.read(selectedAppSectionProvider), AppSection.reader,
          reason: 'a link opened from Research still shows the reader');
    });

    test('a fragment the page really serves opens the leaf', () async {
      // `dl-mid-3` is folded onto the run anchored at `dl-mid-2`, so this is
      // the shape `urlFor` writes for every folded sutta.
      final opened = _Opened();
      final container = _containerFor(opened);

      await container.read(openTipitakaLinkProvider)(
        TipitakaLink.tryParse('$_base/tipitaka/dl-mid-2#dl-mid-3')!,
      );

      expect(opened.nodeKey, 'dl-mid-3');
    });

    test('a fragment the page does not serve opens the page', () async {
      // `dl-mid-1` is a real node — it just owns its own page, so this page
      // carries no section for it. The tree would happily open it; the site,
      // finding nothing to target, shows `dl-mid-2`. The plan is what makes the
      // two surfaces agree, and this is the case that separates them.
      final opened = _Opened();
      final container = _containerFor(opened);

      await container.read(openTipitakaLinkProvider)(
        TipitakaLink.tryParse('$_base/tipitaka/dl-mid-2#dl-mid-1')!,
      );

      expect(opened.nodeKey, 'dl-mid-2',
          reason: 'a real node is not the same question as a served node');
    });

    test('a page override with no entry starts at the top of that page',
        () async {
      final opened = _Opened();
      final container = _containerFor(opened);

      await container.read(openTipitakaLinkProvider)(
        TipitakaLink.tryParse('$_base/tipitaka/dl-mid-1?e=3')!,
      );

      expect(opened.pageIndex, 3);
      expect(opened.entryStart, 0,
          reason: 'never the node own entry — that one pairs with its own page');
    });

    test('an entry override is passed through, and no override stays null',
        () async {
      final opened = _Opened();
      final container = _containerFor(opened);
      final open = container.read(openTipitakaLinkProvider);

      await open(TipitakaLink.tryParse('$_base/tipitaka/dl-mid-1?e=3.2')!);
      expect(opened.pageIndex, 3);
      expect(opened.entryStart, 2);

      await open(TipitakaLink.tryParse('$_base/tipitaka/dl-mid-1')!);
      expect(opened.pageIndex, isNull);
      expect(opened.entryStart, isNull,
          reason: 'no page override means the node own coordinates stand');
    });
  });

  group('building a shareable URL -', () {
    test('a folded leaf is addressed the way the site serves it', () async {
      // The copy button holds the node the reader is looking at. Shared as-is
      // that names a URL the site never wrote.
      final container = _containerFor(_Opened());

      final uri = await container.read(tipitakaLinkUrlBuilderProvider)(
        const TipitakaLink(nodeKey: 'dl-mid-3'),
      );

      expect(uri.toString(), '$_base/tipitaka/dl-mid-2#dl-mid-3');
    });

    test('an origin link keeps its door', () async {
      // A link that already came through a marker is *already* addressed the
      // way the site writes it. Filling in a page key here would have to drop
      // the door — and, since a link cannot hold both, would trip the
      // constructor assert on a chapter anchored on a leaf.
      final container = _containerFor(_Opened());

      final uri = await container.read(tipitakaLinkUrlBuilderProvider)(
        const TipitakaLink(nodeKey: 'atta-dl-mid', originKey: 'dl-mid-3'),
      );

      expect(uri.toString(), '$_base/tipitaka/atta-dl-mid#via_dl-mid-3');
    });
  });

  group('when a snapshot will not load -', () {
    test('the plan failing does not sink the link', () async {
      // Both providers promise this in prose twice over: opening a link must
      // not become the one place a snapshot problem surfaces as a throw.
      final opened = _Opened();
      final container = _containerFor(opened, planFails: true);

      final didOpen = await container.read(openTipitakaLinkProvider)(
        TipitakaLink.tryParse('$_base/tipitaka/dl-mid-2#dl-mid-3')!,
      );

      expect(didOpen, isTrue);
      expect(opened.nodeKey, 'dl-mid-3', reason: 'the tree still answers');

      final uri = await container.read(tipitakaLinkUrlBuilderProvider)(
        const TipitakaLink(nodeKey: 'dl-mid-3'),
      );
      expect(uri.toString(), '$_base/tipitaka/dl-mid-3',
          reason: 'the answer the app gave before the plan existed');
    });

    test('the plan failing still opens the page a stale fragment sits on',
        () async {
      // The fallback's other arm. `dl-mid-9` names nothing the app holds — a
      // link kept from before a re-sync moved the key — so the fragment cannot
      // be the answer and the path it sits on is what is left. With the plan
      // loaded this is `pageOf`'s job; without one, the flat index is the only
      // thing that can tell a served leaf from a key that is simply gone.
      final opened = _Opened();
      final container = _containerFor(opened, planFails: true);

      final didOpen = await container.read(openTipitakaLinkProvider)(
        TipitakaLink.tryParse('$_base/tipitaka/dl-mid-2#dl-mid-9')!,
      );

      expect(didOpen, isTrue);
      expect(opened.nodeKey, 'dl-mid-2',
          reason: 'the fragment names no node, so the path is what is left');
    });
  });

  group('a link that opens nothing -', () {
    // Both ways [openTipitakaLinkProvider] answers false. Returning false is
    // the small half of each: the half that matters is that neither one pulls
    // the Reader into view, because the tab it would show was never opened.

    test('a key naming no node leaves the section where it was', () async {
      // `openTabFromNodeKey` answers -1 for a key `nodeByKeyProvider` cannot
      // find — a typo, or a link older than the re-sync that moved the key.
      final opened = _Opened();
      final container = _containerFor(opened);
      container.read(selectedAppSectionProvider.notifier).state =
          AppSection.research;

      final didOpen = await container.read(openTipitakaLinkProvider)(
        TipitakaLink.tryParse('$_base/tipitaka/dl-mid-9')!,
      );

      expect(didOpen, isFalse);
      expect(opened.nodeKey, isNull, reason: 'no tab was ever asked for');
      expect(container.read(selectedAppSectionProvider), AppSection.research,
          reason: 'an empty Reader is worse than staying where the tap was');
    });

    test('a tree that will not load opens nothing at all', () async {
      // The cold-start guard, and the one failure that returns before the
      // resolver is even asked — every step after it reads the tree.
      final opened = _Opened();
      final container = _containerFor(opened, treeFails: true);
      container.read(selectedAppSectionProvider.notifier).state =
          AppSection.research;

      final didOpen = await container.read(openTipitakaLinkProvider)(
        TipitakaLink.tryParse('$_base/tipitaka/dl-mid-1')!,
      );

      expect(didOpen, isFalse);
      expect(opened.nodeKey, isNull);
      expect(container.read(selectedAppSectionProvider), AppSection.research);
    });
  });

  group('the fixtures -', () {
    test('the two of them describe the same corpus', () async {
      // [_appNodes] is a hand-kept second shape of [_tree], and only the
      // fallback path reads it — so a key added to one and not the other would
      // leave every test above passing against a corpus that does not exist.
      final container = _containerFor(_Opened());
      await container.read(navigationTreeProvider.future);

      expect(
        container.read(nodeIndexProvider).keys.toSet(),
        (await container.read(sitePlanProvider.future))
            .tree
            .allNodes
            .map((n) => n.nodeKey)
            .toSet(),
      );
    });
  });
}

/// Both the host links are parsed from and the one they are built back to —
/// see [_containerFor], which overrides the dev-server default.
const String _base = 'https://sammaditthi.app';

/// What `openTabFromNodeKey` was asked to open — the only observable
/// [openTipitakaLinkProvider] has, since the resolver itself is private.
class _Opened {
  String? nodeKey;
  int? pageIndex;
  int? entryStart;
}

ProviderContainer _containerFor(
  _Opened opened, {
  bool treeFails = false,
  bool planFails = false,
}) {
  final container = ProviderContainer(overrides: [
    // The host a link was parsed from says nothing about the host it is
    // written back out as — that one is a build-time define, and pinning it
    // here is what keeps these expectations about URL *shape*.
    linkBaseUrlProvider.overrideWithValue(_base),
    navigationTreeProvider.overrideWith(
      (_) async => treeFails ? throw StateError('no tree') : _appNodes,
    ),
    // No `sharedTreeProvider` override: the plan carries its own tree, so the
    // resolver has one load, not two.
    sitePlanProvider.overrideWith(
      (_) async => planFails ? throw StateError('no plan') : _plan,
    ),
    syncNavigatorToActiveTabProvider.overrideWithValue(() {}),
    openTabFromNodeKeyProvider.overrideWithValue(
      (String nodeKey,
          {bool isPortraitMode = false, int? pageIndex, int? entryStart}) {
        // -1 for a key that names nothing, exactly as the real one answers
        // when `nodeByKeyProvider` comes back null. Recording *after* that
        // check is what lets a test say no tab was ever asked for.
        if (_tree[nodeKey] == null) return -1;
        opened
          ..nodeKey = nodeKey
          ..pageIndex = pageIndex
          ..entryStart = entryStart;
        return 0; // any index >= 0 means a tab opened
      },
    ),
  ]);
  addTearDown(container.dispose);
  return container;
}

/// The smallest corpus carrying both shapes a deep link has to survive.
///
/// ```text
/// dl                    TOC
///   dl-mid              TOC — mixed, so the run starts below the container
///     dl-mid-1            owns its page
///     dl-mid-2            unfolded, and anchors the run below it
///     dl-mid-3            folded onto dl-mid-2
///     dl-mid-4            folded onto dl-mid-2
/// atta-dl               commentary
///   atta-dl-mid         chapter — every child folded, so it carries both
///     atta-dl-mid-1       "1." — answers for dl-mid-1 alone
///     atta-dl-mid-2       "2-4." — answers for dl-mid-2, -3 and -4
/// ```
///
/// The merge is what makes the marker necessary: three suttas walk into
/// `atta-dl-mid-2`, and its key names only the first of them.
final TipitakaTree _tree = TipitakaTree.fromJson({
  'dl': _row(null, 'මූලපණ්ණාසකො'),
  'dl-mid': _row('dl', 'මජ්ඣිමවග්ගො'),
  'dl-mid-1': _row('dl-mid', 'පඨමසුත්තං'),
  'dl-mid-2': _row('dl-mid', 'දුතියසුත්තං'),
  'dl-mid-3': _row('dl-mid', 'තතියසුත්තං'),
  'dl-mid-4': _row('dl-mid', 'චතුත්ථසුත්තං'),
  'atta-dl': _row(null, 'මූලපණ්ණාසක-අට්ඨකථා'),
  'atta-dl-mid': _row('atta-dl', 'මජ්ඣිමවග්ගවණ්ණනා'),
  'atta-dl-mid-1': _row('atta-dl-mid', '1. පඨමසුත්තවණ්ණනා'),
  'atta-dl-mid-2': _row('atta-dl-mid', '2-4. දුතියසුත්තාදිවණ්ණනා'),
});

/// One tree row: `[pali, sinhala, level, [page, entry], parent, file]`, with the
/// title on both language sides — the Pali one is the authority the declared
/// range is read from.
List<Object?> _row(String? parent, String title) =>
    [title, title, 1, const <int>[0, 0], parent ?? 'root', 'f'];

/// Hand-made, never the shipped snapshot: these keys are not in the corpus, and
/// a test reading the real set would measure the corpus instead of the rule.
final SitePlan _plan = SitePlan.build(
  tree: _tree,
  rootKeys: const ['dl', 'atta-dl'],
  foldedLeafKeys: const {
    'dl-mid-3',
    'dl-mid-4',
    'atta-dl-mid-1',
    'atta-dl-mid-2',
  },
  textBearingContainerKeys: const {},
);

/// The same corpus as the app holds it. Only the fallback path reads this —
/// `openTabFromNodeKey` is stubbed — but it has to agree with [_tree], or the
/// fallback tests would pass against a shape the plan tests never saw.
final List<TipitakaTreeNode> _appNodes = [
  _appNode('dl', children: [
    _appNode('dl-mid', children: [
      _appNode('dl-mid-1'),
      _appNode('dl-mid-2'),
      _appNode('dl-mid-3'),
      _appNode('dl-mid-4'),
    ]),
  ]),
  _appNode('atta-dl', children: [
    _appNode('atta-dl-mid', children: [
      _appNode('atta-dl-mid-1'),
      _appNode('atta-dl-mid-2'),
    ]),
  ]),
];

TipitakaTreeNode _appNode(String key,
        {List<TipitakaTreeNode> children = const []}) =>
    TipitakaTreeNode(
      nodeKey: key,
      paliName: key,
      sinhalaName: key,
      hierarchyLevel: 1,
      entryPageIndex: 0,
      entryIndexInPage: 0,
      childNodes: children,
    );
