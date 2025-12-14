import 'package:dartz/dartz.dart';
import '../entities/failure.dart';
import '../entities/search/categorized_search_result.dart';
import '../entities/search/search_category.dart';
import '../entities/search/search_query.dart';
import '../entities/search/search_result.dart';

/// Repository interface for text search functionality
abstract class TextSearchRepository {
  /// Get categorized preview results (max [maxPerCategory] per category)

  /// Used for the search dropdown preview that shows limited results per category
  Future<Either<Failure, CategorizedSearchResult>> searchCategorizedPreview(
    SearchQuery query, {
    int maxPerCategory = 3,
  });

  /// Get full results for a specific category
  /// Used when viewing all results for one category in the full results screen
  Future<Either<Failure, List<SearchResult>>> searchByCategory(
    SearchQuery query,
    SearchCategory category,
  );

  /// Get auto-complete suggestions for the given prefix
  Future<Either<Failure, List<String>>> getSuggestions(
    String prefix, {
    String? language,
  });
}
