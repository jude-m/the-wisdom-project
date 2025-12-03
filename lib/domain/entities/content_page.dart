import 'package:freezed_annotation/freezed_annotation.dart';
import 'content_section.dart';
import 'content_language.dart';

part 'content_page.freezed.dart';

/// Represents a single page of content with parallel Pali and Sinhala sections
@freezed
class ContentPage with _$ContentPage {
  const ContentPage._();

  const factory ContentPage({
    /// The page number in the original text
    required int pageNumber,

    /// Pali content section for this page
    required ContentSection paliContentSection,

    /// Sinhala content section for this page
    required ContentSection sinhalaContentSection,
  }) = _ContentPage;

  /// Gets the content section for a specific language
  ContentSection getContentSection(ContentLanguage language) {
    switch (language) {
      case ContentLanguage.pali:
        return paliContentSection;
      case ContentLanguage.sinhala:
        return sinhalaContentSection;
    }
  }

  /// Checks if this page has content in both languages
  bool get hasBothLanguages {
    return paliContentSection.hasContent && sinhalaContentSection.hasContent;
  }

  /// Checks if this page has any content at all
  bool get hasAnyContent {
    return paliContentSection.hasContent || sinhalaContentSection.hasContent;
  }

  /// Returns the maximum number of entries between both sections
  /// This is useful for parallel rendering
  int get maxEntryCount {
    return paliContentSection.entryCount > sinhalaContentSection.entryCount
        ? paliContentSection.entryCount
        : sinhalaContentSection.entryCount;
  }
}
