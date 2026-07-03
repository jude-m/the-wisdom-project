import 'dart:developer' as developer;

import 'package:dartz/dartz.dart';

import '../../domain/entities/research/research_answer.dart';
import '../../domain/entities/research/research_filters.dart';
import '../../domain/entities/research/chat_message.dart';
import '../../domain/entities/failure.dart';
import '../../domain/repositories/research_repository.dart';
import '../datasources/research_datasource.dart';
import 'research_error_mapper.dart';

/// Wraps an [ResearchDataSource], turning thrown errors into [Failure]s so the
/// presentation layer only ever deals with `Either<Failure, ResearchAnswer>`.
class ResearchRepositoryImpl implements ResearchRepository {
  final ResearchDataSource _dataSource;

  ResearchRepositoryImpl(this._dataSource);

  @override
  Future<Either<Failure, ResearchAnswer>> research(
    String question, {
    List<ChatMessage> history = const [],
    ResearchFilters? filters,
  }) async {
    try {
      final answer = await _dataSource.research(
        question,
        history: history,
        filters: filters,
      );
      return Right(answer);
    } catch (e, stack) {
      // Typed transport errors ([ApiException]) and any unexpected error both
      // land here. `mapResearchError` turns them into a `Failure.apiFailure` whose
      // `kind` lets the UI show the right message + affordance (offline vs
      // quota vs timeout vs …), instead of one flattened sentence.
      //
      // The real cause is logged here; the user-facing copy is chosen upstream
      // from the kind. (The `Failure` still carries the original error for logs.)
      developer.log('research failed', name: 'research', error: e, stackTrace: stack);
      return Left(mapResearchError(e));
    }
  }
}
