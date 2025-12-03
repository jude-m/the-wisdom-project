import 'package:freezed_annotation/freezed_annotation.dart';

part 'failure.freezed.dart';

/// Represents a failure that can occur in the domain layer
@freezed
class Failure with _$Failure {
  const Failure._();

  /// Failure when loading data from a source
  const factory Failure.dataLoadFailure({
    required String message,
    Object? error,
  }) = DataLoadFailure;

  /// Failure when parsing data
  const factory Failure.dataParseFailure({
    required String message,
    Object? error,
  }) = DataParseFailure;

  /// Failure when requested resource is not found
  const factory Failure.notFoundFailure({
    required String message,
  }) = NotFoundFailure;

  /// Failure when an invalid operation is attempted
  const factory Failure.invalidOperationFailure({
    required String message,
  }) = InvalidOperationFailure;

  /// Generic unexpected failure
  const factory Failure.unexpectedFailure({
    required String message,
    Object? error,
  }) = UnexpectedFailure;

  /// Returns a user-friendly error message
  String get userMessage {
    return when(
      dataLoadFailure: (message, _) => 'Failed to load data: $message',
      dataParseFailure: (message, _) => 'Failed to parse data: $message',
      notFoundFailure: (message) => 'Not found: $message',
      invalidOperationFailure: (message) => 'Invalid operation: $message',
      unexpectedFailure: (message, _) => 'Unexpected error: $message',
    );
  }
}
