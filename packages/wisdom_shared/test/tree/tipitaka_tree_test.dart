import 'package:test/test.dart';
import 'package:wisdom_shared/wisdom_shared.dart';

/// Guards the tree decode shared by the Flutter app and the static-site
/// generator.
///
/// Ordering was verified against the app's algorithm across all 2,005 parents
/// of the real `tree.json`. That run needs the vendored asset, so it lives in
/// `static_site_generator/tool/verify_corpus_invariants.dart`; the invariants
/// it proved are pinned here on synthetic fixtures that reproduce each hazard
/// in isolation.
void main() {
  group('sibling ordering', () {
    test('sorts by trailing integer, not lexicographically', () {
      // The bug this prevents: '10' < '9' as strings, so a naive sort puts the
      // tenth sutta second. Rows are deliberately supplied out of order.
      final tree = TipitakaTree.fromJson({
        'an-1': _row(null),
        'an-1-10': _row('an-1'),
        'an-1-2': _row('an-1'),
        'an-1-1': _row('an-1'),
        'an-1-9': _row('an-1'),
      });

      expect(tree['an-1']!.childKeys, [
        'an-1-1',
        'an-1-2',
        'an-1-9',
        'an-1-10',
      ]);
    });

    test('keys with no trailing integer fall back to document order', () {
      // `vp`, `sp`, `ap`, `kn-khp` and every dotted commentary key land here.
      // The app's comparator returns 0 for these and lets List.sort decide,
      // which is unspecified. Document order makes it a guarantee.
      final tree = TipitakaTree.fromJson({
        'root-ish': _row(null),
        'kn-khp': _row('root-ish'),
        'kn-dhp': _row('root-ish'),
        'kn-ud': _row('root-ish'),
      });

      expect(tree['root-ish']!.childKeys, ['kn-khp', 'kn-dhp', 'kn-ud']);
    });

    test('dotted keys are treated as non-integer, not as their prefix', () {
      // `1.1` does not parse as an int, so these must not be reordered as if
      // they were `1`. 53 real commentary keys have this shape.
      final tree = TipitakaTree.fromJson({
        'atta-ap-dhs-2-1': _row(null),
        'atta-ap-dhs-2-1-1.2': _row('atta-ap-dhs-2-1'),
        'atta-ap-dhs-2-1-1.1': _row('atta-ap-dhs-2-1'),
      });

      expect(tree['atta-ap-dhs-2-1']!.childKeys, [
        'atta-ap-dhs-2-1-1.2',
        'atta-ap-dhs-2-1-1.1',
      ]);
    });

    test('mixed integer and non-integer siblings keep document order', () {
      // The comparator can only compare two keys that *both* carry an index,
      // so any pair involving a non-integer key resolves by document order.
      final tree = TipitakaTree.fromJson({
        'p': _row(null),
        'p-3': _row('p'),
        'p-khp': _row('p'),
        'p-1': _row('p'),
      });

      expect(tree['p']!.childKeys, ['p-3', 'p-khp', 'p-1']);
    });

    test('ordering holds past the insertion-sort threshold', () {
      // The load-bearing regression guard. Dart's List.sort is explicitly not
      // stable: it falls back to insertion sort only below 32 elements, and
      // switches to an unstable quicksort at or above it. The app's comparator
      // survives today solely because the 18 parents holding index-less keys
      // top out at 23 children (`atta-ap-vbh-6`).
      //
      // Here 40 index-less siblings are pushed well past that cliff. The
      // explicit document-order tiebreak must still reproduce input order.
      final expected = [for (var i = 0; i < 40; i++) 'c-x$i'];
      final tree = TipitakaTree.fromJson({
        'p': _row(null),
        for (final key in expected) key: _row('p'),
      });

      expect(tree['p']!.childKeys, expected);
    });

    test('roots are ordered by the same rule', () {
      // All seven real roots (`vp`, `sp`, `ap`, `atta-*`, `anya`) lack a
      // trailing integer, so root order is entirely document order.
      final tree = TipitakaTree.fromJson({
        'vp': _row(null),
        'sp': _row(null),
        'ap': _row(null),
        'anya': _row(null),
      });

      expect(tree.rootKeys, ['vp', 'sp', 'ap', 'anya']);
      expect(tree.roots.map((n) => n.nodeKey), ['vp', 'sp', 'ap', 'anya']);
    });

    test('decoding is reproducible', () {
      // §11.8: Cloudflare dedups by content hash, so unstable ordering would
      // re-upload every page on an unchanged corpus.
      Map<String, dynamic> source() => {
            'p': _row(null),
            'p-b': _row('p'),
            'p-a': _row('p'),
            'p-2': _row('p'),
            'p-1': _row('p'),
          };

      expect(
        TipitakaTree.fromJson(source()).allNodes.map((n) => n.childKeys).toList(),
        TipitakaTree.fromJson(source()).allNodes.map((n) => n.childKeys).toList(),
      );
    });
  });

  group('malformed input fails loudly', () {
    test('a parent that does not exist throws rather than stranding a subtree', () {
      // Silently dropping these would delete a whole branch from navigation
      // with no error anywhere.
      expect(
        () => TipitakaTree.fromJson({'orphan': _row('nobody')}),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('nobody'),
        )),
      );
    });

    test('a row with the wrong field count is named', () {
      expect(
        () => TipitakaTree.fromJson({
          'short': ['pali', 'sinh', 1, [0, 0]],
        }),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          allOf(contains('short'), contains('4 fields')),
        )),
      );
    });

    test('a row that is not a list is named', () {
      expect(
        () => TipitakaTree.fromJson({'weird': 'not a row'}),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('weird'),
        )),
      );
    });

    test('a malformed coordinate throws instead of a RangeError', () {
      // Previously `data[3][0]` would throw a bare RangeError naming nothing.
      expect(
        () => TipitakaTree.fromJson({
          'bad': ['pali', 'sinh', 1, [0], 'root', 'f'],
        }),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          allOf(contains('bad'), contains('coordinate')),
        )),
      );
    });
  });

  group('navigation', () {
    final tree = TipitakaTree.fromJson({
      'an-1': _row(null, file: 'an-1'),
      'an-1-1': _row('an-1', file: 'an-1'),
      'an-1-1-1': _row('an-1-1', file: 'an-1', page: 3, entry: 4),
      'an-1-1-2': _row('an-1-1', file: 'an-1'),
      'an-1-2': _row('an-1', file: 'an-1'),
    });

    test('leaves are found depth-first in reading order', () {
      expect(
        tree.leavesUnder('an-1').map((n) => n.nodeKey),
        ['an-1-1-1', 'an-1-1-2', 'an-1-2'],
      );
    });

    test('a leaf returns itself, so callers need no special case', () {
      expect(tree.leavesUnder('an-1-1-1').map((n) => n.nodeKey), ['an-1-1-1']);
    });

    test('ancestors run nearest-first for breadcrumbs', () {
      expect(
        tree.ancestorsOf('an-1-1-1').map((n) => n.nodeKey),
        ['an-1-1', 'an-1'],
      );
    });

    test('one step up is the first ancestor, and null at the top', () {
      expect(tree.parentOf('an-1-1-1')?.nodeKey, 'an-1-1');
      // The root is where `parentOf` and `ancestorsOf(...).first` part company:
      // the chain is empty there, so only one of the two can answer at all.
      expect(tree.ancestorsOf('an-1'), isEmpty);
      expect(tree.parentOf('an-1'), isNull);
    });

    test('unknown keys return empty rather than throwing', () {
      expect(tree['nope'], isNull);
      expect(tree.parentOf('nope'), isNull);
      expect(tree.childrenOf('nope'), isEmpty);
      expect(tree.leavesUnder('nope'), isEmpty);
      expect(tree.ancestorsOf('nope'), isEmpty);
    });

    test('coordinates and content file survive the decode', () {
      final leaf = tree['an-1-1-1']!;
      expect(leaf.entryPageIndex, 3);
      expect(leaf.entryIndexInPage, 4);
      // A node's text routinely lives in an ancestor's file — 10 real
      // containers do this — so contentFileId is not derivable from the key.
      expect(leaf.contentFileId, 'an-1');
      expect(leaf.isLeaf, isTrue);
      expect(tree['an-1']!.isLeaf, isFalse);
    });

    test('allNodes iterates in tree.json document order', () {
      expect(tree.allNodes.map((n) => n.nodeKey), [
        'an-1',
        'an-1-1',
        'an-1-1-1',
        'an-1-1-2',
        'an-1-2',
      ]);
      expect(tree.length, 5);
    });

    test('a parent cycle terminates instead of hanging', () {
      // Each key is visited at most once, and the starting node counts as
      // already seen — so a → b → a stops at ['b'] rather than looping or
      // listing the start node as its own ancestor.
      final cyclic = TipitakaTree.fromJson({
        'a': _row('b'),
        'b': _row('a'),
      });
      expect(cyclic.ancestorsOf('a').map((n) => n.nodeKey), ['b']);
      expect(cyclic.ancestorsOf('b').map((n) => n.nodeKey), ['a']);
    });

    test('isAncestorOf answers what ancestorsOf lists, cycles included', () {
      // Two spellings of one question, so they may not disagree anywhere —
      // including on data that should not exist. Testing the match before the
      // cycle guard passes every well-formed case below and still calls `a` its
      // own ancestor on the last two.
      expect(tree.isAncestorOf('an-1', 'an-1-1-1'), isTrue);
      expect(tree.isAncestorOf('an-1-1', 'an-1-1-1'), isTrue);
      expect(tree.isAncestorOf('an-1-1-1', 'an-1'), isFalse);
      expect(tree.isAncestorOf('an-1-2', 'an-1-1-1'), isFalse);
      expect(tree.isAncestorOf('an-1', 'an-1'), isFalse,
          reason: 'a key is never its own ancestor');
      expect(tree.isAncestorOf('nope', 'an-1-1'), isFalse);
      expect(tree.isAncestorOf('an-1', 'nope'), isFalse);

      final cyclic = TipitakaTree.fromJson({
        'a': _row('b'),
        'b': _row('a'),
        'x': _row('x'),
      });
      expect(cyclic.isAncestorOf('b', 'a'), isTrue);
      expect(cyclic.isAncestorOf('a', 'a'), isFalse);
      expect(cyclic.isAncestorOf('x', 'x'), isFalse);
      for (final key in ['a', 'b', 'x']) {
        expect(cyclic.isAncestorOf(key, key),
            cyclic.ancestorsOf(key).any((n) => n.nodeKey == key),
            reason: 'the two spellings disagree on $key');
      }
    });
  });
}

/// One `tree.json` row: `[pali, sinh, level, [page, entry], parent, fileId]`.
///
/// `null` [parent] becomes the `"root"` sentinel the real data uses.
List<dynamic> _row(
  String? parent, {
  int level = 1,
  String file = 'f',
  int page = 0,
  int entry = 0,
}) =>
    ['pali', 'sinh', level, <int>[page, entry], parent ?? 'root', file];
