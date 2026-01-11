import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../services/scope_filter_service.dart';

/// Data model for FTS search results from the database
/// Includes edition information for multi-edition search support
class FTSMatch {
  final String editionId;
  final int rowid;
  final String filename;
  final String eind;
  final String language;
  final String type;
  final int level;

  FTSMatch({
    required this.editionId,
    required this.rowid,
    required this.filename,
    required this.eind,
    required this.language,
    required this.type,
    required this.level,
  });

  factory FTSMatch.fromMap(Map<String, dynamic> map, String editionId) {
    return FTSMatch(
      editionId: editionId,
      rowid: map['id'] as int,
      filename: map['filename'] as String,
      eind: map['eind'] as String,
      language: map['language'] as String,
      type: map['type'] as String,
      level: map['level'] as int,
    );
  }
}

/// Data model for search suggestions
class FTSSuggestion {
  final String word;
  final String language;
  final int frequency;

  FTSSuggestion({
    required this.word,
    required this.language,
    required this.frequency,
  });

  factory FTSSuggestion.fromMap(Map<String, dynamic> map) {
    return FTSSuggestion(
      word: map['word'] as String,
      language: map['language'] as String,
      frequency: map['frequency'] as int,
    );
  }
}

/// Abstract interface for FTS (Full-Text Search) data source
/// Supports multiple Tipitaka editions with separate databases
abstract class FTSDataSource {
  /// Initialize FTS databases for the specified editions
  /// Each edition has its own database file: {editionId}-fts.db
  Future<void> initializeEditions(Set<String> editionIds);

  /// Search for content across one or more editions
  /// Returns results tagged with their source edition
  ///
  /// [scope] - Tree node keys (e.g., 'sp', 'dn', 'dn-1') for filtering.
  /// Empty set = search all content.
  ///
  /// [isPhraseSearch] - true for phrase matching (consecutive/adjacent words),
  /// false for separate-word search (words within proximity).
  ///
  /// [isAnywhereInText] - When true and isPhraseSearch is false, ignores
  /// proximity distance and searches anywhere in the text.
  ///
  /// [proximityDistance] - Distance for NEAR/n proximity (1-100).
  /// Only used when isPhraseSearch is false and isAnywhereInText is false.
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
  });

  /// Count full-text matches without loading results (efficient for tab badges)
  ///
  /// [scope] - Tree node keys (e.g., 'sp', 'dn', 'dn-1') for filtering.
  /// Empty set = count all content.
  ///
  /// [isPhraseSearch] - true for phrase matching (consecutive/adjacent words),
  /// false for separate-word search (words within proximity).
  ///
  /// [isAnywhereInText] - When true and isPhraseSearch is false, ignores
  /// proximity distance and searches anywhere in the text.
  ///
  /// [proximityDistance] - Distance for NEAR/n proximity (1-100).
  /// Only used when isPhraseSearch is false and isAnywhereInText is false.
  Future<int> countFullTextMatches(
    String query, {
    required String editionId,
    Set<String> scope = const {},
    bool isExactMatch = false,
    bool isPhraseSearch = true,
    bool isAnywhereInText = false,
    int proximityDistance = 10,
  });

  /// Get search suggestions from one or more editions
  Future<List<FTSSuggestion>> getSuggestions(
    String prefix, {
    required Set<String> editionIds,
    String? language,
    int limit = 10,
  });

  /// Close all database connections
  Future<void> close();
}

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

  /// Builds FTS query syntax for single or multi-word queries.
  ///
  /// ## Single word:
  /// - `word*` (prefix matching) when [isExactMatch] is false
  /// - `word` (exact token) when [isExactMatch] is true
  ///
  /// ## Multi-word with [isPhraseSearch] = true (phrase search):
  /// - [isExactMatch] = true: `"word1 word2"` (exact phrase, consecutive)
  /// - [isExactMatch] = false: `"word1* word2*"` (phrase with prefix matching)
  ///   Note: SQLite FTS4 supports term prefixes inside quoted phrases.
  ///
  /// ## Multi-word with [isPhraseSearch] = false (separate-word search):
  /// - [isAnywhereInText] = true: Implicit AND (space-separated words)
  /// - [isAnywhereInText] = false: Use [proximityDistance] for NEAR/n
  /// - [isExactMatch] affects whether wildcards are added to each word
  ///
  /// ## Search Flows Summary:
  /// | isPhraseSearch | isAnywhereInText | isExactMatch | FTS Query |
  /// |---------------|------------------|--------------|-----------|
  /// | true | - | true | `"word1 word2"` (exact phrase) |
  /// | true | - | false | `"word1* word2*"` (phrase with prefix) |
  /// | false | true | true | `word1 word2` (AND, exact tokens) |
  /// | false | true | false | `word1* word2*` (AND, prefix match) |
  /// | false | false | true | `word1 NEAR/n word2` (proximity, exact) |
  /// | false | false | false | `word1* NEAR/n word2*` (proximity, prefix) |
  String _buildFtsQuery(
    String queryText, {
    bool isExactMatch = false,
    bool isPhraseSearch = true,
    bool isAnywhereInText = false,
    int proximityDistance = 10,
  }) {
    if (queryText.isEmpty) {
      return '""';
    }

    // Split into words (handles multi-word queries)
    final words = queryText.split(' ').where((w) => w.isNotEmpty).toList();

    if (words.length == 1) {
      // Single word: simple token matching (no quotes)
      // isExactMatch=false: අනාථ* (prefix token matching)
      // isExactMatch=true: අනාථ (exact token matching)
      final singleWordQuery = isExactMatch ? words[0] : '${words[0]}*';
      return singleWordQuery;
    }

    // Multi-word handling
    String result;
    if (isPhraseSearch) {
      // Phrase search: words must be adjacent (consecutive)
      if (isExactMatch) {
        // Exact phrase: use double quotes for FTS phrase query
        // FTS query: "word1 word2" (exact consecutive match)
        result = '"${words.join(' ')}"';
      } else {
        // Phrase with prefix: SQLite FTS4 supports term prefixes inside quotes
        // FTS query: "word1* word2*" (phrase with prefix matching)
        // This matches tipitaka.lk's implementation
        result = '"${words.map((w) => '$w*').join(' ')}"';
      }
    } else {
      // Separate-word search
      if (isAnywhereInText) {
        // Anywhere in text: use implicit AND (no NEAR operator)
        // Simply listing terms with spaces = AND query (both must exist)
        if (isExactMatch) {
          // FTS query: word1 word2 (exact tokens, both must exist)
          result = words.join(' ');
        } else {
          // FTS query: word1* word2* (prefix matching, both must exist)
          result = words.map((w) => '$w*').join(' ');
        }
      } else {
        // Proximity search: words within specific distance
        if (isExactMatch) {
          // FTS query: word1 NEAR/n word2 (exact tokens within distance)
          result = words.join(' NEAR/$proximityDistance ');
        } else {
          // FTS query: word1* NEAR/n word2* (prefix matching within distance)
          result = words.map((w) => '$w*').join(' NEAR/$proximityDistance ');
        }
      }
    }
    
    return result;
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
      // Note: Don't use readOnly mode - FTS4 queries may need temp file access
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
      final ftsQuery = _buildFtsQuery(
        query,
        isExactMatch: isExactMatch,
        isPhraseSearch: isPhraseSearch,
        isAnywhereInText: isAnywhereInText,
        proximityDistance: proximityDistance,
      );

      // Build the SQL query using parameterized query for MATCH clause
      // Note: For contentless FTS4, use table name in MATCH, not column name
      final buffer = StringBuffer();
      buffer.write('''
        SELECT m.id, m.filename, m.eind, m.language, m.type, m.level
        FROM $ftsTable t
        JOIN $metaTable m ON t.rowid = m.id
        WHERE $ftsTable MATCH ?
      ''');

      // Start args with the FTS query
      final args = <Object>[ftsQuery];

      // Add scope filter
      final scopeWhereClause = ScopeFilterService.buildWhereClause(scope);
      if (scopeWhereClause != null) {
        buffer.write(' AND $scopeWhereClause');
        args.addAll(ScopeFilterService.getWhereParams(scope));
      }

      // Add pagination
      buffer.write(' LIMIT ? OFFSET ?');
      args.addAll([limit, offset]);

      _log('FTS query: "$ftsQuery" (isExactMatch: $isExactMatch, isPhraseSearch: $isPhraseSearch, isAnywhereInText: $isAnywhereInText, proximityDistance: $proximityDistance)');
      _log('SQL: ${buffer.toString().trim()}');
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
      final ftsQuery = _buildFtsQuery(
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
