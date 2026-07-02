import 'package:freezed_annotation/freezed_annotation.dart';

import 'api_error_type.dart';

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

  /// A classified remote-call failure (gold-standard plan §4.7).
  ///
  /// Carries a machine-readable [type] that drives BOTH the user message and the
  /// UI affordance (retry vs rephrase vs none), and returns its [message]
  /// **verbatim** from [userMessage] — no `"Failed to load data: "` prefix,
  /// because these messages are already user-ready. General, not ask-specific.
  const factory Failure.apiFailure({
    required String message,
    required ApiErrorType type,
    Object? error,
  }) = ApiFailure;

  /// Returns a user-friendly error message
  String get userMessage {
    return when(
      dataLoadFailure: (message, _) => 'Failed to load data: $message',
      dataParseFailure: (message, _) => 'Failed to parse data: $message',
      notFoundFailure: (message) => 'Not found: $message',
      invalidOperationFailure: (message) => 'Invalid operation: $message',
      unexpectedFailure: (message, _) => 'Unexpected error: $message',
      apiFailure: (message, _, __) => message, // verbatim — already user-ready
    );
  }

  /// The error type when this is an [ApiFailure], else null. Lets the UI switch
  /// on the failure category (which message + whether to offer Retry).
  ApiErrorType? get apiType => whenOrNull(
        apiFailure: (_, type, __) => type,
      );
}
