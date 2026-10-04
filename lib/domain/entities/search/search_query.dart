import 'package:freezed_annotation/freezed_annotation.dart';

import 'loose_spellings.dart';

part 'search_query.freezed.dart';

/// Represents a search query with filters
@freezed
class SearchQuery with _$SearchQuery {
  const SearchQuery._();

  const factory SearchQuery({
    /// The search query text
    required String queryText,

    /// Spellings that sound like a Singlish query: the "similar spellings"
    /// tier after the strict results. Empty = strict only.
    @Default(LooseSpellings()) LooseSpellings looseSpellings,

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

    /// Whether to search as a phrase (consecutive words) or separate words.
    /// - true (DEFAULT) = phrase search (words must be adjacent)
    /// - false = separate-word search (words within proximity distance)
    @Default(true) bool isPhraseSearch,

    /// Whether to ignore proximity and search anywhere in the same text unit.
    /// Only applies when [isPhraseSearch] is false.
    /// - true = search for words anywhere in the text (uses very large proximity)
    /// - false (DEFAULT) = use [proximityDistance] for proximity constraint
    @Default(false) bool isAnywhereInText,

    /// Proximity distance for multi-word separate-word queries.
    /// Only applies when [isPhraseSearch] is false and [isAnywhereInText] is false.
    /// Default 10 = words within 10 tokens (NEAR/10).
    /// Range: 1-100.
    @Default(10) int proximityDistance,

    /// Dictionary IDs to filter definitions by (e.g., {'BUS', 'MS'} for Sinhala).
    /// Empty set = no restriction (search all dictionaries).
    @Default({}) Set<String> selectedDictionaryIds,

    /// Maximum number of results to return
    @Default(50) int limit,

    /// Offset for pagination
    @Default(0) int offset,
  }) = _SearchQuery;

  /// The editions to search: [editionIds], or BJT when none is chosen.
  Set<String> get editionsToSearch =>
      editionIds.isEmpty ? const {'bjt'} : editionIds;

  /// What titles and full text list first, above the similar-spellings
  /// divider: each typed word's lead spelling — the strict one, unless a far
  /// more common one outranks it — or [queryText] itself when there are no
  /// similar spellings. Definitions keep [queryText] first.
  String get leadText => looseSpellings.words.isEmpty
      ? queryText
      : [for (final spellings in looseSpellings.words) spellings.first]
          .join(' ');
}
