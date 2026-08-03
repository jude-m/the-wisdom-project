import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import '../../domain/entities/navigation/tipitaka_tree_node.dart';

/// Local data source for loading the navigation tree from assets
abstract class TreeLocalDataSource {
  /// Load the complete navigation tree from tree.json
  Future<List<TipitakaTreeNode>> loadNavigationTree();
}

class TreeLocalDataSourceImpl implements TreeLocalDataSource {
  static const String _treeJsonPath = 'assets/data/tree.json';

  // Mirrors the pattern in DictionaryDataSourceImpl. dart:developer.log is a
  // no-op in release builds, so this costs nothing in production.
  void _log(String message, {Object? error, StackTrace? stack}) {
    developer.log(message, name: 'TreeDataSource', error: error, stackTrace: stack);
  }

  @override
  Future<List<TipitakaTreeNode>> loadNavigationTree() async {
    try {
      // Load JSON from assets
      final jsonString = await rootBundle.loadString(_treeJsonPath);
      final Map<String, dynamic> jsonData = json.decode(jsonString);

      // Parse into flat list of nodes
      final nodesList = <TipitakaTreeNode>[];

      jsonData.forEach((nodeKey, nodeDataArray) {
        final List<dynamic> data = nodeDataArray as List<dynamic>;

        final node = TipitakaTreeNode(
          nodeKey: nodeKey,
          paliName: data[0] as String,
          sinhalaName: data[1] as String,
          hierarchyLevel: data[2] as int,
          entryPageIndex: (data[3] as List<dynamic>)[0] as int,
          entryIndexInPage: (data[3] as List<dynamic>)[1] as int,
          parentNodeKey: data[4] == 'root' ? null : data[4] as String?,
          contentFileId: data[5] as String?,
          childNodes: const [], // Will be populated when building tree
          hasAudioAvailable: false,
        );

        nodesList.add(node);
      });

      // Build tree structure with parent-child relationships
      return _buildTreeStructure(nodesList);
    } catch (e, stack) {
      // rethrow (instead of wrapping) preserves the original stack trace —
      // FormatException, PlatformException, etc. flow up unchanged so the
      // repository's offline classifier can inspect the real exception type.
      _log('Failed to load navigation tree', error: e, stack: stack);
      rethrow;
    }
  }

  /// Build hierarchical tree structure from flat list
  List<TipitakaTreeNode> _buildTreeStructure(List<TipitakaTreeNode> flatList) {
    // Build parent-child relationships
    final Map<String, List<TipitakaTreeNode>> childrenMap = {};

    // Position in tree.json, used as the tiebreak below. `json.decode` returns a
    // LinkedHashMap, so `flatList` is already in file order.
    final Map<String, int> documentOrder = {
      for (var i = 0; i < flatList.length; i++) flatList[i].nodeKey: i,
    };

    // Add root nodes to the map under 'root' key for consistent handling
    for (var node in flatList) {
      final parentKey = node.parentNodeKey ?? 'root';
      childrenMap.putIfAbsent(parentKey, () => []);
      childrenMap[parentKey]!.add(node);
    }

    // Sort all children lists ONCE by extracting the last number from the node key
    // e.g., "sp-1-2-13" -> 13
    // This matches the behavior in the Vue.js app (tree.js:7-12)
    //
    // Document order is the explicit tiebreak, because 113 keys have no trailing
    // number — `vp`, `sp`, `ap`, `kn-khp`, and every dotted commentary key such
    // as `atta-ap-dhs-2-1-1.1`. They cluster under 18 parents, including `root`,
    // `sp`, `kn` and `ap`: the app's most visible navigation. Comparing those as
    // equal and letting `List.sort` decide is unspecified — `List.sort` is
    // explicitly not stable — and only produced the right answer because Dart
    // falls back to insertion sort below 32 elements and the largest of those 18
    // parents has 23 children. A margin of 9 against an undocumented VM detail.
    //
    // Mirrors `TipitakaTree.fromJson` in wisdom_shared, which the static site
    // generator uses; the two surfaces must order siblings identically or the
    // same node lands in a different place on each.
    childrenMap.forEach((parentKey, children) {
      children.sort((a, b) {
        final aIndex = _extractChildIndex(a.nodeKey);
        final bIndex = _extractChildIndex(b.nodeKey);

        if (aIndex != null && bIndex != null) {
          final byIndex = aIndex.compareTo(bIndex);
          if (byIndex != 0) return byIndex;
        }
        return documentOrder[a.nodeKey]!.compareTo(documentOrder[b.nodeKey]!);
      });
    });

    // Recursively build nodes with children (children are already sorted)
    TipitakaTreeNode buildNodeWithChildren(TipitakaTreeNode node) {
      final children = childrenMap[node.nodeKey] ?? [];
      final childrenWithTheirChildren =
          children.map((child) => buildNodeWithChildren(child)).toList();

      return TipitakaTreeNode(
        nodeKey: node.nodeKey,
        paliName: node.paliName,
        sinhalaName: node.sinhalaName,
        hierarchyLevel: node.hierarchyLevel,
        entryPageIndex: node.entryPageIndex,
        entryIndexInPage: node.entryIndexInPage,
        parentNodeKey: node.parentNodeKey,
        contentFileId: node.contentFileId,
        childNodes: childrenWithTheirChildren,
        hasAudioAvailable: node.hasAudioAvailable,
      );
    }

    // Get all root nodes and build them with their children (already sorted in childrenMap)
    final rootNodes = (childrenMap['root'] ?? [])
        .map((node) => buildNodeWithChildren(node))
        .toList();

    return rootNodes;
  }

  /// Extract the last number from a node key for sorting
  /// e.g., "sp-1-2-13" -> 13
  /// Matches the childInd function in Vue.js app (tree.js:7)
  int? _extractChildIndex(String nodeKey) {
    final parts = nodeKey.split('-');
    if (parts.isEmpty) return null;

    final lastPart = parts.last;
    return int.tryParse(lastPart);
  }
}
