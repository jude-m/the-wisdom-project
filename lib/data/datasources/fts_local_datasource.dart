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
    List<List<String>> looseSpellings = const [],
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
        looseSpellings: looseSpellings,
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
    List<List<String>> looseSpellings = const [],
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

      // The rows of [query] are tier 0; the similar spellings' rows follow.
      final tiers = [
        if (!looseOnly) (tier: 0, match: ftsQuery),
        for (final (index, match) in _looseTierMatches(
          query,
          ftsQuery,
          looseSpellings,
          isExactMatch: isExactMatch,
          isPhraseSearch: isPhraseSearch,
          isAnywhereInText: isAnywhereInText,
          proximityDistance: proximityDistance,
        ).indexed)
          (tier: index + 1, match: match),
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
    List<List<String>> looseSpellings = const [],
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
        looseSpellings,
        isExactMatch: isExactMatch,
        isPhraseSearch: isPhraseSearch,
        isAnywhereInText: isAnywhereInText,
        proximityDistance: proximityDistance,
      );
      final ftsQuery =
          looseQuery == null ? strictQuery : '($strictQuery) OR ($looseQuery)';

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

  /// The MATCH of each tier after the one of [query] ([leadMatch]), each
  /// leaving out the rows listed before it. One typed word gets a tier per
  /// spelling, in search order, so a rare spelling's rows never jump ahead of
  /// a common one's. A phrase gets one tier for all its combinations: a tier
  /// per combination would repeat the costly NEAR matching up to 64 times.
  static List<String> _looseTierMatches(
    String query,
    String leadMatch,
    List<List<String>> spellings, {
    required bool isExactMatch,
    required bool isPhraseSearch,
    required bool isAnywhereInText,
    required int proximityDistance,
  }) {
    if (spellings.length != 1) {
      final looseQuery = _looseFtsQuery(
        spellings,
        isExactMatch: isExactMatch,
        isPhraseSearch: isPhraseSearch,
        isAnywhereInText: isAnywhereInText,
        proximityDistance: proximityDistance,
      );
      return [if (looseQuery != null) '($looseQuery) NOT ($leadMatch)'];
    }

    String match(String spelling) =>
        buildFtsQuery(spelling, isExactMatch: isExactMatch);
    final listed = [query];
    final tiers = <String>[];
    for (final spelling in spellings.single) {
      // Nothing to add when listed already, or — prefix search — when it
      // begins with a spelling listed before it (කර covers කර්).
      final covered = isExactMatch
          ? listed.contains(spelling)
          : listed.any(spelling.startsWith);
      if (covered) continue;
      tiers.add('${match(spelling)} NOT (${listed.map(match).join(' OR ')})');
      listed.add(spelling);
    }
    return tiers;
  }

  /// The FTS5 query for the loose tier, or null when there is none.
  static String? _looseFtsQuery(
    List<List<String>> spellings, {
    required bool isExactMatch,
    required bool isPhraseSearch,
    required bool isAnywhereInText,
    required int proximityDistance,
  }) =>
      spellings.isEmpty
          ? null
          : buildLooseFtsQuery(
              spellings,
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
    final db = await _openWordList(editionId);

    try {
      // One statement per batch: json_each turns the list into rows, and each
      // row costs one seek in the word list.
      final rows = await db.rawQuery(
        'SELECT j.value AS candidate FROM json_each(?) j '
        'WHERE EXISTS (SELECT 1 FROM temp.${_vocabTableFor(editionId)} v '
        'WHERE ${_wordListMatch(wholeWords)})',
        [jsonEncode(candidates.toList())],
      );
      return {for (final row in rows) row['candidate'] as String};
    } catch (e) {
      throw Exception('Word list lookup failed for edition $editionId: $e');
    }
  }

  @override
  Future<Map<String, int>> termUsage(
    String editionId,
    Set<String> spellings, {
    required bool wholeWords,
  }) async {
    if (spellings.isEmpty) return const {};
    final db = await _openWordList(editionId);

    try {
      // `doc` is the rows a word is in. Not `cnt`, its occurrences: one
      // passage repeating a word hundreds of times would outweigh it.
      final rows = await db.rawQuery(
        'SELECT j.value AS spelling, '
        '(SELECT coalesce(sum(v.doc), 0) '
        'FROM temp.${_vocabTableFor(editionId)} v '
        'WHERE ${_wordListMatch(wholeWords)}) AS usage '
        'FROM json_each(?) j',
        [jsonEncode(spellings.toList())],
      );
      return {
        for (final row in rows) row['spelling'] as String: row['usage'] as int,
      };
    } catch (e) {
      throw Exception('Word usage lookup failed for edition $editionId: $e');
    }
  }

  /// [editionId]'s database, its word list ready: the index's own, as an
  /// `fts5vocab` table. Made here, not on open, so strict search never
  /// depends on it; in `temp`, so the file is untouched, and it lives as long
  /// as the shared connection does.
  Future<LocalDatabase> _openWordList(String editionId) async {
    await initializeEditions({editionId});

    final db = _databases[editionId];
    if (db == null) {
      throw StateError('Edition $editionId not initialized');
    }

    final vocab = _vocabTables[editionId] ??= db.customStatement(
      'CREATE VIRTUAL TABLE IF NOT EXISTS temp.${_vocabTableFor(editionId)} '
      'USING fts5vocab(main, ${editionId}_fts, row)',
    );
    try {
      await vocab;
    } catch (e) {
      _vocabTables.remove(editionId);
      throw Exception('Word list setup failed for edition $editionId: $e');
    }
    return db;
  }

  /// A word `v.term` of the word list that candidate `j.value` begins — or,
  /// with [wholeWords], equals. U+10FFFF sorts after anything that can
  /// follow a prefix.
  static String _wordListMatch(bool wholeWords) => wholeWords
      ? 'v.term = j.value'
      : 'v.term >= j.value AND v.term < j.value || char(1114111)';

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
