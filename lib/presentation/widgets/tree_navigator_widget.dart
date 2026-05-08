import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/l10n/app_localizations.dart';
import '../../core/theme/app_typography.dart';
import '../utils/content_icons.dart';
import '../../core/utils/pali_conjunct_transformer.dart';
import '../../core/utils/responsive_utils.dart';
import '../../domain/entities/navigation/navigation_language.dart';
import '../../domain/entities/navigation/tipitaka_tree_node.dart';
import '../providers/navigation_tree_provider.dart';
import '../providers/navigator_visibility_provider.dart';
import '../providers/tab_provider.dart';
import 'common/status_message_view.dart';

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
          // search_off (the default for `empty`) doesn't fit a tree that the
          // user did not search — use a folder icon instead.
          return StatusMessageView(
            variant: StatusVariant.empty,
            iconOverride: Icons.folder_off_outlined,
            title: AppLocalizations.of(context).statusNoTreeContent,
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
      loading: () => const StatusMessageView(variant: StatusVariant.loading),
      error: (error, stack) {
        // No Retry / no widget-level logging:
        //   - TreeDataSource logs the raw error + stack trace at the catch
        //     site, so engineers see the real exception in DevTools.
        //   - Web users can refresh the page; mobile assets are bundled,
        //     so a retry can't fix the underlying problem.
        final variant = statusVariantForError(error);
        final l10n = AppLocalizations.of(context);
        return StatusMessageView(
          variant: variant,
          title: variant == StatusVariant.offline
              ? l10n.statusOfflineTitle
              : l10n.errorLoadingTree,
          description: variant == StatusVariant.offline
              ? l10n.statusOfflineDescription
              : l10n.statusErrorDescription,
        );
      },
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
    final rawDisplayName = node.getDisplayName(navigationLanguage);
    final displayName = navigationLanguage == NavigationLanguage.pali
        ? rawDisplayName.withPaliConjuncts
        : rawDisplayName;
    final ci = contentIcon(
      isCommentary: node.isCommentary,
      isTreatise: node.isTreatise,
      hasChildren: hasChildren,
      isExpanded: isExpanded,
      colorScheme: Theme.of(context).colorScheme,
    );

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
                ? Theme.of(context).colorScheme.surfaceContainerHigh
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
                    // Select the node in the tree (for visual highlight)
                    ref.read(selectNodeProvider)(node.nodeKey);

                    // Open a new tab via centralized provider
                    final shouldUseSingleColumn =
                        ResponsiveUtils.shouldDefaultToSingleColumn(context);
                    ref.read(openTabFromNodeKeyProvider)(
                      node.nodeKey,
                      isPortraitMode: shouldUseSingleColumn,
                    );

                    // Close navigator on mobile portrait so user can see the content
                    if (shouldUseSingleColumn) {
                      ref.read(navigatorVisibleProvider.notifier).state = false;
                    }
                  },
                  child: Row(
                    children: [
                      Icon(
                        ci.icon,
                        size: 20,
                        weight: 600,
                        color: isSelected
                            ? Theme.of(context).colorScheme.onSurface
                            : ci.color.withValues(alpha: 0.8),
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
