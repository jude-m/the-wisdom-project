import 'package:test/test.dart';
import 'package:wisdom_shared/wisdom_shared.dart';

/// Guards the inline marker grammar shared by the Flutter app and the
/// static-site generator.
///
/// The extraction into `wisdom_shared` was justified by a differential run over
/// all 466,127 corpus entries with zero divergences. That run cannot live in CI
/// — it needs the 340 MB corpus — so it survives as
/// `static_site_generator/tool/verify_corpus_invariants.dart`, and the
/// *invariants it proved* survive here.
///
/// The oracle below is the pre-extraction implementation, copied verbatim from
/// `Entry` as it stood at commit 4bb320c. Nothing in `lib/` may be changed to
/// make these pass — the whole point is that the oracle is frozen.
void main() {
  group('stripMarkers matches the pre-extraction algorithm', () {
    for (final raw in _cases) {
      test(_describe(raw), () {
        expect(ContentMarkers.stripMarkers(raw), _oldPlainText(raw));
      });
    }
  });

  group('boldRanges matches the pre-extraction algorithm', () {
    for (final raw in _cases) {
      test(_describe(raw), () {
        expect(ContentMarkers.boldRanges(raw), _oldMarkedRanges(raw));
      });
    }
  });

  group('segments reconstruct the stripped text exactly', () {
    for (final raw in [..._cases, _fabricationHazard]) {
      test(_describe(raw), () {
        final rebuilt =
            parseContentMarkers(raw).map((s) => s.text).join();
        expect(rebuilt, ContentMarkers.stripMarkers(raw));
      });
    }
  });

  group('markers are toggles, not matched delimiters', () {
    // 12 corpus entries have an odd number of `**`. A delimiter-matching parser
    // would throw or drop the tail; the toggle leaves bold on to end-of-entry.
    test('unclosed ** stays bold to the end', () {
      const raw = 'plain **bold to the end';
      // Ranges are in stripped coordinates: 'plain bold to the end' is 21
      // characters, so the open span closes at 21, not at the raw length of 23.
      expect(ContentMarkers.stripMarkers(raw), hasLength(21));
      expect(ContentMarkers.boldRanges(raw), [(start: 6, end: 21)]);
      expect(parseContentMarkers(raw).last.bold, isTrue);
    });

    test('unclosed __ stays underlined to the end', () {
      expect(parseContentMarkers('plain __under').last.underline, isTrue);
    });

    test('empty span **** produces no range', () {
      expect(ContentMarkers.boldRanges('a****b'), isEmpty);
    });

    test('adjacent spans stay separate, not merged', () {
      // Deliberate: one range per toggle pair, so this is a drop-in for the
      // app's previous Entry.markedRanges rather than a tidier reading of it.
      expect(ContentMarkers.boldRanges('**a****b**'), [
        (start: 0, end: 1),
        (start: 1, end: 2),
      ]);
    });

    test('bold and underline nest in either order', () {
      final boldOuter = parseContentMarkers('**b __bu__ b**');
      expect(boldOuter.every((s) => s.bold), isTrue);
      expect(boldOuter.where((s) => s.underline).map((s) => s.text), ['bu']);

      final underlineOuter = parseContentMarkers('__u **ub** u__');
      expect(underlineOuter.every((s) => s.underline), isTrue);
      expect(underlineOuter.where((s) => s.bold).map((s) => s.text), ['ub']);
    });
  });

  group('footnote labels are strings, not ints', () {
    // 1,097 of the corpus's 30,514 refs are non-numeric. Typing the field as
    // `int?` silently discards every one of them.
    for (final label in ['12', '*', 'a', 'o', '†', '‡', 'එම']) {
      test('"$label" survives parsing', () {
        final segments = parseContentMarkers('විහරති{$label} sesā');
        final footnotes = segments.where((s) => s.isFootnote).toList();
        expect(footnotes, hasLength(1));
        expect(footnotes.single.footnoteLabel, label);
        expect(footnotes.single.text, isEmpty);
      });
    }

    test('footnoteRefs report offsets in stripped coordinates', () {
      const raw = '**සාවත්ථියං** විහරති{12}{*}';
      final plain = ContentMarkers.stripMarkers(raw);
      expect(ContentMarkers.footnoteRefs(raw), [
        (offset: plain.length, label: '12'),
        (offset: plain.length, label: '*'),
      ]);
    });

    test('an unclosed { is literal text, matching the old regex', () {
      // RegExp(r'\{[^}]*\}') needs the closing brace, so `{12` was never
      // stripped. It still is not.
      expect(ContentMarkers.stripMarkers('විහරති{12'), 'විහරති{12');
      expect(ContentMarkers.footnoteRefs('විහරති{12'), isEmpty);
    });

    test('an empty label {} is still a footnote event', () {
      expect(ContentMarkers.footnoteRefs('a{}b').single.label, isEmpty);
    });
  });

  group('footnote segments carry the style of the span they sit in', () {
    ContentSegment footnoteIn(String raw) =>
        parseContentMarkers(raw).firstWhere((s) => s.isFootnote);

    test('outside any span: neither flag', () {
      final footnote = footnoteIn('plain{12} text');
      expect(footnote.bold, isFalse);
      expect(footnote.underline, isFalse);
    });

    test('inside **bold**: bold', () {
      expect(footnoteIn('**මනොසෙට්ඨා{12}**').bold, isTrue);
    });

    test('inside __underline__: underline', () {
      expect(footnoteIn('__text{12}__').underline, isTrue);
    });

    test('inside both: both', () {
      final footnote = footnoteIn('**__text{12}__**');
      expect(footnote.bold, isTrue);
      expect(footnote.underline, isTrue);
    });

    test('a span containing only a footnote keeps its style', () {
      // The exact shape of the Vibhaṅgavagga uddāna in mn-3-4.json — the one
      // corpus entry where a `__…__` span wraps nothing but a reference. With
      // the flags cleared this reached a renderer as an unstyled zero-width
      // segment, silently losing the only markup on the line.
      final segments = parseContentMarkers('__{4}__');
      expect(segments, hasLength(1));
      expect(segments.single.isFootnote, isTrue);
      expect(segments.single.underline, isTrue);
      expect(segments.single.text, isEmpty);
    });

    test('style does not leak past the closing marker', () {
      final segments = parseContentMarkers('**a{1}**{2}');
      final footnotes = segments.where((s) => s.isFootnote).toList();
      expect(footnotes.map((f) => f.bold), [true, false]);
    });

    test('carrying style leaves the stripped text untouched', () {
      // Footnote segments are zero-width, so this cannot affect plainText,
      // boldRanges, or the rebuild invariant.
      expect(ContentMarkers.stripMarkers('__{4}__'), isEmpty);
      expect(ContentMarkers.boldRanges('**a{1}b**'), [(start: 0, end: 2)]);
    });
  });

  group('hasMarkers', () {
    test('true for each of the three markers', () {
      expect(ContentMarkers.hasMarkers('a **b**'), isTrue);
      expect(ContentMarkers.hasMarkers('a __b__'), isTrue);
      expect(ContentMarkers.hasMarkers('a{1}'), isTrue);
    });

    test('false for unmarked text', () {
      expect(ContentMarkers.hasMarkers('එවං මෙ සුතං'), isFalse);
    });
  });

  test('the new parser refuses to fabricate a marker', () {
    // The one input class where the walk deliberately disagrees with the old
    // chained replaceAll. Given `_**_`, the old code stripped `**` first, which
    // *created* a `__` that the underline pass then deleted — losing two real
    // characters the source never marked up. No corpus entry triggers this
    // today; the single pass cannot do it at all.
    expect(_oldPlainText(_fabricationHazard), isEmpty);
    expect(ContentMarkers.stripMarkers(_fabricationHazard), '__');
  });
}

/// Input that makes chained `replaceAll` invent a marker. See the final test.
const String _fabricationHazard = '_**_';

/// Representative shapes, including every hazard found in the corpus.
///
/// Excludes [_fabricationHazard], which is the sole deliberate divergence and
/// is asserted separately.
const List<String> _cases = [
  '',
  'එවං මෙ සුතං',
  'එවං මෙ සුතං : එකං සමයං භගවා **සාවත්ථියං** විහරති{12}',
  '**bold**',
  '**',
  '****',
  '**a****b**',
  'plain **bold to the end',
  '__underline__',
  '__',
  '**b __bu__ b**',
  '__u **ub** u__',
  'a{1}b{*}c{එම}',
  'a{}b',
  'trailing brace {12',
  '}orphan close',
  '{}',
  '*single asterisk*',
  '_single underscore_',
  '***triple***',
  'මනොපුබ්බඞ්ගමා ධම්මා{3} **මනොසෙට්ඨා** මනොමයා',
];

String _describe(String raw) {
  if (raw.isEmpty) return '(empty)';
  return raw.length <= 40 ? raw : '${raw.substring(0, 40)}…';
}

// ---------------------------------------------------------------------------
// Oracle: `Entry.plainText` and `Entry._computeMarkedRanges` as they were
// before the extraction. Frozen — do not "improve".
// ---------------------------------------------------------------------------

String _oldPlainText(String rawText) => rawText
    .replaceAll('**', '')
    .replaceAll('__', '')
    .replaceAll(RegExp(r'\{[^}]*\}'), '');

List<({int start, int end})> _oldMarkedRanges(String rawText) {
  final ranges = <({int start, int end})>[];
  final raw = rawText;
  final len = raw.length;
  int i = 0;
  int plainIndex = 0;
  bool inMarked = false;
  int markedStart = 0;

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
