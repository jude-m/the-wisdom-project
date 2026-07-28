import 'dart:io';

import 'package:static_site_generator/data/corpus_reader.dart';
import 'package:wisdom_shared/wisdom_shared.dart';

/// Entrypoint for the static HTML site generator.
///
///     dart run static_site_generator/bin/generate.dart --root an-1
///
/// P0 scope: prove the corpus can be read and the tree walked with **no
/// Flutter in the process**. HTML rendering arrives in P1.
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

  final reader = options.assetsPath == null
      ? CorpusReader.discover()
      : CorpusReader(assetsPath: options.assetsPath!);

  final tree = reader.readTree();
  final root = tree[options.rootKey];
  if (root == null) {
    stderr.writeln('Unknown nodeKey "${options.rootKey}".');
    stderr.writeln('Roots: ${tree.rootKeys.join(', ')}');
    exitCode = 2;
    return;
  }

  final leaves = tree.leavesUnder(root.nodeKey);
  stdout.writeln('assets   ${reader.assetsPath}');
  stdout.writeln('tree     ${tree.length} nodes, ${tree.rootKeys.length} roots');
  stdout.writeln('root     ${root.nodeKey}  ${root.paliName}');
  stdout.writeln('         ${root.sinhalaName}');
  stdout.writeln('leaves   ${leaves.length}');
  stdout.writeln('file     ${root.contentFileId}');
  stdout.writeln('');

  _printSubtree(tree, root, options.maxDepth);

  // Slice the first leaf so the whole chain — tree → content file → marker
  // parser — is exercised, not just the tree decode.
  if (leaves.isNotEmpty) {
    _printFirstLeafSample(reader, leaves.first);
  }
}

/// Prints the tree under [node] as an indented outline.
void _printSubtree(
  TipitakaTree tree,
  TipitakaNode node,
  int maxDepth, [
  int depth = 0,
]) {
  final indent = '  ' * depth;
  final marker = node.isLeaf ? '·' : '▸';
  stdout.writeln('$indent$marker ${node.nodeKey.padRight(20 - indent.length)} '
      '${node.paliName}');

  if (depth >= maxDepth) {
    final children = node.childKeys.length;
    if (children > 0) {
      stdout.writeln('$indent    … $children more');
    }
    return;
  }
  for (final child in tree.childrenOf(node.nodeKey)) {
    _printSubtree(tree, child, maxDepth, depth + 1);
  }
}

/// Reads the text of [leaf] and shows how the marker parser segments it.
void _printFirstLeafSample(CorpusReader reader, TipitakaNode leaf) {
  final fileId = leaf.contentFileId;
  if (fileId == null || !reader.hasContentFile(fileId)) {
    stdout.writeln('\n(no content file for ${leaf.nodeKey})');
    return;
  }

  final file = reader.readContentFile(fileId);
  if (leaf.entryPageIndex >= file.pages.length) {
    stdout.writeln('\n(${leaf.nodeKey} points past the end of $fileId)');
    return;
  }

  final page = file.pages[leaf.entryPageIndex];
  final entry = page.paliAt(leaf.entryIndexInPage);
  stdout.writeln('\nfirst leaf  ${leaf.nodeKey}  '
      '(page ${leaf.entryPageIndex}, entry ${leaf.entryIndexInPage})');
  if (entry == null) {
    stdout.writeln('  (no pali entry at that coordinate)');
    return;
  }

  stdout.writeln('  type      ${entry.type}${entry.level == null ? '' : ' L${entry.level}'}');
  stdout.writeln('  raw       ${_truncate(entry.text)}');
  stdout.writeln('  plain     ${_truncate(entry.plainText)}');

  final segments = parseContentMarkers(entry.text);
  stdout.writeln('  segments  ${segments.length}');
  for (final segment in segments.take(6)) {
    stdout.writeln('            $segment');
  }
}

String _truncate(String text, [int max = 72]) =>
    text.length <= max ? text : '${text.substring(0, max)}…';

/// Parsed command line. Hand-rolled rather than pulling in `package:args` —
/// three flags is not worth a dependency in a package whose whole point is
/// that `dart pub deps` shows nothing but `wisdom_shared`.
class _Options {
  final String rootKey;
  final String? assetsPath;
  final int maxDepth;
  final bool showHelp;

  const _Options({
    required this.rootKey,
    required this.assetsPath,
    required this.maxDepth,
    required this.showHelp,
  });

  /// Throws [FormatException] on anything it does not understand.
  ///
  /// Every failure path here is loud on purpose. Falling back to a default on a
  /// typo'd flag, or on `--root` with no value, would run the generator against
  /// `an-1` and print a confident, correct-looking report about the wrong
  /// subtree — the most expensive kind of wrong.
  static _Options parse(List<String> args) {
    var rootKey = 'an-1';
    String? assetsPath;
    var maxDepth = 2;
    var showHelp = false;

    for (var i = 0; i < args.length; i++) {
      final arg = args[i];

      // Accepts both `--flag value` and `--flag=value`. Returns null only when
      // [arg] is not this flag at all; a present-but-empty value throws.
      String? valueFor(String name) {
        String? value;
        if (arg == name) {
          if (i + 1 >= args.length) {
            throw FormatException('Missing value for $name.');
          }
          value = args[++i];
        } else if (arg.startsWith('$name=')) {
          value = arg.substring(name.length + 1);
        } else {
          return null;
        }
        if (value.isEmpty) {
          throw FormatException('Empty value for $name.');
        }
        return value;
      }

      if (arg == '-h' || arg == '--help') {
        showHelp = true;
        continue;
      }
      final root = valueFor('--root');
      if (root != null) {
        rootKey = root;
        continue;
      }
      final assets = valueFor('--assets');
      if (assets != null) {
        assetsPath = assets;
        continue;
      }
      final depth = valueFor('--depth');
      if (depth != null) {
        final parsed = int.tryParse(depth);
        if (parsed == null || parsed < 0) {
          throw FormatException(
            '--depth expects a non-negative integer, got "$depth".',
          );
        }
        maxDepth = parsed;
        continue;
      }

      throw FormatException('Unknown option "$arg".');
    }

    return _Options(
      rootKey: rootKey,
      assetsPath: assetsPath,
      maxDepth: maxDepth,
      showHelp: showHelp,
    );
  }
}

const String _usage = '''
Static HTML site generator — The Wisdom Project

  dart run static_site_generator/bin/generate.dart [options]

Options
  --root <nodeKey>   Subtree to work on            (default: an-1)
  --assets <path>    Path to assets/               (default: discovered upwards)
  --depth <n>        Outline depth to print        (default: 2)
  -h, --help         Show this help
''';
