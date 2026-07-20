import 'dart:convert';

import '../../domain/entities/api_error_type.dart';
import '../../domain/entities/failure.dart';
import '../datasources/api_client.dart';

/// Maps a transport [ApiException] (or any unexpected error) from the `/research`
/// call into a domain `Failure.apiFailure` carrying an [ApiErrorType].
///
/// This is the single seam where technical transport facts become a semantic,
/// source-agnostic failure (gold-standard plan §4.3). It prefers the server's
/// structured `error.code` envelope (§3.2) and falls back to the raw HTTP
/// status. Pure and table-testable — the messages here are English fallbacks;
/// the UI re-localises by [ApiErrorType] (see research_error_messages.dart).
Failure mapResearchError(Object e) {
  if (e is ApiTimeoutException) {
    return Failure.apiFailure(
      type: ApiErrorType.timeout,
      message: _fallbackMessage(ApiErrorType.timeout),
      error: e,
    );
  }
  if (e is ApiNetworkException) {
    return Failure.apiFailure(
      type: ApiErrorType.offline,
      message: _fallbackMessage(ApiErrorType.offline),
      error: e,
    );
  }
  if (e is ApiStatusException) {
    final type = _typeFromStatus(e);
    return Failure.apiFailure(
      type: type,
      message: _fallbackMessage(type),
      error: e,
    );
  }
  // ApiDecodeException / fromJson contract mismatch / anything unexpected →
  // retry. (A bad 200 body is a server fault, not user-fixable.)
  return Failure.apiFailure(
    type: ApiErrorType.serverError,
    message: _fallbackMessage(ApiErrorType.serverError),
    error: e,
  );
}

/// The server's `error.code` is the precise signal; the HTTP status is the
/// coarse fallback (used when the body has no envelope — e.g. FastAPI's own
/// Pydantic 422, or a 401/504 from the edge).
ApiErrorType _typeFromStatus(ApiStatusException e) {
  final byCode = switch (_errorCode(e.body)) {
    'rate_limited' => ApiErrorType.rateLimited,
    'service_unavailable' => ApiErrorType.serviceBusy,
    'not_authorised' => ApiErrorType.notAuthorised,
    'cannot_answer' => ApiErrorType.cannotAnswer,
    // `bad_request` is a client-side bug that shouldn't occur (plan §2d/§2e).
    'server_error' || 'bad_request' => ApiErrorType.serverError,
    _ => null,
  };
  if (byCode != null) return byCode;

  // Cloudflare kills a Worker that exceeds its per-request CPU budget and
  // replies 500 with its own HTML error page (code 1102) — never our JSON
  // envelope, so it has to be sniffed from the raw body.
  if (e.statusCode == 500 && _isCpuExceeded(e.body)) {
    return ApiErrorType.resourceLimit;
  }

  // No structured code → key on the bare status.
  return switch (e.statusCode) {
    429 => ApiErrorType.rateLimited,
    503 => ApiErrorType.serviceBusy,
    401 || 403 => ApiErrorType.notAuthorised,
    504 => ApiErrorType.timeout, // gateway timeout
    // 400/422 with no envelope is a client bug; 500/502 are server faults. Both
    // are "retry" from the user's side.
    _ => ApiErrorType.serverError,
  };
}

/// Cloudflare's 1102 page carries the numeric code and/or the phrase
/// "Worker exceeded resource limits"; either is a safe signal, since our own
/// envelope bodies were already consumed by [_errorCode] above.
bool _isCpuExceeded(String body) =>
    body.contains('1102') ||
    body.toLowerCase().contains('exceeded resource limits');

/// Reads `error.code` from the response body, or null if the body isn't our
/// structured envelope (`{"error": {"code": ...}}`).
String? _errorCode(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      final error = decoded['error'];
      if (error is Map<String, dynamic> && error['code'] is String) {
        return error['code'] as String;
      }
    }
  } catch (_) {
    // Non-JSON or unexpected shape → no code.
  }
  return null;
}

/// English fallback copy — matches the 7-variant table in the plan (§2). The
/// dialog shows the ARB-localised version keyed on the same [ApiErrorType].
String _fallbackMessage(ApiErrorType type) => switch (type) {
      ApiErrorType.offline =>
        "Can't reach the answer service. Check your connection and try again.",
      ApiErrorType.timeout =>
        'That took too long — the model may be busy. Please try again.',
      ApiErrorType.rateLimited =>
        "You've reached the question limit for now. Please try again later.",
      ApiErrorType.serviceBusy =>
        'The answer service is busy or starting up. Please try again shortly.',
      ApiErrorType.notAuthorised =>
        "This version of the app can't use the answer service.",
      ApiErrorType.cannotAnswer =>
        "I couldn't answer that. Try rephrasing your question.",
      ApiErrorType.serverError => 'Something went wrong. Please try again.',
      ApiErrorType.resourceLimit =>
        'That answer was too heavy to process. Please try again.',
    };
