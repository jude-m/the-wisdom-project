import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:the_wisdom_project/core/constants/constants.dart';
import 'package:the_wisdom_project/domain/entities/navigation/navigation_language.dart';
import 'package:the_wisdom_project/domain/entities/navigation/tipitaka_tree_node.dart';
import 'package:the_wisdom_project/presentation/providers/navigation_tree_provider.dart';

import '../../helpers/mocks.mocks.dart';
import '../../helpers/pump_app.dart';

void main() {
  group('expandedNodesProvider -', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('should have Sutta Pitaka expanded by default', () {
      // ARRANGE & ACT
      final expandedNodes = container.read(expandedNodesProvider);

      // ASSERT - Default should have Sutta Pitaka (TipitakaNodeKeys.suttaPitaka) expanded
      expect(expandedNodes, contains(TipitakaNodeKeys.suttaPitaka));
      expect(expandedNodes.length, equals(1));
    });

    test('should be able to update expanded nodes', () {
      // ARRANGE
      final newExpandedNodes = {'node1', 'node2', 'node3'};

      // ACT
      container.read(expandedNodesProvider.notifier).state = newExpandedNodes;

      // ASSERT
      expect(container.read(expandedNodesProvider), equals(newExpandedNodes));
    });
  });

  group('toggleNodeExpansionProvider -', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('should add node to expanded set when not already expanded', () {
      // ARRANGE - Start with default (only Sutta Pitaka expanded)
      expect(container.read(expandedNodesProvider),
          equals({TipitakaNodeKeys.suttaPitaka}));

      // ACT - Toggle a new node
      container.read(toggleNodeExpansionProvider)('vinaya-pitaka');

      // ASSERT - Should now have both nodes expanded
      final expandedNodes = container.read(expandedNodesProvider);
      expect(expandedNodes, contains(TipitakaNodeKeys.suttaPitaka));
      expect(expandedNodes, contains('vinaya-pitaka'));
      expect(expandedNodes.length, equals(2));
    });

    test('should remove node from expanded set when already expanded', () {
      // ARRANGE - Set initial expanded nodes
      container.read(expandedNodesProvider.notifier).state = {
        TipitakaNodeKeys.suttaPitaka,
        'vinaya-pitaka',
      };

      // ACT - Toggle a node that's already expanded
      container.read(toggleNodeExpansionProvider)('vinaya-pitaka');

      // ASSERT - Should only have Sutta Pitaka expanded
      final expandedNodes = container.read(expandedNodesProvider);
      expect(expandedNodes, contains(TipitakaNodeKeys.suttaPitaka));
      expect(expandedNodes.contains('vinaya-pitaka'), isFalse);
      expect(expandedNodes.length, equals(1));
    });

    test('should toggle the same node twice (expand then collapse)', () {
      // ARRANGE
      expect(
          container.read(expandedNodesProvider).contains('test-node'), isFalse);

      // ACT - Toggle to expand
      container.read(toggleNodeExpansionProvider)('test-node');
      expect(container.read(expandedNodesProvider), contains('test-node'));

      // ACT - Toggle to collapse
      container.read(toggleNodeExpansionProvider)('test-node');

      // ASSERT
      expect(
          container.read(expandedNodesProvider).contains('test-node'), isFalse);
    });
  });

  group('selectNodeProvider -', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('should update selected node state', () {
      // ARRANGE - Initially null
      expect(container.read(selectedNodeProvider), isNull);

      // ACT
      container.read(selectNodeProvider)('dn-1');

      // ASSERT
      expect(container.read(selectedNodeProvider), equals('dn-1'));
    });

    test('should allow changing selected node', () {
      // ARRANGE
      container.read(selectNodeProvider)('dn-1');
      expect(container.read(selectedNodeProvider), equals('dn-1'));

      // ACT
      container.read(selectNodeProvider)('mn-1');

      // ASSERT
      expect(container.read(selectedNodeProvider), equals('mn-1'));
    });

    test('should allow setting selected node to same value', () {
      // ARRANGE
      container.read(selectNodeProvider)('dn-1');

      // ACT - Select the same node again
      container.read(selectNodeProvider)('dn-1');

      // ASSERT
      expect(container.read(selectedNodeProvider), equals('dn-1'));
    });
  });

  group('selectedNodeProvider -', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('should be null by default', () {
      // ASSERT
      expect(container.read(selectedNodeProvider), isNull);
    });

    test('should be able to set directly', () {
      // ACT
      container.read(selectedNodeProvider.notifier).state = 'test-node';

      // ASSERT
      expect(container.read(selectedNodeProvider), equals('test-node'));
    });

    test('should be able to reset to null', () {
      // ARRANGE
      container.read(selectedNodeProvider.notifier).state = 'test-node';

      // ACT
      container.read(selectedNodeProvider.notifier).state = null;

      // ASSERT
      expect(container.read(selectedNodeProvider), isNull);
    });
  });

  group('scrollToNodeRequestProvider -', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('should be null by default', () {
      // ASSERT
      expect(container.read(scrollToNodeRequestProvider), isNull);
    });

    test('should trigger scroll event when set', () {
      // ACT
      container.read(scrollToNodeRequestProvider.notifier).state = 'dn-1';

      // ASSERT
      expect(container.read(scrollToNodeRequestProvider), equals('dn-1'));
    });

    test('should allow resetting to null', () {
      // ARRANGE
      container.read(scrollToNodeRequestProvider.notifier).state = 'dn-1';

      // ACT
      container.read(scrollToNodeRequestProvider.notifier).state = null;

      // ASSERT
      expect(container.read(scrollToNodeRequestProvider), isNull);
    });

    test(
        'should allow setting same value consecutively using null-then-set pattern',
        () {
      // This tests the pattern used in syncNavigatorToActiveTabProvider
      // to force listeners to fire even when re-selecting the same node

      // ARRANGE
      container.read(scrollToNodeRequestProvider.notifier).state = 'dn-1';

      // ACT - Use null-then-set pattern
      container.read(scrollToNodeRequestProvider.notifier).state = null;
      container.read(scrollToNodeRequestProvider.notifier).state = 'dn-1';

      // ASSERT
      expect(container.read(scrollToNodeRequestProvider), equals('dn-1'));
    });
  });

  group('navigationLanguageProvider -', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('should default to Sinhala', () {
      // ASSERT
      expect(container.read(navigationLanguageProvider),
          equals(NavigationLanguage.sinhala));
    });

    test('should toggle to Pali', () {
      // ACT
      container.read(navigationLanguageProvider.notifier).state =
          NavigationLanguage.pali;

      // ASSERT
      expect(container.read(navigationLanguageProvider),
          equals(NavigationLanguage.pali));
    });

    test('should toggle back to Sinhala', () {
      // ARRANGE
      container.read(navigationLanguageProvider.notifier).state =
          NavigationLanguage.pali;

      // ACT
      container.read(navigationLanguageProvider.notifier).state =
          NavigationLanguage.sinhala;

      // ASSERT
      expect(container.read(navigationLanguageProvider),
          equals(NavigationLanguage.sinhala));
    });
  });

  group('expandPathToNodeProvider -', () {
    late MockNavigationTreeRepository mockRepository;
    late ProviderContainer container;

    setUp(() {
      mockRepository = MockNavigationTreeRepository();
    });

    tearDown(() {
      container.dispose();
    });

    test('should expand all parent nodes to make target visible', () async {
      // ARRANGE - Create a mock tree structure:
      // sp (Sutta Pitaka)
      //   dn (Digha Nikaya)
      //     dn-1 (Brahmajala Sutta)
      final tree = [
        _createTestTreeNode(
          nodeKey: TipitakaNodeKeys.suttaPitaka,
          paliName: 'Sutta Pitaka',
          childNodes: [
            _createTestTreeNode(
              nodeKey: TipitakaNodeKeys.dighaNikaya,
              paliName: 'Digha Nikaya',
              parentNodeKey: TipitakaNodeKeys.suttaPitaka,
              childNodes: [
                _createTestTreeNode(
                  nodeKey: 'dn-1',
                  paliName: 'Brahmajala Sutta',
                  parentNodeKey: TipitakaNodeKeys.dighaNikaya,
                  contentFileId: 'dn-1',
                ),
              ],
            ),
          ],
        ),
      ];

      when(mockRepository.loadNavigationTree())
          .thenAnswer((_) async => Right(tree));

      container = ProviderContainer(
        overrides: [
          TestProviderOverrides.navigationTreeRepository(mockRepository),
        ],
      );

      // Wait for the navigation tree to load
      await container.read(navigationTreeProvider.future);

      // Clear expanded nodes to start fresh
      container.read(expandedNodesProvider.notifier).state = {};

      // ACT - Expand path to dn-1
      container.read(expandPathToNodeProvider)('dn-1');

      // ASSERT - sp and dn should be expanded (parent nodes), but not dn-1 itself
      final expandedNodes = container.read(expandedNodesProvider);
      expect(expandedNodes, contains(TipitakaNodeKeys.suttaPitaka));
      expect(expandedNodes, contains(TipitakaNodeKeys.dighaNikaya));
      // The target node itself should not be expanded (only parents)
      expect(expandedNodes.contains('dn-1'), isFalse);
    });

    test('should handle root node (no expansion needed)', () async {
      // ARRANGE - Simple tree with root node
      final tree = [
        _createTestTreeNode(
          nodeKey: TipitakaNodeKeys.suttaPitaka,
          paliName: 'Sutta Pitaka',
        ),
      ];

      when(mockRepository.loadNavigationTree())
          .thenAnswer((_) async => Right(tree));

      container = ProviderContainer(
        overrides: [
          TestProviderOverrides.navigationTreeRepository(mockRepository),
        ],
      );

      // Wait for the navigation tree to load
      await container.read(navigationTreeProvider.future);

      // Clear expanded nodes
      container.read(expandedNodesProvider.notifier).state = {};

      // ACT - Expand path to root node
      container.read(expandPathToNodeProvider)(TipitakaNodeKeys.suttaPitaka);

      // ASSERT - No nodes should be expanded (root has no parents)
      final expandedNodes = container.read(expandedNodesProvider);
      expect(expandedNodes, isEmpty);
    });

    test('should preserve existing expanded nodes', () async {
      // ARRANGE
      final tree = [
        _createTestTreeNode(
          nodeKey: TipitakaNodeKeys.suttaPitaka,
          paliName: 'Sutta Pitaka',
          childNodes: [
            _createTestTreeNode(
              nodeKey: TipitakaNodeKeys.dighaNikaya,
              paliName: 'Digha Nikaya',
              parentNodeKey: TipitakaNodeKeys.suttaPitaka,
              childNodes: [
                _createTestTreeNode(
                  nodeKey: 'dn-1',
                  paliName: 'Brahmajala Sutta',
                  parentNodeKey: TipitakaNodeKeys.dighaNikaya,
                  contentFileId: 'dn-1',
                ),
              ],
            ),
          ],
        ),
        _createTestTreeNode(
          nodeKey: TipitakaNodeKeys.vinayaPitaka,
          paliName: 'Vinaya Pitaka',
          childNodes: [
            _createTestTreeNode(
              nodeKey: 'mahavagga',
              paliName: 'Mahavagga',
              parentNodeKey: TipitakaNodeKeys.vinayaPitaka,
            ),
          ],
        ),
      ];

      when(mockRepository.loadNavigationTree())
          .thenAnswer((_) async => Right(tree));

      container = ProviderContainer(
        overrides: [
          TestProviderOverrides.navigationTreeRepository(mockRepository),
        ],
      );
      // Wait for the navigation tree to load
      await container.read(navigationTreeProvider.future);

      // Set some existing expanded nodes
      container.read(expandedNodesProvider.notifier).state = {
        TipitakaNodeKeys.vinayaPitaka,
        'mahavagga'
      };

      // ACT - Expand path to dn-1
      container.read(expandPathToNodeProvider)('dn-1');

      // ASSERT - Should have existing + new expanded nodes
      final expandedNodes = container.read(expandedNodesProvider);
      expect(expandedNodes, contains(TipitakaNodeKeys.vinayaPitaka));
      expect(expandedNodes, contains('mahavagga'));
      expect(expandedNodes, contains(TipitakaNodeKeys.suttaPitaka));
      expect(expandedNodes, contains(TipitakaNodeKeys.dighaNikaya));
    });
  });

  group('nodeByKeyProvider -', () {
    late MockNavigationTreeRepository mockRepository;
    late ProviderContainer container;

    setUp(() {
      mockRepository = MockNavigationTreeRepository();
    });

    tearDown(() {
      container.dispose();
    });

    test('should find node by key in tree', () async {
      // ARRANGE
      final tree = [
        _createTestTreeNode(
          nodeKey: TipitakaNodeKeys.suttaPitaka,
          paliName: 'Sutta Pitaka',
          childNodes: [
            _createTestTreeNode(
              nodeKey: TipitakaNodeKeys.dighaNikaya,
              paliName: 'Digha Nikaya',
              parentNodeKey: TipitakaNodeKeys.suttaPitaka,
              childNodes: [
                _createTestTreeNode(
                  nodeKey: 'dn-1',
                  paliName: 'Brahmajala Sutta',
                  sinhalaName: 'බ්‍රහ්මජාල සූත්‍රය',
                  parentNodeKey: TipitakaNodeKeys.dighaNikaya,
                  contentFileId: 'dn-1',
                ),
              ],
            ),
          ],
        ),
      ];

      when(mockRepository.loadNavigationTree())
          .thenAnswer((_) async => Right(tree));

      container = ProviderContainer(
        overrides: [
          TestProviderOverrides.navigationTreeRepository(mockRepository),
        ],
      );

      // Wait for the navigation tree to load
      await container.read(navigationTreeProvider.future);

      // ACT
      final node = container.read(nodeByKeyProvider('dn-1'));

      // ASSERT
      expect(node, isNotNull);
      expect(node?.nodeKey, equals('dn-1'));
      expect(node?.paliName, equals('Brahmajala Sutta'));
      expect(node?.contentFileId, equals('dn-1'));
    });

    test('should return null for non-existent key', () async {
      // ARRANGE
      final tree = [
        _createTestTreeNode(
          nodeKey: TipitakaNodeKeys.suttaPitaka,
          paliName: 'Sutta Pitaka',
        ),
      ];

      when(mockRepository.loadNavigationTree())
          .thenAnswer((_) async => Right(tree));

      container = ProviderContainer(
        overrides: [
          TestProviderOverrides.navigationTreeRepository(mockRepository),
        ],
      );

      // Wait for the navigation tree to load
      await container.read(navigationTreeProvider.future);

      // ACT
      final node = container.read(nodeByKeyProvider('non-existent'));

      // ASSERT
      expect(node, isNull);
    });

    test('should find deeply nested node', () async {
      // ARRANGE - Create a deeper tree structure (4 levels)
      final tree = [
        _createTestTreeNode(
          nodeKey: 'level-1',
          paliName: 'Level 1',
          childNodes: [
            _createTestTreeNode(
              nodeKey: 'level-2',
              paliName: 'Level 2',
              parentNodeKey: 'level-1',
              childNodes: [
                _createTestTreeNode(
                  nodeKey: 'level-3',
                  paliName: 'Level 3',
                  parentNodeKey: 'level-2',
                  childNodes: [
                    _createTestTreeNode(
                      nodeKey: 'level-4',
                      paliName: 'Level 4 Node',
                      parentNodeKey: 'level-3',
                      contentFileId: 'level-4-content',
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ];

      when(mockRepository.loadNavigationTree())
          .thenAnswer((_) async => Right(tree));

      container = ProviderContainer(
        overrides: [
          TestProviderOverrides.navigationTreeRepository(mockRepository),
        ],
      );

      // Wait for the navigation tree to load
      await container.read(navigationTreeProvider.future);

      // ACT
      final node = container.read(nodeByKeyProvider('level-4'));

      // ASSERT
      expect(node, isNotNull);
      expect(node?.nodeKey, equals('level-4'));
      expect(node?.paliName, equals('Level 4 Node'));
    });

    test('should return null when tree is loading', () async {
      // ARRANGE - Create a slow-loading repository
      when(mockRepository.loadNavigationTree()).thenAnswer(
        (_) => Future.delayed(
          const Duration(seconds: 1),
          () => Right([
            _createTestTreeNode(
                nodeKey: TipitakaNodeKeys.suttaPitaka,
                paliName: 'Sutta Pitaka'),
          ]),
        ),
      );

      container = ProviderContainer(
        overrides: [
          TestProviderOverrides.navigationTreeRepository(mockRepository),
        ],
      );

      // ACT - Don't wait for the tree to load
      final node =
          container.read(nodeByKeyProvider(TipitakaNodeKeys.suttaPitaka));

      // ASSERT - Should return null while loading
      expect(node, isNull);
    });
  });

  group('navigationTreeProvider -', () {
    late MockNavigationTreeRepository mockRepository;
    late ProviderContainer container;

    setUp(() {
      mockRepository = MockNavigationTreeRepository();
    });

    tearDown(() {
      container.dispose();
    });

    test('should load navigation tree successfully', () async {
      // ARRANGE
      final tree = [
        _createTestTreeNode(
            nodeKey: TipitakaNodeKeys.suttaPitaka, paliName: 'Sutta Pitaka'),
        _createTestTreeNode(
            nodeKey: TipitakaNodeKeys.vinayaPitaka, paliName: 'Vinaya Pitaka'),
        _createTestTreeNode(
            nodeKey: TipitakaNodeKeys.abhidhammaPitaka,
            paliName: 'Abhidhamma Pitaka'),
      ];

      when(mockRepository.loadNavigationTree())
          .thenAnswer((_) async => Right(tree));

      container = ProviderContainer(
        overrides: [
          TestProviderOverrides.navigationTreeRepository(mockRepository),
        ],
      );

      // ACT
      final result = await container.read(navigationTreeProvider.future);

      // ASSERT
      expect(result.length, equals(3));
      expect(result[0].nodeKey, equals(TipitakaNodeKeys.suttaPitaka));
      expect(result[1].nodeKey, equals(TipitakaNodeKeys.vinayaPitaka));
      expect(result[2].nodeKey, equals(TipitakaNodeKeys.abhidhammaPitaka));
    });
  });
}

/// Helper function to create test TipitakaTreeNode
TipitakaTreeNode _createTestTreeNode({
  required String nodeKey,
  required String paliName,
  String sinhalaName = 'Test Sinhala Name',
  int hierarchyLevel = 0,
  int entryPageIndex = 0,
  int entryIndexInPage = 0,
  String? parentNodeKey,
  String? contentFileId,
  List<TipitakaTreeNode> childNodes = const [],
  bool hasAudioAvailable = false,
}) {
  return TipitakaTreeNode(
    nodeKey: nodeKey,
    paliName: paliName,
    sinhalaName: sinhalaName,
    hierarchyLevel: hierarchyLevel,
    entryPageIndex: entryPageIndex,
    entryIndexInPage: entryIndexInPage,
    parentNodeKey: parentNodeKey,
    contentFileId: contentFileId,
    childNodes: childNodes,
    hasAudioAvailable: hasAudioAvailable,
  );
}
