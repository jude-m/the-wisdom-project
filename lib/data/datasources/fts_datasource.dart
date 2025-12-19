import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/utils/text_utils.dart';

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
  Future<List<FTSMatch>> searchContent(
    String query, {
    required Set<String> editionIds,
    String? language,
    List<String>? nikayaFilter,
    int limit = 50,
    int offset = 0,
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

  /// Sanitize FTS query to prevent injection and syntax errors.
  ///
  /// FTS4 MATCH has special characters that can cause crashes or unexpected
  /// behavior if not handled:
  /// - Double quotes (") - phrase delimiters
  /// - Asterisk (*) - prefix matching
  /// - Hyphen (-) - NOT operator
  /// - OR, AND, NOT - boolean operators
  /// - Parentheses - grouping
  /// - Colon (:) - column specifier
  ///
  /// This method normalizes Unicode, escapes quotes, and wraps for safe prefix matching.
  String _sanitizeFtsQuery(String query) {
    // Normalize: trim and remove zero-width characters
    var sanitized = normalizeQueryText(query.trim());

    if (sanitized.isEmpty) {
      return '""';
    }

    // Escape double quotes by doubling them (FTS4 escape syntax)
    sanitized = sanitized.replaceAll('"', '""');

    // Wrap in double quotes for safe phrase matching, then add * for prefix matching
    // This treats the entire query as a literal phrase, neutralizing
    // special operators like OR, AND, NOT, -, while still allowing
    // prefix matching (e.g., "සති"* matches සතිපට්ඨාන, සතිසම්පජඤ්ඤ, etc.)
    return '"$sanitized"*';
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
  Future<List<FTSMatch>> searchContent(
    String query, {
    required Set<String> editionIds,
    String? language,
    List<String>? nikayaFilter,
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

      // Build the SQL query
      // Note: For contentless FTS4, use table name in MATCH, not column name
      final buffer = StringBuffer();
      buffer.write('''
        SELECT m.id, m.filename, m.eind, m.language, m.type, m.level
        FROM $ftsTable t
        JOIN $metaTable m ON t.rowid = m.id
        WHERE $ftsTable MATCH ?
      ''');

      final args = <Object>[_sanitizeFtsQuery(query)];

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

      _log('Executing query: ${buffer.toString()}');
      // Execute query
      final List<Map<String, dynamic>> results = await db.rawQuery(
        buffer.toString(),
        args,
      );

      // Tag results with edition ID
      return results.map((row) => FTSMatch.fromMap(row, editionId)).toList();
    } catch (e) {
      throw Exception('FTS search failed for edition $editionId: $e');
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
