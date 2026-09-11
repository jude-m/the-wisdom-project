import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';
import 'package:static_site_generator/data/corpus_reader.dart';
import 'package:wisdom_shared/wisdom_shared.dart';

/// Full-corpus proof that the extracted `wisdom_shared` logic is behaviourally
/// identical to the app code it replaced.
///
///     dart run static_site_generator/tool/verify_corpus_invariants.dart
///     dart run static_site_generator/tool/verify_corpus_invariants.dart \
///       --content-db build/some-other.db
///
/// **A script *and* a test.** Reading every content file plus the tree
/// (`FIGURES.corpusMegabytes` and `FIGURES.treeMegabytes`) costs ~23s, so
/// `test/corpus_tools_test.dart` runs it under the `corpus` tag. Still worth
/// running by hand: only the printout says *what* the corpus looks like.
///
/// The invariants it establishes are also pinned as fast unit tests in
/// `packages/wisdom_shared/test/`; this is the exhaustive backstop, re-run
/// whenever `content_markers.dart` or `tipitaka_tree.dart` is touched, and
/// whenever `assets/` is re-synced from upstream tipitaka.lk.
///
/// The oracles in sections 1 and 2 are the *pre-extraction* implementations,
/// copied verbatim:
///   - `Entry.plainText` / `Entry._computeMarkedRanges` (commit 4bb320c)
///   - `TreeLocalDataSourceImpl._buildTreeStructure` / `_extractChildIndex`
///
/// They are frozen. If one needs changing to make this pass, the extraction
/// changed behaviour and that is the finding.
///
/// Section 3 has no oracle and asks a different question: every URL the site
/// writes is read back with `resolveTarget` — the app's own resolver, now in
/// `wisdom_shared` where a build step can reach it — and required to name the
/// node it was written for.
///
/// Section 4 has no oracle either, and guards the corpus rather than the code:
/// reading order and coordinate order must agree inside every content file, or
/// the app's reader silently shows a short unit. Re-run it at every upstream
/// re-sync; that is the only thing that can break it.
///
/// Section 5 is the safety net for the JSON-to-SQLite migration: every entry in
/// the corpus, read back out of the `bjt_content` table and required to be the
/// same. It looks in the bundled `assets/databases/bjt-fts.db` by default, so
/// it arms itself the moment step 5 populates that table instead of waiting for
/// someone to remember a flag; `--content-db` points it elsewhere. Until the
/// table exists it reports SKIPPED and does not vote — a section that cannot
/// run is not a section that passed.
void main(List<String> args) {
  final assetsFlag = _valueOf(args, '--assets');
  final reader = assetsFlag == null
      ? CorpusReader.discover()
      : CorpusReader(assetsPath: assetsFlag);

  stdout.writeln('assets  ${reader.assetsPath}\n');

  final markersOk = _verifyMarkers(reader);
  stdout.writeln('');
  final treeOk = _verifyTree(reader);
  stdout.writeln('');
  final linksOk = _verifyLinks(reader);
  stdout.writeln('');
  final orderOk = _verifyReadingOrder(reader);

  // Null when no database was named: skipped, which is neither a pass nor a
  // failure and must not read as either.
  final contentDb = _valueOf(args, '--content-db');
  stdout.writeln('');
  final bool? contentOk;
  if (contentDb == null && _flagGiven(args, '--content-db')) {
    // Trailing `--content-db` with nothing after it. Skipping here would tell
    // an operator who believes they ran the section that it passed.
    contentOk = false;
    stdout.writeln('CONTENT');
    stdout.writeln('  ! --content-db needs a path: --content-db build/bjt.db');
  } else {
    contentOk = _verifyContent(
      reader,
      contentDb ?? '${reader.assetsPath}/databases/bjt-fts.db',
      named: contentDb != null,
    );
  }

  stdout.writeln('');
  if (markersOk && treeOk && linksOk && orderOk && contentOk != false) {
    stdout.writeln('PASS — extraction identical to the app original (1, 2), '
        'every URL reads back as its own page (3), and reading order never '
        'steps backwards inside a content file (4).');
    stdout.writeln(contentOk == null
        ? '       Section 5 did not run — see its SKIPPED line above.'
        : '       The content table matches the JSON, entry for entry (5).');
  } else {
    stdout.writeln('FAIL — see divergences above.');
    exitCode = 1;
  }
}

// ---------------------------------------------------------------------------
// 1. Marker grammar, over every entry in the corpus
// ---------------------------------------------------------------------------

bool _verifyMarkers(CorpusReader reader) {
  final files = _contentFiles(reader);

  var entries = 0;
  var plainDiffs = 0;
  var rangeDiffs = 0;
  var rebuildDiffs = 0;
  var footnotes = 0;
  var styledFootnotes = 0;
  var underlineSpans = 0;
  var underlineSegmentRuns = 0;
  final labels = <String>{};
  final samples = <String>[];

  for (final file in files) {
    final id = _fileIdOf(file);
    final content = reader.readContentFile(id);

    for (final page in content.pages) {
      for (final entry in [...page.pali, ...page.sinhala]) {
        final raw = entry.text;
        entries++;

        final plain = ContentMarkers.stripMarkers(raw);
        if (plain != _oldPlainText(raw)) {
          plainDiffs++;
          _sample(samples, 'plainText  $id  ${_clip(raw)}');
        }

        if (!_sameRanges(
            ContentMarkers.boldRanges(raw), _oldMarkedRanges(raw))) {
          rangeDiffs++;
          _sample(samples, 'ranges     $id  ${_clip(raw)}');
        }

        // Segments must be a lossless re-partition of the same stripped text.
        final segments = parseContentMarkers(raw);
        if (segments.map((s) => s.text).join() != plain) {
          rebuildDiffs++;
          _sample(samples, 'segments   $id  ${_clip(raw)}');
        }
        for (final segment in segments) {
          final label = segment.footnoteLabel;
          if (label != null) {
            footnotes++;
            labels.add(label);
            // Footnote segments are zero-width, so their style is the only
            // signal a renderer gets about the span enclosing them.
            if (segment.bold || segment.underline) styledFootnotes++;
          }
        }

        // Underline is counted two ways because they disagree, and the gap is
        // informative. `__` toggle pairs say how many spans the *source*
        // marks up; styled segments say how many the parser hands a renderer.
        underlineSpans += '__'.allMatches(raw).length ~/ 2;
        var underlineOpen = false;
        for (final segment in segments) {
          if (segment.underline && !underlineOpen) underlineSegmentRuns++;
          underlineOpen = segment.underline;
        }
      }
    }
  }

  final nonNumeric = labels.where((l) => int.tryParse(l) == null).length;
  stdout.writeln('MARKERS');
  stdout.writeln('  files                 ${files.length}');
  stdout.writeln('  entries               $entries');
  stdout.writeln('  plainText divergences $plainDiffs');
  stdout.writeln('  boldRanges divergences $rangeDiffs');
  stdout.writeln('  segment rebuild fails $rebuildDiffs');
  stdout.writeln('  footnote refs         $footnotes '
      '(${labels.length} distinct labels, $nonNumeric non-numeric)');
  stdout.writeln('  footnotes inside a span $styledFootnotes '
      '(carry bold/underline)');
  stdout.writeln('  underline spans       $underlineSpans '
      '(source `__` pairs)');
  stdout.writeln('  underline segments    $underlineSegmentRuns '
      '(what a renderer receives)');

  // These two counts disagreed by one before footnote segments carried their
  // ambient style: `__{4}__` in mn-3-4.json wraps nothing but a reference,
  // so the span reached a renderer with no styled segment and its underline was
  // silently lost. They should now match — but this is a diagnostic, not an
  // identity: two *adjacent* spans (`__a____b__`) would also read as one run,
  // and no corpus entry contains `____` today. A mismatch means investigate,
  // not necessarily regress.
  final underlineConsistent = underlineSpans == underlineSegmentRuns;
  if (!underlineConsistent) {
    stdout.writeln('  ⚠ ${underlineSpans - underlineSegmentRuns} span(s) reach '
        'no styled segment — check for footnote-only or adjacent spans');
  }
  _printSamples(samples);

  return plainDiffs == 0 &&
      rangeDiffs == 0 &&
      rebuildDiffs == 0 &&
      underlineConsistent;
}

// ---------------------------------------------------------------------------
// 2. Tree ordering, over every parent in tree.json
// ---------------------------------------------------------------------------

bool _verifyTree(CorpusReader reader) {
  final raw = File('${reader.assetsPath}/data/tree.json').readAsStringSync();
  final decoded = json.decode(raw) as Map<String, dynamic>;

  // --- oracle: TreeLocalDataSourceImpl._buildTreeStructure -----------------
  final oldChildren = <String, List<String>>{};
  decoded.forEach((nodeKey, value) {
    final parent = (value as List<dynamic>)[4];
    final parentKey =
        (parent == 'root' || parent == null) ? 'root' : parent as String;
    (oldChildren[parentKey] ??= <String>[]).add(nodeKey);
  });
  for (final children in oldChildren.values) {
    children.sort((a, b) {
      final aIndex = _oldExtractChildIndex(a);
      final bIndex = _oldExtractChildIndex(b);
      if (aIndex == null || bIndex == null) return 0;
      return aIndex.compareTo(bIndex);
    });
  }

  // --- extracted implementation -------------------------------------------
  final tree = TipitakaTree.fromJson(decoded);

  var parentsCompared = 0;
  var mismatches = 0;
  final samples = <String>[];

  void compare(String parentKey, List<String> oldOrder, List<String> newOrder) {
    parentsCompared++;
    if (oldOrder.length == newOrder.length &&
        List.generate(oldOrder.length, (i) => oldOrder[i] == newOrder[i])
            .every((same) => same)) {
      return;
    }
    mismatches++;
    _sample(
      samples,
      '$parentKey\n      old: ${oldOrder.take(8).join(', ')}'
      '\n      new: ${newOrder.take(8).join(', ')}',
    );
  }

  compare('root', oldChildren['root'] ?? const [], tree.rootKeys);
  for (final node in tree.allNodes) {
    if (node.childKeys.isEmpty) continue;
    compare(
        node.nodeKey, oldChildren[node.nodeKey] ?? const [], node.childKeys);
  }

  // §11.8: unstable ordering would re-hash every page on an unchanged corpus.
  String signature(TipitakaTree t) =>
      t.allNodes.map((n) => '${n.nodeKey}:${n.childKeys.join(",")}').join('|');
  final deterministic = signature(
          TipitakaTree.fromJson(json.decode(raw) as Map<String, dynamic>)) ==
      signature(tree);

  // The hazard the explicit tiebreak exists for: parents holding at least one
  // key with no trailing integer, where the old comparator returns 0.
  final indexless = tree.allNodes
      .where((n) => _oldExtractChildIndex(n.nodeKey) == null)
      .toList();
  final hazardParents = <String, int>{};
  for (final node in indexless) {
    final parent = node.parentNodeKey ?? 'root';
    hazardParents[parent] =
        (tree[parent]?.childKeys.length ?? tree.rootKeys.length);
  }
  final widest = hazardParents.entries.isEmpty
      ? null
      : hazardParents.entries.reduce((a, b) => a.value >= b.value ? a : b);

  stdout.writeln('TREE');
  stdout.writeln('  nodes                 ${tree.length}');
  stdout.writeln('  roots                 ${tree.rootKeys.length} '
      '(${tree.rootKeys.join(', ')})');
  stdout.writeln('  parents compared      $parentsCompared');
  stdout.writeln('  ordering mismatches   $mismatches');
  stdout.writeln('  deterministic decode  $deterministic');
  stdout.writeln('  index-less keys       ${indexless.length} '
      'under ${hazardParents.length} parents');
  if (widest != null) {
    stdout.writeln('  widest such parent    ${widest.key} '
        '(${widest.value} children; List.sort is unstable at 32+)');
  }
  _printSamples(samples);

  return mismatches == 0 && deterministic;
}

// ---------------------------------------------------------------------------
// 3. The URL round trip, over every page the site writes
// ---------------------------------------------------------------------------

/// Two questions about the same function, asked of the whole corpus.
///
/// **Does every URL read back as the node it names?** `urlFor` writes one,
/// `resolveTarget` reads it. A folded leaf, a chapter anchored on a leaf and a
/// plain sutta produce three different shapes, and nothing but real data
/// exercises all three across every book at once.
///
/// **Does a merged vaṇṇanā's door still name the room?** The trip out and the
/// trip back are different functions — `canonKeysCoveredBy` going in,
/// `crossLinkTargetKey` coming back — and this is where they are required to be
/// inverses on every merge in the canon.
///
/// **Only URLs the site writes**, all well-formed by construction, so this
/// cannot catch a resolver that mishandles the ones it did *not* write: a
/// pasted `#top`, a hand-edited fragment. Verified — a `resolveTarget` that
/// blindly trusts the fragment still passes here and fails `site_plan_test`.
/// The two are complements, not a gradient.
///
/// **No oracle here**, unlike sections 1 and 2, whose oracles are genuinely
/// different implementations. The pre-extraction resolver was a verbatim copy,
/// so comparing against it could only ever agree.
bool _verifyLinks(CorpusReader reader) {
  final tree = reader.readTree();
  // Whole corpus, frozen sets — the site exactly as it ships.
  final plan = SitePlan.build(tree: tree, rootKeys: tree.rootKeys);

  // Any host parses; the site's own URLs are root-relative.
  TipitakaLink? read(String url) => TipitakaLink.tryParse('https://x$url');

  var urls = 0;
  var parseFails = 0;
  var roundTripFails = 0;
  final samples = <String>[];

  // --- every key the plan serves ------------------------------------------
  final servedKeys = <String>{
    for (final page in plan.pages) ...[
      page.nodeKey,
      ...page.suttas.map((s) => s.nodeKey),
    ],
  };

  for (final key in servedKeys) {
    final url = plan.urlFor(key);
    urls++;
    final link = read(url);
    if (link == null) {
      parseFails++;
      _sample(samples, 'unparseable  $url');
      continue;
    }
    final got = plan.resolveTarget(link);
    if (got != key) {
      roundTripFails++;
      _sample(samples, 'round trip   $url -> $got, wanted $key');
    }
  }

  // --- every door into a merged vaṇṇanā -----------------------------------
  var merged = 0;
  var doors = 0;
  var doorFails = 0;
  var unplanned = 0;

  for (final node in tree.allNodes) {
    if (!node.isCommentary) continue;
    final covered = canonKeysCoveredBy(tree, node.nodeKey);
    if (covered.length < 2) continue;
    merged++;

    // Asked once per vaṇṇanā, not once per door: every marker in this run sits
    // on the one page, so counting the misses per door would report a single
    // unplanned vaṇṇanā as several. Counted, never silently skipped — on a
    // whole-corpus build every key has a page, so a vaṇṇanā without one means
    // the plan stopped covering the corpus, which would shrink the door count
    // rather than fail anything.
    final page = plan.pageOf(node.nodeKey);
    if (page == null) {
      unplanned++;
      _sample(samples, 'no page for  ${node.nodeKey}');
      continue;
    }

    // `covered.first` needs no marker — the vaṇṇanā's own key already names it.
    for (final canonKey in covered.skip(1)) {
      doors++;
      // The page's own URL, fragment-free, exactly as `_commentaryLink` builds
      // it before appending the marker. `wiring_contract_test` pins that the
      // template really emits this shape; what is checked here is that reading
      // it back lands on the vaṇṇanā the browser's `:target` shows.
      final url = '${tipitakaUrl(page.nodeKey)}#${originId(canonKey)}';
      urls++;

      final link = read(url);
      if (link == null || link.originKey != canonKey) {
        parseFails++;
        _sample(samples, 'door parse   $url');
        continue;
      }
      final got = plan.resolveTarget(link);
      if (got != node.nodeKey) {
        doorFails++;
        _sample(samples, 'door         $url -> $got, wanted ${node.nodeKey}');
      }
    }
  }

  // --- every marker-bearing link is actually printed -----------------------
  // The doors above ask whether a URL still resolves through the plan. This
  // asks whether any page prints it, which is a different question and the one
  // that goes quiet: a link dropped as "the coarser of two" leaves every door
  // round-tripping perfectly at an id no page emits any more. That is exactly
  // how three lone-child chapters — `atta-sn-5-1-7` among them, whose own
  // vaṇṇanā answers for a run of vaggas while its section answers for that
  // vagga's suttas — once took seven live links down with them.
  var unprinted = 0;
  for (final node in tree.allNodes) {
    if (!linksThroughOriginMarkers(tree, node.nodeKey)) continue;
    final page = plan.pageOf(node.nodeKey);
    if (page == null) continue; // already counted as `unplanned`
    if (plan.crossLinkedNodes(page).any((n) => n.nodeKey == node.nodeKey)) {
      continue;
    }
    unprinted++;
    _sample(samples, 'unprinted    ${node.nodeKey} on page ${page.nodeKey}');
  }

  stdout.writeln('LINKS');
  stdout.writeln('  pages planned         ${plan.pages.length}');
  stdout.writeln('  keys served           ${servedKeys.length}');
  stdout.writeln('  merged vannana        $merged '
      '(commentaries answering for more than one sutta)');
  stdout.writeln('  origin markers        $doors');
  stdout.writeln('  urls read back        $urls');
  stdout.writeln('  parse failures        $parseFails');
  stdout.writeln('  round-trip failures   $roundTripFails');
  stdout.writeln('  door failures         $doorFails');
  stdout.writeln('  vannana with no page  $unplanned');
  stdout.writeln('  marker links unprinted $unprinted');
  _printSamples(samples);

  return parseFails == 0 &&
      roundTripFails == 0 &&
      doorFails == 0 &&
      unplanned == 0 &&
      unprinted == 0;
}

// ---------------------------------------------------------------------------
// 4. Reading order never steps backwards inside a content file
// ---------------------------------------------------------------------------

/// The one invariant the app's reader takes a **single** range across.
///
/// `ReaderUnitResolver.unitFor` bounds a unit by the last node of the tapped
/// subtree in *reading* order, then asks `SliceIndex.rangeFor` for that node's
/// end — a *coordinate*-ordered boundary. Those name the same node only while
/// reading order inside a file never goes backwards. A subtree is a contiguous
/// run of this walk, so asking the question once per file answers it for every
/// subtree in that file.
///
/// **The generator does not lean on this**, which is why the check lives here
/// rather than falling out of a build: `sitegen` slices a chapter page one
/// sutta at a time, so a tree out of order would misorder rows rather than
/// lose them. The app takes first-start to last-end as one range, where a
/// violation is silent — the unit is simply short, with no error and nothing
/// missing but text.
///
/// **Walks `roots`/`childrenOf`, and must keep doing so.** That is the order
/// the resolver walks, and it is not `allNodes` — siblings are sorted by the
/// trailing number of their key, JSON order is not. Routing this through
/// `SliceIndex.nodesByFile` instead would sort by coordinate first and hide
/// exactly what it looks for, which is also why `SliceIndex.forFile`'s own
/// "out of reading order" throw cannot fire on a real build.
///
/// Ties are legal: a pitaka root printed on its nikāya root's heading block
/// shares that root's coordinate. Only a step backwards fails.
bool _verifyReadingOrder(CorpusReader reader) {
  final tree = reader.readTree();

  final lastIn = <String, ({String nodeKey, SliceCoordinate at})>{};
  var nodes = 0;
  var ties = 0;
  var backwards = 0;
  final samples = <String>[];

  void visit(TipitakaNode node) {
    final fileId = node.contentFileId;
    if (fileId != null) {
      nodes++;
      final at = SliceCoordinate(node.entryPageIndex, node.entryIndexInPage);
      final previous = lastIn[fileId];
      final order = previous == null ? 1 : at.compareTo(previous.at);
      if (order < 0) {
        backwards++;
        _sample(
          samples,
          '$fileId  ${node.nodeKey} at $at follows '
          '${previous!.nodeKey} at ${previous.at}',
        );
      } else if (order == 0) {
        ties++;
      }
      lastIn[fileId] = (nodeKey: node.nodeKey, at: at);
    }
    for (final child in tree.childrenOf(node.nodeKey)) {
      visit(child);
    }
  }

  for (final root in tree.roots) {
    visit(root);
  }

  stdout.writeln('READING ORDER');
  stdout.writeln('  content files         ${lastIn.length}');
  stdout.writeln('  nodes with text       $nodes');
  stdout.writeln('  shared coordinates    $ties '
      '(legal — a root printed on its first child\'s heading block)');
  stdout.writeln('  steps backwards       $backwards');
  _printSamples(samples);

  return backwards == 0;
}

// ---------------------------------------------------------------------------
// 5. The content table says exactly what the JSON says
// ---------------------------------------------------------------------------

/// Full-corpus parity between `assets/text/*.json` and the `bjt_content` table
/// that is about to replace it as the app's runtime source
/// (`docs/todo/retiring-dart-server/reduce_mobile_bundle_size.md`).
///
/// **Written before the table exists, on purpose.** Without it, a populate bug
/// touching only the Vinaya files — or only Sinhala sections, or only pages
/// past the 200th — ships silently: the reader renders whatever it is handed,
/// and search counts rows without reading them.
///
/// **The contract it pins.** One row per (file, page index, language), holding
/// the compressed bytes of that page's JSON substructure *verbatim* — the same
/// object `pages[i]['pali']` decodes to, entries and footnotes and all. Not a
/// remodelled one: Node writes this table and Dart reads it, so anything
/// app-shaped in the blob is a format two runtimes have to agree about twice.
///
/// **And it is Dart that reads.** A Node-side self-check would prove Node can
/// read what Node wrote, which is not the question — the question is whether
/// `GZipCodec`/`ZLibCodec` inflate it on the platforms the app ships to. So
/// the format is sniffed from the frame rather than assumed, and reported.
///
/// Costs a second full read of the corpus on top of section 1.
/// Returns null when there is nothing to check yet — no database, or one that
/// predates step 5. Neither is a pass, and neither is a failure.
bool? _verifyContent(
  CorpusReader reader,
  String dbPath, {
  required bool named,
}) {
  stdout.writeln('CONTENT');
  final file = File(dbPath);
  if (!file.existsSync()) {
    // A path typed by hand that does not exist is a typo, and saying "skipped"
    // to someone who believes they named a database is the whole of finding 4.
    if (named) {
      stdout.writeln('  ! no database at $dbPath');
      return false;
    }
    stdout.writeln('  SKIPPED — no database at $dbPath.');
    stdout.writeln('            Build it with tools/bjt-fts-populate.js.');
    return null;
  }

  // Strictly read-only, which `OpenMode.readOnly` alone does not give: on a WAL
  // database that still touches the -shm sidecar. `immutable=1` skips the WAL
  // machinery altogether, so the bundled asset and both sidecars are left
  // byte-for-byte and mtime-for-mtime alone.
  //
  // The cost is that SQLite then ignores the -wal, so a database with frames
  // still in it would read stale — exactly the false assurance this section
  // exists to prevent. Refuse rather than read it.
  final wal = File('$dbPath-wal');
  if (wal.existsSync() && wal.lengthSync() > 0) {
    stdout.writeln('  ! $dbPath has ${wal.lengthSync()} bytes of '
        'un-checkpointed WAL, which a read-only open must ignore.');
    stdout.writeln("    Checkpoint first: sqlite3 '$dbPath' "
        "'PRAGMA wal_checkpoint(TRUNCATE);'");
    return false;
  }

  final db = sqlite3.open(
    '${Uri.file(file.absolute.path)}?immutable=1',
    uri: true,
    mode: OpenMode.readOnly,
  );
  try {
    final tables = db.select(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      ['bjt_content'],
    );
    if (tables.isEmpty) {
      // The normal state until step 5 runs. Skipping here is what lets this
      // section arm itself later with no flag and no checklist item.
      stdout.writeln('  SKIPPED — $dbPath has no bjt_content table yet.');
      stdout.writeln('            Step 5 of the migration plan creates it.');
      return null;
    }

    final rowsInTable =
        db.select('SELECT COUNT(*) AS n FROM bjt_content').first['n'] as int;
    final byFile = db.prepare(
      'SELECT pageIndex, language, blob FROM bjt_content WHERE filename = ?',
    );

    var rowsExpected = 0;
    var rowsFound = 0;
    var rowsMissing = 0;
    var typeFails = 0;
    var frameFails = 0;
    var inflateFails = 0;
    var entriesCompared = 0;
    var textDiffs = 0;
    var footnoteDiffs = 0;
    var shapeDiffs = 0;
    var storedBytes = 0;
    var inflatedBytes = 0;
    final formats = <String>{};

    // One bucket per failure kind, not one shared list: a half-populated table
    // produces tens of thousands of "missing" lines, and they would otherwise
    // spend every sample slot and hide the row that was actually corrupt.
    final missingSamples = <String>[];
    final typeSamples = <String>[];
    final frameSamples = <String>[];
    final inflateSamples = <String>[];
    final entrySamples = <String>[];
    final footnoteSamples = <String>[];
    final shapeSamples = <String>[];

    for (final source in _contentFiles(reader)) {
      final id = _fileIdOf(source);
      final decoded =
          json.decode(source.readAsStringSync()) as Map<String, dynamic>;
      final pages = (decoded['pages'] as List<dynamic>?) ?? const [];

      // One query per file, indexed into by the two keys that identify a row.
      // Held as Object?, because `as Uint8List` on a column the populate script
      // filled with TEXT throws — killing the run with a stack trace where a
      // named failure belongs. Wrong type is a finding, not a crash.
      final stored = <String, Object?>{};
      for (final row in byFile.select([id])) {
        stored['${row['pageIndex']}/${row['language']}'] = row['blob'];
      }

      for (var pageIndex = 0; pageIndex < pages.length; pageIndex++) {
        final page = pages[pageIndex] as Map<String, dynamic>;
        for (final language in const ['pali', 'sinh']) {
          final expected = page[language];
          if (expected == null) continue; // no such side on this page
          rowsExpected++;

          final key = '$pageIndex/$language';
          if (!stored.containsKey(key)) {
            rowsMissing++;
            _sample(missingSamples, '$id page $pageIndex $language');
            continue;
          }
          rowsFound++;
          final where = '$id page $pageIndex $language';

          final raw = stored[key];
          if (raw is! Uint8List) {
            typeFails++;
            _sample(typeSamples,
                '$where: the column holds ${_shapeOf(raw)}, not a BLOB');
            continue;
          }
          final blob = raw;
          storedBytes += blob.length;

          // The contract is gzip or zlib. Anything else is a violation even
          // when it decodes perfectly: uncompressed JSON round-trips clean and
          // would otherwise pass at 100% ratio, which is the single most likely
          // populate mistake reading as a green run.
          final format = _frameOf(blob);
          formats.add(format);
          if (format != 'gzip' && format != 'zlib') {
            frameFails++;
            _sample(frameSamples,
                '$where: $format frame — the contract is gzip or zlib');
          }

          final List<int> plain;
          try {
            plain = switch (format) {
              'gzip' => gzip.decode(blob),
              'zlib' => zlib.decode(blob),
              // Already counted above. Read it anyway, so the run also says
              // whether the content underneath was right.
              _ => blob,
            };
          } catch (error) {
            inflateFails++;
            _sample(inflateSamples,
                '$id page $pageIndex $language ($format): $error');
            continue;
          }
          inflatedBytes += plain.length;

          final Object? actual;
          try {
            actual = json.decode(utf8.decode(plain));
          } catch (error) {
            inflateFails++;
            _sample(inflateSamples,
                '$id page $pageIndex $language: not JSON — $error');
            continue;
          }

          final expectedMap = expected as Map<String, dynamic>;
          final actualMap = actual is Map<String, dynamic> ? actual : null;
          if (actualMap == null) {
            shapeDiffs++;
            _sample(shapeSamples, '$where: blob is not a JSON object');
            continue;
          }

          // The two fields the migration is actually about, named separately
          // so a divergence says which one moved.
          final expectedEntries =
              (expectedMap['entries'] as List<dynamic>?) ?? const [];
          final actualEntries =
              (actualMap['entries'] as List<dynamic>?) ?? const [];
          entriesCompared += expectedEntries.length;
          if (!_deepEquals(expectedEntries, actualEntries)) {
            textDiffs++;
            _sample(entrySamples, '$where: '
                '${_firstEntryDivergence(expectedEntries, actualEntries)}');
          }
          if (!_deepEquals(
              expectedMap['footnotes'], actualMap['footnotes'])) {
            footnoteDiffs++;
            _sample(footnoteSamples, '$where: '
                '${_footnoteShape(expectedMap)} in source, '
                '${_footnoteShape(actualMap)} in table');
          }

          // Anything else the page carried. Not decoration: whatever is here
          // today is what the reader may start needing tomorrow.
          final otherKeys = {...expectedMap.keys, ...actualMap.keys}
            ..removeAll(const ['entries', 'footnotes']);
          for (final key in otherKeys) {
            if (!_deepEquals(expectedMap[key], actualMap[key])) {
              shapeDiffs++;
              _sample(shapeSamples, '$where: key "$key" diverges');
            }
          }
        }
      }
    }
    byFile.dispose();

    final rowsExtra = rowsInTable - rowsFound;
    final ratio = inflatedBytes == 0
        ? 0.0
        : storedBytes / inflatedBytes;

    stdout.writeln('  database              $dbPath');
    stdout.writeln('  rows in table         $rowsInTable');
    stdout.writeln('  rows expected         $rowsExpected '
        '(one per page per language)');
    stdout.writeln('  rows missing          $rowsMissing');
    stdout.writeln('  rows not in corpus    $rowsExtra');
    stdout.writeln('  wrong column type     $typeFails '
        '(not a BLOB)');
    stdout.writeln('  frames seen           '
        '${(formats.toList()..sort()).join(', ')}');
    stdout.writeln('  frame violations      $frameFails '
        '(contract is gzip or zlib)');
    stdout.writeln('  inflate/decode fails  $inflateFails');
    stdout.writeln('  entries compared      $entriesCompared');
    stdout.writeln('  entry divergences     $textDiffs');
    stdout.writeln('  footnote divergences  $footnoteDiffs');
    stdout.writeln('  other key divergences $shapeDiffs');
    stdout.writeln('  stored / inflated     ${_mb(storedBytes)} / '
        '${_mb(inflatedBytes)} MB '
        '(${(ratio * 100).toStringAsFixed(1)}% of plain JSON)');
    _printSamples(missingSamples, 'missing rows');
    _printSamples(typeSamples, 'column type');
    _printSamples(frameSamples, 'frame');
    _printSamples(inflateSamples, 'inflate / decode');
    _printSamples(entrySamples, 'entries');
    _printSamples(footnoteSamples, 'footnotes');
    _printSamples(shapeSamples, 'shape');

    return rowsMissing == 0 &&
        rowsExtra == 0 &&
        typeFails == 0 &&
        frameFails == 0 &&
        inflateFails == 0 &&
        textDiffs == 0 &&
        footnoteDiffs == 0 &&
        shapeDiffs == 0;
  } finally {
    db.dispose();
  }
}

/// Which compression frame [bytes] opens with, by magic number.
///
/// Sniffed rather than configured because the populate script picks it, and
/// this check exists to find out what it picked. gzip and zlib are both legal
/// and interchangeable here; every other answer — including plainly readable
/// JSON — is a contract violation the caller counts and fails on.
String _frameOf(Uint8List bytes) {
  if (bytes.length < 2) return 'empty';
  if (bytes[0] == 0x1f && bytes[1] == 0x8b) return 'gzip';
  // RFC 1950: low nibble 8 = deflate, and the two header bytes are a
  // multiple of 31.
  if ((bytes[0] & 0x0f) == 0x08 && ((bytes[0] << 8) | bytes[1]) % 31 == 0) {
    return 'zlib';
  }
  if (bytes[0] == 0x7b || bytes[0] == 0x5b) return 'uncompressed';
  return 'unknown';
}

/// Names the first entry that differs, for the sample line.
String _firstEntryDivergence(List<dynamic> expected, List<dynamic> actual) {
  if (expected.length != actual.length) {
    return '${expected.length} entries in source, ${actual.length} in table';
  }
  for (var i = 0; i < expected.length; i++) {
    if (_deepEquals(expected[i], actual[i])) continue;

    // A corrupt blob is precisely where a non-map entry turns up, so this has
    // to name it rather than die casting it.
    final source = expected[i];
    final table = actual[i];
    if (source is! Map || table is! Map) {
      return 'entry $i is ${_shapeOf(source)} in source, '
          '${_shapeOf(table)} in table';
    }

    final sourceText = source['text'];
    final tableText = table['text'];
    if (sourceText is! String || tableText is! String) {
      return 'entry $i text is ${_shapeOf(sourceText)} in source, '
          '${_shapeOf(tableText)} in table';
    }
    if (sourceText != tableText) {
      return 'entry $i text: "${_clip(sourceText, 40)}" vs '
          '"${_clip(tableText, 40)}"';
    }
    return 'entry $i differs outside its text (type or level)';
  }

  // Unreachable from the only caller, which asks solely about lists
  // `_deepEquals` rejected: equal lengths with no differing index means equal.
  return 'lists compare unequal but no index differs — check _deepEquals';
}

/// A short, safe name for whatever turned up where something else belonged.
String _shapeOf(Object? value) => switch (value) {
      null => 'absent',
      Map() => 'an object',
      List() => 'a list',
      String() => 'a string',
      _ => _withArticle('${value.runtimeType}'),
    };

String _withArticle(String noun) =>
    'aeiou'.contains(noun[0].toLowerCase()) ? 'an $noun' : 'a $noun';

/// How a section's `footnotes` key presents. An absent key and an empty list
/// are different populate bugs, and `?? 0` printed them identically.
String _footnoteShape(Map<String, dynamic> section) {
  if (!section.containsKey('footnotes')) return 'absent';
  return switch (section['footnotes']) {
    null => 'null',
    final List<dynamic> list => '${list.length}',
    final Object other => _withArticle('${other.runtimeType}'),
  };
}

bool _deepEquals(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_deepEquals(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;
      if (!_deepEquals(a[key], b[key])) return false;
    }
    return true;
  }
  return a == b;
}

String _mb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);

/// The `!` lines under a section's counters. [label] names the failure kind,
/// and is only needed where a section keeps more than one bucket.
void _printSamples(List<String> samples, [String? label]) {
  final prefix = label == null ? '' : '$label: ';
  for (final sample in samples) {
    stdout.writeln('  ! $prefix$sample');
  }
}

// ---------------------------------------------------------------------------
// Frozen oracles — pre-extraction app implementations. Do not "improve".
// ---------------------------------------------------------------------------

String _oldPlainText(String rawText) => rawText
    .replaceAll('**', '')
    .replaceAll('__', '')
    .replaceAll(RegExp(r'\{[^}]*\}'), '');

List<({int start, int end})> _oldMarkedRanges(String rawText) {
  final ranges = <({int start, int end})>[];
  final raw = rawText;
  final len = raw.length;
  var i = 0;
  var plainIndex = 0;
  var inMarked = false;
  var markedStart = 0;

  while (i < len) {
    if (i + 1 < len && raw[i] == '*' && raw[i + 1] == '*') {
      if (!inMarked) {
        inMarked = true;
        markedStart = plainIndex;
      } else {
        inMarked = false;
        if (plainIndex > markedStart) {
          ranges.add((start: markedStart, end: plainIndex));
        }
      }
      i += 2;
      continue;
    }
    if (i + 1 < len && raw[i] == '_' && raw[i + 1] == '_') {
      i += 2;
      continue;
    }
    if (raw[i] == '{') {
      final closeBrace = raw.indexOf('}', i);
      if (closeBrace != -1) {
        i = closeBrace + 1;
        continue;
      }
    }
    plainIndex++;
    i++;
  }

  if (inMarked && plainIndex > markedStart) {
    ranges.add((start: markedStart, end: plainIndex));
  }
  return ranges;
}

int? _oldExtractChildIndex(String nodeKey) {
  final parts = nodeKey.split('-');
  if (parts.isEmpty) return null;
  return int.tryParse(parts.last);
}

// ---------------------------------------------------------------------------

bool _sameRanges(
  List<({int start, int end})> a,
  List<({int start, int end})> b,
) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].start != b[i].start || a[i].end != b[i].end) return false;
  }
  return true;
}

/// Every `assets/text/*.json`, in a stable order.
List<File> _contentFiles(CorpusReader reader) =>
    Directory('${reader.assetsPath}/text')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

/// `dn-1` from `.../assets/text/dn-1.json`.
String _fileIdOf(File file) =>
    file.uri.pathSegments.last.replaceAll('.json', '');

void _sample(List<String> into, String line) {
  if (into.length < 5) into.add(line);
}

String _clip(String text, [int max = 60]) =>
    text.length <= max ? text : '${text.substring(0, max)}…';

/// Whether [flag] was typed at all, with or without a value after it.
bool _flagGiven(List<String> args, String flag) =>
    args.any((a) => a == flag || a.startsWith('$flag='));

String? _valueOf(List<String> args, String flag) {
  for (var i = 0; i < args.length; i++) {
    if (args[i] == flag && i + 1 < args.length) return args[i + 1];
    if (args[i].startsWith('$flag=')) return args[i].substring(flag.length + 1);
  }
  return null;
}
