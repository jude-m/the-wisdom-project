import 'package:freezed_annotation/freezed_annotation.dart';
import 'content_entry.dart';
import 'content_language.dart';

part 'content_section.freezed.dart';

/// Represents a section of content in a specific language (Pali or Sinhala)
@freezed
class ContentSection with _$ContentSection {
  const ContentSection._();

  const factory ContentSection({
    /// The language of this content section
    required ContentLanguage contentLanguage,

    /// List of content entries in this section
    @Default([]) List<ContentEntry> contentEntries,

    /// List of footnotes for this section
    @Default([]) List<String> footnotes,
  }) = _ContentSection;

  /// Returns the total number of entries in this section
  int get entryCount => contentEntries.length;

  /// Returns the total number of footnotes in this section
  int get footnoteCount => footnotes.length;

  /// Checks if this section has any content
  bool get hasContent => contentEntries.isNotEmpty;

  /// Checks if this section has any footnotes
  bool get hasFootnotes => footnotes.isNotEmpty;

  /// Gets footnote by index (1-based indexing as shown to users)
  String? getFootnote(int index) {
    if (index < 1 || index > footnotes.length) {
      return null;
    }
    return footnotes[index - 1];
  }
}
