import 'package:dartz/dartz.dart';
import '../entities/failure.dart';
import '../entities/text_content.dart';
import '../repositories/text_content_repository.dart';

/// Use case for loading text content by file ID
class LoadTextContentUseCase {
  final TextContentRepository _repository;

  LoadTextContentUseCase(this._repository);

  /// Execute the use case to load text content
  Future<Either<Failure, TextContent>> execute(String contentFileId) async {
    return await _repository.loadTextContent(contentFileId);
  }
}
