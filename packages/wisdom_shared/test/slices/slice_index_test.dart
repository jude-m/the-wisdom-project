import 'package:test/test.dart';
import 'package:wisdom_shared/wisdom_shared.dart';

/// [SliceIndex] answers the slicing rule in two directions, and only one of
/// them has any other cover.
///
/// *key → range* is what the generator asks on every page it writes, so a
/// whole-corpus build that comes out byte-identical has already exercised it.
/// *row → key* — [SliceIndex.keyAt] — the site never calls. Its callers are the
/// app's: an FTS hit, a `?e=<page>.<entry>` deep link, and following the
/// section a reader has scrolled into. Nothing in a build diff can see it
/// break, and the way it breaks is silent: search finds a line and opens a page
/// that does not contain it.
///
/// Hand-built nodes rather than the vendored corpus — the shapes are what
/// matter, and each is four or five nodes. `plan_corpus.dart` is what asks
/// whether the real tree still has those shapes.
void main() {
  group('rangeFor — the direction the build already covers', () {
    test('a node runs to the next coordinate, whatever kind of node that is',
        () {
      expect(_span(_index, 'bk'), '(0,0)..(0,2)'); // preamble, then its child
      expect(_span(_index, 'bk-1'), '(0,2)..(1,0)'); // across a page break
      expect(_span(_index, 'bk-2'), '(1,0)..(1,4)'); // stops at a *container*
      expect(_span(_index, 'bk-v'), '(1,4)..(1,5)'); // vagga's own preamble
    });

    test('only the last coordinate has no end', () {
      expect(_index.rangeFor('bk-v-1').end, isNull);
      for (final key in const ['bk', 'bk-1', 'bk-2', 'bk-v']) {
        expect(_index.rangeFor(key).end, isNotNull, reason: key);
      }
    });

    test('a key with no text in this file is refused, not guessed', () {
      expect(_index.contains('bk-1'), isTrue);
      expect(_index.contains('elsewhere'), isFalse);
      expect(() => _index.rangeFor('elsewhere'), throwsStateError);
    });
  });

  group('keyAt — the direction nothing else exercises', () {
    test('a row inside a node belongs to that node', () {
      expect(_index.keyAt(0, 2), 'bk-1'); // its own coordinate
      expect(_index.keyAt(0, 3), 'bk-1'); // a row after it
      expect(_index.keyAt(0, 9), 'bk-1'); // last row of the page
      expect(_index.keyAt(1, 0), 'bk-2'); // first row of the next page
    });

    test('a container preamble belongs to the container', () {
      expect(_index.keyAt(0, 0), 'bk');
      expect(_index.keyAt(0, 1), 'bk');
      expect(_index.keyAt(1, 4), 'bk-v');
    });

    test('the last node owns every row to the end of the file', () {
      expect(_index.keyAt(1, 5), 'bk-v-1');
      expect(_index.keyAt(9, 99), 'bk-v-1');
    });

    test('a row above the first coordinate belongs to the first node', () {
      // Real, in a hundred-odd files: rows above the file's first coordinate,
      // book front matter the site renders nowhere. They must still resolve to
      // something rather than crash a reader scrolled onto them.
      final index = SliceIndex.forFile('late', [
        _node('late-1', at: (2, 3), parent: null, children: ['late-2']),
        _node('late-2', at: (2, 6), parent: 'late-1'),
      ]);
      expect(index.keyAt(0, 0), 'late-1');
      expect(index.keyAt(2, 2), 'late-1');
    });

    test('every row resolves to a node whose range contains it', () {
      // The invariant the two directions have to agree on, checked over every
      // addressable row of the fixture rather than the handful named above.
      for (var page = 0; page < 3; page++) {
        for (var entry = 0; entry < 10; entry++) {
          final at = SliceCoordinate(page, entry);
          final range = _index.rangeFor(_index.keyAt(page, entry));
          expect(range.start.compareTo(at), lessThanOrEqualTo(0),
              reason: '$at starts before its owner ${range.nodeKey}');
          expect(range.end == null || range.end!.compareTo(at) > 0, isTrue,
              reason: '$at is past the end of its owner ${range.nodeKey}');
        }
      }
    });
  });

  group('two nodes on one coordinate', () {
    // The corpus's tied coordinates are all one shape: a pitaka root printed
    // under the same heading block as the nikāya root below it — `sp`/`dn` in
    // `dn-1`, `atta-sp`/`atta-dn` in `atta-dn-1`. Both get the same *range*,
    // since the outer one
    // has no preamble the inner one does not also carry — but a row can only
    // have one owner, so keyAt has to pick.
    List<TipitakaNode> pair() => [
          _node('sp', at: (0, 0), parent: null, children: ['dn']),
          _node('dn', at: (0, 0), parent: 'sp', children: ['dn-1-1']),
          _node('dn-1-1', at: (0, 4), parent: 'dn'),
        ];

    test('they share a range', () {
      final index = SliceIndex.forFile('dn-1', pair());
      expect(_span(index, 'sp'), '(0,0)..(0,4)');
      expect(_span(index, 'dn'), '(0,0)..(0,4)');
    });

    test('the deeper one owns the rows', () {
      expect(SliceIndex.forFile('dn-1', pair()).keyAt(0, 1), 'dn');
    });

    test('and does so however the tie was ordered', () {
      // The tie is broken on the parent chain, not on the order the pair
      // arrived in — which is the whole reason it survives a change to how
      // nodesByFile sorts.
      final nodes = pair();
      final swapped = [nodes[1], nodes[0], nodes[2]];
      expect(SliceIndex.forFile('dn-1', swapped).keyAt(0, 1), 'dn');
    });
  });

  group('forFile refuses input it cannot slice', () {
    test('nodes out of reading order throw rather than mis-slice', () {
      expect(
        () => SliceIndex.forFile('bad', [
          _node('bad-2', at: (1, 0), parent: null),
          _node('bad-1', at: (0, 0), parent: null),
        ]),
        throwsArgumentError,
      );
    });

    test('a file no node claims throws', () {
      expect(() => SliceIndex.forFile('empty', const []), throwsArgumentError);
    });
  });

  group('nodesByFile', () {
    final tree = TipitakaTree.fromJson({
      'bk': _row(null, at: [0, 0], file: 'bk-1'),
      'bk-1': _row('bk', at: [0, 2], file: 'bk-1'),
      'bk-2': _row('bk', at: [1, 0], file: 'bk-1'),
      'bk-3': _row('bk', at: [0, 0], file: 'bk-2'),
      'bk-4': _row('bk', at: [0, 0], file: null),
    });

    test('groups by content file and sorts into reading order', () {
      expect(
        {
          for (final e in SliceIndex.nodesByFile(tree).entries)
            e.key: e.value.map((n) => n.nodeKey).toList(),
        },
        {
          'bk-1': ['bk', 'bk-1', 'bk-2'],
          'bk-2': ['bk-3'],
        },
      );
    });

    test('a node with no content file is absent — it has no text to slice', () {
      expect(
        SliceIndex.nodesByFile(tree).values.expand((n) => n).map((n) => n.nodeKey),
        isNot(contains('bk-4')),
      );
    });

    test('forTree builds one index per content file', () {
      final byFile = SliceIndex.forTree(tree);
      expect(byFile.keys, unorderedEquals(['bk-1', 'bk-2']));
      expect(byFile['bk-1']!.keyAt(0, 3), 'bk-1');
      expect(byFile['bk-2']!.fileId, 'bk-2');
    });
  });
}

/// ```text
/// bk        (0,0)   two rows of book/pitaka heading, then its first child
///   bk-1    (0,2)   runs to the end of page 0 and stops on a page break
///   bk-2    (1,0)   stops at a *container*, not at the next leaf
///   bk-v    (1,4)   a vagga: one row of its own, then its child
///     bk-v-1 (1,5)  last node in the file — no end
/// ```
final SliceIndex _index = SliceIndex.forFile('bk-1', [
  _node('bk', at: (0, 0), parent: null, children: ['bk-1', 'bk-2', 'bk-v']),
  _node('bk-1', at: (0, 2), parent: 'bk'),
  _node('bk-2', at: (1, 0), parent: 'bk'),
  _node('bk-v', at: (1, 4), parent: 'bk', children: ['bk-v-1']),
  _node('bk-v-1', at: (1, 5), parent: 'bk-v'),
]);

String _span(SliceIndex index, String key) {
  final range = index.rangeFor(key);
  return '${range.start}..${range.end}';
}

TipitakaNode _node(String key,
        {required (int, int) at,
        required String? parent,
        List<String> children = const []}) =>
    TipitakaNode(
      nodeKey: key,
      paliName: key,
      sinhalaName: key,
      hierarchyLevel: 1,
      entryPageIndex: at.$1,
      entryIndexInPage: at.$2,
      parentNodeKey: parent,
      contentFileId: 'bk-1',
      childKeys: children,
    );

/// One `tree.json` row: `[pali, sinh, level, [page, entry], parent, fileId]`.
List<dynamic> _row(String? parent,
        {required List<int> at, required String? file}) =>
    [parent ?? 'x', parent ?? 'x', 1, at, parent ?? 'root', file];
