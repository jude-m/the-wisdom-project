import 'dart:convert';
import 'package:flutter/services.dart';
import '../../domain/entities/tipitaka_tree_node.dart';

/// Local data source for loading the navigation tree from assets
abstract class TreeLocalDataSource {
  /// Load the complete navigation tree from tree.json
  Future<List<TipitakaTreeNode>> loadNavigationTree();
}

class TreeLocalDataSourceImpl implements TreeLocalDataSource {
  static const String _treeJsonPath = 'assets/data/tree.json';

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
    } catch (e) {
      throw Exception('Failed to load navigation tree: $e');
    }
  }

  /// Build hierarchical tree structure from flat list
  List<TipitakaTreeNode> _buildTreeStructure(List<TipitakaTreeNode> flatList) {
    // Build parent-child relationships
    final Map<String, List<TipitakaTreeNode>> childrenMap = {};

    for (var node in flatList) {
      if (node.parentNodeKey != null) {
        childrenMap.putIfAbsent(node.parentNodeKey!, () => []);
        childrenMap[node.parentNodeKey!]!.add(node);
      }
    }

    // Recursively build nodes with children
    TipitakaTreeNode buildNodeWithChildren(TipitakaTreeNode node) {
      final children = childrenMap[node.nodeKey] ?? [];
      final childrenWithTheirChildren = children
          .map((child) => buildNodeWithChildren(child))
          .toList();

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

    // Get all root nodes and build them with their children
    final rootNodes = flatList
        .where((node) => node.parentNodeKey == null)
        .map((node) => buildNodeWithChildren(node))
        .toList();

    return rootNodes;
  }
}
