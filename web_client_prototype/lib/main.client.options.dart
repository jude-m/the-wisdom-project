// dart format off
// ignore_for_file: type=lint

// GENERATED FILE, DO NOT MODIFY
// Generated with jaspr_builder

import 'package:jaspr/client.dart';

import 'package:web_client_prototype/src/components/reader_shell.dart'
    deferred as _reader_shell;

/// Default [ClientOptions] for use with your Jaspr project.
///
/// Use this to initialize Jaspr **before** calling [runApp].
///
/// Example:
/// ```dart
/// import 'main.client.options.dart';
///
/// void main() {
///   Jaspr.initializeApp(
///     options: defaultClientOptions,
///   );
///
///   runApp(...);
/// }
/// ```
ClientOptions get defaultClientOptions => ClientOptions(
  clients: {
    'reader_shell': ClientLoader(
      (p) => _reader_shell.ReaderShell(
        fileId: p['fileId'] as String,
        suttaName: p['suttaName'] as String,
        initialPageStart: p['initialPageStart'] as int,
        totalPages: p['totalPages'] as int,
        initialWindowJson: p['initialWindowJson'] as String,
      ),
      loader: _reader_shell.loadLibrary,
    ),
  },
);
