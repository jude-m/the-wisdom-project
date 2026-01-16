import 'package:freezed_annotation/freezed_annotation.dart';

import 'search_result.dart';

part 'grouped_fts_match.freezed.dart';

/// Groups multiple FTS matches from the same content file (sutta/section).
///
/// Used to reduce visual clutter in search results by showing one primary
/// match with an option to expand and see additional matches from the same text.
@freezed
class GroupedFTSMatch with _$GroupedFTSMatch {
  const GroupedFTSMatch._();

  const factory GroupedFTSMatch({
    /// Content file identifier (e.g., 'dn-1') - the grouping key
    required String contentFileId,

    /// Tree navigation key
    required String nodeKey,

    /// Document title
    required String title,

    /// Navigation path (e.g., "Dīgha Nikāya > Sīlakkhandhavagga")
    required String subtitle,

    /// Edition this group belongs to (e.g., 'bjt', 'sc')
    required String editionId,

    /// First match shown in collapsed view
    required SearchResult primaryMatch,

    /// Additional matches (shown when expanded)
    @Default([]) List<SearchResult> secondaryMatches,
  }) = _GroupedFTSMatch;

  /// Whether there are additional matches beyond the primary
  bool get hasSecondaryMatches => secondaryMatches.isNotEmpty;

  /// Count of secondary matches (for "See X more" text)
  int get secondaryMatchCount => secondaryMatches.length;

  /// All matches including primary
  List<SearchResult> get allMatches => [primaryMatch, ...secondaryMatches];

  /// Groups flat search results by nodeKey (sutta/section identifier).
  ///
  /// Results within each group are sorted by appearance order in the text
  /// (pageIndex, then entryIndex). The first match becomes primaryMatch,
  /// the rest become secondaryMatches.
  static List<GroupedFTSMatch> fromSearchResults(List<SearchResult> results) {
    if (results.isEmpty) return [];

    // Group by nodeKey (sutta/section) instead of contentFileId (file)
    // This correctly groups matches by their containing sutta, even when
    // multiple suttas share the same content file
    final Map<String, List<SearchResult>> grouped = {};
    for (final result in results) {
      final key = result.nodeKey;
      grouped.putIfAbsent(key, () => []).add(result);
    }

    // Convert each group to GroupedFTSMatch
    final List<GroupedFTSMatch> groupedResults = [];

    for (final entry in grouped.entries) {
      final matches = entry.value;

      // Sort by appearance order in text (pageIndex, then entryIndex)
      matches.sort((a, b) {
        final pageCompare = a.pageIndex.compareTo(b.pageIndex);
        if (pageCompare != 0) return pageCompare;
        return a.entryIndex.compareTo(b.entryIndex);
      });

      // First match is primary, rest are secondary
      final primaryMatch = matches.first;
      final secondaryMatches = matches.length > 1 ? matches.sublist(1) : <SearchResult>[];

      groupedResults.add(
        GroupedFTSMatch(
          contentFileId: primaryMatch.contentFileId,
          nodeKey: primaryMatch.nodeKey,
          title: primaryMatch.title,
          subtitle: primaryMatch.subtitle,
          editionId: primaryMatch.editionId,
          primaryMatch: primaryMatch,
          secondaryMatches: secondaryMatches,
        ),
      );
    }

    return groupedResults;
  }
}
