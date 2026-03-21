import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SelectedContent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/constants.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../domain/entities/bjt/bjt_page.dart';
import '../../models/in_page_search_state.dart';
import '../../providers/tab_provider.dart'
    show activeSplitRatioProvider, updateActiveTabSplitRatioProvider;
import '../resizable_divider.dart';
import 'entry_key_registry.dart';
import 'reader_entry_builder.dart';

/// A dual-column reader pane for side-by-side Pali/Sinhala display mode.
///
/// Uses [SingleChildScrollView] with paired entry rows (each row contains
/// both Pali and Sinhala entries side-by-side). On tablet/desktop, includes
/// a draggable divider overlay for resizing panes.
///
/// Watches [activeSplitRatioProvider] internally for split ratio changes,
/// so the parent widget doesn't rebuild on divider drags.
class DualColumnPane extends ConsumerWidget {
  const DualColumnPane({
    super.key,
    required this.scrollController,
    required this.pages,
    required this.entryStart,
    required this.absolutePageStart,
    required this.searchState,
    required this.currentMatchKey,
    required this.entryKeyRegistry,
    required this.onTapEmpty,
    this.onWordTap,
    required this.onSelectionChanged,
    required this.contextMenuBuilder,
  });

  final ScrollController scrollController;
  final List<BJTPage> pages;
  final int entryStart;
  final int absolutePageStart;
  final InPageSearchState searchState;

  /// Attached to the current search match row for scroll-to-match.
  final GlobalKey currentMatchKey;

  /// Registry for entry-level GlobalKeys used to sync scroll position
  /// across layout switches.
  final EntryKeyRegistry entryKeyRegistry;

  /// Called when tapping empty space (clears highlights).
  final VoidCallback onTapEmpty;

  /// Called when a word is tapped (for dictionary lookup).
  final void Function(String word)? onWordTap;

  final void Function(SelectedContent?) onSelectionChanged;
  final Widget Function(BuildContext, SelectableRegionState) contextMenuBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTabletOrDesktop = ResponsiveUtils.isTabletOrDesktop(context);
    // Watch split ratio — only this widget rebuilds on divider drag
    final splitRatio = ref.watch(activeSplitRatioProvider);

    return SelectionArea(
      onSelectionChanged: onSelectionChanged,
      contextMenuBuilder: contextMenuBuilder,
      child: GestureDetector(
        onTap: onTapEmpty,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            // Main scrollable content
            SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Spacer so content doesn't hide behind button group
                    const SizedBox(
                        height:
                            PaneWidthConstants.readerActionButtonGroupHeight),
                    // Content rows - each page with paired entries
                    ..._buildBothModePages(context, splitRatio),
                  ],
                ),
              ),
            ),
            // Single draggable divider overlay (tablet/desktop only)
            if (isTabletOrDesktop)
              _buildDividerOverlay(context, ref, splitRatio),
          ],
        ),
      ),
    );
  }

  /// Builds the page content for side-by-side Pali/Sinhala.
  /// On the first page, skips entries before [entryStart].
  List<Widget> _buildBothModePages(BuildContext context, double splitRatio) {
    final widgets = <Widget>[];
    final currentMatch = searchState.currentMatch;
    final effectiveQuery = searchState.effectiveQuery;
    final hasQuery = searchState.hasActiveQuery;

    for (var pageIndex = 0; pageIndex < pages.length; pageIndex++) {
      final page = pages[pageIndex];
      final absolutePageIndex = absolutePageStart + pageIndex;
      // On first page, skip entries before entryStart
      final startEntry = pageIndex == 0 ? entryStart : 0;

      // Page number row - uses split layout
      widgets.add(
        _buildSplitRow(
          context,
          splitRatio: splitRatio,
          leftChild:
              ReaderEntryBuilder.buildPageNumber(context, page.pageNumber),
          rightChild:
              ReaderEntryBuilder.buildPageNumber(context, page.pageNumber),
        ),
      );
      widgets.add(const SizedBox(height: 16));

      // Paired entry rows - skip entries before startEntry on first page
      final entryCount = page.paliSection.entries.length - startEntry;
      for (var i = 0; i < entryCount; i++) {
        final entryIndex = i + startEntry;
        final paliEntry = page.paliSection.entries[entryIndex];
        final sinhalaEntry = entryIndex < page.sinhalaSection.entries.length
            ? page.sinhalaSection.entries[entryIndex]
            : null;

        // Determine if either entry is the current match
        final isPaliCurrentMatch = currentMatch != null &&
            currentMatch.pageIndex == absolutePageIndex &&
            currentMatch.entryIndex == entryIndex &&
            currentMatch.languageCode == 'pi';
        final isSinhalaCurrentMatch = currentMatch != null &&
            currentMatch.pageIndex == absolutePageIndex &&
            currentMatch.entryIndex == entryIndex &&
            currentMatch.languageCode == 'si';

        // Pali entry widget — only highlight if this entry has matches
        final paliHasMatch = hasQuery &&
            searchState.hasMatchInEntry(absolutePageIndex, entryIndex, 'pi');
        final paliWidget = ReaderEntryBuilder.buildEntry(
          context,
          paliEntry,
          enableDictionaryLookup: true,
          inPageSearchQuery: paliHasMatch ? effectiveQuery : null,
          currentMatchIndexInEntry:
              isPaliCurrentMatch ? currentMatch.matchIndexInEntry : null,
          onWordTap: onWordTap,
        );

        // Sinhala entry widget — only highlight if this entry has matches
        final sinhalaHasMatch = hasQuery &&
            searchState.hasMatchInEntry(absolutePageIndex, entryIndex, 'si');
        final sinhalaWidget = sinhalaEntry != null
            ? ReaderEntryBuilder.buildEntry(
                context,
                sinhalaEntry,
                enableDictionaryLookup: false,
                inPageSearchQuery: sinhalaHasMatch ? effectiveQuery : null,
                currentMatchIndexInEntry: isSinhalaCurrentMatch
                    ? currentMatch.matchIndexInEntry
                    : null,
                onWordTap: onWordTap,
              )
            : const SizedBox.shrink();

        // Wrap the current match entry with a GlobalKey for scroll-to-match
        final isCurrentMatchRow = isPaliCurrentMatch || isSinhalaCurrentMatch;

        // Wrap with registry key for layout-switch scroll sync
        widgets.add(
          KeyedSubtree(
            key: entryKeyRegistry.keyFor(absolutePageIndex, entryIndex),
            child: Padding(
              key: isCurrentMatchRow ? currentMatchKey : null,
              padding: const EdgeInsets.only(bottom: 12.0),
              child: _buildSplitRow(
                context,
                splitRatio: splitRatio,
                leftChild: paliWidget,
                rightChild: sinhalaWidget,
              ),
            ),
          ),
        );
      }

      widgets.add(const SizedBox(height: 32)); // Space between pages
    }

    return widgets;
  }

  /// Builds a row with split layout for side-by-side columns.
  /// Uses a thin vertical line as separator (actual dragging handled by overlay).
  Widget _buildSplitRow(
    BuildContext context, {
    required double splitRatio,
    required Widget leftChild,
    required Widget rightChild,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTabletOrDesktop = ResponsiveUtils.isTabletOrDesktop(context);

        // Divider width: thin line on tablet/desktop, gap on mobile
        final dividerWidth =
            isTabletOrDesktop ? PaneWidthConstants.dividerWidth : 24.0;

        // Calculate pane widths based on split ratio
        final availableWidth = constraints.maxWidth - dividerWidth;
        final leftWidth = availableWidth * splitRatio;
        final rightWidth = availableWidth * (1 - splitRatio);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left pane (Pali)
            SizedBox(
              width: leftWidth,
              child: Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: leftChild,
              ),
            ),
            // Thin vertical line separator (tablet/desktop) or simple gap (mobile)
            // Note: The actual drag interaction is handled by _buildDividerOverlay
            SizedBox(width: dividerWidth),
            // Right pane (Sinhala)
            SizedBox(
              width: rightWidth,
              child: Padding(
                padding: const EdgeInsets.only(left: 12.0),
                child: rightChild,
              ),
            ),
          ],
        );
      },
    );
  }

  /// Builds the draggable divider overlay positioned at the split ratio.
  /// This single divider handles all drag interactions for resizing panes.
  /// Only visible on hover (the pill handle appears on mouse hover).
  Widget _buildDividerOverlay(
      BuildContext context, WidgetRef ref, double splitRatio) {
    // Content area has 24px padding on each side (matches SingleChildScrollView padding)
    const horizontalPadding = 24.0;

    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final contentWidth = constraints.maxWidth - (horizontalPadding * 2);

          // Position divider at the split point within the content area
          // Account for padding offset and center the divider on the split line
          final dividerLeft = horizontalPadding +
              (contentWidth * splitRatio) -
              (PaneWidthConstants.dividerWidth / 2);

          // Use Padding + Align instead of nested Stack for simpler structure
          return Padding(
            padding: EdgeInsets.only(left: dividerLeft),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ResizableDivider(
                hideWhenIdle: true, // Only show pill on hover
                onDragUpdate: (delta) {
                  // Convert pixel delta to ratio change relative to content width
                  final ratioChange = delta / contentWidth;
                  final currentRatio = ref.read(activeSplitRatioProvider);
                  ref.read(updateActiveTabSplitRatioProvider)(
                      currentRatio + ratioChange);
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
