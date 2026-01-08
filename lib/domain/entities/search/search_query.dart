import 'package:freezed_annotation/freezed_annotation.dart';

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

    /// Search scope using tree node keys (e.g., 'sp', 'dn', 'kn-dhp').
    ///
    /// Empty set = search all content (no scope filter applied).
    /// Non-empty = search only within the selected scope (OR logic).
    ///
    /// Examples:
    /// - {} = search everything
    /// - {'sp'} = search only Sutta Pitaka
    /// - {'dn', 'mn'} = search Digha Nikaya OR Majjhima Nikaya
    /// - {'atta-vp', 'atta-sp', 'atta-ap'} = search all Commentaries
    @Default({}) Set<String> scope,

    /// Proximity distance for multi-word queries.
    /// Default 10 = words within 10 tokens (NEAR/10).
    /// null = phrase matching (consecutive words only).
    /// 1-30 = NEAR/n proximity search.
    @Default(10) int? proximityDistance,

    /// Maximum number of results to return
    @Default(50) int limit,

    /// Offset for pagination
    @Default(0) int offset,
  }) = _SearchQuery;
}
