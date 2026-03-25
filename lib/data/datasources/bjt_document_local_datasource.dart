import 'dart:convert';
import 'package:flutter/services.dart';
import '../../domain/entities/bjt/bjt_document.dart';
import 'bjt_document_datasource.dart';
import 'bjt_document_parser.dart';

class BJTDocumentLocalDataSourceImpl implements BJTDocumentDataSource {
  static const String _textAssetBasePath = 'assets/text';

  @override
  Future<BJTDocument> loadDocument(String fileId) async {
    final assetPath = '$_textAssetBasePath/$fileId.json';

    try {
      final jsonString = await rootBundle.loadString(assetPath);
      final Map<String, dynamic> jsonData = json.decode(jsonString);

      return BJTDocumentParser.parseDocument(fileId, jsonData);
    } catch (e) {
      throw Exception('Failed to load BJT document for $fileId: $e');
    }
  }
}
