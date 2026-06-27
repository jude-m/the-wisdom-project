import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/ask_datasource.dart';
import '../../data/datasources/ask_remote_datasource.dart';
import '../../data/datasources/ask_stub_datasource.dart';
import '../../data/repositories/ask_repository_impl.dart';
import '../../domain/entities/ask/chat_message.dart';
import '../../domain/repositories/ask_repository.dart';
import 'ask_chat_state.dart';

/// Where the `/ask` backend lives. Native needs an absolute URL (unlike the
/// web content server's same-origin '').
///
/// Defaults to the local `ask_server` dev instance on :8081 (8080 is taken by
/// the Dart web content server). Override at build/run time with
/// `--dart-define=ASK_BASE_URL=https://ask.thewisdomproject.app`.
/// On the Android emulator, the host machine is reachable as 10.0.2.2.
final askBaseUrlProvider = Provider<String>(
  (ref) => const String.fromEnvironment(
    'ASK_BASE_URL',
    defaultValue: 'http://localhost:8081',
  ),
);

/// The Q&A data source.
///
/// - Base URL configured → the real HTTP datasource (talks to `ask_server`).
/// - Base URL blank (`--dart-define=ASK_BASE_URL=`) → the canned stub, so the
///   dialog still works with no backend running (capability gate, plan
///   cross-cutting #1).
///
/// Swapping these is the whole payoff of building stub-first: nothing above this
/// provider (repository, notifier, UI) changes.
final askDataSourceProvider = Provider<AskDataSource>((ref) {
  final baseUrl = ref.watch(askBaseUrlProvider);
  if (baseUrl.isEmpty) {
    return AskStubDataSource();
  }
  return AskRemoteDataSourceImpl(baseUrl: baseUrl);
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
