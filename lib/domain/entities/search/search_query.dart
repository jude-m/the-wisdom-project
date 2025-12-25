import 'package:freezed_annotation/freezed_annotation.dart';

import 'search_scope.dart';

part 'search_query.freezed.dart';

/// Represents a search query with filters
@freezed
class SearchQuery with _$SearchQuery {
  const factory SearchQuery({
    /// The search query text
    required String queryText,

    /// Whether to require exact word match (no prefix matching)
    /// Default false = prefix matching enabled (e.g., "සති" matches "සතිපට්ඨානය")
    @Default(false) bool isExactMatch,

    /// Editions to search within (e.g., {'bjt', 'sc'})
    /// If empty, searches all available editions
    @Default({}) Set<String> editionIds,

    /// Whether to search in Pali text
    @Default(true) bool searchInPali,

    /// Whether to search in Sinhala text
    @Default(true) bool searchInSinhala,

    /// Selected scope to search within.
    ///
    /// Empty set = search all content (no scope filter applied).
    /// Non-empty = search only within the selected scope (OR logic).
    ///
    /// Example:
    /// - {} = search everything
    /// - {sutta} = search only Sutta Pitaka
    /// - {sutta, commentaries} = search Sutta Pitaka OR Commentaries
    @Default({}) Set<SearchScope> scope,

    /// Maximum number of results to return
    @Default(50) int limit,

    /// Offset for pagination
    @Default(0) int offset,
  }) = _SearchQuery;
}
