import 'package:test/test.dart';
import 'package:wisdom_shared/wisdom_shared.dart';

/// Guards [crossLinkTargetKey], the one rule behind the `අට්ඨකථා` /
/// `මූල පාඨය` link on both surfaces.
///
/// Every case here is a decision that would be invisible if it regressed: the
/// link would still render, still point somewhere, and still look right. What
/// separates a correct answer from a plausible one is whether a vaṇṇanā
/// *claims* the sutta, so the tests that matter most are the ones asserting
/// **no link** — the corpus cannot tell you those are missing.
void main() {
  group('the exact twin key wins, in both directions', () {
    final tree = _tree({
      'bk': (null, 'පොත'),
      'bk-1': ('bk', 'වග්ගො'),
      'bk-1-1': ('bk-1', 'පඨමසුත්තං'),
      'atta-bk': (null, 'අට්ඨකථා'),
      'atta-bk-1': ('atta-bk', 'වග්ගවණ්ණනා'),
      'atta-bk-1-1': ('atta-bk-1', 'පඨමසුත්තවණ්ණනා'),
    });

    test('canon to its vaṇṇanā and back', () {
      expect(crossLinkTargetKey(tree, 'bk-1-1'), 'atta-bk-1-1');
      expect(crossLinkTargetKey(tree, 'atta-bk-1-1'), 'bk-1-1');
    });

    test('a key naming no node gets no link', () {
      expect(crossLinkTargetKey(tree, 'bk-9-9'), isNull);
    });

    test('twinKeyOf flips the prefix without consulting the tree', () {
      expect(twinKeyOf('bk-1-1'), 'atta-bk-1-1');
      expect(twinKeyOf('atta-bk-1-1'), 'bk-1-1');
    });
  });

  group('canon → commentary is strict: only what a vaṇṇanā declares', () {
    test('a declared range reaches the suttas after it, and stops', () {
      // `atta-bk-1-2` is "2-4.", so it treats suttas 2, 3 and 4. Sutta 5 is
      // past its width and the commentary says nothing about it.
      final tree = _tree({
        'bk': (null, 'පොත'),
        'bk-1': ('bk', 'වග්ගො'),
        'bk-1-1': ('bk-1', 'පඨමසුත්තං'),
        'bk-1-2': ('bk-1', 'දුතියසුත්තං'),
        'bk-1-3': ('bk-1', 'තතියසුත්තං'),
        'bk-1-4': ('bk-1', 'චතුත්ථසුත්තං'),
        'bk-1-5': ('bk-1', 'පඤ්චමසුත්තං'),
        'atta-bk': (null, 'අට්ඨකථා'),
        'atta-bk-1': ('atta-bk', 'වග්ගවණ්ණනා'),
        'atta-bk-1-1': ('atta-bk-1', '1. පඨමසුත්තවණ්ණනා'),
        'atta-bk-1-2': ('atta-bk-1', '2-4. දුතියසුත්තාදිවණ්ණනා'),
      });

      expect(crossLinkTargetKey(tree, 'bk-1-3'), 'atta-bk-1-2');
      expect(crossLinkTargetKey(tree, 'bk-1-4'), 'atta-bk-1-2');
      expect(crossLinkTargetKey(tree, 'bk-1-5'), isNull);
    });

    test('the declared numbers are a width, never endpoints', () {
      // The `ap-dhk-2` shape: the node is its container's second child but the
      // book prints it "1-3.", counting from a different origin. Read as
      // endpoints it would cover suttas 1–3 and leave 4 unlinked; read as a
      // width of three it covers 2–4, which is where the text actually is.
      final tree = _tree({
        'bk': (null, 'පොත'),
        'bk-1': ('bk', 'වග්ගො'),
        'bk-1-1': ('bk-1', 'පඨමසුත්තං'),
        'bk-1-2': ('bk-1', 'දුතියසුත්තං'),
        'bk-1-3': ('bk-1', 'තතියසුත්තං'),
        'bk-1-4': ('bk-1', 'චතුත්ථසුත්තං'),
        'atta-bk': (null, 'අට්ඨකථා'),
        'atta-bk-1': ('atta-bk', 'වග්ගවණ්ණනා'),
        'atta-bk-1-2': ('atta-bk-1', '1-3. දුතියසුත්තාදිවණ්ණනා'),
      });

      expect(crossLinkTargetKey(tree, 'bk-1-4'), 'atta-bk-1-2');
    });

    test('a title declaring nothing covers only itself', () {
      // The `an-5-5-5` shape: suttas 2–8 are mechanical variants the vaṇṇanā
      // never glosses, and an unlabelled node must not be read as covering
      // everything after it.
      final tree = _tree({
        'bk': (null, 'පොත'),
        'bk-1': ('bk', 'වග්ගො'),
        'bk-1-1': ('bk-1', 'පඨමසුත්තං'),
        'bk-1-2': ('bk-1', 'දුතියසුත්තං'),
        'atta-bk': (null, 'අට්ඨකථා'),
        'atta-bk-1': ('atta-bk', 'වග්ගවණ්ණනා'),
        'atta-bk-1-1': ('atta-bk-1', 'දුච්චරිතසුත්තවණ්ණනා'),
      });

      expect(crossLinkTargetKey(tree, 'bk-1-2'), isNull);
    });

    test('a reversed range is a typo, not a claim', () {
      final tree = _tree({
        'bk': (null, 'පොත'),
        'bk-1': ('bk', 'වග්ගො'),
        'bk-1-1': ('bk-1', 'පඨමසුත්තං'),
        'bk-1-2': ('bk-1', 'දුතියසුත්තං'),
        'atta-bk': (null, 'අට්ඨකථා'),
        'atta-bk-1': ('atta-bk', 'වග්ගවණ්ණනා'),
        'atta-bk-1-1': ('atta-bk-1', '13-7. පඨමසුත්තවණ්ණනා'),
      });

      expect(crossLinkTargetKey(tree, 'bk-1-2'), isNull);
    });

    test('coverage stops at the nearest preceding vaṇṇanā', () {
      // `atta-bk-1-1` declares nine, but `atta-bk-1-3` sits between it and
      // sutta 4. Reaching *through* a nearer node would mean that node is not
      // where its key puts it, which is a different defect than a merge.
      final tree = _tree({
        'bk': (null, 'පොත'),
        'bk-1': ('bk', 'වග්ගො'),
        'bk-1-1': ('bk-1', 'පඨමසුත්තං'),
        'bk-1-2': ('bk-1', 'දුතියසුත්තං'),
        'bk-1-3': ('bk-1', 'තතියසුත්තං'),
        'bk-1-4': ('bk-1', 'චතුත්ථසුත්තං'),
        'atta-bk': (null, 'අට්ඨකථා'),
        'atta-bk-1': ('atta-bk', 'වග්ගවණ්ණනා'),
        'atta-bk-1-1': ('atta-bk-1', '1-9. පඨමසුත්තාදිවණ්ණනා'),
        'atta-bk-1-3': ('atta-bk-1', 'තතියසුත්තවණ්ණනා'),
      });

      expect(crossLinkTargetKey(tree, 'bk-1-2'), 'atta-bk-1-1');
      expect(crossLinkTargetKey(tree, 'bk-1-4'), isNull);
    });

    test('a container vaṇṇanā is never offered as a sutta commentary', () {
      // The step that exists going the other way and must not exist here: a
      // vagga's commentary is not "the commentary on this sutta", and the
      // reader has no way to check that claim.
      final tree = _tree({
        'bk': (null, 'පොත'),
        'bk-1': ('bk', 'වග්ගො'),
        'bk-1-1': ('bk-1', 'පඨමසුත්තං'),
        'atta-bk': (null, 'අට්ඨකථා'),
        'atta-bk-1': ('atta-bk', 'වග්ගවණ්ණනා'),
      });

      expect(crossLinkTargetKey(tree, 'bk-1-1'), isNull);
    });

    test('a key with no trailing number takes the exact twin or nothing', () {
      // `vp`, `kn-khp` and the dotted commentary keys: no declared range can
      // name a node whose index cannot be read.
      final tree = _tree({
        'bk': (null, 'පොත'),
        'bk-1': ('bk', 'පඨමසුත්තං'),
        'bk-khp': ('bk', 'ඛුද්දකපාඨො'),
        'atta-bk': (null, 'අට්ඨකථා'),
        'atta-bk-1': ('atta-bk', '1-9. පඨමසුත්තාදිවණ්ණනා'),
      });

      expect(crossLinkTargetKey(tree, 'bk-khp'), isNull);
    });
  });

  group('commentary → canon always lands: the canon is complete', () {
    test('a canon key gap is a merge, so the preceding sibling holds it', () {
      // `sn-2-5-4-8` is පිතුසුත්තාදිඡක්කං — six suttas under one key. The
      // vaṇṇanā still has three nodes, and all three have root text there.
      final tree = _tree({
        'bk': (null, 'පොත'),
        'bk-1': ('bk', 'වග්ගො'),
        'bk-1-1': ('bk-1', 'පඨමසුත්තාදිඡක්කං'),
        'atta-bk': (null, 'අට්ඨකථා'),
        'atta-bk-1': ('atta-bk', 'වග්ගවණ්ණනා'),
        'atta-bk-1-1': ('atta-bk-1', 'පඨමවණ්ණනා'),
        'atta-bk-1-2': ('atta-bk-1', 'දුතියවණ්ණනා'),
        'atta-bk-1-3': ('atta-bk-1', 'තතියවණ්ණනා'),
      });

      expect(crossLinkTargetKey(tree, 'atta-bk-1-2'), 'bk-1-1');
      expect(crossLinkTargetKey(tree, 'atta-bk-1-3'), 'bk-1-1');
    });

    test('an ancestor answers where the commentary subdivides deeper', () {
      // `atta-an-1-14-1`'s thera stories sit under one canon node, so no
      // sibling on the commentary side has a twin — the parent does.
      final tree = _tree({
        'bk': (null, 'පොත'),
        'bk-1': ('bk', 'වග්ගො'),
        'bk-1-1': ('bk-1', 'එතදග්ගවග්ගො'),
        'atta-bk': (null, 'අට්ඨකථා'),
        'atta-bk-1': ('atta-bk', 'වග්ගවණ්ණනා'),
        'atta-bk-1-1': ('atta-bk-1', 'එතදග්ගවග්ගවණ්ණනා'),
        'atta-bk-1-1-1': ('atta-bk-1-1', 'පඨමථෙරවත්ථු'),
        'atta-bk-1-1-2': ('atta-bk-1-1', 'දුතියථෙරවත්ථු'),
      });

      expect(crossLinkTargetKey(tree, 'atta-bk-1-1-1'), 'bk-1-1');
    });

    test('a commentary with no canon side anywhere gets no link', () {
      final tree = _tree({
        'atta-solo': (null, 'අනුරූප මූලයක් නැති අට්ඨකථා'),
      });

      expect(crossLinkTargetKey(tree, 'atta-solo'), isNull);
    });
  });

  group('who a vaṇṇanā answers for', () {
    final tree = _tree({
      'bk': (null, 'පොත'),
      'bk-1': ('bk', 'වග්ගො'),
      'bk-1-1': ('bk-1', 'පඨමසුත්තං'),
      'bk-1-2': ('bk-1', 'දුතියසුත්තං'),
      'bk-1-3': ('bk-1', 'තතියසුත්තං'),
      'bk-1-4': ('bk-1', 'චතුත්ථසුත්තං'),
      'atta-bk': (null, 'අට්ඨකථා'),
      'atta-bk-1': ('atta-bk', 'වග්ගවණ්ණනා'),
      'atta-bk-1-1': ('atta-bk-1', '1. පඨමසුත්තවණ්ණනා'),
      'atta-bk-1-2': ('atta-bk-1', '2-3. දුතියසුත්තාදිවණ්ණනා'),
    });

    test('a merged vaṇṇanā names every sutta, in reading order', () {
      expect(canonKeysCoveredBy(tree, 'atta-bk-1-2'), ['bk-1-2', 'bk-1-3']);
    });

    test('an ordinary vaṇṇanā names only its own twin', () {
      // One key means nothing to disambiguate, which is how a caller knows the
      // plain link is right and no marker is needed.
      expect(canonKeysCoveredBy(tree, 'atta-bk-1-1'), ['bk-1-1']);
    });

    test('empty for a canon node and for a sutta nothing claims', () {
      expect(canonKeysCoveredBy(tree, 'bk-1-1'), isEmpty);
      expect(crossLinkTargetKey(tree, 'bk-1-4'), isNull);
    });

    test('the marker id cannot be mistaken for a nodeKey', () {
      // `TipitakaLink` reads a nodeKey-shaped fragment as the node the reader
      // asked for. `via-bk-1-3` would match that shape and open nothing; the
      // underscore is what makes the codec pass it over.
      expect(originId('bk-1-3'), 'via_bk-1-3');
      expect(
        TipitakaLink.tryParse('https://host/tipitaka/atta-bk-1#via_bk-1-3'),
        const TipitakaLink(nodeKey: 'atta-bk-1'),
      );
    });
  });
}

/// A tree from `key: (parentKey, title)`, with the title on both language
/// sides — the Pali one is the authority [crossLinkTargetKey] reads.
///
/// `null` parent becomes the `"root"` sentinel the real `tree.json` uses.
TipitakaTree _tree(Map<String, (String?, String)> rows) =>
    TipitakaTree.fromJson({
      for (final row in rows.entries)
        row.key: [
          row.value.$2,
          row.value.$2,
          1,
          <int>[0, 0],
          row.value.$1 ?? 'root',
          'f',
        ],
    });
