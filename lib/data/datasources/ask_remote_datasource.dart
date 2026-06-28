import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/entities/ask/ask_answer.dart';
import '../../domain/entities/ask/ask_filters.dart';
import '../../domain/entities/ask/chat_message.dart';
import 'ask_datasource.dart';

/// Real [AskDataSource] — POSTs to the stateless `/ask` backend (design §7).
///
/// Mirrors the shape of `FTSRemoteDataSourceImpl` (an `http.Client` + a base
/// URL). NOT wired yet: `ask_provider.dart` uses `AskStubDataSource` until the
/// Python service exists; flip one line there to switch over.
///
/// Note: unlike the web content server (same-origin `''`), this needs an
/// absolute [baseUrl] because native talks to it too.
class AskRemoteDataSourceImpl implements AskDataSource {
  final http.Client _client;
  final String _baseUrl;

  /// Generous ceiling for one grounded answer. The capable flash models can take
  /// ~35–45s for a long answer (and the backend may try a fallback rung or two
  /// first when the primary model is overloaded), so we wait rather than fail a
  /// good answer. Past this we surface a clear "took too long" message instead
  /// of hanging indefinitely.
  static const _timeout = Duration(seconds: 120);

  AskRemoteDataSourceImpl({required String baseUrl, http.Client? client})
      : _baseUrl = baseUrl,
        _client = client ?? http.Client();

  @override
  Future<AskAnswer> ask(
    String question, {
    List<ChatMessage> history = const [],
    AskFilters? filters,
  }) async {
    final response = await _client
        .post(
          Uri.parse('$_baseUrl/ask'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'question': question,
            // §7: history carries role + content only.
            'history': history.map((m) => m.toHistoryJson()).toList(),
            if (filters != null) 'filters': filters.toJson(),
          }),
        )
        .timeout(
          _timeout,
          onTimeout: () => throw TimeoutException(
            'The answer took longer than ${_timeout.inSeconds}s. The model may '
            'be busy — please try again.',
            _timeout,
          ),
        );

    if (response.statusCode != 200) {
      throw Exception('ask failed (${response.statusCode}): ${response.body}');
    }

    return AskAnswer.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}
