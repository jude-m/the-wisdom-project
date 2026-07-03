import '../../domain/entities/research/research_answer.dart';
import '../../domain/entities/research/research_filters.dart';
import '../../domain/entities/research/chat_message.dart';

/// Data source for the `/research` backend.
///
/// Exactly one implementation type is active per run — the stub (dev) or the
/// remote HTTP client (real). There is deliberately NO local implementation:
/// the feature is inherently online (see the integration plan §1).
abstract class ResearchDataSource {
  Future<ResearchAnswer> research(
    String question, {
    List<ChatMessage> history = const [],
    ResearchFilters? filters,
  });
}
