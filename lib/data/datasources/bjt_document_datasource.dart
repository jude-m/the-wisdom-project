import '../../domain/entities/bjt/bjt_document.dart';

/// Abstract data source for loading BJT documents.
/// Specific to Buddha Jayanti Tripitaka edition.
///
/// Implemented by [BJTDocumentLocalDataSourceImpl], which reads `bjt_content`
/// out of this device's copy of `bjt.db` on every platform.
abstract class BJTDocumentDataSource {
  /// Load pages [firstPage] to [lastPage] of the file [fileId] (e.g. "dn-1"),
  /// inclusive — to the end of the file when [lastPage] is null.
  ///
  /// A source that can only serve whole files may ignore the span and return
  /// the whole thing. [BJTDocument.firstPageIndex] says which pages came back,
  /// so callers translate positions through it rather than assuming page 0.
  Future<BJTDocument> loadDocument(
    String fileId, {
    int firstPage = 0,
    int? lastPage,
  });
}
