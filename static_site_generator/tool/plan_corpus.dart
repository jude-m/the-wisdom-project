import 'dart:io';

import 'package:static_site_generator/data/corpus_reader.dart';
import 'package:static_site_generator/data/slicer_cache.dart';
import 'package:static_site_generator/domain/content_slicer.dart';
import 'package:static_site_generator/domain/coordinate_planner.dart';
import 'package:static_site_generator/domain/grouping_planner.dart';
import 'package:static_site_generator/domain/grouping_policy.dart';
import 'package:static_site_generator/domain/preamble_planner.dart';
import 'package:static_site_generator/domain/slice_alignment.dart';
import 'package:static_site_generator/figures/corpus_figures.dart';
import 'package:static_site_generator/figures/page_budget.dart';
import 'package:wisdom_shared/wisdom_shared.dart';

/// Reports the page budget, checks the frozen snapshot, and regenerates it.
///
///     dart run static_site_generator/tool/plan_corpus.dart
///     dart run static_site_generator/tool/plan_corpus.dart --check
///     dart run static_site_generator/tool/plan_corpus.dart --write-snapshot
///     dart run static_site_generator/tool/plan_corpus.dart --write-figures
///     dart run static_site_generator/tool/plan_corpus.dart --write-upstream
///     dart run static_site_generator/tool/plan_corpus.dart --misaligned
///     dart run static_site_generator/tool/plan_corpus.dart --write-alignment
///     dart run static_site_generator/tool/plan_corpus.dart --redirects > out.csv
///
/// The build no longer measures anything. Two frozen `const`s in
/// `wisdom_shared` are the answers, and `SitePlan.build` reconstructs every
/// page from them: `foldedLeafKeys`, which leaves own a file, and
/// `textBearingContainerKeys`, which container pages carry an introduction and
/// so belong in the reading chain. The rules that *produced* them live in
/// `domain/grouping_planner.dart` (with its per-book exceptions in
/// `domain/grouping_policy.dart`) and `domain/preamble_planner.dart`, and from
/// here on they run only at sync time — as the writers behind
/// `--write-snapshot`, and as the advisors whose disagreements the default
/// report prints.
///
/// **The modes cost very different things.** `--check` reads the tree only
/// (~1 s): its questions are about the shape of the snapshots against the shape
/// of the tree, and none of them needs a character count. The rest re-measure,
/// because the rules do — and the default report walks the corpus *three*
/// times: once for the grouping rule, once for the preamble rule, and once to
/// size the pages it planned. `SlicerCache.parses` is what makes that visible.
///
/// | mode | what it answers | on failure |
/// |---|---|---|
/// | `--check` | is the frozen snapshot still describable by this tree? | exit 1 |
/// | *(none)* | what does the frozen site look like, and where does the rule now disagree? | prints |
/// | `--write-snapshot` | rewrite both frozen sets from their rules | writes |
/// | `--write-figures` | rewrite `CORPUS_FIGURES.md` from the frozen set | writes |
/// | `--write-upstream` | rewrite `UPSTREAM_DEFECTS.md` — what to send back to tipitaka.lk | writes |
/// | `--misaligned` | which leaves still do not hold their own text? | prints |
/// | `--write-alignment` | rewrite the coordinate corrections from their rule | writes |
/// | `--redirects` | where must each folded leaf's own URL send a reader? | prints |
///
/// The two writers are separate commands because they are different acts.
/// `--write-snapshot` moves URLs and its diff needs reviewing sutta by sutta;
/// `--write-figures` only restates what the site already is. A re-sync runs
/// both, snapshots first — the figures describe the site they define.
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
  const modes = {
    '--check',
    '--write-snapshot',
    '--write-figures',
    '--write-upstream',
    '--misaligned',
    '--write-alignment',
    '--redirects',
  };
  final unknown = args.where((a) => !modes.contains(a)).toList();
  if (unknown.isNotEmpty || args.length > 1) {
    stderr.writeln(unknown.isEmpty
        ? 'One mode at a time.'
        : 'Unknown option "${unknown.first}".');
    stderr.writeln('Usage: plan_corpus.dart [--check | --write-snapshot | '
        '--write-figures | --write-upstream | --misaligned | '
        '--write-alignment | --redirects]');
    exitCode = 2;
    return;
  }
  final check = args.contains('--check');

  final reader = CorpusReader.discover();

  // First, and before the corrected tree is even decoded, because this is the
  // one mode that must not read its own output: the defect it measures is by
  // construction invisible once `correctedTreeCoordinates` has been applied, so
  // a run against the corrected tree would find nothing and write an empty map
  // over a good one. Its own slicer cache too — every other mode below shares
  // one built on the corrected tree, and the two trees cut different slices.
  if (args.contains('--write-alignment')) {
    final rawTree = reader.readTree(raw: true);
    final rawCache = SlicerCache(reader: reader, tree: rawTree);
    final List<CoordinateCorrection> corrections;
    try {
      corrections = CoordinatePlanner(
        tree: rawTree,
        slicerFor: rawCache.forFile,
      ).corrections();
    } on CoordinateDerivationFailure catch (error) {
      // The whole run, not the row — see [CoordinateDerivationFailure]. Printed
      // as a refusal rather than a stack trace: it means the corpus changed
      // shape, which is something to go and read, not something to debug.
      stderr.writeln(error.message);
      exitCode = 1;
      return;
    }
    _writeAlignmentSnapshot(_alignmentSnapshotPath(reader), corrections);
    return;
  }

  final tree = reader.readTree();

  // Each mode builds only what it needs, and only this one and the default
  // report need the rule — `--check` asks nothing about text, and reading the
  // whole corpus to not use it would make the one mode meant to run
  // automatically the slowest of them all.
  if (args.contains('--write-snapshot')) {
    final cache = SlicerCache(reader: reader, tree: tree);
    // Grouping first, and the preamble set from a second walk of the same
    // cache. Two questions, two files, one command: they are frozen together
    // because they are read together, and a run that wrote one of them would
    // leave the plan describing a site half-built from each.
    final folded =
        GroupingPlanner(tree: tree, slicerFor: cache.forFile).foldedLeaves();
    final bearing = PreamblePlanner(tree: tree, slicerFor: cache.forFile)
        .textBearingContainers();

    // Both sets clear every refusal before either file is opened. Asking
    // inside the writers ran the same checks in the same order and still let
    // the first file be written and the second refused — which is the
    // half-built state the paragraph above is arranged to make impossible.
    final orderedFolded = _orderedForWriting(tree, folded, 'folded');
    final orderedBearing = _orderedForWriting(tree, bearing, 'text-bearing');
    if (orderedFolded == null || orderedBearing == null) return;

    // Built before anything is written, for two reasons. It proves the sets are
    // *buildable* — `SitePlan.build` throws on each of the three shapes the
    // rule cannot produce, so a snapshot that would break the site never
    // reaches the working tree. And the page count in the header comes from the
    // same walk that will serve it, so the two cannot describe different sites.
    final readable = SitePlan.build(
      tree: tree,
      rootKeys: tree.rootKeys,
      foldedLeafKeys: folded,
      textBearingContainerKeys: bearing,
    ).readablePages.length;

    _writeSnapshot(_snapshotPath(reader), tree, orderedFolded, readable);
    _writePreambleSnapshot(_preambleSnapshotPath(reader), orderedBearing);
    return;
  }

  // The frozen sets, not the rules' — these are what the site actually builds
  // from, so they are what the budget below has to describe.
  const folded = foldedLeafKeys;
  const bearing = textBearingContainerKeys;

  final violations = _integrity(tree, folded, bearing);
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
    textBearingContainerKeys: bearing,
  );

  // After the integrity check for the same reason the plan is built after it:
  // a snapshot this tree cannot produce would be written up as a description of
  // a site nobody can serve.
  if (args.contains('--write-figures')) {
    _writeFigures(_figuresPath(reader), tree, plan, folded, reader);
    return;
  }

  // Its own mode because it is the expensive one: two passes over the corpus,
  // the second unaskable until the first has the list of lines to ask about.
  if (args.contains('--write-upstream')) {
    _writeUpstreamReport(_upstreamReportPath(reader), tree, plan, reader);
    return;
  }

  if (check) {
    if (!_printBudget(tree, plan, folded, parses: null)) exitCode = 1;
    return;
  }

  // Its own mode rather than a block of the default report, for two reasons.
  // It costs a whole extra pass over the corpus, and the answer changes only
  // when upstream text does — so paying for it on every budget run would slow
  // the mode people actually run to print a list that is nearly always the same
  // one. And the list is the point: `FIGURES.misalignedSlices` keys would
  // swamp a report whose other sections are a handful of lines each.
  if (args.contains('--misaligned')) {
    _printMisaligned(
      tree,
      plan,
      SliceAlignment(
        tree: tree,
        slicerFor: SlicerCache(reader: reader, tree: tree).forFile,
      ).misalignedSlices(),
    );
    return;
  }

  // Straight after the plan, because that is all it needs — the mapping is
  // `SitePlan.urlFor` for every folded key and nothing else, so this mode reads
  // no text at all.
  if (args.contains('--redirects')) {
    if (!_printRedirects(plan, folded)) exitCode = 1;
    return;
  }

  // Both passes over the corpus finish before anything is printed, so `files
  // parsed` can report the whole run. `_pageChars` is a *second* pass — the
  // cache holds one file — and a figure printed between the two describes
  // neither, which is what `SlicerCache.parses` exists to make visible.
  final cache = SlicerCache(reader: reader, tree: tree);
  final ruleSays =
      GroupingPlanner(tree: tree, slicerFor: cache.forFile).foldedLeaves();
  final preambleSays = PreamblePlanner(tree: tree, slicerFor: cache.forFile)
      .textBearingContainers();
  final chars = _pageChars(plan, cache);

  if (!_printBudget(tree, plan, folded, parses: cache.parses)) exitCode = 1;
  _printSizes(plan, chars);
  _printSubtrees(tree, plan);
  _reportAdvice(folded, ruleSays);
  _reportPreambleAdvice(bearing, preambleSays);
}

// ---------------------------------------------------------------------------
// The printed report
// ---------------------------------------------------------------------------

/// The page budget, every row of it derived from the frozen set and
/// `SitePlan`'s own walk. Returns whether the derivation identity closed.
///
/// Counted by [PageBudget], which `computeCorpusFigures` also reads — the two
/// reports say the same thing because they share one tally, not because two
/// hand-written loops happen to agree.
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
  final budget = PageBudget.of(tree: tree, plan: plan, folded: folded);

  stdout.writeln('tree              ${tree.length} nodes '
      '(${budget.leaves} leaves, ${budget.containers} containers)');
  stdout.writeln('snapshot          ${budget.foldedLeaves} folded leaves');
  if (parses != null) stdout.writeln('files parsed      $parses');
  // No count of the checks: it can only ever drift from `_integrity`, and once
  // the answer is "none" the number of questions asked tells a reader nothing.
  stdout.writeln('integrity         ok   (no violations)');
  stdout.writeln('');
  stdout.writeln('sutta pages       ${budget.suttaPages}');
  stdout.writeln('chapter pages     ${budget.chapterPages}   '
      '(${budget.wholeVaggaChapters} whole-vagga '
      '+ ${budget.midVaggaChapters} mid-vagga)');
  stdout.writeln('container TOCs    ${budget.containerTocs}   '
      '(${budget.readableTocs} readable, an introduction rather than a '
      'heading)');
  stdout.writeln('root index        ${PageBudget.rootIndex}');
  stdout.writeln('─────────────────────────');
  stdout.writeln('real pages        ${budget.realPages}');
  stdout.writeln('readable pages    ${plan.readablePages.length}   '
      '(the prev/next chain)');
  stdout.writeln('folded leaves     ${budget.foldedLeaves}   '
      '(stubs, if picked)');
  stdout.writeln('with stubs        ${budget.pagesWithStubs}   (cap 20,000)');

  // The derivation from Part 1's Impact table. Two fixed corpus totals decide
  // both moving rows, so an arithmetic mismatch here means the walk and the
  // snapshot disagree about what folded — the cheapest check that a measurement
  // is self-consistent, and the one that caught an earlier draft's mixed table.
  final holds = budget.derivationHolds;
  final derivedSutta = budget.derivedSuttaPages;
  final derivedToc = budget.derivedContainerTocs;
  stdout.writeln('');
  stdout.writeln('derivation        '
      'sutta ${derivedSutta == budget.suttaPages ? 'ok' : 'MISMATCH $derivedSutta'} · '
      'toc ${derivedToc == budget.containerTocs ? 'ok' : 'MISMATCH $derivedToc'}');
  if (!holds) {
    // Exits non-zero rather than only printing, because `--check` is the mode
    // that runs unattended and this is the one thing left that it alone can
    // catch. Every shape [_integrity] covers has already passed by the time we
    // are here, so what remains is a node no root can reach — a parent cycle in
    // a re-synced tree.json, which nothing else in the pipeline would notice.
    stdout.writeln('');
    stdout
        .writeln('The tree holds leaves the walk never reached. The integrity '
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

/// `source,target` for every folded leaf — the URL it would own against the URL
/// that actually serves it. Returns whether every row resolved.
///
/// **The half both answers to the P5 gate need.** A folded leaf owns no file, so
/// something has to answer at `/tipitaka/<leafKey>`: either a stub HTML file at
/// that path or a Cloudflare Bulk Redirect rule. The *mechanism* is deferred
/// (2026-08-19) and the *mapping* is not — it is the same list either way, so
/// switching later is a re-upload rather than a rebuild.
///
/// Mechanism-neutral on purpose, which is why it carries two columns and not
/// Cloudflare's upload schema. Bulk Redirects wants absolute sources and a
/// status column, and the apex domain is exactly what is not settled yet (see
/// [htmlDocument] on the canonical); a stub generator wants neither. Prefixing
/// a host and appending `,301` is a line of `awk` at upload time, against a
/// file that would otherwise have to be regenerated when the domain lands.
///
/// To **stdout**, not a path: this is deploy-time material and not part of the
/// site, and the one place it must never end up is `build/`, where Pages would
/// serve it. `> somewhere.csv` is the whole interface.
///
/// No quoting anywhere, and none needed: a nodeKey is lowercase letters, digits
/// and hyphens, so neither column can contain a comma, a quote or a newline.
bool _printRedirects(SitePlan plan, Set<String> folded) {
  // Walk order rather than the set's, so the file diffs like the snapshot does
  // — a book's rows stay contiguous, and a regeneration that moves one URL
  // shows as one line.
  final stranded = <String>[];
  final rows = StringBuffer();
  var emitted = 0;
  for (final page in plan.pages) {
    for (final leaf in page.suttas) {
      if (!folded.contains(leaf.nodeKey)) continue;
      final source = tipitakaUrl(leaf.nodeKey);
      final target = plan.urlFor(leaf.nodeKey);
      // Identity means the plan has no chapter serving this leaf, so the row
      // would redirect a URL to itself — a loop at the edge, or a stub file
      // pointing at the address it sits on. `SitePlan.build` already refuses
      // the shapes that cause it; this is the cheap proof for the one mode
      // whose whole output is that resolution.
      if (target == source) {
        stranded.add(leaf.nodeKey);
        continue;
      }
      rows.writeln('$source,$target');
      emitted++;
    }
  }

  if (stranded.isNotEmpty) {
    stderr.writeln('${stranded.length} folded leaves resolve to their own URL, '
        'so no page serves them: ${stranded.take(_maxOffendersShown).join(', ')}'
        '${stranded.length > _maxOffendersShown ? ', …' : ''}');
    return false;
  }

  // The walk is over pages, and the file is claimed to be one row per folded
  // leaf — so a folded key that reaches no page's `suttas` would leave the CSV
  // quietly short rather than wrong. `_integrity` makes that hard to arrange
  // and nothing in the corpus does it, but this is a deploy artifact: the whole
  // point of it is that a reader lands somewhere, and a missing row is a leaf
  // that lands nowhere. Counting is free where re-deriving the set is not.
  if (emitted != folded.length) {
    stderr.writeln('${folded.length} folded leaves, but only $emitted rows: '
        '${folded.length - emitted} of them sit on no page at all. '
        'Run --check before trusting this file.');
    return false;
  }

  stdout.write('source,target\n');
  stdout.write(rows.toString());
  return true;
}

/// Every leaf whose slice does not hold its own text, and the page serving it.
///
/// **Asked of the corrected tree**, so what it lists is what
/// `correctedTreeCoordinates` does not reach. That is the useful question after
/// a re-sync: a colophon row reappearing here means the correction has stopped
/// covering the defect and `--write-alignment` needs re-running against the new
/// asset.
///
/// Grouped by content file, because that is how the defect arrives: BJT prints
/// a book's section names one way throughout, so a bad file is bad in bulk.
///
/// The serving URL is the actionable half. A leaf that owns its page shows the
/// defect as a whole page under the wrong title; a folded one shows it as a
/// `#fragment` landing one sutta early inside a chapter that is itself
/// complete and in order. Same cause, two things to look at, and the reader
/// has to be told which — [SitePlan.urlFor] is the only thing that knows.
///
/// Prints and exits 0. What survives the correction is not fixable the same
/// way: a stray divider is one row out rather than one unit, and an empty leaf
/// may be a bare heading upstream really printed. Both want reading before
/// anything moves (see [SliceAlignment]).
void _printMisaligned(
  TipitakaTree tree,
  SitePlan plan,
  Map<String, SliceMisalignment> misaligned,
) {
  // Tags are padded at the print sites, not here. A column width belongs to the
  // column, and baking it into the data means the next value added to
  // [SliceMisalignment] silently prints out of line.
  const shapes = {
    SliceMisalignment.trailingColophon: (
      tag: 'colophon',
      note: "the leaf's own name, printed after the text it names — "
          'the page below it is the next leaf',
    ),
    SliceMisalignment.strayDivider: (
      tag: 'divider',
      note: 'a recitation marker closing the division above — one stray row',
    ),
    SliceMisalignment.strandedLeadingNumber: (
      tag: 'stranded',
      note: "the leaf's own leading number left at the foot of its slice — "
          'the page above it is the previous leaf',
    ),
    SliceMisalignment.headingOnlyLeaf: (
      tag: 'heading',
      note: 'NOT a defect — the leaf is where it should be and the book has '
          'no body under that heading',
    ),
  };
  final tagWidth =
      shapes.values.map((s) => s.tag.length).reduce((a, b) => a > b ? a : b);

  // The two totals are printed apart because they mean different things. The
  // first is a bug count and should read 0; the second is a fact about the
  // book, and reading 0 would only mean upstream had changed.
  final defects = misaligned.values.where(SliceAlignment.isDefect).length;
  stdout.writeln('misaligned leaves  ${defects.toString().padLeft(4)}   '
      'slices not holding the text the leaf is named for — expect 0');
  stdout.writeln('heading-only       '
      '${(misaligned.length - defects).toString().padLeft(4)}   '
      'correct, and carrying no body because the book prints none');
  stdout.writeln('');
  for (final shape in SliceMisalignment.values) {
    final count = misaligned.values.where((v) => v == shape).length;
    stdout.writeln('  ${shapes[shape]!.tag.padRight(tagWidth)}  '
        '${count.toString().padLeft(4)}   ${shapes[shape]!.note}');
  }
  if (misaligned.isEmpty) return;

  final byFile = <String, List<String>>{};
  for (final key in misaligned.keys) {
    // The file the *slice* was cut from, which is the file printed wrong.
    final fileId = tree[key]?.contentFileId ?? '(no content file)';
    (byFile[fileId] ??= <String>[]).add(key);
  }

  for (final entry in byFile.entries) {
    stdout.writeln('');
    stdout.writeln('${entry.key}   ${entry.value.length}');
    for (final key in entry.value) {
      stdout.writeln('  ${key.padRight(22)} '
          '${shapes[misaligned[key]]!.tag.padRight(tagWidth)}  '
          '${plan.urlFor(key)}');
    }
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
/// wholesale renumbering reports as a diagnosis rather than one line per leaf.
List<String> _integrity(
  TipitakaTree tree,
  Set<String> folded,
  Set<String> bearing,
) {
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
  report(
      'containers of folded leaves that now span content files', splitParents);

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

  // 4. Every text-bearing key still names a container. A key that vanished, or
  //    that is now a leaf, would put a page in the reading chain that the walk
  //    never emits as a TOC — silently, because `SitePlan.build` only ever
  //    reads the set through `contains`.
  final bearingMissing = <String>[];
  final bearingLeaves = <String>[];
  for (final key in bearing) {
    final node = tree[key];
    if (node == null) {
      bearingMissing.add(key);
    } else if (node.isLeaf) {
      bearingLeaves.add(key);
    }
  }
  report('text-bearing keys no longer in the tree', bearingMissing);
  report('text-bearing keys that are now leaves', bearingLeaves);

  // 5. Orphan containers — the one question here that is about the tree rather
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
void _reportAdvice(Set<String> folded, Set<String> ruleSays) => _printAdvice(
      label: 'advisor',
      frozen: folded,
      ruleSays: ruleSays,
      proposals: 'leaves the rule would now fold (they own a page today)',
      disagreements: 'folded leaves the rule would now explode (snapshot wins)',
      footer: 'Neither is acted on. Moving a URL is `--write-snapshot` plus a '
          'review of its diff.',
    );

/// The preamble rule's opinion against its frozen set.
///
/// Cheaper to act on than the grouping advisor's, and worth reading first after
/// a re-sync: nothing here moves a URL, so a proposal is a container that has
/// gained an introduction upstream and is currently serving it as navigation.
/// That is the exact defect the set was introduced to end, and it re-appears
/// silently — the page still renders, still links, still looks finished.
void _reportPreambleAdvice(Set<String> bearing, Set<String> ruleSays) =>
    _printAdvice(
      label: 'preamble advisor',
      frozen: bearing,
      ruleSays: ruleSays,
      proposals:
          'containers now carrying running text (served as navigation today)',
      disagreements: 'frozen containers whose text is gone (snapshot wins)',
      footer: 'Neither is acted on. `--write-snapshot` regenerates both sets; '
          'no URL moves.',
    );

/// Both advisors, printed the same way: the two directions, their counts, and
/// up to [_maxOffendersShown] keys each.
///
/// [label] is the only column that varies — everything after it is the same
/// sentence about a different set, which is what makes the two blocks readable
/// as one report rather than two.
void _printAdvice({
  required String label,
  required Set<String> frozen,
  required Set<String> ruleSays,
  required String proposals,
  required String disagreements,
  required String footer,
}) {
  final proposed = ruleSays.difference(frozen).toList();
  final disagreed = frozen.difference(ruleSays).toList();

  stdout.writeln('');
  stdout.writeln('${label.padRight(18)}the rule re-run against the frozen set');
  stdout.writeln('  proposals       ${proposed.length}   $proposals');
  stdout.writeln('  disagreements   ${disagreed.length}   $disagreements');
  if (proposed.isEmpty && disagreed.isEmpty) {
    stdout.writeln('  nothing to review — the frozen set is what the rule '
        'says today.');
    return;
  }
  for (final entry in [
    ('  + ', proposed),
    ('  − ', disagreed),
  ]) {
    for (final key in entry.$2.take(_maxOffendersShown)) {
      stdout.writeln('${entry.$1}$key');
    }
    final rest = entry.$2.length - _maxOffendersShown;
    if (rest > 0) stdout.writeln('${entry.$1}… +$rest more');
  }
  stdout.writeln('  $footer');
}

// ---------------------------------------------------------------------------
// The snapshot writer
// ---------------------------------------------------------------------------

/// Keys safe to interpolate into a single-quoted Dart string literal. Every
/// nodeKey in the vendored `tree.json` matches.
final RegExp _dartSafeKey = RegExp(r'^[A-Za-z0-9._-]+$');

/// The keys of one snapshot in reading order, or null when it must not be
/// written at all.
///
/// **Reading order, one key per line.** The order is the site's own walk, so a
/// book's keys land in one contiguous block and the file reads as a document
/// rather than an index; one key per line is what makes the git diff the impact
/// review the plan doc promises — every added or removed line is exactly one
/// node whose page changed. Nothing here varies per run (no timestamp, no build
/// id), so regenerating an unchanged corpus rewrites identical bytes (§11.8).
///
/// Both refusals are about the *file* rather than the site, and both are
/// returned rather than acted on: the caller asks this of every snapshot before
/// it writes any of them, so one bad set stops the whole command instead of
/// leaving the pair describing two different corpora.
///
/// [noun] names the keys in those two messages — "folded", "text-bearing".
List<String>? _orderedForWriting(
  TipitakaTree tree,
  Set<String> keys,
  String noun,
) {
  final ordered = <String>[];
  void walk(TipitakaNode node) {
    if (keys.contains(node.nodeKey)) ordered.add(node.nodeKey);
    for (final child in tree.childrenOf(node.nodeKey)) {
      walk(child);
    }
  }

  for (final root in tree.roots) {
    walk(root);
  }
  // Only reachable if a key sits outside every root, which the tree's own
  // parent check already rules out. Loud rather than silently short.
  if (ordered.length != keys.length) {
    stderr.writeln('${keys.length - ordered.length} $noun key(s) are not '
        'reachable from any root. Refusing to write a partial snapshot.');
    exitCode = 1;
    return null;
  }

  // Every key is interpolated into a single-quoted Dart literal below, so one
  // carrying a quote, a backslash or a `$` would emit a file that does not
  // compile — or, with `$`, one that compiles and means something else. Every
  // key in the vendored tree is safe; upstream is not bound by that, and
  // absorbing re-syncs is the whole reason these files exist.
  final unsafe = ordered.where((key) => !_dartSafeKey.hasMatch(key)).toList();
  if (unsafe.isNotEmpty) {
    stderr.writeln('${unsafe.length} nodeKey(s) cannot be written as a Dart '
        'literal: ${unsafe.take(_maxOffendersShown).join(', ')}');
    stderr.writeln('Refusing to write a file that would break every package '
        'importing it. Add escaping here first.');
    exitCode = 1;
    return null;
  }
  return ordered;
}

/// Rewrites `tree_coordinate_corrections.dart` from one full-corpus run of the
/// rule, against the **raw** tree.
///
/// One line per leaf whose text moves, in reading order, each carrying the
/// coordinate it came from and the row it now opens on. The `from` and the
/// printed text are comments rather than data: nothing reads them, and they are
/// the whole review — a diff line saying only `(page: 12, entry: 4)` cannot be
/// checked against anything, where one that also says it moved off
/// `පඨමසික්ඛාපදං.` and onto `8. 1. 1.` can be read straight.
void _writeAlignmentSnapshot(
    String path, List<CoordinateCorrection> corrections) {
  final buffer = StringBuffer('''
// GENERATED by `dart run static_site_generator/tool/plan_corpus.dart
// --write-alignment`. Change the rule
// (`static_site_generator/lib/domain/coordinate_planner.dart`) and regenerate
// rather than hand-editing.

/// Leaves whose `tree.json` coordinate points at the wrong row, and the row it
/// should point at — ${corrections.length} of them, frozen from one full-corpus
/// run of the rule.
///
/// ## What is wrong upstream
///
/// A node's coordinate is the `[pageIndex, entryIndexInPage]` where its text
/// **begins**, and every slice in the corpus is cut from one coordinate to the
/// next. For the leaves named here upstream put it somewhere else, in one of
/// three shapes:
///
/// - **One unit late.** BJT prints some section names as a *colophon*, after
///   the text they name, and upstream took that closing line for the opening
///   one. The slice opens on one unit's name and runs through the *next*
///   unit's body.
/// - **One unit early.** Elsewhere the coordinate sits on the body *above* the
///   number that should have opened the leaf, so the leaf's own number is
///   stranded at the foot of its slice and the page carries its title over the
///   section before it.
/// - **One row late.** A `භාණවාරං` recitation marker closes the division above
///   and lands at the top of the next leaf's slice, one stray row over text
///   that is otherwise the leaf's own.
///
/// In each the page carries the right title over the wrong text, and its
/// `#fragment` lands off its own opening: a page that is wrong without looking
/// wrong, which is why it survived every count, link check and byte-diff the
/// build does.
///
/// `SliceAlignment` is the detector; this is the correction. They are kept
/// apart on purpose — the detector is asked of whatever tree is loaded, so
/// running it *after* this map is applied is what proves the correction still
/// covers the defect rather than merely having covered it once.
///
/// ## Why a map and not an edit
///
/// `assets/data/tree.json` is vendored from tipitaka.lk with no provenance, and
/// the next re-sync overwrites it. A hand-edit there is a fix that silently
/// disappears; a `const` here is code, survives the re-sync, and its git diff
/// is the review — one line per leaf whose text moves. It also reaches both
/// surfaces from one place, which a per-app patch could not.
///
/// **It moves text, not URLs.** Nothing here changes which pages exist or what
/// they are called. Both other snapshots are *measured* from the corrected tree
/// and so must be regenerated after this file changes — a container whose
/// preamble was holding a swallowed body stops being an introduction once the
/// body goes back to the leaf that owns it.
///
/// **The defect is upstream's and the correction should be too.** This map is
/// the local answer while the report is open; if tipitaka.lk fixes the
/// coordinates, regenerating writes an empty map and nothing else changes.
///
/// The count above is the only corpus figure written here, and it is
/// interpolated by the writer rather than typed. Every other one lives in
/// `static_site_generator/CORPUS_FIGURES.md`.
///
/// See `docs/todo/web-strategy/reading-units-and-grouping.md` — B5.
const Map<String, ({int page, int entry})> correctedTreeCoordinates = {
''');
  for (final c in corrections) {
    buffer.writeln('  // was (page: ${c.from.page}, entry: ${c.from.entry}), '
        'now opens on "${c.openingRow}"');
    buffer.writeln(
        "  '${c.nodeKey}': (page: ${c.to.page}, entry: ${c.to.entry}),");
  }
  buffer.writeln('};');

  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(buffer.toString());
}

/// Where the frozen coordinate corrections live, beside the tree they correct.
String _alignmentSnapshotPath(CorpusReader reader) => '${_repoRoot(reader)}'
    '/packages/wisdom_shared/lib/src/tree/tree_coordinate_corrections.dart';

/// Writes one snapshot: [header], then [ordered] one key per line, then `};`.
void _writeKeys(String path, String header, List<String> ordered) {
  final buffer = StringBuffer(header);
  for (final key in ordered) {
    buffer.writeln("  '$key',");
  }
  buffer.writeln('};');

  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(buffer.toString());
}

/// Rewrites `grouping_snapshot.dart` from one full-corpus run of the rule.
///
/// [ordered] has already cleared [_orderedForWriting], and [readable] is the
/// page count of the plan it was proved to build — the header states both, and
/// they come from the same run that will serve them.
void _writeSnapshot(
  String path,
  TipitakaTree tree,
  List<String> ordered,
  int readable,
) {
  _writeKeys(
      path,
      '''
// GENERATED by `dart run static_site_generator/tool/plan_corpus.dart
// --write-snapshot`. Hand-editing it moves URLs with no review behind them —
// change the rule (`static_site_generator/lib/domain/grouping_policy.dart`)
// and regenerate instead.

/// Every leaf that does **not** get its own page — ${formatCount(ordered.length)} of them, frozen
/// from one full-corpus run of the split rule.
///
/// **A leaf absent from this set owns its URL.** That is the safe direction:
/// new content self-handles, a wrong explode costs one thin page, and only a
/// wrong fold could hide a named text behind a fragment.
///
/// Nothing re-measures the rule. `SitePlan.build` reconstructs all ${formatCount(readable)}
/// readable pages from this set alone, so a re-sync of `assets/` may change
/// what a page *says* and never which pages *exist*. Regenerating is the
/// supported way to move a line, and the git diff of this file is the impact
/// review: one line per sutta whose URL moved.
///
/// Generated code rather than a bundled asset, because the app reads the same
/// verdicts and may gain no new asset file — one `const` compiles into both
/// surfaces from one place. Written in reading order.
///
/// The two counts above are the only corpus figures written here, and they are
/// interpolated by the writer rather than typed. Every other one lives in
/// `static_site_generator/CORPUS_FIGURES.md`.
///
/// See `docs/todo/web-strategy/reading-units-and-grouping.md` — Part 2.
const Set<String> foldedLeafKeys = {
''',
      ordered);

  // What this run was *compiled* against, which is the committed file's
  // contents — Dart resolved the import before any of this ran, so reading the
  // file back off disk would only re-parse the same answer.
  const before = foldedLeafKeys;
  final now = ordered.toSet();
  final added = now.difference(before).length;
  final removed = before.difference(now).length;
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

/// Rewrites `preamble_snapshot.dart` — which containers open with an
/// introduction rather than a heading.
///
/// A separate file from `grouping_snapshot.dart`, and the separation is the
/// point: the two diffs mean different things. A line moving there is a sutta
/// changing address, which needs a redirect thought about; a line moving here
/// is a container page gaining or losing its layout switcher and its place in
/// prev/next, at an address that does not change. Reviewing them as one diff
/// would make the cheap changes look like the expensive ones.
///
/// Written together all the same, from one command and one validation pass —
/// see [_orderedForWriting].
void _writePreambleSnapshot(String path, List<String> ordered) {
  _writeKeys(
      path,
      '''
// GENERATED by `dart run static_site_generator/tool/plan_corpus.dart
// --write-snapshot`. Change the rule
// (`static_site_generator/lib/domain/preamble_planner.dart`) and regenerate
// rather than hand-editing.

/// Every container whose preamble is the book's introduction to the chapter
/// rather than its title — ${formatCount(ordered.length)} of them, frozen from one full-corpus
/// run of the rule.
///
/// A container's page is normally pure navigation: no layout switcher, no
/// prev/next, and a column sized for link rows. For the containers named here
/// that would serve running text as if it were a menu, so they are **readable**
/// instead — `SitePage.isReadable` is this set unioned with every sutta and
/// chapter page.
///
/// **A superset of the pages it changes, deliberately.** Some of these
/// containers are already whole-vagga chapters, which are readable whatever
/// their preamble holds, so their key does nothing today.
/// `FIGURES.readableContainerTocs` is the count that is actually load-bearing.
/// Naming them anyway is what keeps the two snapshots orthogonal: this one
/// answers "does this container own text", `foldedLeafKeys` answers "which
/// pages exist", and neither has to be correct for the other to be. A grouping
/// change that turns a chapter back into a TOC then finds the answer already
/// here, rather than serving an introduction as a menu until someone notices.
///
/// **An absent key means "not readable".** That is the safe direction here, and
/// it is the opposite of `foldedLeafKeys`: a container that gains an
/// introduction upstream keeps the page it has until someone regenerates, where
/// the opposite default would drop a bare link list into the reading chain that
/// every reader walking prev/next would meet. Neither direction moves a URL —
/// nothing in this file decides which pages *exist*.
///
/// Generated code rather than a bundled asset, for the same reason as
/// `foldedLeafKeys`: one `const` compiles into both surfaces from one place.
/// Written in reading order.
///
/// The count above is the only corpus figure written here, and it is
/// interpolated by the writer rather than typed. Every other one lives in
/// `static_site_generator/CORPUS_FIGURES.md`.
///
/// See `docs/todo/web-strategy/reading-units-and-grouping.md`.
const Set<String> textBearingContainerKeys = {
''',
      ordered);

  const before = textBearingContainerKeys;
  final now = ordered.toSet();
  final added = now.difference(before).length;
  final removed = before.difference(now).length;
  stdout.writeln('wrote             $path');
  stdout.writeln('text-bearing      ${ordered.length} containers');
  stdout.writeln('diff              +$added / −$removed against the set this '
      'run was compiled with');
  if (added != 0 || removed != 0) {
    stdout.writeln('');
    stdout.writeln('That is ${added + removed} container page(s) entering or '
        'leaving the reading chain.');
    stdout.writeln('No URL moves. Review `git diff` on the snapshot.');
  }
}

// ---------------------------------------------------------------------------
// The figures writer
// ---------------------------------------------------------------------------

/// Rewrites `CORPUS_FIGURES.md` — the one place a corpus count is written down.
///
/// Every literal that used to sit in a doc comment lives there now, cited by
/// name. This mode is what keeps the citations honest: it is the only writer,
/// and it derives all of them in one pass, so they cannot disagree with each
/// other the way ~45 hand-maintained copies did.
///
/// Prints the counts it wrote rather than only the path. The mode exists to
/// answer "what is the site now", and making the operator open a file to find
/// out would be a worse report than the default one.
void _writeFigures(
  String path,
  TipitakaTree tree,
  SitePlan plan,
  Set<String> folded,
  CorpusReader reader,
) {
  final groups = computeCorpusFigures(
    tree: tree,
    plan: plan,
    folded: folded,
    reader: reader,
  );
  File(path).writeAsStringSync(renderCorpusFigures(groups));

  stdout.writeln('wrote             $path');
  for (final group in groups) {
    stdout.writeln('');
    stdout.writeln(group.title);
    for (final figure in group.figures) {
      stdout.writeln('  ${figure.name.padRight(34)}${figure.value}');
    }
  }
  stdout.writeln('');
  stdout.writeln('Review `git diff` on the file. Nothing fails when these '
      'move — new upstream');
  stdout.writeln('content should move them — but a comment citing a figure '
      'that is no longer');
  stdout.writeln('listed is a citation to fix.');
}

/// One cell of a preamble, as the report prints it.
typedef _PreambleCell = ({String side, String type, String text});

/// One container whose preamble carries body text but not enough of it.
typedef _FormulaContainer = ({
  String fileId,
  int page,
  int entry,
  int chars,
  bool servesAPage,
  List<_PreambleCell> cells,
});

/// Rewrites `UPSTREAM_DEFECTS.md` — the containers whose "introduction" is one
/// printed line, and what those same lines are typed elsewhere in the corpus.
///
/// **The hand-off artefact for a report to tipitaka.lk**, and the reason a page
/// is navigation written down rather than inferred from a key's absence from
/// `textBearingContainerKeys`. Generated for the same reason
/// `correctedTreeCoordinates` is: a hand-typed table describes the corpus of
/// the day it was typed, and the next re-sync silently outdates it. Regenerate
/// and read the diff.
///
/// What each of the report's three sections is for is written in its own
/// header, which is where the reader deciding what to send upstream will be.
void _writeUpstreamReport(
  String path,
  TipitakaTree tree,
  SitePlan plan,
  CorpusReader reader,
) {
  PreamblePlanner.assertTypesPartitioned();

  final cache = SlicerCache(reader: reader, tree: tree);
  final planner = PreamblePlanner(tree: tree, slicerFor: cache.forFile);
  final tocPages = {
    for (final page in plan.pages)
      if (page.kind == PageKind.toc) page.nodeKey,
  };

  // Pass 1: size every container, and keep the rows of the ones the floor
  // rejects. Sizes are kept for *all* of them because §3 compares siblings,
  // and a sibling that clears the floor is exactly the comparison worth
  // printing.
  final chars = <String, int>{};
  final formulas = <String, _FormulaContainer>{};
  ContentSlicer.containersByFile(tree).forEach((fileId, containers) {
    final slicer = cache.forFile(fileId);
    for (final container in containers) {
      final size = planner.runningTextChars(container, slicer);
      chars[container.nodeKey] = size;
      if (size == 0 || size >= PreamblePlanner.minIntroductionChars) continue;
      final cells = <_PreambleCell>[];
      for (final row in slicer.sliceFor(container.nodeKey).rows) {
        final sides = [('pali', row.pali), ('sinh', row.sinhala)];
        for (final (side, entry) in sides) {
          if (entry == null || entry.text.isEmpty) continue;
          cells.add((side: side, type: entry.type, text: entry.text));
        }
      }
      formulas[container.nodeKey] = (
        fileId: fileId,
        page: container.entryPageIndex,
        entry: container.entryIndexInPage,
        chars: size,
        servesAPage: tocPages.contains(container.nodeKey),
        cells: cells,
      );
    }
  });

  final ordered = _orderedForWriting(tree, formulas.keys.toSet(), 'formula');
  if (ordered == null) return;

  // Pass 2: what the corpus types those same lines. Only the body cells are
  // asked about — a heading typed as a heading everywhere is not the question.
  //
  // Straight through the reader rather than the slicer cache: nothing here
  // needs a slice, and running it through the cache would evict the parsed
  // files pass 1 is done with for no gain.
  final wanted = <String>{
    for (final key in ordered)
      for (final cell in formulas[key]!.cells)
        if (PreamblePlanner.runningTextTypes.contains(cell.type)) cell.text,
  };
  final typedAs = {for (final text in wanted) text: <String, int>{}};
  for (final fileId in ContentSlicer.nodesByFile(tree).keys) {
    final file = reader.readContentFile(fileId);
    for (final page in file.pages) {
      for (var i = 0; i < page.entryCount; i++) {
        for (final entry in [page.paliAt(i), page.sinhalaAt(i)]) {
          if (entry == null) continue;
          final counts = typedAs[entry.text];
          if (counts == null) continue;
          counts[entry.type] = (counts[entry.type] ?? 0) + 1;
        }
      }
    }
  }

  File(path).writeAsStringSync(
    _renderUpstreamReport(tree, ordered, formulas, typedAs, chars),
  );

  final inconsistent = typedAs.values.where((c) => c.length > 1).length;
  stdout.writeln('wrote             $path');
  stdout.writeln('');
  final serving = formulas.values.where((f) => f.servesAPage).length;
  stdout.writeln('formula containers    ${formulas.length}   '
      '($serving serve a page today)');
  stdout.writeln('distinct lines        ${wanted.length}');
  stdout.writeln('typed two ways        $inconsistent   '
      '(verbatim matches only — §3 is where a formula that varies by a word '
      'shows up)');
}

String _renderUpstreamReport(
  TipitakaTree tree,
  List<String> ordered,
  Map<String, _FormulaContainer> formulas,
  Map<String, Map<String, int>> typedAs,
  Map<String, int> chars,
) {
  // Newlines and pipes both end a markdown table cell early, and the corpus is
  // vendored: a `gatha` carries the first today and upstream may add the second
  // tomorrow.
  String cell(String text) =>
      text.replaceAll('|', r'\|').replaceAll('\n', ' / ');

  final out = StringBuffer()..write('''
<!-- GENERATED by `dart run static_site_generator/tool/plan_corpus.dart --write-upstream`.
     Do not hand-edit — regenerate and review the diff. -->

# Upstream defects

**§1–§3 are one defect class and §4 is another.** §1–§3 are about *entry
types*: containers whose introduction is one printed line, and what that same
line is typed as elsewhere. §4 is about *keys*: commentary nodes filed under
the wrong sutta's number, which is the one defect here a reader meets as wrong
text rather than as a page that reads a little differently.

Every container in §1 opens with body text too short to be the book's introduction
to the chapter — one printed line, typically a formula, an announcement or a
bracketed elision marker. `PreamblePlanner` declines them, so their pages are
navigation rather than reading stops. **None of them loses text:** a container
page prints its preamble whether or not it is readable, so every line below is
still on its container's own page, at its own URL, linked from the list above it.
What those pages lose is the pager, the layout switcher, the column captions and
the reading measure. (The site's search indexes names, never body text, so no
line here was ever in it.)

**§2 and §3 are the parts of the first class to send upstream, and they catch
different things.**
§2 tallies each line against the corpus verbatim, so it finds a defect only where
the wording repeats exactly. A formula that varies by a word — the number of
rules in a section of the pātimokkha, the name of a sutta — is invisible to it, and
that is the class §3 exists for: the same line, typed one way under one parent and
another way under its sibling, shows up there as a column of sizes with a zero in
it. A line typed one way everywhere and matched by neither is not a defect at
all, however much it trips our rule — re-typing it upstream would change nothing.

Counts and keys in this file are generated. Prose elsewhere cites them from here
or from `CORPUS_FIGURES.md`, never by hand.

## 1. Containers whose preamble is a formula

''');

  for (final key in ordered) {
    final formula = formulas[key]!;
    out
      ..writeln('### `$key` — ${formatCount(formula.chars)} characters'
          '${formula.servesAPage ? '' : ' (folded into a chapter; inert)'}')
      ..writeln('')
      ..writeln('${tipitakaUrl(key)} · `assets/text/${formula.fileId}.json` '
          'page ${formula.page}, entry ${formula.entry}')
      ..writeln('')
      ..writeln('| side | type | text |')
      ..writeln('|---|---|---|');
    for (final c in formula.cells) {
      final body = PreamblePlanner.runningTextTypes.contains(c.type);
      out.writeln('| ${c.side} | ${body ? '**${c.type}**' : c.type} '
          '| ${cell(c.text)} |');
    }
    out.writeln('');
  }

  out.write('''
## 2. What those lines are typed elsewhere

Body cells only, counted across every content file the tree references. **Bold**
rows carry more than one type and are upstream's to fix.

| line | typed as |
|---|---|
''');
  // Sorted by the text itself: the map is built from a set and §11.8 wants the
  // same bytes from the same corpus however the set iterates.
  final lines = typedAs.keys.toList()..sort();
  for (final text in lines) {
    final counts = typedAs[text]!;
    final types = counts.keys.toList()..sort();
    final rendered = [
      for (final type in types) '$type ×${formatCount(counts[type]!)}',
    ].join(' · ');
    final split = counts.length > 1;
    out.writeln('| ${cell(text)} | ${split ? '**$rendered**' : rendered} |');
  }

  out.write('''

## 3. The same question, asked of the siblings

Running-text characters in each container preamble under a parent that has at
least one of §1 below it. A section typed unlike the ones beside it shows up
here as a column with an outlier in it.

''');

  // A `Set` literal keeps insertion order, so this is the reading order of §1
  // with the duplicates dropped.
  final parents = <String>{
    for (final key in ordered)
      if (tree[key]?.parentNodeKey case final parent?) parent,
  };
  for (final parent in parents) {
    out
      ..writeln('### under `$parent`')
      ..writeln('')
      ..writeln('| container | characters |')
      ..writeln('|---|---|');
    for (final child in tree.childrenOf(parent)) {
      if (child.isLeaf) continue;
      final size = chars[child.nodeKey];
      if (size == null) continue;
      final flagged = formulas.containsKey(child.nodeKey);
      out.writeln(
          '| ${flagged ? '**`${child.nodeKey}`**' : '`${child.nodeKey}`'}'
          ' | ${formatCount(size)} |');
    }
    out.writeln('');
  }

  out.write('''
## 4. Commentary keys that drift from the canon

A vaṇṇanā's key is the canon sutta it treats — `atta-sn-2-5-4-2` is the
commentary on `sn-2-5-4-2`. That is what makes the අට්ඨකථා link a prefix flip,
and `crossLinkTargetKey` trusts it: an exact twin key always wins.

Below, it is not true. Each row is a commentary node whose title is typed
*identically* to a canon sutta at a **different** index in the matching
container — the same name, one key out. Anything that shifts one side against
the other does it: a vaṇṇanā that swallows a sutta without declaring the range,
an extra leading node on the commentary side. However it arose, every key from
there on names the vaṇṇanā of the sutta before it.

**The reader sees a commentary on the wrong sutta**, on both surfaces, and no
rule here can catch it: the wrong answer is a key that exists, and it is
indistinguishable from a correct one. Fixing it means renumbering the
commentary keys upstream, or declaring the merge in the title the way the rest
of the corpus does.

Both languages have to disagree before a row is filed. A Pali-only mismatch is
the *canon* side mislabelled — `an-2-3-12` prints two suttas as "2. 3. 12. 6"
and every Pali label after it slides by one, while the Sinhala labels and the
commentary keys stay correct. That is a defect, but a different one, and it
belongs to §1–§3's family rather than here.

Detected by exact title equality only, so this is a floor and not a census —
a skip whose two sides are worded differently does not appear.

''');

  // Normalised titles that occur once in a container are the only ones that can
  // identify a node: a vagga printing the same sutta name twice would otherwise
  // pair its second copy with the first at random.
  String flatten(String text) => text.replaceAll(RegExp(r'[\s‍]'), '');
  final driftOut = StringBuffer();
  for (final container in tree.allNodes) {
    if (container.isCommentary || container.isLeaf) continue;
    final commentary = tree[twinKeyOf(container.nodeKey)];
    if (commentary == null) continue;

    final canonAt = <String, int>{};
    final ambiguous = <String>{};
    final canonChildren = tree.childrenOf(container.nodeKey);
    for (var i = 0; i < canonChildren.length; i++) {
      if (!canonChildren[i].isLeaf) continue;
      final title = flatten(canonChildren[i].paliName);
      if (canonAt.containsKey(title)) ambiguous.add(title);
      canonAt[title] = i;
    }

    // Compared by *key*, never by position in the child list: a container whose
    // commentary has fewer nodes than the canon has suttas shifts every later
    // position by the difference, and a node correctly keyed `-10` sits at
    // position 8 on one side and 9 on the other. The claim being tested is
    // about the key alone — "this node is filed under a sutta it does not
    // treat" — so the position is not evidence either way.
    final rows = <String>[];
    final commentaryChildren = tree.childrenOf(commentary.nodeKey);
    for (final child in commentaryChildren) {
      if (!child.isLeaf) continue;
      final title = flatten(child.paliName);
      if (ambiguous.contains(title)) continue;
      final i = canonAt[title];
      if (i == null) continue;
      final filedUnder = twinKeyOf(child.nodeKey);
      if (filedUnder == canonChildren[i].nodeKey) continue;
      // Corroborated in Sinhala before it is filed. Where the node it sits on
      // carries the same Sinhala title, the commentary key is right and the
      // canon's Pali label is what drifted — the opposite claim.
      final filed = tree[filedUnder];
      if (filed != null &&
          flatten(filed.sinhalaName) == flatten(child.sinhalaName)) {
        continue;
      }
      rows.add('| `${child.nodeKey}` | ${cell(child.paliName)} | '
          '`$filedUnder` — ${cell(filed?.paliName ?? 'no such node')}'
          ' | `${canonChildren[i].nodeKey}` |');
    }
    if (rows.isEmpty) continue;
    driftOut
      ..writeln('### `${container.nodeKey}` — '
          '${canonChildren.length} suttas, '
          '${commentaryChildren.length} vaṇṇanā')
      ..writeln('')
      ..writeln('| commentary node | its title | its key points at |'
          ' but that title is |')
      ..writeln('|---|---|---|---|')
      ..writeln(rows.join('\n'))
      ..writeln('');
  }
  out.write(driftOut.isEmpty
      ? 'None: every commentary node whose title repeats a canon sutta name '
          'sits at that sutta\'s own index.\n'
      : driftOut.toString());

  return out.toString();
}

/// The checkout whose corpus was measured — every path below hangs off it.
///
/// Derived from the reader rather than from `Platform.script`, which is what
/// `bin/generate.dart` uses for its own package root. That tool only *reads*;
/// this one writes, and resolving the repo root a second way — by this file's
/// depth below it — is a second answer that can disagree with the first. Run
/// from a different checkout's working directory, the `Platform.script` form
/// would measure one corpus and write the snapshot into another.
///
/// `CorpusReader.discover` has already found the root by looking for
/// `assets/data/tree.json`, so reusing its answer is what guarantees every
/// generated file lands beside the corpus it describes.
String _repoRoot(CorpusReader reader) =>
    Directory(reader.assetsPath).parent.path;

/// Where the upstream report lands, beside `CORPUS_FIGURES.md`.
String _upstreamReportPath(CorpusReader reader) =>
    '${_repoRoot(reader)}/static_site_generator/UPSTREAM_DEFECTS.md';

/// Where the generated figures live. Package root, beside `lib/` and `tool/`.
String _figuresPath(CorpusReader reader) =>
    '${_repoRoot(reader)}/static_site_generator/CORPUS_FIGURES.md';

/// Where the frozen grouping verdicts live.
String _snapshotPath(CorpusReader reader) => '${_repoRoot(reader)}'
    '/packages/wisdom_shared/lib/src/grouping/grouping_snapshot.dart';

/// Where the frozen preamble verdicts live, beside the grouping ones.
String _preambleSnapshotPath(CorpusReader reader) => '${_repoRoot(reader)}'
    '/packages/wisdom_shared/lib/src/grouping/preamble_snapshot.dart';

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
