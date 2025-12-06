import 'package:dartz/dartz.dart';
import '../entities/failure.dart';
import '../entities/bjt/bjt_document.dart';
import '../repositories/bjt_document_repository.dart';

/// Use case for loading BJT document by file ID
class LoadBJTDocumentUseCase {
  final BJTDocumentRepository _repository;

  LoadBJTDocumentUseCase(this._repository);

  /// Execute the use case to load BJT document
  Future<Either<Failure, BJTDocument>> execute(String fileId) async {
    return await _repository.loadDocument(fileId);
  }
}
