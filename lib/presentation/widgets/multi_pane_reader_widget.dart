import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/l10n/app_localizations.dart';
import '../../core/theme/app_typography.dart';
import '../models/reader_layout.dart';
import '../models/in_page_search_state.dart';
import '../../domain/entities/bjt/bjt_page.dart';
import '../../domain/entities/navigation/tipitaka_tree_node.dart';
import '../providers/document_provider.dart';
import '../providers/dictionary_provider.dart'
    show
        selectedDictionaryWordProvider,
        dictionaryHighlightProvider,
        hasActiveSelectionProvider;
import '../providers/in_page_search_provider.dart';
import '../providers/tab_provider.dart'
    show
        activeTabIndexProvider,
        saveTabScrollPositionProvider,
        getTabScrollPositionProvider,
        activePageStartProvider,
        activePageEndProvider,
        activeEntryStartProvider,
        activeReaderLayoutProvider,
        activeNodeKeyProvider,
        updateActiveTabPaginationProvider;
import '../providers/previous_sutta_provider.dart'
    show navigateToPreviousSuttaProvider;
import '../providers/navigation_tree_provider.dart'
    show nodeByKeyProvider, previousReadableNodeProvider;
import '../providers/fts_highlight_provider.dart';
import 'reader/entry_key_registry.dart';
import 'reader/single_column_pane.dart';
import 'reader/dual_column_pane.dart';
import 'reader/stacked_pane.dart';
import 'reader/reader_selection_handler.dart';
import 'reader/in_page_search_bar.dart';
import 'reader/reader_action_buttons.dart';
import 'dictionary/dictionary_bottom_sheet.dart';


class MultiPaneReaderWidget extends ConsumerStatefulWidget {
  const MultiPaneReaderWidget({super.key});

  @override
  ConsumerState<MultiPaneReaderWidget> createState() =>
      _MultiPaneReaderWidgetState();
}

class _MultiPaneReaderWidgetState extends ConsumerState<MultiPaneReaderWidget>
    with ReaderSelectionHandler<MultiPaneReaderWidget> {
  // Single scroll controller for all modes
  final ScrollController _scrollController = ScrollController();

  // GlobalKey attached to the current match entry for scroll-to-match
  final GlobalKey _currentMatchKey = GlobalKey();

  // Registry for entry-level GlobalKeys used to sync scroll position
  // across layout switches. Shared with all pane widgets.
  final EntryKeyRegistry _entryKeyRegistry = EntryKeyRegistry();

  // Tracks whether the user has scrolled away from the top.
  // Updated in _onScroll; only calls setState when the value actually changes.
  bool _isScrolledDown = false;

  @override
  void initState() {
    super.initState();
    // Add scroll listener for automatic page loading
    _scrollController.addListener(_onScroll);
  }

  /// Scroll listener for infinite scroll and scroll-position tracking.
  void _onScroll() {
    if (_scrollController.hasClients) {
      final currentScroll = _scrollController.position.pixels;

      // Track whether the user has scrolled at least one viewport height down.
      // This prevents the "Go to beginning" button from appearing too eagerly
      // after just a couple of scroll ticks.
      final viewportHeight = _scrollController.position.viewportDimension;
      final scrolledDown = currentScroll > viewportHeight;
      if (scrolledDown != _isScrolledDown) {
        setState(() => _isScrolledDown = scrolledDown);
      }

      // Infinite scroll: load next page when user scrolls near bottom (within 200px)
      final delta = _scrollController.position.maxScrollExtent - currentScroll;
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
    _entryKeyRegistry.clear();
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

    // Reset scroll-tracking state so the button transitions correctly
    // (from scroll-to-top to skip-previous once we're at the beginning).
    setState(() => _isScrolledDown = false);

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


  /// Navigates to the previous sutta in tree order.
  /// Delegates business logic to [navigateToPreviousSuttaProvider] and
  /// handles widget-specific concerns (scroll position, page loading).
  void _navigateToPreviousSutta(TipitakaTreeNode previousNode) {
    // Delegate business logic to provider
    ref.read(navigateToPreviousSuttaProvider)(previousNode);

    // Jump to top — handles same-contentFileId case where doc won't reload
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }

    // Ensure enough pages are loaded to fill the screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMorePagesIfNeeded(scheduleNextCheck: true);
    });
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

  /// Scrolls to the current in-page search match.
  ///
  /// If the match is on a page outside the loaded range, expands pagination first.
  /// Then uses Scrollable.ensureVisible on the GlobalKey attached to the match entry.
  void _scrollToCurrentMatch(InPageSearchState searchState) {
    final currentMatch = searchState.currentMatch;
    if (currentMatch == null) return;

    final pageStart = ref.read(activePageStartProvider);
    final pageEnd = ref.read(activePageEndProvider);

    // Check if the match page is within the loaded range
    if (currentMatch.pageIndex < pageStart ||
        currentMatch.pageIndex >= pageEnd) {
      // Expand pagination to include the match page
      final newPageStart =
          currentMatch.pageIndex < pageStart ? currentMatch.pageIndex : pageStart;
      final newPageEnd =
          currentMatch.pageIndex >= pageEnd ? currentMatch.pageIndex + 1 : pageEnd;
      ref.read(updateActiveTabPaginationProvider)(
        pageStart: newPageStart,
        pageEnd: newPageEnd,
        entryStart: 0,
      );
    }

    // Scroll to the match after the frame rebuilds with the new content
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final keyContext = _currentMatchKey.currentContext;
      if (keyContext != null) {
        Scrollable.ensureVisible(
          keyContext,
          alignment: 0.3, // Position match 30% from the top
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
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

        // Clear entry key registry — old tab's keys are stale
        _entryKeyRegistry.clear();

        // Reset scroll to 0 (always reset when tab changes)
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }

        // Layout is now per-tab and derived from activeReaderLayoutProvider
        // No need to override or reset - each tab remembers its own column mode

        // Then restore the actual saved position for the new tab after content renders
        // (only if transitioning to a valid tab, not to -1)
        if (next >= 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _restoreScrollPosition();
            // Only load more pages if content doesn't fill the viewport yet.
            // Returning to a tab that already has enough content should NOT grow
            // pageEnd — that causes search results to inflate on every tab switch.
            if (_scrollController.hasClients &&
                _scrollController.position.maxScrollExtent <= 0) {
              _loadMorePagesIfNeeded(scheduleNextCheck: true);
            }
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

    // Listen to layout changes — sync scroll position by logical entry, not pixels.
    // Pixel offsets are meaningless across layouts (stacked is ~2x taller than
    // side-by-side per entry). Instead, capture which entry is at the viewport
    // top, then reset pagination so the new layout starts from that entry.
    //
    // This avoids Scrollable.ensureVisible which clamps to maxScrollExtent —
    // a value ListView.builder underestimates on fresh layouts. By changing
    // WHAT content is displayed (pagination reset) rather than WHERE to scroll,
    // we sidestep all scroll-extent estimation issues.
    ref.listen<ReaderLayout>(activeReaderLayoutProvider, (previous, next) {
      if (previous != null && previous != next) {
        // Capture top-visible entry from the OLD layout (still mounted)
        final topEntry =
            _entryKeyRegistry.findTopVisibleEntry(_scrollController);
        // Clear stale keys from old layout before rebuild
        _entryKeyRegistry.clear();
        if (topEntry != null) {
          // Reset pagination to start from the target entry.
          // The rebuild in this same frame renders the new layout starting
          // at this entry — no scrolling needed.
          ref.read(updateActiveTabPaginationProvider)(
            pageStart: topEntry.$1,
            pageEnd: topEntry.$1 + 1,
            entryStart: topEntry.$2,
          );
        }

        // After rebuild, ensure scroll is at 0 and fill screen with pages
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(0);
          }
          _loadMorePagesIfNeeded(scheduleNextCheck: true);
        });
      }
    });

    // Listen to in-page search state changes to trigger scroll-to-match
    ref.listen<InPageSearchState>(activeInPageSearchStateProvider,
        (previous, next) {
      if (next.currentMatchIndex >= 0 &&
          next.currentMatchIndex != (previous?.currentMatchIndex ?? -1)) {
        _scrollToCurrentMatch(next);
      }
    });

    final contentAsync = ref.watch(currentBJTDocumentProvider);
    // Watch per-tab reader layout (each tab remembers its own setting)
    final readerLayout = ref.watch(activeReaderLayoutProvider);
    // Watch selected word to conditionally mount the dictionary sheet
    final selectedWord = ref.watch(selectedDictionaryWordProvider);
    // Watch pagination state to determine if scroll up buttons should show
    final pageStart = ref.watch(activePageStartProvider);
    final entryStart = ref.watch(activeEntryStartProvider);

    // Watch in-page search state for the active tab
    final searchState = ref.watch(activeInPageSearchStateProvider);

    // Determine if we're past the sutta's beginning (to show scroll up buttons)
    final nodeKey = ref.watch(activeNodeKeyProvider);
    final node = nodeKey != null ? ref.watch(nodeByKeyProvider(nodeKey)) : null;
    final isAfterSuttaBeginning = node != null &&
        (pageStart > node.entryPageIndex ||
            (pageStart == node.entryPageIndex &&
                entryStart > node.entryIndexInPage));

    // Watch the previous readable node in tree order for backward navigation
    final previousNode = nodeKey != null
        ? ref.watch(previousReadableNodeProvider(nodeKey))
        : null;

    // Visibility flags for the two action button modes.
    // Computed once here so IgnorePointer, AnimatedOpacity, and AnimatedSlide
    // all reference the same boolean — avoids duplication and drift.
    final hasContent = contentAsync.valueOrNull != null;
    final showMode1 = hasContent &&
        !searchState.isVisible &&
        !_isScrolledDown &&
        !isAfterSuttaBeginning;
    final showMode2 = hasContent &&
        !searchState.isVisible &&
        (_isScrolledDown || isAfterSuttaBeginning);

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

                  // Build the layout based on reader layout mode
                  // (entryStart already watched above for isAfterSuttaBeginning check)
                  return _buildContentLayout(
                    context,
                    pagesToShow,
                    readerLayout,
                    entryStart,
                    searchState,
                    pageStart,
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
        // In-page search bar (floating at top)
        // ValueKey ensures a fresh widget instance per tab (resets controller text)
        if (searchState.isVisible)
          Positioned(
            top: 8,
            left: 16,
            right: 16,
            child: InPageSearchBar(
              key: ValueKey('search_bar_${ref.watch(activeTabIndexProvider)}'),
            ),
          ),
        // When search bar is active, all action buttons are hidden.
        // The search bar is self-contained (close, up/down navigation).
        //
        // Mode 1 & 2 both stay in the tree so AnimatedOpacity can crossfade.
        // IgnorePointer disables taps on the invisible widget.
        if (hasContent) ...[
          // Mode 1: Button group at top-right (at sutta beginning, not scrolled)
          Positioned(
            top: 12,
            right: 16,
            child: IgnorePointer(
              ignoring: !showMode1,
              child: AnimatedOpacity(
                opacity: showMode1 ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOutCubic,
                child: ReaderActionButtonGroup(
                  onSearchTap: () => ref
                      .read(inPageSearchStatesProvider.notifier)
                      .openSearch(),
                  onScrollTap: previousNode != null
                      ? () => _navigateToPreviousSutta(previousNode)
                      : null,
                  scrollIcon:
                      previousNode != null ? Icons.skip_previous : null,
                  scrollTooltip: previousNode != null
                      ? AppLocalizations.of(context)
                          .goToPreviousSutta(previousNode.paliName)
                      : null,
                ),
              ),
            ),
          ),
          // Mode 2: Expandable FAB at bottom-right (scrolled down or FTS mid-sutta)
          Positioned(
            bottom: 24,
            right: 16,
            child: IgnorePointer(
              ignoring: !showMode2,
              child: AnimatedOpacity(
                opacity: showMode2 ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                child: AnimatedSlide(
                  offset: showMode2
                      ? Offset.zero
                      : const Offset(0, 0.3),
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  child: ReaderExpandableFab(
                    visible: showMode2,
                    onSearchTap: () => ref
                        .read(inPageSearchStatesProvider.notifier)
                        .openSearch(),
                    onScrollTap: _scrollToBeginning,
                    scrollTooltip:
                        AppLocalizations.of(context).scrollToBeginning,
                  ),
                ),
              ),
            ),
          ),
        ],
        // Non-modal dictionary bottom sheet overlay
        // Only mounted when a word is selected (conditional mounting for performance)
        if (selectedWord != null) const DictionaryBottomSheet(),
      ],
    );
  }

  /// Clears all highlights and bottom sheet when tapping empty space.
  void _clearAllHighlights() {
    // Clear text selection if active
    if (ref.read(hasActiveSelectionProvider)) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
    // Clear dictionary and FTS highlights (per-tab for FTS)
    ref.read(dictionaryHighlightProvider.notifier).state = null;
    ref.read(selectedDictionaryWordProvider.notifier).state = null;
    ref.read(ftsHighlightProvider.notifier).clearForActiveTab();
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
    // Open dictionary lookup — pass word with conjuncts intact so the
    // dictionary bottom sheet displays proper bound letters in the text field.
    // The lookup itself strips ZWJ via computeEffectiveQuery/normalizeText.
    ref.read(selectedDictionaryWordProvider.notifier).state = word;
  }

  /// Delegates to the appropriate pane widget based on reader layout.
  Widget _buildContentLayout(
    BuildContext context,
    List<BJTPage> pages,
    ReaderLayout readerLayout,
    int entryStart,
    InPageSearchState searchState,
    int absolutePageStart,
  ) {
    switch (readerLayout) {
      case ReaderLayout.paliOnly:
        return SingleColumnPane(
          scrollController: _scrollController,
          pages: pages,
          entryStart: entryStart,
          absolutePageStart: absolutePageStart,
          searchState: searchState,
          languageCode: 'pi',
          enableDictionaryLookup: true,
          currentMatchKey: _currentMatchKey,
          entryKeyRegistry: _entryKeyRegistry,
          onTapEmpty: _clearAllHighlights,
          onWordTap: _handleWordTap,
          onSelectionChanged: onSelectionChanged,
          contextMenuBuilder: buildSelectionContextMenu,
        );
      case ReaderLayout.sinhalaOnly:
        return SingleColumnPane(
          scrollController: _scrollController,
          pages: pages,
          entryStart: entryStart,
          absolutePageStart: absolutePageStart,
          searchState: searchState,
          languageCode: 'si',
          enableDictionaryLookup: false,
          currentMatchKey: _currentMatchKey,
          entryKeyRegistry: _entryKeyRegistry,
          onTapEmpty: _clearAllHighlights,
          onWordTap: _handleWordTap,
          onSelectionChanged: onSelectionChanged,
          contextMenuBuilder: buildSelectionContextMenu,
        );
      case ReaderLayout.sideBySide:
        return DualColumnPane(
          scrollController: _scrollController,
          pages: pages,
          entryStart: entryStart,
          absolutePageStart: absolutePageStart,
          searchState: searchState,
          currentMatchKey: _currentMatchKey,
          entryKeyRegistry: _entryKeyRegistry,
          onTapEmpty: _clearAllHighlights,
          onWordTap: _handleWordTap,
          onSelectionChanged: onSelectionChanged,
          contextMenuBuilder: buildSelectionContextMenu,
        );
      case ReaderLayout.stacked:
        return StackedPane(
          scrollController: _scrollController,
          pages: pages,
          entryStart: entryStart,
          absolutePageStart: absolutePageStart,
          searchState: searchState,
          currentMatchKey: _currentMatchKey,
          entryKeyRegistry: _entryKeyRegistry,
          onTapEmpty: _clearAllHighlights,
          onWordTap: _handleWordTap,
          onSelectionChanged: onSelectionChanged,
          contextMenuBuilder: buildSelectionContextMenu,
        );
    }
  }
}
