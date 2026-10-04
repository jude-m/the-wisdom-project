import 'dart:convert';
import 'dart:developer' as developer;

import 'package:wisdom_shared/wisdom_shared.dart';

import '../../domain/entities/dictionary/dictionary_entry.dart';
import '../database/local_database.dart';
import 'dictionary_datasource.dart';

/// Implementation of dictionary data source
class DictionaryDataSourceImpl implements DictionaryDataSource {
  static const String _dbName = 'dict.db';

  LocalDatabase? _database;
  bool _initialized = false;

  /// Log debug messages only in debug mode.
  void _log(String message) {
    developer.log(message, name: 'DictionaryDataSource');
  }

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _database = await LocalDatabase.open(_dbName);

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
    try {
      return await _selectEntries(
        word,
        exactMatch: exactMatch,
        dictionaryIds: dictionaryIds,
        limit: limit,
      );
    } catch (e) {
      throw Exception('Dictionary lookup failed: $e');
    }
  }

  @override
  Future<List<DictionaryEntry>> searchDefinitions(
    String query, {
    bool isExactMatch = false,
    Set<String> dictionaryIds = const {},
    List<String> looseSpellings = const [],
    bool looseOnly = false,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      return await _selectEntries(
        query,
        exactMatch: isExactMatch,
        dictionaryIds: dictionaryIds,
        looseSpellings: looseSpellings,
        looseOnly: looseOnly,
        limit: limit,
        offset: offset,
      );
    } catch (e) {
      throw Exception('Dictionary search failed: $e');
    }
  }

  /// The entries for [word] (order: see dictionaryOrderBy), then — with
  /// [looseSpellings] — those only its similar spellings find.
  Future<List<DictionaryEntry>> _selectEntries(
    String word, {
    required bool exactMatch,
    required Set<String> dictionaryIds,
    List<String> looseSpellings = const [],
    bool looseOnly = false,
    required int limit,
    int offset = 0,
  }) async {
    await initialize();

    final db = _database;
    if (db == null) {
      throw StateError('Dictionary database not initialized');
    }

    final tiered = looseSpellings.isNotEmpty;
    final buffer = StringBuffer();
    buffer.write("""
      SELECT
        id, word, dict_id, meaning, rank,
        CASE WHEN word = ? THEN 0 ELSE 1 END AS is_exact""");
    final args = <Object>[word];
    if (tiered) {
      // [word]'s rows are tier 0, then each similar spelling's in turn.
      buffer.write(', CASE WHEN ');
      appendDictionaryWordMatch(buffer, args, word, exactMatch: exactMatch);
      buffer.write(' THEN 0');
      for (final (index, spelling) in looseSpellings.indexed) {
        buffer.write(' WHEN ');
        appendDictionaryWordMatch(buffer, args, spelling,
            exactMatch: exactMatch);
        buffer.write(' THEN ${index + 1}');
      }
      // A headword that is a whole spelling, not a longer word. The walk
      // keeps a long final a under the short spelling (පඤ්ඤ for පඤ්ඤා too),
      // so that form is a whole one as well.
      final readings = [
        for (final spelling in looseSpellings) ...[spelling, '$spellingා'],
      ];
      buffer.write(' END AS tier, CASE WHEN word IN '
          '(${List.filled(readings.length, '?').join(', ')}) '
          'THEN 0 ELSE 1 END AS is_reading');
      args.addAll(readings);
    }
    buffer.write("""

      FROM dictionary
      WHERE """);
    _appendMatch(
      buffer,
      args,
      word,
      exactMatch: exactMatch,
      looseSpellings: looseSpellings,
      looseOnly: looseOnly,
    );
    appendDictionaryFilter(buffer, args, dictionaryIds);
    buffer.write(
      ' ${tiered ? dictionaryTieredOrderBy : dictionaryOrderBy} '
      'LIMIT ? OFFSET ?',
    );
    args.addAll([limit, offset]);

    final results = await db.rawQuery(buffer.toString(), args);
    return results.map(_mapRowToEntry).toList();
  }

  /// The WHERE condition for [word] — and, with [looseSpellings], for its similar
  /// spellings too, or ([looseOnly]) for only the rows they add.
  static void _appendMatch(
    StringBuffer buffer,
    List<Object> args,
    String word, {
    required bool exactMatch,
    List<String> looseSpellings = const [],
    bool looseOnly = false,
  }) {
    if (looseSpellings.isEmpty) {
      appendDictionaryWordMatch(buffer, args, word, exactMatch: exactMatch);
      return;
    }
    buffer.write('(');
    if (!looseOnly) {
      buffer.write('(');
      appendDictionaryWordMatch(buffer, args, word, exactMatch: exactMatch);
      buffer.write(') OR ');
    }
    appendDictionaryAnyWordMatch(
      buffer,
      args,
      looseSpellings,
      exactMatch: exactMatch,
    );
    if (looseOnly) {
      buffer.write(' AND NOT (');
      appendDictionaryWordMatch(buffer, args, word, exactMatch: exactMatch);
      buffer.write(')');
    }
    buffer.write(')');
  }

  @override
  Future<int> countDefinitions(
    String query, {
    bool isExactMatch = false,
    Set<String> dictionaryIds = const {},
    List<String> looseSpellings = const [],
  }) async {
    await initialize();

    final db = _database;
    if (db == null) {
      throw StateError('Dictionary database not initialized');
    }

    try {
      // Build count query
      final buffer = StringBuffer();
      buffer.write('''
        SELECT COUNT(*) as count
        FROM dictionary
        WHERE ''');

      final args = <Object>[];

      _appendMatch(
        buffer,
        args,
        query,
        exactMatch: isExactMatch,
        looseSpellings: looseSpellings,
      );
      appendDictionaryFilter(buffer, args, dictionaryIds);

      final results = await db.rawQuery(buffer.toString(), args);
      return results.first['count'] as int;
    } catch (e) {
      throw Exception('Dictionary count failed: $e');
    }
  }

  @override
  Future<Set<String>> existingHeadwords(
    Set<String> candidates, {
    required bool wholeWords,
  }) async {
    if (candidates.isEmpty) return const {};
    await initialize();

    final db = _database;
    if (db == null) {
      throw StateError('Dictionary database not initialized');
    }

    try {
      // One statement per batch, one `idx_word` seek per candidate — the same
      // range as appendDictionaryWordMatch.
      final match = wholeWords
          ? 'd.word = j.value'
          : 'd.word >= j.value AND d.word < j.value || char(1114111)';
      final rows = await db.rawQuery(
        'SELECT j.value AS candidate FROM json_each(?) j '
        'WHERE EXISTS (SELECT 1 FROM dictionary d WHERE $match)',
        [jsonEncode(candidates.toList())],
      );
      return {for (final row in rows) row['candidate'] as String};
    } catch (e) {
      throw Exception('Headword lookup failed: $e');
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
      isLooseMatch: ((row['tier'] as int?) ?? 0) > 0,
    );
  }

  @override
  Future<void> close() async {
    try {
      if (_database != null) await LocalDatabase.closeShared(_dbName);
    } catch (e) {
      _log('Error closing dictionary database: $e');
    } finally {
      _database = null;
      _initialized = false;
    }
  }
}
