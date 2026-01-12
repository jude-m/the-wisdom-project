import 'package:flutter_test/flutter_test.dart';
import 'package:the_wisdom_project/core/constants/constants.dart';
import 'package:the_wisdom_project/domain/entities/navigation/tipitaka_tree_node.dart';
import 'package:the_wisdom_project/domain/entities/search/scope_operations.dart';

// =============================================================================
// TEST FIXTURES - Mock Tree Nodes
// =============================================================================

/// Creates a mock TipitakaTreeNode for testing.
///
/// This helper creates nodes with the minimal required fields.
/// Use [childNodes] to build hierarchical structures.
TipitakaTreeNode createMockNode({
  required String nodeKey,
  String? parentNodeKey,
  List<TipitakaTreeNode> childNodes = const [],
  String paliName = '',
  String sinhalaName = '',
  int hierarchyLevel = 0,
}) {
  return TipitakaTreeNode(
    nodeKey: nodeKey,
    parentNodeKey: parentNodeKey,
    childNodes: childNodes,
    paliName: paliName.isEmpty ? nodeKey : paliName,
    sinhalaName: sinhalaName.isEmpty ? nodeKey : sinhalaName,
    hierarchyLevel: hierarchyLevel,
    entryPageIndex: 0,
    entryIndexInPage: 0,
  );
}

/// Builds a mock Sutta Pitaka tree structure for testing.
///
/// Structure:
/// ```
/// sp (Sutta Pitaka)
/// ├── dn (Digha Nikaya)
/// │   ├── dn-1 (Silakkhandhavagga)
/// │   └── dn-2 (Mahavagga)
/// ├── mn (Majjhima Nikaya)
/// ├── sn (Samyutta Nikaya)
/// ├── an (Anguttara Nikaya)
/// └── kn (Khuddaka Nikaya)
/// ```
TipitakaTreeNode buildMockSuttaPitaka() {
  // Level 2: Vaggas under Digha Nikaya
  final dn1 = createMockNode(
    nodeKey: 'dn-1',
    parentNodeKey: TipitakaNodeKeys.dighaNikaya,
    hierarchyLevel: 2,
    paliName: 'Silakkhandhavagga',
  );
  final dn2 = createMockNode(
    nodeKey: 'dn-2',
    parentNodeKey: TipitakaNodeKeys.dighaNikaya,
    hierarchyLevel: 2,
    paliName: 'Mahavagga',
  );

  // Level 1: Nikayas under Sutta Pitaka
  final dn = createMockNode(
    nodeKey: TipitakaNodeKeys.dighaNikaya,
    parentNodeKey: TipitakaNodeKeys.suttaPitaka,
    childNodes: [dn1, dn2],
    hierarchyLevel: 1,
    paliName: 'Digha Nikaya',
  );
  final mn = createMockNode(
    nodeKey: TipitakaNodeKeys.majjhimaNikaya,
    parentNodeKey: TipitakaNodeKeys.suttaPitaka,
    hierarchyLevel: 1,
    paliName: 'Majjhima Nikaya',
  );
  final sn = createMockNode(
    nodeKey: TipitakaNodeKeys.samyuttaNikaya,
    parentNodeKey: TipitakaNodeKeys.suttaPitaka,
    hierarchyLevel: 1,
    paliName: 'Samyutta Nikaya',
  );
  final an = createMockNode(
    nodeKey: TipitakaNodeKeys.anguttaraNikaya,
    parentNodeKey: TipitakaNodeKeys.suttaPitaka,
    hierarchyLevel: 1,
    paliName: 'Anguttara Nikaya',
  );
  final kn = createMockNode(
    nodeKey: TipitakaNodeKeys.khuddakaNikaya,
    parentNodeKey: TipitakaNodeKeys.suttaPitaka,
    hierarchyLevel: 1,
    paliName: 'Khuddaka Nikaya',
  );

  // Level 0: Sutta Pitaka root
  return createMockNode(
    nodeKey: TipitakaNodeKeys.suttaPitaka,
    childNodes: [dn, mn, sn, an, kn],
    hierarchyLevel: 0,
    paliName: 'Sutta Pitaka',
  );
}

/// Builds mock tree roots (all pitakas) for testing collapse behavior.
List<TipitakaTreeNode> buildMockTreeRoots() {
  return [
    buildMockSuttaPitaka(),
    createMockNode(
      nodeKey: TipitakaNodeKeys.vinayaPitaka,
      paliName: 'Vinaya Pitaka',
    ),
    createMockNode(
      nodeKey: TipitakaNodeKeys.abhidhammaPitaka,
      paliName: 'Abhidhamma Pitaka',
    ),
  ];
}

void main() {
  group('ScopeOperations -', () {
    // =========================================================================
    // PATTERN CONFIGURATION
    // =========================================================================

    group('getPatternsForScope', () {
      test('returns empty list when scope set is empty', () {
        final patterns = ScopeOperations.getPatternsForScope({});
        expect(patterns, isEmpty);
      });

      test('returns correct patterns for sutta pitaka (sp)', () {
        final patterns = ScopeOperations.getPatternsForScope(
            {TipitakaNodeKeys.suttaPitaka});
        expect(patterns, equals(['dn-', 'mn-', 'sn-', 'an-', 'kn-']));
      });

      test('combines patterns for multiple node keys', () {
        final patterns = ScopeOperations.getPatternsForScope({
          TipitakaNodeKeys.suttaPitaka,
          TipitakaNodeKeys.vinayaPitaka,
        });
        expect(
            patterns, containsAll(['dn-', 'mn-', 'sn-', 'an-', 'kn-', 'vp-']));
        expect(patterns.length, equals(6)); // 5 sutta + 1 vinaya
      });

      test('returns single pattern for specific nikaya', () {
        final patterns = ScopeOperations.getPatternsForScope(
            {TipitakaNodeKeys.dighaNikaya, TipitakaNodeKeys.majjhimaNikaya});
        expect(patterns, equals(['dn-', 'mn-']));
      });

      test('returns pattern for sub-node key', () {
        final patterns = ScopeOperations.getPatternsForScope({'dn-1'});
        expect(patterns, equals(['dn-1-']));
      });

      test('expands atta-sp to commentary patterns', () {
        final patterns = ScopeOperations.getPatternsForScope(
            {TipitakaNodeKeys.suttaAtthakatha});
        expect(
            patterns,
            equals(
                ['atta-dn-', 'atta-mn-', 'atta-sn-', 'atta-an-', 'atta-kn-']));
      });
    });

    group('getPatternsForNodeKey', () {
      test('expands sp to nikaya patterns', () {
        final patterns = ScopeOperations.getPatternsForNodeKey(
            TipitakaNodeKeys.suttaPitaka);
        expect(patterns, equals(['dn-', 'mn-', 'sn-', 'an-', 'kn-']));
      });

      test('returns direct pattern for vp', () {
        final patterns = ScopeOperations.getPatternsForNodeKey(
            TipitakaNodeKeys.vinayaPitaka);
        expect(patterns, equals(['vp-']));
      });

      test('returns direct pattern for ap', () {
        final patterns = ScopeOperations.getPatternsForNodeKey(
            TipitakaNodeKeys.abhidhammaPitaka);
        expect(patterns, equals(['ap-']));
      });

      test('returns direct pattern for anya', () {
        final patterns =
            ScopeOperations.getPatternsForNodeKey(TipitakaNodeKeys.treatises);
        expect(patterns, equals(['anya-']));
      });

      test('returns pattern for specific node like dn', () {
        final patterns = ScopeOperations.getPatternsForNodeKey(
            TipitakaNodeKeys.dighaNikaya);
        expect(patterns, equals(['dn-']));
      });
    });

    // =========================================================================
    // HIERARCHY NAVIGATION
    // =========================================================================

    group('isNodeCoveredBy', () {
      test('returns true when child is covered by ancestor', () {
        // dn is covered by sp (Sutta Pitaka)
        expect(
          ScopeOperations.isNodeCoveredBy(
              TipitakaNodeKeys.dighaNikaya, TipitakaNodeKeys.suttaPitaka),
          isTrue,
        );
      });

      test('returns true when node covers itself', () {
        expect(
          ScopeOperations.isNodeCoveredBy(
              TipitakaNodeKeys.suttaPitaka, TipitakaNodeKeys.suttaPitaka),
          isTrue,
        );
      });

      test('returns false when nodes are siblings', () {
        // mn is not covered by dn (they are siblings)
        expect(
          ScopeOperations.isNodeCoveredBy(
              TipitakaNodeKeys.majjhimaNikaya, TipitakaNodeKeys.dighaNikaya),
          isFalse,
        );
      });

      test('returns true for nested sub-nodes', () {
        // dn-1 is covered by dn
        expect(
          ScopeOperations.isNodeCoveredBy('dn-1', TipitakaNodeKeys.dighaNikaya),
          isTrue,
        );
        // dn-1 is also covered by sp
        expect(
          ScopeOperations.isNodeCoveredBy('dn-1', TipitakaNodeKeys.suttaPitaka),
          isTrue,
        );
      });

      test('returns true for commentary hierarchy', () {
        // atta-dn should be covered by atta-sp (Sutta Commentary)
        expect(
          ScopeOperations.isNodeCoveredBy(
              'atta-dn', TipitakaNodeKeys.suttaAtthakatha),
          isTrue,
        );
        // atta-mn-1 should also be covered by atta-sp
        expect(
          ScopeOperations.isNodeCoveredBy(
              'atta-mn-1', TipitakaNodeKeys.suttaAtthakatha),
          isTrue,
        );
      });

      test('returns false for cross-pitaka commentary coverage', () {
        // atta-dn (Sutta commentary) is NOT covered by atta-vp (Vinaya commentary)
        expect(
          ScopeOperations.isNodeCoveredBy(
              'atta-dn', TipitakaNodeKeys.vinayaAtthakatha),
          isFalse,
        );
      });
    });

    group('findCoveringAncestors', () {
      test('finds ancestor that covers node', () {
        final ancestors = ScopeOperations.findCoveringAncestors(
          TipitakaNodeKeys.dighaNikaya,
          {
            TipitakaNodeKeys.suttaPitaka,
            TipitakaNodeKeys.vinayaPitaka,
            TipitakaNodeKeys.abhidhammaPitaka
          },
        );
        expect(ancestors, equals({TipitakaNodeKeys.suttaPitaka}));
      });

      test('returns empty when no ancestors cover node', () {
        final ancestors = ScopeOperations.findCoveringAncestors(
          TipitakaNodeKeys.vinayaPitaka,
          {TipitakaNodeKeys.suttaPitaka, TipitakaNodeKeys.abhidhammaPitaka},
        );
        expect(ancestors, isEmpty);
      });

      test('finds multiple covering ancestors for deep node', () {
        final ancestors = ScopeOperations.findCoveringAncestors(
          'dn-1',
          {TipitakaNodeKeys.suttaPitaka, TipitakaNodeKeys.dighaNikaya},
        );
        // Both sp and dn cover dn-1
        expect(ancestors,
            containsAll([TipitakaNodeKeys.suttaPitaka, TipitakaNodeKeys.dighaNikaya]));
      });
    });

    // =========================================================================
    // CHIP OPERATIONS
    // =========================================================================

    group('getAllChipNodeKeys', () {
      test('returns all node keys from predefined chip groups', () {
        final allKeys = ScopeOperations.getAllChipNodeKeys();

        // 7 keys: sp, vp, ap, atta-vp, atta-sp, atta-ap, anya
        expect(
          allKeys,
          containsAll([
            TipitakaNodeKeys.suttaPitaka,
            TipitakaNodeKeys.vinayaPitaka,
            TipitakaNodeKeys.abhidhammaPitaka,
            TipitakaNodeKeys.treatises,
          ]),
        );
        expect(
          allKeys,
          containsAll([
            TipitakaNodeKeys.vinayaAtthakatha,
            TipitakaNodeKeys.suttaAtthakatha,
            TipitakaNodeKeys.abhidhammaAtthakatha,
          ]),
        );
        expect(allKeys.length, equals(7));
      });
    });

    group('isAllSelected', () {
      test('returns true for empty scope', () {
        expect(ScopeOperations.isAllSelected({}), isTrue);
      });

      test('returns false for non-empty scope', () {
        expect(
          ScopeOperations.isAllSelected({TipitakaNodeKeys.suttaPitaka}),
          isFalse,
        );
      });
    });

    group('isChipSelectionOnly', () {
      test('returns true for empty scope', () {
        expect(ScopeOperations.isChipSelectionOnly({}), isTrue);
      });

      test('returns true when scope matches single chip', () {
        expect(
          ScopeOperations.isChipSelectionOnly({TipitakaNodeKeys.suttaPitaka}),
          isTrue,
        );
        expect(
          ScopeOperations.isChipSelectionOnly({TipitakaNodeKeys.vinayaPitaka}),
          isTrue,
        );
      });

      test('returns true when scope matches multiple chips', () {
        expect(
          ScopeOperations.isChipSelectionOnly({
            TipitakaNodeKeys.suttaPitaka,
            TipitakaNodeKeys.vinayaPitaka,
          }),
          isTrue,
        );
      });

      test('returns true for commentaries chip (multi-key)', () {
        expect(
          ScopeOperations.isChipSelectionOnly(TipitakaNodeKeys.commentaries),
          isTrue,
        );
      });

      test('returns false when scope contains sub-node keys', () {
        // 'dn' is a sub-node of sp, not a chip's nodeKey
        expect(
          ScopeOperations.isChipSelectionOnly({TipitakaNodeKeys.dighaNikaya}),
          isFalse,
        );
        expect(
          ScopeOperations.isChipSelectionOnly({
            TipitakaNodeKeys.dighaNikaya,
            TipitakaNodeKeys.majjhimaNikaya,
          }),
          isFalse,
        );
      });
    });

    group('hasCustomSelections', () {
      test('returns false for chip-only selections', () {
        expect(ScopeOperations.hasCustomSelections({}), isFalse);
        expect(
          ScopeOperations.hasCustomSelections({
            TipitakaNodeKeys.suttaPitaka,
            TipitakaNodeKeys.vinayaPitaka,
          }),
          isFalse,
        );
      });

      test('returns true for sub-node selections', () {
        expect(
          ScopeOperations.hasCustomSelections({TipitakaNodeKeys.dighaNikaya}),
          isTrue,
        );
      });
    });

    group('normalize', () {
      test('returns empty scope unchanged', () {
        expect(ScopeOperations.normalize({}), isEmpty);
      });

      test('collapses to empty when all chip keys selected', () {
        // All 7 chip node keys
        expect(ScopeOperations.normalize(TipitakaNodeKeys.allRoots), isEmpty);
      });

      test('preserves partial selections', () {
        final partial = {
          TipitakaNodeKeys.suttaPitaka,
          TipitakaNodeKeys.vinayaPitaka,
        };
        expect(ScopeOperations.normalize(partial), equals(partial));
      });
    });

    // =========================================================================
    // KEY OPERATIONS
    // =========================================================================

    group('toggleKeys', () {
      test('adds keys when not present', () {
        final result = ScopeOperations.toggleKeys(
          {},
          {TipitakaNodeKeys.suttaPitaka},
        );
        expect(result, equals({TipitakaNodeKeys.suttaPitaka}));
      });

      test('removes keys when all are present', () {
        final result = ScopeOperations.toggleKeys(
          {TipitakaNodeKeys.suttaPitaka},
          {TipitakaNodeKeys.suttaPitaka},
        );
        expect(result, isEmpty);
      });

      test('adds keys when only some are present', () {
        final result = ScopeOperations.toggleKeys(
          {TipitakaNodeKeys.suttaPitaka},
          {TipitakaNodeKeys.suttaPitaka, TipitakaNodeKeys.vinayaPitaka},
        );
        // Should add vp since not all keys were present
        expect(result,
            containsAll([TipitakaNodeKeys.suttaPitaka, TipitakaNodeKeys.vinayaPitaka]));
      });

      test('removes covered children when adding parent', () {
        // Start with dn (child), add sp (parent) - should remove dn
        final result = ScopeOperations.toggleKeys(
          {TipitakaNodeKeys.dighaNikaya},
          {TipitakaNodeKeys.suttaPitaka},
        );
        expect(result, equals({TipitakaNodeKeys.suttaPitaka}));
        expect(result.contains(TipitakaNodeKeys.dighaNikaya), isFalse);
      });

      test('keeps non-covered children when adding unrelated parent', () {
        // mn (Sutta child) + vp (Vinaya) - vp doesn't cover mn
        final result = ScopeOperations.toggleKeys(
          {TipitakaNodeKeys.majjhimaNikaya},
          {TipitakaNodeKeys.vinayaPitaka},
        );
        expect(
          result,
          equals({
            TipitakaNodeKeys.majjhimaNikaya,
            TipitakaNodeKeys.vinayaPitaka,
          }),
        );
      });

      test('removes only covered children in mixed scope', () {
        // mn + vp, add sp → should remove mn (covered by sp), keep vp
        final result = ScopeOperations.toggleKeys(
          {TipitakaNodeKeys.majjhimaNikaya, TipitakaNodeKeys.vinayaPitaka},
          {TipitakaNodeKeys.suttaPitaka},
        );
        expect(
          result,
          equals({
            TipitakaNodeKeys.suttaPitaka,
            TipitakaNodeKeys.vinayaPitaka,
          }),
        );
        expect(result.contains(TipitakaNodeKeys.majjhimaNikaya), isFalse);
      });

      test('removes multiple covered children when adding parent', () {
        // dn + mn (both Sutta children), add sp → both removed
        final result = ScopeOperations.toggleKeys(
          {TipitakaNodeKeys.dighaNikaya, TipitakaNodeKeys.majjhimaNikaya},
          {TipitakaNodeKeys.suttaPitaka},
        );
        expect(result, equals({TipitakaNodeKeys.suttaPitaka}));
      });

      test('removes deeply nested children when adding ancestor', () {
        // dn-1 (grandchild of sp), add sp → removed
        final result = ScopeOperations.toggleKeys(
          {'dn-1'},
          {TipitakaNodeKeys.suttaPitaka},
        );
        expect(result, equals({TipitakaNodeKeys.suttaPitaka}));
      });

      test('hasCustomSelections returns false after parent covers children', () {
        // Simulates: refine dialog selects mn, then user clicks Sutta chip
        final afterRefine = {TipitakaNodeKeys.majjhimaNikaya};
        expect(ScopeOperations.hasCustomSelections(afterRefine), isTrue);

        final afterChip = ScopeOperations.toggleKeys(
          afterRefine,
          {TipitakaNodeKeys.suttaPitaka},
        );
        // After clicking Sutta chip, scope is {'sp'} which is chip-only
        expect(ScopeOperations.hasCustomSelections(afterChip), isFalse);
      });

      test('auto-normalizes when all chips selected', () {
        // Adding the last chip should collapse to "All"
        final result = ScopeOperations.toggleKeys(
          {
            TipitakaNodeKeys.suttaPitaka,
            TipitakaNodeKeys.vinayaPitaka,
            TipitakaNodeKeys.abhidhammaPitaka,
            TipitakaNodeKeys.vinayaAtthakatha,
            TipitakaNodeKeys.suttaAtthakatha,
            TipitakaNodeKeys.abhidhammaAtthakatha,
          },
          {TipitakaNodeKeys.treatises},
        );
        expect(result, isEmpty); // Normalized to "All"
      });
    });

    group('containsAllKeys', () {
      test('returns false for empty scope', () {
        expect(
          ScopeOperations.containsAllKeys({}, {TipitakaNodeKeys.suttaPitaka}),
          isFalse,
        );
      });

      test('returns true when all keys present', () {
        expect(
          ScopeOperations.containsAllKeys(
            {TipitakaNodeKeys.suttaPitaka, TipitakaNodeKeys.vinayaPitaka},
            {TipitakaNodeKeys.suttaPitaka},
          ),
          isTrue,
        );
      });

      test('returns false when some keys missing', () {
        expect(
          ScopeOperations.containsAllKeys(
            {TipitakaNodeKeys.suttaPitaka},
            {TipitakaNodeKeys.suttaPitaka, TipitakaNodeKeys.vinayaPitaka},
          ),
          isFalse,
        );
      });
    });

    // =========================================================================
    // CONSTANTS
    // =========================================================================

    group('chipKeyGroups', () {
      test('has 5 chip groups', () {
        expect(ScopeOperations.chipKeyGroups.length, equals(5));
      });

      test('commentaries group has 3 keys', () {
        final commentariesGroup = ScopeOperations.chipKeyGroups
            .firstWhere((g) => g.contains(TipitakaNodeKeys.suttaAtthakatha));
        expect(commentariesGroup.length, equals(3));
      });

      test('all chip groups combined equals allRoots', () {
        final allFromGroups =
            ScopeOperations.chipKeyGroups.expand((g) => g).toSet();
        expect(allFromGroups, equals(TipitakaNodeKeys.allRoots));
      });
    });

    // =========================================================================
    // TREE OPERATIONS
    // =========================================================================

    group('Tree Operations', () {
      late TipitakaTreeNode suttaPitaka;
      late TipitakaTreeNode dighaNikaya;
      late List<TipitakaTreeNode> treeRoots;

      setUp(() {
        suttaPitaka = buildMockSuttaPitaka();
        dighaNikaya = suttaPitaka.findDescendantByKey(TipitakaNodeKeys.dighaNikaya)!;
        treeRoots = buildMockTreeRoots();
      });

      group('hasSelectedDescendant', () {
        test('returns true when direct child is selected', () {
          final scope = {TipitakaNodeKeys.dighaNikaya};
          expect(
            ScopeOperations.hasSelectedDescendant(suttaPitaka, scope),
            isTrue,
          );
        });

        test('returns true when nested descendant is selected', () {
          // dn-1 is a grandchild of suttaPitaka
          final scope = {'dn-1'};
          expect(
            ScopeOperations.hasSelectedDescendant(suttaPitaka, scope),
            isTrue,
          );
        });

        test('returns false when no descendants selected', () {
          // vp is not a descendant of suttaPitaka
          final scope = {TipitakaNodeKeys.vinayaPitaka};
          expect(
            ScopeOperations.hasSelectedDescendant(suttaPitaka, scope),
            isFalse,
          );
        });

        test('returns false for empty scope', () {
          expect(
            ScopeOperations.hasSelectedDescendant(suttaPitaka, {}),
            isFalse,
          );
        });

        test('returns false when only the node itself is selected', () {
          // The node itself is not a descendant of itself
          final scope = {TipitakaNodeKeys.suttaPitaka};
          expect(
            ScopeOperations.hasSelectedDescendant(suttaPitaka, scope),
            isFalse,
          );
        });
      });

      group('removeDescendantsFromScope', () {
        test('removes all descendant keys from scope', () {
          final scope = {
            TipitakaNodeKeys.suttaPitaka,
            TipitakaNodeKeys.dighaNikaya,
            'dn-1',
            'dn-2',
            TipitakaNodeKeys.majjhimaNikaya,
          };
          final result = ScopeOperations.removeDescendantsFromScope(
            suttaPitaka,
            scope,
          );
          // Should only keep sp (the node itself is not removed)
          expect(result, equals({TipitakaNodeKeys.suttaPitaka}));
        });

        test('preserves non-descendant keys', () {
          final scope = {
            TipitakaNodeKeys.dighaNikaya,
            TipitakaNodeKeys.vinayaPitaka, // Not a descendant of sp
          };
          final result = ScopeOperations.removeDescendantsFromScope(
            suttaPitaka,
            scope,
          );
          expect(result, equals({TipitakaNodeKeys.vinayaPitaka}));
        });

        test('returns unchanged scope when no descendants present', () {
          final scope = {TipitakaNodeKeys.vinayaPitaka};
          final result = ScopeOperations.removeDescendantsFromScope(
            suttaPitaka,
            scope,
          );
          expect(result, equals(scope));
        });
      });

      group('collapseChildrenToParent', () {
        test('collapses children to parent when all direct children selected',
            () {
          // All 5 nikayas selected
          final scope = {
            TipitakaNodeKeys.dighaNikaya,
            TipitakaNodeKeys.majjhimaNikaya,
            TipitakaNodeKeys.samyuttaNikaya,
            TipitakaNodeKeys.anguttaraNikaya,
            TipitakaNodeKeys.khuddakaNikaya,
          };
          final result = ScopeOperations.collapseChildrenToParent(
            suttaPitaka,
            scope,
          );
          expect(result, equals({TipitakaNodeKeys.suttaPitaka}));
        });

        test('returns unchanged scope when not all children selected', () {
          // Only 4 of 5 nikayas selected
          final scope = {
            TipitakaNodeKeys.dighaNikaya,
            TipitakaNodeKeys.majjhimaNikaya,
            TipitakaNodeKeys.samyuttaNikaya,
            TipitakaNodeKeys.anguttaraNikaya,
            // Missing kn
          };
          final result = ScopeOperations.collapseChildrenToParent(
            suttaPitaka,
            scope,
          );
          expect(result, equals(scope)); // Unchanged
        });

        test('returns unchanged scope when parent has no children', () {
          final leafNode = createMockNode(nodeKey: 'leaf');
          final scope = {'some-key'};
          final result = ScopeOperations.collapseChildrenToParent(
            leafNode,
            scope,
          );
          expect(result, equals(scope));
        });

        test('collapses at vagga level (dn-1, dn-2 -> dn)', () {
          // All vaggas under dn selected
          final scope = {'dn-1', 'dn-2'};
          final result = ScopeOperations.collapseChildrenToParent(
            dighaNikaya,
            scope,
          );
          expect(result, equals({TipitakaNodeKeys.dighaNikaya}));
        });
      });

      group('toggleNodeSelection', () {
        test('selects single node from "All" state', () {
          final result = ScopeOperations.toggleNodeSelection(
            suttaPitaka,
            {}, // "All" = empty scope
          );
          expect(result, equals({TipitakaNodeKeys.suttaPitaka}));
        });

        test('deselects node when it is selected', () {
          final result = ScopeOperations.toggleNodeSelection(
            suttaPitaka,
            {TipitakaNodeKeys.suttaPitaka},
          );
          expect(result, isEmpty);
        });

        test('deselects node and removes descendants', () {
          final scope = {
            TipitakaNodeKeys.suttaPitaka,
            TipitakaNodeKeys.dighaNikaya, // descendant
          };
          final result = ScopeOperations.toggleNodeSelection(
            suttaPitaka,
            scope,
          );
          // Deselecting sp should also remove dn
          expect(result, isEmpty);
        });

        test('removes covering ancestor when selecting child (narrow down)', () {
          // sp is selected, user clicks dn to narrow down
          final result = ScopeOperations.toggleNodeSelection(
            dighaNikaya,
            {TipitakaNodeKeys.suttaPitaka},
          );
          // Should remove sp and select only dn
          expect(result, equals({TipitakaNodeKeys.dighaNikaya}));
        });

        test('selects node and removes selected descendants', () {
          // dn-1 is selected, user clicks dn (parent)
          final result = ScopeOperations.toggleNodeSelection(
            dighaNikaya,
            {'dn-1'},
          );
          // Should select dn and remove dn-1
          expect(result, equals({TipitakaNodeKeys.dighaNikaya}));
        });

        test('auto-collapses to parent when last sibling selected (with treeRoots)',
            () {
          // 4 nikayas selected, user clicks the 5th (kn)
          final kn = suttaPitaka.findDescendantByKey(TipitakaNodeKeys.khuddakaNikaya)!;
          final scope = {
            TipitakaNodeKeys.dighaNikaya,
            TipitakaNodeKeys.majjhimaNikaya,
            TipitakaNodeKeys.samyuttaNikaya,
            TipitakaNodeKeys.anguttaraNikaya,
          };
          final result = ScopeOperations.toggleNodeSelection(
            kn,
            scope,
            treeRoots: treeRoots,
          );
          // Should collapse all 5 nikayas to sp
          expect(result, equals({TipitakaNodeKeys.suttaPitaka}));
        });

        test('does not collapse without treeRoots parameter', () {
          // Same scenario but without treeRoots
          final kn = suttaPitaka.findDescendantByKey(TipitakaNodeKeys.khuddakaNikaya)!;
          final scope = {
            TipitakaNodeKeys.dighaNikaya,
            TipitakaNodeKeys.majjhimaNikaya,
            TipitakaNodeKeys.samyuttaNikaya,
            TipitakaNodeKeys.anguttaraNikaya,
          };
          final result = ScopeOperations.toggleNodeSelection(
            kn,
            scope,
            // No treeRoots
          );
          // Should have all 5 nikayas (no collapse)
          expect(result.length, equals(5));
          expect(result, contains(TipitakaNodeKeys.khuddakaNikaya));
        });

        test('cascades collapse through multiple levels (vagga → nikaya → pitaka)',
            () {
          // Scenario: dn-1 selected, all other nikayas selected
          // Selecting dn-2 should trigger two-level cascade:
          // 1. dn-1 + dn-2 → dn (collapse vaggas to nikaya)
          // 2. all nikayas → sp (collapse nikayas to pitaka)
          final dn2 = dighaNikaya.findDescendantByKey('dn-2')!;
          final scope = {
            'dn-1', // First vagga of Digha
            TipitakaNodeKeys.majjhimaNikaya,
            TipitakaNodeKeys.samyuttaNikaya,
            TipitakaNodeKeys.anguttaraNikaya,
            TipitakaNodeKeys.khuddakaNikaya,
          };
          final result = ScopeOperations.toggleNodeSelection(
            dn2,
            scope,
            treeRoots: treeRoots,
          );
          // Should cascade all the way up to sp
          expect(result, equals({TipitakaNodeKeys.suttaPitaka}));
        });
      });

      group('getCheckboxState', () {
        test('returns true when node is directly selected', () {
          final scope = {TipitakaNodeKeys.dighaNikaya};
          expect(
            ScopeOperations.getCheckboxState(dighaNikaya, scope),
            isTrue,
          );
        });

        test('returns true when ancestor is selected (implicit)', () {
          // sp is selected, dn should show as checked
          final scope = {TipitakaNodeKeys.suttaPitaka};
          expect(
            ScopeOperations.getCheckboxState(dighaNikaya, scope),
            isTrue,
          );
        });

        test('returns true when "All" is selected', () {
          expect(
            ScopeOperations.getCheckboxState(dighaNikaya, {}),
            isTrue,
          );
        });

        test('returns null (tristate) when some descendants selected', () {
          // Only dn-1 selected (partial selection of dn)
          final scope = {'dn-1'};
          expect(
            ScopeOperations.getCheckboxState(dighaNikaya, scope),
            isNull,
          );
        });

        test('returns null for parent when only some children selected', () {
          // Only 2 of 5 nikayas selected
          final scope = {
            TipitakaNodeKeys.dighaNikaya,
            TipitakaNodeKeys.majjhimaNikaya,
          };
          expect(
            ScopeOperations.getCheckboxState(suttaPitaka, scope),
            isNull,
          );
        });

        test('returns false when node not selected and no descendants selected',
            () {
          // vp selected, checking state for dn (unrelated)
          final scope = {TipitakaNodeKeys.vinayaPitaka};
          expect(
            ScopeOperations.getCheckboxState(dighaNikaya, scope),
            isFalse,
          );
        });
      });

      group('getNodesNeedingExpansion', () {
        test('expands root nodes that are directly selected', () {
          final result = ScopeOperations.getNodesNeedingExpansion(
            {TipitakaNodeKeys.suttaPitaka},
          );
          expect(result, contains(TipitakaNodeKeys.suttaPitaka));
        });

        test('expands root nodes that cover selected children', () {
          // dn selected - should expand sp to show it
          final result = ScopeOperations.getNodesNeedingExpansion(
            {TipitakaNodeKeys.dighaNikaya},
          );
          expect(result, contains(TipitakaNodeKeys.suttaPitaka));
        });

        test('expands multiple roots for mixed selections', () {
          final result = ScopeOperations.getNodesNeedingExpansion(
            {TipitakaNodeKeys.dighaNikaya, TipitakaNodeKeys.vinayaPitaka},
          );
          expect(result, contains(TipitakaNodeKeys.suttaPitaka));
          expect(result, contains(TipitakaNodeKeys.vinayaPitaka));
        });

        test('returns empty for empty scope', () {
          final result = ScopeOperations.getNodesNeedingExpansion({});
          expect(result, isEmpty);
        });
      });

      group('collapseToAncestors', () {
        test('recursively collapses up the tree', () {
          // All vaggas under dn + all other nikayas selected
          // Should collapse dn-1,dn-2 -> dn, then all nikayas -> sp
          final dn1Node = dighaNikaya.findDescendantByKey('dn-1')!;
          final scope = {
            'dn-1',
            'dn-2',
            TipitakaNodeKeys.majjhimaNikaya,
            TipitakaNodeKeys.samyuttaNikaya,
            TipitakaNodeKeys.anguttaraNikaya,
            TipitakaNodeKeys.khuddakaNikaya,
          };
          final result = ScopeOperations.collapseToAncestors(
            dn1Node,
            scope,
            treeRoots,
          );
          // First collapse: dn-1 + dn-2 -> dn
          // Second collapse: all nikayas -> sp
          expect(result, equals({TipitakaNodeKeys.suttaPitaka}));
        });

        test('stops at root level', () {
          // All nikayas selected, should collapse to sp and stop
          final scope = {
            TipitakaNodeKeys.dighaNikaya,
            TipitakaNodeKeys.majjhimaNikaya,
            TipitakaNodeKeys.samyuttaNikaya,
            TipitakaNodeKeys.anguttaraNikaya,
            TipitakaNodeKeys.khuddakaNikaya,
          };
          final result = ScopeOperations.collapseToAncestors(
            dighaNikaya,
            scope,
            treeRoots,
          );
          expect(result, equals({TipitakaNodeKeys.suttaPitaka}));
        });

        test('does not collapse when siblings are not all selected', () {
          // Only some vaggas selected
          final dn1Node = dighaNikaya.findDescendantByKey('dn-1')!;
          final scope = {'dn-1'}; // dn-2 not selected
          final result = ScopeOperations.collapseToAncestors(
            dn1Node,
            scope,
            treeRoots,
          );
          expect(result, equals({'dn-1'})); // No collapse
        });
      });
    });
  });
}
