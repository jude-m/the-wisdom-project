import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/l10n/app_localizations.dart';
import '../../../core/theme/app_typography.dart';
import '../../models/reader_layout.dart';
import '../../providers/parallel_text_provider.dart';
import '../../utils/content_icons.dart';
import '../../providers/tab_provider.dart'
    show activeReaderLayoutProvider, updateActiveTabLayoutProvider;

/// Mode 1: Horizontal pill of icon buttons shown at top-right when the user
/// hasn't scrolled past the first viewport.
///
/// Contains up to 3 buttons (commentary toggle, search, scroll/navigate).
/// Buttons are conditionally included based on context.
class ReaderActionButtonGroup extends ConsumerWidget {
  final VoidCallback onSearchTap;
  final VoidCallback? onScrollTap;
  final IconData? scrollIcon;
  final String? scrollTooltip;

  const ReaderActionButtonGroup({
    super.key,
    required this.onSearchTap,
    this.onScrollTap,
    this.scrollIcon,
    this.scrollTooltip,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final targetNode = ref.watch(parallelTextNodeProvider);
    final isCommentary = ref.watch(isCommentaryProvider);
    final l10n = AppLocalizations.of(context);

    return Material(
      elevation: 1,
      borderRadius: BorderRadius.circular(24),
      color: colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Commentary/Root text toggle — hidden when no parallel text
            if (targetNode != null)
              _ActionIconButton(
                icon: contentIcon(
                  isCommentary: !isCommentary,
                  colorScheme: colorScheme,
                ).icon,
                tooltip: isCommentary ? l10n.rootText : l10n.commentary,
                onTap: () => ref.read(openParallelTextProvider)(),
              ),
            // In-page search
            _ActionIconButton(
              icon: Icons.search,
              tooltip: l10n.findInPage,
              onTap: onSearchTap,
            ),
            // Scroll to beginning / Go to previous sutta
            if (onScrollTap != null)
              _ActionIconButton(
                icon: scrollIcon ?? Icons.vertical_align_top,
                tooltip: scrollTooltip ?? l10n.scrollToBeginning,
                onTap: onScrollTap!,
              ),
          ],
        ),
      ),
    );
  }
}

/// Floating pill showing the layout selector (P / P+S / P|S / S).
/// Shown at top-right when the user is at the sutta beginning.
/// Matches the visual style of [ReaderActionButtonGroup] — no outlines.
class ReaderLayoutPill extends ConsumerWidget {
  const ReaderLayoutPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentLayout = ref.watch(activeReaderLayoutProvider);
    return Material(
      elevation: 1,
      borderRadius: BorderRadius.circular(24),
      color: colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final layout in ReaderLayout.values)
              _LayoutOptionButton(
                layout: layout,
                tooltip: _tooltipFor(context, layout),
                isSelected: currentLayout == layout,
                onTap: () =>
                    ref.read(updateActiveTabLayoutProvider)(layout),
              ),
          ],
        ),
      ),
    );
  }
}

/// Mode 2: Expandable FAB at bottom-right shown when the user has scrolled
/// past one viewport height.
///
/// Collapsed: single pill with a menu icon.
/// Expanded: vertical column of labeled action items above the trigger.
///
/// Pass [visible] = false when the FAB is faded out so it auto-collapses.
class ReaderExpandableFab extends ConsumerStatefulWidget {
  final VoidCallback onSearchTap;
  final VoidCallback onScrollTap;
  final String? scrollTooltip;
  final bool visible;

  const ReaderExpandableFab({
    super.key,
    required this.onSearchTap,
    required this.onScrollTap,
    this.scrollTooltip,
    this.visible = true,
  });

  @override
  ConsumerState<ReaderExpandableFab> createState() =>
      _ReaderExpandableFabState();
}

class _ReaderExpandableFabState extends ConsumerState<ReaderExpandableFab> {
  bool _isExpanded = false;

  @override
  void didUpdateWidget(ReaderExpandableFab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Auto-collapse when the FAB becomes invisible
    if (!widget.visible && oldWidget.visible && _isExpanded) {
      setState(() => _isExpanded = false);
    }
  }

  void _collapse() {
    setState(() => _isExpanded = false);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final targetNode = ref.watch(parallelTextNodeProvider);
    final isCommentary = ref.watch(isCommentaryProvider);
    final currentLayout = ref.watch(activeReaderLayoutProvider);
    final l10n = AppLocalizations.of(context);

    return TapRegion(
      // Collapse when the user taps outside the FAB
      onTapOutside: (_) {
        if (_isExpanded) _collapse();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Expanded action items — animated size for smooth expand/collapse
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: Alignment.bottomCenter,
            child: _isExpanded
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Layout selector — per-tab setting
                      _FabLayoutSelector(
                        currentLayout: currentLayout,
                        onLayoutChanged: (layout) {
                          ref.read(updateActiveTabLayoutProvider)(layout);
                        },
                      ),
                      const SizedBox(height: 8),
                      // Divider between layout and actions
                      SizedBox(
                        width: 120,
                        child: Divider(
                          height: 1,
                          thickness: 1,
                          color: colorScheme.outlineVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Commentary/Root text toggle
                      if (targetNode != null) ...[
                        _FabActionItem(
                          icon: contentIcon(
                            isCommentary: !isCommentary,
                            colorScheme: colorScheme,
                          ).icon,
                          label:
                              isCommentary ? l10n.rootText : l10n.commentary,
                          onTap: () {
                            _collapse();
                            ref.read(openParallelTextProvider)();
                          },
                        ),
                        const SizedBox(height: 8),
                      ],
                      // In-page search
                      _FabActionItem(
                        icon: Icons.search,
                        label: l10n.findInPage,
                        onTap: () {
                          _collapse();
                          widget.onSearchTap();
                        },
                      ),
                      const SizedBox(height: 8),
                      // Scroll to beginning
                      _FabActionItem(
                        icon: Icons.vertical_align_top,
                        label: widget.scrollTooltip ?? l10n.scrollToBeginning,
                        onTap: () {
                          _collapse();
                          widget.onScrollTap();
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
          // FAB trigger button
          Material(
            elevation: _isExpanded ? 4 : 2,
            borderRadius: BorderRadius.circular(16),
            color: colorScheme.surfaceContainer,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: AnimatedRotation(
                  turns: _isExpanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  child: Icon(
                    _isExpanded ? Icons.close : Icons.more_vert,
                    size: 24,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual icon button used inside [ReaderActionButtonGroup].
/// No background — the parent Material provides the shared surface.
/// Uses ConstrainedBox to meet the 44x44 minimum accessible touch target.
class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: 44,
            minHeight: 44,
          ),
          child: Icon(
            icon,
            size: 20,
            color: colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

/// Returns the localized tooltip for a given [ReaderLayout].
String _tooltipFor(BuildContext context, ReaderLayout layout) {
  final l10n = AppLocalizations.of(context);
  return switch (layout) {
    ReaderLayout.paliOnly => l10n.layoutPaliOnly,
    ReaderLayout.sideBySide => l10n.layoutSideBySide,
    ReaderLayout.stacked => l10n.layoutStacked,
    ReaderLayout.sinhalaOnly => l10n.layoutSinhalaOnly,
  };
}

/// Maps each [ReaderLayout] to an icon (for dual-language modes) or `null`
/// (for single-language modes that use a text label instead).
const _layoutIcons = {
  ReaderLayout.sideBySide: Icons.vertical_split,
  ReaderLayout.stacked: Icons.horizontal_split,
};

/// Individual layout option button used inside [ReaderLayoutPill] and
/// [_FabLayoutSelector]. Shows an icon or a text label depending on the layout.
/// Selected state is indicated by primary color + bold weight.
class _LayoutOptionButton extends StatelessWidget {
  final ReaderLayout layout;
  final String tooltip;
  final bool isSelected;
  final VoidCallback onTap;

  const _LayoutOptionButton({
    required this.layout,
    required this.tooltip,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final segmentStyle = context.typography.segmentedButtonLabel;
    final color =
        isSelected ? colorScheme.onSecondaryContainer : colorScheme.onSurfaceVariant;
    final icon = _layoutIcons[layout];

    return Tooltip(
      message: tooltip,
      child: Material(
        color: isSelected
            ? colorScheme.secondaryContainer
            : Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: 44,
              minHeight: 44,
            ),
            child: Center(
              child: icon != null
                  ? Icon(icon, size: 20, color: color)
                  : Text(
                      layout.shortLabel,
                      style: segmentStyle.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Layout selector shown inside the expanded [ReaderExpandableFab].
/// Matches the outline-free style of [ReaderLayoutPill].
class _FabLayoutSelector extends StatelessWidget {
  final ReaderLayout currentLayout;
  final ValueChanged<ReaderLayout> onLayoutChanged;

  const _FabLayoutSelector({
    required this.currentLayout,
    required this.onLayoutChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(20),
      color: colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final layout in ReaderLayout.values)
              _LayoutOptionButton(
                layout: layout,
                tooltip: _tooltipFor(context, layout),
                isSelected: currentLayout == layout,
                onTap: () => onLayoutChanged(layout),
              ),
          ],
        ),
      ),
    );
  }
}

/// Labeled action item used in the expanded [ReaderExpandableFab] menu.
class _FabActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _FabActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(20),
      color: colorScheme.surfaceContainer,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colorScheme.primary,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
