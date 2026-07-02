import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Thin JSON-over-HTTP transport.
///
/// Centralises the base URL, timeout, the optional app-token header, status-code
/// handling, and JSON decoding so datasources stay tiny and consistent. It
/// throws *typed technical* exceptions ([ApiException]); a repository maps those
/// to the domain `Failure` — status codes never leak above the repository.
///
/// Framework-free so it can later move to `wisdom_shared`. Introduced for the
/// ask feature (the error-handling gold-standard pilot); the other remote
/// datasources adopt it in a follow-up refactor — see
/// `docs/todo/refactor/generic-server-call-and-error-handling-standard.md`.
class ApiClient {
  final http.Client _client;
  final String _baseUrl;
  final String? _appToken;
  final Duration _timeout;

  /// [timeout] defaults to 120s — a generous ceiling for one grounded answer, as
  /// the capable flash models can take ~35–45s (and the backend may try a
  /// fallback rung or two first). Past it we surface an [ApiTimeoutException]
  /// rather than hang.
  ApiClient({
    required String baseUrl,
    String? appToken,
    Duration timeout = const Duration(seconds: 120),
    http.Client? client,
  })  : _baseUrl = baseUrl,
        _appToken = appToken,
        _timeout = timeout,
        _client = client ?? http.Client();

  /// POSTs [body] as JSON to [path]; decodes a JSON object on 200.
  ///
  /// Throws [ApiTimeoutException] past the timeout, [ApiNetworkException] when
  /// the server can't be reached, [ApiStatusException] on any non-200, and
  /// [ApiDecodeException] when a 200 body isn't a decodable JSON object.
  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) =>
      _send(() => _client.post(
            Uri.parse('$_baseUrl$path'),
            headers: _headers,
            body: jsonEncode(body),
          ));

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        // review Finding #2: one home for the X-App-Token gate.
        if (_appToken != null) 'X-App-Token': _appToken,
      };

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() call,
  ) async {
    final http.Response res;
    try {
      res = await call().timeout(_timeout);
    } on TimeoutException {
      throw ApiTimeoutException(_timeout);
    } catch (e) {
      // SocketException, connection refused, DNS failure, web ClientException…
      // We deliberately don't import dart:io so this stays web-safe.
      throw ApiNetworkException(e);
    }
    if (res.statusCode == 200) {
      // Decode inside the guard so a malformed / non-object 200 body surfaces as
      // a typed ApiException (contract above) rather than leaking a raw
      // FormatException / cast error above the repository.
      final Object? decoded;
      try {
        decoded = jsonDecode(res.body);
      } on FormatException catch (e) {
        throw ApiDecodeException(e);
      }
      if (decoded is Map<String, dynamic>) return decoded;
      throw ApiDecodeException(
        'expected a JSON object, got ${decoded.runtimeType}',
      );
    }
    throw ApiStatusException(res.statusCode, res.body);
  }
}

/// Typed transport errors thrown by [ApiClient]. A repository maps these to the
/// domain `Failure` union (never the other way round).
sealed class ApiException implements Exception {}

/// The server could not be reached (offline, refused, DNS, wrong host).
class ApiNetworkException implements ApiException {
  final Object cause;
  ApiNetworkException(this.cause);

  @override
  String toString() => 'ApiNetworkException($cause)';
}

/// The request exceeded the client [limit].
class ApiTimeoutException implements ApiException {
  final Duration limit;
  ApiTimeoutException(this.limit);

  @override
  String toString() => 'ApiTimeoutException(${limit.inSeconds}s)';
}

/// The server replied with a non-200 [statusCode]. [body] is the raw response
/// body — it may carry a structured error envelope the mapper reads.
class ApiStatusException implements ApiException {
  final int statusCode;
  final String body;
  ApiStatusException(this.statusCode, this.body);

  @override
  String toString() => 'ApiStatusException($statusCode)';
}

/// The server replied 200 but the body wasn't a decodable JSON object
/// (invalid JSON, or a JSON array/string/number). [cause] is the underlying
/// [FormatException] or a short description of the mismatch.
class ApiDecodeException implements ApiException {
  final Object cause;
  ApiDecodeException(this.cause);

  @override
  String toString() => 'ApiDecodeException($cause)';
}
