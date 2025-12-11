import 'package:freezed_annotation/freezed_annotation.dart';

part 'search_query.freezed.dart';

/// Type of search to perform
enum SearchType {
  /// Search both names and content
  all,

  /// Search only in sutta/document names
  nameOnly,

  /// Search only in content/text
  contentOnly,
}

/// Represents a search query with filters
@freezed
class SearchQuery with _$SearchQuery {
  const factory SearchQuery({
    /// The search query text
    required String queryText,

    /// Editions to search within (e.g., {'bjt', 'sc'})
    /// If empty, searches all available editions
    @Default({}) Set<String> editionIds,

    /// Whether to search in Pali text
    @Default(true) bool searchInPali,

    /// Whether to search in Sinhala text
    @Default(true) bool searchInSinhala,

    /// Filter by Nikaya (e.g., ['dn', 'mn'])
    @Default([]) List<String> nikayaFilters,

    /// Filter by label/tag
    @Default([]) List<String> labelFilters,

    /// Type of search to perform
    @Default(SearchType.all) SearchType searchType,

    /// Maximum number of results to return
    @Default(50) int limit,

    /// Offset for pagination
    @Default(0) int offset,
  }) = _SearchQuery;
}
