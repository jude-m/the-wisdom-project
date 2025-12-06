import 'package:dartz/dartz.dart';
import '../entities/failure.dart';
import '../entities/bjt/bjt_document.dart';

/// Repository interface for managing BJT documents
///
/// This interface defines the contract for loading and accessing
/// BJT (Buddha Jayanti Tripitaka) documents.
abstract class BJTDocumentRepository {
  /// Loads BJT document by its file identifier
  ///
  /// [fileId] The unique identifier of the document file (filename without extension)
  ///
  /// Returns Either:
  /// - Left(Failure): If loading or parsing fails
  /// - Right(BJTDocument): The loaded BJT document on success
  Future<Either<Failure, BJTDocument>> loadDocument(String fileId);

  /// Checks if BJT document exists for the given file identifier
  ///
  /// [fileId] The unique identifier to check
  ///
  /// Returns Either:
  /// - Left(Failure): If check fails
  /// - Right(bool): true if document exists, false otherwise
  Future<Either<Failure, bool>> hasDocument(String fileId);

  /// Preloads multiple BJT documents for better performance
  ///
  /// [fileIds] List of file identifiers to preload
  ///
  /// Returns Either:
  /// - Left(Failure): If preloading fails
  /// - Right(int): Number of files successfully preloaded
  Future<Either<Failure, int>> preloadDocuments(List<String> fileIds);
}
