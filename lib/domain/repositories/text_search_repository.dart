import 'package:dartz/dartz.dart';
import '../entities/failure.dart';
import '../entities/search/grouped_search_result.dart';
import '../entities/search/search_result_type.dart';
import '../entities/search/search_query.dart';
import '../entities/search/search_result.dart';

/// Repository interface for text search functionality
abstract class TextSearchRepository {
  /// Get categorized preview results (max [maxPerCategory] per category)

  /// Used for the search dropdown preview that shows limited results per category
  Future<Either<Failure, GroupedSearchResult>> searchTopResults(
    SearchQuery query, {
    int maxPerCategory = 3,
  });

  /// Get full results for a specific category
  /// Used when viewing all results for one category in the full results screen
  Future<Either<Failure, List<SearchResult>>> searchByResultType(
    SearchQuery query,
    SearchResultType resultType,
  );

  /// Get result counts per search type (for tab badges)
  /// Efficient method that only fetches counts, not actual results
  Future<Either<Failure, Map<SearchResultType, int>>> countByResultType(
    SearchQuery query,
  );

  /// Get auto-complete suggestions for the given prefix
  Future<Either<Failure, List<String>>> getSuggestions(
    String prefix, {
    String? language,
  });
}
