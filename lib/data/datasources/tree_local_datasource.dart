import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import 'package:wisdom_shared/wisdom_shared.dart';
import '../../domain/entities/navigation/tipitaka_tree_node.dart';

/// Local data source for loading the navigation tree from assets
abstract class TreeLocalDataSource {
  /// Load the complete navigation tree from tree.json
  Future<List<TipitakaTreeNode>> loadNavigationTree();

  /// The same tree in its shared form, which is what `SitePlan` reads.
  ///
  /// Exposed beside [loadNavigationTree] rather than derived from it: the app
  /// entity nests its children and drops the flat key index, so rebuilding a
  /// [TipitakaTree] from it would be a second decode of a 4 MB asset and a
  /// second chance to disagree with the site.
  Future<TipitakaTree> loadSharedTree();
}

class TreeLocalDataSourceImpl implements TreeLocalDataSource {
  static const String _treeJsonPath = 'assets/data/tree.json';

  /// Decoded once and shared by both accessors — the asset is 4 MB and neither
  /// caller wants a private copy of it. Held as the Future, so two callers
  /// racing at startup await one decode rather than starting two.
  Future<TipitakaTree>? _sharedTree;

  // Mirrors the pattern in DictionaryDataSourceImpl. dart:developer.log is a
  // no-op in release builds, so this costs nothing in production.
  void _log(String message, {Object? error, StackTrace? stack}) {
    developer.log(message, name: 'TreeDataSource', error: error, stackTrace: stack);
  }

  /// Decodes `tree.json` through [TipitakaTree.fromJson] and maps the result
  /// onto the app's entity.
  ///
  /// **The decoding is not done here**, and that is the point. This file used
  /// to hold its own copy of the row parsing and the sibling comparator, kept
  /// deliberately line-for-line identical to the shared one — two copies of a
  /// rule that decides where every node sits, with nothing but a comment
  /// holding them together. The static site reads the shared decoder, so any
  /// drift between the copies would have shown up as the same tap landing in
  /// two different places on the two surfaces.
  ///
  /// Reading the shared decoder also brings [correctedTreeCoordinates] in: the
  /// leaves whose upstream coordinate points at the wrong row (a closing
  /// colophon taken for an opening line, and two other shapes) are corrected
  /// before the tree is used at all. Until this migration the app opened those
  /// leaves one unit off — the page titled for one section carrying the text of
  /// the one beside it — while the site had been serving them correctly since
  /// the map landed.
  @override
  Future<List<TipitakaTreeNode>> loadNavigationTree() async {
    try {
      final tree = await loadSharedTree();

      // The shared tree is flat — a node names its children by key — while the
      // app's entity nests them, so the only work left here is to inflate one
      // shape into the other. Children arrive already sorted; re-sorting them
      // is precisely the duplication this migration removes.
      return [for (final root in tree.roots) _toEntity(tree, root)];
    } catch (e, stack) {
      // rethrow (instead of wrapping) preserves the original stack trace —
      // FormatException, PlatformException, etc. flow up unchanged so the
      // repository's offline classifier can inspect the real exception type.
      _log('Failed to load navigation tree', error: e, stack: stack);
      rethrow;
    }
  }

  @override
  Future<TipitakaTree> loadSharedTree() async {
    final cached = _sharedTree;
    if (cached != null) return cached;

    final decoding = _decodeSharedTree();
    _sharedTree = decoding;
    try {
      return await decoding;
    } catch (e, stack) {
      // A failed decode must not stay cached, or every later caller replays
      // the same error and a retry can never succeed.
      _sharedTree = null;
      _log('Failed to decode navigation tree', error: e, stack: stack);
      rethrow;
    }
  }

  Future<TipitakaTree> _decodeSharedTree() async {
    final jsonString = await rootBundle.loadString(_treeJsonPath);
    final Map<String, dynamic> jsonData = json.decode(jsonString);
    return TipitakaTree.fromJson(jsonData);
  }

  /// One shared node, with its whole subtree built underneath it.
  ///
  /// `hasAudioAvailable` keeps its default: the old parser set it to `false`
  /// on every node and nothing has ever set it otherwise, so there is nothing
  /// in the shared tree for it to carry.
  TipitakaTreeNode _toEntity(TipitakaTree tree, TipitakaNode node) {
    return TipitakaTreeNode(
      nodeKey: node.nodeKey,
      paliName: node.paliName,
      sinhalaName: node.sinhalaName,
      hierarchyLevel: node.hierarchyLevel,
      entryPageIndex: node.entryPageIndex,
      entryIndexInPage: node.entryIndexInPage,
      parentNodeKey: node.parentNodeKey,
      contentFileId: node.contentFileId,
      childNodes: [
        for (final childKey in node.childKeys) _toEntity(tree, tree[childKey]!),
      ],
    );
  }
}
