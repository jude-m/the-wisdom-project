import 'dart:convert';
import 'package:flutter/services.dart';
import '../../domain/entities/bjt/bjt_document.dart';
import '../../domain/entities/bjt/bjt_page.dart';
import '../../domain/entities/bjt/bjt_section.dart';
import '../../domain/entities/entry.dart';
import '../../domain/entities/entry_type.dart';

/// Local data source for loading BJT documents from assets
/// Specific to Buddha Jayanti Tripitaka edition
abstract class BJTDocumentDataSource {
  /// Load BJT document by file ID
  Future<BJTDocument> loadDocument(String fileId);
}

class BJTDocumentLocalDataSourceImpl implements BJTDocumentDataSource {
  static const String _textAssetBasePath = 'assets/text';

  @override
  Future<BJTDocument> loadDocument(String fileId) async {
    final assetPath = '$_textAssetBasePath/$fileId.json';

    try {
      final jsonString = await rootBundle.loadString(assetPath);
      final Map<String, dynamic> jsonData = json.decode(jsonString);

      return _parseDocument(fileId, jsonData);
    } catch (e) {
      throw Exception('Failed to load BJT document for $fileId: $e');
    }
  }

  /// Parse JSON into BJTDocument entity
  BJTDocument _parseDocument(String fileId, Map<String, dynamic> json) {
    final List<dynamic> pagesJson = json['pages'] as List<dynamic>;

    // Shared counter for generating sequential segment IDs across all entries
    // Note: Counter increments across BOTH Pali and Sinhala entries
    // This creates unique IDs for future cross-edition alignment (BJT ↔ SuttaCentral ↔ PTS)
    // Within BJT, Pali/Sinhala entries are already aligned by array index
    int segmentIndex = 0;

    final pages = pagesJson.map((pageJson) {
      return _parsePage(
        pageJson as Map<String, dynamic>,
        fileId,
        (_) =>
            segmentIndex++, // Closure that increments shared counter (param unused)
      );
    }).toList();

    return BJTDocument(
      fileId: fileId,
      pages: pages,
      editionId: 'bjt', // Always BJT for this datasource
    );
  }

  /// Parse a single page
  BJTPage _parsePage(
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
      paliSection: _parseSection(
        paliJson,
        'pi', // ISO 639-1 code for Pali
        fileId,
        generateSegmentIndex,
      ),
      sinhalaSection: _parseSection(
        sinhJson,
        'si', // ISO 639-1 code for Sinhala
        fileId,
        generateSegmentIndex,
      ),
    );
  }

  /// Parse a section (pali or sinhala)
  BJTSection _parseSection(
    Map<String, dynamic> sectionJson,
    String languageCode,
    String fileId,
    int Function(String) generateSegmentIndex,
  ) {
    final List<dynamic> entriesJson = sectionJson['entries'] as List<dynamic>;
    final List<dynamic>? footnotesJson =
        sectionJson['footnotes'] as List<dynamic>?;

    final entries = entriesJson.map((entryJson) {
      // Generate segment ID for this entry
      final segmentId =
          _generateSegmentId(fileId, generateSegmentIndex(languageCode));
      return _parseEntry(
        entryJson as Map<String, dynamic>,
        segmentId,
      );
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

  /// Parse a single entry
  Entry _parseEntry(
    Map<String, dynamic> entryJson,
    String segmentId,
  ) {
    final String typeString = entryJson['type'] as String;
    final String text = entryJson['text'] as String;

    // Parse entry type
    final EntryType entryType = _parseEntryType(typeString);

    return Entry(
      entryType: entryType,
      rawText: text,
      segmentId: segmentId, // Assign generated segment ID
    );
  }

  /// Generate segment ID in format: "dn-1:bjt:0"
  /// This matches the file naming convention (dn-1.json)
  String _generateSegmentId(String fileId, int index) {
    return '$fileId:bjt:$index';
  }

  /// Convert string to EntryType enum
  EntryType _parseEntryType(String typeString) {
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
