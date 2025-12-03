import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/column_display_mode.dart';
import '../../domain/entities/content_entry.dart';
import '../../domain/entities/entry_type.dart';
import '../providers/text_content_provider.dart';

class DualPaneReaderWidget extends ConsumerWidget {
  const DualPaneReaderWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              Flexible(
                child: SegmentedButton<ColumnDisplayMode>(
                segments: const [
                  ButtonSegment(
                    value: ColumnDisplayMode.paliOnly,
                    label: Text('Pali', style: TextStyle(fontSize: 12)),
                  ),
                  ButtonSegment(
                    value: ColumnDisplayMode.both,
                    label: Text('Both', style: TextStyle(fontSize: 12)),
                  ),
                  ButtonSegment(
                    value: ColumnDisplayMode.sinhalaOnly,
                    label: Text('සිං', style: TextStyle(fontSize: 12)),
                  ),
                ],
                selected: {columnMode},
                onSelectionChanged: (Set<ColumnDisplayMode> newSelection) {
                  ref.read(columnDisplayModeProvider.notifier).state =
                      newSelection.first;
                },
                ),
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

              final page = content.getPageByIndex(currentPageIndex);
              if (page == null) {
                return const Center(
                  child: Text('Page not found'),
                );
              }

              // Build the layout based on column mode
              return _buildContentLayout(context, ref, page, columnMode);
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
    dynamic page,
    ColumnDisplayMode columnMode,
  ) {
    switch (columnMode) {
      case ColumnDisplayMode.paliOnly:
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPageNumber(context, page.pageNumber),
              const SizedBox(height: 16),
              ..._buildEntries(context, page.paliContentSection.contentEntries),
            ],
          ),
        );

      case ColumnDisplayMode.sinhalaOnly:
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPageNumber(context, page.pageNumber),
              const SizedBox(height: 16),
              ..._buildEntries(context, page.sinhalaContentSection.contentEntries),
            ],
          ),
        );

      case ColumnDisplayMode.both:
        return Row(
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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLanguageLabel(context, 'Pali'),
                      _buildPageNumber(context, page.pageNumber),
                      const SizedBox(height: 16),
                      ..._buildEntries(context, page.paliContentSection.contentEntries),
                    ],
                  ),
                ),
              ),
            ),

            // Sinhala pane (right)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLanguageLabel(context, 'සිංහල'),
                    _buildPageNumber(context, page.pageNumber),
                    const SizedBox(height: 16),
                    ..._buildEntries(context, page.sinhalaContentSection.contentEntries),
                  ],
                ),
              ),
            ),
          ],
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
