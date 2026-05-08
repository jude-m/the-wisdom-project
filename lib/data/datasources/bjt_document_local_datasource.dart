import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import '../../domain/entities/bjt/bjt_document.dart';
import 'bjt_document_datasource.dart';
import 'bjt_document_parser.dart';

class BJTDocumentLocalDataSourceImpl implements BJTDocumentDataSource {
  static const String _textAssetBasePath = 'assets/text';

  // Mirrors DictionaryDataSourceImpl._log. No-op in release builds.
  void _log(String message, {Object? error, StackTrace? stack}) {
    developer.log(message, name: 'BJTDataSource', error: error, stackTrace: stack);
  }

  @override
  Future<BJTDocument> loadDocument(String fileId) async {
    final assetPath = '$_textAssetBasePath/$fileId.json';

    try {
      final jsonString = await rootBundle.loadString(assetPath);
      final Map<String, dynamic> jsonData = json.decode(jsonString);

      return BJTDocumentParser.parseDocument(fileId, jsonData);
    } catch (e, stack) {
      // rethrow preserves the original exception (PlatformException for a
      // missing asset, FormatException for malformed JSON) so the repository
      // can pass it through to the offline/error classifier intact.
      _log('Failed to load BJT document for $fileId', error: e, stack: stack);
      rethrow;
    }
  }
}
