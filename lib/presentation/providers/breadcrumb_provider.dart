import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/content_text_formatter.dart';
import 'content_language_provider.dart';
import 'navigation_tree_provider.dart';
import 'pali_letter_options_provider.dart';
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

  // Watch the Content Language — re-renders names when the setting changes.
  final language = ref.watch(effectiveContentLanguageProvider);

  // Watch the Pali-letter switches — re-renders names when a switch flips.
  final options = ref.watch(paliLetterOptionsProvider);

  // Map each key to its display name in the selected Content Language, routed
  // through the shared formatter (applies Pali conjuncts only when Pali).
  return keys.map((key) {
    final node = ref.watch(nodeByKeyProvider(key));
    if (node == null) return (nodeKey: key, displayName: key);
    return (
      nodeKey: key,
      displayName:
          formatContentLabel(node.getDisplayName(language), language, options),
    );
  }).toList();
});
