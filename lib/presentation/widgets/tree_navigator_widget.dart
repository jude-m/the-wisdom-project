import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/tipitaka_tree_node.dart';
import '../../domain/entities/reader_tab.dart';
import '../providers/navigation_tree_provider.dart';
import '../providers/document_provider.dart';
import '../providers/tab_provider.dart';

class TreeNavigatorWidget extends ConsumerWidget {
  const TreeNavigatorWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final treeAsync = ref.watch(navigationTreeProvider);

    return Column(
      children: [
        // Tree content
        Expanded(
          child: treeAsync.when(
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
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.red),
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
          ),
        ),
      ],
    );
  }
}

class TreeNodeWidget extends ConsumerWidget {
  final TipitakaTreeNode node;
  final int level;

  const TreeNodeWidget({
    super.key,
    required this.node,
    required this.level,
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
                color: Theme.of(context).dividerColor.withOpacity(0.3),
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

                    // Create a new tab for this node
                    final newTab = ReaderTab.fromNode(
                      nodeKey: node.nodeKey,
                      paliName: node.paliName,
                      sinhalaName: node.sinhalaName,
                      contentFileId:
                          node.isReadableContent ? node.contentFileId : null,
                      pageIndex:
                          node.isReadableContent ? node.entryPageIndex : 0,
                    );

                    final newIndex =
                        ref.read(tabsProvider.notifier).addTab(newTab);
                    ref.read(activeTabIndexProvider.notifier).state = newIndex;

                    // If it has readable content, set it (without resetting pagination)
                    if (node.isReadableContent) {
                      final fileId = node.contentFileId?.trim();
                      if (fileId != null && fileId.isNotEmpty) {
                        // Use the tab's pagination state instead of resetting
                        ref.read(currentContentFileIdProvider.notifier).state =
                            fileId;
                        ref.read(currentPageIndexProvider.notifier).state =
                            node.entryPageIndex;
                        ref.read(pageStartProvider.notifier).state =
                            newTab.pageStart;
                        ref.read(pageEndProvider.notifier).state =
                            newTab.pageEnd;
                      }
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
                                .withOpacity(0.6),
                      ),
                      const SizedBox(width: 8),

                      // Node name
                      Expanded(
                        child: Text(
                          displayName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isSelected
                                ? Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer
                                : null,
                          ),
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
            );
          }),
      ],
    );
  }
}
