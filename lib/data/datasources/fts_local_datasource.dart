import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:wisdom_shared/wisdom_shared.dart';

import '../services/scope_filter_service.dart';
import 'fts_datasource.dart';

/// Implementation of FTS data source supporting multiple editions
/// Each edition has its own SQLite database with edition-specific table names
class FTSDataSourceImpl implements FTSDataSource {
  /// Map of edition ID to database instance
  final Map<String, Database> _databases = {};

  /// Log debug messages only in debug mode.
  /// Uses dart:developer.log which is stripped in release builds.
  void _log(String message) {
    developer.log(message, name: 'FTSDataSource');
  }

  /// Track which editions are initialized
  final Set<String> _initializedEditions = {};

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
      // Database naming: {editionId}-fts.db (e.g., bjt-fts.db, sc-fts.db)
      final dbName = '$editionId-fts.db';
      final assetPath = 'assets/databases/$dbName';

      // Get the path to the documents directory
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final dbPath = join(documentsDirectory.path, dbName);

      _log('Initializing edition $editionId');
      _log('Asset path: $assetPath');
      _log('DB path: $dbPath');

      // Check if database already exists
      final exists = await File(dbPath).exists();
      _log('Database exists: $exists');

      if (!exists) {
        // Copy from assets
        _log('Copying database from assets...');
        final ByteData data = await rootBundle.load(assetPath);
        final List<int> bytes = data.buffer.asUint8List();
        _log('Loaded ${bytes.length} bytes from assets');

        // Write to file
        await File(dbPath).writeAsBytes(bytes, flush: true);
        _log('Database copied successfully');
      }

      // Open the database
      _log('Opening database...');
      final db = await openDatabase(dbPath);
      _log('Database opened successfully');

      _databases[editionId] = db;
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

      // Build the SQL query using CTE for proper bm25() usage
      // The CTE approach ensures bm25() is called in the correct context
      // with the FTS table directly referenced (not aliased)

      // Build scope filter clause
      final scopeWhereClause = ScopeFilterService.buildWhereClause(scope);
      final scopeArgs = ScopeFilterService.getWhereParams(scope);

      // Build query with BM25 ranking using CTE
      // The CTE computes bm25() in the correct FTS context (direct table reference)
      // ORDER BY and LIMIT are in the outer query for proper pagination
      final buffer = StringBuffer();
      buffer.write('''
        WITH ranked AS (
          SELECT
            m.id, m.filename, m.eind, m.language, m.type, m.level, m.nodeKey,
            bm25($ftsTable) AS score
          FROM $ftsTable
          JOIN $metaTable m ON $ftsTable.rowid = m.id
          WHERE $ftsTable MATCH ?
      ''');
      if (scopeWhereClause != null) {
        buffer.write(' AND $scopeWhereClause');
      }
      buffer.write('''
        )
        SELECT * FROM ranked ORDER BY score LIMIT ? OFFSET ?
      ''');

      // Build args
      final args = <Object>[
        ftsQuery,
        if (scopeWhereClause != null) ...scopeArgs,
        limit,
        offset,
      ];

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
      final ftsQuery = buildFtsQuery(
        query,
        isExactMatch: isExactMatch,
        isPhraseSearch: isPhraseSearch,
        isAnywhereInText: isAnywhereInText,
        proximityDistance: proximityDistance,
      );

      // Build query with optional scope filter
      final buffer = StringBuffer();
      final args = <Object>[ftsQuery];

      // If scope is specified, we need to join with meta table
      if (scope.isNotEmpty) {
        buffer.write('''
          SELECT COUNT(*) as count
          FROM $ftsTable t
          JOIN $metaTable m ON t.rowid = m.id
          WHERE $ftsTable MATCH ?
        ''');

        final scopeWhereClause = ScopeFilterService.buildWhereClause(scope);
        if (scopeWhereClause != null) {
          buffer.write(' AND $scopeWhereClause');
          args.addAll(ScopeFilterService.getWhereParams(scope));
        }
      } else {
        // No scope filter - simple count query
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

  @override
  Future<List<FTSSuggestion>> getSuggestions(
    String prefix, {
    required Set<String> editionIds,
    String? language,
    int limit = 10,
  }) async {
    // Ensure all requested editions are initialized
    await initializeEditions(editionIds);

    // Get suggestions from all editions in parallel
    final futures = editionIds.map((editionId) {
      return _getSuggestionsFromEdition(
        editionId,
        prefix,
        language: language,
        limit: limit,
      );
    });

    final results = await Future.wait(futures);

    // Merge suggestions from all editions
    // Combine frequencies for duplicate words
    final Map<String, FTSSuggestion> mergedSuggestions = {};

    for (final suggestions in results) {
      for (final suggestion in suggestions) {
        final key = '${suggestion.word}_${suggestion.language}';
        if (mergedSuggestions.containsKey(key)) {
          // Add frequencies if word appears in multiple editions
          final existing = mergedSuggestions[key]!;
          mergedSuggestions[key] = FTSSuggestion(
            word: suggestion.word,
            language: suggestion.language,
            frequency: existing.frequency + suggestion.frequency,
          );
        } else {
          mergedSuggestions[key] = suggestion;
        }
      }
    }

    // Sort by frequency and return top N
    final sorted = mergedSuggestions.values.toList()
      ..sort((a, b) => b.frequency.compareTo(a.frequency));

    return sorted.take(limit).toList();
  }

  /// Get suggestions from a single edition
  Future<List<FTSSuggestion>> _getSuggestionsFromEdition(
    String editionId,
    String prefix, {
    String? language,
    int limit = 10,
  }) async {
    final db = _databases[editionId];
    if (db == null) {
      throw StateError('Edition $editionId not initialized');
    }

    try {
      // Table naming: {editionId}_suggestions
      final suggestionsTable = '${editionId}_suggestions';

      // Build the SQL query
      final buffer = StringBuffer();
      buffer.write('''
        SELECT word, language, frequency
        FROM $suggestionsTable
        WHERE word LIKE ?
      ''');

      final args = <Object>['$prefix%'];

      // Add language filter
      if (language != null) {
        buffer.write(' AND language = ?');
        args.add(language);
      }

      // Order by frequency and limit
      buffer.write(' ORDER BY frequency DESC LIMIT ?');
      args.add(limit);

      // Execute query
      final List<Map<String, dynamic>> results = await db.rawQuery(
        buffer.toString(),
        args,
      );

      return results.map((row) => FTSSuggestion.fromMap(row)).toList();
    } catch (e) {
      throw Exception('Suggestion search failed for edition $editionId: $e');
    }
  }

  @override
  Future<void> close() async {
    // Close all databases, collecting any errors
    final errors = <String, Object>{};

    for (final entry in _databases.entries) {
      try {
        await entry.value.close();
      } catch (e) {
        errors[entry.key] = e;
        _log('Error closing database ${entry.key}: $e');
      }
    }

    // Always clear state, even if some closes failed
    _databases.clear();
    _initializedEditions.clear();

    // Report if any errors occurred
    if (errors.isNotEmpty) {
      _log('Failed to close ${errors.length} database(s): ${errors.keys.join(', ')}');
    }
  }
}
