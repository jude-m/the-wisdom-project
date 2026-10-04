import 'package:wisdom_shared/wisdom_shared.dart' show spellingCombinations;

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

  /// Similar spellings of each query word (loose Singlish), matched as the
  /// word itself is. Empty = the query only.
  final List<List<String>> looseAlternatives;

  /// Cached normalized query and words for reuse.
  late final String _normalizedQuery;

  /// What each query word may read as: the word first, then its spellings.
  late final List<List<String>> _queryWords;

  /// Whole-query forms for exact phrases: the query, then each combination of
  /// spellings.
  late final List<String> _phrases;

  SearchMatchFinder({
    required this.queryText,
    required this.isPhraseSearch,
    required this.isExactMatch,
    this.maxGap = 20,
    this.looseAlternatives = const [],
  }) {
    _normalizedQuery = normalizeText(queryText, toLowerCase: true);
    final words = splitQueryWords(queryText);
    // Spellings are per typed word, so they only line up word for word.
    final aligned =
        looseAlternatives.isNotEmpty && looseAlternatives.length == words.length;
    _queryWords = [
      for (var i = 0; i < words.length; i++)
        [words[i], if (aligned) ...looseAlternatives[i]],
    ];
    _phrases = [
      _normalizedQuery,
      if (aligned)
        for (final spellings in spellingCombinations(looseAlternatives))
          spellings.join(' '),
    ];
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
    for (final phrase in _phrases) {
      int searchStart = 0;

      while (true) {
        final normIndex = matcher.normalized.indexOf(phrase, searchStart);
        if (normIndex == -1) break;

        ranges.add(
            matcher.mapToOriginal(normIndex, normIndex + phrase.length));
        searchStart = normIndex + phrase.length;
      }
    }

    // Fallback: FTS returns hyphenated text for space-separated query
    // e.g., "සීල-සමාධි" matches query "සීල සමාධි"
    if (ranges.isEmpty &&
        _queryWords.length >= 2 &&
        (matcher.normalized.contains('-') ||
            matcher.normalized.contains(','))) {
      return _findPhraseRanges(matcher);
    }

    // One phrase is found in order already; several need sorting and merging.
    if (_phrases.length == 1) return ranges;
    ranges.sort((a, b) => a.start.compareTo(b.start));
    return mergeOverlappingRanges(ranges);
  }

  /// Finds all phrase occurrences (words adjacent).
  List<({int start, int end})> _findPhraseRanges(
      NormalizedTextMatcher matcher) {
    if (_queryWords.isEmpty) return [];
    if (_queryWords.length == 1) return _findWordRanges(matcher);

    final ranges = <({int start, int end})>[];
    int searchStart = 0;

    while (searchStart < matcher.normalized.length) {
      final firstWord =
          _earliest(matcher.normalized, _queryWords.first, searchStart);
      if (firstWord == null) break;
      final firstWordIndex = firstWord.index;

      bool allWordsFound = true;
      int currentPos = firstWordIndex + firstWord.length;
      int phraseEndPos = currentPos;

      for (int i = 1; i < _queryWords.length; i++) {
        final searchEnd =
            (currentPos + maxGap).clamp(0, matcher.normalized.length);
        final searchWindow =
            matcher.normalized.substring(currentPos, searchEnd);
        final nextWord = _earliest(searchWindow, _queryWords[i], 0);

        if (nextWord == null) {
          allWordsFound = false;
          break;
        }
        currentPos = currentPos + nextWord.index + nextWord.length;
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

    for (final word in _queryWords.expand((options) => options)) {
      allRanges.addAll(_findSingleWordRanges(matcher, word));
    }

    if (allRanges.isEmpty) return [];

    // Sort and merge overlapping ranges
    allRanges.sort((a, b) => a.start.compareTo(b.start));
    return mergeOverlappingRanges(allRanges);
  }

  /// The first occurrence in [text] from [start] of any of [options].
  static ({int index, int length})? _earliest(
    String text,
    List<String> options,
    int start,
  ) {
    ({int index, int length})? first;
    for (final option in options) {
      final index = text.indexOf(option, start);
      if (index != -1 && (first == null || index < first.index)) {
        first = (index: index, length: option.length);
      }
    }
    return first;
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
/// Handles mapping between normalized text (ZWJ/punctuation removed, lowercased)
/// and original text positions, which is necessary for highlighting the correct
/// characters in the UI.
class NormalizedTextMatcher {
  /// The original text as provided.
  final String original;

  /// Normalized text (ZWJ/punctuation removed, lowercased).
  final String normalized;

  /// Position map from normalized indices to original indices.
  final List<int> _positionMap;

  factory NormalizedTextMatcher(String text) {
    final result = normalizeSearchText(text);
    return NormalizedTextMatcher._(text, result.normalized, result.positionMap);
  }

  NormalizedTextMatcher._(this.original, this.normalized, this._positionMap);

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
/// Assumes the query has already been sanitized by [sanitizeSearchQuery],
/// which strips punctuation before this is called.
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
