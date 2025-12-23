import 'package:freezed_annotation/freezed_annotation.dart';
import 'search_result_type.dart';
import 'search_result.dart';

part 'grouped_search_result.freezed.dart';

/// Container for search results grouped by result type
/// Used for the top results tab that shows max 3 results per result type
@freezed
class GroupedSearchResult with _$GroupedSearchResult {
  const GroupedSearchResult._();

  const factory GroupedSearchResult({
    /// Results grouped by result type (limited preview, e.g., max 3 per result type)
    required Map<SearchResultType, List<SearchResult>> resultsByType,
  }) = _GroupedSearchResult;

  /// Get results for a specific result type
  List<SearchResult> getResultsByType(SearchResultType resultType) {
    return resultsByType[resultType] ?? [];
  }

  /// Total count of top results
  int get totalCount =>
      resultsByType.values.fold(0, (sum, list) => sum + list.length);

  /// Check if there are results for a result type
  bool hasResultsForType(SearchResultType resultType) {
    return resultsByType.containsKey(resultType) &&
        resultsByType[resultType]!.isNotEmpty;
  }

  /// Get all result types that have results
  List<SearchResultType> get categoriesWithResults {
    return resultsByType.entries
        .where((entry) => entry.value.isNotEmpty)
        .map((entry) => entry.key)
        .toList();
  }

  /// Check if there are any results at all
  bool get isEmpty => totalCount == 0;

  /// Check if there are results
  bool get isNotEmpty => totalCount > 0;
}
