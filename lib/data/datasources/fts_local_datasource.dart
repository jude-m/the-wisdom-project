import 'dart:convert';
import 'dart:developer' as developer;

import 'package:wisdom_shared/wisdom_shared.dart';

import '../database/local_database.dart';
import '../services/scope_filter_service.dart';
import 'fts_datasource.dart';

/// Implementation of FTS data source supporting multiple editions
/// Each edition has its own SQLite database with edition-specific table names
class FTSDataSourceImpl implements FTSDataSource {
  /// Map of edition ID to database instance
  final Map<String, LocalDatabase> _databases = {};

  /// Log debug messages only in debug mode.
  /// Uses dart:developer.log which is stripped in release builds.
  void _log(String message) {
    developer.log(message, name: 'FTSDataSource');
  }

  /// Track which editions are initialized
  final Set<String> _initializedEditions = {};

  /// Per edition, the creation of its word-list table — kept so concurrent
  /// [existingTerms] calls wait on one, and dropped on failure to retry.
  final Map<String, Future<void>> _vocabTables = {};

  /// Database naming: {editionId}.db (e.g., bjt.db, sc.db)
  static String _dbNameFor(String editionId) => '$editionId.db';

  /// The `fts5vocab` view of `{editionId}_fts`, one row per distinct word.
  static String _vocabTableFor(String editionId) => '${editionId}_vocab';

  @override
  Future<void> initializeEditions(Set<String> editionIds) async {
    for (final editionId in editionIds) {
      if (_initializedEditions.contains(editionId)) {
        continue; // Already initialized
      }

      await _initializeEdition(editionId);
      _initializedEditions.add(editionId);
    }
  }

  /// Initialize a single edition's database
  Future<void> _initializeEdition(String editionId) async {
    try {
      _log('Initializing edition $editionId');
      _databases[editionId] = await LocalDatabase.open(_dbNameFor(editionId));
      _log('Database opened successfully');
    } catch (e) {
      _log('Error initializing $editionId: $e');
      throw Exception(
          'Failed to initialize FTS database for edition $editionId: $e');
    }
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
    String? language,
    List<List<String>> looseAlternatives = const [],
    bool looseOnly = false,
    int limit = 50,
    int offset = 0,
  }) async {
    // Ensure all requested editions are initialized
    await initializeEditions(editionIds);

    // Search across all requested editions in parallel
    final futures = editionIds.map((editionId) {
      return _searchInEdition(
        editionId,
        query,
        scope: scope,
        isExactMatch: isExactMatch,
        isPhraseSearch: isPhraseSearch,
        isAnywhereInText: isAnywhereInText,
        proximityDistance: proximityDistance,
        language: language,
        looseAlternatives: looseAlternatives,
        looseOnly: looseOnly,
        limit: limit,
        offset: offset,
      );
    });

    final results = await Future.wait(futures);

    // Flatten results from all editions
    return results.expand((matches) => matches).toList();
  }

  /// Search within a single edition's database
  Future<List<FTSMatch>> _searchInEdition(
    String editionId,
    String query, {
    Set<String> scope = const {},
    bool isExactMatch = false,
    bool isPhraseSearch = true,
    bool isAnywhereInText = false,
    int proximityDistance = 10,
    String? language,
    List<List<String>> looseAlternatives = const [],
    bool looseOnly = false,
    int limit = 50,
    int offset = 0,
  }) async {
    final db = _databases[editionId];
    if (db == null) {
      throw StateError('Edition $editionId not initialized');
    }

    try {
      // Table naming: {editionId}_fts and {editionId}_meta
      final ftsTable = '${editionId}_fts';
      final metaTable = '${editionId}_meta';

      // Build FTS query syntax (query already validated by repository)
      final ftsQuery = buildFtsQuery(
        query,
        isExactMatch: isExactMatch,
        isPhraseSearch: isPhraseSearch,
        isAnywhereInText: isAnywhereInText,
        proximityDistance: proximityDistance,
      );

      // Strict rows are tier 0. Rows that only a similar spelling finds are
      // tier 1: `(loose) NOT (strict)`, so no row is listed twice.
      final looseQuery = _looseFtsQuery(
        looseAlternatives,
        isExactMatch: isExactMatch,
        isPhraseSearch: isPhraseSearch,
        isAnywhereInText: isAnywhereInText,
        proximityDistance: proximityDistance,
      );
      final tiers = [
        if (!looseOnly) (tier: 0, match: ftsQuery),
        if (looseQuery != null) (tier: 1, match: '($looseQuery) NOT ($ftsQuery)'),
      ];
      if (tiers.isEmpty) return const [];

      // Build scope filter clause
      final scopeWhereClause = ScopeFilterService.buildWhereClause(scope);
      final scopeArgs = ScopeFilterService.getWhereParams(scope);
      // Optional language filter (පාළි / සිංහල toggle). Same shared builder as
      // scope above; 'language' lives on the meta table, already joined as `m`.
      final languageClause = ScopeFilterService.buildLanguageClause(language);

      // Build query with BM25 ranking using CTE
      // The CTE computes bm25() in the correct FTS context (direct table
      // reference) — once per tier, each its own MATCH. ORDER BY and LIMIT
      // are in the outer query for proper pagination.
      // Args MUST follow the '?' placeholders: per tier MATCH, [scope...],
      // [language]; then LIMIT, OFFSET.
      final buffer = StringBuffer('WITH ranked AS (');
      final args = <Object>[];
      for (final (index, tier) in tiers.indexed) {
        if (index > 0) buffer.write(' UNION ALL ');
        buffer.write('''
          SELECT
            m.id, m.filename, m.eind, m.language, m.type, m.level, m.nodeKey,
            bm25($ftsTable) AS score, ${tier.tier} AS tier
          FROM $ftsTable
          JOIN $metaTable m ON $ftsTable.rowid = m.id
          WHERE $ftsTable MATCH ?
        ''');
        args.add(tier.match);
        if (scopeWhereClause != null) {
          buffer.write(' AND $scopeWhereClause');
          args.addAll(scopeArgs);
        }
        if (languageClause != null) {
          buffer.write(' AND $languageClause');
          args.addAll(ScopeFilterService.getLanguageParams(language));
        }
      }
      // `id` breaks bm25 ties, so paging can't repeat or drop a tied row.
      buffer.write('''
        )
        SELECT * FROM ranked ORDER BY tier, score, id LIMIT ? OFFSET ?
      ''');
      args.addAll([limit, offset]);

      // Execute query
      final List<Map<String, dynamic>> results = await db.rawQuery(
        buffer.toString(),
        args,
      );
      _log('Results: ${results.length} matches');

      // Tag results with edition ID
      return results.map((row) => FTSMatch.fromMap(row, editionId)).toList();
    } catch (e) {
      throw Exception('FTS search failed for edition $editionId: $e');
    }
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
    String? language,
    List<List<String>> looseAlternatives = const [],
  }) async {
    await initializeEditions({editionId});

    final db = _databases[editionId];
    if (db == null) {
      throw StateError('Edition $editionId not initialized');
    }

    try {
      final ftsTable = '${editionId}_fts';
      final metaTable = '${editionId}_meta';

      // Build FTS query syntax (query already validated by repository)
      final strictQuery = buildFtsQuery(
        query,
        isExactMatch: isExactMatch,
        isPhraseSearch: isPhraseSearch,
        isAnywhereInText: isAnywhereInText,
        proximityDistance: proximityDistance,
      );
      // Both tiers, as searchFullText lists them.
      final looseQuery = _looseFtsQuery(
        looseAlternatives,
        isExactMatch: isExactMatch,
        isPhraseSearch: isPhraseSearch,
        isAnywhereInText: isAnywhereInText,
        proximityDistance: proximityDistance,
      );
      final ftsQuery = looseQuery == null
          ? strictQuery
          : '($strictQuery) OR ($looseQuery)';

      // Build query with optional scope and/or language filters.
      // Either filter lives on the meta table, so we only join `m` when needed
      // (a bare MATCH count is cheaper).
      final buffer = StringBuffer();
      final args = <Object>[ftsQuery];
      final needsMetaJoin = scope.isNotEmpty || language != null;

      if (needsMetaJoin) {
        buffer.write('''
          SELECT COUNT(*) as count
          FROM $ftsTable t
          JOIN $metaTable m ON t.rowid = m.id
          WHERE $ftsTable MATCH ?
        ''');

        if (scope.isNotEmpty) {
          final scopeWhereClause = ScopeFilterService.buildWhereClause(scope);
          if (scopeWhereClause != null) {
            buffer.write(' AND $scopeWhereClause');
            args.addAll(ScopeFilterService.getWhereParams(scope));
          }
        }

        // Language filter (පාළි / සිංහල toggle) — mirror searchFullText.
        final languageClause = ScopeFilterService.buildLanguageClause(language);
        if (languageClause != null) {
          buffer.write(' AND $languageClause');
          args.addAll(ScopeFilterService.getLanguageParams(language));
        }
      } else {
        // No filters - simple count query
        buffer.write(
          'SELECT COUNT(*) as count FROM $ftsTable WHERE $ftsTable MATCH ?',
        );
      }

      final results = await db.rawQuery(buffer.toString(), args);

      return results.first['count'] as int;
    } catch (e) {
      throw Exception('FTS count failed for edition $editionId: $e');
    }
  }

  /// The FTS5 query for the loose tier, or null when there is none.
  static String? _looseFtsQuery(
    List<List<String>> alternatives, {
    required bool isExactMatch,
    required bool isPhraseSearch,
    required bool isAnywhereInText,
    required int proximityDistance,
  }) =>
      alternatives.isEmpty
          ? null
          : buildLooseFtsQuery(
              alternatives,
              isExactMatch: isExactMatch,
              isPhraseSearch: isPhraseSearch,
              isAnywhereInText: isAnywhereInText,
              proximityDistance: proximityDistance,
            );

  @override
  Future<Set<String>> existingTerms(
    String editionId,
    Set<String> candidates, {
    required bool wholeWords,
  }) async {
    if (candidates.isEmpty) return const {};
    await initializeEditions({editionId});

    final db = _databases[editionId];
    if (db == null) {
      throw StateError('Edition $editionId not initialized');
    }

    try {
      // The index's own word list. Made here, not on open, so strict search
      // never depends on it; in `temp`, so the file is untouched, and it lives
      // as long as the shared connection does.
      final vocab = _vocabTables[editionId] ??= db.customStatement(
        'CREATE VIRTUAL TABLE IF NOT EXISTS temp.${_vocabTableFor(editionId)} '
        'USING fts5vocab(main, ${editionId}_fts, row)',
      );
      try {
        await vocab;
      } catch (_) {
        _vocabTables.remove(editionId);
        rethrow;
      }

      // One statement per batch: json_each turns the list into rows, and each
      // row costs one seek in the word list. U+10FFFF sorts after anything
      // that can follow a prefix.
      final match = wholeWords
          ? 'v.term = j.value'
          : 'v.term >= j.value AND v.term < j.value || char(1114111)';
      final rows = await db.rawQuery(
        'SELECT j.value AS candidate FROM json_each(?) j '
        'WHERE EXISTS (SELECT 1 FROM temp.${_vocabTableFor(editionId)} v '
        'WHERE $match)',
        [jsonEncode(candidates.toList())],
      );
      return {for (final row in rows) row['candidate'] as String};
    } catch (e) {
      throw Exception('Word list lookup failed for edition $editionId: $e');
    }
  }

  @override
  Future<void> close() async {
    // Close all databases, collecting any errors
    final errors = <String, Object>{};

    for (final entry in _databases.entries) {
      try {
        await LocalDatabase.closeShared(_dbNameFor(entry.key));
      } catch (e) {
        errors[entry.key] = e;
        _log('Error closing database ${entry.key}: $e');
      }
    }

    // Always clear state, even if some closes failed
    _databases.clear();
    _initializedEditions.clear();
    _vocabTables.clear(); // temp tables go with their connection

    // Report if any errors occurred
    if (errors.isNotEmpty) {
      _log(
          'Failed to close ${errors.length} database(s): ${errors.keys.join(', ')}');
    }
  }
}
