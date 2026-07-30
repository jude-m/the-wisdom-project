import 'dart:convert';
import 'dart:io';

import 'package:wisdom_shared/wisdom_shared.dart';

import '../domain/content_file.dart';
import '../domain/content_hash.dart';
import 'ancestor_dir.dart';

/// The only layer in the generator that touches the filesystem.
///
/// Everything downstream (`domain/`, `grouping/`, `render/`) takes decoded
/// models and returns strings, which is what keeps those layers unit-testable
/// without a 340 MB corpus on disk. The models themselves live in
/// `domain/content_file.dart`; this file only reads bytes and hands them to
/// their factories.
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
    // The landmark is the tree file itself, not the `assets/` directory: an
    // empty or half-copied `assets/` would otherwise match and the failure
    // would surface much later as "missing content file".
    final found = findAncestorDir(
      (directory) =>
          File('${directory.path}/assets/data/tree.json').existsSync(),
      start: start,
    );
    if (found == null) {
      throw StateError(
        'Could not find assets/data/tree.json above '
        '${(start ?? Directory.current).path}. '
        'Run from the repo root, or pass --assets.',
      );
    }
    return CorpusReader(assetsPath: '${found.path}/assets');
  }

  File get _treeFile => File('$assetsPath/data/tree.json');

  /// Decodes the full navigation tree (16,355 nodes).
  TipitakaTree readTree() {
    final file = _treeFile;
    if (!file.existsSync()) {
      throw StateError('Missing ${file.path}');
    }
    final decoded =
        json.decode(file.readAsStringSync()) as Map<String, dynamic>;
    return TipitakaTree.fromJson(decoded);
  }

  /// Reads one `assets/text/<fileId>.json` content file.
  ContentFile readContentFile(String fileId) {
    final raw = _readContentSource(fileId);
    return ContentFile.fromJson(
      fileId,
      json.decode(raw) as Map<String, dynamic>,
    );
  }

  /// Content hash of `<fileId>.json`, for the build manifest.
  ///
  /// Memoised, and normally free: [readContentFile] hashes the bytes while it
  /// still holds them, so by the time the manifest asks — always *after* the
  /// page has been rendered from that file — the answer is already cached. Only
  /// a caller that asks before any parse pays a read.
  ///
  /// Hashing the raw bytes rather than the decoded model is deliberate: the
  /// question is "did the source change?", and a re-serialised model would hide
  /// whitespace-only corrections that are still worth a rebuild.
  String contentFileHash(String fileId) {
    final cached = _hashes[fileId];
    if (cached != null) return cached;
    _readContentSource(fileId); // hashes into _hashes on the way past
    return _hashes[fileId]!;
  }

  /// Reads the raw JSON text, hashing it on the way past.
  String _readContentSource(String fileId) {
    final file = File('$assetsPath/text/$fileId.json');
    if (!file.existsSync()) {
      throw StateError('Missing content file ${file.path}');
    }
    final raw = file.readAsStringSync();
    _hashes[fileId] ??= contentHash(raw);
    return raw;
  }

  final Map<String, String> _hashes = {};
}
