import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../domain/entities/dictionary/dictionary_entry.dart';
import 'dictionary_datasource.dart';

/// Implementation of dictionary data source
class DictionaryDataSourceImpl implements DictionaryDataSource {
  Database? _database;
  bool _initialized = false;

  /// Log debug messages only in debug mode.
  void _log(String message) {
    developer.log(message, name: 'DictionaryDataSource');
  }

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      const dbName = 'dict.db';
      const assetPath = 'assets/databases/$dbName';

      // Get the path to the documents directory
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final dbPath = join(documentsDirectory.path, dbName);

      // Check if database already exists
      final exists = await File(dbPath).exists();

      if (!exists) {
        // Copy from assets
        final ByteData data = await rootBundle.load(assetPath);
        final List<int> bytes = data.buffer.asUint8List();

        // Write to file
        await File(dbPath).writeAsBytes(bytes, flush: true);
      }

      // Open the database
      _database = await openDatabase(dbPath);

      _initialized = true;
    } catch (e) {
      throw Exception('Failed to initialize dictionary database: $e');
    }
  }

  /// Builds LIKE pattern for word lookup
  /// For single word: "word%" (prefix) or "word" (exact)
  /// Escapes special SQL LIKE characters
  String _buildLikePattern(String word, {bool exactMatch = false}) {
    if (word.isEmpty) return '%';
    // Escape special LIKE characters: % and _
    final escaped = word.replaceAll('%', '\\%').replaceAll('_', '\\_');
    return exactMatch ? escaped : '$escaped%';
  }

  @override
  Future<List<DictionaryEntry>> lookupWord(
    String word, {
    bool exactMatch = false,
    Set<String> dictionaryIds = const {},
    int limit = 50,
  }) async {
    await initialize();

    final db = _database;
    if (db == null) {
      throw StateError('Dictionary database not initialized');
    }

    try {
      final likePattern = _buildLikePattern(word, exactMatch: exactMatch);

      // Build the SQL query
      // Order by:
      // 1. Exact match first (word = ?)
      // 2. Dictionary rank (higher rank = more important)
      final buffer = StringBuffer();
      buffer.write('''
        SELECT
          id, word, dict_id, meaning, rank,
          CASE WHEN word = ? THEN 0 ELSE 1 END AS is_exact
        FROM dictionary
        WHERE word LIKE ? ESCAPE '\\'
      ''');

      final args = <Object>[word, likePattern];

      _appendDictionaryFilter(buffer, args, dictionaryIds);

      buffer.write('''
        ORDER BY is_exact ASC, rank DESC
        LIMIT ?
      ''');

      args.add(limit);

      // Execute query
      final List<Map<String, dynamic>> results = await db.rawQuery(
        buffer.toString(),
        args,
      );

      return results.map((row) => _mapRowToEntry(row)).toList();
    } catch (e) {
      throw Exception('Dictionary lookup failed: $e');
    }
  }

  @override
  Future<List<DictionaryEntry>> searchDefinitions(
    String query, {
    bool isExactMatch = false,
    Set<String> dictionaryIds = const {},
    int limit = 50,
    int offset = 0,
  }) async {
    await initialize();

    final db = _database;
    if (db == null) {
      throw StateError('Dictionary database not initialized');
    }

    try {
      final likePattern = _buildLikePattern(query, exactMatch: isExactMatch);

      // Build the SQL query
      final buffer = StringBuffer();
      buffer.write('''
        SELECT
          id, word, dict_id, meaning, rank,
          CASE WHEN word = ? THEN 0 ELSE 1 END AS is_exact
        FROM dictionary
        WHERE word LIKE ? ESCAPE '\\'
      ''');

      final args = <Object>[query, likePattern];

      _appendDictionaryFilter(buffer, args, dictionaryIds);

      buffer.write('''
        ORDER BY is_exact ASC, rank DESC
        LIMIT ? OFFSET ?
      ''');

      args.addAll([limit, offset]);

      // Execute query
      final List<Map<String, dynamic>> results = await db.rawQuery(
        buffer.toString(),
        args,
      );

      return results.map((row) => _mapRowToEntry(row)).toList();
    } catch (e) {
      throw Exception('Dictionary search failed: $e');
    }
  }

  @override
  Future<int> countDefinitions(
    String query, {
    bool isExactMatch = false,
    Set<String> dictionaryIds = const {},
  }) async {
    await initialize();

    final db = _database;
    if (db == null) {
      throw StateError('Dictionary database not initialized');
    }

    try {
      final likePattern = _buildLikePattern(query, exactMatch: isExactMatch);

      // Build count query
      final buffer = StringBuffer();
      buffer.write('''
        SELECT COUNT(*) as count
        FROM dictionary
        WHERE word LIKE ? ESCAPE '\\'
      ''');

      final args = <Object>[likePattern];

      _appendDictionaryFilter(buffer, args, dictionaryIds);

      final results = await db.rawQuery(buffer.toString(), args);
      return results.first['count'] as int;
    } catch (e) {
      throw Exception('Dictionary count failed: $e');
    }
  }

  /// Appends SQL WHERE clause for dictionary ID filtering.
  /// Empty [dictionaryIds] = no filter (all dictionaries).
  void _appendDictionaryFilter(
    StringBuffer buffer,
    List<Object> args,
    Set<String> dictionaryIds,
  ) {
    if (dictionaryIds.isNotEmpty) {
      final placeholders = List.filled(dictionaryIds.length, '?').join(', ');
      buffer.write(' AND dict_id IN ($placeholders)');
      args.addAll(dictionaryIds);
    }
  }

  /// Maps a database row to DictionaryEntry
  DictionaryEntry _mapRowToEntry(Map<String, dynamic> row) {
    final dictId = row['dict_id'] as String;

    // Infer target language from dictionary ID
    // BUS and MS are Sinhala target dictionaries, others are English
    final targetLang = (dictId == 'BUS' || dictId == 'MS') ? 'si' : 'en';

    // Handle is_exact as relevance score (0 for exact match, 1 for prefix match)
    final rawScore = row['is_exact'];
    final double? score = rawScore == null
        ? null
        : (rawScore is int ? rawScore.toDouble() : rawScore as double);

    return DictionaryEntry(
      id: row['id'] as int,
      word: row['word'] as String,
      dictionaryId: dictId,
      meaning: row['meaning'] as String,
      targetLanguage: targetLang,
      sourceLanguage: 'pali', // All entries are Pali source
      rank: row['rank'] as int,
      relevanceScore: score,
    );
  }

  @override
  Future<void> close() async {
    try {
      await _database?.close();
    } catch (e) {
      _log('Error closing dictionary database: $e');
    } finally {
      _database = null;
      _initialized = false;
    }
  }
}
