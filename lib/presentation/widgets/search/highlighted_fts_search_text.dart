import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/pali_conjunct_transformer.dart';
import '../../../core/utils/pali_letter_options.dart';
import '../../../core/utils/search_match_finder.dart';
import '../../../core/utils/text_utils.dart';
import '../../providers/fts_highlight_provider.dart';
import '../../providers/pali_letter_options_provider.dart';

/// Displays text with search query matches highlighted.
///
/// Supports three modes:
/// - **Exact phrase**: Entire query as single match
/// - **Phrase with prefix**: Adjacent words with prefix matching
/// - **Separate words**: Each word highlighted independently
class HighlightedFtsSearchText extends ConsumerWidget {
  /// The text content to display and highlight matches within.
  final String matchedText;

  /// What to highlight: the effective query, its search modes and similar
  /// spellings.
  final FtsHighlightState highlight;

  /// Language of the matched text ('pali' or 'sinhala').
  /// When 'pali', conjunct consonant transformation is applied for display.
  final String language;

  /// Maximum display lines. Defaults to 3.
  final int maxLines;

  const HighlightedFtsSearchText({
    super.key,
    required this.matchedText,
    required this.highlight,
    required this.language,
    this.maxLines = 2,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // The Pali-letter switches; only used on the Pali branch. Watching here
    // rebuilds the snippet live when a switch flips.
    final options = ref.watch(paliLetterOptionsProvider);
    return _buildHighlightedText(context, matchedText, theme, options);
  }

  /// Main entry point for building highlighted text.
  Widget _buildHighlightedText(
    BuildContext context,
    String matchedText,
    ThemeData theme,
    PaliLetterOptions options,
  ) {
    final baseStyle = context.typography.resultMatchedText;

    // One finder centres the snippet on the first match and then highlights
    // the matches inside it.
    final finder = highlight.finder;
    final snippet = _createSnippet(text: matchedText, finder: finder);

    final highlightStyle = TextStyle(
      backgroundColor: theme.colorScheme.tertiaryContainer,
      color: theme.colorScheme.onPrimaryContainer,
    );

    final rawRanges = finder.findMatchRanges(snippet);

    // For Pali text, apply conjunct transformation and remap highlight ranges
    final String displaySnippet;
    final List<({int start, int end})> displayRanges;
    if (language == 'pali') {
      (displaySnippet, displayRanges) =
          applyConjunctsWithRangeMapping(snippet, rawRanges, options);
    } else {
      displaySnippet = snippet;
      displayRanges = rawRanges;
    }

    // Build spans from ranges
    final spans =
        _buildSpansFromRanges(displaySnippet, displayRanges, highlightStyle);

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
    required SearchMatchFinder finder,
    int contextBefore = 50,
    int contextAfter = 100,
  }) {
    // The first match, or the start of the text when none shows.
    final range =
        finder.findMatchRanges(text).firstOrNull ?? (start: 0, end: 0);

    // Snap snippet boundaries to grapheme cluster boundaries so we don't
    // split Sinhala combining characters (virama, vowel signs) and produce
    // garbled text at the "..." edges.
    final rawStart = (range.start - contextBefore).clamp(0, text.length);
    final rawEnd = (range.end + contextAfter).clamp(0, text.length);
    final snippetStart = snapToGraphemeBoundary(text, rawStart);
    final snippetEnd = snapToGraphemeBoundary(text, rawEnd, forward: true);

    var snippet = text.substring(snippetStart, snippetEnd);
    if (snippetStart > 0) snippet = '...$snippet';
    if (snippetEnd < text.length) snippet = '$snippet...';

    return snippet;
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
