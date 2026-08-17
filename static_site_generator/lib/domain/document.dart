import 'content_file.dart';

/// One row of a content file: the same position on both language sides.
///
/// The BJT JSON stores Pali and Sinhala as two parallel `entries` arrays per
/// printed page, aligned by index. A [DocRow] is one index — the unit the
/// side-by-side and stacked layouts put in a single grid row.
///
/// Either side can be null. That is not corruption: 1,660 pages (all inside the
/// 7 `ap-pat*` Paṭṭhāna files) have lists of different lengths, so the tail of
/// the longer side has no counterpart. Every other file in the corpus pairs
/// perfectly.
class DocRow {
  /// Index into `ContentFile.pages` — the `<page>` half of a `?e=` coordinate.
  final int pageIndex;

  /// The page number as printed in the book, or null when the source omits it.
  /// Used for the in-page citation anchor and, from P7, footnote numbering,
  /// which restarts on every printed page.
  final int? pageNum;

  /// Index within the page's entry lists.
  final int entryIndex;

  final ContentEntry? pali;
  final ContentEntry? sinhala;

  const DocRow({
    required this.pageIndex,
    required this.pageNum,
    required this.entryIndex,
    required this.pali,
    required this.sinhala,
  });

  /// Combined length of both sides' *raw* text, markers included.
  ///
  /// This is the unit the grouping lines count in — see `GroupingPolicy`. Raw
  /// rather than stripped, and *combined* rather than Pali alone, because that
  /// is the convention the locked 1,500 figure was measured under.
  int get rawCharCount =>
      (pali?.text.length ?? 0) + (sinhala?.text.length ?? 0);

  /// True when neither side carries text — nothing to render in any phase.
  ///
  /// The guard a renderer wants, and **not** the same as "the Pali side is
  /// empty": 5,571 rows in the corpus carry Sinhala with an empty Pali
  /// counterpart, and only one row corpus-wide is empty on both sides.
  bool get isEmpty =>
      (pali?.text.isEmpty ?? true) && (sinhala?.text.isEmpty ?? true);
}

/// The rows one tree node owns, in reading order.
///
/// Produced for *every* node, not just readable ones: a container's slice is
/// its **preamble** (the pitaka/nikāya headings, `namo tassa`, the vagga title
/// printed before its first sutta), which belongs on the container's own page.
/// See [ContentSlicer] for why that falls out of the same rule.
class NodeSlice {
  final String nodeKey;

  /// Rows from this node's start coordinate up to the next node's.
  final List<DocRow> rows;

  /// Position of the first row in the file's flattened row list. Kept so the
  /// provenance comment (build plan D8) can name the exact slice a page came
  /// from — `pages[3].pali[4..9]` — which is the first question asked when a
  /// page renders wrong.
  final int startIndex;

  const NodeSlice({
    required this.nodeKey,
    required this.rows,
    required this.startIndex,
  });

  int get rawCharCount {
    var total = 0;
    for (final row in rows) {
      total += row.rawCharCount;
    }
    return total;
  }

  /// `pages[2].pali[4..9]` — the human-readable form of this slice, for the
  /// provenance comment. Reports the coordinate range, which spans pages when
  /// a sutta does.
  String get coordinateRange {
    if (rows.isEmpty) return 'empty';
    final first = rows.first;
    final last = rows.last;
    if (first.pageIndex == last.pageIndex) {
      return 'pages[${first.pageIndex}].[${first.entryIndex}..${last.entryIndex}]';
    }
    return 'pages[${first.pageIndex}].[${first.entryIndex}..] '
        'through pages[${last.pageIndex}].[..${last.entryIndex}]';
  }
}
