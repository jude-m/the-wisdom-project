import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/ask_datasource.dart';
import '../../data/datasources/ask_stub_datasource.dart';
// Phase 4 swap — uncomment when the Python /ask backend is up:
// import '../../data/datasources/ask_remote_datasource.dart';
import '../../data/repositories/ask_repository_impl.dart';
import '../../domain/entities/ask/chat_message.dart';
import '../../domain/repositories/ask_repository.dart';
import 'ask_chat_state.dart';

/// Where the `/ask` backend lives. Native needs an absolute URL (unlike the
/// web content server's same-origin ''). Override per environment.
final askBaseUrlProvider = Provider<String>((ref) => '');

/// The Q&A data source.
///
/// PHASE 1 (now): the stub — a canned answer, no backend.
/// PHASE 4: swap the body to
///   `return AskRemoteDataSourceImpl(baseUrl: ref.watch(askBaseUrlProvider));`
/// That one line is the entire payoff of building stub-first — nothing above
/// this provider changes.
final askDataSourceProvider = Provider<AskDataSource>((ref) {
  return AskStubDataSource();
});

/// The Q&A repository (datasource → Either<Failure, AskAnswer>).
final askRepositoryProvider = Provider<AskRepository>((ref) {
  return AskRepositoryImpl(ref.watch(askDataSourceProvider));
});

/// Chat state + the send action for the dialog.
final askChatProvider =
    StateNotifierProvider<AskChatNotifier, AskChatState>((ref) {
  return AskChatNotifier(ref.watch(askRepositoryProvider));
});

/// Owns the chat transcript and drives the one network call per question.
class AskChatNotifier extends StateNotifier<AskChatState> {
  AskChatNotifier(this._repository) : super(const AskChatState());

  final AskRepository _repository;

  /// Send a question: optimistically append the user's turn, call the repo,
  /// then append the answer (or surface an error). History is empty in the
  /// prototype (design §5.8).
  Future<void> send(String question) async {
    final text = question.trim();
    if (text.isEmpty || state.isLoading) return;

    // 1) Add the user's message and enter the loading state.
    state = state.copyWith(
      messages: [
        ...state.messages,
        ChatMessage(role: ChatRole.user, content: text),
      ],
      isLoading: true,
      error: null,
    );

    // 2) Ask. (Prototype sends no history.)
    final result = await _repository.ask(text);

    // 3) Fold the result back into the transcript.
    state = result.fold(
      (failure) => state.copyWith(
        isLoading: false,
        error: failure.userMessage,
      ),
      (answer) => state.copyWith(
        isLoading: false,
        messages: [
          ...state.messages,
          ChatMessage(
            role: ChatRole.assistant,
            content: answer.answer,
            citations: answer.citations,
          ),
        ],
      ),
    );
  }

  /// Clear the transcript — the "New chat" affordance.
  void clear() => state = const AskChatState();
}
