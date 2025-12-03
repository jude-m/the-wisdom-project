import 'package:freezed_annotation/freezed_annotation.dart';
import 'content_page.dart';

part 'text_content.freezed.dart';

/// Represents the complete text content for a Tipitaka node (sutta, chapter, etc.)
@freezed
class TextContent with _$TextContent {
  const TextContent._();

  const factory TextContent({
    /// The unique identifier for this content (filename without extension)
    required String contentFileId,

    /// List of pages containing the actual content
    @Default([]) List<ContentPage> contentPages,
  }) = _TextContent;

  /// Returns the total number of pages in this content
  int get pageCount => contentPages.length;

  /// Checks if this content has any pages
  bool get hasPages => contentPages.isNotEmpty;

  /// Gets a specific page by its index (0-based)
  ContentPage? getPageByIndex(int index) {
    if (index < 0 || index >= contentPages.length) {
      return null;
    }
    return contentPages[index];
  }

  /// Gets a specific page by its page number
  ContentPage? getPageByNumber(int pageNumber) {
    try {
      return contentPages.firstWhere((page) => page.pageNumber == pageNumber);
    } catch (e) {
      return null;
    }
  }

  /// Returns all page numbers in this content
  List<int> get allPageNumbers {
    return contentPages.map((page) => page.pageNumber).toList();
  }
}
