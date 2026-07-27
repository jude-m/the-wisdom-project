/// The entrypoint for the **server** environment (SSR).
library;

import 'package:jaspr/dom.dart';
import 'package:jaspr/server.dart';

import 'app.dart';
// This file is generated automatically by Jaspr, do not remove or edit.
import 'main.server.options.dart';

void main() {
  Jaspr.initializeApp(
    options: defaultServerOptions,
  );

  runApp(Document(
    title: 'The Wisdom Project',
    lang: 'si',
    meta: {'description': 'Tipitaka — Pali and Sinhala parallel reader'},
    head: [
      // All styling lives in a plain CSS file (theme → CSS variables is the
      // long-term plan anyway; no typed-css indirection needed for that).
      link(rel: 'stylesheet', href: 'styles.css'),
    ],
    body: App(),
  ));
}
