import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';

import '../logging/logger.dart';

/// Returns liveness + deploy metadata at GET /healthz.
///
/// Used by the deploy pipeline: after rsync + server restart, the Mac-side
/// script polls /healthz until the reported `sha` matches the committed one,
/// confirming the new build is live.
///
/// Response shape:
///   {
///     "ok": true,
///     "sha": "abc1234",           // from DEPLOY.json, null if not present
///     "builtAt": "2026-04-23T...", // ISO-8601 UTC, from DEPLOY.json
///     "startedAt": "2026-04-23T..." // when this server process started
///   }
class HealthHandler {
  final ServerLogger _logger;
  final String _assetsPath;
  final DateTime _startedAt;

  HealthHandler(this._logger, this._assetsPath)
      : _startedAt = DateTime.now().toUtc();

  /// DEPLOY.json sits at the deploy root — one level above assets/.
  String get _deployJsonPath => p.join(p.dirname(_assetsPath), 'DEPLOY.json');

  Future<Response> handle(Request request) async {
    String? sha;
    String? builtAt;

    final file = File(_deployJsonPath);
    if (file.existsSync()) {
      try {
        final parsed = json.decode(file.readAsStringSync()) as Map<String, dynamic>;
        sha = parsed['sha'] as String?;
        builtAt = parsed['builtAt'] as String?;
      } catch (e, st) {
        _logger.error('Failed to parse DEPLOY.json at $_deployJsonPath', e, st);
      }
    }

    return Response.ok(
      json.encode({
        'ok': true,
        'sha': sha,
        'builtAt': builtAt,
        'startedAt': _startedAt.toIso8601String(),
      }),
      headers: const {
        'Content-Type': 'application/json; charset=utf-8',
        'Cache-Control': 'no-store',
      },
    );
  }
}
