import 'package:dartz/dartz.dart';
import 'package:wisdom_shared/wisdom_shared.dart';
import '../entities/failure.dart';
import '../repositories/navigation_tree_repository.dart';

/// Use case for loading the decoded navigation tree — the structural view the
/// canon ↔ aṭṭhakathā cross-link is resolved against.
///
/// A pass-through, exactly like [LoadSitePlanUseCase] beside it, and there for
/// the same reason: every answer the reader needs from this repository is
/// reached the same way.
class LoadSharedTreeUseCase {
  final NavigationTreeRepository _repository;

  LoadSharedTreeUseCase(this._repository);

  /// Execute the use case to load the decoded tree
  Future<Either<Failure, TipitakaTree>> execute() async {
    return await _repository.loadSharedTree();
  }
}
