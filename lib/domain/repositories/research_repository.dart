import 'package:dartz/dartz.dart';

import '../entities/research/research_answer.dart';
import '../entities/research/research_filters.dart';
import '../entities/research/chat_message.dart';
import '../entities/failure.dart';

/// Repository interface for the AI Q&A feature.
///
/// The whole feature is remote-only — no client can call Gemini directly (the
/// API key stays server-side), so unlike search/dictionary there is NO local
/// implementation. See the resolver/integration plan §1.
abstract class ResearchRepository {
  /// Ask a grounded question about the canon.
  ///
  /// [history] is empty in the prototype (design §5.8); the contract keeps the
  /// field so multi-turn follow-ups need no signature change later.
  Future<Either<Failure, ResearchAnswer>> research(
    String question, {
    List<ChatMessage> history = const [],
    ResearchFilters? filters,
  });
}
