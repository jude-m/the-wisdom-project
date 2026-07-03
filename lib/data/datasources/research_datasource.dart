import '../../domain/entities/research/research_answer.dart';
import '../../domain/entities/research/research_filters.dart';
import '../../domain/entities/research/chat_message.dart';

/// Data source for the `/research` backend.
///
/// One implementation: the remote HTTP client. There is deliberately NO local
/// (offline) implementation — the feature is inherently online (see the
/// integration plan §1); when the backend is unreachable the call surfaces a
/// clean error rather than a canned answer.
abstract class ResearchDataSource {
  Future<ResearchAnswer> research(
    String question, {
    List<ChatMessage> history = const [],
    ResearchFilters? filters,
  });
}
