import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/key_value_store_provider.dart';
import '../../data/datasources/api_client.dart';
import '../../data/datasources/research_datasource.dart';
import '../../data/datasources/research_remote_datasource.dart';
import '../../data/repositories/chat_history_repository_impl.dart';
import '../../data/repositories/research_repository_impl.dart';
import '../../domain/entities/research/chat_message.dart';
import '../../domain/entities/research/chat_summary.dart';
import '../../domain/entities/research/research_answer.dart';
import '../../domain/entities/research/research_mode.dart';
import '../../domain/repositories/chat_history_repository.dart';
import '../../domain/repositories/research_repository.dart';
import 'research_chat_state.dart';
import 'research_mode_provider.dart';

/// Where the `/research` backend lives. Native needs an absolute URL (unlike the
/// web content server's same-origin '').
///
/// Defaults to the local `research_server` dev instance on :8082 (8081 is taken
/// by the Dart content server). Override at build/run time with
/// `--dart-define=RESEARCH_BASE_URL=https://research.thewisdomproject.app`.
/// On the Android emulator, the host machine is reachable as 10.0.2.2.
final researchBaseUrlProvider = Provider<String>(
  (ref) => const String.fromEnvironment(
    'RESEARCH_BASE_URL',
    defaultValue: 'http://localhost:8082',
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

/// Locally saved chats — the "Recent" list's storage (SharedPreferences via
/// the app-wide [KeyValueStore], max 25 chats).
final chatHistoryRepositoryProvider = Provider<ChatHistoryRepository>((ref) {
  return ChatHistoryRepositoryImpl(ref.watch(keyValueStoreProvider));
});

/// Summaries for the "Recent" panel, newest first. Re-read whenever
/// [ResearchChatNotifier] saves or deletes a chat (it invalidates this).
final chatSummariesProvider = FutureProvider<List<ChatSummary>>((ref) {
  return ref.watch(chatHistoryRepositoryProvider).getSummaries();
});

/// Chat state + the send action for the Research section.
final researchChatProvider =
    StateNotifierProvider<ResearchChatNotifier, ResearchChatState>((ref) {
  return ResearchChatNotifier(
    ref,
    ref.watch(researchRepositoryProvider),
    ref.watch(chatHistoryRepositoryProvider),
  );
});

/// Owns the active chat transcript, drives the one network call per question,
/// and keeps the saved-chats store in sync (create on first send, persist
/// after every turn, open/delete from the Recent panel).
class ResearchChatNotifier extends StateNotifier<ResearchChatState> {
  ResearchChatNotifier(this._ref, this._repository, this._historyRepo)
      : super(const ResearchChatState());

  final Ref _ref;
  final ResearchRepository _repository;
  final ChatHistoryRepository _historyRepo;

  /// Sessions with a `/research` call still in flight, mapped to the mode that
  /// call is running under. Lets [openChat] restore both the loading state AND
  /// the correct busy label ("Answering…" / "Thinking…") when the user
  /// navigates away from a waiting chat and back — otherwise the reopened chat
  /// would re-enable send (a second question could interleave with the pending
  /// answer) and could mislabel the wait.
  final Map<String, ResearchMode> _pendingSessions = {};

  /// Send a question: optimistically append the user's turn, call the repo,
  /// then append the answer (or surface an error). Prior turns go along as
  /// history so follow-ups have context — bounded by the per-chat turn cap
  /// ([ResearchChatState.maxUserTurns]), which also gates sending here.
  Future<void> send(String question) async {
    final text = question.trim();
    if (text.isEmpty || state.isLoading || state.isAtTurnLimit) return;

    // First send of a fresh chat mints the session id; the chat only ever
    // reaches storage once it has a message, so empty chats never appear
    // in the Recent list. Minted/captured BEFORE the awaits below: the
    // user can open or start another chat while the persist write yields,
    // and this question must be sent with — and filed under — the chat it
    // was typed in, not whatever is live when the answer arrives.
    final sessionId =
        state.sessionId ?? DateTime.now().microsecondsSinceEpoch.toString();
    final history = state.messages; // Prior turns; [text] rides separately.
    // The active tier, captured (like [sessionId]/[history]) before the awaits
    // so a mid-flight switch flip can't change what this question is filed under.
    final mode = _ref.read(researchModeProvider);

    state = state.copyWith(
      sessionId: sessionId,
      messages: [
        ...state.messages,
        ChatMessage(role: ChatRole.user, content: text),
      ],
      isLoading: true,
      inFlightMode: mode,
      error: null,
      errorType: null,
    );
    // Persist the question right away — it creates/refreshes the Recent
    // entry and survives a crash or a chat switch while the answer is
    // still in flight.
    await _persist(mode);
    await _run(text, sessionId: sessionId, history: history, mode: mode);
  }

  /// Retry the last question after a retriable failure — re-runs the call
  /// WITHOUT appending a duplicate user turn (on failure the transcript's last
  /// message is the unanswered question). No-op if that isn't the case.
  Future<void> retry() async {
    if (state.isLoading || state.messages.isEmpty) return;
    final last = state.messages.last;
    if (!last.isUser) return;

    final mode = _ref.read(researchModeProvider);
    state = state.copyWith(
      isLoading: true,
      inFlightMode: mode,
      error: null,
      errorType: null,
    );
    // No await between reading state and _run here, so capturing inline is
    // race-free (unlike send, which persists first).
    await _run(
      last.content,
      sessionId: state.sessionId,
      history: state.messages.sublist(0, state.messages.length - 1),
      mode: mode,
    );
  }

  /// Run one `/research` call for [text] and fold the result into the
  /// transcript. Shared by [send] and [retry], whose job it is to capture
  /// [sessionId] (the chat the question belongs to), [history] (everything
  /// before the in-flight question — at most 4 Q&A pairs given the turn cap;
  /// citations are stripped on the wire by ChatMessage.toHistoryJson) and
  /// [mode] (the Fast/Thinking tier active at send time) before any await: the
  /// live state may already be a different chat by the time this runs.
  Future<void> _run(
    String text, {
    required String? sessionId,
    required List<ChatMessage> history,
    required ResearchMode mode,
  }) async {
    if (sessionId != null) _pendingSessions[sessionId] = mode;
    final result =
        await _repository.research(text, history: history, mode: mode);
    if (sessionId != null) _pendingSessions.remove(sessionId);

    // The user may have opened another chat (or started a new one) while the
    // answer was in flight. File a successful answer into the chat it belongs
    // to instead of the live transcript; drop errors — reopening that chat
    // shows the still-unanswered question with a Retry affordance.
    if (state.sessionId != sessionId) {
      final answer = result.fold<ResearchAnswer?>((_) => null, (a) => a);
      if (answer != null && sessionId != null) {
        final stored = await _historyRepo.getMessages(sessionId);
        // A chat that reads back empty was deleted while the answer was in
        // flight (send() persists the question before calling out, so a live
        // chat always has at least that turn). Filing the answer would
        // resurrect the deleted chat — with the answer prose as its title.
        if (stored.isEmpty) return;
        await _saveTranscript(sessionId, [
          ...stored,
          ChatMessage(
            role: ChatRole.assistant,
            content: answer.answer,
            citations: answer.citations,
            model: answer.model,
          ),
        ], mode);
      }
      return;
    }

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
            model: answer.model,
          ),
        ],
      ),
    );
    // Errors are transient UI state — only a new answer is worth a rewrite
    // (the question itself was persisted in send()).
    if (result.isRight()) await _persist(mode);
  }

  /// Start a fresh chat — the "New chat" affordance. The previous chat is
  /// already persisted turn-by-turn, so nothing to save here. Always resets the
  /// tier to [ResearchMode.fast]: a new chat begins on Fast regardless of what
  /// the last chat used (the per-chat tier only comes back when that chat is
  /// reopened — see [openChat]).
  void newChat() {
    state = const ResearchChatState();
    _ref.read(researchModeProvider.notifier).set(ResearchMode.fast);
  }

  /// Open a saved chat from the Recent panel. Any in-flight answer for the
  /// previous chat keeps running and is filed to its own transcript (see
  /// [_run]'s session guard). Restores the chat's last-used tier
  /// ([ChatSummary.mode]) into the header, so reopening a Thinking chat comes
  /// back on Thinking rather than the previous chat's tier.
  Future<void> openChat(ChatSummary summary) async {
    final id = summary.id;
    if (state.sessionId == id) return;
    _ref.read(researchModeProvider.notifier).set(summary.mode);
    final messages = await _historyRepo.getMessages(id);
    final pendingMode = _pendingSessions[id];
    state = ResearchChatState(
      sessionId: id,
      messages: messages,
      // Reopening a chat whose answer is still in flight: keep the busy row up
      // and send disabled — the answer folds in when it arrives — and label it
      // with the mode that request is actually running under.
      isLoading: pendingMode != null,
      inFlightMode: pendingMode ?? ResearchMode.fast,
    );
  }

  /// Delete a saved chat; clears the canvas if it was the open one.
  Future<void> deleteChat(String id) async {
    await _historyRepo.deleteChat(id);
    _ref.invalidate(chatSummariesProvider);
    if (state.sessionId == id) newChat();
  }

  /// Write the live transcript to storage under its session id, tagged [mode].
  Future<void> _persist(ResearchMode mode) async {
    final id = state.sessionId;
    if (id == null || state.messages.isEmpty) return;
    await _saveTranscript(id, state.messages, mode);
  }

  /// Save [messages] as chat [id] (title = first user question), tagged with
  /// [mode], and refresh the Recent panel. [mode] is passed in, not read from
  /// `state`: [_run]'s background path saves a chat that isn't the live one.
  Future<void> _saveTranscript(
      String id, List<ChatMessage> messages, ResearchMode mode) async {
    final firstUserTurn =
        messages.firstWhere((m) => m.isUser, orElse: () => messages.first);
    await _historyRepo.saveChat(
      ChatSummary(
        id: id,
        title: firstUserTurn.content,
        updatedAt: DateTime.now(),
        // Record the tier the last question was actually sent under, so
        // reopening this chat restores that tier — see [openChat].
        mode: mode,
      ),
      messages,
    );
    _ref.invalidate(chatSummariesProvider);
  }
}
