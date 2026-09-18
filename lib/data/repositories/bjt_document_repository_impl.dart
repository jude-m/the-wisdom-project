import 'package:dartz/dartz.dart';
import '../../domain/entities/failure.dart';
import '../../domain/entities/bjt/bjt_document.dart';
import '../../domain/repositories/bjt_document_repository.dart';
import '../datasources/bjt_document_datasource.dart';

class BJTDocumentRepositoryImpl implements BJTDocumentRepository {
  final BJTDocumentDataSource _dataSource;

  // Cache recently loaded documents, keyed by the span that was asked for:
  // two units of the same file are different documents now.
  final Map<String, BJTDocument> _cache = {};

  BJTDocumentRepositoryImpl(this._dataSource);

  @override
  Future<Either<Failure, BJTDocument>> loadDocument(
    String fileId, {
    int firstPage = 0,
    int? lastPage,
  }) async {
    final cacheKey = '$fileId:$firstPage:${lastPage ?? 'eof'}';
    try {
      // Return cached document if available
      if (_cache.containsKey(cacheKey)) {
        return Right(_cache[cacheKey]!);
      }

      // Load from data source
      final document = await _dataSource.loadDocument(
        fileId,
        firstPage: firstPage,
        lastPage: lastPage,
      );

      // Cache it
      _cache[cacheKey] = document;

      return Right(document);
    } catch (e) {
      return Left(Failure.dataLoadFailure(
        message: 'Failed to load BJT document for $fileId',
        error: e,
      ));
    }
  }

  @override
  Future<Either<Failure, bool>> hasDocument(String fileId) async {
    try {
      // NOT cheap, and nothing in the app calls it. It reads the whole file —
      // every page, both languages, inflated and parsed — to answer a bool,
      // and caches it under a span key no reader asks for, since units only
      // ever request their own span now. Give it a caller and it should first
      // become the row probe bjt_content_local_datasource.dart already runs
      // inline: SELECT 1 FROM bjt_content WHERE filename = ? LIMIT 1.
      final result = await loadDocument(fileId);
      return Right(result.isRight());
    } catch (e) {
      return const Right(false);
    }
  }

  @override
  Future<Either<Failure, int>> preloadDocuments(List<String> fileIds) async {
    try {
      int successCount = 0;

      for (final fileId in fileIds) {
        final result = await loadDocument(fileId);
        if (result.isRight()) {
          successCount++;
        }
      }

      return Right(successCount);
    } catch (e) {
      return Left(Failure.unexpectedFailure(
        message: 'Failed to preload BJT documents',
        error: e,
      ));
    }
  }
}
