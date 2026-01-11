import 'package:flutter/material.dart';
import '../../core/utils/text_utils.dart';

/// Displays text with search query matches highlighted.
///
/// Supports three modes:
/// - **Exact phrase**: Entire query as single match
/// - **Phrase with prefix**: Adjacent words with prefix matching
/// - **Separate words**: Each word highlighted independently
class HighlightedSearchText extends StatelessWidget {
  /// The text content to display and highlight matches within.
  final String matchedText;

  /// Pre-computed effective query (sanitized + Singlish converted).
  final String effectiveQuery;

  /// Phrase mode: words must appear adjacent. Otherwise within proximity.
  final bool isPhraseSearch;

  /// Exact mode: exact token match. Otherwise prefix matching.
  final bool isExactMatch;

  /// Maximum display lines. Defaults to 3.
  final int maxLines;

  const HighlightedSearchText({
    super.key,
    required this.matchedText,
    required this.effectiveQuery,
    required this.isPhraseSearch,
    required this.isExactMatch,
    this.maxLines = 3,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _buildHighlightedText(matchedText, theme);
  }

  /// Main entry point for building highlighted text.
  Widget _buildHighlightedText(String matchedText, ThemeData theme) {
    final baseStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    final queryWords = _splitWords(effectiveQuery);
    final normalizedQuery = normalizeText(effectiveQuery, toLowerCase: true);

    // Create snippet centered around match
    final snippet = _createSnippet(text: matchedText, query: effectiveQuery);

    final highlightStyle = TextStyle(
      backgroundColor: theme.colorScheme.primaryContainer,
      fontWeight: FontWeight.bold,
      color: theme.colorScheme.onPrimaryContainer,
    );

    // Build spans based on search mode
    final spans = _buildSpansForMode(
      snippet: snippet,
      query: normalizedQuery,
      words: queryWords,
      highlightStyle: highlightStyle,
    );

    return RichText(
      text: TextSpan(style: baseStyle, children: spans),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// Routes to appropriate span builder based on search mode.
  List<TextSpan> _buildSpansForMode({
    required String snippet,
    required String query,
    required List<String> words,
    required TextStyle highlightStyle,
  }) {
    if (isPhraseSearch && isExactMatch) {
      return _buildSpansExact(snippet, query, highlightStyle);
    } else if (isPhraseSearch) {
      return _buildSpansPhrase(snippet, words, highlightStyle);
    } else {
      return _buildSpansWords(snippet, words, highlightStyle);
    }
  }

  // ===========================================================================
  // SNIPPET CREATION
  // ===========================================================================

  /// Creates text snippet centered around first match.
  String _createSnippet({
    required String text,
    required String query,
    int contextBefore = 50,
    int contextAfter = 100,
  }) {
    final textMatcher = _NormalizedTextMatcher(text);
    final normalizedQuery = normalizeText(query, toLowerCase: true);
    final words = _splitWords(query);

    // Find match position
    int matchIndex;
    int matchLength;

    if (isPhraseSearch && isExactMatch) {
      matchIndex = textMatcher.normalized.indexOf(normalizedQuery);
      matchLength = normalizedQuery.length;

      // Fallback: FTS returns hyphenated text for space-separated query
      // e.g., "සීල-සමාධි" matches query "සීල සමාධි"
      if (matchIndex == -1 &&
          words.length >= 2 &&
          (textMatcher.normalized.contains('-') ||
              textMatcher.normalized.contains(','))) {
        final result = _findPhrasePosition(textMatcher.normalized, words);
        matchIndex = result.index;
        matchLength = result.length;
      }
    } else if (words.length >= 2) {
      final result = _findPhrasePosition(textMatcher.normalized, words);
      matchIndex = result.index;
      matchLength = result.length;
    } else {
      matchIndex =
          words.isNotEmpty ? textMatcher.normalized.indexOf(words.first) : -1;
      matchLength = words.isNotEmpty ? words.first.length : 0;
    }

    // Map to original positions and extract snippet
    final range =
        textMatcher.mapToOriginal(matchIndex, matchIndex + matchLength);
    final snippetStart = (range.start - contextBefore).clamp(0, text.length);
    final snippetEnd = (range.end + contextAfter).clamp(0, text.length);

    var snippet = text.substring(snippetStart, snippetEnd);
    if (snippetStart > 0) snippet = '...$snippet';
    if (snippetEnd < text.length) snippet = '$snippet...';

    return snippet;
  }

  /// Finds position where words appear adjacent/close together.
  ({int index, int length}) _findPhrasePosition(
    String normalizedText,
    List<String> words,
  ) {
    if (words.isEmpty) return (index: -1, length: 0);
    if (words.length == 1) {
      final idx = normalizedText.indexOf(words.first);
      return (index: idx, length: idx != -1 ? words.first.length : 0);
    }

    final firstWord = words.first;
    int searchStart = 0;

    while (searchStart < normalizedText.length) {
      final firstWordIndex = normalizedText.indexOf(firstWord, searchStart);
      if (firstWordIndex == -1) break;

      bool allWordsFound = true;
      int currentPos = firstWordIndex + firstWord.length;
      int phraseEndPos = currentPos;

      for (int i = 1; i < words.length; i++) {
        final maxGap = isPhraseSearch ? 20 : 100;
        final searchEnd = (currentPos + maxGap).clamp(0, normalizedText.length);
        final searchWindow = normalizedText.substring(currentPos, searchEnd);
        final nextWordIndex = searchWindow.indexOf(words[i]);

        if (nextWordIndex == -1) {
          allWordsFound = false;
          break;
        }

        currentPos = currentPos + nextWordIndex + words[i].length;
        phraseEndPos = currentPos;
      }

      if (allWordsFound) {
        return (index: firstWordIndex, length: phraseEndPos - firstWordIndex);
      }
      searchStart = firstWordIndex + 1;
    }

    // Fallback: return first word position
    final fallbackIndex = normalizedText.indexOf(firstWord);
    return (
      index: fallbackIndex,
      length: fallbackIndex != -1 ? firstWord.length : 0,
    );
  }

  // ===========================================================================
  // SPAN BUILDERS
  // ===========================================================================

  /// Highlights exact query as single match.
  List<TextSpan> _buildSpansExact(
    String text,
    String query,
    TextStyle highlightStyle,
  ) {
    final textMatcher = _NormalizedTextMatcher(text);
    final ranges = _findExactRanges(textMatcher, query);

    // Fallback: FTS returns hyphenated text for space-separated query
    if (ranges.isEmpty) {
      final words = _splitWords(query);
      if (words.length >= 2 &&
          (textMatcher.normalized.contains('-') ||
              textMatcher.normalized.contains(','))) {
        final phraseRanges = _findPhraseRanges(textMatcher, words);
        return _buildSpansFromRanges(text, phraseRanges, highlightStyle);
      }
    }

    if (ranges.isEmpty) return [TextSpan(text: text)];

    return _buildSpansFromRanges(text, ranges, highlightStyle);
  }

  /// Highlights adjacent phrase occurrences (words must appear together).
  List<TextSpan> _buildSpansPhrase(
    String text,
    List<String> words,
    TextStyle highlightStyle,
  ) {
    if (words.isEmpty) return [TextSpan(text: text)];
    if (words.length == 1) {
      return _buildSpansWords(text, words, highlightStyle);
    }

    final textMatcher = _NormalizedTextMatcher(text);
    final ranges = _findPhraseRanges(textMatcher, words);
    if (ranges.isEmpty) return [TextSpan(text: text)];

    return _buildSpansFromRanges(text, ranges, highlightStyle);
  }

  /// Highlights each word independently.
  List<TextSpan> _buildSpansWords(
    String text,
    List<String> words,
    TextStyle highlightStyle,
  ) {
    if (words.isEmpty) return [TextSpan(text: text)];

    final textMatcher = _NormalizedTextMatcher(text);
    final allRanges = <({int start, int end})>[];

    for (final word in words) {
      allRanges.addAll(_findWordRanges(textMatcher, word));
    }

    if (allRanges.isEmpty) return [TextSpan(text: text)];

    // Sort and merge overlapping ranges
    allRanges.sort((a, b) => a.start.compareTo(b.start));
    final mergedRanges = _mergeRanges(allRanges);

    return _buildSpansFromRanges(text, mergedRanges, highlightStyle);
  }

  // ===========================================================================
  // RANGE FINDERS
  // ===========================================================================

  /// Finds all exact query matches.
  List<({int start, int end})> _findExactRanges(
    _NormalizedTextMatcher matcher,
    String query,
  ) {
    final ranges = <({int start, int end})>[];
    int searchStart = 0;

    while (true) {
      final normIndex = matcher.normalized.indexOf(query, searchStart);
      if (normIndex == -1) break;

      ranges.add(matcher.mapToOriginal(normIndex, normIndex + query.length));
      searchStart = normIndex + query.length;
    }
    return ranges;
  }

  /// Finds all phrase occurrences (words adjacent).
  List<({int start, int end})> _findPhraseRanges(
    _NormalizedTextMatcher matcher,
    List<String> words,
  ) {
    final ranges = <({int start, int end})>[];
    int searchStart = 0;

    while (searchStart < matcher.normalized.length) {
      final firstWordIndex =
          matcher.normalized.indexOf(words.first, searchStart);
      if (firstWordIndex == -1) break;

      bool allWordsFound = true;
      int currentPos = firstWordIndex + words.first.length;
      int phraseEndPos = currentPos;

      for (int i = 1; i < words.length; i++) {
        const maxGap = 20;
        final searchEnd =
            (currentPos + maxGap).clamp(0, matcher.normalized.length);
        final searchWindow =
            matcher.normalized.substring(currentPos, searchEnd);
        final nextWordIndex = searchWindow.indexOf(words[i]);

        if (nextWordIndex == -1) {
          allWordsFound = false;
          break;
        }
        currentPos = currentPos + nextWordIndex + words[i].length;
        phraseEndPos = currentPos;
      }

      if (allWordsFound) {
        ranges.add(matcher.mapToOriginal(firstWordIndex, phraseEndPos));
      }
      searchStart = firstWordIndex + 1;
    }
    return ranges;
  }

  /// Finds all occurrences of a single word.
  List<({int start, int end})> _findWordRanges(
    _NormalizedTextMatcher matcher,
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

  // ===========================================================================
  // UTILITIES
  // ===========================================================================

  /// Builds TextSpans from highlight ranges.
  List<TextSpan> _buildSpansFromRanges(
    String text,
    List<({int start, int end})> ranges,
    TextStyle highlightStyle,
  ) {
    if (ranges.isEmpty) return [TextSpan(text: text)];

    final spans = <TextSpan>[];
    int pos = 0;

    for (final range in ranges) {
      if (range.start > pos) {
        spans.add(TextSpan(text: text.substring(pos, range.start)));
      }
      spans.add(TextSpan(
        text: text.substring(range.start, range.end),
        style: highlightStyle,
      ));
      pos = range.end;
    }

    if (pos < text.length) {
      spans.add(TextSpan(text: text.substring(pos)));
    }
    return spans;
  }

  /// Merges overlapping ranges into non-overlapping ranges.
  List<({int start, int end})> _mergeRanges(
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

  /// Splits query into normalized non-empty words.
  List<String> _splitWords(String query) =>
      normalizeText(query, toLowerCase: true)
          .split(' ')
          .where((w) => w.isNotEmpty)
          .toList();
}

// =============================================================================
// HELPER CLASS
// =============================================================================

/// Caches normalization data for efficient text matching.
class _NormalizedTextMatcher {
  final String original;
  final String normalized;
  final List<int> _positionMap;

  _NormalizedTextMatcher(String text)
      : original = text,
        normalized = normalizeText(text, toLowerCase: true),
        _positionMap = createNormalizedToOriginalPositionMap(text);

  /// Maps normalized [start, end) to original text positions.
  ({int start, int end}) mapToOriginal(int normStart, int normEnd) => (
        start: _positionMap[normStart],
        end: normEnd < _positionMap.length
            ? _positionMap[normEnd]
            : original.length,
      );
}
