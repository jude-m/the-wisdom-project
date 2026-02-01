import 'text_utils.dart';

/// Utility for finding search matches in text with ZWJ normalization.
///
/// This is a shared utility used by:
/// - `HighlightedFtsSearchText` (search panel snippets)
/// - `TextEntryWidget` (reader search highlighting)
///
/// Supports three search modes:
/// - **Exact phrase**: Entire query as single match
/// - **Phrase search**: Adjacent words with prefix matching
/// - **Separate words**: Each word highlighted independently
class SearchMatchFinder {
  /// The search query text (already sanitized + Singlish converted).
  final String queryText;

  /// Phrase mode: words must appear adjacent. Otherwise within proximity.
  final bool isPhraseSearch;

  /// Exact mode: exact token match. Otherwise prefix matching.
  final bool isExactMatch;

  /// Gap allowed between words in phrase search (in normalized characters).
  final int maxGap;

  /// Cached normalized query and words for reuse.
  late final String _normalizedQuery;
  late final List<String> _queryWords;

  SearchMatchFinder({
    required this.queryText,
    required this.isPhraseSearch,
    required this.isExactMatch,
    this.maxGap = 20,
  }) {
    _normalizedQuery = normalizeText(queryText, toLowerCase: true);
    _queryWords = splitQueryWords(queryText);
  }

  /// Find all highlight ranges in the given text.
  ///
  /// Returns a list of (start, end) positions in the original text
  /// where matches were found. Ranges are sorted and non-overlapping.
  List<({int start, int end})> findMatchRanges(String text) {
    if (_normalizedQuery.isEmpty || text.isEmpty) return [];

    final textMatcher = NormalizedTextMatcher(text);

    // Route to appropriate finder based on search mode
    if (isPhraseSearch && isExactMatch) {
      return _findExactRanges(textMatcher);
    } else if (isPhraseSearch) {
      return _findPhraseRanges(textMatcher);
    } else {
      return _findWordRanges(textMatcher);
    }
  }

  /// Finds all exact query matches.
  List<({int start, int end})> _findExactRanges(NormalizedTextMatcher matcher) {
    final ranges = <({int start, int end})>[];
    int searchStart = 0;

    while (true) {
      final normIndex = matcher.normalized.indexOf(_normalizedQuery, searchStart);
      if (normIndex == -1) break;

      ranges.add(matcher.mapToOriginal(normIndex, normIndex + _normalizedQuery.length));
      searchStart = normIndex + _normalizedQuery.length;
    }

    // Fallback: FTS returns hyphenated text for space-separated query
    // e.g., "සීල-සමාධි" matches query "සීල සමාධි"
    if (ranges.isEmpty &&
        _queryWords.length >= 2 &&
        (matcher.normalized.contains('-') ||
            matcher.normalized.contains(','))) {
      return _findPhraseRanges(matcher);
    }

    return ranges;
  }

  /// Finds all phrase occurrences (words adjacent).
  List<({int start, int end})> _findPhraseRanges(NormalizedTextMatcher matcher) {
    if (_queryWords.isEmpty) return [];
    if (_queryWords.length == 1) return _findWordRanges(matcher);

    final ranges = <({int start, int end})>[];
    int searchStart = 0;

    while (searchStart < matcher.normalized.length) {
      final firstWordIndex = matcher.normalized.indexOf(_queryWords.first, searchStart);
      if (firstWordIndex == -1) break;

      bool allWordsFound = true;
      int currentPos = firstWordIndex + _queryWords.first.length;
      int phraseEndPos = currentPos;

      for (int i = 1; i < _queryWords.length; i++) {
        final searchEnd = (currentPos + maxGap).clamp(0, matcher.normalized.length);
        final searchWindow = matcher.normalized.substring(currentPos, searchEnd);
        final nextWordIndex = searchWindow.indexOf(_queryWords[i]);

        if (nextWordIndex == -1) {
          allWordsFound = false;
          break;
        }
        currentPos = currentPos + nextWordIndex + _queryWords[i].length;
        phraseEndPos = currentPos;
      }

      if (allWordsFound) {
        ranges.add(matcher.mapToOriginal(firstWordIndex, phraseEndPos));
      }
      searchStart = firstWordIndex + 1;
    }
    return ranges;
  }

  /// Finds all occurrences of all words independently.
  List<({int start, int end})> _findWordRanges(NormalizedTextMatcher matcher) {
    if (_queryWords.isEmpty) return [];

    final allRanges = <({int start, int end})>[];

    for (final word in _queryWords) {
      allRanges.addAll(_findSingleWordRanges(matcher, word));
    }

    if (allRanges.isEmpty) return [];

    // Sort and merge overlapping ranges
    allRanges.sort((a, b) => a.start.compareTo(b.start));
    return mergeOverlappingRanges(allRanges);
  }

  /// Finds all occurrences of a single word.
  List<({int start, int end})> _findSingleWordRanges(
    NormalizedTextMatcher matcher,
    String word,
  ) {
    final ranges = <({int start, int end})>[];
    int searchStart = 0;

    while (true) {
      final normIndex = matcher.normalized.indexOf(word, searchStart);
      if (normIndex == -1) break;

      ranges.add(matcher.mapToOriginal(normIndex, normIndex + word.length));
      searchStart = normIndex + word.length;
    }
    return ranges;
  }
}

// =============================================================================
// HELPER CLASSES AND UTILITIES
// =============================================================================

/// Caches normalization data for efficient text matching.
///
/// Handles mapping between normalized text (ZWJ removed, lowercased) and
/// original text positions, which is necessary for highlighting the correct
/// characters in the UI.
class NormalizedTextMatcher {
  /// The original text as provided.
  final String original;

  /// Normalized text (ZWJ removed, lowercased).
  final String normalized;

  /// Position map from normalized indices to original indices.
  final List<int> _positionMap;

  NormalizedTextMatcher(String text)
      : original = text,
        normalized = normalizeText(text, toLowerCase: true),
        _positionMap = createNormalizedToOriginalPositionMap(text);

  /// Maps normalized [start, end) range to original text positions.
  ({int start, int end}) mapToOriginal(int normStart, int normEnd) => (
        start: _positionMap[normStart],
        end: normEnd < _positionMap.length
            ? _positionMap[normEnd]
            : original.length,
      );
}

/// Splits query into normalized non-empty words.
///
/// Uses the same normalization as [NormalizedTextMatcher] for consistency.
List<String> splitQueryWords(String query) =>
    normalizeText(query, toLowerCase: true)
        .split(' ')
        .where((w) => w.isNotEmpty)
        .toList();

/// Merges overlapping ranges into non-overlapping ranges.
///
/// Assumes [ranges] is sorted by start position.
/// Returns a new list with overlapping ranges combined.
List<({int start, int end})> mergeOverlappingRanges(
    List<({int start, int end})> ranges) {
  if (ranges.isEmpty) return ranges;

  final merged = <({int start, int end})>[];
  for (final range in ranges) {
    if (merged.isEmpty || merged.last.end < range.start) {
      merged.add(range);
    } else {
      final last = merged.removeLast();
      merged.add((
        start: last.start,
        end: range.end > last.end ? range.end : last.end,
      ));
    }
  }
  return merged;
}
