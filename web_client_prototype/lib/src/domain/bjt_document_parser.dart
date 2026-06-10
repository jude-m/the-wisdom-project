/// Ported from lib/data/datasources/bjt_document_parser.dart (imports adapted).
/// Parses the raw BJT JSON served by GET /api/text/`fileId`.
/// Prototype-only duplication — the real build extracts these into a shared package.
library;

import 'bjt_document.dart';
import 'entry.dart';

class BJTDocumentParser {
  const BJTDocumentParser._();

  /// Parse a full document JSON into a [BJTDocument] entity.
  static BJTDocument parseDocument(String fileId, Map<String, dynamic> json) {
    final List<dynamic> pagesJson = json['pages'] as List<dynamic>;

    // Shared counter for generating sequential segment IDs across all entries
    // (increments across BOTH Pali and Sinhala entries, same as the app).
    int segmentIndex = 0;

    final pages = pagesJson.map((pageJson) {
      return _parsePage(
        pageJson as Map<String, dynamic>,
        fileId,
        () => segmentIndex++,
      );
    }).toList();

    return BJTDocument(fileId: fileId, pages: pages);
  }

  static BJTPage _parsePage(
    Map<String, dynamic> pageJson,
    String fileId,
    int Function() nextSegmentIndex,
  ) {
    final int pageNumber = pageJson['pageNum'] as int;
    final Map<String, dynamic> paliJson =
        pageJson['pali'] as Map<String, dynamic>;
    final Map<String, dynamic> sinhJson =
        pageJson['sinh'] as Map<String, dynamic>;

    return BJTPage(
      pageNumber: pageNumber,
      paliSection: _parseSection(paliJson, 'pi', fileId, nextSegmentIndex),
      sinhalaSection: _parseSection(sinhJson, 'si', fileId, nextSegmentIndex),
    );
  }

  static BJTSection _parseSection(
    Map<String, dynamic> sectionJson,
    String languageCode,
    String fileId,
    int Function() nextSegmentIndex,
  ) {
    final List<dynamic> entriesJson = sectionJson['entries'] as List<dynamic>;
    final List<dynamic>? footnotesJson =
        sectionJson['footnotes'] as List<dynamic>?;

    final entries = entriesJson.map((entryJson) {
      final segmentId = '$fileId:bjt:${nextSegmentIndex()}';
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
    return Entry(
      entryType: EntryType.fromString(entryJson['type'] as String),
      rawText: entryJson['text'] as String,
      segmentId: segmentId,
      level: entryJson['level'] as int?,
    );
  }
}
