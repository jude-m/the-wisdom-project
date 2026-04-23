import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/constants.dart';
import '../../data/datasources/tree_local_datasource.dart';
import '../../data/repositories/navigation_tree_repository_impl.dart';
import '../../domain/entities/navigation/tipitaka_tree_node.dart';
import '../../domain/entities/navigation/navigation_language.dart';
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

// State for navigation language preference (persisted to SharedPreferences)
final navigationLanguageProvider =
    StateNotifierProvider<NavigationLanguageNotifier, NavigationLanguage>(
  (ref) => NavigationLanguageNotifier(),
);

/// Manages the navigation language preference with persistence across
/// app restarts / web reloads. See [NavigationLanguage] for supported values.
class NavigationLanguageNotifier extends StateNotifier<NavigationLanguage> {
  static const String _storageKey = 'navigation_language';

  NavigationLanguageNotifier() : super(NavigationLanguage.sinhala);

  /// Load saved language preference from storage. Called once at startup.
  Future<void> loadSavedLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_storageKey);
      if (saved != null) {
        state = NavigationLanguage.values.firstWhere(
          (e) => e.name == saved,
          orElse: () => NavigationLanguage.sinhala,
        );
      }
    } catch (e) {
      // Keep default if load fails
      debugPrint('Failed to load navigation language: $e');
    }
  }

  /// Update the language and persist the choice.
  Future<void> setLanguage(NavigationLanguage language) async {
    state = language;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, language.name);
    } catch (e) {
      // UI still updates even if persistence fails
      debugPrint('Failed to save navigation language: $e');
    }
  }
}

// Helper provider to get a node by key
// Uses autoDispose to clean up when no listeners remain (prevents memory leaks).
final nodeByKeyProvider =
    Provider.autoDispose.family<TipitakaTreeNode?, String>((ref, nodeKey) {
  final treeAsync = ref.watch(navigationTreeProvider);

  return treeAsync.when(
    data: (rootNodes) {
      // Search for node recursively
      TipitakaTreeNode? findNode(List<TipitakaTreeNode> nodes) {
        for (var node in nodes) {
          if (node.nodeKey == nodeKey) {
            return node;
          }
          final found = findNode(node.childNodes);
          if (found != null) {
            return found;
          }
        }
        return null;
      }

      return findNode(rootNodes);
    },
    loading: () => null,
    error: (_, __) => null,
  );
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
