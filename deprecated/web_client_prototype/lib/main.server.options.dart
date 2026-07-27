// dart format off
// ignore_for_file: type=lint

// GENERATED FILE, DO NOT MODIFY
// Generated with jaspr_builder

import 'package:jaspr/server.dart';
import 'package:web_client_prototype/src/components/reader_shell.dart' as _reader_shell;

/// Default [ServerOptions] for use with your Jaspr project.
///
/// Use this to initialize Jaspr **before** calling [runApp].
///
/// Example:
/// ```dart
/// import 'main.server.options.dart';
///
/// void main() {
///   Jaspr.initializeApp(
///     options: defaultServerOptions,
///   );
///
///   runApp(...);
/// }
/// ```
ServerOptions get defaultServerOptions => ServerOptions(
  clientId: 'main.client.dart.js',
  clients: {
    _reader_shell.ReaderShell: ClientTarget<_reader_shell.ReaderShell>(
      'reader_shell',
      params: __reader_shellReaderShell,
    ),
  },
);

Map<String, Object?> __reader_shellReaderShell(_reader_shell.ReaderShell c) => {
  'fileId': c.fileId,
  'suttaName': c.suttaName,
  'initialPageStart': c.initialPageStart,
  'totalPages': c.totalPages,
  'initialWindowJson': c.initialWindowJson,
};
