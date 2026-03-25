import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/entities/dictionary/dictionary_entry.dart';
import 'dictionary_datasource.dart';

/// Remote implementation of DictionaryDataSource that calls the server API.
/// Used on web platform where local SQLite is not available.
class DictionaryRemoteDataSourceImpl implements DictionaryDataSource {
  final http.Client _client;
  final String _baseUrl;

  DictionaryRemoteDataSourceImpl({
    required String baseUrl,
    http.Client? client,
  })  : _baseUrl = baseUrl,
        _client = client ?? http.Client();

  @override
  Future<void> initialize() async {
    // No-op: server manages database
  }

  @override
  Future<List<DictionaryEntry>> lookupWord(
    String word, {
    bool exactMatch = false,
    Set<String> dictionaryIds = const {},
    int limit = 50,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/dict/lookup').replace(
      queryParameters: {
        'word': word,
        'exactMatch': exactMatch.toString(),
        if (dictionaryIds.isNotEmpty) 'dictionaryIds': dictionaryIds.join(','),
        'limit': limit.toString(),
      },
    );

    final response = await _client.get(uri);
    _checkResponse(response, 'Dictionary lookup');

    final data = json.decode(response.body) as Map<String, dynamic>;
    final entries = data['entries'] as List<dynamic>;

    return entries.map((e) => _mapEntry(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<DictionaryEntry>> searchDefinitions(
    String query, {
    bool isExactMatch = false,
    Set<String> dictionaryIds = const {},
    int limit = 50,
    int offset = 0,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/dict/search').replace(
      queryParameters: {
        'query': query,
        'isExactMatch': isExactMatch.toString(),
        if (dictionaryIds.isNotEmpty) 'dictionaryIds': dictionaryIds.join(','),
        'limit': limit.toString(),
        'offset': offset.toString(),
      },
    );

    final response = await _client.get(uri);
    _checkResponse(response, 'Dictionary search');

    final data = json.decode(response.body) as Map<String, dynamic>;
    final entries = data['entries'] as List<dynamic>;

    return entries.map((e) => _mapEntry(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<int> countDefinitions(
    String query, {
    bool isExactMatch = false,
    Set<String> dictionaryIds = const {},
  }) async {
    final uri = Uri.parse('$_baseUrl/api/dict/count').replace(
      queryParameters: {
        'query': query,
        'isExactMatch': isExactMatch.toString(),
        if (dictionaryIds.isNotEmpty) 'dictionaryIds': dictionaryIds.join(','),
      },
    );

    final response = await _client.get(uri);
    _checkResponse(response, 'Dictionary count');

    final data = json.decode(response.body) as Map<String, dynamic>;
    return data['count'] as int;
  }

  @override
  Future<void> close() async {
    // No-op
  }

  /// Map server JSON to DictionaryEntry (Freezed entity)
  DictionaryEntry _mapEntry(Map<String, dynamic> json) {
    return DictionaryEntry(
      id: json['id'] as int,
      word: json['word'] as String,
      dictionaryId: json['dictionaryId'] as String,
      meaning: json['meaning'] as String,
      targetLanguage: json['targetLanguage'] as String,
      sourceLanguage: json['sourceLanguage'] as String,
      rank: json['rank'] as int,
      relevanceScore: (json['relevanceScore'] as num?)?.toDouble(),
    );
  }

  void _checkResponse(http.Response response, String operation) {
    if (response.statusCode != 200) {
      throw Exception(
        '$operation failed (${response.statusCode}): ${response.body}',
      );
    }
  }
}
