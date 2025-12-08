import 'package:dartz/dartz.dart';
import '../../domain/entities/failure.dart';
import '../../domain/entities/tipitaka_tree_node.dart';
import '../../domain/repositories/navigation_tree_repository.dart';
import '../datasources/tree_local_datasource.dart';

class NavigationTreeRepositoryImpl implements NavigationTreeRepository {
  final TreeLocalDataSource _localDataSource;

  // Cache the loaded tree
  List<TipitakaTreeNode>? _cachedTree;
  Map<String, TipitakaTreeNode>? _nodeIndex;

  NavigationTreeRepositoryImpl(this._localDataSource);

  @override
  Future<Either<Failure, List<TipitakaTreeNode>>> loadNavigationTree() async {
    try {
      // Return cached tree if available
      if (_cachedTree != null) {
        return Right(_cachedTree!);
      }

      // Load from data source
      final tree = await _localDataSource.loadNavigationTree();

      // Cache the tree and build index
      _cachedTree = tree;
      _nodeIndex = _buildNodeIndex(tree);

      return Right(tree);
    } catch (e) {
      return Left(Failure.dataLoadFailure(
        message: 'Failed to load navigation tree',
        error: e,
      ));
    }
  }

  @override
  Future<Either<Failure, TipitakaTreeNode>> getNodeByKey(String nodeKey) async {
    try {
      // Ensure tree is loaded
      if (_nodeIndex == null) {
        final result = await loadNavigationTree();
        if (result.isLeft()) {
          return Left(
              result.fold((failure) => failure, (_) => throw Exception()));
        }
      }

      final node = _nodeIndex![nodeKey];
      if (node == null) {
        return Left(Failure.notFoundFailure(
          message: 'Node with key "$nodeKey" not found',
        ));
      }

      return Right(node);
    } catch (e) {
      return Left(Failure.unexpectedFailure(
        message: 'Failed to get node by key',
        error: e,
      ));
    }
  }

  @override
  Future<Either<Failure, List<TipitakaTreeNode>>> getRootNodes() async {
    try {
      // Ensure tree is loaded
      if (_cachedTree == null) {
        final result = await loadNavigationTree();
        if (result.isLeft()) {
          return Left(
              result.fold((failure) => failure, (_) => throw Exception()));
        }
      }

      return Right(_cachedTree ?? []);
    } catch (e) {
      return Left(Failure.unexpectedFailure(
        message: 'Failed to get root nodes',
        error: e,
      ));
    }
  }

  @override
  Future<Either<Failure, List<TipitakaTreeNode>>> searchNodes({
    required String query,
    bool searchInPali = true,
    bool searchInSinhala = true,
  }) async {
    try {
      // Ensure tree is loaded
      if (_nodeIndex == null) {
        final result = await loadNavigationTree();
        if (result.isLeft()) {
          return Left(
              result.fold((failure) => failure, (_) => throw Exception()));
        }
      }

      final lowercaseQuery = query.toLowerCase();
      final matchingNodes = <TipitakaTreeNode>[];

      _nodeIndex!.forEach((key, node) {
        bool matches = false;

        if (searchInPali &&
            node.paliName.toLowerCase().contains(lowercaseQuery)) {
          matches = true;
        }

        if (searchInSinhala &&
            node.sinhalaName.toLowerCase().contains(lowercaseQuery)) {
          matches = true;
        }

        if (matches) {
          matchingNodes.add(node);
        }
      });

      return Right(matchingNodes);
    } catch (e) {
      return Left(Failure.unexpectedFailure(
        message: 'Failed to search nodes',
        error: e,
      ));
    }
  }

  /// Build a flat index of all nodes for quick lookup
  Map<String, TipitakaTreeNode> _buildNodeIndex(
      List<TipitakaTreeNode> rootNodes) {
    final index = <String, TipitakaTreeNode>{};

    void indexNode(TipitakaTreeNode node) {
      index[node.nodeKey] = node;
      for (var child in node.childNodes) {
        indexNode(child);
      }
    }

    for (var rootNode in rootNodes) {
      indexNode(rootNode);
    }

    return index;
  }
}
