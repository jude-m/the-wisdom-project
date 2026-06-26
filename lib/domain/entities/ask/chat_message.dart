import 'package:freezed_annotation/freezed_annotation.dart';
import 'citation.dart';

part 'chat_message.freezed.dart';
part 'chat_message.g.dart';

/// Role values for [ChatMessage.role]. Match the `/ask` history contract
/// (design doc §7): "user" | "assistant". Kept as plain strings so they map
/// straight onto the wire format with no enum ceremony.
abstract class ChatRole {
  static const String user = 'user';
  static const String assistant = 'assistant';
}

/// One turn in the chat transcript.
///
/// The `/ask` `history` array only carries `{role, content}` (§7); [citations]
/// is a UI-only field attached to assistant turns and is intentionally NOT sent
/// back as history — see [toHistoryJson].
@freezed
class ChatMessage with _$ChatMessage {
  const ChatMessage._();

  const factory ChatMessage({
    /// "user" | "assistant" — see [ChatRole].
    required String role,
    required String content,

    /// Sources grounding an assistant turn. Empty for user turns.
    @Default([]) List<Citation> citations,
  }) = _ChatMessage;

  factory ChatMessage.fromJson(Map<String, dynamic> json) =>
      _$ChatMessageFromJson(json);

  bool get isUser => role == ChatRole.user;

  /// Wire shape for the `/ask` `history` array — role + content only.
  Map<String, dynamic> toHistoryJson() => {'role': role, 'content': content};
}
