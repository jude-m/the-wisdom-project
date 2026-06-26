import '../../domain/entities/ask/ask_answer.dart';
import '../../domain/entities/ask/ask_filters.dart';
import '../../domain/entities/ask/chat_message.dart';
import '../../domain/entities/ask/citation.dart';
import 'ask_datasource.dart';

/// Fake [AskDataSource] for building the UI before the backend exists.
///
/// Returns a canned grounded answer after a short delay (so the "thinking…"
/// loading state is visible). Swap for `AskRemoteDataSourceImpl` in
/// `ask_provider.dart` once the Python `/ask` service is up — that one-line
/// change is the whole point of building stub-first.
class AskStubDataSource implements AskDataSource {
  @override
  Future<AskAnswer> ask(
    String question, {
    List<ChatMessage> history = const [],
    AskFilters? filters,
  }) async {
    // Simulate network latency so the loading state and send-button guard show.
    await Future<void>.delayed(const Duration(milliseconds: 700));

    return AskAnswer(
      answer:
          'This is a stub answer — no backend is connected yet.\n\n'
          'You asked: "${question.trim()}"\n\n'
          'Once the real /ask service is wired in, this will be a grounded '
          'answer over the Pali Canon, in the same language you asked, with '
          'citations like the ones listed below.',
      lang: 'en',
      citations: const [
        Citation(
          uid: 'sn15.3',
          ref: 'SN 15.3',
          snippet:
              'Transmigration has no known beginning … the tears you have shed '
              'while roaming on are more than the water in the four oceans.',
        ),
        Citation(
          uid: 'mn10',
          ref: 'MN 10',
          snippet:
              'The four kinds of mindfulness meditation — body, feelings, mind, '
              'and principles.',
        ),
      ],
    );
  }
}
