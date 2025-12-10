import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/column_display_mode.dart';
import '../../domain/entities/entry.dart';
import '../../domain/entities/entry_type.dart';
import '../../core/theme/theme_notifier.dart';
import '../providers/document_provider.dart';
import '../providers/tab_provider.dart';

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

  void _onScroll() {
    // Check if we're near the bottom (within 200 pixels)
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;
      final delta = maxScroll - currentScroll;

      // Load more pages when user scrolls near the bottom
      if (delta < 200) {
        final contentAsync = ref.read(currentBJTDocumentProvider);
        contentAsync.whenData((content) {
          if (content != null) {
            final currentEnd = ref.read(pageEndProvider);
            if (currentEnd < content.pageCount) {
              // Load one more page
              ref.read(loadMorePagesProvider)(1);
            }
          }
        });
      }
    }
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

      // Also save pagination state to the tab
      final pageStart = ref.read(pageStartProvider);
      final pageEnd = ref.read(pageEndProvider);

      // Update the tab's pagination state
      final tabs = ref.read(tabsProvider);
      if (activeTabIndex < tabs.length) {
        final updatedTab = tabs[activeTabIndex].copyWith(
          pageStart: pageStart,
          pageEnd: pageEnd,
        );
        ref.read(tabsProvider.notifier).updateTab(activeTabIndex, updatedTab);
      }
    }
  }

  void _restoreScrollPosition() {
    final activeTabIndex = ref.read(activeTabIndexProvider);
    if (activeTabIndex >= 0) {
      // First restore pagination state from the tab
      final tabs = ref.read(tabsProvider);
      if (activeTabIndex < tabs.length) {
        final tab = tabs[activeTabIndex];
        ref.read(pageStartProvider.notifier).state = tab.pageStart;
        ref.read(pageEndProvider.notifier).state = tab.pageEnd;
      }

      // Then restore scroll position after a frame (to let pagination update)
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
          });
        }
      }
    });

    // Listen to content loading state and restore scroll position after content is loaded
    ref.listen(currentBJTDocumentProvider, (previous, next) {
      // When content finishes loading (transitions to AsyncData with actual content)
      next.whenData((content) {
        if (content != null && previous?.value == null) {
          // Content just loaded, restore scroll position after widget tree is built
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _restoreScrollPosition();
          });
        }
      });
    });

    final contentAsync = ref.watch(currentBJTDocumentProvider);
    final columnMode = ref.watch(columnDisplayModeProvider);
    final currentPageIndex = ref.watch(currentPageIndexProvider);

    return Column(
      children: [
        // Content area
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
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.6),
                                ),
                      ),
                    ],
                  ),
                );
              }

              // Get pagination state
              final pageStart = ref.watch(pageStartProvider);
              final pageEnd = ref.watch(pageEndProvider);

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
              return _buildContentLayout(
                context,
                ref,
                pagesToShow,
                columnMode,
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
    );
  }

  Widget _buildContentLayout(
    BuildContext context,
    WidgetRef ref,
    List<dynamic> pages,
    ColumnDisplayMode columnMode,
  ) {
    switch (columnMode) {
      case ColumnDisplayMode.paliOnly:
        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(24.0),
          itemCount: pages.length,
          itemBuilder: (context, index) {
            final page = pages[index];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPageNumber(context, page.pageNumber),
                const SizedBox(height: 16),
                ..._buildEntries(context, page.paliSection.entries),
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
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPageNumber(context, page.pageNumber),
                const SizedBox(height: 16),
                ..._buildEntries(context, page.sinhalaSection.entries),
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
                // Language labels header row
                // Row(
                //   crossAxisAlignment: CrossAxisAlignment.start,
                //   children: [
                //     Expanded(
                //       child: Padding(
                //         padding: const EdgeInsets.only(right: 12.0),
                //         child: _buildLanguageLabel(context, 'Pali'),
                //       ),
                //     ),
                //     const SizedBox(width: 24),
                //     Expanded(
                //       child: Padding(
                //         padding: const EdgeInsets.only(left: 12.0),
                //         child: _buildLanguageLabel(context, 'සිංහල'),
                //       ),
                //     ),
                //   ],
                // ),
                const SizedBox(height: 16),

                // Content rows - each page with paired entries
                for (final page in pages) ...[
                  // Page number row
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
                  const SizedBox(height: 16),

                  // Paired entry rows
                  ...List.generate(
                    page.paliSection.entries.length,
                    (entryIndex) {
                      final paliEntry = page.paliSection.entries[entryIndex];
                      final sinhalaEntry =
                          entryIndex < page.sinhalaSection.entries.length
                              ? page.sinhalaSection.entries[entryIndex]
                              : null;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment
                              .start, // Top-align for proper vertical sync
                          children: [
                            // Pali entry (left)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 12.0),
                                child: _buildEntry(context, paliEntry),
                              ),
                            ),
                            const SizedBox(width: 24),
                            // Sinhala entry (right)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 12.0),
                                child: sinhalaEntry != null
                                    ? _buildEntry(context, sinhalaEntry)
                                    : _buildEmptyCell(context),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 32), // Space between pages
                ],
              ],
            ),
          ),
        );
    }
  }

  Widget _buildPageNumber(BuildContext context, int pageNumber) {
    return SizedBox(
      height: 20, // Fixed height to ensure alignment
      child: Text(
        '$pageNumber',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              fontWeight: FontWeight.w500,
              height: 1.0, // Set line height to prevent extra spacing
            ),
      ),
    );
  }

  List<Widget> _buildEntries(BuildContext context, List<Entry> entries) {
    return entries.map((entry) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: _buildEntry(context, entry),
      );
    }).toList();
  }

  Widget _buildEmptyCell(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        '—',
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            ),
      ),
    );
  }

  Widget _buildEntry(BuildContext context, Entry entry) {
    TextStyle? textStyle;

    switch (entry.entryType) {
      case EntryType.heading:
        textStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            );
        break;
      case EntryType.centered:
        textStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            );
        return Center(
          child: Text(
            entry.plainText,
            style: textStyle,
            textAlign: TextAlign.center,
          ),
        );
      case EntryType.gatha:
        textStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontStyle: FontStyle.italic,
              height: 1.6,
            );
        break;
      case EntryType.unindented:
      case EntryType.paragraph:
        textStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
              height: 1.8,
            );
        break;
    }

    return Text(
      entry.plainText,
      style: textStyle,
      textAlign: entry.entryType == EntryType.centered
          ? TextAlign.center
          : TextAlign.left,
    );
  }
}
