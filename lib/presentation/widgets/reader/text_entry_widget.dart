import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/pali_conjunct_transformer.dart';
import '../../../core/utils/search_match_finder.dart';
import '../../../core/utils/text_utils.dart';
import '../../providers/dictionary_provider.dart' show dictionaryHighlightProvider;
import '../../providers/fts_highlight_provider.dart';

/// Callback type for word tap events
/// [word] - The tapped word
/// [position] - Global position of the tap (useful for positioning popups)
typedef OnWordTap = void Function(String word, Offset position);

/// A widget that makes individual words in text tappable.
///
/// When [enableTap] is true, each word in the text can be tapped to trigger
/// the [onWordTap] callback. This is used for dictionary lookup on Pali text.
///
/// Words are identified using Unicode-aware regex that handles Sinhala script
/// and other Unicode letter/mark characters.
///
/// Implementation: Uses TapGestureRecognizer on TextSpans (standard Flutter pattern)
/// for native gesture handling without manual hit-testing.
class TextEntryWidget extends ConsumerStatefulWidget {
  /// The text to display
  final String text;

  /// Text style for the text
  final TextStyle? style;

  /// Text alignment
  final TextAlign? textAlign;

  /// Callback when a word is tapped
  final OnWordTap? onWordTap;

  /// Whether to enable tap detection on words
  /// Set to false for non-Pali text to improve performance
  final bool enableTap;

  /// Maximum number of lines (null for unlimited)
  final int? maxLines;

  /// How to handle text overflow
  final TextOverflow? overflow;

  /// In-page search query (already sanitized + Singlish converted).
  /// When non-null, highlights all occurrences in this entry.
  /// Suppresses FTS highlighting when active.
  final String? inPageSearchQuery;

  /// Which match in this entry should get the "current match" highlight.
  /// -1 or null means no match in this entry is current.
  final int? currentMatchIndexInEntry;

  const TextEntryWidget({
    super.key,
    required this.text,
    this.style,
    this.textAlign,
    this.onWordTap,
    this.enableTap = true,
    this.maxLines,
    this.overflow,
    this.inPageSearchQuery,
    this.currentMatchIndexInEntry,
  });

  @override
  ConsumerState<TextEntryWidget> createState() => _TextEntryWidgetState();
}

class _TextEntryWidgetState extends ConsumerState<TextEntryWidget> {
  /// Map of word position to gesture recognizer
  /// Using a map allows us to reuse recognizers across rebuilds
  final Map<int, TapGestureRecognizer> _recognizers = {};

  /// Cached word matches for the current text
  List<RegExpMatch> _wordMatches = [];

  /// Cached display text (computed once per text change)
  String? _cachedDisplayText;
  String? _lastText;

  /// Cached in-page search ranges (avoids re-creating SearchMatchFinder on every build)
  List<({int start, int end})>? _cachedInPageRanges;
  String? _lastInPageQuery;
  String? _lastInPageDisplayText;

  /// Get display text with conjunct transformation applied for Pali text.
  /// Uses caching to avoid recomputing on every access.
  String get _displayText {
    // Return cached if text unchanged
    if (_lastText == widget.text && _cachedDisplayText != null) {
      return _cachedDisplayText!;
    }

    // Compute and cache
    _lastText = widget.text;
    _cachedDisplayText =
        widget.enableTap ? applyConjunctConsonants(widget.text) : widget.text;
    return _cachedDisplayText!;
  }

  @override
  void initState() {
    super.initState();
    // Create recognizers on init
    _createRecognizers();
  }

  @override
  void didUpdateWidget(TextEntryWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only recreate recognizers if text or enableTap changed
    if (oldWidget.text != widget.text ||
        oldWidget.enableTap != widget.enableTap) {
      _disposeRecognizers();
      _createRecognizers();
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  /// Disposes all recognizers and clears the map
  void _disposeRecognizers() {
    for (final recognizer in _recognizers.values) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  /// Creates gesture recognizers for all words in the text
  void _createRecognizers() {
    // Skip for non-Pali text (no dictionary lookup needed)
    if (!widget.enableTap || widget.onWordTap == null) {
      _wordMatches = [];
      return;
    }

    // Find all words in the display text (getter handles conjunct transformation)
    _wordMatches = sinhalaWordPattern.allMatches(_displayText).toList();
    final myWidgetId = identityHashCode(this);

    for (final match in _wordMatches) {
      final word = match.group(0)!;
      final wordPosition = match.start;

      final recognizer = TapGestureRecognizer()
        // Use onTap (not onTapDown) to prevent triggering during long-press.
        // onTapDown fires immediately on touch, but onTap only fires after
        // a complete tap gesture (down + up), so long-press for text selection
        // won't accidentally open the dictionary sheet.
        ..onTap = () {
          // Clear search highlight on any tap (user found what they were looking for)
          ref.read(ftsHighlightProvider.notifier).state = null;

          // Update global highlight state with this widget and position
          ref.read(dictionaryHighlightProvider.notifier).state = (
            widgetId: myWidgetId,
            position: wordPosition,
          );

          // Call the word tap callback
          widget.onWordTap?.call(word, Offset.zero);
        };

      _recognizers[wordPosition] = recognizer;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch the global highlight state to rebuild when highlighting changes
    // Store the result to use in _buildTextSpan
    final highlightState = ref.watch(dictionaryHighlightProvider);

    // Watch search highlight state for FTS result highlighting
    final searchHighlight = ref.watch(ftsHighlightProvider);

    // In-page search suppresses FTS highlight to avoid confusing dual highlights
    final hasInPageSearch = widget.inPageSearchQuery != null &&
        widget.inPageSearchQuery!.isNotEmpty;

    // Compute in-page search ranges if active
    final inPageRanges = hasInPageSearch
        ? _computeInPageSearchRanges(widget.inPageSearchQuery!)
        : <({int start, int end})>[];

    // Compute FTS search highlight ranges only if in-page search is not active
    final searchRanges =
        hasInPageSearch ? <({int start, int end})>[] : _computeSearchRanges(searchHighlight);

    // For non-Pali text (e.g., Sinhala translations), render as simple Text
    // to avoid unnecessary gesture recognizer overhead.
    // BUT: still use Text.rich if there are search/in-page highlights to display.
    if ((!widget.enableTap || widget.onWordTap == null) &&
        searchRanges.isEmpty &&
        inPageRanges.isEmpty) {
      return Text(
        widget.text,
        style: widget.style,
        textAlign: widget.textAlign,
        maxLines: widget.maxLines,
        overflow: widget.overflow,
      );
    }

    // Build rich text with tappable word spans
    return Text.rich(
      _buildTextSpan(context, highlightState, searchRanges, inPageRanges),
      textAlign: widget.textAlign,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
  }

  /// Computes in-page search highlight ranges for the current text.
  /// Uses exact phrase matching (same as FTS with isPhraseSearch + isExactMatch).
  /// Results are cached based on (query, displayText) to avoid re-creating
  /// SearchMatchFinder on every rebuild.
  List<({int start, int end})> _computeInPageSearchRanges(String query) {
    if (query == _lastInPageQuery &&
        _displayText == _lastInPageDisplayText &&
        _cachedInPageRanges != null) {
      return _cachedInPageRanges!;
    }
    _lastInPageQuery = query;
    _lastInPageDisplayText = _displayText;
    final finder = SearchMatchFinder(
      queryText: query,
      isPhraseSearch: true,
      isExactMatch: true,
    );
    _cachedInPageRanges = finder.findMatchRanges(_displayText);
    return _cachedInPageRanges!;
  }

  /// Computes search highlight ranges for the current text.
  /// Returns empty list if no search highlight is active.
  List<({int start, int end})> _computeSearchRanges(
    FtsHighlightState? searchHighlight,
  ) {
    if (searchHighlight == null || searchHighlight.queryText.isEmpty) {
      return [];
    }

    final finder = SearchMatchFinder(
      queryText: searchHighlight.queryText,
      isPhraseSearch: searchHighlight.isPhraseSearch,
      isExactMatch: searchHighlight.isExactMatch,
    );

    return finder.findMatchRanges(_displayText);
  }

  /// Builds a TextSpan with tappable words and optional highlighting.
  ///
  /// Supports three types of highlighting:
  /// - Dictionary highlight (primaryContainer) - single tapped word
  /// - FTS search highlight (tertiaryContainer) - matched search terms from FTS
  /// - In-page search highlight - Sage Green for all matches, Golden Amber for current
  TextSpan _buildTextSpan(
    BuildContext context,
    ({int widgetId, int position})? highlightState,
    List<({int start, int end})> searchRanges,
    List<({int start, int end})> inPageRanges,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final dictHighlightColor = colorScheme.tertiaryContainer;
    final searchHighlightColor = colorScheme.tertiaryContainer.withValues(alpha: 0.6);
    // In-page search colors: Sage Green for all matches, Golden Amber for current
    final inPageMatchColor = colorScheme.tertiaryContainer;
    final inPageCurrentMatchColor = colorScheme.tertiary;
    final myWidgetId = identityHashCode(this);

    // Determine which in-page range is the "current" match
    final currentInPageRangeIndex = widget.currentMatchIndexInEntry;

    // Merge both search types into a unified highlight list
    // (in-page ranges take priority when active)
    final effectiveSearchRanges =
        inPageRanges.isNotEmpty ? inPageRanges : searchRanges;
    final effectiveHighlightColor =
        inPageRanges.isNotEmpty ? inPageMatchColor : searchHighlightColor;

    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in _wordMatches) {
      final word = match.group(0)!;
      final wordPosition = match.start;
      final wordEnd = match.end;

      // Add spaces and punctuation between words
      if (match.start > lastEnd) {
        final betweenText = _displayText.substring(lastEnd, match.start);
        // Check if this "between" text contains search matches
        final betweenSpans = _buildSpansWithSearchHighlight(
          text: betweenText,
          textStart: lastEnd,
          searchRanges: effectiveSearchRanges,
          searchHighlightColor: effectiveHighlightColor,
          baseStyle: widget.style,
          recognizer: null,
          inPageCurrentMatchColor: inPageRanges.isNotEmpty ? inPageCurrentMatchColor : null,
          currentInPageRangeIndex: currentInPageRangeIndex,
          allInPageRanges: inPageRanges.isNotEmpty ? inPageRanges : null,
        );
        spans.addAll(betweenSpans);
      }

      // Get the pre-created recognizer for this word
      final recognizer = _recognizers[wordPosition];

      // Dictionary highlight takes priority over search highlight
      final isDictHighlight = highlightState?.widgetId == myWidgetId &&
          highlightState?.position == wordPosition;

      if (isDictHighlight) {
        // Dictionary highlight - single color for entire word
        spans.add(TextSpan(
          text: word,
          style: widget.style?.copyWith(backgroundColor: dictHighlightColor) ??
              TextStyle(backgroundColor: dictHighlightColor),
          recognizer: recognizer,
        ));
      } else {
        // Check for search highlight - may highlight partial word
        final wordSpans = _buildSpansWithSearchHighlight(
          text: word,
          textStart: wordPosition,
          searchRanges: effectiveSearchRanges,
          searchHighlightColor: effectiveHighlightColor,
          baseStyle: widget.style,
          recognizer: recognizer,
          inPageCurrentMatchColor: inPageRanges.isNotEmpty ? inPageCurrentMatchColor : null,
          currentInPageRangeIndex: currentInPageRangeIndex,
          allInPageRanges: inPageRanges.isNotEmpty ? inPageRanges : null,
        );
        spans.addAll(wordSpans);
      }

      lastEnd = wordEnd;
    }

    // Add remaining text after the last word
    if (lastEnd < _displayText.length) {
      final remainingText = _displayText.substring(lastEnd);
      final remainingSpans = _buildSpansWithSearchHighlight(
        text: remainingText,
        textStart: lastEnd,
        searchRanges: effectiveSearchRanges,
        searchHighlightColor: effectiveHighlightColor,
        baseStyle: widget.style,
        recognizer: null,
        inPageCurrentMatchColor: inPageRanges.isNotEmpty ? inPageCurrentMatchColor : null,
        currentInPageRangeIndex: currentInPageRangeIndex,
        allInPageRanges: inPageRanges.isNotEmpty ? inPageRanges : null,
      );
      spans.addAll(remainingSpans);
    }

    return TextSpan(children: spans);
  }

  /// Builds TextSpans for a text segment, applying search highlight where needed.
  ///
  /// [textStart] is the position of [text] within [_displayText].
  /// [searchRanges] are the global highlight ranges in [_displayText].
  /// [inPageCurrentMatchColor] - if set, the range at [currentInPageRangeIndex]
  ///   within [allInPageRanges] gets this color instead of [searchHighlightColor].
  List<InlineSpan> _buildSpansWithSearchHighlight({
    required String text,
    required int textStart,
    required List<({int start, int end})> searchRanges,
    required Color searchHighlightColor,
    required TextStyle? baseStyle,
    required TapGestureRecognizer? recognizer,
    Color? inPageCurrentMatchColor,
    int? currentInPageRangeIndex,
    List<({int start, int end})>? allInPageRanges,
  }) {
    if (searchRanges.isEmpty || text.isEmpty) {
      return [
        TextSpan(text: text, style: baseStyle, recognizer: recognizer),
      ];
    }

    final textEnd = textStart + text.length;

    // Find ranges that overlap with this text segment, tracking their global index
    // for in-page current-match highlighting
    final overlappingRanges = <({int start, int end, int globalIndex})>[];
    for (var i = 0; i < searchRanges.length; i++) {
      final range = searchRanges[i];
      if (range.start < textEnd && range.end > textStart) {
        // Clamp range to this text segment
        overlappingRanges.add((
          start: (range.start - textStart).clamp(0, text.length),
          end: (range.end - textStart).clamp(0, text.length),
          globalIndex: i,
        ));
      }
    }

    if (overlappingRanges.isEmpty) {
      return [
        TextSpan(text: text, style: baseStyle, recognizer: recognizer),
      ];
    }

    // Build spans with highlights
    final spans = <InlineSpan>[];
    int pos = 0;

    for (final range in overlappingRanges) {
      // Add non-highlighted text before this range
      if (range.start > pos) {
        spans.add(TextSpan(
          text: text.substring(pos, range.start),
          style: baseStyle,
          recognizer: recognizer,
        ));
      }

      // Determine highlight color: Golden Amber for current in-page match,
      // default color for all others
      final isCurrentInPageMatch = inPageCurrentMatchColor != null &&
          allInPageRanges != null &&
          currentInPageRangeIndex != null &&
          currentInPageRangeIndex >= 0 &&
          range.globalIndex == currentInPageRangeIndex;

      final highlightColor =
          isCurrentInPageMatch ? inPageCurrentMatchColor : searchHighlightColor;

      // Add highlighted text
      spans.add(TextSpan(
        text: text.substring(range.start, range.end),
        style: baseStyle?.copyWith(backgroundColor: highlightColor) ??
            TextStyle(backgroundColor: highlightColor),
        recognizer: recognizer,
      ));

      pos = range.end;
    }

    // Add remaining non-highlighted text
    if (pos < text.length) {
      spans.add(TextSpan(
        text: text.substring(pos),
        style: baseStyle,
        recognizer: recognizer,
      ));
    }

    return spans;
  }
}
