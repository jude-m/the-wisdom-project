import '../../domain/entities/ask/ask_answer.dart';
import '../../domain/entities/ask/ask_filters.dart';
import '../../domain/entities/ask/chat_message.dart';
import 'api_client.dart';
import 'ask_datasource.dart';

/// Real [AskDataSource] — POSTs to the stateless `/ask` backend (design §7).
///
/// This is now pure JSON↔entity: transport concerns (base URL, timeout,
/// app-token header, status → typed exceptions) live in the injected
/// [ApiClient]. Errors it throws ([ApiException]) are turned into a `Failure`
/// by `AskRepositoryImpl` via `mapAskError`.
///
/// Note: unlike the web content server (same-origin `''`), the [ApiClient] here
/// is built with an absolute base URL because native talks to it too.
class AskRemoteDataSourceImpl implements AskDataSource {
  final ApiClient _client;

  AskRemoteDataSourceImpl({required ApiClient client}) : _client = client;

  @override
  Future<AskAnswer> ask(
    String question, {
    List<ChatMessage> history = const [],
    AskFilters? filters,
  }) async {
    final json = await _client.postJson('/ask', {
      'question': question,
      // §7: history carries role + content only.
      'history': history.map((m) => m.toHistoryJson()).toList(),
      if (filters != null) 'filters': filters.toJson(),
    });
    return AskAnswer.fromJson(json);
  }
}
