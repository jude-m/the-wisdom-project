import '../../domain/entities/research/research_answer.dart';
import '../../domain/entities/research/research_filters.dart';
import '../../domain/entities/research/chat_message.dart';
import '../../domain/entities/research/citation.dart';
import 'research_datasource.dart';

/// Fake [ResearchDataSource] for building the UI before the backend exists.
///
/// Returns a canned grounded answer after a short delay (so the "thinking…"
/// loading state is visible). Swap for `ResearchRemoteDataSourceImpl` in
/// `research_provider.dart` once the Python `/research` service is up — that one-line
/// change is the whole point of building stub-first.
class ResearchStubDataSource implements ResearchDataSource {
  @override
  Future<ResearchAnswer> research(
    String question, {
    List<ChatMessage> history = const [],
    ResearchFilters? filters,
  }) async {
    // Simulate network latency so the loading state and send-button guard show.
    await Future<void>.delayed(const Duration(milliseconds: 700));

    return ResearchAnswer(
      answer:
          'This is a stub answer — no backend is connected yet.\n\n'
          'You asked: "${question.trim()}"\n\n'
          'Once the real /research service is wired in, this will be a grounded '
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
