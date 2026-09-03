import 'dart:convert';
import 'dart:io';

import 'package:static_site_generator/data/corpus_reader.dart';
import 'package:wisdom_shared/wisdom_shared.dart';

/// Full-corpus proof that the extracted `wisdom_shared` logic is behaviourally
/// identical to the app code it replaced.
///
///     dart run static_site_generator/tool/verify_corpus_invariants.dart
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
  if (markersOk && treeOk && linksOk) {
    stdout.writeln('PASS — extraction identical to the app original (1, 2), '
        'and every URL reads back as its own page (3).');
  } else {
    stdout.writeln('FAIL — see divergences above.');
    exitCode = 1;
  }
}

// ---------------------------------------------------------------------------
// 1. Marker grammar, over every entry in the corpus
// ---------------------------------------------------------------------------

bool _verifyMarkers(CorpusReader reader) {
  final files = Directory('${reader.assetsPath}/text')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

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
    final id = file.uri.pathSegments.last.replaceAll('.json', '');
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
  for (final sample in samples) {
    stdout.writeln('  ! $sample');
  }

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
  for (final sample in samples) {
    stdout.writeln('  ! $sample');
  }

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
  for (final sample in samples) {
    stdout.writeln('  ! $sample');
  }

  return parseFails == 0 &&
      roundTripFails == 0 &&
      doorFails == 0 &&
      unplanned == 0 &&
      unprinted == 0;
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

void _sample(List<String> into, String line) {
  if (into.length < 5) into.add(line);
}

String _clip(String text, [int max = 60]) =>
    text.length <= max ? text : '${text.substring(0, max)}…';

String? _valueOf(List<String> args, String flag) {
  for (var i = 0; i < args.length; i++) {
    if (args[i] == flag && i + 1 < args.length) return args[i + 1];
    if (args[i].startsWith('$flag=')) return args[i].substring(flag.length + 1);
  }
  return null;
}
