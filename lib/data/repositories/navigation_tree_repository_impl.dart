import 'package:dartz/dartz.dart';
import 'package:wisdom_shared/wisdom_shared.dart';
import '../../domain/entities/failure.dart';
import '../../domain/entities/navigation/tipitaka_tree_node.dart';
import '../../domain/repositories/navigation_tree_repository.dart';
import '../datasources/tree_local_datasource.dart';

class NavigationTreeRepositoryImpl implements NavigationTreeRepository {
  final TreeLocalDataSource _localDataSource;

  // Cache the loaded tree
  List<TipitakaTreeNode>? _cachedTree;
  Map<String, TipitakaTreeNode>? _nodeIndex;

  // The page plan is a pure function of the tree and the frozen snapshot, so
  // it is built once and never invalidated — same lifetime as _cachedTree.
  //
  // Held as the Future, not the plan: the build walks the whole corpus, and two
  // callers arriving before the first finishes would otherwise each run one and
  // throw one away. Mirrors `TreeLocalDataSourceImpl._sharedTree`.
  Future<SitePlan>? _planBuild;

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

  @override
  Future<Either<Failure, SitePlan>> loadSitePlan() async {
    final building = _planBuild ??= _buildSitePlan();
    try {
      return Right(await building);
    } catch (e) {
      // A failed build must not stay cached, or every later caller replays the
      // same error and a retry can never succeed.
      _planBuild = null;
      return Left(Failure.dataLoadFailure(
        message: 'Failed to load the page plan',
        error: e,
      ));
    }
  }

  Future<SitePlan> _buildSitePlan() async {
    final tree = await _localDataSource.loadSharedTree();
    // Whole corpus, and the frozen sets by default — the app reads the site
    // as it ships, never a plan of its own. `SitePlan.build` refuses a
    // snapshot that cannot describe a real site, so a bad regeneration fails
    // here rather than resolving links to pages that were never written.
    return SitePlan.build(tree: tree, rootKeys: tree.rootKeys);
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
