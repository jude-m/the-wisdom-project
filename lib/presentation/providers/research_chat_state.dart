import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/api_error_type.dart';
import '../../domain/entities/research/chat_message.dart';

part 'research_chat_state.freezed.dart';

/// UI state for the Q&A chat window.
@freezed
class ResearchChatState with _$ResearchChatState {
  const factory ResearchChatState({
    /// Full transcript, oldest first. Assistant turns carry their citations.
    @Default([]) List<ChatMessage> messages,

    /// True while a question is in flight — disables the send button (a real
    /// client-side cost guardrail) and shows a "thinking…" row.
    @Default(false) bool isLoading,

    /// User-facing error message from the last attempt, or null. Kept as an
    /// English fallback / for logging; the dialog prefers [errorType] and
    /// re-localises by category (see research_error_messages.dart).
    String? error,

    /// Category of the last error, or null. Drives the localised message and
    /// whether the dialog offers a Retry (see [ApiErrorType]).
    ApiErrorType? errorType,
  }) = _ResearchChatState;
}
