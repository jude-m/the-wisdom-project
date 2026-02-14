/// Represents a single match location within the document.
///
/// Each match is identified by its page, entry, language, and position
/// within that entry's match list (to avoid character offset mapping issues).
class InPageMatch {
  /// Index of the page in the document's pages list
  final int pageIndex;

  /// Index of the entry within the page's section
  final int entryIndex;

  /// Language code: 'pi' for Pali, 'si' for Sinhala
  final String languageCode;

  /// 0-based index within this entry's match list
  /// (e.g., if an entry has 3 matches, this is 0, 1, or 2)
  final int matchIndexInEntry;

  const InPageMatch({
    required this.pageIndex,
    required this.entryIndex,
    required this.languageCode,
    required this.matchIndexInEntry,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InPageMatch &&
          pageIndex == other.pageIndex &&
          entryIndex == other.entryIndex &&
          languageCode == other.languageCode &&
          matchIndexInEntry == other.matchIndexInEntry;

  @override
  int get hashCode => Object.hash(
        pageIndex,
        entryIndex,
        languageCode,
        matchIndexInEntry,
      );
}

/// State for the in-page search feature, scoped per tab.
///
/// Immutable with manual copyWith (no Freezed per plan).
class InPageSearchState {
  /// Whether the search bar is visible
  final bool isVisible;

  /// Raw user input (displayed in text field)
  final String rawQuery;

  /// Sanitized + Singlish-converted query (used for matching)
  final String effectiveQuery;

  /// All matches found in the document
  final List<InPageMatch> matches;

  /// Index into [matches] for the current highlighted match (-1 if none)
  final int currentMatchIndex;

  InPageSearchState({
    this.isVisible = false,
    this.rawQuery = '',
    this.effectiveQuery = '',
    this.matches = const [],
    this.currentMatchIndex = -1,
  });

  InPageSearchState copyWith({
    bool? isVisible,
    String? rawQuery,
    String? effectiveQuery,
    List<InPageMatch>? matches,
    int? currentMatchIndex,
  }) {
    return InPageSearchState(
      isVisible: isVisible ?? this.isVisible,
      rawQuery: rawQuery ?? this.rawQuery,
      effectiveQuery: effectiveQuery ?? this.effectiveQuery,
      matches: matches ?? this.matches,
      currentMatchIndex: currentMatchIndex ?? this.currentMatchIndex,
    );
  }

  /// Whether a Singlish conversion was applied
  bool get isSinglishConverted =>
      rawQuery.isNotEmpty &&
      effectiveQuery.isNotEmpty &&
      rawQuery != effectiveQuery;

  /// Total number of matches
  int get matchCount => matches.length;

  /// Whether there are any matches
  bool get hasMatches => matches.isNotEmpty;

  /// Whether the search is active and has a query to highlight.
  /// Centralizes the visibility + query check used by renderers.
  bool get hasActiveQuery => effectiveQuery.isNotEmpty && isVisible;

  /// The current match, if any
  InPageMatch? get currentMatch =>
      currentMatchIndex >= 0 && currentMatchIndex < matches.length
          ? matches[currentMatchIndex]
          : null;

  /// Set of (pageIndex, entryIndex, languageCode) tuples that have at least
  /// one match. Used by the renderer to avoid highlighting entries that are
  /// outside the sutta boundary but still visible due to infinite scroll.
  ///
  /// Computed once on first access, then cached for all subsequent reads.
  /// Safe because InPageSearchState is immutable — each copyWith creates
  /// a new instance with its own lazy field.
  late final Set<(int, int, String)> matchedEntries = {
    for (final m in matches) (m.pageIndex, m.entryIndex, m.languageCode),
  };

  /// Returns true if the given entry has at least one search match.
  bool hasMatchInEntry(int pageIndex, int entryIndex, String languageCode) {
    return matchedEntries.contains((pageIndex, entryIndex, languageCode));
  }
}
