import 'dart:convert';
import 'dart:io';

import 'package:static_site_generator/data/corpus_reader.dart';
import 'package:wisdom_shared/wisdom_shared.dart';

/// Full-corpus proof that the extracted `wisdom_shared` logic is behaviourally
/// identical to the app code it replaced.
///
///     dart run static_site_generator/tool/verify_corpus_invariants.dart
///
/// **A script *and* a test.** Reading all 285 content files (~340 MB) plus the
/// 4 MB tree costs ~23s, so `test/corpus_tools_test.dart` runs it under the
/// `corpus` tag. Still worth running by hand: only the printout says *what* the
/// corpus looks like.
///
/// The invariants it establishes are also pinned as fast unit tests in
/// `packages/wisdom_shared/test/`; this is the exhaustive backstop, re-run
/// whenever `content_markers.dart` or `tipitaka_tree.dart` is touched, and
/// whenever `assets/` is re-synced from upstream tipitaka.lk.
///
/// Both oracles below are the *pre-extraction* implementations, copied verbatim
/// from commit 4bb320c:
///   - `Entry.plainText` / `Entry._computeMarkedRanges`
///   - `TreeLocalDataSourceImpl._buildTreeStructure` / `_extractChildIndex`
///
/// They are frozen. If one needs changing to make this pass, the extraction
/// changed behaviour and that is the finding.
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
  if (markersOk && treeOk) {
    stdout.writeln('PASS — extracted logic is identical to the app original.');
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

  // These two counts disagreed at 268/267 before footnote segments carried
  // their ambient style: `__{4}__` in mn-3-4.json wraps nothing but a reference,
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
