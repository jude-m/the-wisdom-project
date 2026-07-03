import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/api_client.dart';
import '../../data/datasources/research_datasource.dart';
import '../../data/datasources/research_remote_datasource.dart';
import '../../data/repositories/research_repository_impl.dart';
import '../../domain/entities/research/chat_message.dart';
import '../../domain/repositories/research_repository.dart';
import 'research_chat_state.dart';

/// Where the `/research` backend lives. Native needs an absolute URL (unlike the
/// web content server's same-origin '').
///
/// Defaults to the local `research_server` dev instance on :8081 (8080 is taken by
/// the Dart web content server). Override at build/run time with
/// `--dart-define=RESEARCH_BASE_URL=https://research.thewisdomproject.app`.
/// On the Android emulator, the host machine is reachable as 10.0.2.2.
final researchBaseUrlProvider = Provider<String>(
  (ref) => const String.fromEnvironment(
    'RESEARCH_BASE_URL',
    defaultValue: 'http://localhost:8081',
  ),
);

/// Optional shared secret sent as the `X-App-Token` header (review Finding #2 —
/// the money endpoint's abuse gate). Unset for local dev; provide with
/// `--dart-define=RESEARCH_APP_TOKEN=…` to match the backend's `RESEARCH_APP_TOKEN`.
/// Empty → null (no header), so the open local backend still works.
final researchAppTokenProvider = Provider<String?>((ref) {
  const token = String.fromEnvironment('RESEARCH_APP_TOKEN');
  return token.isEmpty ? null : token;
});

/// The Q&A data source — always the real HTTP datasource over an [ApiClient]
/// (which owns the timeout, the app-token header, and status → typed
/// exceptions).
///
/// There is no offline/stub fallback: if the backend is unset or unreachable,
/// the call fails and `mapResearchError` turns it into a clean, localised
/// "can't reach the answer service" message with a Retry (see
/// research_error_messages.dart). A blank base URL therefore just reads as the
/// service being down — the honest signal, not a fake answer.
final researchDataSourceProvider = Provider<ResearchDataSource>((ref) {
  final client = ApiClient(
    baseUrl: ref.watch(researchBaseUrlProvider),
    appToken: ref.watch(researchAppTokenProvider),
  );
  return ResearchRemoteDataSourceImpl(client: client);
});

/// The Q&A repository (datasource → Either<Failure, ResearchAnswer>).
final researchRepositoryProvider = Provider<ResearchRepository>((ref) {
  return ResearchRepositoryImpl(ref.watch(researchDataSourceProvider));
});

/// Chat state + the send action for the dialog.
final researchChatProvider =
    StateNotifierProvider<ResearchChatNotifier, ResearchChatState>((ref) {
  return ResearchChatNotifier(ref.watch(researchRepositoryProvider));
});

/// Owns the chat transcript and drives the one network call per question.
class ResearchChatNotifier extends StateNotifier<ResearchChatState> {
  ResearchChatNotifier(this._repository) : super(const ResearchChatState());

  final ResearchRepository _repository;

  /// Send a question: optimistically append the user's turn, call the repo,
  /// then append the answer (or surface an error). History is empty in the
  /// prototype (design §5.8).
  Future<void> send(String question) async {
    final text = question.trim();
    if (text.isEmpty || state.isLoading) return;

    // Add the user's message and enter the loading state (clearing any prior
    // error), then run the request.
    state = state.copyWith(
      messages: [
        ...state.messages,
        ChatMessage(role: ChatRole.user, content: text),
      ],
      isLoading: true,
      error: null,
      errorType: null,
    );
    await _run(text);
  }

  /// Retry the last question after a retriable failure — re-runs the call
  /// WITHOUT appending a duplicate user turn (on failure the transcript's last
  /// message is the unanswered question). No-op if that isn't the case.
  Future<void> retry() async {
    if (state.isLoading || state.messages.isEmpty) return;
    final last = state.messages.last;
    if (!last.isUser) return;

    state = state.copyWith(isLoading: true, error: null, errorType: null);
    await _run(last.content);
  }

  /// Run one `/research` call for [text] and fold the result into the transcript.
  /// Shared by [send] and [retry].
  Future<void> _run(String text) async {
    // Prototype sends no history (design §5.8).
    final result = await _repository.research(text);

    state = result.fold(
      (failure) => state.copyWith(
        isLoading: false,
        error: failure.userMessage, // English fallback; UI re-localises by type
        errorType: failure.apiType,
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
  void clear() => state = const ResearchChatState();
}
