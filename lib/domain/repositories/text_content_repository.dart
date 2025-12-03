import 'package:dartz/dartz.dart';
import '../entities/failure.dart';
import '../entities/text_content.dart';

/// Repository interface for managing Tipitaka text content
///
/// This interface defines the contract for loading and accessing
/// the actual text content (suttas, commentaries, etc.)
abstract class TextContentRepository {
  /// Loads text content by its file identifier
  ///
  /// [contentFileId] The unique identifier of the content file (filename without extension)
  ///
  /// Returns Either:
  /// - Left(Failure): If loading or parsing fails
  /// - Right(TextContent): The loaded text content on success
  Future<Either<Failure, TextContent>> loadTextContent(String contentFileId);

  /// Checks if content exists for the given file identifier
  ///
  /// [contentFileId] The unique identifier to check
  ///
  /// Returns Either:
  /// - Left(Failure): If check fails
  /// - Right(bool): true if content exists, false otherwise
  Future<Either<Failure, bool>> hasTextContent(String contentFileId);

  /// Preloads multiple content files for better performance
  ///
  /// [contentFileIds] List of file identifiers to preload
  ///
  /// Returns Either:
  /// - Left(Failure): If preloading fails
  /// - Right(int): Number of files successfully preloaded
  Future<Either<Failure, int>> preloadTextContent(List<String> contentFileIds);
}
