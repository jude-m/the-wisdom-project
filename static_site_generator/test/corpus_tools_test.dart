/// The two whole-corpus tools, run automatically.
///
/// Both already assert and exit non-zero, so each test just runs one and checks
/// the exit code. The point isn't a new check — it's that **nobody has to
/// remember**. Their documented trigger is a re-sync of `assets/` from upstream,
/// and a trigger written in a doc holds until someone re-syncs without reading
/// the doc.
///
/// Still run them by hand when reviewing a change: the printout shows the
/// margins either side of the grouping line, which a pass/fail cannot.
@Tags(['corpus'])
library;

import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('the locked page budget still holds', () {
    // The figures themselves are in `_locked` in the tool, deliberately not
    // repeated here: a copy no assertion reads is a copy that goes quietly
    // wrong on the next legitimate update, which is the exact failure --expect
    // exists to prevent.
    final result = _run('tool/classify_corpus.dart', ['--expect']);
    expect(result.exitCode, 0, reason: _output(result));
  });

  test('the extracted wisdom_shared logic matches the app original', () {
    // Every entry and every parent in the corpus, against the frozen
    // pre-extraction oracles. Counts live in the tool.
    final result = _run('tool/verify_corpus_invariants.dart');
    expect(result.exitCode, 0, reason: _output(result));
  });
}

/// Runs one of `tool/`'s scripts and returns its result.
ProcessResult _run(String toolPath, [List<String> args = const []]) {
  // Checked before running so a wrong working directory fails saying so,
  // instead of surfacing as a non-zero exit that reads like real drift.
  if (!File(toolPath).existsSync()) {
    fail('$toolPath not found. Run `dart test` from the static_site_generator/ '
        'package root — the path is relative to it.');
  }
  return Process.runSync(
    // The Dart running this test, not whatever `dart` is on PATH: with Flutter
    // installed that is a wrapper script which writes to the engine cache on
    // startup, and fails wherever that cache is not writable.
    Platform.resolvedExecutable,
    ['run', toolPath, ...args],
  );
}

/// The tool's own output, which already names the row that moved.
String _output(ProcessResult result) =>
    '${result.stdout}${result.stderr}'.trim();
