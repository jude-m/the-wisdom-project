import 'package:freezed_annotation/freezed_annotation.dart';

import '../reader/reader_unit.dart';
import 'search_result.dart';
import 'search_result_unit.dart';

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

  /// Groups flat search results by the sutta each match's *row* belongs to.
  ///
  /// Results within each group are sorted by appearance order in the text
  /// (pageIndex, then entryIndex). The first match becomes primaryMatch,
  /// the rest become secondaryMatches.
  ///
  /// [resolver] is what answers which sutta owns a row — see
  /// [SearchResultUnitKey.unitKey] for why the stored `nodeKey` cannot. Every
  /// result is rewritten to the key it groups under, so this is the one place
  /// the correction has to be made: the tiles below label and open the result
  /// they are handed.
  static List<GroupedFTSMatch> fromSearchResults(
    List<SearchResult> results, {
    ReaderUnitResolver? resolver,
  }) {
    if (results.isEmpty) return [];

    // Group by node (sutta/section) instead of contentFileId (file), so
    // matches group by their containing sutta even when several suttas share
    // one content file.
    final Map<String, List<SearchResult>> grouped = {};
    for (final result in results) {
      final key = result.unitKey(resolver);
      grouped
          .putIfAbsent(key, () => [])
          .add(key == result.nodeKey ? result : result.copyWith(nodeKey: key));
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
