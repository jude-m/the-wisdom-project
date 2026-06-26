import 'package:dartz/dartz.dart';

import '../../domain/entities/ask/ask_answer.dart';
import '../../domain/entities/ask/ask_filters.dart';
import '../../domain/entities/ask/chat_message.dart';
import '../../domain/entities/failure.dart';
import '../../domain/repositories/ask_repository.dart';
import '../datasources/ask_datasource.dart';

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
    } catch (e) {
      // Network errors (offline / backend down) and backend errors both land
      // here. We avoid importing dart:io (SocketException) so this stays
      // web-safe; the message reads sensibly for either case.
      return Left(Failure.dataLoadFailure(
        message: 'Could not get an answer right now. Please try again.',
        error: e,
      ));
    }
  }
}
