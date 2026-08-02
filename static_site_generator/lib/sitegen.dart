import 'dart:io';

import 'package:wisdom_shared/wisdom_shared.dart';

import 'data/corpus_reader.dart';
import 'data/slicer_cache.dart';
import 'domain/document.dart';
import 'domain/grouping_classifier.dart';
import 'domain/site_page.dart';
import 'domain/theme_tokens.dart';
import 'manifest/build_manifest.dart';
import 'render/page_template.dart';
import 'render/stylesheet.dart';
import 'render/web_fonts.dart';

/// Version stamped into `<meta name="generator">` and `.manifest.json`.
/// Bump by hand; it is not a build id (§11.8 forbids anything that changes per
/// run).
const String generatorVersion = '0.1.0';

/// What a build produced.
class BuildReport {
  final int suttaPages;
  final int chapterPages;
  final int tocPages;
  final int contentFilesParsed;

  const BuildReport({
    required this.suttaPages,
    required this.chapterPages,
    required this.tocPages,
    required this.contentFilesParsed,
  });

  int get total => suttaPages + chapterPages + tocPages;
}

/// classify → slice → render → write.
///
/// The use case. Everything it calls is either a pure transform (`domain/`,
/// `render/`) or a reader (`data/`); this is the only place the two meet, and —
/// with `BuildManifest.writeTo` — the only place that writes.
class SiteGenerator {
  final CorpusReader reader;
  final TipitakaTree tree;
  final ThemeTokens tokens;

  /// Directory that receives `tipitaka/`, `assets/`, `fonts/`.
  final String outputDir;

  SiteGenerator({
    required this.reader,
    required this.tree,
    required this.tokens,
    required this.outputDir,
  });

  BuildReport generate(List<String> rootKeys) {
    _clearOutputDir();
    final cache = SlicerCache(reader: reader, tree: tree);
    final classifier = GroupingClassifier(tree: tree, slicerFor: cache.forFile);

    // Verdicts first, and memoised: SitePlan asks for a container's verdict as
    // it walks, and the renderer would otherwise re-slice whole vaggas to
    // re-derive an answer already known.
    final verdicts = <String, GroupingVerdict>{};
    GroupingVerdict classify(TipitakaNode container) =>
        verdicts[container.nodeKey] ??= classifier.classify(container);

    final plan =
        SitePlan.build(tree: tree, rootKeys: rootKeys, classify: classify);
    final template =
        PageTemplate(tree: tree, generatorVersion: generatorVersion);
    final manifest = BuildManifest();

    var suttaPages = 0;
    var chapterPages = 0;
    var tocPages = 0;

    for (final page in plan.pages) {
      final sourceFileId = _sourceFileOf(page);
      if (sourceFileId == null) {
        // Cannot fire on the vendored corpus. Throws rather than warns because
        // skipping the page would leave a 404 that the site's own breadcrumbs,
        // TOCs and pagers still link to.
        throw StateError(
          'Page "${page.nodeKey}" (${page.kind.name}) has no content file. '
          'Its URL is already linked from its parent and siblings, so it '
          'cannot be skipped. Re-check assets/data/tree.json after a re-sync.',
        );
      }

      final slices = <String, NodeSlice>{};
      for (final sutta in page.suttas) {
        // A container's leaves can live in a different file than the container
        // itself — 10 of them do — so each sutta resolves its own.
        final fileId = sutta.contentFileId;
        if (fileId == null) {
          throw StateError(
            'Sutta "${sutta.nodeKey}" has no content file, so its text would '
            'be silently missing from "${page.nodeKey}".',
          );
        }
        slices[sutta.nodeKey] = cache.forFile(fileId).sliceFor(sutta.nodeKey);
      }

      // The container's own slice is its preamble. On a leaf page there is
      // none: a leaf owns its rows outright.
      NodeSlice? preamble;
      if (page.kind != PageKind.sutta) {
        preamble = cache.forFile(sourceFileId).sliceFor(page.nodeKey);
      }

      final html = template.render(
        page,
        slices: slices,
        preamble: preamble,
        previous: plan.previousOf(page),
        next: plan.nextOf(page),
        sourceFile: sourceFileId,
      );

      _write('$outputDir/${page.outputPath}', html);
      manifest.record(
        sourceFileId: sourceFileId,
        outputPath: page.outputPath,
        sourceHash: reader.contentFileHash(sourceFileId),
      );

      switch (page.kind) {
        case PageKind.sutta:
          suttaPages++;
        case PageKind.chapter:
          chapterPages++;
        case PageKind.toc:
          tocPages++;
      }
    }

    _write('$outputDir/assets/site.css', buildStylesheet(tokens));
    _copyFonts();
    manifest.writeTo('$outputDir/.manifest.json',
        generatorVersion: generatorVersion);

    return BuildReport(
      suttaPages: suttaPages,
      chapterPages: chapterPages,
      tocPages: tocPages,
      contentFilesParsed: cache.parses,
    );
  }

  /// Empties the output directory before writing into it.
  ///
  /// The build only ever *adds* files, so without this a page that stops
  /// existing — a vagga crossing the grouping threshold after an upstream
  /// re-sync, a nodeKey that shifts — leaves its old HTML behind, and
  /// Cloudflare happily serves the orphan. §11.8's byte-determinism covers
  /// building the *same* input twice; it says nothing about building a changed
  /// one, which is exactly when stale files appear.
  ///
  /// A wipe rather than a reconcile against `.manifest.json`: the manifest
  /// lists pages, not `assets/` or `fonts/`, and a full rebuild takes 85 ms.
  ///
  /// **It will only wipe a directory it recognises as its own.** `outputDir`
  /// comes from `--out`, so a recursive delete here is one typo away from
  /// eating a directory that matters. An empty directory is fine to claim, and
  /// so is one holding a previous build (`.manifest.json` is the marker, which
  /// only this generator writes). Anything else stops the build.
  void _clearOutputDir() {
    final directory = Directory(outputDir);
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
      return;
    }

    // Probed directly rather than matched against `listSync()` paths: those are
    // joined with the platform separator, so a suffix test would silently never
    // fire on Windows and refuse every rebuild.
    final isPreviousBuild = File('$outputDir/.manifest.json').existsSync();
    if (directory.listSync().isNotEmpty && !isPreviousBuild) {
      throw StateError(
        '"$outputDir" is not empty and holds no .manifest.json, so it does not '
        'look like a directory this generator produced. Refusing to delete it. '
        'Point --out at a new or previously-generated directory.',
      );
    }

    directory.deleteSync(recursive: true);
    directory.createSync(recursive: true);
  }

  /// Which content file a page's text comes from.
  String? _sourceFileOf(SitePage page) =>
      page.node.contentFileId ??
      (page.suttas.isEmpty ? null : page.suttas.first.contentFileId);

  /// Copies the committed WOFF2 subsets (D7).
  ///
  /// Fonts are a build **input**, like `theme_tokens.json`: `subset_fonts.sh`
  /// is run by hand and its output committed, so the build loop stays pure Dart
  /// with no Python in it. Here we only move bytes.
  ///
  /// Driven by [webFontFaces] — the same list the stylesheet writes its
  /// `@font-face` rules from — so the site ships exactly the faces it declares.
  /// Globbing `assets/fonts/` instead would also copy the Latin-only families
  /// the Flutter app bundles, which no CSS rule here names.
  void _copyFonts() {
    final source = Directory('${reader.assetsPath}/fonts');
    if (!source.existsSync()) {
      stderr.writeln('WARNING  ${source.path} missing — no fonts copied.');
      return;
    }

    final missing = <String>[];
    for (final face in webFontFaces(tokens)) {
      final file = File('${source.path}/${face.relativePath}');
      if (!file.existsSync()) {
        missing.add(face.relativePath);
        continue;
      }
      final target = File('$outputDir/fonts/${face.relativePath}');
      target.parent.createSync(recursive: true);
      target.writeAsBytesSync(file.readAsBytesSync());
    }

    if (missing.isEmpty) return;
    stderr.writeln(
      'WARNING  ${missing.length} of the declared WOFF2 faces are not in '
      '${source.path} (${missing.first}${missing.length > 1 ? ', …' : ''}). '
      'Those pages fall back to a system Sinhala face, which is NOT the face '
      'the conjuncts were verified against. Fix: run '
      'assets/fonts/subset_fonts.sh and commit its *-Subset.woff2 output '
      '(needs `pip install "fonttools[woff]"`).',
    );
  }

  void _write(String path, String contents) {
    final file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(contents);
  }
}
