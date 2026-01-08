import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/navigation/tipitaka_tree_node.dart';
import '../../domain/entities/search/scope_filter_config.dart';
import '../../domain/entities/search/scope_utils.dart';
import '../providers/navigation_tree_provider.dart';
import '../providers/search_provider.dart';

/// Dialog for refining search with hierarchical scope selection.
///
/// Features:
/// - 3-level tree (Pitaka → Nikaya → Vagga) with checkboxes
/// - Live updates to search results as nodes are toggled
/// - Single source of truth: searchStateProvider.scope
///
/// The dialog is fully controlled by the search state provider.
/// All changes sync immediately to the provider, and the UI
/// rebuilds automatically via ref.watch().
///
/// Opened from the "Refine" chip in the scope filter row.
class RefineSearchDialog extends ConsumerStatefulWidget {
  const RefineSearchDialog({super.key});

  /// Show the dialog.
  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => const RefineSearchDialog(),
    );
  }

  @override
  ConsumerState<RefineSearchDialog> createState() => _RefineSearchDialogState();
}

class _RefineSearchDialogState extends ConsumerState<RefineSearchDialog> {
  // Track expanded nodes in the dialog tree (local UI state only)
  final Set<String> _expandedNodes = {};

  @override
  void initState() {
    super.initState();
    _initializeExpandedNodes();
  }

  /// Initialize which tree nodes should be expanded based on current scope.
  void _initializeExpandedNodes() {
    final scope = ref.read(searchStateProvider).scope;

    // Smart expansion: if specific scopes are selected, expand their parent nodes
    if (scope.isNotEmpty) {
      _expandedNodes.addAll(_getNodesNeedingExpansion(scope));
    }
  }

  /// Determine which nodes should be expanded to show currently selected nodes.
  Set<String> _getNodesNeedingExpansion(Set<String> selectedKeys) {
    final rootNodes = ScopeUtils.getAllChipNodeKeys();
    final nodesToExpand = <String>{};

    for (final selectedKey in selectedKeys) {
      // If it's a root node itself, expand it to show children
      if (rootNodes.contains(selectedKey)) {
        nodesToExpand.add(selectedKey);
        continue;
      }

      // Find which root node covers this selected key
      for (final rootKey in rootNodes) {
        if (ScopeFilterConfig.isNodeCoveredBy(selectedKey, rootKey)) {
          nodesToExpand.add(rootKey);
          break;
        }
      }
    }

    return nodesToExpand;
  }

  void _resetToDefaults() {
    setState(() => _expandedNodes.clear());
    ref.read(searchStateProvider.notifier).setScope({});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final treeAsync = ref.watch(navigationTreeProvider);
    // Watch the scope so UI rebuilds on changes
    final scope = ref.watch(searchStateProvider.select((s) => s.scope));

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 400,
          maxHeight: 600,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              _buildHeader(theme),
              const SizedBox(height: 16),

              // Scope section
              Expanded(
                child: treeAsync.when(
                  data: (tree) => _buildScopeSection(theme, tree, scope),
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  error: (error, _) => Center(
                    child: Text('Error loading tree: $error'),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Action buttons
              _buildActionButtons(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      children: [
        Icon(
          Icons.tune,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Text(
          'Refine Search',
          style: theme.textTheme.titleLarge,
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Close',
        ),
      ],
    );
  }

  Widget _buildScopeSection(
    ThemeData theme,
    List<TipitakaTreeNode> tree,
    Set<String> scope,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'SCOPE',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (scope.isNotEmpty)
              TextButton(
                onPressed: () {
                  ref.read(searchStateProvider.notifier).setScope({});
                },
                child: Text(
                  'Clear',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: theme.colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SingleChildScrollView(
                child: Column(
                  children: tree
                      .map((node) => _buildTreeNode(theme, node, 0, scope))
                      .toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTreeNode(
    ThemeData theme,
    TipitakaTreeNode node,
    int depth,
    Set<String> scope,
  ) {
    // Only show first 3 levels (Pitaka, Nikaya, Vagga)
    if (depth > 2) return const SizedBox.shrink();

    final hasChildren = node.childNodes.isNotEmpty && depth < 2;
    final isExpanded = _expandedNodes.contains(node.nodeKey);
    final isDirectlySelected = scope.contains(node.nodeKey);

    // "All" means empty scope - everything is selected
    final isAllSelected = scope.isEmpty;

    // Check if implicitly selected (an ancestor is selected)
    final isImplicitlySelected =
        ScopeFilterConfig.findCoveringAncestors(node.nodeKey, scope).isNotEmpty;

    // Check if any descendants are selected
    final hasSelectedDescendant = _hasSelectedDescendant(node, scope);

    // Determine checkbox state (tristate)
    final bool? checkboxValue;
    if (isAllSelected || isDirectlySelected || isImplicitlySelected) {
      checkboxValue = true;
    } else if (hasSelectedDescendant) {
      checkboxValue = null; // Partial selection
    } else {
      checkboxValue = false;
    }

    return Column(
      children: [
        InkWell(
          onTap: hasChildren
              ? () => setState(() {
                    if (isExpanded) {
                      _expandedNodes.remove(node.nodeKey);
                    } else {
                      _expandedNodes.add(node.nodeKey);
                    }
                  })
              : null,
          child: Padding(
            padding: EdgeInsets.only(
              left: 8.0 + (depth * 16.0),
              right: 8.0,
            ),
            child: Row(
              children: [
                // Expand/collapse icon
                if (hasChildren)
                  Icon(
                    isExpanded ? Icons.expand_more : Icons.chevron_right,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  )
                else
                  const SizedBox(width: 20),

                // Checkbox
                Checkbox(
                  value: checkboxValue,
                  tristate: true,
                  onChanged: (value) => _toggleNodeSelection(node, scope),
                ),

                // Node name
                Expanded(
                  child: Text(
                    node.sinhalaName.isNotEmpty
                        ? node.sinhalaName
                        : node.paliName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight:
                          (isAllSelected || isDirectlySelected || isImplicitlySelected)
                              ? FontWeight.w600
                              : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Children
        if (hasChildren && isExpanded)
          ...node.childNodes
              .map((child) => _buildTreeNode(theme, child, depth + 1, scope)),
      ],
    );
  }

  bool _hasSelectedDescendant(TipitakaTreeNode node, Set<String> scope) {
    for (final child in node.childNodes) {
      if (scope.contains(child.nodeKey)) {
        return true;
      }
      if (_hasSelectedDescendant(child, scope)) {
        return true;
      }
    }
    return false;
  }

  void _toggleNodeSelection(TipitakaTreeNode node, Set<String> currentScope) {
    final newScope = Set<String>.from(currentScope);

    // Special case: "All" is selected (empty set means everything is included)
    // Clicking any node means "focus on this" = select ONLY this node
    if (newScope.isEmpty) {
      ref.read(searchStateProvider.notifier).setScope({node.nodeKey});
      return;
    }

    if (newScope.contains(node.nodeKey)) {
      // Deselect this node and all descendants
      newScope.remove(node.nodeKey);
      _removeDescendantsFromScope(node, newScope);
    } else {
      // Check if this node is already covered by an ancestor selection
      // If so, remove the ancestor (user wants to narrow down)
      final coveringAncestors =
          ScopeFilterConfig.findCoveringAncestors(node.nodeKey, newScope);
      if (coveringAncestors.isNotEmpty) {
        newScope.removeAll(coveringAncestors);
      }

      // Select this node
      newScope.add(node.nodeKey);

      // Remove any selected descendants (parent selection supersedes)
      _removeDescendantsFromScope(node, newScope);
    }

    // Update provider - UI will rebuild automatically via ref.watch()
    ref.read(searchStateProvider.notifier).setScope(newScope);
  }

  void _removeDescendantsFromScope(TipitakaTreeNode node, Set<String> scope) {
    for (final child in node.childNodes) {
      scope.remove(child.nodeKey);
      _removeDescendantsFromScope(child, scope);
    }
  }

  Widget _buildActionButtons(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: _resetToDefaults,
          child: const Text('Reset'),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
