import 'dart:convert';
import 'package:flutter/services.dart';
import '../../domain/entities/text_content.dart';
import '../../domain/entities/content_page.dart';
import '../../domain/entities/content_section.dart';
import '../../domain/entities/content_entry.dart';
import '../../domain/entities/content_language.dart';
import '../../domain/entities/entry_type.dart';

/// Local data source for loading text content from assets
abstract class TextContentLocalDataSource {
  /// Load text content by file ID
  Future<TextContent> loadTextContent(String contentFileId);
}

class TextContentLocalDataSourceImpl implements TextContentLocalDataSource {
  static const String _textAssetBasePath = 'assets/text';

  @override
  Future<TextContent> loadTextContent(String contentFileId) async {
    final assetPath = '$_textAssetBasePath/$contentFileId.json';

    try {
      final jsonString = await rootBundle.loadString(assetPath);
      final Map<String, dynamic> jsonData = json.decode(jsonString);

      return _parseTextContent(contentFileId, jsonData);
    } catch (e) {
      throw Exception('Failed to load text content for $contentFileId: $e');
    }
  }

  /// Parse JSON into TextContent entity
  TextContent _parseTextContent(String fileId, Map<String, dynamic> json) {
    final List<dynamic> pagesJson = json['pages'] as List<dynamic>;

    final pages = pagesJson.map((pageJson) {
      return _parseContentPage(pageJson as Map<String, dynamic>);
    }).toList();

    return TextContent(
      contentFileId: fileId,
      contentPages: pages,
    );
  }

  /// Parse a single page
  ContentPage _parseContentPage(Map<String, dynamic> pageJson) {
    final int pageNumber = pageJson['pageNum'] as int;
    final Map<String, dynamic> paliJson = pageJson['pali'] as Map<String, dynamic>;
    final Map<String, dynamic> sinhJson = pageJson['sinh'] as Map<String, dynamic>;

    return ContentPage(
      pageNumber: pageNumber,
      paliContentSection: _parseContentSection(paliJson, ContentLanguage.pali),
      sinhalaContentSection: _parseContentSection(sinhJson, ContentLanguage.sinhala),
    );
  }

  /// Parse a content section (pali or sinhala)
  ContentSection _parseContentSection(
    Map<String, dynamic> sectionJson,
    ContentLanguage language,
  ) {
    final List<dynamic> entriesJson = sectionJson['entries'] as List<dynamic>;
    final List<dynamic>? footnotesJson = sectionJson['footnotes'] as List<dynamic>?;

    final entries = entriesJson.map((entryJson) {
      return _parseContentEntry(entryJson as Map<String, dynamic>, language);
    }).toList();

    final footnotes = footnotesJson?.map((footnoteJson) {
      final Map<String, dynamic> footnote = footnoteJson as Map<String, dynamic>;
      return footnote['text'] as String;
    }).toList() ?? [];

    return ContentSection(
      contentLanguage: language,
      contentEntries: entries,
      footnotes: footnotes,
    );
  }

  /// Parse a single content entry
  ContentEntry _parseContentEntry(
    Map<String, dynamic> entryJson,
    ContentLanguage language,
  ) {
    final String typeString = entryJson['type'] as String;
    final String text = entryJson['text'] as String;

    // Parse entry type
    final EntryType entryType = _parseEntryType(typeString);

    return ContentEntry(
      entryType: entryType,
      rawTextContent: text,
    );
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
