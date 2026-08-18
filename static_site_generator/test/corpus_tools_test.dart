/// The two whole-corpus tools, run automatically.
///
/// Both already assert and exit non-zero, so each test just runs one and checks
/// the exit code. The point isn't a new check — it's that **nobody has to
/// remember**. Their documented trigger is a re-sync of `assets/` from upstream,
/// and a trigger written in a doc holds until someone re-syncs without reading
/// the doc.
///
/// Still run them by hand when reviewing a change: the printout shows the page
/// budget and what the grouping rule would say about newly synced content,
/// which a pass/fail cannot.
@Tags(['corpus'])
library;

import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('the frozen snapshot still describes this tree, and the rule still runs',
      () {
    // The default report rather than `--check`, which is not a second test's
    // worth of coverage: `_integrity` and `SitePlan.build` both run *before*
    // the mode branch, so this already asks the four questions `--check` asks.
    // What it adds is `GroupingPlanner` — which since the freeze nothing else
    // runs, at build time or anywhere else. A rule that has stopped compiling
    // would otherwise surface at `--write-snapshot`, mid-sync.
    //
    // Two things it deliberately does *not* assert. Page totals: they cannot
    // drift on their own any more, nothing re-measures them, and new upstream
    // content should add pages without failing here. And the advisor's two
    // counts: absorbing that drift is the entire point of freezing, so a
    // re-sync that moves a text across its line must not fail here either.
    // Reading the advisor is a step in the sync runbook, not a gate.
    //
    // What is left is the one event no local design survives: an upstream
    // re-sync that renumbers nodeKeys, turning frozen verdicts into keys that
    // name nothing.
    final result = _run('tool/plan_corpus.dart');
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
ProcessResult _run(String toolPath) {
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
    ['run', toolPath],
  );
}

/// The tool's own output, which already names the row that moved.
String _output(ProcessResult result) =>
    '${result.stdout}${result.stderr}'.trim();
