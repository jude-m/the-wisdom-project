import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/pali_conjunct_transformer.dart';
import '../../../core/utils/text_utils.dart';
import '../../providers/dictionary_provider.dart';

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

  const TextEntryWidget({
    super.key,
    required this.text,
    this.style,
    this.textAlign,
    this.onWordTap,
    this.enableTap = true,
    this.maxLines,
    this.overflow,
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

  /// Get display text with conjunct transformation applied for Pali text.
  /// Uses caching to avoid recomputing on every access.
  String get _displayText {
    // Return cached if text unchanged
    if (_lastText == widget.text && _cachedDisplayText != null) {
      return _cachedDisplayText!;
    }

    // Compute and cache
    _lastText = widget.text;
    _cachedDisplayText = widget.enableTap
        ? applyConjunctConsonants(widget.text)
        : widget.text;
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
    if (oldWidget.text != widget.text || oldWidget.enableTap != widget.enableTap) {
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
        ..onTapDown = (details) {
          // Update global highlight state with this widget and position
          ref.read(highlightStateProvider.notifier).state = (
            widgetId: myWidgetId,
            position: wordPosition,
          );

          // Call the word tap callback
          widget.onWordTap?.call(word, details.globalPosition);
        };

      _recognizers[wordPosition] = recognizer;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch the global highlight state to rebuild when highlighting changes
    // Store the result to use in _buildTextSpan
    final highlightState = ref.watch(highlightStateProvider);

    // For non-Pali text (e.g., Sinhala translations), render as simple Text
    // to avoid unnecessary gesture recognizer overhead
    if (!widget.enableTap || widget.onWordTap == null) {
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
      _buildTextSpan(context, highlightState),
      textAlign: widget.textAlign,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
  }

  /// Builds a TextSpan with tappable words and optional highlighting
  TextSpan _buildTextSpan(
    BuildContext context,
    ({int widgetId, int position})? highlightState,
  ) {
    final highlightColor = Theme.of(context).colorScheme.primaryContainer;
    final myWidgetId = identityHashCode(this);

    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in _wordMatches) {
      final word = match.group(0)!;
      final wordPosition = match.start;

      // Add spaces and punctuation between words
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: _displayText.substring(lastEnd, match.start),
          style: widget.style,
        ));
      }

      // Get the pre-created recognizer for this word
      final recognizer = _recognizers[wordPosition];

      // Highlight this word only if the global state matches this widget and position
      final shouldHighlight = highlightState?.widgetId == myWidgetId &&
          highlightState?.position == wordPosition;

      spans.add(TextSpan(
        text: word,
        style: shouldHighlight
            ? widget.style?.copyWith(backgroundColor: highlightColor) ??
                TextStyle(backgroundColor: highlightColor)
            : widget.style,
        recognizer: recognizer,
      ));

      lastEnd = match.end;
    }

    // Add remaining text after the last word
    if (lastEnd < _displayText.length) {
      spans.add(TextSpan(
        text: _displayText.substring(lastEnd),
        style: widget.style,
      ));
    }

    return TextSpan(children: spans);
  }
}
