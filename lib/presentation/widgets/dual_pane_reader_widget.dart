import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/column_display_mode.dart';
import '../../domain/entities/content_entry.dart';
import '../../domain/entities/entry_type.dart';
import '../providers/text_content_provider.dart';
import '../providers/tab_provider.dart';

class DualPaneReaderWidget extends ConsumerStatefulWidget {
  const DualPaneReaderWidget({super.key});

  @override
  ConsumerState<DualPaneReaderWidget> createState() => _DualPaneReaderWidgetState();
}

class _DualPaneReaderWidgetState extends ConsumerState<DualPaneReaderWidget> {
  // Single scroll controller for all modes (both panes use the same controller in dual mode)
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
        final contentAsync = ref.read(currentTextContentProvider);
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
    _saveScrollPosition();
    _scrollController.dispose();
    super.dispose();
  }

  void _saveScrollPosition([int? index]) {
    final int activeTabIndex = index ?? ref.read(activeTabIndexProvider);
    if (activeTabIndex >= 0 && _scrollController.hasClients) {
      ref.read(saveTabScrollPositionProvider)(activeTabIndex, _scrollController.offset);

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
            final scrollOffset = ref.read(getTabScrollPositionProvider)(activeTabIndex);
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
      if (previous != null && previous >= 0 && previous != next) {
        // Save scroll position for the previous tab
        _saveScrollPosition(previous);

        // Reset scroll to 0
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }

        // Then restore the actual saved position for the new tab after content renders
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _restoreScrollPosition();
        });
      }
    });

    // Listen to content loading state and restore scroll position after content is loaded
    ref.listen(currentTextContentProvider, (previous, next) {
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

    final contentAsync = ref.watch(currentTextContentProvider);
    final columnMode = ref.watch(columnDisplayModeProvider);
    final currentPageIndex = ref.watch(currentPageIndexProvider);

    return Column(
      children: [
        // Header with controls
        Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Reader',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // Column mode selector
              SegmentedButton<ColumnDisplayMode>(
                segments: const [
                  ButtonSegment(
                    value: ColumnDisplayMode.paliOnly,
                    label: Text('P', style: TextStyle(fontSize: 11)),
                  ),
                  ButtonSegment(
                    value: ColumnDisplayMode.both,
                    label: Text('P+S', style: TextStyle(fontSize: 11)),
                  ),
                  ButtonSegment(
                    value: ColumnDisplayMode.sinhalaOnly,
                    label: Text('S', style: TextStyle(fontSize: 11)),
                  ),
                ],
                selected: {columnMode},
                onSelectionChanged: (Set<ColumnDisplayMode> newSelection) {
                  ref.read(columnDisplayModeProvider.notifier).state =
                      newSelection.first;
                },
              ),
              const SizedBox(width: 8),

              // Page navigation
              Flexible(
                child: contentAsync.maybeWhen(
                  data: (content) {
                    if (content != null && content.pageCount > 1) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: currentPageIndex > 0
                                ? () => ref.read(previousPageProvider)()
                                : null,
                          ),
                          Text(
                            'Page ${currentPageIndex + 1} / ${content.pageCount}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: currentPageIndex < content.pageCount - 1
                                ? () => ref.read(nextPageProvider)()
                                : null,
                          ),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  },
                  orElse: () => const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),

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
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
              final pagesToShow = content.contentPages
                  .sublist(
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
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
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
                ..._buildEntries(context, page.paliContentSection.contentEntries),
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
                ..._buildEntries(context, page.sinhalaContentSection.contentEntries),
                const SizedBox(height: 32), // Space between pages
              ],
            );
          },
        );

      case ColumnDisplayMode.both:
        // Single scroll view wraps both panes so they scroll together
        return SingleChildScrollView(
          controller: _scrollController,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pali pane (left)
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(
                        color: Theme.of(context).dividerColor,
                        width: 1,
                      ),
                    ),
                  ),
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildLanguageLabel(context, 'Pali'),
                      // Show all pages
                      for (final page in pages) ...[
                        _buildPageNumber(context, page.pageNumber),
                        const SizedBox(height: 16),
                        ..._buildEntries(context, page.paliContentSection.contentEntries),
                        const SizedBox(height: 32), // Space between pages
                      ],
                    ],
                  ),
                ),
              ),

              // Sinhala pane (right)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildLanguageLabel(context, 'සිංහල'),
                      // Show all pages
                      for (final page in pages) ...[
                        _buildPageNumber(context, page.pageNumber),
                        const SizedBox(height: 16),
                        ..._buildEntries(context, page.sinhalaContentSection.contentEntries),
                        const SizedBox(height: 32), // Space between pages
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildLanguageLabel(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }

  Widget _buildPageNumber(BuildContext context, int pageNumber) {
    return Text(
      'BJT Page $pageNumber',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        fontWeight: FontWeight.w500,
      ),
    );
  }

  List<Widget> _buildEntries(BuildContext context, List<ContentEntry> entries) {
    return entries.map((entry) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: _buildEntry(context, entry),
      );
    }).toList();
  }

  Widget _buildEntry(BuildContext context, ContentEntry entry) {
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
      _parseFormattedText(entry.rawTextContent),
      style: textStyle,
      textAlign: entry.entryType == EntryType.centered
          ? TextAlign.center
          : TextAlign.left,
    );
  }

  // Simple text parsing (removes formatting markers for now)
  String _parseFormattedText(String text) {
    return text
        .replaceAll('**', '')
        .replaceAll('__', '')
        .replaceAll(RegExp(r'\{[^}]*\}'), '');
  }
}
