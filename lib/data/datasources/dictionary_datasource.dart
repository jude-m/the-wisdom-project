import '../../domain/entities/dictionary/dictionary_entry.dart';

/// Abstract interface for dictionary data source
abstract class DictionaryDataSource {
  /// Initialize the dictionary database
  Future<void> initialize();

  /// Lookup a word in the dictionary (exact or prefix match)
  /// Returns entries ordered by: exact match first, then by rank
  ///
  /// [dictionaryIds] - Filter to specific dict IDs, empty = all
  Future<List<DictionaryEntry>> lookupWord(
    String word, {
    bool exactMatch = false,
    Set<String> dictionaryIds = const {},
    int limit = 50,
  });

  /// Search definitions for a query (used in search tab)
  ///
  /// [dictionaryIds] - Filter to specific dict IDs, empty = all
  /// [looseSpellings] - headword spellings that sound like a Singlish query,
  /// in search order; the entries only they find follow, each spelling's in
  /// turn, flagged [DictionaryEntry.isLooseMatch]. [looseOnly] returns just
  /// those entries.
  Future<List<DictionaryEntry>> searchDefinitions(
    String query, {
    bool isExactMatch = false,
    Set<String> dictionaryIds = const {},
    List<String> looseSpellings = const [],
    bool looseOnly = false,
    int limit = 50,
    int offset = 0,
  });

  /// Count definition matches for a query (for tab badge)
  ///
  /// [dictionaryIds] - Filter to specific dict IDs, empty = all
  /// [looseSpellings] - as in [searchDefinitions]; both tiers are counted
  Future<int> countDefinitions(
    String query, {
    bool isExactMatch = false,
    Set<String> dictionaryIds = const {},
    List<String> looseSpellings = const [],
  });

  /// Which [candidates] begin a headword — or, with [wholeWords], are one.
  /// Loose Singlish keeps only these.
  Future<Set<String>> existingHeadwords(
    Set<String> candidates, {
    required bool wholeWords,
  });

  /// Close the database connection
  Future<void> close();
}
