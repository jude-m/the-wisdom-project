import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/bjt_document.dart';
import '../domain/bjt_document_parser.dart';
import '../domain/fts_models.dart';

/// Base URL of the existing Dart shelf server (run `dart run bin/server.dart`
/// from server/). Overridable at build time:
///   jaspr serve --dart-define=WISDOM_API=http://host:port
const wisdomApiBaseUrl =
    String.fromEnvironment('WISDOM_API', defaultValue: 'http://localhost:8080');

/// Thin HTTP client over the wisdom shelf API.
///
/// Platform-neutral on purpose: the SSR server uses it to preload documents
/// (dart:io HTTP) and the hydrated browser island uses the same code (fetch).
/// This mirrors the contract of the app's remote datasources
/// (lib/data/datasources/*_remote_datasource.dart).
class WisdomApiClient {
  WisdomApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// GET /api/text/`fileId` → raw BJT JSON map.
  Future<Map<String, dynamic>> fetchTextJson(String fileId) async {
    final response =
        await _client.get(Uri.parse('$wisdomApiBaseUrl/api/text/$fileId'));
    _checkResponse(response, 'Load text $fileId');
    return json.decode(response.body) as Map<String, dynamic>;
  }

  /// GET /api/text/`fileId`, parsed into the domain entity.
  Future<BJTDocument> fetchDocument(String fileId) async {
    return BJTDocumentParser.parseDocument(fileId, await fetchTextJson(fileId));
  }

  /// GET /api/fts/search — same params as the app's FTSRemoteDataSourceImpl.
  Future<List<FTSMatch>> searchFullText(
    String query, {
    Set<String> editionIds = const {'bjt'},
    bool isExactMatch = false,
    bool isPhraseSearch = true,
    bool isAnywhereInText = false,
    int proximityDistance = 10,
    String? language,
    int limit = 50,
    int offset = 0,
  }) async {
    final uri = Uri.parse('$wisdomApiBaseUrl/api/fts/search').replace(
      queryParameters: {
        'query': query,
        'editionIds': editionIds.join(','),
        'isExactMatch': isExactMatch.toString(),
        'isPhraseSearch': isPhraseSearch.toString(),
        'isAnywhereInText': isAnywhereInText.toString(),
        'proximityDistance': proximityDistance.toString(),
        if (language != null) 'language': language,
        'limit': limit.toString(),
        'offset': offset.toString(),
      },
    );

    final response = await _client.get(uri);
    _checkResponse(response, 'FTS search');

    final data = json.decode(response.body) as Map<String, dynamic>;
    final results = data['results'] as List<dynamic>;
    return results
        .map((r) => FTSMatch.fromMap(
              r as Map<String, dynamic>,
              (r)['editionId'] as String,
            ))
        .toList();
  }

  void _checkResponse(http.Response response, String operation) {
    if (response.statusCode != 200) {
      throw Exception(
        '$operation failed (${response.statusCode}): ${response.body}',
      );
    }
  }
}
