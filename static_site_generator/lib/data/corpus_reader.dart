import 'dart:convert';
import 'dart:io';

import 'package:wisdom_shared/wisdom_shared.dart';

/// The only layer in the generator that touches the filesystem.
///
/// Everything downstream (`grouping/`, `render/`) takes decoded models and
/// returns strings, which is what keeps those layers unit-testable without a
/// 340 MB corpus on disk.
class CorpusReader {
  /// Absolute or relative path to the app's `assets/` directory.
  ///
  /// The generator reads the *same* vendored assets the app ships — there is no
  /// second copy of the canon, and no build step between them.
  final String assetsPath;

  CorpusReader({required this.assetsPath});

  /// Locates `assets/` by walking up from [start] (defaults to the current
  /// directory), so the generator runs correctly from the repo root or from
  /// inside `static_site_generator/`.
  factory CorpusReader.discover([Directory? start]) {
    var directory = start ?? Directory.current;
    for (var depth = 0; depth < 5; depth++) {
      final candidate = Directory('${directory.path}/assets');
      if (File('${candidate.path}/data/tree.json').existsSync()) {
        return CorpusReader(assetsPath: candidate.path);
      }
      final parent = directory.parent;
      if (parent.path == directory.path) break; // hit the filesystem root
      directory = parent;
    }
    throw StateError(
      'Could not find assets/data/tree.json above ${(start ?? Directory.current).path}. '
      'Run from the repo root, or pass --assets.',
    );
  }

  File get _treeFile => File('$assetsPath/data/tree.json');

  /// Decodes the full navigation tree (16,355 nodes).
  TipitakaTree readTree() {
    final file = _treeFile;
    if (!file.existsSync()) {
      throw StateError('Missing ${file.path}');
    }
    final decoded = json.decode(file.readAsStringSync()) as Map<String, dynamic>;
    return TipitakaTree.fromJson(decoded);
  }

  /// Reads one `assets/text/<fileId>.json` content file.
  ContentFile readContentFile(String fileId) {
    final file = File('$assetsPath/text/$fileId.json');
    if (!file.existsSync()) {
      throw StateError('Missing content file ${file.path}');
    }
    return ContentFile.fromJson(
      fileId,
      json.decode(file.readAsStringSync()) as Map<String, dynamic>,
    );
  }

  /// True when `<fileId>.json` exists — 10 containers reference files that
  /// belong to an ancestor, so callers cannot assume the key names the file.
  bool hasContentFile(String fileId) =>
      File('$assetsPath/text/$fileId.json').existsSync();
}

/// One `assets/text/<id>.json` file: a printed book, page by page.
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
  int get entryCount => pali.length > sinhala.length ? pali.length : sinhala.length;

  /// Pali entry at [index], or null when that side is shorter.
  ContentEntry? paliAt(int index) => index < pali.length ? pali[index] : null;

  /// Sinhala entry at [index], or null when that side is shorter.
  ContentEntry? sinhalaAt(int index) =>
      index < sinhala.length ? sinhala[index] : null;
}

/// A single entry (paragraph, heading, verse line …) as stored in the JSON.
///
/// Kept structurally identical to the app's `Entry` — same five types, same
/// `level`, same marker-bearing [text] — so the two surfaces cannot disagree
/// about what the source says.
class ContentEntry {
  /// One of `paragraph`, `heading`, `centered`, `gatha`, `unindented`.
  /// Unknown values fall back to `paragraph`, matching `EntryTypeExtension`.
  final String type;

  /// Raw text, markers intact: `**bold**`, `__underline__`, `{footnote}`.
  /// Parse with `parseContentMarkers` from wisdom_shared.
  final String text;

  /// Hierarchy level: 1–5 for heading/centered, 1–2 for gatha, null otherwise.
  final int? level;

  /// Set on entries the audio recordings skip (headings, numbering).
  final bool noAudio;

  const ContentEntry({
    required this.type,
    required this.text,
    required this.level,
    required this.noAudio,
  });

  factory ContentEntry.fromJson(Map<String, dynamic> json) {
    final type = (json['type'] as String?)?.toLowerCase() ?? 'paragraph';
    return ContentEntry(
      type: _knownTypes.contains(type) ? type : 'paragraph',
      text: (json['text'] as String?) ?? '',
      level: json['level'] as int?,
      noAudio: (json['noAudio'] as bool?) ?? false,
    );
  }

  /// The reader-visible text, markers removed.
  String get plainText => ContentMarkers.stripMarkers(text);

  static const Set<String> _knownTypes = {
    'paragraph',
    'heading',
    'centered',
    'gatha',
    'unindented',
  };
}
