import 'package:flutter_test/flutter_test.dart';
import 'package:the_wisdom_project/domain/entities/reader/reader_unit.dart';
import 'package:wisdom_shared/wisdom_shared.dart';

/// [ReaderUnitResolver] is the one place the app answers "what does tapping
/// this show", and nothing else checks it: the static site answers the same
/// question with a *different* rule (`foldedLeafKeys`), so a build diff cannot
/// see the app's version break.
///
/// The rule is the node's own subtree, bounded by its own content file. The
/// three shapes below are where that differs from `SliceIndex` alone — a
/// container, a subtree that crosses a file, and the last node in a file —
/// plus the prev/next walk, which steps on leaves and not on the containers
/// between them.
void main() {
  group('unitFor — the node you tapped, bounded by its own subtree', () {
    test('a leaf ends where the next node begins, container or not', () {
      // bk-1's next coordinate is the vagga bk-2, not another sutta.
      expect(_span('bk-1'), '(0,2)..(1,0)');
    });

    test('a container runs from its preamble through its last descendant', () {
      // SliceIndex alone gives bk-2 only (1,0)..(1,1) — the vagga's title row
      // and nothing else. The reader's unit is the whole subtree, which is why
      // tapping a vagga renders text rather than a list of links.
      expect(_span('bk-2'), '(1,0)..(2,0)');
    });

    test('the last node in a file has no end', () {
      expect(_span('bk-3'), '(2,0)..eof');
    });

    test('a subtree that crosses files stops at its own file', () {
      // bk owns bk-4's subtree too, but that text is in another printed book.
      expect(_span('bk'), '(0,0)..eof');
      expect(_resolver.unitFor('bk')!.contentFileId, 'f1');
    });

    test('a key the tree has never heard of has no unit', () {
      expect(_resolver.unitFor('nope'), isNull);
    });

    test('a node whose text lives nowhere has no unit', () {
      final tree = TipitakaTree.fromJson({
        'x': _row(parent: null, at: [0, 0], file: null),
      });
      expect(ReaderUnitResolver(tree).unitFor('x'), isNull);
    });
  });

  group('leafBefore / leafAfter — the stops are suttas, never a vagga title',
      () {
    test('next steps off the last leaf actually rendered', () {
      // bk-2's unit ended at bk-2-2, so next is the sutta after *that*.
      expect(_resolver.leafAfter('bk-2')?.nodeKey, 'bk-3');
    });

    test('a unit cut short by a file boundary steps off where it stopped', () {
      // bk rendered f1 only, so next is f2's first sutta and not whatever
      // follows the whole book.
      expect(_resolver.leafAfter('bk')?.nodeKey, 'bk-4-1');
    });

    test('previous is the sutta before the unit, not the container above it',
        () {
      expect(_resolver.leafBefore('bk-2')?.nodeKey, 'bk-1');
      expect(_resolver.leafBefore('bk-2-2')?.nodeKey, 'bk-2-1');
    });

    test('null at each end of the corpus', () {
      expect(_resolver.leafBefore('bk'), isNull);
      expect(_resolver.leafBefore('bk-1'), isNull);
      expect(_resolver.leafAfter('bk-4-2'), isNull);
    });
  });

  group('keyAt — which node owns a row', () {
    test('a row inside a node belongs to that node', () {
      expect(_resolver.keyAt('f1', 1, 2), 'bk-2-1');
    });

    test('a vagga title row belongs to the vagga', () {
      expect(_resolver.keyAt('f1', 1, 0), 'bk-2');
    });

    test('a file with no tree node answers nothing rather than guessing', () {
      expect(_resolver.keyAt('f9', 0, 0), isNull);
    });
  });

  group('ReaderUnit equality — a re-resolve must not look like a move', () {
    test('the same key resolves equal', () {
      expect(_resolver.unitFor('bk-2'), _resolver.unitFor('bk-2'));
      expect(
        _resolver.unitFor('bk-2').hashCode,
        _resolver.unitFor('bk-2').hashCode,
      );
    });

    test('the span is part of the identity, not just the key', () {
      // The one comparison a resolver cannot produce on its own: same node,
      // same file, different end. Drop `end` from SliceRange's `==` and these
      // two become equal, so a unit that grew would never reach the panes.
      final unit = _resolver.unitFor('bk-2')!;
      final widened = ReaderUnit(
        node: unit.node,
        contentFileId: unit.contentFileId,
        range: SliceRange(
          nodeKey: unit.range.nodeKey,
          start: unit.range.start,
          end: null,
        ),
      );
      expect(widened, isNot(unit));
    });

    test('two different nodes are two different units', () {
      expect(_resolver.unitFor('bk-2'), isNot(_resolver.unitFor('bk-2-1')));
    });
  });
}

/// ```
/// bk         f1 (0,0)  a book whose subtree crosses into f2
///   bk-1     f1 (0,2)  a sutta that stops at a *container*
///   bk-2     f1 (1,0)  a vagga: one title row, then two suttas
///     bk-2-1 f1 (1,1)
///     bk-2-2 f1 (1,4)
///   bk-3     f1 (2,0)  the last node in f1 — no end
///   bk-4     f2 (0,0)  the next printed book
///     bk-4-1 f2 (0,1)
///     bk-4-2 f2 (0,5)  the last leaf in the corpus
/// ```
final TipitakaTree _tree = TipitakaTree.fromJson({
  'bk': _row(parent: null, at: [0, 0], file: 'f1'),
  'bk-1': _row(parent: 'bk', at: [0, 2], file: 'f1'),
  'bk-2': _row(parent: 'bk', at: [1, 0], file: 'f1'),
  'bk-2-1': _row(parent: 'bk-2', at: [1, 1], file: 'f1'),
  'bk-2-2': _row(parent: 'bk-2', at: [1, 4], file: 'f1'),
  'bk-3': _row(parent: 'bk', at: [2, 0], file: 'f1'),
  'bk-4': _row(parent: 'bk', at: [0, 0], file: 'f2'),
  'bk-4-1': _row(parent: 'bk-4', at: [0, 1], file: 'f2'),
  'bk-4-2': _row(parent: 'bk-4', at: [0, 5], file: 'f2'),
});

final ReaderUnitResolver _resolver = ReaderUnitResolver(_tree);

String _span(String nodeKey) {
  final range = _resolver.unitFor(nodeKey)!.range;
  return '${range.start}..${range.end ?? 'eof'}';
}

/// One `tree.json` row: `[pali, sinhala, level, [page, entry], parent, file]`.
List<dynamic> _row({
  required String? parent,
  required List<int> at,
  required String? file,
}) =>
    ['pali', 'sinhala', 1, at, parent ?? 'root', file];
