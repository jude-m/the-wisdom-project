import 'package:dartz/dartz.dart';
import 'package:wisdom_shared/wisdom_shared.dart';
import '../entities/failure.dart';
import '../entities/navigation/tipitaka_tree_node.dart';

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

  /// Loads the page plan: which page serves each node, and in what order a
  /// reader walks them.
  ///
  /// The same [SitePlan] the static site is generated from, rebuilt here from
  /// the same tree and the same frozen snapshot — so "which page is this sutta
  /// on" has one answer on both surfaces, and regenerating the snapshot moves
  /// them together.
  ///
  /// Returns Either:
  /// - Left(Failure): If the tree cannot be loaded
  /// - Right(SitePlan): The whole-corpus plan on success
  Future<Either<Failure, SitePlan>> loadSitePlan();

  /// Loads the decoded [TipitakaTree] itself — parents, siblings and titles.
  ///
  /// The app's own [TipitakaTreeNode] answers most questions, but two it
  /// cannot: sibling *order* within a container, and the numeric range a
  /// vaṇṇanā's title declares. `crossLinkTargetKey` needs both to decide
  /// whether a sutta has a commentary at all, so the shared tree is exposed
  /// rather than the answer re-derived from the nested entity.
  ///
  /// Already decoded and cached for [loadSitePlan] — this hands back the same
  /// instance and costs nothing extra.
  ///
  /// Returns Either:
  /// - Left(Failure): If the tree cannot be loaded
  /// - Right(TipitakaTree): The whole-corpus tree on success
  Future<Either<Failure, TipitakaTree>> loadSharedTree();
}
