import 'dart:developer' as developer;
import '../../domain/entities/bjt/bjt_document.dart';
import 'bjt_content_datasource.dart';
import 'bjt_content_local_datasource.dart';
import 'bjt_document_datasource.dart';
import 'bjt_document_parser.dart';

/// Reads a document's pages out of `bjt_content`, so only the span the reader
/// asked for is fetched and inflated.
class BJTDocumentLocalDataSourceImpl implements BJTDocumentDataSource {
  final BJTContentDataSource _contentDataSource;

  BJTDocumentLocalDataSourceImpl({BJTContentDataSource? contentDataSource})
      : _contentDataSource =
            contentDataSource ?? BJTContentLocalDataSourceImpl();

  // Mirrors DictionaryDataSourceImpl._log. No-op in release builds.
  void _log(String message, {Object? error, StackTrace? stack}) {
    developer.log(message,
        name: 'BJTDataSource', error: error, stackTrace: stack);
  }

  @override
  Future<BJTDocument> loadDocument(
    String fileId, {
    int firstPage = 0,
    int? lastPage,
  }) async {
    try {
      final pages = await _contentDataSource.loadPages(
        fileId,
        firstPage: firstPage,
        lastPage: lastPage,
      );

      // The rows are shaped like the JSON's `pages` list, so the parser reads
      // them unchanged.
      return BJTDocumentParser.parseDocument(
        fileId,
        {'pages': pages},
        firstPageIndex: firstPage,
      );
    } catch (e, stack) {
      // rethrow preserves the original exception (StateError for a missing
      // row, FormatException for a corrupt one) so the repository can pass it
      // through to the offline/error classifier intact.
      _log('Failed to load BJT document for $fileId', error: e, stack: stack);
      rethrow;
    }
  }
}
