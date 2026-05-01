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

  /// Character ranges from `**...**` markers in the source text.
  /// These are in `plainText` coordinate space (before conjunct transformation).
  /// The widget maps them to display coordinates internally.
  final List<({int start, int end})> markedRanges;

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
    this.markedRanges = const [],
    this.inPageSearchQuery,
    this.currentMatchIndexInEntry,
  });

  @override
  ConsumerState<TextEntryWidget> createState() => _TextEntryWidgetState();
}

class _TextEntryWidgetState extends ConsumerState<TextEntryWidget> {
  /// Style applied to text within `**...**` markers.
  /// Change this single value to alter the visual treatment of marked text
  /// (e.g., bold → italic, color change, etc.).
  static const _markedStyle = TextStyle(fontWeight: FontWeight.bold);

  /// Map of word position to gesture recognizer
  /// Using a map allows us to reuse recognizers across rebuilds
  final Map<int, TapGestureRecognizer> _recognizers = {};

  /// Cached word matches for the current text
  List<RegExpMatch> _wordMatches = [];

  /// Cached display text (computed once per text change)
  String? _cachedDisplayText;
  String? _lastText;

  /// Cached marked ranges mapped to display coordinates
  List<({int start, int end})>? _cachedDisplayMarkedRanges;

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
        widget.enableTap ? widget.text.withPaliConjuncts : widget.text;
    // Invalidate marked ranges cache (depends on display text)
    _cachedDisplayMarkedRanges = null;
    return _cachedDisplayText!;
  }

  /// Get marked ranges mapped from plainText coordinates to displayText
  /// coordinates. When conjunct transformation is applied (Pali text), positions
  /// shift due to ZWJ insertion/removal — this getter handles the mapping.
  List<({int start, int end})> get _displayMarkedRanges {
    if (_cachedDisplayMarkedRanges != null) return _cachedDisplayMarkedRanges!;

    if (widget.markedRanges.isEmpty) {
      _cachedDisplayMarkedRanges = const [];
    } else if (widget.enableTap) {
      // Pali text — conjunct transformation may shift positions.
      // Use buildConjunctPositionMap directly with the already-cached
      // _displayText to avoid a redundant applyConjunctConsonants call.
      final posMap = buildConjunctPositionMap(widget.text, _displayText);
      _cachedDisplayMarkedRanges = [
        for (final r in widget.markedRanges)
          (start: posMap[r.start], end: posMap[r.end]),
      ];
    } else {
      // Non-Pali text — no transformation, coordinates unchanged
      _cachedDisplayMarkedRanges = widget.markedRanges;
    }

    return _cachedDisplayMarkedRanges!;
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
    // Note: _cachedDisplayMarkedRanges is invalidated inside _displayText
    // whenever the text changes, which is the only way markedRanges can change.
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
          // Clear search highlight for this tab (user found what they were looking for)
          ref.read(ftsHighlightProvider.notifier).clearForActiveTab();

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

    // Watch per-tab search highlight state for FTS result highlighting
    final searchHighlight = ref.watch(activeFtsHighlightProvider);

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
    // BUT: still use Text.rich if there are search/in-page highlights
    // or marked ranges to display.
    if ((!widget.enableTap || widget.onWordTap == null) &&
        searchRanges.isEmpty &&
        inPageRanges.isEmpty &&
        _displayMarkedRanges.isEmpty) {
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
  /// Supports four types of styling:
  /// - Marked text styling (markedStyle) - text within `**...**` markers
  /// - Dictionary highlight (tertiaryContainer) - single tapped word
  /// - FTS search highlight (tertiaryContainer) - matched search terms from FTS
  /// - In-page search highlight - Sage Green for all matches, Golden Amber for current
  TextSpan _buildTextSpan(
    BuildContext context,
    ({int widgetId, int position})? highlightState,
    List<({int start, int end})> searchRanges,
    List<({int start, int end})> inPageRanges,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final dictHighlightColor = colorScheme.tertiary;
    final searchHighlightColor = colorScheme.tertiaryContainer;
    final inPageMatchColor = colorScheme.tertiaryContainer;
    final inPageCurrentMatchColor = colorScheme.tertiary;
    final myWidgetId = identityHashCode(this);
    final markedRanges = _displayMarkedRanges;

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
    // Track the last word's recognizer for trailing text after the final word.
    TapGestureRecognizer? lastRecognizer;

    for (final match in _wordMatches) {
      final word = match.group(0)!;
      final wordPosition = match.start;
      final wordEnd = match.end;

      // Get the pre-created recognizer for this word
      final recognizer = _recognizers[wordPosition];

      // Add spaces and punctuation between words.
      // Use the next word's recognizer so tapping a gap triggers the
      // upcoming word — feels more natural when reading left-to-right.
      if (match.start > lastEnd) {
        final betweenText = _displayText.substring(lastEnd, match.start);
        final betweenSpans = _buildSpansWithSearchHighlight(
          text: betweenText,
          textStart: lastEnd,
          searchRanges: effectiveSearchRanges,
          searchHighlightColor: effectiveHighlightColor,
          baseStyle: widget.style,
          recognizer: recognizer,
          markedRanges: markedRanges,
          inPageCurrentMatchColor: inPageRanges.isNotEmpty ? inPageCurrentMatchColor : null,
          currentInPageRangeIndex: currentInPageRangeIndex,
          allInPageRanges: inPageRanges.isNotEmpty ? inPageRanges : null,
        );
        spans.addAll(betweenSpans);
      }

      // Dictionary highlight takes priority over search highlight
      final isDictHighlight = highlightState?.widgetId == myWidgetId &&
          highlightState?.position == wordPosition;

      if (isDictHighlight) {
        // Dictionary highlight — also apply marked style if word is marked
        var style = widget.style;
        if (_isInMarkedRange(wordPosition, markedRanges)) {
          style = style?.merge(_markedStyle) ?? _markedStyle;
        }
        spans.add(TextSpan(
          text: word,
          style: style?.copyWith(backgroundColor: dictHighlightColor) ??
              TextStyle(backgroundColor: dictHighlightColor),
          recognizer: recognizer,
        ));
      } else {
        // Check for search highlight and/or marked styling
        final wordSpans = _buildSpansWithSearchHighlight(
          text: word,
          textStart: wordPosition,
          searchRanges: effectiveSearchRanges,
          searchHighlightColor: effectiveHighlightColor,
          baseStyle: widget.style,
          recognizer: recognizer,
          markedRanges: markedRanges,
          inPageCurrentMatchColor: inPageRanges.isNotEmpty ? inPageCurrentMatchColor : null,
          currentInPageRangeIndex: currentInPageRangeIndex,
          allInPageRanges: inPageRanges.isNotEmpty ? inPageRanges : null,
        );
        spans.addAll(wordSpans);
      }

      lastRecognizer = recognizer;
      lastEnd = wordEnd;
    }

    // Add remaining text after the last word — extends last word's hit area
    if (lastEnd < _displayText.length) {
      final remainingText = _displayText.substring(lastEnd);
      final remainingSpans = _buildSpansWithSearchHighlight(
        text: remainingText,
        textStart: lastEnd,
        searchRanges: effectiveSearchRanges,
        searchHighlightColor: effectiveHighlightColor,
        baseStyle: widget.style,
        recognizer: lastRecognizer,
        markedRanges: markedRanges,
        inPageCurrentMatchColor: inPageRanges.isNotEmpty ? inPageCurrentMatchColor : null,
        currentInPageRangeIndex: currentInPageRangeIndex,
        allInPageRanges: inPageRanges.isNotEmpty ? inPageRanges : null,
      );
      spans.addAll(remainingSpans);
    }

    return TextSpan(children: spans);
  }

  /// Checks if a display position falls within any marked range.
  static bool _isInMarkedRange(
    int position,
    List<({int start, int end})> markedRanges,
  ) {
    for (final r in markedRanges) {
      if (position >= r.start && position < r.end) return true;
      // Ranges are sorted — if start is past position, no more can match
      if (r.start > position) break;
    }
    return false;
  }

  /// Builds TextSpans for a text segment, applying search highlight and
  /// marked styling where needed.
  ///
  /// [textStart] is the position of [text] within [_displayText].
  /// [searchRanges] are the global highlight ranges in [_displayText].
  /// [markedRanges] are the display-mapped marked ranges from `**...**` markers.
  /// [inPageCurrentMatchColor] - if set, the range at [currentInPageRangeIndex]
  ///   within [allInPageRanges] gets this color instead of [searchHighlightColor].
  List<InlineSpan> _buildSpansWithSearchHighlight({
    required String text,
    required int textStart,
    required List<({int start, int end})> searchRanges,
    required Color searchHighlightColor,
    required TextStyle? baseStyle,
    required TapGestureRecognizer? recognizer,
    required List<({int start, int end})> markedRanges,
    Color? inPageCurrentMatchColor,
    int? currentInPageRangeIndex,
    List<({int start, int end})>? allInPageRanges,
  }) {
    if (searchRanges.isEmpty || text.isEmpty) {
      // No search highlights — only apply marked styling if needed.
      // Split at marked range boundaries so words in the middle of a
      // large text segment (e.g., non-tap Sinhala path) are styled correctly.
      return _buildSpansWithMarkedStyle(
        text: text,
        textStart: textStart,
        baseStyle: baseStyle,
        recognizer: recognizer,
        markedRanges: markedRanges,
      );
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
      return _buildSpansWithMarkedStyle(
        text: text,
        textStart: textStart,
        baseStyle: baseStyle,
        recognizer: recognizer,
        markedRanges: markedRanges,
      );
    }

    // Build spans with search highlights + marked styling
    final spans = <InlineSpan>[];
    int pos = 0;

    for (final range in overlappingRanges) {
      // Add non-highlighted text before this range
      if (range.start > pos) {
        spans.addAll(_buildSpansWithMarkedStyle(
          text: text.substring(pos, range.start),
          textStart: textStart + pos,
          baseStyle: baseStyle,
          recognizer: recognizer,
          markedRanges: markedRanges,
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

      // Add highlighted text (search highlight composes with marked style)
      final markedBase = _isInMarkedRange(textStart + range.start, markedRanges)
          ? (baseStyle?.merge(_markedStyle) ?? _markedStyle)
          : baseStyle;
      spans.add(TextSpan(
        text: text.substring(range.start, range.end),
        style: markedBase?.copyWith(backgroundColor: highlightColor) ??
            TextStyle(backgroundColor: highlightColor),
        recognizer: recognizer,
      ));

      pos = range.end;
    }

    // Add remaining non-highlighted text
    if (pos < text.length) {
      spans.addAll(_buildSpansWithMarkedStyle(
        text: text.substring(pos),
        textStart: textStart + pos,
        baseStyle: baseStyle,
        recognizer: recognizer,
        markedRanges: markedRanges,
      ));
    }

    return spans;
  }

  /// Splits a text segment at marked range boundaries and applies [_markedStyle]
  /// to the marked portions. Returns a single unstyled span if no marked ranges
  /// overlap this segment.
  List<InlineSpan> _buildSpansWithMarkedStyle({
    required String text,
    required int textStart,
    required TextStyle? baseStyle,
    required TapGestureRecognizer? recognizer,
    required List<({int start, int end})> markedRanges,
  }) {
    if (text.isEmpty || markedRanges.isEmpty) {
      return [TextSpan(text: text, style: baseStyle, recognizer: recognizer)];
    }

    final textEnd = textStart + text.length;
    final spans = <InlineSpan>[];
    int pos = 0;

    for (final r in markedRanges) {
      // Skip ranges that don't overlap this segment
      if (r.end <= textStart || r.start >= textEnd) continue;

      // Clamp to local coordinates
      final localStart = (r.start - textStart).clamp(0, text.length);
      final localEnd = (r.end - textStart).clamp(0, text.length);

      // Add non-marked text before this range
      if (localStart > pos) {
        spans.add(TextSpan(
          text: text.substring(pos, localStart),
          style: baseStyle,
          recognizer: recognizer,
        ));
      }

      // Add marked text
      spans.add(TextSpan(
        text: text.substring(localStart, localEnd),
        style: baseStyle?.merge(_markedStyle) ?? _markedStyle,
        recognizer: recognizer,
      ));
      pos = localEnd;
    }

    // Add remaining non-marked text
    if (pos < text.length) {
      spans.add(TextSpan(
        text: text.substring(pos),
        style: baseStyle,
        recognizer: recognizer,
      ));
    }

    // If no ranges overlapped, return a single plain span
    return spans.isEmpty
        ? [TextSpan(text: text, style: baseStyle, recognizer: recognizer)]
        : spans;
  }
}
