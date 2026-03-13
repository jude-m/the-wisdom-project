import 'package:dartz/dartz.dart';

import '../entities/dictionary/dictionary_entry.dart';
import '../entities/failure.dart';

/// Repository interface for dictionary lookup functionality
abstract class DictionaryRepository {
  /// Lookup a word in the dictionary
  /// Returns entries ordered by exact match first, then by rank
  ///
  /// [word] - The Pali word to lookup (in Sinhala script)
  /// [exactMatch] - If true, only return exact matches; if false, also match prefixes
  /// [dictionaryIds] - Filter to specific dict IDs, empty = all
  /// [limit] - Maximum number of results to return
  Future<Either<Failure, List<DictionaryEntry>>> lookupWord(
    String word, {
    bool exactMatch = false,
    Set<String> dictionaryIds = const {},
    int limit = 50,
  });

  /// Search definitions for a query (used in search tab)
  ///
  /// [query] - The search query
  /// [isExactMatch] - If true, only return exact matches
  /// [dictionaryIds] - Filter to specific dict IDs, empty = all
  /// [limit] - Maximum number of results to return
  /// [offset] - Offset for pagination
  Future<Either<Failure, List<DictionaryEntry>>> searchDefinitions(
    String query, {
    bool isExactMatch = false,
    Set<String> dictionaryIds = const {},
    int limit = 50,
    int offset = 0,
  });

  /// Count definition matches for a query (for tab badge)
  ///
  /// [query] - The search query
  /// [isExactMatch] - If true, only count exact matches
  /// [dictionaryIds] - Filter to specific dict IDs, empty = all
  Future<Either<Failure, int>> countDefinitions(
    String query, {
    bool isExactMatch = false,
    Set<String> dictionaryIds = const {},
  });
}
