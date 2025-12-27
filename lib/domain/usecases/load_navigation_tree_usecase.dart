import 'package:dartz/dartz.dart';
import '../entities/failure.dart';
import '../entities/navigation/tipitaka_tree_node.dart';
import '../repositories/navigation_tree_repository.dart';

/// Use case for loading the navigation tree
class LoadNavigationTreeUseCase {
  final NavigationTreeRepository _repository;

  LoadNavigationTreeUseCase(this._repository);

  /// Execute the use case to load the navigation tree
  Future<Either<Failure, List<TipitakaTreeNode>>> execute() async {
    return await _repository.loadNavigationTree();
  }
}
