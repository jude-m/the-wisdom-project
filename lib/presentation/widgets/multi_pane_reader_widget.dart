import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SelectedContent;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
        highlightStateProvider,
        hasActiveSelectionProvider;
import '../providers/tab_provider.dart'
    show
        activeTabIndexProvider,
        saveTabScrollPositionProvider,
        getTabScrollPositionProvider,
        activePageStartProvider,
        activePageEndProvider,
        activeEntryStartProvider;
import 'reader/text_entry_widget.dart';
import 'reader/parallel_text_button.dart';
import 'dictionary/dictionary_bottom_sheet.dart';

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

        // Apply orientation-based default display mode for the new tab
        if (next >= 0) {
          final shouldUseSingleColumn =
              ResponsiveUtils.shouldDefaultToSingleColumn(context);
          ref.read(columnDisplayModeProvider.notifier).state =
              shouldUseSingleColumn
                  ? ColumnDisplayMode.paliOnly
                  : ColumnDisplayMode.both;
        }

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
    final columnMode = ref.watch(columnDisplayModeProvider);
    // Watch selected word to conditionally mount the dictionary sheet
    final selectedWord = ref.watch(selectedDictionaryWordProvider);

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

                  // Get pagination state from derived providers (read from active tab)
                  final pageStart = ref.watch(activePageStartProvider);
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

                  // Get entry start (which entry to start from on the first page)
                  final entryStart = ref.watch(activeEntryStartProvider);

                  // Build the layout based on column mode
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
      ref.read(highlightStateProvider.notifier).state = null;
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
        return GestureDetector(
          // Clear dictionary highlight when tapping empty space
          onTap: _clearDictionarySelection,
          behavior: HitTestBehavior.translucent,
          child: SelectionArea(
            onSelectionChanged: _onSelectionChanged,
            contextMenuBuilder: (context, selectableRegionState) =>
                _buildSelectionContextMenu(context, selectableRegionState),
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
        return GestureDetector(
          onTap: _clearDictionarySelection,
          behavior: HitTestBehavior.translucent,
          child: SelectionArea(
            onSelectionChanged: _onSelectionChanged,
            contextMenuBuilder: (context, selectableRegionState) =>
                _buildSelectionContextMenu(context, selectableRegionState),
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
        return GestureDetector(
          onTap: _clearDictionarySelection,
          behavior: HitTestBehavior.translucent,
          child: SelectionArea(
            onSelectionChanged: _onSelectionChanged,
            contextMenuBuilder: (context, selectableRegionState) =>
                _buildSelectionContextMenu(context, selectableRegionState),
            child: SingleChildScrollView(
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
          ),
        );
    }
  }

  /// Clears dictionary highlight and bottom sheet when tapping empty space.
  void _clearDictionarySelection() {
    ref.read(highlightStateProvider.notifier).state = null;
    ref.read(selectedDictionaryWordProvider.notifier).state = null;
  }

  /// Handles word tap for dictionary lookup.
  /// If there's an active text selection, clears it instead of opening dictionary.
  void _handleWordTap(String word) {
    // If there's an active text selection, clear it and don't open dictionary
    if (ref.read(hasActiveSelectionProvider)) {
      FocusManager.instance.primaryFocus?.unfocus();
      // Clear the highlight that was set by TextEntryWidget before this callback
      ref.read(highlightStateProvider.notifier).state = null;
      return;
    }
    // Open dictionary lookup
    ref.read(selectedDictionaryWordProvider.notifier).state =
        removeConjunctFormatting(word);
  }

  /// Builds the page content for "both" column mode (side-by-side Pali/Sinhala)
  /// On the first page, skips entries before [entryStart]
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

      // Page number row
      widgets.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: _buildPageNumber(context, page.pageNumber),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 12.0),
                child: _buildPageNumber(context, page.pageNumber),
              ),
            ),
          ],
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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pali entry (left) - enable dictionary lookup
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: _buildEntry(
                      context,
                      paliEntry,
                      enableDictionaryLookup: true,
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                // Sinhala entry (right) - disable dictionary lookup
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12.0),
                    child: sinhalaEntry != null
                        ? _buildEntry(context, sinhalaEntry,
                            enableDictionaryLookup: false)
                        : const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      widgets.add(const SizedBox(height: 32)); // Space between pages
    }

    return widgets;
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
