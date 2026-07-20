import '../../domain/entities/research/research_answer.dart';
import '../../domain/entities/research/research_filters.dart';
import '../../domain/entities/research/research_mode.dart';
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

  /// How long to wait, per mode. The two differ by a lot: Fast answers in ~10s,
  /// while Thinking legitimately reasons for minutes (one measured run took 289s
  /// on the top rung).
  ///
  /// One shared ceiling served neither. At 120s for both, a real Thinking answer
  /// — already generated, already charged against the daily quota — was thrown
  /// away unseen, and the user got an error inviting a retry that would spend the
  /// quota again. Sizing that ceiling up for Thinking instead would leave a hung
  /// Fast call sitting for minutes before it reported anything.
  ///
  /// So Thinking gets a deliberately generous backstop: it is there to catch a
  /// wedged request, NOT to bound a slow one. An answer we have paid for is worth
  /// waiting for; the cure for slowness is the server's reasoning cap, not a
  /// stopwatch on the client.
  ///
  /// 5 minutes because it must clear the slowest run we have actually seen — 289s,
  /// uncapped — with room to spare. Sized to the *capped* time instead, it would
  /// silently start binning answers the moment someone raised
  /// `config.THINKING_LEVEL`, which is precisely when you are experimenting and
  /// least want to lose the result you just paid for.
  static Duration _timeoutFor(ResearchMode mode) => switch (mode) {
        ResearchMode.fast => const Duration(seconds: 60),
        ResearchMode.thinking => const Duration(minutes: 5),
      };

  @override
  Future<ResearchAnswer> research(
    String question, {
    List<ChatMessage> history = const [],
    ResearchFilters? filters,
    ResearchMode mode = ResearchMode.fast,
  }) async {
    final json = await _client.postJson('/research', {
      'question': question,
      // §7: history carries role + content only.
      'history': history.map((m) => m.toHistoryJson()).toList(),
      if (filters != null) 'filters': filters.toJson(),
      // "fast" | "thinking" — the backend maps it to a model tier. Always sent;
      // an older backend that doesn't know the field just ignores it.
      'mode': mode.wire,
    }, timeout: _timeoutFor(mode));
    return ResearchAnswer.fromJson(json);
  }
}
