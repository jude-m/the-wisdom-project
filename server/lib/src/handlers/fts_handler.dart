import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../database/database_manager.dart';
import '../logging/logger.dart';

/// Handles FTS search, count, and suggestion API endpoints.
class FtsHandler {
  final DatabaseManager _db;
  final ServerLogger _logger;
  final String _assetsPath;

  FtsHandler(this._db, this._logger, this._assetsPath);

  Router get router {
    final router = Router();
    router.get('/search', _search);
    router.get('/count', _count);
    router.get('/suggestions', _suggestions);
    return router;
  }

  /// GET /api/fts/search?query=...&editionIds=bjt&scope=dn,mn&...
  Future<Response> _search(Request request) async {
    try {
      final params = request.url.queryParameters;
      final query = params['query'] ?? '';
      if (query.isEmpty) {
        return _jsonResponse({'results': [], 'count': 0});
      }

      final editionId = params['editionIds'] ?? 'bjt';
      final scope = _parseSet(params['scope']);
      final isExactMatch = params['isExactMatch'] == 'true';
      final isPhraseSearch = params['isPhraseSearch'] != 'false';
      final isAnywhereInText = params['isAnywhereInText'] == 'true';
      final proximityDistance = int.tryParse(params['proximityDistance'] ?? '') ?? 10;
      final limit = int.tryParse(params['limit'] ?? '') ?? 50;
      final offset = int.tryParse(params['offset'] ?? '') ?? 0;

      // Build FTS5 query string
      final ftsQuery = _buildFtsQuery(
        query,
        isExactMatch: isExactMatch,
        isPhraseSearch: isPhraseSearch,
        isAnywhereInText: isAnywhereInText,
        proximityDistance: proximityDistance,
      );

      final ftsTable = '${editionId}_fts';
      final metaTable = '${editionId}_meta';

      // Build scope filter
      final scopeClause = _buildScopeWhereClause(scope);
      final scopeParams = _getScopeParams(scope);

      // Build SQL with BM25 ranking
      final sql = StringBuffer();
      sql.write('''
        WITH ranked AS (
          SELECT
            m.id, m.filename, m.eind, m.language, m.type, m.level, m.nodeKey,
            bm25($ftsTable) AS score
          FROM $ftsTable
          JOIN $metaTable m ON $ftsTable.rowid = m.id
          WHERE $ftsTable MATCH ?
      ''');
      if (scopeClause != null) {
        sql.write(' AND $scopeClause');
      }
      sql.write('''
        )
        SELECT * FROM ranked ORDER BY score LIMIT ? OFFSET ?
      ''');

      final args = [
        ftsQuery,
        ...scopeParams,
        limit,
        offset,
      ];

      final results = _db.ftsDb.select(sql.toString(), args);

      // Enrich results with matched text from JSON files
      final enrichedResults = <Map<String, dynamic>>[];
      for (final row in results) {
        final result = <String, dynamic>{
          'editionId': editionId,
          'id': row['id'],
          'filename': row['filename'],
          'eind': row['eind'],
          'language': row['language'],
          'type': row['type'],
          'level': row['level'],
          'nodeKey': row['nodeKey'],
          'score': row['score'],
        };

        // Load matched text from JSON file
        final matchedText = _loadTextForMatch(
          row['filename'] as String,
          row['eind'] as String,
          row['language'] as String,
        );
        if (matchedText != null) {
          result['matchedText'] = matchedText;
        }

        enrichedResults.add(result);
      }

      return _jsonResponse({'results': enrichedResults});
    } catch (e, stackTrace) {
      _logger.error('FTS search failed', e, stackTrace);
      return _errorResponse('Search failed: $e');
    }
  }

  /// GET /api/fts/count?query=...&editionId=bjt&scope=...
  Future<Response> _count(Request request) async {
    try {
      final params = request.url.queryParameters;
      final query = params['query'] ?? '';
      if (query.isEmpty) {
        return _jsonResponse({'count': 0});
      }

      final editionId = params['editionId'] ?? 'bjt';
      final scope = _parseSet(params['scope']);
      final isExactMatch = params['isExactMatch'] == 'true';
      final isPhraseSearch = params['isPhraseSearch'] != 'false';
      final isAnywhereInText = params['isAnywhereInText'] == 'true';
      final proximityDistance = int.tryParse(params['proximityDistance'] ?? '') ?? 10;

      final ftsQuery = _buildFtsQuery(
        query,
        isExactMatch: isExactMatch,
        isPhraseSearch: isPhraseSearch,
        isAnywhereInText: isAnywhereInText,
        proximityDistance: proximityDistance,
      );

      final ftsTable = '${editionId}_fts';
      final metaTable = '${editionId}_meta';

      final sql = StringBuffer();
      final args = <Object>[ftsQuery];

      final scopeClause = _buildScopeWhereClause(scope);
      final scopeParams = _getScopeParams(scope);

      if (scope.isNotEmpty) {
        sql.write('''
          SELECT COUNT(*) as count
          FROM $ftsTable t
          JOIN $metaTable m ON t.rowid = m.id
          WHERE $ftsTable MATCH ?
        ''');
        if (scopeClause != null) {
          sql.write(' AND $scopeClause');
          args.addAll(scopeParams);
        }
      } else {
        sql.write(
          'SELECT COUNT(*) as count FROM $ftsTable WHERE $ftsTable MATCH ?',
        );
      }

      final results = _db.ftsDb.select(sql.toString(), args);
      final count = results.first['count'] as int;

      return _jsonResponse({'count': count});
    } catch (e, stackTrace) {
      _logger.error('FTS count failed', e, stackTrace);
      return _errorResponse('Count failed: $e');
    }
  }

  /// GET /api/fts/suggestions?prefix=...&editionIds=bjt&language=pali&limit=10
  Future<Response> _suggestions(Request request) async {
    try {
      final params = request.url.queryParameters;
      final prefix = params['prefix'] ?? '';
      if (prefix.isEmpty) {
        return _jsonResponse({'suggestions': []});
      }

      final editionId = params['editionIds'] ?? 'bjt';
      final language = params['language'];
      final limit = int.tryParse(params['limit'] ?? '') ?? 10;

      final suggestionsTable = '${editionId}_suggestions';

      final sql = StringBuffer();
      sql.write('''
        SELECT word, language, frequency
        FROM $suggestionsTable
        WHERE word LIKE ?
      ''');
      final args = <Object>['$prefix%'];

      if (language != null && language.isNotEmpty) {
        sql.write(' AND language = ?');
        args.add(language);
      }

      sql.write(' ORDER BY frequency DESC LIMIT ?');
      args.add(limit);

      final results = _db.ftsDb.select(sql.toString(), args);
      final suggestions = results
          .map((row) => {
                'word': row['word'],
                'language': row['language'],
                'frequency': row['frequency'],
              })
          .toList();

      return _jsonResponse({'suggestions': suggestions});
    } catch (e, stackTrace) {
      _logger.error('FTS suggestions failed', e, stackTrace);
      return _errorResponse('Suggestions failed: $e');
    }
  }

  // ===========================================================================
  // FTS5 Query Builder (same logic as FTSDataSourceImpl._buildFtsQuery)
  // ===========================================================================

  String _buildFtsQuery(
    String queryText, {
    bool isExactMatch = false,
    bool isPhraseSearch = true,
    bool isAnywhereInText = false,
    int proximityDistance = 10,
  }) {
    if (queryText.isEmpty) return '""';

    final words = queryText.split(' ').where((w) => w.isNotEmpty).toList();

    if (words.length == 1) {
      return isExactMatch ? words[0] : '${words[0]}*';
    }

    if (isPhraseSearch) {
      if (isExactMatch) {
        return '"${words.join(' ')}"';
      } else {
        return 'NEAR(${words.map((w) => '$w*').join(' ')}, 1)';
      }
    } else {
      if (isAnywhereInText) {
        if (isExactMatch) {
          return words.join(' ');
        } else {
          return words.map((w) => '$w*').join(' ');
        }
      } else {
        if (isExactMatch) {
          return 'NEAR(${words.join(' ')}, $proximityDistance)';
        } else {
          return 'NEAR(${words.map((w) => '$w*').join(' ')}, $proximityDistance)';
        }
      }
    }
  }

  // ===========================================================================
  // Scope Filter (same logic as ScopeFilterService + ScopeOperations)
  // ===========================================================================

  /// Root nodes that need expansion to multiple filename prefixes
  static const _expandedPatterns = <String, List<String>>{
    'sp': ['dn-', 'mn-', 'sn-', 'an-', 'kn-'],
    'atta-sp': ['atta-dn-', 'atta-mn-', 'atta-sn-', 'atta-an-', 'atta-kn-'],
  };

  List<String> _getPatternsForScope(Set<String> scope) {
    if (scope.isEmpty) return [];
    return scope.expand((key) {
      if (_expandedPatterns.containsKey(key)) {
        return _expandedPatterns[key]!;
      }
      return ['$key-'];
    }).toList();
  }

  String? _buildScopeWhereClause(Set<String> scope) {
    if (scope.isEmpty) return null;
    final patterns = _getPatternsForScope(scope);
    if (patterns.isEmpty) return null;
    final conditions = patterns.map((_) => 'm.filename LIKE ?').join(' OR ');
    return '($conditions)';
  }

  List<String> _getScopeParams(Set<String> scope) {
    if (scope.isEmpty) return [];
    return _getPatternsForScope(scope).map((p) => '$p%').toList();
  }

  // ===========================================================================
  // Text Content Loading (for enriching search results with matched text)
  // ===========================================================================

  /// Cache loaded JSON files to avoid re-reading for multiple results from same file
  final Map<String, dynamic> _jsonCache = {};

  String? _loadTextForMatch(String filename, String eind, String language) {
    try {
      final eindParts = eind.split('-');
      final pageIndex = int.parse(eindParts[0]);
      final entryIndex = int.parse(eindParts[1]);

      // Load JSON file (cached)
      final jsonData = _loadJsonFile(filename);
      if (jsonData == null) return null;

      final pages = jsonData['pages'] as List<dynamic>?;
      if (pages == null || pageIndex >= pages.length) return null;

      final page = pages[pageIndex] as Map<String, dynamic>;

      // Try matched language first, then fallback
      final langOrder =
          language == 'pali' ? ['pali', 'sinh'] : ['sinh', 'pali'];
      for (final lang in langOrder) {
        final langData = page[lang] as Map<String, dynamic>?;
        if (langData != null) {
          final entries = langData['entries'] as List<dynamic>?;
          if (entries != null && entryIndex < entries.length) {
            final entry = entries[entryIndex] as Map<String, dynamic>;
            final text = entry['text'] as String?;
            if (text != null && text.isNotEmpty) return text;
          }
        }
      }
    } catch (e) {
      _logger.debug('Failed to load text for match: $filename/$eind: $e');
    }
    return null;
  }

  Map<String, dynamic>? _loadJsonFile(String filename) {
    if (_jsonCache.containsKey(filename)) {
      return _jsonCache[filename] as Map<String, dynamic>?;
    }

    try {
      final file = File('$_assetsPath/text/$filename.json');
      if (!file.existsSync()) {
        _jsonCache[filename] = null;
        return null;
      }
      final jsonString = file.readAsStringSync();
      final data = json.decode(jsonString) as Map<String, dynamic>;
      _jsonCache[filename] = data;
      return data;
    } catch (e) {
      _logger.debug('Failed to load JSON file $filename: $e');
      _jsonCache[filename] = null;
      return null;
    }
  }

  // ===========================================================================
  // Helpers
  // ===========================================================================

  Set<String> _parseSet(String? csv) {
    if (csv == null || csv.isEmpty) return {};
    return csv.split(',').where((s) => s.isNotEmpty).toSet();
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
