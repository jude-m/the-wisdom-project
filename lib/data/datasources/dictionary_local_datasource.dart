import 'dart:developer' as developer;

import 'package:wisdom_shared/wisdom_shared.dart';

import '../../domain/entities/dictionary/dictionary_entry.dart';
import '../database/bundled_database.dart';
import 'dictionary_datasource.dart';

/// Implementation of dictionary data source
class DictionaryDataSourceImpl implements DictionaryDataSource {
  static const String _dbName = 'dict.db';

  BundledDatabase? _database;
  bool _initialized = false;

  /// Log debug messages only in debug mode.
  void _log(String message) {
    developer.log(message, name: 'DictionaryDataSource');
  }

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _database = await BundledDatabase.open(_dbName);

      _initialized = true;
    } catch (e) {
      throw Exception('Failed to initialize dictionary database: $e');
    }
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
      final likePattern =
          buildDictionaryLikePattern(word, exactMatch: exactMatch);

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

      appendDictionaryFilter(buffer, args, dictionaryIds);

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
      final likePattern =
          buildDictionaryLikePattern(query, exactMatch: isExactMatch);

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

      appendDictionaryFilter(buffer, args, dictionaryIds);

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
      final likePattern =
          buildDictionaryLikePattern(query, exactMatch: isExactMatch);

      // Build count query
      final buffer = StringBuffer();
      buffer.write('''
        SELECT COUNT(*) as count
        FROM dictionary
        WHERE word LIKE ? ESCAPE '\\'
      ''');

      final args = <Object>[likePattern];

      appendDictionaryFilter(buffer, args, dictionaryIds);

      final results = await db.rawQuery(buffer.toString(), args);
      return results.first['count'] as int;
    } catch (e) {
      throw Exception('Dictionary count failed: $e');
    }
  }

  /// Maps a database row to DictionaryEntry
  DictionaryEntry _mapRowToEntry(Map<String, dynamic> row) {
    final dictId = row['dict_id'] as String;
    final targetLang = inferTargetLanguage(dictId);

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
      if (_database != null) await BundledDatabase.closeShared(_dbName);
    } catch (e) {
      _log('Error closing dictionary database: $e');
    } finally {
      _database = null;
      _initialized = false;
    }
  }
}
