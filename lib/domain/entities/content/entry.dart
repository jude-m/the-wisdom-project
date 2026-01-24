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
}
