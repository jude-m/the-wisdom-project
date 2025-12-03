import 'package:freezed_annotation/freezed_annotation.dart';
import 'entry_type.dart';

part 'content_entry.freezed.dart';

/// Represents a single content entry (paragraph, heading, etc.) in a text section
@freezed
class ContentEntry with _$ContentEntry {
  const ContentEntry._();

  const factory ContentEntry({
    /// The type of this content entry (paragraph, heading, centered, etc.)
    required EntryType entryType,

    /// The raw text content with formatting markers
    /// Examples of markers: **bold**, __underline__, {footnote}
    required String rawTextContent,

    /// Optional reference to a footnote
    String? footnoteReference,
  }) = _ContentEntry;

  /// Checks if this entry contains formatting markers
  bool get hasFormattingMarkers {
    return rawTextContent.contains('**') ||
        rawTextContent.contains('__') ||
        rawTextContent.contains('{');
  }

  /// Checks if this entry has an associated footnote
  bool get hasFootnote => footnoteReference != null;

  /// Returns plain text with all formatting markers removed
  String get plainText {
    return rawTextContent
        .replaceAll('**', '')
        .replaceAll('__', '')
        .replaceAll(RegExp(r'\{[^}]*\}'), '');
  }
}
