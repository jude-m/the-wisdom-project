import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/bjt_document_remote_datasource.dart';
import '../../data/datasources/dictionary_remote_datasource.dart';
import '../../data/datasources/fts_remote_datasource.dart';
import 'dictionary_provider.dart';
import 'document_provider.dart';
import 'search_provider.dart';

/// Returns Riverpod overrides for web platform.
///
/// On web, all datasources use HTTP to call the server API
/// instead of local SQLite/assets. The base URL is empty string
/// because the server serves both the SPA and API from the same origin.
List<Override> getWebOverrides() {
  // Empty base URL = same origin (relative URLs like /api/fts/search)
  const baseUrl = '';

  return [
    // Override FTS datasource → remote HTTP calls
    ftsDataSourceProvider.overrideWithValue(
      FTSRemoteDataSourceImpl(baseUrl: baseUrl),
    ),
    // Override dictionary datasource → remote HTTP calls
    dictionaryDataSourceProvider.overrideWithValue(
      DictionaryRemoteDataSourceImpl(baseUrl: baseUrl),
    ),
    // Override document datasource → fetch from server
    bjtDocumentDataSourceProvider.overrideWithValue(
      BJTDocumentRemoteDataSourceImpl(baseUrl: baseUrl),
    ),
  ];
}
