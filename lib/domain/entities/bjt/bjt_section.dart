import 'package:freezed_annotation/freezed_annotation.dart';
import '../entry.dart';

part 'bjt_section.freezed.dart';

/// Represents a section of BJT text in a specific language (Pali or Sinhala)
///
/// Each BJT page has two sections - one for Pali and one for Sinhala.
/// Uses ISO 639-1 language codes: 'pi' for Pali, 'si' for Sinhala.
@freezed
class BJTSection with _$BJTSection {
  const BJTSection._();

  const factory BJTSection({
    /// ISO 639-1 language code ('pi' for Pali, 'si' for Sinhala)
    required String languageCode,

    /// List of entries in this section
    @Default([]) List<Entry> entries,

    /// List of footnotes for this section
    @Default([]) List<String> footnotes,
  }) = _BJTSection;

  /// Returns the total number of entries in this section
  int get entryCount => entries.length;

  /// Returns the total number of footnotes in this section
  int get footnoteCount => footnotes.length;

  /// Checks if this section has any entries
  bool get hasEntries => entries.isNotEmpty;

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
