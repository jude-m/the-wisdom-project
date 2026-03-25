import 'dart:io';

import 'package:args/args.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'package:wisdom_server/src/database/database_manager.dart';
import 'package:wisdom_server/src/logging/logger.dart';
import 'package:wisdom_server/src/server_app.dart';

void main(List<String> arguments) async {
  // Parse command-line arguments
  final parser = ArgParser()
    ..addOption('port', abbr: 'p', defaultsTo: '8080', help: 'Port to listen on')
    ..addOption('assets', abbr: 'a', help: 'Path to assets directory (default: ../assets)')
    ..addOption('web-root', abbr: 'w', help: 'Path to Flutter web build (e.g., ../build/web)')
    ..addOption('log-file', abbr: 'l', defaultsTo: 'server.log', help: 'Log file path')
    ..addFlag('verbose', abbr: 'v', defaultsTo: false, help: 'Verbose logging')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show help');

  final ArgResults args;
  try {
    args = parser.parse(arguments);
  } catch (e) {
    stderr.writeln('Error: $e');
    stderr.writeln(parser.usage);
    exit(1);
  }

  if (args['help'] as bool) {
    stdout.writeln('The Wisdom Project - API Server\n');
    stdout.writeln('Usage: dart run bin/server.dart [options]\n');
    stdout.writeln(parser.usage);
    exit(0);
  }

  final port = int.tryParse(args['port'] as String) ?? 8080;
  final assetsPath = args['assets'] as String? ?? '../assets';
  final webRoot = args['web-root'] as String?;
  final logFile = args['log-file'] as String?;
  final verbose = args['verbose'] as bool;

  // Initialize logger
  final logger = await ServerLogger.create(
    logFilePath: logFile,
    verbose: verbose,
  );

  logger.info('Server starting...');
  logger.info('Assets path: ${Directory(assetsPath).absolute.path}');
  if (webRoot != null) {
    logger.info('Web root: ${Directory(webRoot).absolute.path}');
  }

  // Validate assets directory
  if (!Directory(assetsPath).existsSync()) {
    logger.error('Assets directory not found: $assetsPath');
    logger.error('Run from the server/ directory or specify --assets path');
    exit(1);
  }

  // Check text files
  final textDir = Directory('$assetsPath/text');
  if (textDir.existsSync()) {
    final textFiles = textDir.listSync().where((f) => f.path.endsWith('.json'));
    logger.info('Text: ${textFiles.length} JSON files available');
  } else {
    logger.warn('Text directory not found: $assetsPath/text');
  }

  // Initialize databases
  final db = DatabaseManager(logger);
  try {
    await db.initialize(assetsPath);
  } catch (e) {
    logger.error('Failed to initialize databases: $e');
    exit(1);
  }

  // Build the server app
  final app = ServerApp(
    db: db,
    logger: logger,
    assetsPath: assetsPath,
    webRoot: webRoot,
  );

  // Start the server
  final server = await shelf_io.serve(
    app.handler,
    InternetAddress.anyIPv4,
    port,
  );

  logger.info('Listening on http://localhost:${server.port}');
  if (webRoot != null) {
    logger.info('Open http://localhost:${server.port} in your browser');
  }
  logger.info('Press Ctrl+C to stop\n');

  // Handle graceful shutdown
  ProcessSignal.sigint.watch().listen((_) async {
    logger.info('Shutting down...');
    db.close();
    await logger.close();
    await server.close();
    exit(0);
  });
}
