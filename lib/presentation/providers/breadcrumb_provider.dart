import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'navigation_tree_provider.dart';
import 'tab_provider.dart';

/// Derived provider that builds the breadcrumb segments for the active tab.
///
/// Returns a list of `({String nodeKey, String displayName})` records in
/// root→leaf order. The widget uses `nodeKey` for click navigation and
/// `displayName` for rendering.
///
/// Reuses [ancestorKeysProvider] for the tree walk, then maps each key
/// to a localized display name. Returns [] when no tab is active.
final breadcrumbPathProvider =
    Provider<List<({String nodeKey, String displayName})>>((ref) {
  // Watch the active node key — changes on tab switch/close
  final nodeKey = ref.watch(activeNodeKeyProvider);
  if (nodeKey == null) return [];

  // Get ancestor keys (root → leaf order) via shared tree-walk provider
  final keys = ref.watch(ancestorKeysProvider(nodeKey));
  if (keys.isEmpty) return [];

  // Watch navigation language — re-renders names when language changes
  final language = ref.watch(navigationLanguageProvider);

  // Map each key to its localized display name
  return keys.map((key) {
    final node = ref.watch(nodeByKeyProvider(key));
    return (
      nodeKey: key,
      displayName: node?.getDisplayName(language) ?? key,
    );
  }).toList();
});
