import 'package:freezed_annotation/freezed_annotation.dart';

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
  }) = _ChatSummary;

  /// Create from JSON for local storage.
  factory ChatSummary.fromJson(Map<String, dynamic> json) =>
      _$ChatSummaryFromJson(json);
}
