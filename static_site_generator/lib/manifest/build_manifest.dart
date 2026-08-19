import 'dart:convert';
import 'dart:io';

/// Path under the output directory. Flat at the root, and dot-prefixed so it
/// sorts away from the site's own directories.
///
/// Named here rather than spelled at each use: `sitegen.dart` writes it and
/// probes for it as the marker that a directory is a previous build, and
/// `site_headers.dart` keeps it out of search results. Three literals is three
/// chances for a rename to leave one of them pointing at nothing.
const String manifestOutputPath = '.manifest.json';

/// `source → [outputs]` plus a content hash per source (plan §10).
///
/// The hashes are computed by `domain/content_hash.dart` and handed in — see
/// the note there for why that function does not live in this file.
///
/// This is what makes a correction cheap (C1): edit one entry in `an-1.json`,
/// its hash changes, and the build regenerates exactly the pages that file
/// feeds — so the git diff shows only the suttas whose HTML actually moved.
///
/// It runs in the opposite direction to the `dc.source` comment each page
/// carries. The manifest decides **what to rebuild**; the page comment says
/// **where a broken page came from**. Both directions get asked, at different
/// times.
class BuildManifest {
  /// Output paths per source file id, insertion-ordered; sorted on write.
  final Map<String, Set<String>> _outputs = {};
  final Map<String, String> _hashes = {};

  void record({
    required String sourceFileId,
    required String outputPath,
    required String sourceHash,
  }) {
    (_outputs[sourceFileId] ??= <String>{}).add(outputPath);
    _hashes[sourceFileId] ??= sourceHash;
  }

  /// Writes `.manifest.json`, sorted throughout.
  ///
  /// Sorted because §11.8 needs byte-identical output on unchanged input:
  /// Cloudflare skips uploading a file whose content hash it already has, so
  /// map ordering that shifts between runs would re-upload the whole site.
  /// There is deliberately **no timestamp** here for the same reason.
  void writeTo(String path, {required String generatorVersion}) {
    final sources = <String, dynamic>{};
    for (final fileId in _outputs.keys.toList()..sort()) {
      sources[fileId] = {
        'hash': _hashes[fileId],
        'outputs': _outputs[fileId]!.toList()..sort(),
      };
    }
    const encoder = JsonEncoder.withIndent('  ');
    File(path).writeAsStringSync('${encoder.convert({
          'generator': 'wisdom-ssg $generatorVersion',
          'sources': sources,
        })}\n');
  }
}
