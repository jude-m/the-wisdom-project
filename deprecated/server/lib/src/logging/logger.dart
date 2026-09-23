import 'dart:io';

/// Simple file + console logger for the server.
/// Logs requests, errors, and startup diagnostics.
class ServerLogger {
  final IOSink? _fileSink;
  final bool _verbose;

  ServerLogger._({IOSink? fileSink, bool verbose = false})
      : _fileSink = fileSink,
        _verbose = verbose;

  /// Create a logger that writes to both console and a log file.
  /// If [logFilePath] is null, logs to console only.
  static Future<ServerLogger> create({
    String? logFilePath,
    bool verbose = false,
  }) async {
    IOSink? fileSink;
    if (logFilePath != null) {
      final file = File(logFilePath);
      // Append mode so logs persist across restarts
      fileSink = file.openWrite(mode: FileMode.append);
    }
    return ServerLogger._(fileSink: fileSink, verbose: verbose);
  }

  String _timestamp() {
    final now = DateTime.now();
    return '${now.year}-${_pad(now.month)}-${_pad(now.day)} '
        '${_pad(now.hour)}:${_pad(now.minute)}:${_pad(now.second)}';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  void _write(String level, String message) {
    final line = '[${_timestamp()}] [$level] $message';
    stdout.writeln(line);
    _fileSink?.writeln(line);
  }

  void info(String message) => _write('INFO', message);

  void warn(String message) => _write('WARN', message);

  void error(String message, [Object? err, StackTrace? stackTrace]) {
    _write('ERROR', message);
    if (err != null) {
      _write('ERROR', '  Exception: $err');
    }
    if (stackTrace != null && _verbose) {
      _write('ERROR', '  Stack trace:\n$stackTrace');
    }
  }

  /// Log a request with method, path, status code, and duration
  void request(String method, String path, int statusCode, Duration duration) {
    final ms = duration.inMilliseconds;
    _write('INFO', '$method $path -> $statusCode (${ms}ms)');
  }

  /// Log verbose/debug messages (only when verbose mode is on)
  void debug(String message) {
    if (_verbose) {
      _write('DEBUG', message);
    }
  }

  /// Flush and close the file sink
  Future<void> close() async {
    await _fileSink?.flush();
    await _fileSink?.close();
  }
}
