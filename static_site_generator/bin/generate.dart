import 'dart:convert';
import 'dart:io';

import 'package:static_site_generator/data/corpus_reader.dart';
import 'package:static_site_generator/domain/theme_tokens.dart';
import 'package:static_site_generator/sitegen.dart';

/// Entrypoint for the static HTML site generator.
///
///     dart run static_site_generator/bin/generate.dart --root an-1
///
/// Writes `static_site_generator/build/` — one HTML file per sutta, one per
/// grouped chapter, one per container TOC, plus `assets/site.css`, the copied
/// WOFF2 subsets and `.manifest.json`.
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
  final BuildReport report;
  final stopwatch = Stopwatch()..start();
  try {
    final reader = options.assetsPath == null
        ? CorpusReader.discover()
        : CorpusReader(assetsPath: options.assetsPath!);

    final tree = reader.readTree();
    if (tree[options.rootKey] == null) {
      stderr.writeln('Unknown nodeKey "${options.rootKey}".');
      stderr.writeln('Roots: ${tree.rootKeys.join(', ')}');
      exitCode = 2;
      return;
    }

    outputDir = options.outputDir ?? '$_packageRoot/build';
    report = SiteGenerator(
      reader: reader,
      tree: tree,
      tokens: _readThemeTokens('$_packageRoot/assets/theme_tokens.json'),
      outputDir: outputDir,
    ).generate(options.rootKey);
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

  stdout.writeln('root            ${options.rootKey}');
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
  final String rootKey;
  final String? assetsPath;
  final String? outputDir;
  final bool showHelp;

  const _Options({
    required this.rootKey,
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

    return _Options(
      rootKey: values['--root'] ?? 'an-1',
      assetsPath: values['--assets'],
      outputDir: values['--out'],
      showHelp: showHelp,
    );
  }
}

const String _usage = '''
Static HTML site generator — The Wisdom Project

  dart run static_site_generator/bin/generate.dart [options]

Options
  --root <nodeKey>   Subtree to build              (default: an-1)
  --assets <path>    Path to assets/               (default: discovered upwards)
  --out <path>       Output directory              (default: <package>/build)
  -h, --help         Show this help
''';
