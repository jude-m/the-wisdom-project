/// Renders a single [Entry] as semantic HTML.
///
/// This is the web re-expression of text_entry_widget.dart's marker handling:
/// `**bold**` ranges become real <strong> elements (via [Entry.markedRanges],
/// the domain logic ported 1:1 from the app), `__underline__` and
/// `{footnote}` markers are stripped by [Entry.plainText].
library;

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../domain/entry.dart';

/// Builds the entry's text as a list of text/<strong> spans.
List<Component> _markedSpans(Entry entry) {
  final plain = entry.plainText;
  final ranges = entry.markedRanges;
  if (ranges.isEmpty) return [.text(plain)];

  final spans = <Component>[];
  int cursor = 0;
  for (final range in ranges) {
    if (range.start > cursor) {
      spans.add(.text(plain.substring(cursor, range.start)));
    }
    spans.add(strong([.text(plain.substring(range.start, range.end))]));
    cursor = range.end;
  }
  if (cursor < plain.length) {
    spans.add(.text(plain.substring(cursor)));
  }
  return spans;
}

/// Maps an entry to an HTML element by [EntryType] (CSS does the styling).
/// [anchorId] (`e-<page>-<lang>-<entry>`) makes every entry deep-scrollable —
/// search results scroll to their matched entry through this.
Component entryView(Entry entry, String anchorId) {
  final spans = _markedSpans(entry);
  switch (entry.entryType) {
    case EntryType.heading:
      // BJT heading levels: 5 = book title … 1 = sub-section.
      final level = entry.level ?? 1;
      final classes = 'entry heading level-$level';
      if (level >= 4) return h2(id: anchorId, classes: classes, spans);
      if (level >= 2) return h3(id: anchorId, classes: classes, spans);
      return h4(id: anchorId, classes: classes, spans);
    case EntryType.centered:
      return p(id: anchorId, classes: 'entry centered', spans);
    case EntryType.gatha:
      return p(id: anchorId, classes: 'entry gatha', spans);
    case EntryType.unindented:
      return p(id: anchorId, classes: 'entry unindented', spans);
    case EntryType.paragraph:
      return p(id: anchorId, classes: 'entry', spans);
  }
}
