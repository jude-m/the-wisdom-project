import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/tree_local_datasource.dart';
import '../../data/repositories/navigation_tree_repository_impl.dart';
import '../../domain/entities/tipitaka_tree_node.dart';
import '../../domain/entities/navigation_language.dart';
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

// State for expanded nodes
final expandedNodesProvider = StateProvider<Set<String>>((ref) => {});

// State for selected node
final selectedNodeProvider = StateProvider<String?>((ref) => null);

// State for navigation language preference
final navigationLanguageProvider = StateProvider<NavigationLanguage>((ref) {
  return NavigationLanguage.sinhala;
});

// Helper provider to get a node by key
final nodeByKeyProvider =
    Provider.family<TipitakaTreeNode?, String>((ref, nodeKey) {
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
    final treeAsync = ref.read(navigationTreeProvider);
    final expandedNodes = ref.read(expandedNodesProvider);

    treeAsync.whenData((rootNodes) {
      final newSet = Set<String>.from(expandedNodes);

      // Find path to node
      List<String>? findPath(List<TipitakaTreeNode> nodes, String targetKey,
          List<String> currentPath) {
        for (var node in nodes) {
          final path = [...currentPath, node.nodeKey];

          if (node.nodeKey == targetKey) {
            return path;
          }

          final found = findPath(node.childNodes, targetKey, path);
          if (found != null) {
            return found;
          }
        }
        return null;
      }

      final path = findPath(rootNodes, nodeKey, []);
      if (path != null) {
        // Expand all nodes in the path except the last one
        for (var i = 0; i < path.length - 1; i++) {
          newSet.add(path[i]);
        }
        ref.read(expandedNodesProvider.notifier).state = newSet;
      }
    });
  };
});
