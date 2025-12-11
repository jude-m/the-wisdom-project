import 'package:freezed_annotation/freezed_annotation.dart';
import 'search_category.dart';
import 'search_result.dart';

part 'categorized_search_result.freezed.dart';

/// Container for search results grouped by category
/// Used for the preview dropdown that shows max 3 results per category
@freezed
class CategorizedSearchResult with _$CategorizedSearchResult {
  const CategorizedSearchResult._();

  const factory CategorizedSearchResult({
    /// Results grouped by category
    required Map<SearchCategory, List<SearchResult>> resultsByCategory,

    /// Total count of all results across all categories
    required int totalCount,
  }) = _CategorizedSearchResult;

  /// Get results for a specific category
  List<SearchResult> getResultsForCategory(SearchCategory category) {
    return resultsByCategory[category] ?? [];
  }

  /// Check if there are results for a category
  bool hasResultsForCategory(SearchCategory category) {
    return resultsByCategory.containsKey(category) &&
        resultsByCategory[category]!.isNotEmpty;
  }

  /// Get all categories that have results
  List<SearchCategory> get categoriesWithResults {
    return resultsByCategory.entries
        .where((entry) => entry.value.isNotEmpty)
        .map((entry) => entry.key)
        .toList();
  }

  /// Check if there are any results at all
  bool get isEmpty => totalCount == 0;

  /// Check if there are results
  bool get isNotEmpty => totalCount > 0;
}
