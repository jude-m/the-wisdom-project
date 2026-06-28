import 'dart:developer' as developer;

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
    } catch (e, stack) {
      // Network errors (offline / backend down) and backend errors both land
      // here. We avoid importing dart:io (SocketException) so this stays
      // web-safe; the message reads sensibly for either case.
      //
      // The user-facing copy stays generic, but log the real cause — for a
      // backend 5xx the datasource embeds the response body (which carries the
      // server's "ask backend error: …" detail), so this line shows exactly why.
      developer.log('ask failed', name: 'ask', error: e, stackTrace: stack);
      return Left(Failure.dataLoadFailure(
        message: 'Could not get an answer right now. Please try again.',
        error: e,
      ));
    }
  }
}
