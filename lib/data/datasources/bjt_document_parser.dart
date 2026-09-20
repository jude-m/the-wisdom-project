import '../../domain/entities/bjt/bjt_document.dart';
import '../../domain/entities/bjt/bjt_page.dart';
import '../../domain/entities/bjt/bjt_section.dart';
import '../../domain/entities/content/entry.dart';
import '../../domain/entities/content/entry_type.dart';

/// Shared JSON-to-entity parsing for BJT documents.
///
/// The page JSON in `bjt_content` is the same shape the source files had, so
/// this stayed a separate class when the loader moved onto the database.
class BJTDocumentParser {
  const BJTDocumentParser._();

  /// Parse a document's `pages` JSON into a [BJTDocument] entity.
  ///
  /// [firstPageIndex] is where `json['pages']` starts in the file — 0 for a
  /// whole file, the span's first page when only part of one was loaded.
  static BJTDocument parseDocument(
    String fileId,
    Map<String, dynamic> json, {
    int firstPageIndex = 0,
  }) {
    final List<dynamic> pagesJson = json['pages'] as List<dynamic>;

    // Shared counter for generating sequential segment IDs across all entries.
    // Increments across BOTH Pali and Sinhala entries for unique IDs
    // useful in future cross-edition alignment (BJT <-> SuttaCentral <-> PTS).
    //
    // It counts from 0 per parse, so these are unique within a document, not
    // within a file: the reader parses one span at a time. Nothing reads them
    // yet; cross-edition alignment will need them derived from the absolute
    // page and entry instead.
    int segmentIndex = 0;

    final pages = pagesJson.map((pageJson) {
      return _parsePage(
        pageJson as Map<String, dynamic>,
        fileId,
        (_) => segmentIndex++,
      );
    }).toList();

    return BJTDocument(
      fileId: fileId,
      pages: pages,
      editionId: 'bjt',
      firstPageIndex: firstPageIndex,
    );
  }

  static BJTPage _parsePage(
    Map<String, dynamic> pageJson,
    String fileId,
    int Function(String) generateSegmentIndex,
  ) {
    final int pageNumber = pageJson['pageNum'] as int;
    final Map<String, dynamic> paliJson =
        pageJson['pali'] as Map<String, dynamic>;
    final Map<String, dynamic> sinhJson =
        pageJson['sinh'] as Map<String, dynamic>;

    return BJTPage(
      pageNumber: pageNumber,
      paliSection: _parseSection(paliJson, 'pi', fileId, generateSegmentIndex),
      sinhalaSection:
          _parseSection(sinhJson, 'si', fileId, generateSegmentIndex),
    );
  }

  static BJTSection _parseSection(
    Map<String, dynamic> sectionJson,
    String languageCode,
    String fileId,
    int Function(String) generateSegmentIndex,
  ) {
    final List<dynamic> entriesJson = sectionJson['entries'] as List<dynamic>;
    final List<dynamic>? footnotesJson =
        sectionJson['footnotes'] as List<dynamic>?;

    final entries = entriesJson.map((entryJson) {
      final segmentId = '$fileId:bjt:${generateSegmentIndex(languageCode)}';
      return _parseEntry(entryJson as Map<String, dynamic>, segmentId);
    }).toList();

    final footnotes = footnotesJson?.map((footnoteJson) {
          final Map<String, dynamic> footnote =
              footnoteJson as Map<String, dynamic>;
          return footnote['text'] as String;
        }).toList() ??
        [];

    return BJTSection(
      languageCode: languageCode,
      entries: entries,
      footnotes: footnotes,
    );
  }

  static Entry _parseEntry(Map<String, dynamic> entryJson, String segmentId) {
    final String typeString = entryJson['type'] as String;
    final String text = entryJson['text'] as String;
    final int? level = entryJson['level'] as int?;

    return Entry(
      entryType: _parseEntryType(typeString),
      rawText: text,
      segmentId: segmentId,
      level: level,
    );
  }

  static EntryType _parseEntryType(String typeString) {
    switch (typeString.toLowerCase()) {
      case 'heading':
        return EntryType.heading;
      case 'centered':
        return EntryType.centered;
      case 'paragraph':
        return EntryType.paragraph;
      case 'gatha':
        return EntryType.gatha;
      case 'unindented':
        return EntryType.unindented;
      default:
        return EntryType.paragraph;
    }
  }
}
