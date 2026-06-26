import '../../domain/entities/ask/ask_answer.dart';
import '../../domain/entities/ask/ask_filters.dart';
import '../../domain/entities/ask/chat_message.dart';

/// Data source for the `/ask` backend.
///
/// Exactly one implementation type is active per run — the stub (dev) or the
/// remote HTTP client (real). There is deliberately NO local implementation:
/// the feature is inherently online (see the integration plan §1).
abstract class AskDataSource {
  Future<AskAnswer> ask(
    String question, {
    List<ChatMessage> history = const [],
    AskFilters? filters,
  });
}
