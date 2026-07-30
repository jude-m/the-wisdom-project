/// One `assets/text/<id>.json` file: a printed book, page by page.
///
/// Entities, not DTOs — `render/`, `grouping/` and the rest of `domain/` all
/// speak in these, so they live here rather than beside the filesystem code
/// that decodes them. `data/corpus_reader.dart` reads the bytes and calls the
/// factories below; nothing here knows what a file is.
///
/// Mirrors: lib/domain/entities/content/entry.dart
/// Same five entry types, same `level`, same marker-bearing text, so the two
/// surfaces cannot disagree about what the source says.
class ContentFile {
  /// The `<id>` part — matches `TipitakaNode.contentFileId`.
  final String fileId;

  /// Printed pages in order. Index into this list is the `pageIndex` half of
  /// every node coordinate and of the `?e=<page>.<entry>` URL parameter.
  final List<ContentPage> pages;

  const ContentFile({required this.fileId, required this.pages});

  factory ContentFile.fromJson(String fileId, Map<String, dynamic> json) {
    final rawPages = (json['pages'] as List<dynamic>?) ?? const [];
    return ContentFile(
      fileId: fileId,
      pages: [
        for (final page in rawPages)
          ContentPage.fromJson(page as Map<String, dynamic>),
      ],
    );
  }
}

/// One printed page, holding parallel Pali and Sinhala entry lists.
///
/// The two lists are *positionally* aligned — entry `n` of [pali] translates
/// entry `n` of [sinhala] — but they are not guaranteed equal in length, so
/// always pair them through [entryCount] rather than zipping blindly.
class ContentPage {
  /// The page number as printed in the book (not the index — books start at 1,
  /// and some carry front matter, so `pageNum != index + 1` in general).
  final int? pageNum;

  final List<ContentEntry> pali;
  final List<ContentEntry> sinhala;

  const ContentPage({
    required this.pageNum,
    required this.pali,
    required this.sinhala,
  });

  factory ContentPage.fromJson(Map<String, dynamic> json) {
    List<ContentEntry> entries(String key) {
      final block = json[key] as Map<String, dynamic>?;
      final raw = (block?['entries'] as List<dynamic>?) ?? const [];
      return [
        for (final entry in raw)
          ContentEntry.fromJson(entry as Map<String, dynamic>),
      ];
    }

    return ContentPage(
      pageNum: json['pageNum'] as int?,
      pali: entries('pali'),
      sinhala: entries('sinh'),
    );
  }

  /// Number of entry slots on this page — the longer of the two languages, so
  /// an untranslated tail is still addressable.
  int get entryCount =>
      pali.length > sinhala.length ? pali.length : sinhala.length;

  /// Pali entry at [index], or null when that side is shorter.
  ContentEntry? paliAt(int index) => index < pali.length ? pali[index] : null;

  /// Sinhala entry at [index], or null when that side is shorter.
  ContentEntry? sinhalaAt(int index) =>
      index < sinhala.length ? sinhala[index] : null;
}

/// A single entry (paragraph, heading, verse line …) as stored in the JSON.
class ContentEntry {
  /// One of `paragraph`, `heading`, `centered`, `gatha`, `unindented`.
  /// Unknown values fall back to `paragraph`, matching `EntryTypeExtension`.
  final String type;

  /// Raw text, markers intact: `**bold**`, `__underline__`, `{footnote}`.
  /// Parse with `parseContentMarkers` from wisdom_shared.
  final String text;

  /// Hierarchy level: 1–5 for heading/centered, 1–2 for gatha, null otherwise.
  final int? level;

  const ContentEntry({
    required this.type,
    required this.text,
    required this.level,
  });

  factory ContentEntry.fromJson(Map<String, dynamic> json) {
    final type = (json['type'] as String?)?.toLowerCase() ?? 'paragraph';
    return ContentEntry(
      type: _knownTypes.contains(type) ? type : 'paragraph',
      text: (json['text'] as String?) ?? '',
      level: json['level'] as int?,
    );
  }

  static const Set<String> _knownTypes = {
    'paragraph',
    'heading',
    'centered',
    'gatha',
    'unindented',
  };
}
