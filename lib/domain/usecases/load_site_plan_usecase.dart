import 'package:dartz/dartz.dart';
import 'package:wisdom_shared/wisdom_shared.dart';
import '../entities/failure.dart';
import '../repositories/navigation_tree_repository.dart';

/// Use case for loading the page plan — which page serves each node, and in
/// what order a reader walks them.
///
/// A pass-through, exactly like [LoadNavigationTreeUseCase] beside it. It
/// exists so the two answers the reader needs from the same repository are
/// reached the same way: before this, the tree came through a use case and the
/// plan came straight off the repository, from two providers in one file.
class LoadSitePlanUseCase {
  final NavigationTreeRepository _repository;

  LoadSitePlanUseCase(this._repository);

  /// Execute the use case to load the page plan
  Future<Either<Failure, SitePlan>> execute() async {
    return await _repository.loadSitePlan();
  }
}
