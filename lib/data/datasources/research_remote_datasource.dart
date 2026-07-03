import '../../domain/entities/research/research_answer.dart';
import '../../domain/entities/research/research_filters.dart';
import '../../domain/entities/research/chat_message.dart';
import 'api_client.dart';
import 'research_datasource.dart';

/// Real [ResearchDataSource] — POSTs to the stateless `/research` backend (design §7).
///
/// This is now pure JSON↔entity: transport concerns (base URL, timeout,
/// app-token header, status → typed exceptions) live in the injected
/// [ApiClient]. Errors it throws ([ApiException]) are turned into a `Failure`
/// by `ResearchRepositoryImpl` via `mapResearchError`.
///
/// Note: unlike the web content server (same-origin `''`), the [ApiClient] here
/// is built with an absolute base URL because native talks to it too.
class ResearchRemoteDataSourceImpl implements ResearchDataSource {
  final ApiClient _client;

  ResearchRemoteDataSourceImpl({required ApiClient client}) : _client = client;

  @override
  Future<ResearchAnswer> research(
    String question, {
    List<ChatMessage> history = const [],
    ResearchFilters? filters,
  }) async {
    final json = await _client.postJson('/research', {
      'question': question,
      // §7: history carries role + content only.
      'history': history.map((m) => m.toHistoryJson()).toList(),
      if (filters != null) 'filters': filters.toJson(),
    });
    return ResearchAnswer.fromJson(json);
  }
}
