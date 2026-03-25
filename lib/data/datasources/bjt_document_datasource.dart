import '../../domain/entities/bjt/bjt_document.dart';

/// Abstract data source for loading BJT documents.
/// Specific to Buddha Jayanti Tripitaka edition.
///
/// Implemented by:
/// - [BJTDocumentLocalDataSourceImpl] (native: reads from bundled assets)
/// - [BJTDocumentRemoteDataSourceImpl] (web: fetches from server API)
abstract class BJTDocumentDataSource {
  /// Load BJT document by file ID (e.g. "dn-1", "mn-3")
  Future<BJTDocument> loadDocument(String fileId);
}
