import '../entities/research/chat_message.dart';
import '../entities/research/chat_summary.dart';

/// Repository interface for locally saved research chats (the "Recent"
/// list in the Research section).
///
/// Storage is split in two so listing stays cheap:
/// - a small index of [ChatSummary]s (id + title + updatedAt), newest first
/// - one transcript per chat, loaded only when that chat is opened
///
/// Like `RecentSearchesRepository`, this is local-only persistence with
/// plain Futures — storage/parse problems degrade to empty results rather
/// than surfacing as Failures.
abstract class ChatHistoryRepository {
  /// All saved chat summaries, newest first.
  Future<List<ChatSummary>> getSummaries();

  /// The full transcript for chat [id], oldest turn first.
  /// Returns an empty list if the chat is missing or unreadable.
  Future<List<ChatMessage>> getMessages(String id);

  /// Insert or update a chat: the summary moves to the top of the index and
  /// the transcript is (re)written. When the index exceeds the cap, the
  /// oldest chats are evicted together with their transcripts.
  Future<void> saveChat(ChatSummary summary, List<ChatMessage> messages);

  /// Remove chat [id] — both its index entry and its transcript.
  Future<void> deleteChat(String id);
}
