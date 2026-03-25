import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../logging/logger.dart';

/// Handles text content API endpoint.
/// Serves individual JSON text files on demand.
class TextHandler {
  final ServerLogger _logger;
  final String _assetsPath;

  TextHandler(this._logger, this._assetsPath);

  Router get router {
    final router = Router();
    router.get('/<fileId>', _getText);
    return router;
  }

  /// GET /api/text/<fileId>
  /// Returns the JSON content for a single text file (e.g., dn-1, mn-1)
  Future<Response> _getText(Request request, String fileId) async {
    try {
      // Sanitize fileId to prevent path traversal
      if (fileId.contains('..') || fileId.contains('/') || fileId.contains('\\')) {
        return Response(
          400,
          body: json.encode({'error': 'Invalid file ID'}),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
        );
      }

      final file = File('$_assetsPath/text/$fileId.json');
      if (!file.existsSync()) {
        return Response.notFound(
          json.encode({'error': 'Text file not found: $fileId'}),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
        );
      }

      final content = file.readAsStringSync();
      return Response.ok(
        content,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          // Cache for 1 hour - text content rarely changes
          'Cache-Control': 'public, max-age=3600',
        },
      );
    } catch (e, stackTrace) {
      _logger.error('Failed to serve text file: $fileId', e, stackTrace);
      return Response.internalServerError(
        body: json.encode({'error': 'Failed to load text: $fileId'}),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    }
  }
}
