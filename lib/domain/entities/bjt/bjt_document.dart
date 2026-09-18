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

    /// Index of `pages.first` in the whole file. Non-zero when only part of the
    /// file was loaded, which is what the reader asks for: everything that
    /// names a position — entry keys, search hits, deep links — is absolute,
    /// so this is what maps those onto [pages].
    @Default(0) int firstPageIndex,
  }) = _BJTDocument;

  /// How many pages this document holds — the loaded span, not the file.
  int get pageCount => pages.length;

  /// Index of the last page this document holds, or one below
  /// [firstPageIndex] when it holds none.
  int get lastPageIndex => firstPageIndex + pages.length - 1;

  /// Checks if this document has any pages
  bool get hasPages => pages.isNotEmpty;

  /// Gets a specific page by its index in the file (0-based, absolute).
  ///
  /// Null when that page sits outside the loaded span.
  BJTPage? getPageByIndex(int index) {
    final local = index - firstPageIndex;
    if (local < 0 || local >= pages.length) {
      return null;
    }
    return pages[local];
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
