import 'dart:convert';
import 'dart:io';

import 'package:static_site_generator/data/corpus_reader.dart';
import 'package:static_site_generator/domain/theme_tokens.dart';
import 'package:static_site_generator/sitegen.dart';

/// Entrypoint for the static HTML site generator.
///
///     dart run static_site_generator/bin/generate.dart --root all
///     dart run static_site_generator/bin/generate.dart --root an-1,atta-an-1
///
/// Writes `static_site_generator/build/` — one HTML file per sutta, one per
/// grouped chapter, one per container TOC, plus `assets/site.css`,
/// `assets/site.js`, `assets/search-index.json`, the copied WOFF2 subsets,
/// `_headers` (browser caching, read by Cloudflare Pages) and `.manifest.json`.
///
/// `--root` takes a **list** because the corpus has seven disjoint roots and a
/// canon subtree links into its `atta-*` twin, which lives under a different
/// one. Building `an-1` alone leaves every අට්ඨකථා link on those pages pointing
/// at a page that was never generated — see [SitePlan.build].
void main(List<String> args) {
  final _Options options;
  try {
    options = _Options.parse(args);
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    stderr.writeln('');
    stderr.writeln(_usage);
    exitCode = 2;
    return;
  }

  if (options.showHelp) {
    stdout.writeln(_usage);
    return;
  }

  final String outputDir;
  final List<String> rootKeys;
  final BuildReport report;
  final stopwatch = Stopwatch()..start();
  try {
    final reader = options.assetsPath == null
        ? CorpusReader.discover()
        : CorpusReader(assetsPath: options.assetsPath!);

    final tree = reader.readTree();
    // `all` resolves here, not in the parser: it means "every root in the tree"
    // and the parser has no tree. Taken from `tree.rootKeys` — a fixed,
    // file-order list — so `--root all` is as deterministic as spelling the
    // seven out by hand (§11.8).
    rootKeys = options.rootsAreAll ? tree.rootKeys : options.rootKeys;

    final unknown = rootKeys.where((key) => tree[key] == null).toList();
    if (unknown.isNotEmpty) {
      stderr.writeln('Unknown nodeKey${unknown.length > 1 ? 's' : ''} '
          '"${unknown.join('", "')}".');
      stderr.writeln('Roots: ${tree.rootKeys.join(', ')}  (or "all")');
      exitCode = 2;
      return;
    }

    outputDir = options.outputDir ?? '$_packageRoot/build';
    final packageAssetsPath = '$_packageRoot/assets';
    report = SiteGenerator(
      reader: reader,
      tree: tree,
      tokens: _readThemeTokens('$packageAssetsPath/theme_tokens.json'),
      outputDir: outputDir,
      packageAssetsPath: packageAssetsPath,
    ).generate(rootKeys);
  } on StateError catch (error) {
    // Every StateError the generator raises is a deliberate, explained refusal
    // — a missing corpus file, an unrecognised --out, a node pointing past the
    // end of its file. They are operator errors, so they get the same clean
    // one-line treatment as a bad flag rather than a Dart stack trace.
    stderr.writeln(error.message);
    exitCode = 1;
    return;
  }
  stopwatch.stop();

  stdout.writeln('roots           ${rootKeys.join(', ')}');
  stdout.writeln('output          $outputDir');
  stdout.writeln('');
  stdout.writeln('sutta pages     ${report.suttaPages}');
  stdout.writeln('chapter pages   ${report.chapterPages}');
  stdout.writeln('container TOCs  ${report.tocPages}');
  stdout.writeln('─────────────────────────');
  stdout.writeln('total           ${report.total}');
  stdout.writeln('');
  stdout.writeln('content files   ${report.contentFilesParsed} parsed');
  stdout.writeln('elapsed         ${stopwatch.elapsedMilliseconds} ms');
}

/// Reads the committed theme export.
///
/// Lives here, not on [ThemeTokens], so that class stays a pure typed view over
/// a decoded map — which is what lets `render/` depend on it without reaching
/// sideways into `data/`. This is the composition root; it is allowed to touch
/// the disk.
ThemeTokens _readThemeTokens(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    throw StateError(
      'Missing $path. Regenerate it with:\n'
      '  flutter test tools/dump_theme_tokens.dart',
    );
  }
  return ThemeTokens(
    json.decode(file.readAsStringSync()) as Map<String, dynamic>,
  );
}

/// Directory holding this package's `pubspec.yaml`, so `build/` and
/// `assets/theme_tokens.json` resolve the same whether the generator is run
/// from the repo root or from inside `static_site_generator/`.
///
/// Read off `Platform.script` — the URI of *this file* — rather than searched
/// for upwards. The answer is then exact instead of inferred from landmarks,
/// which is what a walk has to do when the repo root and every other package
/// in it also carry a `pubspec.yaml`. (Only holds while the generator runs as
/// source, which is how it is invoked; a compiled snapshot would point here at
/// the executable, and `--out` is the escape hatch.)
final String _packageRoot = File.fromUri(Platform.script).parent.parent.path;

/// Parsed command line. Hand-rolled rather than pulling in `package:args` —
/// three flags is not worth a dependency in a package whose whole point is that
/// `dart pub deps` shows nothing but `wisdom_shared`.
class _Options {
  /// Subtrees to build, in walk order. Empty when [rootsAreAll] is set.
  final List<String> rootKeys;

  /// `--root all` was given. Kept as a flag rather than expanded here because
  /// only the loaded tree knows what "all" is.
  final bool rootsAreAll;

  final String? assetsPath;
  final String? outputDir;
  final bool showHelp;

  const _Options({
    required this.rootKeys,
    required this.rootsAreAll,
    required this.assetsPath,
    required this.outputDir,
    required this.showHelp,
  });

  static const Set<String> _valueFlags = {'--root', '--assets', '--out'};

  /// Accepts both `--flag value` and `--flag=value`.
  ///
  /// Throws [FormatException] on anything it does not understand. Every failure
  /// path is loud on purpose: falling back to a default on a typo'd flag would
  /// build a confident, correct-looking site for the wrong subtree — the most
  /// expensive kind of wrong.
  static _Options parse(List<String> args) {
    final values = <String, String>{};
    var showHelp = false;

    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      if (arg == '-h' || arg == '--help') {
        showHelp = true;
        continue;
      }

      final separator = arg.indexOf('=');
      final name = separator < 0 ? arg : arg.substring(0, separator);
      if (!_valueFlags.contains(name)) {
        throw FormatException('Unknown option "$arg".');
      }

      final String value;
      if (separator >= 0) {
        value = arg.substring(separator + 1);
      } else if (i + 1 < args.length) {
        value = args[++i];
      } else {
        throw FormatException('Missing value for $name.');
      }
      if (value.isEmpty) throw FormatException('Empty value for $name.');

      values[name] = value;
    }

    // Defaults to the whole corpus. The old default was `an-1`, which built a
    // one-book fragment whose අට්ඨකථා links mostly pointed outside it — fine to
    // ask for, wrong to get by accident, because the way that fails is a deploy
    // that looks like a finished site. A slow default is recoverable; a
    // silently partial one is not.
    final raw = values['--root'] ?? _allRoots;
    if (raw == _allRoots) {
      return _Options(
        rootKeys: const [],
        rootsAreAll: true,
        assetsPath: values['--assets'],
        outputDir: values['--out'],
        showHelp: showHelp,
      );
    }

    final rootKeys = [
      for (final key in raw.split(',')) key.trim(),
    ];
    if (rootKeys.any((key) => key.isEmpty)) {
      throw FormatException('--root has an empty entry: "$raw".');
    }

    return _Options(
      rootKeys: rootKeys,
      rootsAreAll: false,
      assetsPath: values['--assets'],
      outputDir: values['--out'],
      showHelp: showHelp,
    );
  }
}

/// `--root` value meaning "every root in the tree".
///
/// Safe as a keyword: no node is named `all` — the seven roots are `vp`, `sp`,
/// `ap`, `atta-vp`, `atta-sp`, `atta-ap` and `anya`.
const String _allRoots = 'all';

const String _usage = '''
Static HTML site generator — The Wisdom Project

  dart run static_site_generator/bin/generate.dart [options]

Options
  --root <keys>      Comma-separated subtrees, or  (default: all)
                     "all" for every tree root
  --assets <path>    Path to assets/               (default: discovered upwards)
  --out <path>       Output directory              (default: <package>/build)
  -h, --help         Show this help

Roots are walked in the order given, and prev/next chains across them.
A canon subtree links into its atta-* commentary twin, which is under a
different root — so build both, or those links 404:

  --root all                 whole corpus, ~30s
  --root an-1,atta-an-1      one nikaya section and its commentary
''';
