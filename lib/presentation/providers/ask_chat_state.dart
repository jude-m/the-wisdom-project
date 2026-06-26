import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/ask/chat_message.dart';

part 'ask_chat_state.freezed.dart';

/// UI state for the Q&A chat window.
@freezed
class AskChatState with _$AskChatState {
  const factory AskChatState({
    /// Full transcript, oldest first. Assistant turns carry their citations.
    @Default([]) List<ChatMessage> messages,

    /// True while a question is in flight — disables the send button (a real
    /// client-side cost guardrail) and shows a "thinking…" row.
    @Default(false) bool isLoading,

    /// User-facing error from the last attempt, or null.
    String? error,
  }) = _AskChatState;
}
