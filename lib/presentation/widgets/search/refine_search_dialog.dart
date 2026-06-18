import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/l10n/app_localizations.dart';
import '../../../core/utils/pali_letter_options.dart';
import '../../../domain/entities/content/content_language.dart';
import '../../../domain/entities/navigation/tipitaka_tree_node.dart';
import '../../../domain/entities/search/scope_operations.dart';
import '../../providers/content_language_provider.dart';
import '../../providers/navigation_tree_provider.dart';
import '../../providers/overlay_stack_provider.dart';
import '../../providers/pali_letter_options_provider.dart';
import '../../providers/search_provider.dart';
import '../../utils/content_text_formatter.dart';

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
  ///
  /// Registers the dialog on [overlayStackProvider] so the global ESC
  /// shortcut treats it as the topmost dismissible overlay. Without this,
  /// pressing ESC while the dialog is open would pop the underlying FTS
  /// results panel (the next entry on the stack) and leave the dialog
  /// floating above an empty reader — clearly wrong.
  ///
  /// We capture the navigator at show-time so the dismiss callback can pop
  /// the dialog without needing the dialog's own BuildContext. The
  /// try/finally guarantees the stack entry is removed no matter how the
  /// dialog actually closed (ESC, barrier tap, system back, programmatic).
  static Future<void> show(BuildContext context) async {
    final overlayStack = ProviderScope.containerOf(context, listen: false)
        .read(overlayStackProvider.notifier);
    final navigator = Navigator.of(context, rootNavigator: true);
    overlayStack.push(DismissibleOverlay(
      id: 'refine-search-dialog',
      dismiss: () {
        if (navigator.canPop()) navigator.pop();
      },
    ));
    try {
      await showDialog<void>(
        context: context,
        builder: (context) => const RefineSearchDialog(),
      );
    } finally {
      overlayStack.remove('refine-search-dialog');
    }
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
    // Resolve the Content Language once here, then thread it down so each tree
    // row doesn't independently watch it. (Watching here already rebuilds the
    // whole dialog on change — the per-row Builder added nothing.)
    final language = ref.watch(effectiveContentLanguageProvider);
    final options = ref.watch(paliLetterOptionsProvider);
    final l10n = AppLocalizations.of(context);

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
              _buildHeader(theme, l10n),
              const SizedBox(height: 16),

              // Language toggle (පාළි / සිංහල) — which language(s) the search
              // looks in. Sits above the scope tree, applies to Title + FTS.
              _buildLanguageSection(theme, l10n),
              const SizedBox(height: 16),

              // Scope section
              Expanded(
                child: treeAsync.when(
                  data: (tree) => _buildScopeSection(
                      theme, tree, scope, language, options, l10n),
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  error: (_, __) => Center(
                    child: Text(l10n.errorLoadingTree),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Action buttons
              _buildActionButtons(theme, l10n),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, AppLocalizations l10n) {
    return Row(
      children: [
        Icon(
          Icons.tune,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Text(
          l10n.refineSearch,
          style: theme.textTheme.titleLarge,
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: l10n.close,
        ),
      ],
    );
  }

  /// Language toggle row — which language(s) the Title/FTS search looks in.
  ///
  /// A [SegmentedButton] with `emptySelectionAllowed: false` enforces the
  /// "at least one always on" rule for free: tapping the last selected segment
  /// is a no-op, so the user can never search in zero languages. The options
  /// are edition-driven (`availableContentLanguagesProvider`), so an edition
  /// that lacks a language simply won't show that button.
  Widget _buildLanguageSection(ThemeData theme, AppLocalizations l10n) {
    final available = ref.watch(availableContentLanguagesProvider);
    // Nothing to toggle if the edition exposes fewer than two languages.
    if (available.length < 2) return const SizedBox.shrink();

    final searchInPali =
        ref.watch(searchStateProvider.select((s) => s.searchInPali));
    final searchInSinhala =
        ref.watch(searchStateProvider.select((s) => s.searchInSinhala));

    // Current selection as a Set, clamped to available languages. The fallback
    // to "all available" guards SegmentedButton's non-empty assert (the toggle
    // itself can't produce an empty set, but a stale state could).
    final selected = <ContentLanguage>{
      if (searchInPali) ContentLanguage.pali,
      if (searchInSinhala) ContentLanguage.sinhala,
    }.intersection(available.toSet());
    final effectiveSelected = selected.isEmpty ? available.toSet() : selected;

    // When exactly one language is selected, that segment locks: it can't be
    // toggled off. We render this as a dimmed, non-tappable segment (see the
    // style + `enabled` below) so the "at least one always on" rule is *visible*
    // — instead of SegmentedButton's silent no-op when you tap the last segment.
    final lockLast = effectiveSelected.length == 1;
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.searchLanguageLabel.toUpperCase(),
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        // No width wrapper → the bar shrink-wraps to its labels (content width),
        // left-aligned by the Column, instead of stretching across the dialog.
        SegmentedButton<ContentLanguage>(
          showSelectedIcon: false,
          multiSelectionEnabled: true,
          emptySelectionAllowed: false,
          // Restyle the default M3 segmented look to match the quick-filter
          // pills (_ScopeChip uses these same colorScheme tokens), so the
          // language toggle reads as part of the app's filter family — while
          // its connected shape still signals it behaves differently (the
          // locked-last-segment rule) than the always-tappable scope chips.
          // WidgetStateProperty resolves each color per state.
          style: ButtonStyle(
            // Trim the default 48dp tap-target padding so it sits as a compact
            // chip-height bar rather than a chunky button.
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              final isSelected = states.contains(WidgetState.selected);
              // Selected + disabled = the locked language: dim its fill so it
              // clearly reads "on, but you can't turn this off".
              if (isSelected && states.contains(WidgetState.disabled)) {
                return cs.secondary.withValues(alpha: 0.45);
              }
              return isSelected ? cs.secondary : cs.surfaceContainerLow;
            }),
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              final isSelected = states.contains(WidgetState.selected);
              if (isSelected && states.contains(WidgetState.disabled)) {
                return cs.onSecondary.withValues(alpha: 0.7);
              }
              return isSelected ? cs.onSecondary : cs.onSurfaceVariant;
            }),
            // `side` colors BOTH the outer border and the inter-segment divider
            // from one resolved BorderSide (segmented_button.dart) — they can't
            // be styled separately. We copy the quick-filter pill border
            // (_ScopeChip: outline / 1px) so the unselected, clickable segment
            // reads as an identical surfaceContainerLow chip. Trade-off: when
            // both languages are selected the divider over the brown `secondary`
            // fill is faint, because outline ≈ secondary in luminance.
            side: WidgetStateProperty.all(
              BorderSide(color: cs.outline),
            ),
            // Echo the quick-filter pill roundness while staying one connected bar.
            shape: WidgetStateProperty.all(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),
          segments: available.map((lang) {
            final isSelected = effectiveSelected.contains(lang);
            return ButtonSegment<ContentLanguage>(
              value: lang,
              label: Text(_languageLabel(lang, l10n)),
              // Lock the lone selected segment: disabling it makes the tap a
              // no-op AND renders the dimmed style above (visible lock).
              enabled: !(lockLast && isSelected),
            );
          }).toList(),
          selected: effectiveSelected,
          onSelectionChanged: (newSelection) {
            // Single source of truth: searchStateProvider.
            // setLanguageFilter triggers a re-search + recount.
            ref.read(searchStateProvider.notifier).setLanguageFilter(
                  pali: newSelection.contains(ContentLanguage.pali),
                  sinhala: newSelection.contains(ContentLanguage.sinhala),
                );
          },
        ),
      ],
    );
  }

  /// Localized label for a content language (reuses the settings-menu ARB keys).
  String _languageLabel(ContentLanguage language, AppLocalizations l10n) {
    switch (language) {
      case ContentLanguage.pali:
        return l10n.paliLanguageLabel;
      case ContentLanguage.sinhala:
        return l10n.sinhalaLanguageLabel;
    }
  }

  Widget _buildScopeSection(
    ThemeData theme,
    List<TipitakaTreeNode> tree,
    Set<String> scope,
    ContentLanguage language,
    PaliLetterOptions options,
    AppLocalizations l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              l10n.scope.toUpperCase(),
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
                  l10n.clear,
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
                      .map((node) => _buildTreeNode(
                          theme, node, 0, scope, tree, language, options))
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
    ContentLanguage language,
    PaliLetterOptions options,
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

                // Node name — follows the Content Language setting (resolved
                // once in build() and threaded down via [language]).
                Expanded(
                  child: Text(
                    formatContentLabel(
                      node.getDisplayName(language),
                      language,
                      options,
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
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
          ...node.childNodes.map((child) => _buildTreeNode(
              theme, child, depth + 1, scope, tree, language, options)),
      ],
    );
  }

  Widget _buildActionButtons(ThemeData theme, AppLocalizations l10n) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: _resetToDefaults,
          child: Text(l10n.reset),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.done),
        ),
      ],
    );
  }
}
