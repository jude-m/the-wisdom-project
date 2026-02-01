import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/responsive_utils.dart';
import '../../domain/entities/navigation/tipitaka_tree_node.dart';
import '../models/reader_tab.dart';
import '../providers/navigation_tree_provider.dart';
import '../providers/navigator_visibility_provider.dart';
import '../providers/tab_provider.dart';

class TreeNavigatorWidget extends ConsumerStatefulWidget {
  const TreeNavigatorWidget({super.key});

  @override
  ConsumerState<TreeNavigatorWidget> createState() =>
      _TreeNavigatorWidgetState();
}

class _TreeNavigatorWidgetState extends ConsumerState<TreeNavigatorWidget> {
  // Store GlobalKeys for each node to enable scroll-to-selected
  final Map<String, GlobalKey> _nodeKeys = {};

  GlobalKey _getKeyForNode(String nodeKey) {
    return _nodeKeys.putIfAbsent(nodeKey, () => GlobalKey());
  }

  @override
  Widget build(BuildContext context) {
    final treeAsync = ref.watch(navigationTreeProvider);

    // Listen to scroll requests (only triggered by tab switch/search, not manual nav clicks)
    ref.listen<String?>(scrollToNodeRequestProvider, (previous, next) {
      if (next != null && next != previous) {
        _scrollToSelectedNode(next);
      }
    });

    return treeAsync.when(
      data: (rootNodes) {
        if (rootNodes.isEmpty) {
          return const Center(
            child: Text('No content available'),
          );
        }

        return ListView.builder(
          itemCount: rootNodes.length,
          itemBuilder: (context, index) {
            return TreeNodeWidget(
              node: rootNodes[index],
              level: 0,
              getKeyForNode: _getKeyForNode,
            );
          },
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (error, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Error loading navigation tree',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Scrolls to the selected node in the tree.
  /// Uses a retry mechanism to wait for the node to be rendered after expansion.
  void _scrollToSelectedNode(String nodeKey) {
    _attemptScrollToNode(nodeKey, retriesRemaining: 5);
  }

  /// Attempts to scroll to a node, retrying if the node isn't rendered yet.
  /// This handles the async nature of tree expansion and layout.
  void _attemptScrollToNode(String nodeKey, {required int retriesRemaining}) {
    if (!mounted || retriesRemaining <= 0) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final key = _nodeKeys[nodeKey];
      final context = key?.currentContext;

      if (context != null) {
        // Node is rendered, scroll to it
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.2, // Position at 20% from top
        );
      } else {
        // Node not yet rendered, retry after next frame
        _attemptScrollToNode(nodeKey, retriesRemaining: retriesRemaining - 1);
      }
    });
  }
}

class TreeNodeWidget extends ConsumerWidget {
  final TipitakaTreeNode node;
  final int level;
  final GlobalKey Function(String nodeKey) getKeyForNode;

  const TreeNodeWidget({
    super.key,
    required this.node,
    required this.level,
    required this.getKeyForNode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expandedNodes = ref.watch(expandedNodesProvider);
    final selectedNode = ref.watch(selectedNodeProvider);
    final navigationLanguage = ref.watch(navigationLanguageProvider);

    final isExpanded = expandedNodes.contains(node.nodeKey);
    final isSelected = selectedNode == node.nodeKey;
    final hasChildren = node.childNodes.isNotEmpty;
    final displayName = node.getDisplayName(navigationLanguage);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: getKeyForNode(node.nodeKey),
          padding: EdgeInsets.only(
            left: 16.0 + (level * 20.0),
            right: 16.0,
            top: 8.0,
            bottom: 8.0,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primaryContainer
                : null,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              // Expand/collapse icon - separate tap handler
              if (hasChildren)
                GestureDetector(
                  onTap: () {
                    // Only toggle expansion, don't create tab
                    ref.read(toggleNodeExpansionProvider)(node.nodeKey);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(
                      isExpanded ? Icons.expand_more : Icons.chevron_right,
                      size: 20,
                    ),
                  ),
                )
              else
                const SizedBox(width: 28),
              const SizedBox(width: 8),

              // Node content area - tap to select and create tab
              Expanded(
                child: InkWell(
                  onTap: () {
                    // Select the node
                    ref.read(selectNodeProvider)(node.nodeKey);

                    // Create a new tab for this node with entryStart for proper positioning
                    // This ensures the sutta title appears at the top of the page
                    final newTab = ReaderTab.fromNode(
                      nodeKey: node.nodeKey,
                      paliName: node.paliName,
                      sinhalaName: node.sinhalaName,
                      contentFileId:
                          node.isReadableContent ? node.contentFileId : null,
                      pageIndex:
                          node.isReadableContent ? node.entryPageIndex : 0,
                      entryStart:
                          node.isReadableContent ? node.entryIndexInPage : 0,
                    );

                    // Add tab and make it active
                    // Content and pagination state are derived automatically from the tab via:
                    // - activeContentFileIdProvider
                    // - activePageIndexProvider
                    // - activePageStartProvider, activePageEndProvider, activeEntryStartProvider
                    final newIndex =
                        ref.read(tabsProvider.notifier).addTab(newTab);
                    ref.read(activeTabIndexProvider.notifier).state = newIndex;

                    // Close navigator on mobile portrait so user can see the content
                    // In landscape mode, keep navigator open as there's more screen space
                    final isPortrait =
                        MediaQuery.of(context).orientation == Orientation.portrait;
                    if (ResponsiveUtils.isMobile(context) && isPortrait) {
                      ref.read(navigatorVisibleProvider.notifier).state = false;
                    }
                  },
                  child: Row(
                    children: [
                      // Node icon
                      Icon(
                        node.isReadableContent
                            ? Icons.description_outlined
                            : Icons.folder_outlined,
                        size: 18,
                        color: isSelected
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                            : Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 8),

                      // Node name
                      Expanded(
                        child: Text(
                          displayName,
                          style: isSelected
                              ? context.typography.treeNodeLabelSelected
                              : context.typography.treeNodeLabel,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Child nodes
        if (hasChildren && isExpanded)
          ...node.childNodes.map((childNode) {
            return TreeNodeWidget(
              node: childNode,
              level: level + 1,
              getKeyForNode: getKeyForNode,
            );
          }),
      ],
    );
  }
}
