import 'package:wisdom_shared/wisdom_shared.dart';

import '../domain/content_slicer.dart';
import 'corpus_reader.dart';

/// Hands out [ContentSlicer]s, parsing each content file at most once in a row.
///
/// The corpus is 340 MB across 285 files and the median file is ~1 MB, so
/// holding every parsed file would cost several gigabytes. It only ever holds
/// **one**, which is enough: every caller walks the tree in order, and a
/// content file's nodes are contiguous in that walk. Jumping between files
/// re-parses, so callers that can group their work by file should.
///
/// ## A build now parses each file once (review D1, closed by S2)
///
/// It used to be twice, and that was never cache thrash — tree order already
/// gives near-perfect locality within a pass. It was two passes: the grouping
/// planner had to measure every leaf before `SitePlan.build` could decide which
/// nodes even became pages, and rendering then needed the same rows again.
/// Neither could be folded into the other, because a page's prev/next link
/// depends on how the tree groups further down.
///
/// Freezing the verdicts removed the first pass outright rather than caching
/// around it: `foldedLeafKeys` is a `const`, so nothing measures text to decide
/// a page. `GroupingPlanner` still uses this cache, but only from
/// `tool/plan_corpus.dart` at sync time.
class SlicerCache {
  final CorpusReader reader;
  final TipitakaTree tree;

  String? _fileId;
  ContentSlicer? _slicer;

  /// Which tree nodes belong to which content file — built once, on first use.
  /// See [ContentSlicer.nodesByFile] for why this is not computed per call.
  Map<String, List<TipitakaNode>>? _nodesByFile;

  /// Files parsed so far — a re-parse of the same file counts again, so a number
  /// far above the number of files the caller actually needs means it is
  /// thrashing. A whole-corpus render parses 285, one per file; a caller that
  /// walks the corpus twice pays twice, which is why `plan_corpus.dart` reports
  /// this only once both of its passes are done.
  int parses = 0;

  SlicerCache({required this.reader, required this.tree});

  ContentSlicer forFile(String fileId) {
    if (_fileId == fileId && _slicer != null) return _slicer!;
    final nodes = (_nodesByFile ??= ContentSlicer.nodesByFile(tree))[fileId];
    if (nodes == null) {
      throw StateError('No tree node has its text in "$fileId".');
    }
    final slicer = ContentSlicer.forFile(reader.readContentFile(fileId), nodes);
    _fileId = fileId;
    _slicer = slicer;
    parses++;
    return slicer;
  }
}
