import '../../core/storage/key_value_store.dart';
import '../../core/storage/storage_keys.dart';
import '../../domain/entities/research/chat_message.dart';
import '../../domain/entities/research/chat_summary.dart';
import '../../domain/repositories/chat_history_repository.dart';

/// [ChatHistoryRepository] backed by the app's [KeyValueStore]
/// (SharedPreferences in production — same pattern as recent searches).
///
/// Two-part scheme so the "Recent" list never parses transcripts:
/// - [StorageKeys.researchChatIndex]: JSON array of [ChatSummary]s, newest first
/// - one [StorageKeys.researchChatPrefix]`<id>` key per transcript (full
///   [ChatMessage] list, citations included, so chips survive restarts)
///
/// Every write goes through [saveChat]/[deleteChat], which keep the index
/// and the per-chat keys consistent: evicting past [_maxChats] also removes
/// the evicted transcripts, so storage can't accumulate orphans. Mutations
/// are queued ([_serialized]) so overlapping saves can't drop each other's
/// index entry.
class ChatHistoryRepositoryImpl implements ChatHistoryRepository {
  static const _indexKey = StorageKeys.researchChatIndex;
  static const _chatKeyPrefix = StorageKeys.researchChatPrefix;
  static const _maxChats = 25;

  final KeyValueStore _store;

  /// Tail of the mutation queue — see [_serialized].
  Future<void> _lastWrite = Future.value();

  ChatHistoryRepositoryImpl(this._store);

  static String _chatKey(String id) => '$_chatKeyPrefix$id';

  /// Runs [action] after every previously queued mutation has finished.
  ///
  /// [saveChat] and [deleteChat] are read-modify-write cycles against the
  /// index with awaits in the middle, so two overlapping calls — an answer
  /// being filed to a background chat while a fresh chat's first send
  /// persists — could read the same index snapshot, and the later write
  /// would silently drop the earlier one's entry, orphaning that
  /// transcript. Queueing makes each cycle atomic.
  Future<void> _serialized(Future<void> Function() action) {
    final run = _lastWrite.then((_) => action());
    // A failed action must not wedge the queue shut for the ones behind it.
    _lastWrite = run.catchError((_) {});
    return run;
  }

  @override
  Future<List<ChatSummary>> getSummaries() async => _readIndex();

  @override
  Future<List<ChatMessage>> getMessages(String id) async {
    // getJsonList already removes a corrupted entry and returns null; a
    // malformed element inside the list lands in the catch below.
    final list = _store.getJsonList(_chatKey(id));
    if (list == null) return [];
    try {
      return list
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Unparseable transcript: delete the whole chat — deleteChat also
      // drops the index entry, which would otherwise linger as a phantom
      // "Recent" row that opens an empty canvas.
      await deleteChat(id);
      return [];
    }
  }

  @override
  Future<void> saveChat(ChatSummary summary, List<ChatMessage> messages) =>
      _serialized(() async {
        final index = _readIndex()
          // Upsert: drop any old entry for this chat, re-insert at the top.
          ..removeWhere((s) => s.id == summary.id)
          ..insert(0, summary);

        // Evict beyond the cap — index entry AND transcript, oldest first.
        for (final evicted in index.skip(_maxChats)) {
          await _store.remove(_chatKey(evicted.id));
        }
        final limited = index.take(_maxChats).toList();

        await _store.setJson(
            _chatKey(summary.id), messages.map((m) => m.toJson()).toList());
        await _writeIndex(limited);
      });

  @override
  Future<void> deleteChat(String id) => _serialized(() async {
        await _store.remove(_chatKey(id));
        final index = _readIndex()..removeWhere((s) => s.id == id);
        await _writeIndex(index);
      });

  /// Decode the index, degrading to empty (and clearing the corrupted key)
  /// on any parse failure — matches RecentSearchesRepositoryImpl.
  List<ChatSummary> _readIndex() {
    final list = _store.getJsonList(_indexKey);
    if (list == null) return [];
    try {
      return list
          .map((e) => ChatSummary.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      _store.remove(_indexKey);
      return [];
    }
  }

  Future<void> _writeIndex(List<ChatSummary> index) =>
      _store.setJson(_indexKey, index.map((s) => s.toJson()).toList());
}
