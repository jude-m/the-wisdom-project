import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:wisdom_shared/wisdom_shared.dart';

import '../database/database_manager.dart';
import '../logging/logger.dart';

/// Handles dictionary lookup, search, and count API endpoints.
class DictionaryHandler {
  final DatabaseManager _db;
  final ServerLogger _logger;

  DictionaryHandler(this._db, this._logger);

  late final router = () {
    final r = Router();
    r.get('/lookup', _lookup);
    r.get('/search', _search);
    r.get('/count', _count);
    return r;
  }();

  /// GET /api/dict/lookup?word=...&exactMatch=false&dictionaryIds=DPD,BUS&limit=50
  Future<Response> _lookup(Request request) async {
    try {
      final params = request.url.queryParameters;
      final word = params['word'] ?? '';
      if (word.isEmpty) {
        return _jsonResponse({'entries': []});
      }

      final exactMatch = params['exactMatch'] == 'true';
      final dictionaryIds = parseCsvToSet(params['dictionaryIds']);
      final limit = int.tryParse(params['limit'] ?? '') ?? 50;

      final likePattern = buildDictionaryLikePattern(word, exactMatch: exactMatch);

      final sql = StringBuffer();
      sql.write('''
        SELECT
          id, word, dict_id, meaning, rank,
          CASE WHEN word = ? THEN 0 ELSE 1 END AS is_exact
        FROM dictionary
        WHERE word LIKE ? ESCAPE '\\'
      ''');

      final args = <Object>[word, likePattern];
      appendDictionaryFilter(sql, args, dictionaryIds);

      sql.write(' ORDER BY is_exact ASC, rank DESC LIMIT ?');
      args.add(limit);

      final results = _db.dictDb.select(sql.toString(), args);
      final entries = results.map(_mapRow).toList();

      return _jsonResponse({'entries': entries});
    } catch (e, stackTrace) {
      _logger.error('Dictionary lookup failed', e, stackTrace);
      return _errorResponse('Lookup failed: $e');
    }
  }

  /// GET /api/dict/search?query=...&isExactMatch=false&dictionaryIds=&limit=50&offset=0
  Future<Response> _search(Request request) async {
    try {
      final params = request.url.queryParameters;
      final query = params['query'] ?? '';
      if (query.isEmpty) {
        return _jsonResponse({'entries': []});
      }

      final isExactMatch = params['isExactMatch'] == 'true';
      final dictionaryIds = parseCsvToSet(params['dictionaryIds']);
      final limit = int.tryParse(params['limit'] ?? '') ?? 50;
      final offset = int.tryParse(params['offset'] ?? '') ?? 0;

      final likePattern = buildDictionaryLikePattern(query, exactMatch: isExactMatch);

      final sql = StringBuffer();
      sql.write('''
        SELECT
          id, word, dict_id, meaning, rank,
          CASE WHEN word = ? THEN 0 ELSE 1 END AS is_exact
        FROM dictionary
        WHERE word LIKE ? ESCAPE '\\'
      ''');

      final args = <Object>[query, likePattern];
      appendDictionaryFilter(sql, args, dictionaryIds);

      sql.write(' ORDER BY is_exact ASC, rank DESC LIMIT ? OFFSET ?');
      args.addAll([limit, offset]);

      final results = _db.dictDb.select(sql.toString(), args);
      final entries = results.map(_mapRow).toList();

      return _jsonResponse({'entries': entries});
    } catch (e, stackTrace) {
      _logger.error('Dictionary search failed', e, stackTrace);
      return _errorResponse('Search failed: $e');
    }
  }

  /// GET /api/dict/count?query=...&isExactMatch=false&dictionaryIds=
  Future<Response> _count(Request request) async {
    try {
      final params = request.url.queryParameters;
      final query = params['query'] ?? '';
      if (query.isEmpty) {
        return _jsonResponse({'count': 0});
      }

      final isExactMatch = params['isExactMatch'] == 'true';
      final dictionaryIds = parseCsvToSet(params['dictionaryIds']);

      final likePattern = buildDictionaryLikePattern(query, exactMatch: isExactMatch);

      final sql = StringBuffer();
      sql.write('''
        SELECT COUNT(*) as count
        FROM dictionary
        WHERE word LIKE ? ESCAPE '\\'
      ''');

      final args = <Object>[likePattern];
      appendDictionaryFilter(sql, args, dictionaryIds);

      final results = _db.dictDb.select(sql.toString(), args);
      final count = results.first['count'] as int;

      return _jsonResponse({'count': count});
    } catch (e, stackTrace) {
      _logger.error('Dictionary count failed', e, stackTrace);
      return _errorResponse('Count failed: $e');
    }
  }

  Map<String, dynamic> _mapRow(dynamic row) {
    final dictId = row['dict_id'] as String;
    final rawScore = row['is_exact'];
    final double? score = rawScore == null
        ? null
        : (rawScore is int ? rawScore.toDouble() : rawScore as double);

    return {
      'id': row['id'],
      'word': row['word'],
      'dictionaryId': dictId,
      'meaning': row['meaning'],
      'targetLanguage': inferTargetLanguage(dictId),
      'sourceLanguage': 'pali',
      'rank': row['rank'],
      if (score != null) 'relevanceScore': score,
    };
  }

  Response _jsonResponse(Object data) {
    return Response.ok(
      json.encode(data),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
    );
  }

  Response _errorResponse(String message, {int status = 500}) {
    return Response(
      status,
      body: json.encode({'error': message}),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
    );
  }
}
