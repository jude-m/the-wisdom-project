import 'package:dartz/dartz.dart';
import '../../domain/entities/failure.dart';
import '../../domain/entities/bjt/bjt_document.dart';
import '../../domain/repositories/bjt_document_repository.dart';
import '../datasources/bjt_document_local_datasource.dart';

class BJTDocumentRepositoryImpl implements BJTDocumentRepository {
  final BJTDocumentDataSource _dataSource;

  // Cache recently loaded documents
  final Map<String, BJTDocument> _cache = {};

  BJTDocumentRepositoryImpl(this._dataSource);

  @override
  Future<Either<Failure, BJTDocument>> loadDocument(String fileId) async {
    try {
      // Return cached document if available
      if (_cache.containsKey(fileId)) {
        return Right(_cache[fileId]!);
      }

      // Load from data source
      final document = await _dataSource.loadDocument(fileId);

      // Cache it
      _cache[fileId] = document;

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
      // Check cache first
      if (_cache.containsKey(fileId)) {
        return const Right(true);
      }

      // Try to load it
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
