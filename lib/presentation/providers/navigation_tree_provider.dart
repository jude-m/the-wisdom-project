import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/constants.dart';
import '../../data/datasources/tree_local_datasource.dart';
import '../../data/repositories/navigation_tree_repository_impl.dart';
import '../../domain/entities/navigation/tipitaka_tree_node.dart';
import '../../domain/repositories/navigation_tree_repository.dart';
import '../../domain/usecases/load_navigation_tree_usecase.dart';

// Datasource provider
final treeLocalDataSourceProvider = Provider<TreeLocalDataSource>((ref) {
  return TreeLocalDataSourceImpl();
});

// Repository provider
final navigationTreeRepositoryProvider =
    Provider<NavigationTreeRepository>((ref) {
  final dataSource = ref.watch(treeLocalDataSourceProvider);
  return NavigationTreeRepositoryImpl(dataSource);
});

// Use case provider
final loadNavigationTreeUseCaseProvider =
    Provider<LoadNavigationTreeUseCase>((ref) {
  final repository = ref.watch(navigationTreeRepositoryProvider);
  return LoadNavigationTreeUseCase(repository);
});

// Navigation tree state provider
final navigationTreeProvider =
    FutureProvider<List<TipitakaTreeNode>>((ref) async {
  final useCase = ref.watch(loadNavigationTreeUseCaseProvider);
  final result = await useCase.execute();

  return result.fold(
    (failure) => throw Exception(failure.userMessage),
    (tree) => tree,
  );
});

// State for expanded nodes - Sutta Pitaka expanded by default
final expandedNodesProvider =
    StateProvider<Set<String>>((ref) => {TipitakaNodeKeys.suttaPitaka});

// State for selected node
final selectedNodeProvider = StateProvider<String?>((ref) => null);

// State for scroll-to-node requests (only set by sync, not manual selection)
// This separates "selection" from "scroll request"
final scrollToNodeRequestProvider = StateProvider<String?>((ref) => null);

// The former "navigation language" preference now lives in
// content_language_provider.dart as `contentLanguageProvider` /
// `effectiveContentLanguageProvider` — it applies app-wide (tree, breadcrumbs,
// search, dialogs, tabs), not just to the tree, and its options are
// edition-driven.

// Flat key → node index, built once when the tree loads. Lets [nodeByKeyProvider]
// (and the ancestor walk) do O(1) lookups instead of an O(N) recursive scan of
// the whole tree per call — important because search-result tiles look up their
// node + every ancestor on each build while scrolling. Empty while the tree is
// loading or on error. Rebuilds only when the tree itself changes.
final nodeIndexProvider = Provider<Map<String, TipitakaTreeNode>>((ref) {
  final treeAsync = ref.watch(navigationTreeProvider);

  return treeAsync.maybeWhen(
    data: (rootNodes) {
      final index = <String, TipitakaTreeNode>{};
      void visit(List<TipitakaTreeNode> nodes) {
        for (final node in nodes) {
          index[node.nodeKey] = node;
          visit(node.childNodes);
        }
      }

      visit(rootNodes);
      return index;
    },
    orElse: () => const {},
  );
});

// Helper provider to get a node by key (O(1) via [nodeIndexProvider]).
// Uses autoDispose to clean up when no listeners remain (prevents memory leaks).
final nodeByKeyProvider =
    Provider.autoDispose.family<TipitakaTreeNode?, String>((ref, nodeKey) {
  return ref.watch(nodeIndexProvider)[nodeKey];
});

/// Provider that finds the previous readable node in tree order before [nodeKey].
/// Walks the tree depth-first. Returns null if [nodeKey] is the very first
/// readable node (i.e., there's nothing before it).
final previousReadableNodeProvider =
    Provider.autoDispose.family<TipitakaTreeNode?, String>((ref, nodeKey) {
  final treeAsync = ref.watch(navigationTreeProvider);
  return treeAsync.when(
    data: (rootNodes) {
      TipitakaTreeNode? prev;
      bool found = false;

      void dfs(TipitakaTreeNode node) {
        if (found) return;
        if (node.nodeKey == nodeKey) {
          found = true;
          return;
        }
        if (node.isReadableContent) prev = node;
        for (final child in node.childNodes) {
          if (found) return;
          dfs(child);
        }
      }

      for (final root in rootNodes) {
        if (found) break;
        dfs(root);
      }
      return found ? prev : null;
    },
    loading: () => null,
    error: (_, __) => null,
  );
});

/// Returns the list of node keys from root to [nodeKey] by walking up
/// the parent chain via `parentNodeKey`.
///
/// Reused by breadcrumb display, expand-path-to-node, and any future
/// feature that needs the ancestor path. Returns [] if the node is not
/// found or the tree hasn't loaded.
final ancestorKeysProvider =
    Provider.autoDispose.family<List<String>, String>((ref, nodeKey) {
  final keys = <String>[];
  String? currentKey = nodeKey;

  // Safety limit to prevent infinite loops from malformed data
  const maxDepth = 20;
  var depth = 0;

  while (currentKey != null && depth < maxDepth) {
    final node = ref.watch(nodeByKeyProvider(currentKey));
    if (node == null) break;

    keys.add(node.nodeKey);
    currentKey = node.parentNodeKey;
    depth++;
  }

  // Reverse so it reads root → leaf
  return keys.reversed.toList();
});

// Provider to toggle node expansion
final toggleNodeExpansionProvider = Provider<void Function(String)>((ref) {
  return (String nodeKey) {
    final expandedNodes = ref.read(expandedNodesProvider);
    final newSet = Set<String>.from(expandedNodes);

    if (newSet.contains(nodeKey)) {
      newSet.remove(nodeKey);
    } else {
      newSet.add(nodeKey);
    }

    ref.read(expandedNodesProvider.notifier).state = newSet;
  };
});

// Provider to select a node
final selectNodeProvider = Provider<void Function(String)>((ref) {
  return (String nodeKey) {
    ref.read(selectedNodeProvider.notifier).state = nodeKey;
  };
});

// Provider to expand path to a node (expand all parents)
final expandPathToNodeProvider = Provider<void Function(String)>((ref) {
  return (String nodeKey) {
    final path = ref.read(ancestorKeysProvider(nodeKey));
    if (path.isEmpty) return;

    final expandedNodes = ref.read(expandedNodesProvider);
    final newSet = Set<String>.from(expandedNodes);

    // Expand all nodes in the path except the last one (the node itself)
    for (var i = 0; i < path.length - 1; i++) {
      newSet.add(path[i]);
    }
    ref.read(expandedNodesProvider.notifier).state = newSet;
  };
});
