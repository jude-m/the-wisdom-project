import 'dart:io';

import 'package:static_site_generator/data/corpus_reader.dart';
import 'package:static_site_generator/data/slicer_cache.dart';
import 'package:static_site_generator/domain/grouping_planner.dart';
import 'package:static_site_generator/domain/grouping_policy.dart';
import 'package:static_site_generator/domain/site_page.dart';
import 'package:wisdom_shared/wisdom_shared.dart';

/// Runs the split rule over the whole corpus and reports the page budget.
///
///     dart run static_site_generator/tool/plan_corpus.dart
///     dart run static_site_generator/tool/plan_corpus.dart --expect
///
/// The rule itself is in `domain/grouping_planner.dart` and its per-book
/// exceptions in `domain/grouping_policy.dart`; this only measures. Every
/// figure it prints is derived from one flat set of folded leaf keys plus
/// `SitePlan.build`, which is the same path the site itself takes — so a number
/// here that disagrees with the built manifest means the two have drifted, not
/// that the tool needs its own opinion.
///
/// `--expect` compares the run against [_locked] and exits non-zero on any
/// drift. Without it this tool only *prints*, so a number could move and the
/// run would still look like a success. Read the printout when reviewing a
/// change; use `--expect` when asking "did anything move?".
void main(List<String> args) {
  final expect = args.contains('--expect');
  if (args.any((a) => a != '--expect')) {
    stderr.writeln('Usage: plan_corpus.dart [--expect]');
    exitCode = 2;
    return;
  }

  final reader = CorpusReader.discover();
  final tree = reader.readTree();
  final cache = SlicerCache(reader: reader, tree: tree);
  final planner = GroupingPlanner(tree: tree, slicerFor: cache.forFile);

  final orphans = [
    for (final node in tree.allNodes)
      if (!node.isLeaf && node.contentFileId == null) node,
  ];

  final folded = planner.foldedLeaves();
  final plan = SitePlan.build(
    tree: tree,
    rootKeys: tree.rootKeys,
    foldedLeafKeys: folded,
  );

  final leaves = tree.allNodes.where((n) => n.isLeaf).length;
  final containers = tree.length - leaves;

  var suttaPages = 0;
  var wholeVaggaChapters = 0;
  var midVaggaChapters = 0;
  var tocPages = 0;
  for (final page in plan.pages) {
    switch (page.kind) {
      case PageKind.sutta:
        suttaPages++;
      case PageKind.chapter:
        page.node.isLeaf ? midVaggaChapters++ : wholeVaggaChapters++;
      case PageKind.toc:
        tocPages++;
    }
  }
  final chapterPages = wholeVaggaChapters + midVaggaChapters;
  const rootIndex = 1;
  final realPages = suttaPages + chapterPages + tocPages + rootIndex;

  stdout.writeln('tree              ${tree.length} nodes '
      '($leaves leaves, $containers containers)');
  stdout.writeln('files parsed      ${cache.parses}');
  // Zero across the vendored corpus. Reported rather than assumed because a
  // re-sync that introduces one is a hard error in the generator (a page whose
  // URL is linked but whose text cannot be found), and this run is where that
  // should first show up.
  stdout.writeln('orphan containers ${orphans.length}   (expected 0)');
  stdout.writeln('');
  stdout.writeln('sutta pages       $suttaPages');
  stdout.writeln('chapter pages     $chapterPages   '
      '($wholeVaggaChapters whole-vagga + $midVaggaChapters mid-vagga)');
  stdout.writeln('container TOCs    $tocPages');
  stdout.writeln('root index        $rootIndex');
  stdout.writeln('─────────────────────────');
  stdout.writeln('real pages        $realPages');
  stdout.writeln('folded leaves     ${folded.length}   (stubs, if picked)');
  stdout
      .writeln('with stubs        ${realPages + folded.length}   (cap 20,000)');

  // The derivation from Part 1's Impact table. Two fixed corpus totals decide
  // both moving rows, so an arithmetic mismatch here means the walk and the
  // planner disagree about what folded — the cheapest check that a measurement
  // is self-consistent, and the one that caught an earlier draft's mixed table.
  final derivedSutta = leaves - folded.length - midVaggaChapters;
  final derivedToc = containers - wholeVaggaChapters;
  stdout.writeln('');
  stdout.writeln('derivation        '
      'sutta ${derivedSutta == suttaPages ? 'ok' : 'MISMATCH $derivedSutta'} · '
      'toc ${derivedToc == tocPages ? 'ok' : 'MISMATCH $derivedToc'}');

  // The problem the rule was aimed at. Measured on the page, not the leaf: a
  // chapter carrying seven short suttas is not a thin page.
  final chars = _pageChars(plan, cache);
  final thin = [
    for (final page in plan.pages)
      if (page.kind == PageKind.sutta &&
          chars[page.nodeKey]! < GroupingPolicy.shortLineChars)
        page,
  ];
  final promotedThin = thin
      .where((p) => GroupingPolicy.policyFor(p.node) == LeafPolicy.ownPage)
      .length;
  stdout.writeln('thin sutta pages  ${thin.length}   '
      '(under ${GroupingPolicy.shortLineChars} chars; '
      '$promotedThin of them promoted books, thin on purpose)');

  final biggest = [
    for (final page in plan.pages)
      if (page.kind == PageKind.chapter && page.suttas.length > 1) page,
  ]..sort((a, b) => chars[b.nodeKey]!.compareTo(chars[a.nodeKey]!));
  final over100k = biggest.where((p) => chars[p.nodeKey]! > 100000).length;
  // Empty only under a root with no multi-sutta chapter, which a subtree run
  // can reach. Everything else here is guarded; this was the one place a `-`
  // in the printout would have arrived as a crash reading like real drift.
  final top = biggest.isEmpty ? null : biggest.first;
  stdout.writeln('biggest chapter   '
      '${top == null ? '—' : '${chars[top.nodeKey]} chars (${top.nodeKey})'}'
      ' · $over100k over 100k');

  stdout.writeln('');
  stdout.writeln('subtree            pages');
  for (final key in _watchedSubtrees) {
    final count = plan.pages
        .where((p) => p.nodeKey == key || _isUnder(tree, p.nodeKey, key))
        .length;
    stdout.writeln('  ${key.padRight(16)} $count');
  }

  if (expect) {
    final drifted = _checkLocked({
      'tree nodes': tree.length,
      'orphan containers': orphans.length,
      'sutta pages': suttaPages,
      'whole-vagga chapters': wholeVaggaChapters,
      'mid-vagga chapters': midVaggaChapters,
      'container TOCs': tocPages,
      'real pages': realPages,
      'folded leaves': folded.length,
      'with stubs': realPages + folded.length,
      'thin sutta pages': thin.length,
    });
    if (drifted) exitCode = 1;
  }
}

/// Combined raw characters each page renders, preamble included.
///
/// Built in one pass over the plan rather than per query: the slicer cache
/// holds one file at a time, so asking out of order re-parses.
Map<String, int> _pageChars(SitePlan plan, SlicerCache cache) {
  final chars = <String, int>{};
  for (final page in plan.pages) {
    var total = 0;
    if (page.hasPreamble) {
      final fileId = page.node.contentFileId;
      if (fileId != null) {
        total += cache.forFile(fileId).sliceFor(page.nodeKey).rawCharCount;
      }
    }
    for (final sutta in page.suttas) {
      final fileId = sutta.contentFileId;
      if (fileId != null) {
        total += cache.forFile(fileId).sliceFor(sutta.nodeKey).rawCharCount;
      }
    }
    chars[page.nodeKey] = total;
  }
  return chars;
}

bool _isUnder(TipitakaTree tree, String key, String ancestorKey) {
  for (String? at = tree[key]?.parentNodeKey;
      at != null;
      at = tree[at]?.parentNodeKey) {
    if (at == ancestorKey) return true;
  }
  return false;
}

/// The subtrees the plan doc argues about, printed every run so a review can
/// check the worked examples without a second tool.
const List<String> _watchedSubtrees = [
  'sn-4-9-2',
  'sn-2-1-8',
  'sn-2-1-9',
  'sn-2-1-10',
  'sn-5-12-2',
  'atta-sn-1-1-6',
  'kn-khp',
  'kn-thig-6',
  'kn-thag',
  'an-1-14',
];

/// The locked page budget.
///
/// These are not aspirations — they are the numbers the hosting topology, the
/// Cloudflare file cap and the P5 stub gate were all sized against. A change
/// here is a real decision (a line move, a book policy, a re-sync from upstream
/// tipitaka.lk that shifts nodeKeys), never a drive-by: **update the figure and
/// `docs/todo/web-strategy/reading-units-and-grouping.md` in the same commit,
/// or find out why it moved.**
///
/// `tree nodes` is the whole vendored `tree.json`; `real pages` counts the
/// site's own `/` index alongside everything written under `/tipitaka/`.
const Map<String, int> _locked = {
  'tree nodes': 16355,
  'orphan containers': 0,
  'sutta pages': 7687,
  'whole-vagga chapters': 615,
  'mid-vagga chapters': 606,
  'container TOCs': 1389,
  'real pages': 10298,
  'folded leaves': 6058,
  'with stubs': 16356,
  'thin sutta pages': 738,
};

/// Compares a run against [_locked]; true when anything moved.
///
/// Prints every row rather than only the failures, so a reviewer can see the
/// check ran over all of them. That is evidence to a human reading the output
/// and to nobody else — CI sees an exit code — which is why the set of rows is
/// checked in both directions below rather than left to be eyeballed.
bool _checkLocked(Map<String, int> counts) {
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

  // The other direction. `report` only ever sees labels this *run* produced, so
  // deleting a line from the literal above would stop checking that figure and
  // still exit 0 — a green wall with one fewer row in it, which is exactly the
  // kind of change nobody reads closely enough to catch.
  final unreported = _locked.keys.toSet().difference(counts.keys.toSet());
  for (final label in unreported) {
    drifted = true;
    stdout.writeln('  DRIFT ${label.padRight(24)} '
        'locked, but this run never reported it');
  }

  if (drifted) {
    stdout.writeln('');
    stdout.writeln('A locked figure moved. Either the corpus was re-synced or '
        'the grouping rule changed —');
    stdout.writeln('both are real decisions. Update _locked and the plan doc '
        'together, or find out why.');
  }
  return drifted;
}
