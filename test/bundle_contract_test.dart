import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the one bundle rule nothing else can see. The app reads its text from
/// the `bjt_content` table in `assets/databases/bjt.db`; re-declaring the JSON
/// puts ~340 MiB back into the installed app while every other test stays green.
void main() {
  test('pubspec does not bundle assets/text', () {
    final declared = _declaredAssets(File('pubspec.yaml').readAsLinesSync());

    // Without this, a pubspec the parser cannot read would pass by finding
    // nothing at all.
    expect(
      declared,
      isNotEmpty,
      reason: 'Found no assets under flutter: -> assets:. The pubspec layout '
          'changed and this guard can no longer see what ships.',
    );

    expect(
      declared.where((asset) => asset.startsWith('assets/text')),
      isEmpty,
      reason: 'assets/text is declared in pubspec.yaml again. The Tipitaka '
          'JSON must not ship: the app reads its text from the bjt_content '
          'table in assets/databases/bjt.db, so bundling the JSON as well adds '
          '~340 MiB to the installed app and buys nothing. The files stay in '
          'the repo on purpose — tools/bjt-populate.js, the static site '
          'generator and server/ read them from disk, not from the bundle.',
    );
  });
}

/// Asset paths declared under `flutter:` -> `assets:`, with surrounding quotes
/// and trailing comments stripped. Other keys under `flutter:` (`fonts:`, and
/// its own nested lists) end the list and are ignored.
List<String> _declaredAssets(List<String> lines) {
  final assets = <String>[];
  var inFlutter = false;
  var inAssets = false;

  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

    final isTopLevel = line.trimLeft().length == line.length;
    if (isTopLevel) {
      inFlutter = trimmed == 'flutter:';
      inAssets = false;
      continue;
    }

    if (!inFlutter) continue;

    if (trimmed.startsWith('-')) {
      if (inAssets) assets.add(_scalar(trimmed.substring(1)));
      continue;
    }

    inAssets = trimmed == 'assets:';
  }

  return assets;
}

String _scalar(String raw) {
  var value = raw.trim();

  final comment = value.indexOf('#');
  if (comment >= 0) value = value.substring(0, comment).trim();

  const quotes = ['"', "'"];
  for (final quote in quotes) {
    if (value.length >= 2 && value.startsWith(quote) && value.endsWith(quote)) {
      return value.substring(1, value.length - 1);
    }
  }

  return value;
}
