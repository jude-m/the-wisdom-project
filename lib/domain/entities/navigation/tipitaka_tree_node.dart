import 'package:freezed_annotation/freezed_annotation.dart';
import 'navigation_language.dart';

part 'tipitaka_tree_node.freezed.dart';

/// Represents a single node in the Tipitaka navigation tree
/// Can be either a container node (folder) or a readable content node (sutta)
@freezed
class TipitakaTreeNode with _$TipitakaTreeNode {
  const TipitakaTreeNode._();

  const factory TipitakaTreeNode({
    /// Unique key identifying this node in the tree structure
    required String nodeKey,

    /// Display name in Pali language
    required String paliName,

    /// Display name in Sinhala language
    required String sinhalaName,

    /// The hierarchical level/depth of this node in the tree (0 = root)
    required int hierarchyLevel,

    /// Index of the entry's page in the content file
    required int entryPageIndex,

    /// Index of the entry within the page
    required int entryIndexInPage,

    /// Key of the parent node (null for root nodes)
    String? parentNodeKey,

    /// ID of the content file associated with this node (null for container nodes)
    String? contentFileId,

    /// List of child nodes (empty for leaf nodes)
    @Default([]) List<TipitakaTreeNode> childNodes,

    /// Indicates whether audio is available for this content
    @Default(false) bool hasAudioAvailable,
  }) = _TipitakaTreeNode;

  /// Returns the display name based on the selected language
  String getDisplayName(NavigationLanguage language) {
    switch (language) {
      case NavigationLanguage.pali:
        return paliName;
      case NavigationLanguage.sinhala:
        return sinhalaName;
    }
  }

  /// Checks if this node represents readable content (has an associated content file)
  bool get isReadableContent => contentFileId != null;

  /// Checks if this node is a container (has child nodes)
  bool get isContainerNode => childNodes.isNotEmpty;

  /// Checks if this node is a leaf node (no children)
  bool get isLeafNode => childNodes.isEmpty;

  /// Checks if this is a root level node
  bool get isRootNode => parentNodeKey == null;

  /// Returns the number of direct children
  int get childCount => childNodes.length;

  /// Gets the entry location as a tuple [pageIndex, entryIndex]
  List<int> get entryLocation => [entryPageIndex, entryIndexInPage];

  /// Recursively counts all descendant nodes (children, grandchildren, etc.)
  int get totalDescendantCount {
    int count = childNodes.length;
    for (var child in childNodes) {
      count += child.totalDescendantCount;
    }
    return count;
  }

  /// Finds a child node by its key
  TipitakaTreeNode? findChildByKey(String key) {
    try {
      return childNodes.firstWhere((child) => child.nodeKey == key);
    } catch (e) {
      return null;
    }
  }

  /// Recursively searches for a node with the given key in the entire subtree
  TipitakaTreeNode? findDescendantByKey(String key) {
    if (nodeKey == key) {
      return this;
    }

    for (var child in childNodes) {
      final found = child.findDescendantByKey(key);
      if (found != null) {
        return found;
      }
    }

    return null;
  }

  /// Returns all readable content nodes in this subtree
  List<TipitakaTreeNode> get allReadableDescendants {
    final List<TipitakaTreeNode> readableNodes = [];

    if (isReadableContent) {
      readableNodes.add(this);
    }

    for (var child in childNodes) {
      readableNodes.addAll(child.allReadableDescendants);
    }

    return readableNodes;
  }
}
