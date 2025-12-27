import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:the_wisdom_project/data/repositories/navigation_tree_repository_impl.dart';
import 'package:the_wisdom_project/domain/entities/failure.dart';
import 'package:the_wisdom_project/domain/entities/navigation/tipitaka_tree_node.dart';

import '../../helpers/mocks.mocks.dart';
import '../../helpers/test_data.dart';

void main() {
  late NavigationTreeRepositoryImpl repository;
  late MockTreeLocalDataSource mockDataSource;

  setUp(() {
    mockDataSource = MockTreeLocalDataSource();
    // Create a NEW repository for each test to clear the cache
    repository = NavigationTreeRepositoryImpl(mockDataSource);
  });

  // ============================================================
  // loadNavigationTree tests
  // ============================================================
  group('loadNavigationTree', () {
    test('should return tree from datasource on first call', () async {
      // ARRANGE
      when(mockDataSource.loadNavigationTree())
          .thenAnswer((_) async => TestData.sampleTree);

      // ACT
      final result = await repository.loadNavigationTree();

      // ASSERT
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Expected success'),
        (tree) {
          expect(tree.length, equals(2));
          expect(tree[0].nodeKey, equals('sp'));
        },
      );

      verify(mockDataSource.loadNavigationTree()).called(1);
    });

    test('should return CACHED tree on second call (no datasource hit)',
        () async {
      // ARRANGE
      when(mockDataSource.loadNavigationTree())
          .thenAnswer((_) async => TestData.sampleTree);

      // ACT - Call twice
      await repository.loadNavigationTree();
      final result = await repository.loadNavigationTree();

      // ASSERT
      expect(result.isRight(), true);

      // KEY ASSERTION: DataSource should only be called ONCE
      // Second call should use cache
      verify(mockDataSource.loadNavigationTree()).called(1);
    });

    test('should return DataLoadFailure when datasource throws', () async {
      // ARRANGE
      when(mockDataSource.loadNavigationTree())
          .thenThrow(Exception('Network error'));

      // ACT
      final result = await repository.loadNavigationTree();

      // ASSERT
      expect(result.isLeft(), true);
      result.fold(
        (failure) {
          expect(failure, isA<DataLoadFailure>());
          expect(failure.userMessage, contains('Failed to load'));
        },
        (tree) => fail('Expected failure'),
      );
    });
  });

  // ============================================================
  // getNodeByKey tests
  // ============================================================
  group('getNodeByKey', () {
    test('should return node when found', () async {
      // ARRANGE
      when(mockDataSource.loadNavigationTree())
          .thenAnswer((_) async => TestData.sampleTree);

      // ACT
      final result = await repository.getNodeByKey('sp');

      // ASSERT
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Expected success'),
        (node) {
          expect(node.nodeKey, equals('sp'));
          expect(node.paliName, equals('Sutta Pitaka'));
        },
      );
    });

    test('should return nested node when found', () async {
      // ARRANGE - sampleTree has nested structure: sp -> sp-1 -> sp-1-1, sp-1-2
      when(mockDataSource.loadNavigationTree())
          .thenAnswer((_) async => TestData.sampleTree);

      // ACT - Look for a deeply nested node
      final result = await repository.getNodeByKey('sp-1-1');

      // ASSERT
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Expected success'),
        (node) {
          expect(node.nodeKey, equals('sp-1-1'));
          expect(node.paliName, equals('Silakkhandha Vagga'));
        },
      );
    });

    test('should return NotFoundFailure when node does not exist', () async {
      // ARRANGE
      when(mockDataSource.loadNavigationTree())
          .thenAnswer((_) async => TestData.sampleTree);

      // ACT
      final result = await repository.getNodeByKey('non-existent-key');

      // ASSERT
      expect(result.isLeft(), true);
      result.fold(
        (failure) {
          expect(failure, isA<NotFoundFailure>());
          expect(failure.userMessage, contains('non-existent-key'));
        },
        (node) => fail('Expected failure'),
      );
    });

    test('should load tree first if not cached', () async {
      // ARRANGE
      when(mockDataSource.loadNavigationTree())
          .thenAnswer((_) async => TestData.sampleTree);

      // ACT - Call getNodeByKey without loading tree first
      await repository.getNodeByKey('sp');

      // ASSERT - Tree should have been loaded
      verify(mockDataSource.loadNavigationTree()).called(1);
    });
  });

  // ============================================================
  // getRootNodes tests
  // ============================================================
  group('getRootNodes', () {
    test('should return root nodes', () async {
      // ARRANGE
      when(mockDataSource.loadNavigationTree())
          .thenAnswer((_) async => TestData.sampleTree);

      // ACT
      final result = await repository.getRootNodes();

      // ASSERT
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Expected success'),
        (roots) {
          expect(roots.length, equals(2));
          expect(roots[0].nodeKey, equals('sp'));
          expect(roots[1].nodeKey, equals('vp'));
        },
      );
    });

    test('should return empty list when tree is empty', () async {
      // ARRANGE
      when(mockDataSource.loadNavigationTree())
          .thenAnswer((_) async => <TipitakaTreeNode>[]);

      // ACT
      final result = await repository.getRootNodes();

      // ASSERT
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Expected success'),
        (roots) => expect(roots, isEmpty),
      );
    });
  });

  // ============================================================
  // searchNodes tests
  // ============================================================
  group('searchNodes', () {
    test('should find nodes matching Pali name', () async {
      // ARRANGE
      when(mockDataSource.loadNavigationTree())
          .thenAnswer((_) async => TestData.sampleTree);

      // ACT - Search for "Sutta" in Pali
      final result = await repository.searchNodes(
        query: 'Sutta',
        searchInPali: true,
        searchInSinhala: false,
      );

      // ASSERT
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Expected success'),
        (nodes) {
          expect(nodes.isNotEmpty, true);
          expect(
            nodes.any((n) => n.paliName.contains('Sutta')),
            true,
          );
        },
      );
    });

    test('should find nodes matching Sinhala name', () async {
      // ARRANGE
      when(mockDataSource.loadNavigationTree())
          .thenAnswer((_) async => TestData.sampleTree);

      // ACT - Search for Sinhala text
      final result = await repository.searchNodes(
        query: 'පිටකය', // "Pitaka" in Sinhala
        searchInPali: false,
        searchInSinhala: true,
      );

      // ASSERT
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Expected success'),
        (nodes) {
          expect(nodes.isNotEmpty, true);
        },
      );
    });

    test('should be case-insensitive', () async {
      // ARRANGE
      when(mockDataSource.loadNavigationTree())
          .thenAnswer((_) async => TestData.sampleTree);

      // ACT - Search with lowercase
      final result = await repository.searchNodes(
        query: 'sutta', // lowercase
        searchInPali: true,
        searchInSinhala: false,
      );

      // ASSERT
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Expected success'),
        (nodes) {
          expect(nodes.isNotEmpty, true);
        },
      );
    });

    test('should return empty list when no matches found', () async {
      // ARRANGE
      when(mockDataSource.loadNavigationTree())
          .thenAnswer((_) async => TestData.sampleTree);

      // ACT
      final result = await repository.searchNodes(
        query: 'xyznonexistent',
        searchInPali: true,
        searchInSinhala: true,
      );

      // ASSERT
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Expected success'),
        (nodes) => expect(nodes, isEmpty),
      );
    });

    test('should search in both languages by default', () async {
      // ARRANGE
      when(mockDataSource.loadNavigationTree())
          .thenAnswer((_) async => TestData.sampleTree);

      // ACT - Search for "Pitaka" which appears in Pali names
      final result = await repository.searchNodes(query: 'Pitaka');

      // ASSERT
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Expected success'),
        (nodes) {
          // Should find both Sutta Pitaka and Vinaya Pitaka
          expect(nodes.length, greaterThanOrEqualTo(2));
        },
      );
    });
  });
}
