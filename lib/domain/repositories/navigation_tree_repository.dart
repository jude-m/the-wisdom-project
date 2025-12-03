import 'package:dartz/dartz.dart';
import '../entities/failure.dart';
import '../entities/tipitaka_tree_node.dart';

/// Repository interface for managing the Tipitaka navigation tree
///
/// This interface defines the contract for loading and accessing
/// the hierarchical structure of the Tipitaka content.
abstract class NavigationTreeRepository {
  /// Loads the complete navigation tree from the data source
  ///
  /// Returns Either:
  /// - Left(Failure): If loading fails
  /// - Right(List<TipitakaTreeNode>): List of root nodes on success
  Future<Either<Failure, List<TipitakaTreeNode>>> loadNavigationTree();

  /// Retrieves a specific node by its unique key
  ///
  /// [nodeKey] The unique identifier of the node to retrieve
  ///
  /// Returns Either:
  /// - Left(Failure): If node is not found or retrieval fails
  /// - Right(TipitakaTreeNode): The requested node on success
  Future<Either<Failure, TipitakaTreeNode>> getNodeByKey(String nodeKey);

  /// Retrieves all root-level nodes in the tree
  ///
  /// Returns Either:
  /// - Left(Failure): If retrieval fails
  /// - Right(List<TipitakaTreeNode>): List of root nodes on success
  Future<Either<Failure, List<TipitakaTreeNode>>> getRootNodes();

  /// Searches for nodes matching the given query
  ///
  /// [query] The search string to match against node names
  /// [searchInPali] Whether to search in Pali names
  /// [searchInSinhala] Whether to search in Sinhala names
  ///
  /// Returns Either:
  /// - Left(Failure): If search fails
  /// - Right(List<TipitakaTreeNode>): List of matching nodes on success
  Future<Either<Failure, List<TipitakaTreeNode>>> searchNodes({
    required String query,
    bool searchInPali = true,
    bool searchInSinhala = true,
  });
}
