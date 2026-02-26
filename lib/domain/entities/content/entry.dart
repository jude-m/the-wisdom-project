import 'package:freezed_annotation/freezed_annotation.dart';
import 'entry_type.dart';

part 'entry.freezed.dart';

/// Represents a single text entry (paragraph, heading, etc.)
///
/// Used by all editions (BJT, SuttaCentral, PTS, etc.)
@freezed
class Entry with _$Entry {
  const Entry._();

  const factory Entry({
    /// The type of this entry (paragraph, heading, centered, etc.)
    required EntryType entryType,

    /// The raw text with formatting markers
    /// Examples of markers: **bold**, __underline__, {footnote}
    required String rawText,

    /// Unique segment identifier for cross-edition alignment
    /// Generated at runtime for BJT (e.g., "dn-1:bjt:0")
    /// Loaded from JSON for SuttaCentral (e.g., "dn1:1.1")
    String? segmentId,

    /// Optional reference to a footnote
    String? footnoteReference,

    /// Hierarchy level for this entry (1-5 for heading/centered, 1-2 for gatha)
    /// Higher numbers = higher in hierarchy (level 5 = book title, level 1 = sub-section)
    int? level,
  }) = _Entry;

  /// Checks if this entry contains formatting markers
  bool get hasFormattingMarkers {
    return rawText.contains('**') ||
        rawText.contains('__') ||
        rawText.contains('{');
  }

  /// Checks if this entry has an associated footnote
  bool get hasFootnote => footnoteReference != null;

  /// Returns plain text with all formatting markers removed
  String get plainText {
    return rawText
        .replaceAll('**', '')
        .replaceAll('__', '')
        .replaceAll(RegExp(r'\{[^}]*\}'), '');
  }

  /// Cached storage for [markedRanges]. Uses Expando (identity-based) so it
  /// works with Freezed's const constructor without changing the class signature.
  static final Expando<List<({int start, int end})>> _markedRangesCache =
      Expando('markedRanges');

  /// Character ranges in `plainText` coordinate space that correspond
  /// to text wrapped in `**...**` markers in `rawText`.
  ///
  /// Ranges are sorted by start position (left-to-right parse order).
  ///
  /// Computed once per instance and cached.
  List<({int start, int end})> get markedRanges {
    return _markedRangesCache[this] ??= _computeMarkedRanges();
  }

  /// Walks `rawText` tracking the current position in the stripped (plainText)
  /// coordinate system, toggling marked state on/off when `**` is encountered,
  /// and skipping `__` and `{...}` markers (which are also stripped).
  List<({int start, int end})> _computeMarkedRanges() {
    final ranges = <({int start, int end})>[];
    final raw = rawText;
    final len = raw.length;
    int i = 0; // position in rawText
    int plainIndex = 0; // position in plainText
    bool inMarked = false;
    int markedStart = 0;

    while (i < len) {
      // Check for ** marker (bold toggle)
      if (i + 1 < len && raw[i] == '*' && raw[i + 1] == '*') {
        if (!inMarked) {
          // Opening marker — record where this marked section starts
          inMarked = true;
          markedStart = plainIndex;
        } else {
          // Closing marker — emit the range
          inMarked = false;
          if (plainIndex > markedStart) {
            ranges.add((start: markedStart, end: plainIndex));
          }
        }
        i += 2; // skip the two * characters
        continue;
      }

      // Check for __ marker (underline — stripped, not rendered)
      if (i + 1 < len && raw[i] == '_' && raw[i + 1] == '_') {
        i += 2;
        continue;
      }

      // Check for {footnote} marker — skip entire content
      if (raw[i] == '{') {
        final closeBrace = raw.indexOf('}', i);
        if (closeBrace != -1) {
          i = closeBrace + 1;
          continue;
        }
      }

      // Regular character — advances plainIndex
      plainIndex++;
      i++;
    }

    // Close any unclosed marked range (defensive against malformed input)
    if (inMarked && plainIndex > markedStart) {
      ranges.add((start: markedStart, end: plainIndex));
    }

    return ranges;
  }
}
