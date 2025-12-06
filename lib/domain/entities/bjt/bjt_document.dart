import 'package:freezed_annotation/freezed_annotation.dart';
import 'bjt_page.dart';

part 'bjt_document.freezed.dart';

/// Represents a complete BJT document (sutta, chapter, etc.)
///
/// This is specific to the Buddha Jayanti Tripitaka edition which has:
/// - Page-based structure (physical book pages)
/// - Dual-language per page (Pali and Sinhala columns)
@freezed
class BJTDocument with _$BJTDocument {
  const BJTDocument._();

  const factory BJTDocument({
    /// The unique identifier for this document (filename without extension)
    required String fileId,

    /// List of pages containing the text
    @Default([]) List<BJTPage> pages,

    /// Edition identifier - always 'bjt' for this class
    @Default('bjt') String editionId,
  }) = _BJTDocument;

  /// Returns the total number of pages
  int get pageCount => pages.length;

  /// Checks if this document has any pages
  bool get hasPages => pages.isNotEmpty;

  /// Gets a specific page by its index (0-based)
  BJTPage? getPageByIndex(int index) {
    if (index < 0 || index >= pages.length) {
      return null;
    }
    return pages[index];
  }

  /// Gets a specific page by its page number
  BJTPage? getPageByNumber(int pageNumber) {
    try {
      return pages.firstWhere((page) => page.pageNumber == pageNumber);
    } catch (e) {
      return null;
    }
  }

  /// Returns all page numbers
  List<int> get allPageNumbers {
    return pages.map((page) => page.pageNumber).toList();
  }
}
