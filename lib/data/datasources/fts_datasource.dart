import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

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
  Future<List<FTSMatch>> searchFullText(
    String query, {
    required Set<String> editionIds,
    String? language,
    List<String>? nikayaFilter,
    bool exactMatch = false,
    int limit = 50,
    int offset = 0,
  });

  /// Count full-text matches without loading results (efficient for tab badges)
  Future<int> countFullTextMatches(
    String query, {
    required String editionId,
    bool exactMatch = false,
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

  /// Sanitize FTS query for safe execution.
  ///
  /// This method follows tipitaka.lk's approach:
  /// - For simple queries: pass directly to FTS with optional * for prefix matching
  /// - NO double quotes wrapping (quotes change FTS from token to phrase matching)
  ///
  /// FTS4 token matching (without quotes):
  /// - `අනාථ*` matches any word TOKEN starting with "අනාථ" anywhere in text
  ///
  /// FTS4 phrase matching (with quotes):
  /// - `"අනාථ"*` matches the exact PHRASE "අනාථ" - much more restrictive
  ///
  /// When [exactMatch] is false (default), appends * for prefix/token matching.
  /// When [exactMatch] is true, no asterisk for exact token match.
  String _sanitizeFtsQuery(String query, {bool exactMatch = false}) {
    // Normalize: trim and remove zero-width characters, periods, commas
    var sanitized = query.trim();

    // Remove ALL zero-width Unicode characters that can break FTS matching:
    // - U+200D: Zero-Width Joiner (ZWJ)
    // - U+200C: Zero-Width Non-Joiner (ZWNJ)
    // - U+200B: Zero-Width Space (ZWSP) - THIS WAS MISSING!
    // - U+FEFF: Byte Order Mark (BOM)
    // Also remove period and comma (same as tipitaka.lk)
    sanitized = sanitized.replaceAll(RegExp(r'[\u200d\u200c\u200b\ufeff\.,]'), '');

    // Collapse multiple spaces to single space
    sanitized = sanitized.replaceAll(RegExp(r'\s+'), ' ');

    if (sanitized.isEmpty) {
      return '""';
    }

    // Handle multi-word queries
    final words = sanitized.split(' ');

    if (words.length == 1) {
      // Single word: simple token matching (no quotes)
      // exactMatch=false: අනාථ* (prefix token matching)
      // exactMatch=true: අනාථ (exact token matching)
      return exactMatch ? sanitized : '$sanitized*';
    } else {
      // Multi-word: use NEAR/10 for proximity matching (same as tipitaka.lk default)
      if (exactMatch) {
        // Exact match for each word with NEAR proximity
        return words.join(' NEAR/10 ');
      } else {
        // Prefix match for each word with NEAR proximity
        return words.map((w) => '$w*').join(' NEAR/10 ');
      }
    }
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
    String? language,
    List<String>? nikayaFilter,
    bool exactMatch = false,
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
        language: language,
        nikayaFilter: nikayaFilter,
        exactMatch: exactMatch,
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
    String? language,
    List<String>? nikayaFilter,
    bool exactMatch = false,
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

      // Sanitize query for FTS MATCH
      // Testing parameterized query approach for FTS MATCH
      final ftsQuery = _sanitizeFtsQuery(query, exactMatch: exactMatch);

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

      // Add language filter
      if (language != null) {
        buffer.write(' AND m.language = ?');
        args.add(language);
      }

      // Add nikaya filter
      if (nikayaFilter != null && nikayaFilter.isNotEmpty) {
        buffer.write(' AND (');
        buffer.write(nikayaFilter.map((_) => 'm.filename LIKE ?').join(' OR '));
        buffer.write(')');
        args.addAll(nikayaFilter.map((n) => '$n-%'));
      }

      // Add pagination
      buffer.write(' LIMIT ? OFFSET ?');
      args.addAll([limit, offset]);

      _log('FTS query: "$ftsQuery" (exactMatch: $exactMatch)');
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
    bool exactMatch = false,
  }) async {
    await initializeEditions({editionId});

    final db = _databases[editionId];
    if (db == null) {
      throw StateError('Edition $editionId not initialized');
    }

    try {
      final ftsTable = '${editionId}_fts';
      final ftsQuery = _sanitizeFtsQuery(query, exactMatch: exactMatch);

      final sql = 'SELECT COUNT(*) as count FROM $ftsTable WHERE $ftsTable MATCH ?';
      final results = await db.rawQuery(sql, [ftsQuery]);

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
    for (final db in _databases.values) {
      await db.close();
    }
    _databases.clear();
    _initializedEditions.clear();
  }
}
