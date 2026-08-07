import 'dart:io';

import 'package:static_site_generator/data/corpus_reader.dart';
import 'package:static_site_generator/data/slicer_cache.dart';
import 'package:static_site_generator/domain/site_page.dart';
import 'package:static_site_generator/domain/grouping_classifier.dart';
import 'package:wisdom_shared/wisdom_shared.dart';

/// Runs the grouping classifier over the whole corpus and reports the page
/// budget, optionally regenerating the reviewable CSV.
///
///     dart run static_site_generator/tool/classify_corpus.dart
///     dart run static_site_generator/tool/classify_corpus.dart --write-csv
///     dart run static_site_generator/tool/classify_corpus.dart --expect
///
/// This exists because the *original* classifier was never committed — only its
/// CSV output was, which made an off-by-one in it unreviewable. That CSV listed
/// 145 grouped vaggas; it was produced by slicing each leaf up to the next
/// **readable** node instead of the next node of any kind, which inflates the
/// last leaf of every container with the following container's preamble. Under
/// the correct rule the answer is **146 vaggas / 1,603 leaves**.
///
/// `--expect` compares the run against [_locked] and exits non-zero on any
/// drift. Without it this tool only *prints*, so a number could move and the run
/// would still look like a success — no use in CI, and easy to skim past by
/// hand. Read the printout when reviewing a refinement; use `--expect` when
/// asking "did anything move?".
///
/// ~3s: it parses 231 of the 285 content files, the earlier gates having settled
/// the rest. `test/corpus_tools_test.dart` runs `--expect` on every `dart test`.
void main(List<String> args) {
  final writeCsv = args.contains('--write-csv');
  final expect = args.contains('--expect');
  if (args.any((a) => a != '--write-csv' && a != '--expect')) {
    stderr.writeln('Usage: classify_corpus.dart [--write-csv] [--expect]');
    exitCode = 2;
    return;
  }

  final reader = CorpusReader.discover();
  final tree = reader.readTree();
  final cache = SlicerCache(reader: reader, tree: tree);
  final classifier = GroupingClassifier(tree: tree, slicerFor: cache.forFile);

  // Classify file by file rather than by tree order: the cache holds one parsed
  // file, and a container's leaves are always in a single file.
  final containersByFile = <String, List<TipitakaNode>>{};
  final orphans = <TipitakaNode>[];
  for (final node in tree.allNodes) {
    if (node.isLeaf) continue;
    final fileId = node.contentFileId;
    if (fileId == null) {
      orphans.add(node);
    } else {
      (containersByFile[fileId] ??= []).add(node);
    }
  }

  final verdicts = <String, GroupingVerdict>{};
  for (final fileId in containersByFile.keys.toList()..sort()) {
    for (final container in containersByFile[fileId]!) {
      verdicts[container.nodeKey] = classifier.classify(container);
    }
  }
  for (final container in orphans) {
    verdicts[container.nodeKey] = classifier.classify(container);
  }

  final grouped = verdicts.values.where((v) => v.grouped).toList();
  final groupedLeaves = grouped.fold(0, (sum, v) => sum + v.leafCount);
  final leaves = tree.allNodes.where((n) => n.isLeaf).length;
  final containers = tree.length - leaves;

  final explodedLeaves = leaves - groupedLeaves;
  final chapterPages = grouped.length;
  final tocPages = containers - grouped.length;
  const rootIndex = 1;
  final realPages = explodedLeaves + chapterPages + tocPages + rootIndex;

  stdout.writeln('tree              ${tree.length} nodes '
      '($leaves leaves, $containers containers)');
  stdout.writeln('files parsed      ${cache.parses}');
  // Zero across the vendored corpus. Reported rather than assumed because a
  // re-sync that introduces one is a hard error in the generator (a page whose
  // URL is linked but whose text cannot be found), and this run is where that
  // should first show up.
  stdout.writeln('orphan containers ${orphans.length}   (expected 0)');
  stdout.writeln('');
  stdout.writeln('grouped vaggas    ${grouped.length}');
  stdout.writeln(
      'grouped leaves    $groupedLeaves   (redirect stubs, if picked)');
  stdout.writeln('exploded leaves   $explodedLeaves');
  stdout.writeln('chapter pages     $chapterPages');
  stdout.writeln('container TOCs    $tocPages');
  stdout.writeln('root index        $rootIndex');
  stdout.writeln('─────────────────────────');
  stdout.writeln('real pages        $realPages');
  stdout
      .writeln('with stubs        ${realPages + groupedLeaves}   (cap 20,000)');
  stdout.writeln('');

  final reasons = <GroupingReason, int>{};
  for (final verdict in verdicts.values) {
    reasons[verdict.reason] = (reasons[verdict.reason] ?? 0) + 1;
  }
  for (final entry in reasons.entries) {
    stdout.writeln('${entry.key.name.padRight(20)} ${entry.value}');
  }

  // The threshold's margin is one character (`kn-thig-6` measures exactly
  // 1,500), so report what is closest on each side of it every run.
  // `maxLeafChars != null` already implies the leaf-count gate: a container is
  // only measured once it has passed it.
  final measured = verdicts.values.where((v) => v.maxLeafChars != null).toList()
    ..sort((a, b) => a.maxLeafChars!.compareTo(b.maxLeafChars!));
  final nearestGrouped = measured.lastWhere((v) => v.grouped);
  final nearestExploded = measured.firstWhere((v) => !v.grouped);
  stdout.writeln('');
  stdout
      .writeln('closest to the ${GroupingClassifier.maxLeafChars}-char line:');
  stdout.writeln('  grouped   ${nearestGrouped.containerKey} '
      'max=${nearestGrouped.maxLeafChars}');
  stdout.writeln('  exploded  ${nearestExploded.containerKey} '
      'max=${nearestExploded.maxLeafChars}');

  if (expect) {
    final drifted = _checkLocked({
      'tree nodes': tree.length,
      'orphan containers': orphans.length,
      'grouped vaggas': grouped.length,
      'grouped leaves': groupedLeaves,
      'real pages': realPages,
      'with stubs': realPages + groupedLeaves,
      // The two either side of the line, by measurement and (below) by key. The
      // threshold's margin is a single character, so a re-sync that shifts one
      // of these by one silently regroups a vagga — which moves every page count
      // above it and changes where 1,603 deep links have to point.
      'nearest grouped chars': nearestGrouped.maxLeafChars!,
      'nearest exploded chars': nearestExploded.maxLeafChars!,
    }, {
      'nearest grouped': nearestGrouped.containerKey,
      'nearest exploded': nearestExploded.containerKey,
    });
    if (drifted) exitCode = 1;
  }

  if (!writeCsv) return;

  final rows = <String>[];
  for (final node in tree.allNodes) {
    final verdict = verdicts[node.nodeKey];
    if (verdict == null || !verdict.grouped) continue;
    final children = tree.childrenOf(node.nodeKey);
    final slicer = cache.forFile(children.first.contentFileId!);
    final sizes = [
      for (final child in children) slicer.sliceFor(child.nodeKey).rawCharCount,
    ];
    rows.add([
      node.nodeKey,
      // The same collection the page titles use, not a second rule read off
      // the key: the two used to disagree (`kn-ap` here against `kn` there) and
      // there is no reason for a reviewer to have to know which is which.
      collectionOf(tree, node.nodeKey)?.nodeKey ?? node.nodeKey,
      _csv(node.paliName),
      _csv(node.sinhalaName),
      '${verdict.leafCount}',
      '${sizes.reduce((a, b) => a < b ? a : b)}',
      '${verdict.maxLeafChars}',
      '${sizes.reduce((a, b) => a + b)}',
      tipitakaUrl(node.nodeKey),
      children.first.contentFileId!,
    ].join(','));
  }

  // Lexicographic by nodeKey, matching the CSV this file replaces, so a
  // re-run's git diff shows the verdicts that actually moved rather than a
  // whole-file reshuffle.
  rows.sort();

  const header = 'nodeKey,collection,pali_name,sinhala_name,sutta_count,'
      'min_sutta_chars,max_sutta_chars,total_vagga_chars,chapter_url,content_file';
  final path = '$_repoRoot/docs/todo/web-strategy/'
      'grouped-vaggas-threshold-1500.csv';
  // BOM + CRLF, matching the file this replaces: it exists to be eyeballed in
  // Excel, which wants both. Nothing downstream parses it, and keeping the
  // encoding identical means a re-run's diff shows verdicts, not line endings.
  File(path).writeAsStringSync('﻿$header\r\n${rows.join('\r\n')}\r\n');
  stdout.writeln('');
  stdout.writeln('wrote ${rows.length} rows → ${File(path).absolute.path}');
}

/// The locked page budget, verified over the full corpus on 2026-07-22 and
/// re-confirmed as each phase ships.
///
/// These are not aspirations — they are the numbers the hosting topology, the
/// Cloudflare file cap and the P6 stub gate were all sized against. A change
/// here is a real decision (a threshold move, a re-sync from upstream
/// tipitaka.lk that shifts nodeKeys), never a drive-by: **update the figure and
/// the plan docs in the same commit, or find out why it moved.**
///
/// `tree nodes` is the whole vendored `tree.json`; `real pages` counts the
/// site's own `/` index alongside the 14,752 written under `/tipitaka/`.
const Map<String, int> _locked = {
  'tree nodes': 16355,
  'orphan containers': 0,
  'grouped vaggas': 146,
  'grouped leaves': 1603,
  'real pages': 14753,
  'with stubs': 16356,
  'nearest grouped chars': 1490,
  // Exactly the threshold. `GroupingClassifier` tests `<`, so this container
  // stays exploded by a single character — the strict comparison is
  // load-bearing, and this row is what proves it still is.
  'nearest exploded chars': 1500,
};

/// The two containers either side of the threshold, by key.
const Map<String, String> _lockedKeys = {
  'nearest grouped': 'atta-an-10-1-1',
  'nearest exploded': 'kn-thig-6',
};

/// Compares a run against [_locked] / [_lockedKeys]; true when anything moved.
///
/// Prints every row rather than only the failures, so a reviewer can see the
/// check ran over all of them. That is evidence to a human reading the output
/// and to nobody else — CI sees an exit code — which is why the count of rows
/// is asserted below rather than left to be eyeballed.
bool _checkLocked(Map<String, int> counts, Map<String, String> keys) {
  var drifted = false;
  stdout.writeln('');
  stdout.writeln('--expect:');

  // `expected` is nullable so a label the run produced with no locked
  // counterpart — a typo, or a row added here and not there — reports as a
  // failure instead of comparing against null and quietly passing.
  void report(String label, Object actual, Object? expected) {
    final ok = expected != null && actual == expected;
    if (!ok) drifted = true;
    final note = expected == null
        ? '   NO LOCKED VALUE for "$label"'
        : (ok ? '' : '   expected $expected');
    stdout.writeln(
        '  ${ok ? 'ok  ' : 'DRIFT'} ${label.padRight(24)} $actual$note');
  }

  counts.forEach((label, actual) => report(label, actual, _locked[label]));
  keys.forEach((label, actual) => report(label, actual, _lockedKeys[label]));

  // The other direction. `report` only ever sees labels this *run* produced, so
  // deleting a line from the literal above would stop checking that figure and
  // still exit 0 — a green wall with one fewer row in it, which is exactly the
  // kind of change nobody reads closely enough to catch.
  final unreported = {..._locked.keys, ..._lockedKeys.keys}
      .difference({...counts.keys, ...keys.keys});
  for (final label in unreported) {
    drifted = true;
    stdout.writeln('  DRIFT ${label.padRight(24)} '
        'locked, but this run never reported it');
  }

  if (drifted) {
    stdout.writeln('');
    stdout.writeln('A locked figure moved. Either the corpus was re-synced or '
        'the grouping rule changed —');
    stdout.writeln('both are real decisions. Update _locked and the plan docs '
        'together, or find out why.');
  }
  return drifted;
}

/// Repo root, for the one doc this tool writes.
///
/// Read off `Platform.script` — the URI of *this file*, two directories down
/// from the root — rather than off `reader.assetsPath`. That was
/// `assetsPath/../docs/…`, which asks the *corpus* where the *docs* are: it
/// only holds while `CorpusReader.discover()` lands on this repo's own
/// `assets/`, and when it doesn't the CSV is written somewhere beside the
/// corpus, leaving the reviewed file quietly stale.
final String _repoRoot =
    File.fromUri(Platform.script).parent.parent.parent.path;

/// Quotes a CSV field only when it needs it. Titles carry commas.
String _csv(String value) =>
    value.contains(',') || value.contains('"') || value.contains('\n')
        ? '"${value.replaceAll('"', '""')}"'
        : value;
