/// Every count this codebase would otherwise hard-code in a doc comment.
///
/// ## Why it exists
///
/// Before this file, ~45 comments across `lib/`, `tool/`, `test/` and the plan
/// docs each carried their own literal — "all N pages", "N of the M nodes", "N
/// pages carry one". Every one of them was a private copy of a number the build
/// already knows, and one upstream re-sync moved all of them at once while
/// updating none. Six sites were measured stale by roughly a third the day this
/// was written, all of them still quoting the page count from before the
/// grouping rule landed.
///
/// So the rule is now: **a corpus-derived count appears in exactly one place,
/// `CORPUS_FIGURES.md`, and prose cites it by name.** A comment writes
/// `` `FIGURES.realPages` `` where it used to write the digits.
///
/// ## Derived, never asserted
///
/// This is a *report*, not an input. Nothing in `lib/` reads a figure to decide
/// anything — the build derives its page set from the tree and
/// `foldedLeafKeys`, and a constant it could compare against would be a second
/// answer able to disagree with the first. That is also why the figures live in
/// Markdown rather than as Dart `const`s: a number the compiler cannot see
/// cannot quietly become load-bearing.
///
/// It is likewise **not a CI gate**. New upstream content *should* move these
/// counts without failing anything — same reasoning as `plan_corpus.dart`'s
/// retired `--expect`. Regenerating is a step of the sync workflow, next to
/// `--write-snapshot`, and the git diff is the review.
///
/// ## What is deliberately absent
///
/// - **Thresholds and policy.** `GroupingPolicy.shortLineChars`,
///   `longLineChars`, `minRunLength` and `keyPolicies` are *inputs*, argued in
///   the plan doc and cited by name already. A figure is an output.
/// - **Layout arithmetic.** The px and rem in `stylesheet.dart` are design
///   math, bound to the rule they justify, and no re-sync moves them.
/// - **External limits.** Cloudflare's 20,000-file cap, `max-age` values, HTTP
///   status codes.
/// - **Anything needing a full build or a counterfactual run** — output bytes,
///   gzip sizes of the index, "how many runs the preconditions block". Those
///   are one-off analyses, not facts this pass can re-derive, so their digits
///   were removed from the comments rather than parked here to go stale again.
library;

import 'dart:io';

import 'package:wisdom_shared/wisdom_shared.dart';

import '../data/corpus_reader.dart';
import '../domain/content_slicer.dart';
import '../domain/grouping_policy.dart';
import '../domain/preamble_planner.dart';
import '../domain/slice_alignment.dart';
import '../render/node_labels.dart';
import 'page_budget.dart';

/// One counted fact, cited in prose as `FIGURES.[name]`.
class Figure {
  /// The citation key. Stable — renaming one orphans every comment citing it.
  final String name;

  /// Formatted for reading, thousands separated.
  final String value;

  /// One line saying exactly what was counted. The definition matters more than
  /// the number: "leaves sharing a name" is a different figure depending on
  /// whether the commentary marker is on.
  final String note;

  const Figure(this.name, this.value, this.note);
}

/// A themed run of figures — one Markdown table in the output.
class FigureGroup {
  final String title;
  final String blurb;
  final List<Figure> figures;

  const FigureGroup({
    required this.title,
    required this.blurb,
    required this.figures,
  });
}

/// `6058` → `6,058`. Only ever sees counts, so it need not handle a sign or a
/// fractional part.
String formatCount(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// Counts everything, in **one pass** over the corpus.
///
/// The pass is structured by content file rather than by figure: several
/// figures need the same parsed file, and asking for them independently would
/// re-read the whole corpus once per question. Files are visited in sorted
/// order so the output is byte-stable across runs (§11.8) — the same property
/// the snapshot writer needs, for the same reason.
///
/// [plan] must be built from the **frozen** [folded] set, not from a fresh run
/// of the rule: these figures describe the site that is actually served.
List<FigureGroup> computeCorpusFigures({
  required TipitakaTree tree,
  required SitePlan plan,
  required Set<String> folded,
  required CorpusReader reader,
}) {
  // This mode calls [SliceAlignment.verdictFor] directly rather than through
  // `misalignedSlices()`, so it has to ask for itself. It matters more here
  // than anywhere: a type classified by neither set reaches no verdict, the
  // misalignment figures below quietly drop it, and `--write-figures` writes
  // that undercount into `CORPUS_FIGURES.md` — a file the prose then cites by
  // name. The one report whose whole purpose is to be trusted is the one that
  // must not be allowed to under-report.
  PreamblePlanner.assertTypesPartitioned();

  // ── the corpus pass ───────────────────────────────────────────────────────
  final nodesByFile = ContentSlicer.nodesByFile(tree);
  final charsOf = <String, int>{};
  final nodesWithPali = <String>{};
  final nodesWithSinhala = <String>{};
  var rowsSinhalaOnly = 0;
  var rowsEmptyBothSides = 0;
  var unequalPrintedPages = 0;
  final filesWithUnequalSides = <String>{};
  final misaligned = <SliceMisalignment, int>{};

  for (final fileId in nodesByFile.keys.toList()..sort()) {
    final file = reader.readContentFile(fileId);

    for (final page in file.pages) {
      if (page.pali.length != page.sinhala.length) {
        unequalPrintedPages++;
        filesWithUnequalSides.add(fileId);
      }
      for (var i = 0; i < page.entryCount; i++) {
        final paliEmpty = page.paliAt(i)?.text.isEmpty ?? true;
        final sinhalaEmpty = page.sinhalaAt(i)?.text.isEmpty ?? true;
        if (paliEmpty && sinhalaEmpty) {
          rowsEmptyBothSides++;
        } else if (paliEmpty) {
          rowsSinhalaOnly++;
        }
      }
    }

    final slicer = ContentSlicer.forFile(file, nodesByFile[fileId]!);
    for (final node in nodesByFile[fileId]!) {
      final slice = slicer.sliceFor(node.nodeKey);
      charsOf[node.nodeKey] = slice.rawCharCount;

      // Free here, and nowhere else: the rule reads a slice's first two rows,
      // and this is the one pass that already holds every slice.
      if (node.isLeaf) {
        final verdict = SliceAlignment.verdictFor(node, slice);
        if (verdict != null) {
          misaligned[verdict] = (misaligned[verdict] ?? 0) + 1;
        }
      }
      for (final row in slice.rows) {
        if (row.pali?.text.isNotEmpty ?? false) nodesWithPali.add(node.nodeKey);
        if (row.sinhala?.text.isNotEmpty ?? false) {
          nodesWithSinhala.add(node.nodeKey);
        }
      }
    }
  }

  // Combined raw characters a page renders, preamble included — the same
  // definition `plan_corpus.dart` reports sizes under, and the one the grouping
  // lines were measured in.
  int charsOfPage(SitePage page) {
    var total = page.hasPreamble ? charsOf[page.nodeKey] ?? 0 : 0;
    for (final sutta in page.suttas) {
      total += charsOf[sutta.nodeKey] ?? 0;
    }
    return total;
  }

  bool pageHasLanguage(SitePage page, Set<String> present) =>
      (page.hasPreamble && present.contains(page.nodeKey)) ||
      page.suttas.any((s) => present.contains(s.nodeKey));

  // ── tree shape ────────────────────────────────────────────────────────────
  final nodes = tree.allNodes.toList();
  final leaves = nodes.where((n) => n.isLeaf).toList();
  final containers = nodes.where((n) => !n.isLeaf).toList();
  final commentaryNodes = nodes.where((n) => n.isCommentary).length;
  final treatiseNodes = nodes
      .where((n) =>
          n.nodeKey == TipitakaNodeKeys.treatises ||
          n.nodeKey.startsWith('${TipitakaNodeKeys.treatises}-'))
      .length;

  var names = 0;
  var namesWithZwj = 0;
  for (final node in nodes) {
    for (final name in [node.paliName, node.sinhalaName]) {
      names++;
      if (name.contains(_zwj)) namesWithZwj++;
    }
  }

  // The same predicate [SliceAlignment] asks of a *row*, rather than a second
  // copy of it here — one statement about what BJT printed, asked of a name in
  // one place and a row's text in the other. It differs in one way from the
  // local regex it replaced: an empty name is not bare numbering, where the
  // regex counted one as numeric-only. That is the better reading — a leaf with
  // no name is not a leaf titled by number — and the figure does not move
  // either way, because no leaf in the corpus has an empty `paliName`.
  final numericOnlyTitles =
      leaves.where((n) => SliceAlignment.isBareNumbering(n.paliName)).length;

  final leavesPerTitle = <String, int>{};
  for (final leaf in leaves) {
    final title = nodeTitle(leaf);
    leavesPerTitle[title] = (leavesPerTitle[title] ?? 0) + 1;
  }
  final leavesSharingATitle =
      leaves.where((l) => leavesPerTitle[nodeTitle(l)]! > 1).length;

  final markedNodes = nodes.where(carriesCommentaryMarker).length;

  // Leaf children only. A *container* child sitting in another file is the
  // ordinary shape — that is how a book is split across printed volumes — and
  // counting those would answer a different question than the one the renderer
  // asks, which is whether a page's own suttas can share one parsed file.
  final containersWhoseLeavesSitElsewhere = containers
      .where((c) => tree.childrenOf(c.nodeKey).any(
          (child) => child.isLeaf && child.contentFileId != c.contentFileId))
      .length;

  // ── the planned site ──────────────────────────────────────────────────────
  // The page tally itself is [PageBudget]'s, not counted again here: it is the
  // one thing `plan_corpus.dart`'s own report also needs, and two loops
  // producing `FIGURES.realPages` is the duplication this whole file exists to
  // remove. What stays below is the part only the figures want — and every one
  // of those needs either a character count or a second key lookup, which is
  // why the budget does not carry them.
  final budget = PageBudget.of(tree: tree, plan: plan, folded: folded);

  var loneChildChapters = 0;
  var loneChildChaptersNotFoldedOnSize = 0;
  ({String key, int chars})? largestLoneChild;
  var nodesWithCommentaryLink = 0;
  var runLinkChapters = 0;
  var commentaryLinksResolvedByNeighbour = 0;
  var canonNodesWithNoCommentary = 0;
  var commentaryTwinsFolded = 0;
  var commentaryPages = 0;
  var readablePagesWithoutSinhala = 0;
  var readablePagesWithoutPali = 0;
  final thinSuttaPages = <SitePage>[];
  final multiSuttaChapters = <SitePage>[];

  for (final page in plan.pages) {
    if (page.node.isCommentary) commentaryPages++;

    // Exactly what `PageTemplate` emits, asked of the plan rather than spelled
    // out again here — see [SitePage.crossLinkedNodes]. Counting pages instead
    // would undercount the chapters, which is the shape that hid the
    // container-anchored bug: one wrong link served a whole run.
    if (page.speaksForRun(tree)) runLinkChapters++;
    for (final node in page.crossLinkedNodes(tree)) {
      final target = crossLinkTargetKey(tree, node.nodeKey);
      if (target == null) {
        if (!node.isCommentary) canonNodesWithNoCommentary++;
        continue;
      }
      nodesWithCommentaryLink++;
      if (target != twinKeyOf(node.nodeKey)) {
        commentaryLinksResolvedByNeighbour++;
      }
      if (folded.contains(target)) commentaryTwinsFolded++;
    }

    switch (page.kind) {
      case PageKind.sutta:
        if (charsOfPage(page) < GroupingPolicy.shortLineChars) {
          thinSuttaPages.add(page);
        }
      case PageKind.chapter:
        if (page.suttas.length == 1) {
          loneChildChapters++;
          final leaf = page.suttas.first;
          final chars = charsOf[leaf.nodeKey] ?? 0;
          // "The merge outranks both the size line and promotion" — so the
          // interesting count is leaves the rule would *not* have folded on
          // their own: at or above their line, or promoted and never measured
          // at all. `isShort` is false in exactly those two cases.
          if (!GroupingPolicy.isShort(leaf, chars)) {
            loneChildChaptersNotFoldedOnSize++;
          }
          if (largestLoneChild == null || chars > largestLoneChild.chars) {
            largestLoneChild = (key: leaf.nodeKey, chars: chars);
          }
        } else {
          multiSuttaChapters.add(page);
        }
      case PageKind.toc:
        break;
    }

    // `isReadable`, not `kind != toc`: a container page carrying the book's
    // introduction is a page a reader reads in a chosen layout, so a missing
    // language side is the same defect there as on a sutta.
    if (page.isReadable) {
      if (!pageHasLanguage(page, nodesWithSinhala)) {
        readablePagesWithoutSinhala++;
      }
      if (!pageHasLanguage(page, nodesWithPali)) readablePagesWithoutPali++;
    }
  }

  final thinPromoted = thinSuttaPages
      .where((p) => GroupingPolicy.policyFor(p.node) == LeafPolicy.ownPage)
      .length;

  multiSuttaChapters.sort((a, b) => charsOfPage(b).compareTo(charsOfPage(a)));
  final biggestChapter = multiSuttaChapters.isEmpty
      ? null
      : (
          key: multiSuttaChapters.first.nodeKey,
          chars: charsOfPage(multiSuttaChapters.first)
        );
  final chaptersOver100k =
      multiSuttaChapters.where((p) => charsOfPage(p) > 100000).length;

  final longestLeaf = leaves.isEmpty
      ? null
      : (leaves
          .map((l) => (key: l.nodeKey, chars: charsOf[l.nodeKey] ?? 0))
          .reduce((a, b) => b.chars > a.chars ? b : a));

  // Rows whose serving URL is not the bare one — asked of `urlFor` rather than
  // of the folded set, because owning a file and owning the bare URL stopped
  // being the same question. An anchor leaf owns its file and still needs the
  // fragment, and it is the half of this count that fails quietly: a folded
  // leaf's bare URL 404s, an anchor leaf's answers 200 with its whole run.
  var tocRowsNeedingUrlFor = 0;
  for (final page in plan.pages) {
    if (page.kind != PageKind.toc) continue;
    tocRowsNeedingUrlFor += tree
        .childrenOf(page.nodeKey)
        .where((child) =>
            plan.urlFor(child.nodeKey) != tipitakaUrl(child.nodeKey))
        .length;
  }

  // ── on-disk size ──────────────────────────────────────────────────────────
  final textFiles = Directory('${reader.assetsPath}/text')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList();
  final corpusBytes = textFiles.fold<int>(0, (sum, f) => sum + f.lengthSync());
  final treeBytes = File('${reader.assetsPath}/data/tree.json').lengthSync();

  return [
    FigureGroup(
      title: 'The tree',
      blurb: '`assets/data/tree.json`, before the site makes any decision '
          'about it. These move only when the corpus is re-synced from '
          'upstream tipitaka.lk.',
      figures: [
        Figure('treeNodes', formatCount(tree.length),
            'every node in `tree.json`, leaves and containers together'),
        Figure('leaves', formatCount(budget.leaves),
            'nodes with no children — a sutta, or the smallest addressable unit'),
        Figure('containers', formatCount(budget.containers),
            'nodes with children'),
        Figure(
            'roots',
            formatCount(tree.rootKeys.length),
            'top-level nodes, which have no common ancestor: '
                '${tree.rootKeys.join(', ')}'),
        Figure('commentaryNodes', formatCount(commentaryNodes),
            'nodes under an `atta-*` key'),
        Figure('treatiseNodes', formatCount(treatiseNodes),
            'nodes under `anya`, which sits outside the three-pitaka pattern'),
        Figure('nodeNames', formatCount(names),
            'name strings — two per node, Pali and Sinhala'),
        Figure(
            'namesWithLigatureZwj',
            formatCount(namesWithZwj),
            'names containing a ZWJ. All of them are ligature ZWJ '
                '(rakaransaya, yansaya): raw `tree.json` carries no touching ZWJ'),
        Figure('numericOnlyLeafTitles', formatCount(numericOnlyTitles),
            'leaves whose Pali name has no letter in it at all — "1. 16. 8. 9-24"'),
        Figure(
            'leavesSharingATitle',
            formatCount(leavesSharingATitle),
            'leaves whose `nodeTitle` — commentary marker included — is also '
                "another leaf's"),
        Figure(
            'nodesCarryingCommentaryMarker',
            formatCount(markedNodes),
            'commentary nodes the site appends අට්ඨකථා to. The remaining '
                '${formatCount(commentaryNodes - markedNodes)} are already named '
                'with it upstream'),
        Figure(
            'containersWhoseLeavesSitElsewhere',
            formatCount(containersWhoseLeavesSitElsewhere),
            "containers holding a child whose text is in a different file than "
                "the container's own"),
      ],
    ),
    FigureGroup(
      title: 'The site',
      blurb: 'What `SitePlan.build` produces from the tree and the frozen '
          '`foldedLeafKeys`. These move when the snapshot is regenerated, and '
          'each move is one URL.',
      figures: [
        Figure('foldedLeaves', formatCount(budget.foldedLeaves),
            'leaves with no page of their own, served as `<chapter>#<key>`'),
        Figure('suttaPages', formatCount(budget.suttaPages),
            'leaves that own a file'),
        Figure('chapterPages', formatCount(budget.chapterPages),
            'files carrying a run of folded leaves'),
        Figure('wholeVaggaChapters', formatCount(budget.wholeVaggaChapters),
            'chapters covering a whole container, sitting at its URL'),
        Figure('midVaggaChapters', formatCount(budget.midVaggaChapters),
            'chapters starting below a container, anchored on their first leaf'),
        Figure('loneChildChapters', formatCount(loneChildChapters),
            'chapters that are a container merged with its only leaf'),
        Figure(
            'runLinkChapters',
            formatCount(runLinkChapters),
            'chapters named after their group whose own cross-link stands for '
                'the whole run — the unfiltered view offers it instead of one '
                'link per sutta (`SitePage.speaksForRun`)'),
        Figure(
            'loneChildChaptersNotFoldedOnSize',
            formatCount(loneChildChaptersNotFoldedOnSize),
            'of those, the ones the size rule would not have folded — at or '
                'above their line, or promoted and never measured. The merge '
                'outranks both'),
        if (largestLoneChild != null)
          Figure(
              'largestLoneChildChars',
              formatCount(largestLoneChild.chars),
              'the biggest leaf merged into its container '
                  '(`${largestLoneChild.key}`)'),
        Figure(
            'containerTocs',
            formatCount(budget.containerTocs),
            'container pages — a list of links, and above it whatever the '
                'container itself owns'),
        Figure(
            'readableContainerTocs',
            formatCount(budget.readableTocs),
            "of those, the ones whose preamble is the book's introduction to "
                'the chapter rather than its title, so the page is readable '
                '(`textBearingContainerKeys`)'),
        Figure(
            'realPages',
            formatCount(budget.realPages),
            'pages the build writes, `/` included. Not `404.html`, which is '
                'the answer for addresses that have no page'),
        Figure(
            'readablePages',
            formatCount(plan.readablePages.length),
            'pages carrying text — sutta, chapter, and the container pages '
                'that open with an introduction. The prev/next chain'),
        Figure(
            'pagesWithStubs',
            formatCount(budget.pagesWithStubs),
            'the count if every folded leaf also got a redirect stub (the P5 '
                'gate). Cloudflare Pages caps a project at 20,000 files'),
        Figure(
            'tocRowsNeedingUrlFor',
            formatCount(tocRowsNeedingUrlFor),
            'TOC rows the bare URL gets wrong, so `tocList` has to resolve '
                'them through `SitePlan.urlFor`: folded leaves, which 404, and '
                'anchor leaves, which answer with their whole run'),
        Figure('commentaryPages', formatCount(commentaryPages),
            'pages under an `atta-*` key'),
        Figure(
            'nodesWithCommentaryLink',
            formatCount(nodesWithCommentaryLink),
            'texts carrying a canon ↔ commentary cross-link, counted where the '
                'link is emitted: once per section, one per TOC, and once more '
                'per `FIGURES.runLinkChapters` chapter for the run itself. '
                'Nodes and not leaves — a TOC links from its container'),
        Figure(
            'commentaryLinksResolvedByNeighbour',
            formatCount(commentaryLinksResolvedByNeighbour),
            'of those, links whose exact twin key names no node and which a '
                'neighbour answers for instead. Three shapes: a vaṇṇanā whose '
                'declared range reaches the sutta, the canon node a merge put '
                'the root text in, and — where the commentary subdivides below '
                'the canon — the nearest canon ancestor, which is about half'),
        Figure(
            'canonNodesWithNoCommentary',
            formatCount(canonNodesWithNoCommentary),
            'canon nodes no commentary claims, which carry no link at all — '
                'mostly suttas the vaṇṇanā is silent on, plus the containers '
                'whose twin never existed; the page says so by omission'),
        Figure(
            'commentaryTwinsFolded',
            formatCount(commentaryTwinsFolded),
            'of the linked, targets that are folded leaves — so the link must '
                'be resolved through `urlFor`, never `tipitakaUrl`'),
      ],
    ),
    FigureGroup(
      title: 'The text',
      blurb: 'Measured over all ${formatCount(textFiles.length)} content '
          'files. Character counts are combined Pali + Sinhala, raw with '
          'markers left in — the convention `NodeSlice.rawCharCount` and the '
          'grouping lines both use.',
      figures: [
        Figure('contentFiles', formatCount(textFiles.length),
            '`assets/text/*.json` — one printed book each'),
        Figure(
            'corpusMegabytes', _megabytes(corpusBytes), 'those files on disk'),
        Figure('treeMegabytes', _megabytes(treeBytes), '`tree.json` on disk'),
        Figure('thinSuttaPages', formatCount(thinSuttaPages.length),
            'sutta pages under `GroupingPolicy.shortLineChars`'),
        Figure(
            'thinSuttaPagesPromoted',
            formatCount(thinPromoted),
            'of those, leaves in a promoted book — thin on purpose, because '
                'the leaf is a complete named work'),
        if (biggestChapter != null)
          Figure('biggestChapterChars', formatCount(biggestChapter.chars),
              'the largest multi-sutta chapter (`${biggestChapter.key}`)'),
        Figure('chaptersOver100k', formatCount(chaptersOver100k),
            'multi-sutta chapters over 100,000 characters'),
        if (longestLeaf != null)
          Figure('longestLeafChars', formatCount(longestLeaf.chars),
              'the largest single leaf in the corpus (`${longestLeaf.key}`)'),
        Figure(
            'rowsSinhalaWithEmptyPali',
            formatCount(rowsSinhalaOnly),
            "rows carrying Sinhala against an empty Pali cell — translator's "
                'matter the book prints on one side only'),
        Figure('rowsEmptyBothSides', formatCount(rowsEmptyBothSides),
            'rows with nothing on either side, the only ones dropped outright'),
        Figure(
            'printedPagesWithUnequalSides',
            formatCount(unequalPrintedPages),
            'printed pages whose two entry lists differ in length, so the '
                'tail of the longer side has no counterpart'),
        Figure(
            'filesWithUnequalSides',
            formatCount(filesWithUnequalSides.length),
            'content files holding such a page — the known `ap-pat*` '
                '(Paṭṭhāna) misalignment'),
        Figure(
            'readablePagesWithoutSinhala',
            formatCount(readablePagesWithoutSinhala),
            'readable pages with no Sinhala at all. They get no column '
                'captions, no layout switcher — one of the four would hide '
                'every row they have — and `solo` on `.content` in place of '
                'what the missing radios would have set'),
        Figure(
            'readablePagesWithoutPali',
            formatCount(readablePagesWithoutPali),
            'the reverse. The test is symmetric anyway: nothing guarantees '
                'this stays 0 after a re-sync'),
        Figure(
            'correctedCoordinates',
            formatCount(correctedTreeCoordinates.length),
            'leaves whose upstream coordinate did not point at the row their '
                'text begins on, in any of the shapes `SliceAlignment` finds — '
                'a closing colophon taken for an opening line, a recitation '
                'marker, or a coordinate a whole section early — corrected '
                'before the tree is used at all (`correctedTreeCoordinates`). '
                'Every figure on this page is measured after that correction'),
        Figure(
            'misalignedSlices',
            formatCount(misaligned.entries
                .where((e) => SliceAlignment.isDefect(e.key))
                .fold(0, (sum, e) => sum + e.value)),
            'leaves whose slice still does not hold the text they are named '
                'for (`SliceAlignment`), which is what the correction above '
                'does not reach. **0 is the expected value** — anything here '
                'means a re-sync moved the defect and `--write-alignment` '
                'needs re-running. `plan_corpus.dart --misaligned` lists them'),
        Figure(
            'trailingColophonLeaves',
            formatCount(misaligned[SliceMisalignment.trailingColophon] ?? 0),
            "of those, the ones opening on the leaf's own name printed as a "
                "colophon, so the page would carry this leaf's title over the "
                "next leaf's text"),
        Figure(
            'strayDividerLeaves',
            formatCount(misaligned[SliceMisalignment.strayDivider] ?? 0),
            'leaves gaining one stray row from a `භාණවාරං` recitation marker '
                'closing the division above'),
        Figure(
            'strandedLeadingNumberLeaves',
            formatCount(
                misaligned[SliceMisalignment.strandedLeadingNumber] ?? 0),
            "the rest: leaves whose own leading number is stranded at the foot "
                "of their slice, so the page carries this leaf's title over "
                "the previous leaf's text"),
        Figure(
            'headingOnlyLeaves',
            formatCount(misaligned[SliceMisalignment.headingOnlyLeaf] ?? 0),
            '**not** part of the count above, and not a defect. Leaves whose '
                'slice is one heading and nothing a reader reads, because '
                'that is what BJT printed — a group title whose content is '
                'split across its siblings, an abbreviation standing in for '
                'two sections, or a recitation marker modelled as a node. The '
                'coordinate is right; the section renders with a title and no '
                'body'),
      ],
    ),
  ];
}

/// The whole file, ready to write.
///
/// **No timestamp and no build id**, for the same reason `grouping_snapshot`
/// carries none: regenerating an unchanged corpus must rewrite identical bytes,
/// so the git diff shows only figures that actually moved. The date is the
/// commit's.
String renderCorpusFigures(List<FigureGroup> groups) {
  final buffer = StringBuffer('''
<!-- GENERATED by `dart run tool/plan_corpus.dart --write-figures`. Do not hand-edit. -->

# Corpus figures

Every count the static site's code and docs would otherwise hard-code, derived
in one pass over the vendored corpus.

**Cite one, never copy it.** In a comment or a doc, write the name — for
example `` `FIGURES.realPages` `` — and no digits. A literal in prose is a
private copy of a number that moves on every upstream re-sync, and the copies
do not move with it.

Regenerate as a step of the sync workflow, beside the snapshot:

```sh
dart run static_site_generator/tool/plan_corpus.dart --write-snapshot
dart run static_site_generator/tool/plan_corpus.dart --write-figures
```

Nothing reads this file at build time and nothing fails when it drifts — new
upstream content *should* move these counts. The git diff is the review.

Not here, deliberately: the thresholds in `GroupingPolicy` (inputs, not
outputs), the layout arithmetic in `stylesheet.dart`, external limits such as
Cloudflare's file cap, and anything that needs a full build or a counterfactual
run to produce.
''');

  for (final group in groups) {
    buffer.writeln('');
    buffer.writeln('## ${group.title}');
    buffer.writeln('');
    buffer.writeln(_wrap(group.blurb));
    buffer.writeln('');
    buffer.writeln('| figure | value | what it counts |');
    buffer.writeln('| --- | ---: | --- |');
    for (final figure in group.figures) {
      buffer.writeln(
          '| `FIGURES.${figure.name}` | ${figure.value} | ${figure.note} |');
    }
  }

  return buffer.toString();
}

/// Greedy wrap to 80 columns, so the prose in the generated file reads like the
/// rest of the repo's Markdown. Table rows are exempt: a wrapped row is not a
/// table.
String _wrap(String text) {
  final lines = <String>[];
  var line = '';
  for (final word in text.split(' ')) {
    if (line.isEmpty) {
      line = word;
    } else if (line.length + 1 + word.length <= 80) {
      line = '$line $word';
    } else {
      lines.add(line);
      line = word;
    }
  }
  if (line.isNotEmpty) lines.add(line);
  return lines.join('\n');
}

/// Zero-width joiner. Ligature ZWJ in a `tree.json` name — rakaransaya
/// (`සූත්‍ර`) and yansaya — is ordinary Sinhala spelling, not the touching form
/// `weldTitle` inserts.
const String _zwj = '‍';

/// `356789012` → `340 MB`. Binary megabytes, the unit `du -h` reports in.
String _megabytes(int bytes) => '${(bytes / (1024 * 1024)).round()} MB';
