import 'package:freezed_annotation/freezed_annotation.dart';
import 'bjt_section.dart';

part 'bjt_page.freezed.dart';

/// Represents a single page of BJT text with parallel Pali and Sinhala sections
///
/// This is specific to the Buddha Jayanti Tripitaka edition which displays
/// Pali and Sinhala in parallel columns on each physical page.
@freezed
class BJTPage with _$BJTPage {
  const BJTPage._();

  const factory BJTPage({
    /// The page number in the original text
    required int pageNumber,

    /// Pali section for this page
    required BJTSection paliSection,

    /// Sinhala section for this page
    required BJTSection sinhalaSection,
  }) = _BJTPage;

  /// Gets the section for a specific language using ISO 639-1 code
  /// 'pi' = Pali, 'si' = Sinhala
  BJTSection? getSection(String languageCode) {
    switch (languageCode) {
      case 'pi':
        return paliSection;
      case 'si':
        return sinhalaSection;
      default:
        return null;
    }
  }

  /// Checks if this page has text in both languages
  bool get hasBothLanguages {
    return paliSection.hasEntries && sinhalaSection.hasEntries;
  }

  /// Checks if this page has any text at all
  bool get hasAnyContent {
    return paliSection.hasEntries || sinhalaSection.hasEntries;
  }

  /// Returns the maximum number of entries between both sections
  /// This is useful for parallel rendering
  int get maxEntryCount {
    return paliSection.entryCount > sinhalaSection.entryCount
        ? paliSection.entryCount
        : sinhalaSection.entryCount;
  }
}
