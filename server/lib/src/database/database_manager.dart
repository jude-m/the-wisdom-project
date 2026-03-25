import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import '../logging/logger.dart';

/// Manages SQLite database connections for the server.
/// Opens databases on startup and keeps connections alive.
class DatabaseManager {
  final ServerLogger _logger;
  Database? _ftsDb;
  Database? _dictDb;

  DatabaseManager(this._logger);

  Database get ftsDb {
    if (_ftsDb == null) throw StateError('FTS database not initialized');
    return _ftsDb!;
  }

  Database get dictDb {
    if (_dictDb == null) throw StateError('Dictionary database not initialized');
    return _dictDb!;
  }

  /// Open both databases and log diagnostics.
  /// [assetsPath] is the path to the directory containing the database files
  /// and other assets (data/, text/).
  Future<void> initialize(String assetsPath) async {
    final ftsPath = '$assetsPath/databases/bjt-fts.db';
    final dictPath = '$assetsPath/databases/dict.db';

    // Validate files exist
    if (!File(ftsPath).existsSync()) {
      throw FileSystemException('FTS database not found', ftsPath);
    }
    if (!File(dictPath).existsSync()) {
      throw FileSystemException('Dictionary database not found', dictPath);
    }

    // Open databases in read-write mode to support WAL journal access.
    // The server only reads but WAL mode requires write access to the SHM file.
    _ftsDb = sqlite3.open(ftsPath);
    _dictDb = sqlite3.open(dictPath);

    // Log startup diagnostics
    _logDiagnostics(ftsPath, dictPath);
  }

  void _logDiagnostics(String ftsPath, String dictPath) {
    // File sizes
    final ftsSize = File(ftsPath).lengthSync();
    final dictSize = File(dictPath).lengthSync();
    _logger.info(
        'Database: bjt-fts.db (${_formatBytes(ftsSize)})');
    _logger.info(
        'Database: dict.db (${_formatBytes(dictSize)})');

    // Row counts
    try {
      final metaCount =
          _ftsDb!.select('SELECT COUNT(*) as c FROM bjt_meta').first['c'];
      _logger.info('  bjt_meta: $metaCount rows');
    } catch (e) {
      _logger.warn('  Could not count bjt_meta rows: $e');
    }

    try {
      final dictCount =
          _dictDb!.select('SELECT COUNT(*) as c FROM dictionary').first['c'];
      _logger.info('  dictionary: $dictCount rows');
    } catch (e) {
      _logger.warn('  Could not count dictionary rows: $e');
    }

    // Check if suggestions table exists (optional feature)
    try {
      final tables = _ftsDb!.select(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='bjt_suggestions'");
      if (tables.isNotEmpty) {
        final sugCount = _ftsDb!
            .select('SELECT COUNT(*) as c FROM bjt_suggestions')
            .first['c'];
        _logger.info('  bjt_suggestions: $sugCount rows');
      } else {
        _logger.info('  bjt_suggestions: not available');
      }
    } catch (e) {
      _logger.warn('  Could not check bjt_suggestions: $e');
    }
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '$bytes B';
  }

  /// Close all database connections
  void close() {
    _ftsDb?.dispose();
    _dictDb?.dispose();
    _ftsDb = null;
    _dictDb = null;
    _logger.info('Database connections closed');
  }
}
