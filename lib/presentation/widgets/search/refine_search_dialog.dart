import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/navigation/tipitaka_tree_node.dart';
import '../../../domain/entities/search/scope_operations.dart';
import '../../providers/navigation_tree_provider.dart';
import '../../providers/search_provider.dart';

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
      _expandedNodes.addAll(ScopeOperations.getNodesNeedingExpansion(scope));
    }
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
                      .map((node) => _buildTreeNode(theme, node, 0, scope, tree))
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
    List<TipitakaTreeNode> tree,
  ) {
    // Only show first 3 levels (Pitaka, Nikaya, Vagga)
    if (depth > 2) return const SizedBox.shrink();

    final hasChildren = node.childNodes.isNotEmpty && depth < 2;
    final isExpanded = _expandedNodes.contains(node.nodeKey);

    // Use ScopeOperations to determine checkbox state (tristate)
    final checkboxValue = ScopeOperations.getCheckboxState(node, scope);
    final isSelected = checkboxValue == true;

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
                  onChanged: (_) {
                    // Use ScopeOperations for toggle logic with tree for auto-collapse
                    final newScope = ScopeOperations.toggleNodeSelection(
                      node,
                      scope,
                      treeRoots: tree,
                    );
                    ref.read(searchStateProvider.notifier).setScope(newScope);
                  },
                ),

                // Node name
                Expanded(
                  child: Text(
                    node.sinhalaName.isNotEmpty
                        ? node.sinhalaName
                        : node.paliName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
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
              .map((child) => _buildTreeNode(theme, child, depth + 1, scope, tree)),
      ],
    );
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
