import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/text_entry_theme.dart';
import '../../core/utils/pali_conjunct_transformer.dart';
import '../models/column_display_mode.dart';
import '../../domain/entities/content/entry.dart';
import '../../domain/entities/content/entry_type.dart';
import '../providers/document_provider.dart';
import '../providers/dictionary_provider.dart' show selectedDictionaryWordProvider;
import '../providers/tab_provider.dart'
    show
        activeTabIndexProvider,
        saveTabScrollPositionProvider,
        getTabScrollPositionProvider,
        activePageStartProvider,
        activePageEndProvider,
        activeEntryStartProvider;
import 'reader/text_entry_widget.dart';
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

  Widget _buildContentLayout(
    BuildContext context,
    List<dynamic> pages,
    ColumnDisplayMode columnMode,
    int entryStart,
  ) {
    switch (columnMode) {
      case ColumnDisplayMode.paliOnly:
        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(24.0),
          itemCount: pages.length,
          itemBuilder: (context, index) {
            final page = pages[index];
            // On first page, skip entries before entryStart
            final entries = index == 0
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
        );

      case ColumnDisplayMode.sinhalaOnly:
        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(24.0),
          itemCount: pages.length,
          itemBuilder: (context, index) {
            final page = pages[index];
            // On first page, skip entries before entryStart
            final entries = index == 0
                ? page.sinhalaSection.entries.skip(entryStart).toList()
                : page.sinhalaSection.entries;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPageNumber(context, page.pageNumber),
                const SizedBox(height: 16),
                // Disable dictionary lookup for Sinhala translation text
                ..._buildEntries(context, entries, enableDictionaryLookup: false),
                const SizedBox(height: 32), // Space between pages
              ],
            );
          },
        );

      case ColumnDisplayMode.both:
        // Row-based layout for proper vertical alignment
        // Each row contains both Pali and Sinhala entries side-by-side
        return SingleChildScrollView(
          controller: _scrollController,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                // Content rows - each page with paired entries
                ..._buildBothModePages(context, pages, entryStart),
              ],
            ),
          ),
        );
    }
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
                        ? _buildEntry(context, sinhalaEntry, enableDictionaryLookup: false)
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
        // Use level 1 heading style (default for entries without level info)
        textStyle = textEntryTheme.headingStyles[1];
        break;
      case EntryType.centered:
        // Use level 0 centered style (normal weight, appropriate for most centered text)
        textStyle = textEntryTheme.centeredStyles[0];
        // Use TextEntryWidget for dictionary lookup on centered text too
        return Center(
          child: TextEntryWidget(
            text: entry.plainText,
            style: textStyle,
            textAlign: TextAlign.center,
            enableTap: enableDictionaryLookup,
            onWordTap: (word, _) => ref.read(selectedDictionaryWordProvider.notifier).state = removeConjunctFormatting(word),
          ),
        );
      case EntryType.gatha:
        textStyle = textEntryTheme.gathaStyle;
        break;
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
      _ => TextAlign.left, // gatha
    };

    return TextEntryWidget(
      text: entry.plainText,
      style: textStyle,
      textAlign: textAlign,
      enableTap: enableDictionaryLookup,
      onWordTap: (word, _) => ref.read(selectedDictionaryWordProvider.notifier).state = removeConjunctFormatting(word),
    );
  }
}
