import 'package:freezed_annotation/freezed_annotation.dart';

import 'research_mode.dart';

part 'chat_summary.freezed.dart';
part 'chat_summary.g.dart';

/// One row in the "Recent" chat list — the lightweight index entry for a
/// saved research chat. The full transcript is stored separately (one key
/// per chat) so listing recents never parses 25 transcripts; see
/// `ChatHistoryRepository`.
@freezed
class ChatSummary with _$ChatSummary {
  const factory ChatSummary({
    /// Stable id — also the suffix of the transcript's storage key.
    required String id,

    /// Display title: the chat's first user question (ellipsized by the UI).
    required String title,

    /// Last activity — drives newest-first ordering and the relative
    /// timestamp ("2 hours ago") in the list.
    required DateTime updatedAt,

    /// The Fast/Thinking tier this chat last sent a question under, so
    /// reopening it restores the same tier (a chat is remembered per-tier,
    /// unlike the "always Fast" new-chat default). Defaults to
    /// [ResearchMode.fast], which also covers chats saved before this field
    /// existed (the key is simply absent → Fast on read).
    @Default(ResearchMode.fast) ResearchMode mode,
  }) = _ChatSummary;

  /// Create from JSON for local storage.
  factory ChatSummary.fromJson(Map<String, dynamic> json) =>
      _$ChatSummaryFromJson(json);
}
