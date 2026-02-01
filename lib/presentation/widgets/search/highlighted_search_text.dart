import 'package:flutter/material.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/search_match_finder.dart';
import '../../../core/utils/text_utils.dart';

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
    this.maxLines = 2,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _buildHighlightedText(context, matchedText, theme);
  }

  /// Main entry point for building highlighted text.
  Widget _buildHighlightedText(
    BuildContext context,
    String matchedText,
    ThemeData theme,
  ) {
    final baseStyle = context.typography.resultMatchedText;

    // Create snippet centered around match
    final snippet = _createSnippet(text: matchedText, query: effectiveQuery);

    final highlightStyle = TextStyle(
      backgroundColor: theme.colorScheme.tertiaryContainer,
      color: theme.colorScheme.onPrimaryContainer,
    );

    // Use shared SearchMatchFinder to find highlight ranges
    final finder = SearchMatchFinder(
      queryText: effectiveQuery,
      isPhraseSearch: isPhraseSearch,
      isExactMatch: isExactMatch,
    );
    final ranges = finder.findMatchRanges(snippet);

    // Build spans from ranges
    final spans = _buildSpansFromRanges(snippet, ranges, highlightStyle);

    return RichText(
      text: TextSpan(style: baseStyle, children: spans),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
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
    final textMatcher = NormalizedTextMatcher(text);
    final normalizedQuery = normalizeText(query, toLowerCase: true);
    final words = splitQueryWords(query);

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
}
