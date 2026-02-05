import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SelectedContent;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/constants.dart';
import '../../core/localization/l10n/app_localizations.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/text_entry_theme.dart';
import '../../core/utils/pali_conjunct_transformer.dart';
import '../../core/utils/responsive_utils.dart';
import '../models/column_display_mode.dart';
import '../../domain/entities/content/entry.dart';
import '../../domain/entities/content/entry_type.dart';
import '../providers/document_provider.dart';
import '../providers/dictionary_provider.dart'
    show
        selectedDictionaryWordProvider,
        dictionaryHighlightProvider,
        hasActiveSelectionProvider;
import '../providers/tab_provider.dart'
    show
        activeTabIndexProvider,
        saveTabScrollPositionProvider,
        getTabScrollPositionProvider,
        activePageStartProvider,
        activePageEndProvider,
        activeEntryStartProvider,
        activeColumnModeProvider,
        activeNodeKeyProvider,
        activeSplitRatioProvider,
        updateActiveTabPaginationProvider,
        updateActiveTabSplitRatioProvider;
import '../providers/navigation_tree_provider.dart' show nodeByKeyProvider;
import '../providers/fts_highlight_provider.dart';
import 'reader/text_entry_widget.dart';
import 'reader/parallel_text_button.dart';
import 'dictionary/dictionary_bottom_sheet.dart';
import 'resizable_divider.dart';

/// Number of entries to reveal per "scroll up gradually" click
const int kScrollUpEntryStep = 5;

class MultiPaneReaderWidget extends ConsumerStatefulWidget {
  const MultiPaneReaderWidget({super.key});

  @override
  ConsumerState<MultiPaneReaderWidget> createState() =>
      _MultiPaneReaderWidgetState();
}

class _MultiPaneReaderWidgetState extends ConsumerState<MultiPaneReaderWidget> {
  // Single scroll controller for all modes
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Add scroll listener for automatic page loading
    _scrollController.addListener(_onScroll);
  }

  /// Scroll listener for infinite scroll behavior.
  void _onScroll() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;
      final delta = maxScroll - currentScroll;

      // Infinite scroll: load next page when user scrolls near bottom (within 200px)
      if (delta < 200) {
        _loadMorePagesIfNeeded();
      }
    }
  }

  /// Loads more pages if available.
  ///
  /// Documents are loaded page-by-page to save memory. This method handles two scenarios:
  /// 1. Infinite scroll: Called without [scheduleNextCheck] when user scrolls near bottom
  /// 2. Initial fill: Called with [scheduleNextCheck]=true to keep loading until
  ///    content fills the screen (solves "can't scroll to load more" problem)
  void _loadMorePagesIfNeeded({bool scheduleNextCheck = false}) {
    // Step 1: Get the current document (async state)
    final contentAsync = ref.read(currentBJTDocumentProvider);

    // Step 2: Only proceed if we have actual data (not loading/error)
    contentAsync.whenData((content) {
      // Step 3: Only proceed if document exists
      if (content != null) {
        // Step 4: Get current last page number being shown
        final currentEnd = ref.read(activePageEndProvider);

        // Step 5: Check if there are more pages to load
        if (currentEnd < content.pageCount) {
          // Step 6: Load one more page
          ref.read(loadMorePagesProvider)(1);

          // Step 7: If asked to keep checking (initial fill mode), schedule another check
          if (scheduleNextCheck && _scrollController.hasClients) {
            // Step 8: Wait for Flutter to rebuild the UI with new content
            WidgetsBinding.instance.addPostFrameCallback((_) {
              // Step 9: If content STILL doesn't fill the screen, load more (recursive)
              if (_scrollController.hasClients &&
                  _scrollController.position.maxScrollExtent <= 0) {
                _loadMorePagesIfNeeded(scheduleNextCheck: true);
              }
            });
          }
        }
      }
    });
  }

  @override
  void dispose() {
    // Note: We cannot use ref.read() in dispose() as the widget is already unmounted.
    // Scroll position is saved when switching tabs (in the ref.listen callback)
    // and when navigating away, so we don't need to save here.
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _saveScrollPosition([int? index]) {
    final int activeTabIndex = index ?? ref.read(activeTabIndexProvider);
    if (activeTabIndex >= 0 && _scrollController.hasClients) {
      ref.read(saveTabScrollPositionProvider)(
          activeTabIndex, _scrollController.offset);
      // Note: Pagination state (pageStart, pageEnd, entryStart) is already
      // stored in the tab entity and updated via updateActiveTabPaginationProvider
      // when loading more pages, so no need to sync it here.
    }
  }

  /// Scrolls to the beginning of the current sutta.
  /// Behaves the same as loading from the navigation tree.
  void _scrollToBeginning() {
    final nodeKey = ref.read(activeNodeKeyProvider);
    if (nodeKey == null) return;

    final node = ref.read(nodeByKeyProvider(nodeKey));
    if (node == null) return;

    // Reset pagination to the sutta's beginning
    ref.read(updateActiveTabPaginationProvider)(
      pageStart: node.entryPageIndex,
      pageEnd: node.entryPageIndex + 1,
      entryStart: node.entryIndexInPage,
    );

    // Reset scroll to top - same as loading from navigator
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }

    // After resetting pagination, ensure enough pages are loaded to fill the screen.
    // This is necessary because the single page might not have enough content to
    // enable scrolling (e.g., if the sutta starts near the end of a page).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMorePagesIfNeeded(scheduleNextCheck: true);
    });
  }

  /// Reveals more content above by decreasing entryStart by kScrollUpEntryStep.
  /// Respects the sutta's beginning position (won't go to a previous sutta).
  /// User's scroll position is preserved so they can scroll up to see new content.
  void _scrollUpGradually() {
    // Get the nodeKey of the current sutta
    final nodeKey = ref.read(activeNodeKeyProvider);
    if (nodeKey == null) return;

    // Look up the node to find the sutta's actual start position
    final node = ref.read(nodeByKeyProvider(nodeKey));
    if (node == null) return;

    final currentPageStart = ref.read(activePageStartProvider);
    final currentEntryStart = ref.read(activeEntryStartProvider);

    // Determine the minimum entry we can scroll to on the current page
    // On the sutta's start page, don't go below the sutta's start entry
    // On later pages, we can go down to entry 0
    final minEntryOnCurrentPage =
        currentPageStart == node.entryPageIndex ? node.entryIndexInPage : 0;

    if (currentEntryStart > minEntryOnCurrentPage) {
      // Still have room to scroll up on current page - decrease entryStart by step
      final newEntryStart = (currentEntryStart - kScrollUpEntryStep)
          .clamp(minEntryOnCurrentPage, currentEntryStart);
      ref.read(updateActiveTabPaginationProvider)(entryStart: newEntryStart);
      // Don't reset scroll - user can scroll up to see new content
    } else if (currentPageStart > node.entryPageIndex) {
      // At entry 0 on current page, but not yet at sutta's start page
      // Go to previous page
      // Don't reset scroll - new page content appears above
      final newPageStart = currentPageStart - 1;
      // If moving to the sutta's start page, stop at the sutta heading entry
      // Otherwise, start from entry 0 (will be clamped on next tap)
      final newEntryStart =
          newPageStart == node.entryPageIndex ? node.entryIndexInPage : 0;
      ref.read(updateActiveTabPaginationProvider)(
        pageStart: newPageStart,
        entryStart: newEntryStart,
      );
    }
    // If we're already at the sutta's beginning, do nothing
  }

  void _restoreScrollPosition() {
    final activeTabIndex = ref.read(activeTabIndexProvider);
    if (activeTabIndex >= 0) {
      // Pagination state is derived from the active tab automatically via
      // activePageStartProvider, activePageEndProvider, activeEntryStartProvider.
      // Just restore the scroll position after a frame (to let content rebuild).
      if (_scrollController.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            final scrollOffset =
                ref.read(getTabScrollPositionProvider)(activeTabIndex);
            final maxExtent = _scrollController.position.maxScrollExtent;
            final targetOffset = scrollOffset.clamp(0.0, maxExtent);
            _scrollController.jumpTo(targetOffset);
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to active tab changes
    ref.listen<int>(activeTabIndexProvider, (previous, next) {
      if (previous != null && previous != next) {
        // Save scroll position for the previous tab, but ONLY if:
        // - previous was a valid tab (>= 0)
        // - next is also a valid tab (>= 0) - meaning we're switching, not closing
        // This prevents saving the closed tab's scroll position to the wrong index
        if (previous >= 0 && next >= 0) {
          _saveScrollPosition(previous);
        }

        // Reset scroll to 0 (always reset when tab changes)
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }

        // Column mode is now per-tab and derived from activeColumnModeProvider
        // No need to override or reset - each tab remembers its own column mode

        // Then restore the actual saved position for the new tab after content renders
        // (only if transitioning to a valid tab, not to -1)
        if (next >= 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _restoreScrollPosition();
            // Cached content: When switching tabs, if the document is already cached,
            // the content listener below won't fire. This ensures pages still load.
            _loadMorePagesIfNeeded(scheduleNextCheck: true);
          });
        }
      }
    });

    // Listen to content loading state and restore scroll position after content is loaded
    ref.listen(currentBJTDocumentProvider, (previous, next) {
      // When content finishes loading (transitions to AsyncData with actual content)
      next.whenData((content) {
        if (content != null && previous?.value == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _restoreScrollPosition();
            // Fresh content: Document just loaded (cache miss). Ensure initial
            // pages fill the screen so user can scroll to load more.
            _loadMorePagesIfNeeded(scheduleNextCheck: true);
          });
        }
      });
    });

    final contentAsync = ref.watch(currentBJTDocumentProvider);
    // Watch per-tab column mode (each tab remembers its own setting)
    final columnMode = ref.watch(activeColumnModeProvider);
    // Watch selected word to conditionally mount the dictionary sheet
    final selectedWord = ref.watch(selectedDictionaryWordProvider);
    // Watch pagination state to determine if scroll up buttons should show
    final pageStart = ref.watch(activePageStartProvider);
    final entryStart = ref.watch(activeEntryStartProvider);

    // Determine if we're past the sutta's beginning (to show scroll up buttons)
    final nodeKey = ref.watch(activeNodeKeyProvider);
    final node = nodeKey != null ? ref.watch(nodeByKeyProvider(nodeKey)) : null;
    final isAfterSuttaBeginning = node != null &&
        (pageStart > node.entryPageIndex ||
            (pageStart == node.entryPageIndex &&
                entryStart > node.entryIndexInPage));

    return Stack(
      children: [
        // Main content area
        Column(
          children: [
            Expanded(
              child: contentAsync.when(
                data: (content) {
                  if (content == null) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.menu_book_outlined,
                            size: 64,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Select a sutta from the tree to begin reading',
                            style: context.typography.emptyStateMessage,
                          ),
                        ],
                      ),
                    );
                  }

                  // Get page end from derived provider (pageStart already watched above)
                  final pageEnd = ref.watch(activePageEndProvider);

                  // Show only the loaded page slice
                  final pagesToShow = content.pages.sublist(
                    pageStart.clamp(0, content.pageCount),
                    pageEnd.clamp(0, content.pageCount),
                  );

                  if (pagesToShow.isEmpty) {
                    return const Center(
                      child: Text('No content to display'),
                    );
                  }

                  // Build the layout based on column mode
                  // (entryStart already watched above for isAfterSuttaBeginning check)
                  return _buildContentLayout(
                    context,
                    pagesToShow,
                    columnMode,
                    entryStart,
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
                          'Error loading content',
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
        ),
        // Scroll up buttons (only when current position is after sutta's beginning)
        // Allows user to see content before the search result position
        if (isAfterSuttaBeginning)
          Positioned(
            top: 16,
            right: 16,
            child: _ScrollUpButtons(
              onScrollToBeginning: _scrollToBeginning,
              onScrollUpGradually: _scrollUpGradually,
            ),
          ),
        // Non-modal dictionary bottom sheet overlay
        // Only mounted when a word is selected (conditional mounting for performance)
        if (selectedWord != null) const DictionaryBottomSheet(),
      ],
    );
  }

  /// Handles text selection changes.
  /// - Stores selected text for copy functionality
  /// - Clears dictionary highlight and hides bottom sheet to prevent visual conflict
  /// - Tracks selection state to prevent dictionary from opening during selection gestures
  void _onSelectionChanged(SelectedContent? selection) {
    if (selection != null && selection.plainText.isNotEmpty) {
      // Store selected text for the copy action
      _currentSelectedText = selection.plainText;
      // Mark that selection is active - prevents dictionary from opening on taps
      ref.read(hasActiveSelectionProvider.notifier).state = true;
      // Clear dictionary highlight when user starts selecting text
      ref.read(dictionaryHighlightProvider.notifier).state = null;
      // Hide dictionary bottom sheet when selection starts
      ref.read(selectedDictionaryWordProvider.notifier).state = null;
    } else {
      _currentSelectedText = null;
      // Use post-frame callback to clear selection state AFTER tap handlers run.
      // This allows tap handler to see hasActiveSelection=true and skip dictionary,
      // then this callback clears it for subsequent taps.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(hasActiveSelectionProvider.notifier).state = false;
      });
    }
  }

  /// Tracks the currently selected text for the context menu.
  /// Updated via onSelectionChanged callback.
  String? _currentSelectedText;

  /// Builds the custom context menu for text selection.
  /// Provides "Copy" (functional) and "More" (UI placeholder) actions.
  /// Returns empty widget if no text is selected (e.g., long-press on empty space).
  Widget _buildSelectionContextMenu(
    BuildContext context,
    SelectableRegionState selectableRegionState,
  ) {
    // Don't show context menu if nothing is selected
    if (_currentSelectedText == null || _currentSelectedText!.isEmpty) {
      return const SizedBox.shrink();
    }

    final List<ContextMenuButtonItem> buttonItems = [
      // Copy button - copies selected text to clipboard
      ContextMenuButtonItem(
        label: 'Copy',
        onPressed: () {
          // Copy the currently selected text to clipboard
          if (_currentSelectedText != null &&
              _currentSelectedText!.isNotEmpty) {
            Clipboard.setData(ClipboardData(text: _currentSelectedText!));
          }
          // Hide the context menu and clear selection
          selectableRegionState.hideToolbar();
        },
      ),
      // More button - UI placeholder for future features (Highlight, Share, etc.)
      ContextMenuButtonItem(
        label: 'More',
        onPressed: () {
          // TODO: Implement more options (Highlight, Share, etc.)
          // For now, just hide the menu
          selectableRegionState.hideToolbar();
          // Show a snackbar as placeholder feedback
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('More options coming soon'),
              duration: Duration(seconds: 1),
            ),
          );
        },
      ),
    ];

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: selectableRegionState.contextMenuAnchors,
      buttonItems: buttonItems,
    );
  }

  Widget _buildContentLayout(
    BuildContext context,
    List<dynamic> pages,
    ColumnDisplayMode columnMode,
    int entryStart,
  ) {
    switch (columnMode) {
      case ColumnDisplayMode.paliOnly:
        return SelectionArea(
          onSelectionChanged: _onSelectionChanged,
          contextMenuBuilder: (context, selectableRegionState) =>
              _buildSelectionContextMenu(context, selectableRegionState),
          child: GestureDetector(
            // Clear all highlights when tapping empty space
            onTap: _clearAllHighlights,
            behavior: HitTestBehavior.translucent,
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(24.0),
              itemCount: pages.length + 1, // +1 for commentary link button
              itemBuilder: (context, index) {
                // First item is the commentary link button
                if (index == 0) {
                  return const ParallelTextButton();
                }
                // Adjust index for pages (index-1 since button is at 0)
                final pageIndex = index - 1;
                final page = pages[pageIndex];
                // On first page, skip entries before entryStart
                final entries = pageIndex == 0
                    ? page.paliSection.entries.skip(entryStart).toList()
                    : page.paliSection.entries;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPageNumber(context, page.pageNumber),
                    const SizedBox(height: 16),
                    // Enable dictionary lookup for Pali text
                    ..._buildEntries(
                      context,
                      entries,
                      enableDictionaryLookup: true,
                    ),
                    const SizedBox(height: 32), // Space between pages
                  ],
                );
              },
            ),
          ),
        );

      case ColumnDisplayMode.sinhalaOnly:
        return SelectionArea(
          onSelectionChanged: _onSelectionChanged,
          contextMenuBuilder: (context, selectableRegionState) =>
              _buildSelectionContextMenu(context, selectableRegionState),
          child: GestureDetector(
            onTap: _clearAllHighlights,
            behavior: HitTestBehavior.translucent,
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(24.0),
              itemCount: pages.length + 1, // +1 for commentary link button
              itemBuilder: (context, index) {
                // First item is the commentary link button
                if (index == 0) {
                  return const ParallelTextButton();
                }
                // Adjust index for pages (index-1 since button is at 0)
                final pageIndex = index - 1;
                final page = pages[pageIndex];
                // On first page, skip entries before entryStart
                final entries = pageIndex == 0
                    ? page.sinhalaSection.entries.skip(entryStart).toList()
                    : page.sinhalaSection.entries;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPageNumber(context, page.pageNumber),
                    const SizedBox(height: 16),
                    // Disable dictionary lookup for Sinhala translation text
                    ..._buildEntries(context, entries,
                        enableDictionaryLookup: false),
                    const SizedBox(height: 32), // Space between pages
                  ],
                );
              },
            ),
          ),
        );

      case ColumnDisplayMode.both:
        // Row-based layout for proper vertical alignment
        // Each row contains both Pali and Sinhala entries side-by-side
        // On tablet/desktop: resizable split pane with draggable divider overlay
        final isTabletOrDesktop = ResponsiveUtils.isTabletOrDesktop(context);
        return SelectionArea(
          onSelectionChanged: _onSelectionChanged,
          contextMenuBuilder: (context, selectableRegionState) =>
              _buildSelectionContextMenu(context, selectableRegionState),
          child: GestureDetector(
            onTap: _clearAllHighlights,
            behavior: HitTestBehavior.translucent,
            child: Stack(
              children: [
                // Main scrollable content
                SingleChildScrollView(
                  controller: _scrollController,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Commentary link button at the top
                        const ParallelTextButton(),
                        // Content rows - each page with paired entries
                        ..._buildBothModePages(context, pages, entryStart),
                      ],
                    ),
                  ),
                ),
                // Single draggable divider overlay (tablet/desktop only)
                if (isTabletOrDesktop) _buildDividerOverlay(context),
              ],
            ),
          ),
        );
    }
  }

  /// Clears all highlights and bottom sheet when tapping empty space.
  void _clearAllHighlights() {
    // Clear text selection if active
    if (ref.read(hasActiveSelectionProvider)) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
    // Clear dictionary and FTS highlights
    ref.read(dictionaryHighlightProvider.notifier).state = null;
    ref.read(selectedDictionaryWordProvider.notifier).state = null;
    ref.read(ftsHighlightProvider.notifier).state = null;
  }

  /// Handles word tap for dictionary lookup.
  /// If there's an active text selection, clears it instead of opening dictionary.
  void _handleWordTap(String word) {
    // If there's an active text selection, clear it and don't open dictionary
    if (ref.read(hasActiveSelectionProvider)) {
      FocusManager.instance.primaryFocus?.unfocus();
      // Clear the highlight that was set by TextEntryWidget before this callback
      ref.read(dictionaryHighlightProvider.notifier).state = null;
      return;
    }
    // Open dictionary lookup
    ref.read(selectedDictionaryWordProvider.notifier).state =
        removeConjunctFormatting(word);
  }

  /// Builds the page content for "both" column mode (side-by-side Pali/Sinhala)
  /// On the first page, skips entries before [entryStart]
  /// On tablet/desktop: uses resizable split pane with draggable divider
  List<Widget> _buildBothModePages(
    BuildContext context,
    List<dynamic> pages,
    int entryStart,
  ) {
    final widgets = <Widget>[];

    for (var pageIndex = 0; pageIndex < pages.length; pageIndex++) {
      final page = pages[pageIndex];
      // On first page, skip entries before entryStart
      final startEntry = pageIndex == 0 ? entryStart : 0;

      // Page number row - uses split layout
      widgets.add(
        _buildSplitRow(
          context,
          leftChild: _buildPageNumber(context, page.pageNumber),
          rightChild: _buildPageNumber(context, page.pageNumber),
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

        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: _buildSplitRow(
              context,
              // Pali entry (left) - enable dictionary lookup
              leftChild: _buildEntry(
                context,
                paliEntry,
                enableDictionaryLookup: true,
              ),
              // Sinhala entry (right) - disable dictionary lookup
              rightChild: sinhalaEntry != null
                  ? _buildEntry(context, sinhalaEntry,
                      enableDictionaryLookup: false)
                  : const SizedBox.shrink(),
            ),
          ),
        );
      }

      widgets.add(const SizedBox(height: 32)); // Space between pages
    }

    return widgets;
  }

  /// Builds a row with split layout for "both" column mode.
  /// Uses a thin vertical line as separator (actual dragging handled by overlay)
  Widget _buildSplitRow(
    BuildContext context, {
    required Widget leftChild,
    required Widget rightChild,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final splitRatio = ref.watch(activeSplitRatioProvider);
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
  Widget _buildDividerOverlay(BuildContext context) {
    final splitRatio = ref.watch(activeSplitRatioProvider);

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

  Widget _buildPageNumber(BuildContext context, int pageNumber) {
    return SizedBox(
      height: 20, // Fixed height to ensure alignment
      child: Text(
        '$pageNumber',
        style: context.typography.pageNumber,
      ),
    );
  }

  List<Widget> _buildEntries(
    BuildContext context,
    List<Entry> entries, {
    bool enableDictionaryLookup = false,
  }) {
    return entries.map((entry) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: _buildEntry(
          context,
          entry,
          enableDictionaryLookup: enableDictionaryLookup,
        ),
      );
    }).toList();
  }

  Widget _buildEntry(
    BuildContext context,
    Entry entry, {
    bool enableDictionaryLookup = false,
  }) {
    final textEntryTheme = context.textEntryTheme;
    TextStyle? textStyle;

    switch (entry.entryType) {
      case EntryType.heading:
        // Direct 1:1 mapping from JSON level, fallback to level 1
        final level = (entry.level ?? 1).clamp(1, 5);
        textStyle = textEntryTheme.headingStyles[level] ??
            textEntryTheme.headingStyles[1];
        break;
      case EntryType.centered:
        // Direct 1:1 mapping from JSON level, fallback to level 1
        final level = (entry.level ?? 1).clamp(1, 5);
        textStyle = textEntryTheme.centeredStyles[level] ??
            textEntryTheme.centeredStyles[1];
        // Use TextEntryWidget for dictionary lookup on centered text too
        return Center(
          child: TextEntryWidget(
            text: entry.plainText,
            style: textStyle,
            textAlign: TextAlign.center,
            enableTap: enableDictionaryLookup,
            onWordTap: (word, _) => _handleWordTap(word),
          ),
        );
      case EntryType.gatha:
        textStyle = textEntryTheme.gathaStyle;
        // Use level to determine padding (level 2 = deeper indent)
        final gathaLevel = entry.level ?? 1;
        final leftPadding = gathaLevel >= 2
            ? textEntryTheme.gathaLevel2LeftPadding
            : textEntryTheme.gathaLeftPadding;
        return Padding(
          padding: EdgeInsets.only(left: leftPadding),
          child: TextEntryWidget(
            text: entry.plainText,
            style: textStyle,
            textAlign: TextAlign.left,
            enableTap: enableDictionaryLookup,
            onWordTap: (word, _) => _handleWordTap(word),
          ),
        );
      case EntryType.unindented:
        textStyle = textEntryTheme.unindentedStyle;
        break;
      case EntryType.paragraph:
        textStyle = textEntryTheme.paragraphStyle;
        break;
    }

    final textAlign = switch (entry.entryType) {
      EntryType.heading => TextAlign.center,
      EntryType.paragraph || EntryType.unindented => TextAlign.justify,
      _ =>
        TextAlign.left, // gatha (already returned above, but kept for safety)
    };

    return TextEntryWidget(
      text: entry.plainText,
      style: textStyle,
      textAlign: textAlign,
      enableTap: enableDictionaryLookup,
      onWordTap: (word, _) => _handleWordTap(word),
    );
  }
}

/// Floating buttons to unlock scrolling up when content was opened mid-document.
/// Only visible when entryStart > 0 (i.e., opened from FTS results).
///
/// Provides two buttons:
/// - Go to beginning (vertical_align_top icon): Resets entryStart to 0
/// - Scroll up gradually (arrow_upward icon): Decreases entryStart by kScrollUpEntryStep
class _ScrollUpButtons extends StatelessWidget {
  final VoidCallback onScrollToBeginning;
  final VoidCallback onScrollUpGradually;

  const _ScrollUpButtons({
    required this.onScrollToBeginning,
    required this.onScrollUpGradually,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(20),
      color: colorScheme.surfaceContainerHigh,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Go to beginning button
          _buildButton(
            context,
            icon: Icons.vertical_align_top,
            tooltip: AppLocalizations.of(context).scrollToBeginning,
            onTap: onScrollToBeginning,
          ),
          // Divider between buttons
          Container(
            width: 1,
            height: 24,
            color: colorScheme.outlineVariant,
          ),
          // Scroll up gradually button
          _buildButton(
            context,
            icon: Icons.arrow_upward,
            tooltip: AppLocalizations.of(context).scrollUpGradually,
            onTap: onScrollUpGradually,
          ),
        ],
      ),
    );
  }

  Widget _buildButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
