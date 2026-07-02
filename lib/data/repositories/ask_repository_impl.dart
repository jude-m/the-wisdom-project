import 'dart:developer' as developer;

import 'package:dartz/dartz.dart';

import '../../domain/entities/ask/ask_answer.dart';
import '../../domain/entities/ask/ask_filters.dart';
import '../../domain/entities/ask/chat_message.dart';
import '../../domain/entities/failure.dart';
import '../../domain/repositories/ask_repository.dart';
import '../datasources/ask_datasource.dart';
import 'ask_error_mapper.dart';

/// Wraps an [AskDataSource], turning thrown errors into [Failure]s so the
/// presentation layer only ever deals with `Either<Failure, AskAnswer>`.
class AskRepositoryImpl implements AskRepository {
  final AskDataSource _dataSource;

  AskRepositoryImpl(this._dataSource);

  @override
  Future<Either<Failure, AskAnswer>> ask(
    String question, {
    List<ChatMessage> history = const [],
    AskFilters? filters,
  }) async {
    try {
      final answer = await _dataSource.ask(
        question,
        history: history,
        filters: filters,
      );
      return Right(answer);
    } catch (e, stack) {
      // Typed transport errors ([ApiException]) and any unexpected error both
      // land here. `mapAskError` turns them into a `Failure.apiFailure` whose
      // `kind` lets the UI show the right message + affordance (offline vs
      // quota vs timeout vs …), instead of one flattened sentence.
      //
      // The real cause is logged here; the user-facing copy is chosen upstream
      // from the kind. (The `Failure` still carries the original error for logs.)
      developer.log('ask failed', name: 'ask', error: e, stackTrace: stack);
      return Left(mapAskError(e));
    }
  }
}
