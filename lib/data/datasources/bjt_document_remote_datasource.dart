import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/entities/bjt/bjt_document.dart';
import 'bjt_document_datasource.dart';
import 'bjt_document_parser.dart';

/// Remote implementation of BJTDocumentDataSource that fetches content
/// from the server API. Used on web platform.
class BJTDocumentRemoteDataSourceImpl implements BJTDocumentDataSource {
  final http.Client _client;
  final String _baseUrl;

  BJTDocumentRemoteDataSourceImpl({
    required String baseUrl,
    http.Client? client,
  })  : _baseUrl = baseUrl,
        _client = client ?? http.Client();

  @override
  Future<BJTDocument> loadDocument(String fileId) async {
    final uri = Uri.parse('$_baseUrl/api/text/$fileId');
    final response = await _client.get(uri);

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load document $fileId (${response.statusCode})',
      );
    }

    final Map<String, dynamic> jsonData = json.decode(response.body);
    return BJTDocumentParser.parseDocument(fileId, jsonData);
  }
}
