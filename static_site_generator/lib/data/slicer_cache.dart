import 'package:wisdom_shared/wisdom_shared.dart';

import '../domain/content_slicer.dart';
import 'corpus_reader.dart';

/// Hands out [ContentSlicer]s, parsing each content file at most once in a row.
///
/// The corpus is 340 MB across 285 files and the median file is ~1 MB, so
/// holding every parsed file would cost several gigabytes. It only ever holds
/// **one**, which is enough: both the classifier and the renderer walk the tree
/// in order, and a content file's nodes are contiguous in that walk. Jumping
/// between files re-parses, so callers that can group their work by file
/// should.
///
/// ## Why a full build parses each file about twice (review D1 — not a bug)
///
/// A whole-corpus run reports ~516 parses against 285 files. That is **not**
/// cache thrash — tree order already gives near-perfect locality within a pass.
/// It is the two passes: the grouping verdicts must all exist before
/// `SitePlan.build` can decide which nodes even become pages, and rendering
/// then needs the same rows again. Neither pass can be folded into the other,
/// because a page's prev/next link depends on verdicts further down the tree.
///
/// Collapsing it would mean keeping parsed files alive between the passes, i.e.
/// the several gigabytes above. A one-minute saving on a manually-run build is
/// not worth that, so the second pass stays.
class SlicerCache {
  final CorpusReader reader;
  final TipitakaTree tree;

  String? _fileId;
  ContentSlicer? _slicer;

  /// Which tree nodes belong to which content file — built once, on first use.
  /// See [ContentSlicer.nodesByFile] for why this is not computed per call.
  Map<String, List<TipitakaNode>>? _nodesByFile;

  /// Files parsed so far — a re-parse of the same file counts again, so a
  /// number far above the ~2×285 explained above means a caller is thrashing.
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
