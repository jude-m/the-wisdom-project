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
///
/// This exists because the *original* classifier was never committed — only its
/// CSV output was, which made an off-by-one in it unreviewable. That CSV listed
/// 145 grouped vaggas; it was produced by slicing each leaf up to the next
/// **readable** node instead of the next node of any kind, which inflates the
/// last leaf of every container with the following container's preamble. Under
/// the correct rule the answer is **146 vaggas / 1,603 leaves**.
///
/// Takes ~1 minute: it parses all 285 content files.
void main(List<String> args) {
  final writeCsv = args.contains('--write-csv');
  if (args.any((a) => a != '--write-csv')) {
    stderr.writeln('Usage: classify_corpus.dart [--write-csv]');
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
  final path = '${reader.assetsPath}/../docs/todo/web-strategy/'
      'grouped-vaggas-threshold-1500.csv';
  // BOM + CRLF, matching the file this replaces: it exists to be eyeballed in
  // Excel, which wants both. Nothing downstream parses it, and keeping the
  // encoding identical means a re-run's diff shows verdicts, not line endings.
  File(path).writeAsStringSync('﻿$header\r\n${rows.join('\r\n')}\r\n');
  stdout.writeln('');
  stdout.writeln('wrote ${rows.length} rows → ${File(path).absolute.path}');
}

/// Quotes a CSV field only when it needs it. Titles carry commas.
String _csv(String value) =>
    value.contains(',') || value.contains('"') || value.contains('\n')
        ? '"${value.replaceAll('"', '""')}"'
        : value;
