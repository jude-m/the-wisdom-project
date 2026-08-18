import 'dart:io';

import 'package:static_site_generator/data/corpus_reader.dart';
import 'package:static_site_generator/data/slicer_cache.dart';
import 'package:static_site_generator/domain/grouping_planner.dart';
import 'package:static_site_generator/domain/grouping_policy.dart';
import 'package:static_site_generator/domain/site_page.dart';
import 'package:wisdom_shared/wisdom_shared.dart';

/// Reports the page budget, checks the frozen snapshot, and regenerates it.
///
///     dart run static_site_generator/tool/plan_corpus.dart
///     dart run static_site_generator/tool/plan_corpus.dart --check
///     dart run static_site_generator/tool/plan_corpus.dart --write-snapshot
///
/// The build no longer measures anything: `foldedLeafKeys` in `wisdom_shared`
/// is the frozen answer, and `SitePlan.build` reconstructs every page from it.
/// The rule that *produced* those keys lives in `domain/grouping_planner.dart`
/// and its per-book exceptions in `domain/grouping_policy.dart`, and from here
/// on it runs only at sync time — as the writer behind `--write-snapshot`, and
/// as the advisor whose disagreements the default report prints.
///
/// **The three modes cost very different things.** `--check` reads the tree
/// only (~1 s): its four questions are about the shape of the snapshot against
/// the shape of the tree, and none of them needs a character count. The other
/// two re-measure, because the rule does — and the default report measures
/// *twice*, once to run the rule and once to size the pages it planned.
///
/// | mode | what it answers | on failure |
/// |---|---|---|
/// | `--check` | is the frozen snapshot still describable by this tree? | exit 1 |
/// | *(none)* | what does the frozen site look like, and where does the rule now disagree? | prints |
/// | `--write-snapshot` | rewrite the frozen set from the rule | writes |
///
/// **What is deliberately no longer here: a locked page budget.** `--expect`
/// compared ten counted rows against a literal, which was the right guard while
/// the rule ran at build time and one edited character could move a URL. It is
/// the wrong guard now — the counts cannot drift on their own, because nothing
/// re-measures them; and new upstream content *should* add pages without
/// failing CI. What replaces it is [_integrity], which has no judgment in it,
/// and the git diff of `grouping_snapshot.dart`, which is the review artifact
/// for every deliberate move.
void main(List<String> args) {
  const modes = {'--check', '--write-snapshot'};
  final unknown = args.where((a) => !modes.contains(a)).toList();
  if (unknown.isNotEmpty || args.length > 1) {
    stderr.writeln(unknown.isEmpty
        ? 'One mode at a time.'
        : 'Unknown option "${unknown.first}".');
    stderr.writeln('Usage: plan_corpus.dart [--check | --write-snapshot]');
    exitCode = 2;
    return;
  }
  final check = args.contains('--check');

  final reader = CorpusReader.discover();
  final tree = reader.readTree();

  // Each mode builds only what it needs, and only this one and the default
  // report need the rule — `--check` asks nothing about text, and reading 340 MB
  // to not use it would make the one mode meant to run automatically the
  // slowest of the three.
  if (args.contains('--write-snapshot')) {
    final cache = SlicerCache(reader: reader, tree: tree);
    _writeSnapshot(
      _snapshotPath(reader),
      tree,
      GroupingPlanner(tree: tree, slicerFor: cache.forFile).foldedLeaves(),
    );
    return;
  }

  // The frozen set, not the rule's — this is what the site actually builds
  // from, so it is what the budget below has to describe.
  const folded = foldedLeafKeys;

  final violations = _integrity(tree, folded);
  if (violations.isNotEmpty) {
    stdout.writeln('integrity FAILED — ${violations.length} violation(s):');
    for (final line in violations) {
      stdout.writeln('  $line');
    }
    stdout.writeln('');
    stdout.writeln('The snapshot describes a site this tree cannot produce. '
        'Either assets/data/tree.json');
    stdout.writeln('was re-synced with renumbered nodeKeys — the one event no '
        'local design survives, and');
    stdout.writeln('the stop-the-line moment of the sync workflow — or '
        'grouping_snapshot.dart was hand-edited.');
    exitCode = 1;
    return;
  }

  // Built after the integrity check, never before: its three StateErrors guard
  // the same shapes, and a thrown stack trace says far less about which key is
  // wrong than the lines above do.
  final plan = SitePlan.build(
    tree: tree,
    rootKeys: tree.rootKeys,
    foldedLeafKeys: folded,
  );

  if (check) {
    if (!_printBudget(tree, plan, folded, parses: null)) exitCode = 1;
    return;
  }

  // Both passes over the corpus finish before anything is printed, so `files
  // parsed` can report the whole run. `_pageChars` is a *second* pass — the
  // cache holds one file — and a figure printed between the two describes
  // neither, which is what `SlicerCache.parses` exists to make visible.
  final cache = SlicerCache(reader: reader, tree: tree);
  final ruleSays =
      GroupingPlanner(tree: tree, slicerFor: cache.forFile).foldedLeaves();
  final chars = _pageChars(plan, cache);

  if (!_printBudget(tree, plan, folded, parses: cache.parses)) exitCode = 1;
  _printSizes(plan, chars);
  _printSubtrees(tree, plan);
  _reportAdvice(folded, ruleSays);
}

// ---------------------------------------------------------------------------
// The printed report
// ---------------------------------------------------------------------------

/// The page budget, every row of it derived from the frozen set and
/// `SitePlan`'s own walk. Returns whether the derivation identity closed.
///
/// [parses] is null when no content was read. The row is then omitted rather
/// than printed as a zero, which would read as a broken cache instead of a mode
/// that never opened a file.
bool _printBudget(
  TipitakaTree tree,
  SitePlan plan,
  Set<String> folded, {
  required int? parses,
}) {
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
  stdout.writeln('snapshot          ${folded.length} folded leaves');
  if (parses != null) stdout.writeln('files parsed      $parses');
  // No count of the checks: it can only ever drift from `_integrity`, and once
  // the answer is "none" the number of questions asked tells a reader nothing.
  stdout.writeln('integrity         ok   (no violations)');
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
  // snapshot disagree about what folded — the cheapest check that a measurement
  // is self-consistent, and the one that caught an earlier draft's mixed table.
  final derivedSutta = leaves - folded.length - midVaggaChapters;
  final derivedToc = containers - wholeVaggaChapters;
  final holds = derivedSutta == suttaPages && derivedToc == tocPages;
  stdout.writeln('');
  stdout.writeln('derivation        '
      'sutta ${derivedSutta == suttaPages ? 'ok' : 'MISMATCH $derivedSutta'} · '
      'toc ${derivedToc == tocPages ? 'ok' : 'MISMATCH $derivedToc'}');
  if (!holds) {
    // Exits non-zero rather than only printing, because `--check` is the mode
    // that runs unattended and this is the one thing left that it alone can
    // catch. Every shape [_integrity] covers has already passed by the time we
    // are here, so what remains is a node no root can reach — a parent cycle in
    // a re-synced tree.json, which nothing else in the pipeline would notice.
    stdout.writeln('');
    stdout.writeln('The tree holds leaves the walk never reached. The integrity '
        'checks passed, so this is');
    stdout.writeln('not a snapshot problem: it is a subtree no root can reach, '
        'i.e. a parent cycle in');
    stdout.writeln('assets/data/tree.json. Those pages would be missing from '
        'the site in silence.');
  }
  return holds;
}

/// Page sizes — the problem the rule was aimed at, and its opposite end.
void _printSizes(SitePlan plan, Map<String, int> chars) {
  // Measured on the page, not the leaf: a chapter carrying seven short suttas
  // is not a thin page.
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
}

/// Page counts for [_watchedSubtrees].
void _printSubtrees(TipitakaTree tree, SitePlan plan) {
  stdout.writeln('');
  stdout.writeln('subtree            pages');
  for (final key in _watchedSubtrees) {
    final count = plan.pages
        .where((p) => p.nodeKey == key || _isUnder(tree, p.nodeKey, key))
        .length;
    stdout.writeln('  ${key.padRight(16)} $count');
  }
}

// ---------------------------------------------------------------------------
// Integrity — the four questions that survive freezing
// ---------------------------------------------------------------------------

/// Whether the tree can still produce the site the snapshot describes.
///
/// Every check here is a question about *shape*, answerable from the tree
/// alone, and none of them has an opinion about where a line should sit — that
/// judgment was spent once, when the snapshot was written. They fire on one
/// event: an upstream re-sync that renumbers `nodeKey`s. New content trips
/// nothing, deliberately, because an absent key already means "owns a page".
///
/// Returns one line per violation, most specific first, capped per check so a
/// wholesale renumbering reports as a diagnosis rather than 6,000 lines.
List<String> _integrity(TipitakaTree tree, Set<String> folded) {
  final violations = <String>[];

  void report(String what, List<String> offenders) {
    if (offenders.isEmpty) return;
    final shown = offenders.take(_maxOffendersShown).join(', ');
    final rest = offenders.length - _maxOffendersShown;
    violations.add('$what: ${offenders.length} '
        '($shown${rest > 0 ? ', +$rest more' : ''})');
  }

  // 1. Every folded key still names a leaf. A key that vanished, or that grew
  //    children, has no page to be folded into and `urlFor` would keep handing
  //    out a fragment on a page that no longer carries it.
  final missing = <String>[];
  final notLeaves = <String>[];
  for (final key in folded) {
    final node = tree[key];
    if (node == null) {
      missing.add(key);
    } else if (!node.isLeaf) {
      notLeaves.add(key);
    }
  }
  report('folded keys no longer in the tree', missing);
  report('folded keys that are no longer leaves', notLeaves);

  // 2. Every folded leaf's parent is still a container the rule could have
  //    grouped: all children leaves, all in one content file. Both are
  //    preconditions of the rule (Part 1), and both are the reason a chapter
  //    page is renderable at all — a parent that has since grown a
  //    sub-container would put text and navigation on one page, and one that
  //    now spans two content files cannot be spliced into a single chapter.
  // The containers checks 2 and 3 are both about, named up front rather than
  // accumulated as a side effect of check 2's de-duplication. Check 3 reads this
  // set, and building it inside check 2's loop made its coverage depend on where
  // an early `continue` happened to sit. Insertion order is the snapshot's own
  // reading order, so the report stays byte-stable across runs.
  final parentsOfFolded = <String>{};
  for (final key in folded) {
    final parentKey = tree[key]?.parentNodeKey;
    if (parentKey != null) parentsOfFolded.add(parentKey);
  }

  final hybridParents = <String>[];
  final splitParents = <String>[];
  for (final parentKey in parentsOfFolded) {
    final children = tree.childrenOf(parentKey);
    if (children.any((child) => !child.isLeaf)) {
      hybridParents.add(parentKey);
      continue;
    }
    final fileIds = {for (final child in children) child.contentFileId};
    if (fileIds.length != 1 || fileIds.first == null) {
      splitParents.add(parentKey);
    }
  }
  report('containers of folded leaves that now hold a sub-container',
      hybridParents);
  report('containers of folded leaves that now span content files',
      splitParents);

  // 3. The index-0 invariant `SitePlan.build` reconstructs from: a first child
  //    folds only when the whole container folds. A run starting at the first
  //    sutta anchors on that leaf, which stays unfolded and owns the URL — so a
  //    folded first child beside an unfolded sibling is a page half text and
  //    half navigation, which the rule cannot produce.
  final hybridPages = <String>[];
  for (final parentKey in parentsOfFolded) {
    final children = tree.childrenOf(parentKey);
    if (children.isEmpty || !folded.contains(children.first.nodeKey)) continue;
    if (children.any((child) => !folded.contains(child.nodeKey))) {
      hybridPages.add(parentKey);
    }
  }
  report('containers whose first leaf folds beside an unfolded sibling',
      hybridPages);

  // 4. Orphan containers — the one question here that is about the tree rather
  //    than the snapshot, which is why [_orphanContainers] is shared with the
  //    writer. Through [report] like the rest: naming the container is what
  //    turns "expected 0" into somewhere to look.
  report('containers with no content file', _orphanContainers(tree));

  return violations;
}

/// Containers carrying no content file of their own.
///
/// None across the vendored corpus, and a re-sync that introduces one is a hard
/// error in the generator: a page whose URL every breadcrumb and TOC already
/// links, but whose text cannot be found. Read by [_integrity] and by
/// [_writeSnapshot], because the mode that freezes verdicts must not be the one
/// mode that stays quiet about it.
List<String> _orphanContainers(TipitakaTree tree) => [
      for (final node in tree.allNodes)
        if (!node.isLeaf && node.contentFileId == null) node.nodeKey,
    ];

/// Offending keys printed per violation before the count stands in for them.
const int _maxOffendersShown = 5;

// ---------------------------------------------------------------------------
// Advisor — what the rule would say, now that nobody has to listen
// ---------------------------------------------------------------------------

/// The rule's opinion against the frozen set.
///
/// Both directions are informational and **the snapshot wins either way**.
/// Proposals are the interesting half: content that arrived since the freeze
/// owns a page by default, which errs safe (a thin page, never a named text
/// hidden behind a fragment) and is the shape a deliberate `--write-snapshot`
/// would change. Disagreements mean an existing text has crossed its line since
/// the freeze, which is exactly the drift freezing exists to absorb: the page
/// contents move, the URL does not.
void _reportAdvice(Set<String> folded, Set<String> ruleSays) {
  final proposals = ruleSays.difference(folded).toList();
  final disagreements = folded.difference(ruleSays).toList();

  stdout.writeln('');
  stdout.writeln('advisor           the rule re-run against the frozen set');
  stdout.writeln('  proposals       ${proposals.length}   '
      'leaves the rule would now fold (they own a page today)');
  stdout.writeln('  disagreements   ${disagreements.length}   '
      'folded leaves the rule would now explode (snapshot wins)');
  if (proposals.isEmpty && disagreements.isEmpty) {
    stdout.writeln('  nothing to review — the frozen set is what the rule '
        'says today.');
    return;
  }
  for (final entry in [
    ('  + ', proposals),
    ('  − ', disagreements),
  ]) {
    for (final key in entry.$2.take(_maxOffendersShown)) {
      stdout.writeln('${entry.$1}$key');
    }
    final rest = entry.$2.length - _maxOffendersShown;
    if (rest > 0) stdout.writeln('${entry.$1}… +$rest more');
  }
  stdout.writeln('  Neither is acted on. Moving a URL is `--write-snapshot` '
      'plus a review of its diff.');
}

// ---------------------------------------------------------------------------
// The snapshot writer
// ---------------------------------------------------------------------------

/// Rewrites `grouping_snapshot.dart` from one full-corpus run of the rule.
///
/// **Reading order, one key per line.** The order is the site's own walk, so a
/// book's folds land in one contiguous block and the file reads as a document
/// rather than an index; one key per line is what makes the git diff the impact
/// review the plan doc promises — every added or removed line is exactly one
/// sutta whose URL moved. Nothing here varies per run (no timestamp, no build
/// id), so regenerating an unchanged corpus rewrites identical bytes (§11.8).
void _writeSnapshot(
  String path,
  TipitakaTree tree,
  Set<String> folded,
) {
  final ordered = <String>[];
  void walk(TipitakaNode node) {
    if (folded.contains(node.nodeKey)) ordered.add(node.nodeKey);
    for (final child in tree.childrenOf(node.nodeKey)) {
      walk(child);
    }
  }

  for (final root in tree.roots) {
    walk(root);
  }
  // Only reachable if a folded key sits outside every root, which the tree's
  // own parent check already rules out. Loud rather than silently short.
  if (ordered.length != folded.length) {
    stderr.writeln('${folded.length - ordered.length} folded key(s) are not '
        'reachable from any root. Refusing to write a partial snapshot.');
    exitCode = 1;
    return;
  }

  // Every key is interpolated into a single-quoted Dart literal below, so one
  // carrying a quote, a backslash or a `$` would emit a file that does not
  // compile — or, with `$`, one that compiles and means something else. Every
  // key in the vendored tree is safe; upstream is not bound by that, and
  // absorbing re-syncs is the whole reason this file exists.
  final unsafe = ordered.where((key) => !_dartSafeKey.hasMatch(key)).toList();
  if (unsafe.isNotEmpty) {
    stderr.writeln('${unsafe.length} nodeKey(s) cannot be written as a Dart '
        'literal: ${unsafe.take(_maxOffendersShown).join(', ')}');
    stderr.writeln('Refusing to write a file that would break every package '
        'importing it. Add escaping here first.');
    exitCode = 1;
    return;
  }

  // Built before it is written, for two reasons. It proves the set is
  // *buildable* — `SitePlan.build` throws on each of the three shapes the rule
  // cannot produce, so a snapshot that would break the site never reaches the
  // working tree. And the page count in the header comes from the same walk
  // that will serve it, so the two cannot describe different sites.
  final readable = SitePlan.build(
    tree: tree,
    rootKeys: tree.rootKeys,
    foldedLeafKeys: folded,
  ).readablePages.length;

  final buffer = StringBuffer('''
// GENERATED by `dart run static_site_generator/tool/plan_corpus.dart
// --write-snapshot`. Hand-editing it moves URLs with no review behind them —
// change the rule (`static_site_generator/lib/domain/grouping_policy.dart`)
// and regenerate instead.

/// Every leaf that does **not** get its own page — ${_thousands(ordered.length)} of them, frozen
/// from one full-corpus run of the split rule.
///
/// **A leaf absent from this set owns its URL.** That is the safe direction:
/// new content self-handles, a wrong explode costs one thin page, and only a
/// wrong fold could hide a named text behind a fragment.
///
/// Nothing re-measures the rule. `SitePlan.build` reconstructs all ${_thousands(readable)}
/// readable pages from this set alone, so a re-sync of `assets/` may change
/// what a page *says* and never which pages *exist*. Regenerating is the
/// supported way to move a line, and the git diff of this file is the impact
/// review: one line per sutta whose URL moved.
///
/// Generated code rather than a bundled asset, because the app reads the same
/// verdicts and may gain no new asset file — one `const` compiles into both
/// surfaces from one place. Written in reading order.
///
/// See `docs/todo/web-strategy/reading-units-and-grouping.md` — Part 2.
const Set<String> foldedLeafKeys = {
''');
  for (final key in ordered) {
    buffer.writeln("  '$key',");
  }
  buffer.writeln('};');

  // What this run was *compiled* against, which is the committed file's
  // contents — Dart resolved the import before any of this ran, so reading the
  // file back off disk would only re-parse the same answer.
  const before = foldedLeafKeys;
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(buffer.toString());

  final added = folded.difference(before).length;
  final removed = before.difference(folded).length;
  stdout.writeln('wrote             $path');
  stdout.writeln('folded leaves     ${ordered.length}');
  stdout.writeln('diff              +$added / −$removed against the set this '
      'run was compiled with');
  if (added != 0 || removed != 0) {
    stdout.writeln('');
    stdout.writeln('That is ${added + removed} URL(s) moving. Review '
        '`git diff` on the snapshot, and update');
    stdout.writeln('docs/todo/web-strategy/reading-units-and-grouping.md in '
        'the same commit.');
  }

  // The integrity question that is about the tree rather than the snapshot, and
  // so still meaningful in the mode that skips the rest of the check. Warned
  // rather than refused: `GroupingPlanner` plans orphan containers deliberately,
  // and both reading modes hard-fail on one — but freezing their verdicts
  // without a word is how a broken tree gets committed.
  final orphans = _orphanContainers(tree);
  if (orphans.isNotEmpty) {
    stdout.writeln('');
    stdout.writeln('WARNING: ${orphans.length} container(s) have no content '
        'file (${orphans.take(_maxOffendersShown).join(', ')}).');
    stdout.writeln('Their leaves were just frozen, but the site cannot render '
        'a page whose text it');
    stdout.writeln("cannot find — this is the sync workflow's stop-the-line "
        'moment. Sort the tree');
    stdout.writeln('out before committing this file.');
  }
}

/// Keys safe to interpolate into a single-quoted Dart string literal. Every
/// nodeKey in the vendored `tree.json` matches.
final RegExp _dartSafeKey = RegExp(r'^[A-Za-z0-9._-]+$');

/// `6058` → `6,058`. Only ever sees counts, so it need not handle a sign or a
/// fractional part.
String _thousands(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// Where the generated set lives, in the checkout whose corpus was measured.
///
/// Derived from the reader rather than from `Platform.script`, which is what
/// `bin/generate.dart` uses for its own package root. That tool only *reads*;
/// this one writes, and resolving the repo root a second way — by this file's
/// depth below it — is a second answer that can disagree with the first. Run
/// from a different checkout's working directory, the `Platform.script` form
/// would measure one corpus and write the snapshot into another.
///
/// `CorpusReader.discover` has already found the root by looking for
/// `assets/data/tree.json`, so reusing its answer is what guarantees the
/// snapshot lands beside the corpus it describes.
String _snapshotPath(CorpusReader reader) =>
    '${Directory(reader.assetsPath).parent.path}'
    '/packages/wisdom_shared/lib/src/grouping/grouping_snapshot.dart';

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
