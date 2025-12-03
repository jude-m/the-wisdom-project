import 'package:dartz/dartz.dart';
import '../../domain/entities/failure.dart';
import '../../domain/entities/text_content.dart';
import '../../domain/repositories/text_content_repository.dart';
import '../datasources/text_content_local_datasource.dart';

class TextContentRepositoryImpl implements TextContentRepository {
  final TextContentLocalDataSource _localDataSource;

  // Cache recently loaded content
  final Map<String, TextContent> _contentCache = {};

  TextContentRepositoryImpl(this._localDataSource);

  @override
  Future<Either<Failure, TextContent>> loadTextContent(String contentFileId) async {
    try {
      // Return cached content if available
      if (_contentCache.containsKey(contentFileId)) {
        return Right(_contentCache[contentFileId]!);
      }

      // Load from data source
      final content = await _localDataSource.loadTextContent(contentFileId);

      // Cache it
      _contentCache[contentFileId] = content;

      return Right(content);
    } catch (e) {
      return Left(Failure.dataLoadFailure(
        message: 'Failed to load text content for $contentFileId',
        error: e,
      ));
    }
  }

  @override
  Future<Either<Failure, bool>> hasTextContent(String contentFileId) async {
    try {
      // Check cache first
      if (_contentCache.containsKey(contentFileId)) {
        return const Right(true);
      }

      // Try to load it
      final result = await loadTextContent(contentFileId);
      return Right(result.isRight());
    } catch (e) {
      return const Right(false);
    }
  }

  @override
  Future<Either<Failure, int>> preloadTextContent(List<String> contentFileIds) async {
    try {
      int successCount = 0;

      for (final fileId in contentFileIds) {
        final result = await loadTextContent(fileId);
        if (result.isRight()) {
          successCount++;
        }
      }

      return Right(successCount);
    } catch (e) {
      return Left(Failure.unexpectedFailure(
        message: 'Failed to preload content',
        error: e,
      ));
    }
  }
}
