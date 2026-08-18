/// Parsing for the inline formatting markers used in BJT entry text.
///
/// The corpus stores formatting inline, not as structured data:
///
///     එවං මෙ සුතං : එකං සමයං භගවා **සාවත්ථියං** විහරති{12}
///
/// Three markers exist, and only three:
///
/// | Marker            | Meaning                    | How common          |
/// |-------------------|----------------------------|---------------------|
/// | `**…**`           | bold / emphasised term     | very common         |
/// | `__…__`           | underline                  | rare, and clustered |
/// | `{label}`         | footnote reference         | common              |
///
/// **No corpus counts are written down in this file.**
/// `static_site_generator/tool/verify_corpus_invariants.dart` walks every entry
/// and prints them — entries, footnote references, distinct labels, underline
/// spans — which is the only form of those numbers that cannot go stale. Run it
/// whenever this grammar is touched; that is what it is for.
///
/// One parser, two renderers: Flutter builds `TextSpan`s from
/// [parseContentMarkers], the static-site generator emits
/// `<strong>` / `<u>` / `<sup><a>` from the *same* segments. Keeping the
/// grammar in one pure-Dart place is what stops the two surfaces from drifting.
///
/// **Markers are toggles, not matched delimiters.** `**` flips bold on/off
/// wherever it appears. That matters because a handful of corpus entries carry
/// an odd number of `**`; a delimiter-matching parser would either throw or
/// lose their tail text. A toggle simply leaves the style on to end-of-entry,
/// which is what the app has always rendered.
///
/// Bold and underline nest — some bold spans contain `__`, and a few underline
/// spans contain `**` — but they never *interleave*, verified across every
/// entry in the corpus. So two independent toggles are sufficient and no
/// span-repair is needed.
library;

/// A run of entry text sharing one style, or a single footnote reference.
///
/// Segments are emitted in reading order and, concatenated, reproduce
/// [stripMarkers] exactly. A footnote is a zero-width event: its [text] is
/// empty and [footnoteLabel] is set — but [bold] and [underline] still describe
/// the span it sits in, so a renderer can style the reference to match.
class ContentSegment {
  /// The visible characters of this run, markers already removed.
  final String text;

  /// Rendered `**bold**` — `<strong>` on the web, `FontWeight.bold` in Flutter.
  final bool bold;

  /// Rendered `__underline__`.
  ///
  /// The app currently **drops** underline (see [ContentMarkers.boldRanges]);
  /// this field is what lets either surface start honouring it without another
  /// pass over the grammar.
  final bool underline;

  /// The label inside `{…}`, or null for an ordinary text run.
  ///
  /// Deliberately a `String`, not an `int`. Corpus footnote labels are mostly
  /// numeric, but a substantial minority are not — `*`, `a`–`o`, `†`, `‡` and
  /// `එම` all appear. Typing this as `int?` silently discards every one of
  /// them.
  final String? footnoteLabel;

  const ContentSegment({
    required this.text,
    this.bold = false,
    this.underline = false,
    this.footnoteLabel,
  });

  /// True when this segment is a footnote reference rather than text.
  bool get isFootnote => footnoteLabel != null;

  @override
  bool operator ==(Object other) =>
      other is ContentSegment &&
      other.text == text &&
      other.bold == bold &&
      other.underline == underline &&
      other.footnoteLabel == footnoteLabel;

  @override
  int get hashCode => Object.hash(text, bold, underline, footnoteLabel);

  @override
  String toString() => isFootnote
      ? 'ContentSegment.footnote($footnoteLabel)'
      : 'ContentSegment("$text"${bold ? ' bold' : ''}'
          '${underline ? ' underline' : ''})';
}

/// Splits raw entry text into ordered, styled segments. No Flutter.
///
/// Adjacent characters sharing a style are coalesced into one segment, so a
/// plain paragraph costs exactly one segment.
List<ContentSegment> parseContentMarkers(String raw) {
  final segments = <ContentSegment>[];
  final buffer = StringBuffer();
  var bold = false;
  var underline = false;

  void flush() {
    if (buffer.isEmpty) return;
    segments.add(ContentSegment(
      text: buffer.toString(),
      bold: bold,
      underline: underline,
    ));
    buffer.clear();
  }

  _scan(
    raw,
    onText: buffer.write,
    onBoldToggle: () {
      flush(); // the style change starts a new run
      bold = !bold;
    },
    onUnderlineToggle: () {
      flush();
      underline = !underline;
    },
    onFootnote: (label) {
      flush();
      // Carries the ambient style. A footnote is an event *inside* whatever
      // span encloses it, so `**text{12}**` must mark the reference bold and
      // `__{4}__` must mark it underlined — the latter being a real corpus
      // entry (the Vibhaṅgavagga uddāna in mn-3-4.json) whose entire span is
      // one footnote, and which would otherwise reach a renderer with no
      // styling information at all.
      segments.add(ContentSegment(
        text: '',
        bold: bold,
        underline: underline,
        footnoteLabel: label,
      ));
    },
  );
  flush();

  return segments;
}

/// Marker-level helpers that operate on the *stripped* coordinate space.
///
/// These exist because `Entry` (the Flutter side) has always exposed
/// `plainText` + bold ranges rather than segments, and a large amount of
/// selection/search/highlight code is written against those coordinates.
/// Both are re-implemented here so the app and the generator share one grammar.
abstract final class ContentMarkers {
  /// The text with every marker removed — what the reader actually sees.
  ///
  /// Equivalent to the app's historical
  /// `raw.replaceAll('**','').replaceAll('__','').replaceAll(RegExp(r'\{[^}]*\}'),'')`,
  /// verified character-identical across every corpus entry. The single pass is
  /// also *safer* than chained `replaceAll`s, which can fabricate a marker that
  /// was not in the source: stripping `**` from `_**_` leaves `__`, which the
  /// next pass then deletes as an underline. No corpus entry currently triggers
  /// that, but the walk cannot do it at all.
  static String stripMarkers(String raw) {
    final buffer = StringBuffer();
    _scan(raw, onText: buffer.write);
    return buffer.toString();
  }

  /// Character ranges of `**bold**` text, in [stripMarkers] coordinates,
  /// sorted by start position.
  ///
  /// One range per toggle *pair*, which is why `**a****b**` yields two
  /// adjacent ranges rather than one merged range — preserved deliberately so
  /// this is a drop-in for the app's previous `Entry.markedRanges`.
  ///
  /// Empty spans (`****`) are skipped, and a span left open at end-of-entry is
  /// closed at the end — the odd-`**` entries noted at the top of this file.
  static List<({int start, int end})> boldRanges(String raw) {
    final ranges = <({int start, int end})>[];
    var index = 0; // position in the stripped string
    var inBold = false;
    var boldStart = 0;

    _scan(
      raw,
      onText: (text) => index += text.length,
      onBoldToggle: () {
        if (!inBold) {
          inBold = true;
          boldStart = index;
        } else {
          inBold = false;
          if (index > boldStart) ranges.add((start: boldStart, end: index));
        }
      },
    );

    // Defensive: an unclosed span still renders to end-of-entry.
    if (inBold && index > boldStart) {
      ranges.add((start: boldStart, end: index));
    }
    return ranges;
  }

  /// Every footnote reference in [raw], in order, as `(offset, label)` where
  /// `offset` is the position in [stripMarkers] coordinates.
  static List<({int offset, String label})> footnoteRefs(String raw) {
    final refs = <({int offset, String label})>[];
    var index = 0;
    _scan(
      raw,
      onText: (text) => index += text.length,
      onFootnote: (label) => refs.add((offset: index, label: label)),
    );
    return refs;
  }

  /// True when [raw] contains any marker at all — a cheap pre-filter for
  /// callers that can take a fast path on unformatted text.
  static bool hasMarkers(String raw) =>
      raw.contains('**') || raw.contains('__') || raw.contains('{');
}

/// The single tokenizer every public function above is built on.
///
/// Walks [raw] once, left to right, invoking the callbacks that the caller
/// cares about. Text is delivered in chunks, never character-by-character, so
/// callers that only accumulate length stay O(markers) rather than O(chars).
void _scan(
  String raw, {
  void Function(String text)? onText,
  void Function()? onBoldToggle,
  void Function()? onUnderlineToggle,
  void Function(String label)? onFootnote,
}) {
  final length = raw.length;
  var i = 0;
  var chunkStart = 0;

  // Emits the plain text accumulated since the last marker.
  void emitChunk() {
    if (i > chunkStart) onText?.call(raw.substring(chunkStart, i));
  }

  while (i < length) {
    final char = raw.codeUnitAt(i);

    // `**` — bold toggle.
    if (char == _asterisk && i + 1 < length && raw.codeUnitAt(i + 1) == _asterisk) {
      emitChunk();
      onBoldToggle?.call();
      i += 2;
      chunkStart = i;
      continue;
    }

    // `__` — underline toggle.
    if (char == _underscore &&
        i + 1 < length &&
        raw.codeUnitAt(i + 1) == _underscore) {
      emitChunk();
      onUnderlineToggle?.call();
      i += 2;
      chunkStart = i;
      continue;
    }

    // `{label}` — footnote reference. An unclosed `{` is literal text, which
    // matches the old regex (`\{[^}]*\}` needs the closing brace to match).
    if (char == _openBrace) {
      final close = raw.indexOf('}', i);
      if (close != -1) {
        emitChunk();
        onFootnote?.call(raw.substring(i + 1, close));
        i = close + 1;
        chunkStart = i;
        continue;
      }
    }

    i++;
  }

  emitChunk();
}

const int _asterisk = 0x2A; // *
const int _underscore = 0x5F; // _
const int _openBrace = 0x7B; // {
