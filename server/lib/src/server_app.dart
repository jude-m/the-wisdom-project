import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';

import 'database/database_manager.dart';
import 'handlers/dictionary_handler.dart';
import 'handlers/fts_handler.dart';
import 'handlers/health_handler.dart';
import 'handlers/text_handler.dart';
import 'logging/logger.dart';

/// Assembles the shelf pipeline with all middleware and routes.
class ServerApp {
  final DatabaseManager db;
  final ServerLogger logger;
  final String assetsPath;
  final String? webRoot;

  ServerApp({
    required this.db,
    required this.logger,
    required this.assetsPath,
    this.webRoot,
  });

  Handler get handler {
    // Build API router
    final apiRouter = Router();
    apiRouter.mount('/fts/', FtsHandler(db, logger, assetsPath).router.call);
    apiRouter.mount('/dict/', DictionaryHandler(db, logger).router.call);
    apiRouter.mount('/text/', TextHandler(logger, assetsPath).router.call);

    // Build the top-level router
    final topRouter = Router();
    topRouter.mount('/api/', apiRouter.call);

    // /healthz is a top-level, top-priority endpoint for the deploy pipeline.
    // Constructed once so startedAt reflects process start, not request time.
    final healthHandler = HealthHandler(logger, assetsPath);

    // Build the pipeline
    final pipeline = const Pipeline()
        .addMiddleware(_gzipMiddleware())
        .addMiddleware(_corsMiddleware())
        .addMiddleware(_requestLogger());

    if (webRoot != null && Directory(webRoot!).existsSync()) {
      // Serve both API and static web files
      final staticHandler = createStaticHandler(
        webRoot!,
        defaultDocument: 'index.html',
      );

      // /healthz > API > static files
      return pipeline.addHandler(
        (Request request) async {
          if (request.url.path == 'healthz') {
            return healthHandler.handle(request);
          }
          // Try API first
          if (request.url.path.startsWith('api/')) {
            return topRouter.call(request);
          }
          // Fall back to static files
          final response = await staticHandler(request);
          // If static file not found, serve index.html for SPA routing
          if (response.statusCode == 404) {
            final indexFile = File('$webRoot/index.html');
            if (indexFile.existsSync()) {
              return Response.ok(
                indexFile.readAsStringSync(),
                headers: {'Content-Type': 'text/html; charset=utf-8'},
              );
            }
          }
          return response;
        },
      );
    } else {
      // API-only mode — still expose /healthz for the deploy pipeline.
      return pipeline.addHandler(
        (Request request) async {
          if (request.url.path == 'healthz') {
            return healthHandler.handle(request);
          }
          return topRouter.call(request);
        },
      );
    }
  }

  /// Gzip compression middleware
  Middleware _gzipMiddleware() {
    return (Handler innerHandler) {
      return (Request request) async {
        final response = await innerHandler(request);

        // Only compress JSON and HTML responses
        final contentType = response.headers['Content-Type'] ?? '';
        if (!contentType.contains('json') && !contentType.contains('html')) {
          return response;
        }

        // Check if client accepts gzip
        final acceptEncoding = request.headers['Accept-Encoding'] ?? '';
        if (!acceptEncoding.contains('gzip')) {
          return response;
        }

        final body = await response.readAsString();
        final compressed = gzip.encode(utf8.encode(body));

        return response.change(
          body: compressed,
          headers: {
            ...response.headers,
            'Content-Encoding': 'gzip',
            'Content-Length': compressed.length.toString(),
          },
        );
      };
    };
  }

  /// CORS middleware (permissive for local development)
  Middleware _corsMiddleware() {
    return (Handler innerHandler) {
      return (Request request) async {
        // Handle preflight OPTIONS requests
        if (request.method == 'OPTIONS') {
          return Response.ok('', headers: _corsHeaders);
        }

        final response = await innerHandler(request);
        return response.change(headers: {...response.headers, ..._corsHeaders});
      };
    };
  }

  static const _corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  };

  /// Request logging middleware
  Middleware _requestLogger() {
    return (Handler innerHandler) {
      return (Request request) async {
        final stopwatch = Stopwatch()..start();
        try {
          final response = await innerHandler(request);
          stopwatch.stop();
          logger.request(
            request.method,
            '/${request.url.path}${request.url.query.isNotEmpty ? '?${request.url.query}' : ''}',
            response.statusCode,
            stopwatch.elapsed,
          );
          return response;
        } catch (e, stackTrace) {
          stopwatch.stop();
          logger.error(
            '${request.method} /${request.url.path} failed',
            e,
            stackTrace,
          );
          return Response.internalServerError(
            body: json.encode({'error': 'Internal server error'}),
            headers: {'Content-Type': 'application/json; charset=utf-8'},
          );
        }
      };
    };
  }
}
