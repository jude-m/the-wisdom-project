import 'dart:convert';

import 'package:http/http.dart' as http;

import 'fts_datasource.dart';

/// Remote implementation of FTS data source that calls the server API.
/// Used on web platform where local SQLite is not available.
class FTSRemoteDataSourceImpl implements FTSDataSource {
  final http.Client _client;
  final String _baseUrl;

  FTSRemoteDataSourceImpl({
    required String baseUrl,
    http.Client? client,
  })  : _baseUrl = baseUrl,
        _client = client ?? http.Client();

  @override
  Future<void> initializeEditions(Set<String> editionIds) async {
    // No-op: server manages databases
  }

  @override
  Future<List<FTSMatch>> searchFullText(
    String query, {
    required Set<String> editionIds,
    Set<String> scope = const {},
    bool isExactMatch = false,
    bool isPhraseSearch = true,
    bool isAnywhereInText = false,
    int proximityDistance = 10,
    int limit = 50,
    int offset = 0,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/fts/search').replace(
      queryParameters: {
        'query': query,
        'editionIds': editionIds.join(','),
        if (scope.isNotEmpty) 'scope': scope.join(','),
        'isExactMatch': isExactMatch.toString(),
        'isPhraseSearch': isPhraseSearch.toString(),
        'isAnywhereInText': isAnywhereInText.toString(),
        'proximityDistance': proximityDistance.toString(),
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
              r['editionId'] as String,
            ))
        .toList();
  }

  @override
  Future<int> countFullTextMatches(
    String query, {
    required String editionId,
    Set<String> scope = const {},
    bool isExactMatch = false,
    bool isPhraseSearch = true,
    bool isAnywhereInText = false,
    int proximityDistance = 10,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/fts/count').replace(
      queryParameters: {
        'query': query,
        'editionId': editionId,
        if (scope.isNotEmpty) 'scope': scope.join(','),
        'isExactMatch': isExactMatch.toString(),
        'isPhraseSearch': isPhraseSearch.toString(),
        'isAnywhereInText': isAnywhereInText.toString(),
        'proximityDistance': proximityDistance.toString(),
      },
    );

    final response = await _client.get(uri);
    _checkResponse(response, 'FTS count');

    final data = json.decode(response.body) as Map<String, dynamic>;
    return data['count'] as int;
  }

  @override
  Future<List<FTSSuggestion>> getSuggestions(
    String prefix, {
    required Set<String> editionIds,
    String? language,
    int limit = 10,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/fts/suggestions').replace(
      queryParameters: {
        'prefix': prefix,
        'editionIds': editionIds.join(','),
        if (language != null) 'language': language,
        'limit': limit.toString(),
      },
    );

    final response = await _client.get(uri);
    _checkResponse(response, 'FTS suggestions');

    final data = json.decode(response.body) as Map<String, dynamic>;
    final suggestions = data['suggestions'] as List<dynamic>;

    return suggestions
        .map((s) => FTSSuggestion.fromMap(s as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> close() async {
    // No-op: HTTP client can be reused
  }

  void _checkResponse(http.Response response, String operation) {
    if (response.statusCode != 200) {
      throw Exception(
        '$operation failed (${response.statusCode}): ${response.body}',
      );
    }
  }
}
