import 'package:dartz/dartz.dart';
import '../entities/failure.dart';
import '../entities/bjt/bjt_document.dart';
import '../repositories/bjt_document_repository.dart';

/// Use case for loading BJT document by file ID
class LoadBJTDocumentUseCase {
  final BJTDocumentRepository _repository;

  LoadBJTDocumentUseCase(this._repository);

  /// Execute the use case to load a BJT document — pages [firstPage] to
  /// [lastPage] of the file, or all of it by default.
  Future<Either<Failure, BJTDocument>> execute(
    String fileId, {
    int firstPage = 0,
    int? lastPage,
  }) async {
    return await _repository.loadDocument(
      fileId,
      firstPage: firstPage,
      lastPage: lastPage,
    );
  }
}
