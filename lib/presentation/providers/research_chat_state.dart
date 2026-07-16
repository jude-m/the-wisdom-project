import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/api_error_type.dart';
import '../../domain/entities/research/chat_message.dart';
import '../../domain/entities/research/research_mode.dart';

part 'research_chat_state.freezed.dart';

/// UI state for the Q&A chat window.
@freezed
class ResearchChatState with _$ResearchChatState {
  // Private ctor so the class can carry getters ([userTurnCount], …).
  const ResearchChatState._();

  /// Hard per-chat length cap (user decision 2026-07-14): each question is
  /// sent with the full prior transcript as history, so capping turns keeps
  /// the token cost of a follow-up bounded. Reaching the cap disables the
  /// input and shows a "start a new chat" banner.
  static const maxUserTurns = 5;

  const factory ResearchChatState({
    /// Id of the saved chat this transcript belongs to, or null for a fresh
    /// chat that hasn't sent its first message yet (unsent chats are never
    /// persisted, so "New chat" spam can't pollute the Recent list).
    String? sessionId,

    /// Full transcript, oldest first. Assistant turns carry their citations.
    @Default([]) List<ChatMessage> messages,

    /// True while a question is in flight — disables the send button (a real
    /// client-side cost guardrail) and shows the busy row.
    @Default(false) bool isLoading,

    /// The Fast/Thinking mode the in-flight request is running under, pinned at
    /// send time. The busy row's label ("Answering…" / "Thinking…") reads THIS,
    /// not the live global mode, so flipping the switch mid-request can't
    /// relabel the answer already running (mirrors how send() pins the mode it
    /// sends to the backend). Only meaningful while [isLoading]; not persisted —
    /// openChat restores it from the pending-session map, defaulting to fast.
    @Default(ResearchMode.fast) ResearchMode inFlightMode,

    /// User-facing error message from the last attempt, or null. Kept as an
    /// English fallback / for logging; the chat view prefers [errorType] and
    /// re-localises by category (see research_error_messages.dart).
    String? error,

    /// Category of the last error, or null. Drives the localised message and
    /// whether the chat view offers a Retry (see [ApiErrorType]).
    ApiErrorType? errorType,
  }) = _ResearchChatState;

  /// Number of questions the user has asked in this chat.
  int get userTurnCount => messages.where((m) => m.isUser).length;

  /// True once the chat has used all [maxUserTurns] questions — the UI swaps
  /// the input row for the limit banner. Retry of a failed last question is
  /// still allowed (retry re-runs the existing turn, it doesn't add one).
  bool get isAtTurnLimit => userTurnCount >= maxUserTurns;
}
