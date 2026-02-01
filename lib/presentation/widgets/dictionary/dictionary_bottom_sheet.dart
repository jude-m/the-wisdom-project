import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/constants.dart';
import '../../../core/localization/l10n/app_localizations.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../domain/entities/dictionary/dictionary_entry.dart';
import '../../../domain/entities/dictionary/dictionary_info.dart';
import '../../providers/dictionary_provider.dart';

/// Non-modal bottom sheet that displays dictionary definitions for a word.
///
/// Shows a scrollable list of definitions from multiple dictionaries,
/// ordered by relevance and dictionary rank.
///
/// This widget should be used inside a Stack, positioned at the bottom.
/// It allows interaction with content behind it (non-blocking).
class DictionaryBottomSheet extends ConsumerWidget {
  /// Callback when the sheet should be closed
  final VoidCallback? onClose;

  const DictionaryBottomSheet({
    super.key,
    this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Defensive null check - widget should only be mounted when word is non-null
    final word = ref.watch(selectedDictionaryWordProvider);
    if (word == null) {
      // This shouldn't happen, but handle gracefully to prevent crashes
      return const SizedBox.shrink();
    }

    final isMobile = ResponsiveUtils.isMobile(context);

    // Use LayoutBuilder to get the actual available height from the parent Stack,
    // not the full screen height. This prevents the sheet from expanding beyond
    // the Stack's bounds and going behind the tab bar.
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Create the sheet with the actual Stack height
          Widget sheet = _DictionarySheet(
            word: word,
            availableHeight: constraints.maxHeight,
            onClose: () {
              ref.read(selectedDictionaryWordProvider.notifier).state = null;
              ref.read(dictionaryHighlightProvider.notifier).state = null;
              onClose?.call();
            },
          );

          // Desktop/Tablet: wrap with centering and max-width constraint
          if (!isMobile) {
            sheet = Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: PaneWidthConstants.dictionarySheetMaxWidth,
                ),
                child: sheet,
              ),
            );
          }

          return sheet;
        },
      ),
    );
  }
}

/// The actual draggable sheet content
class _DictionarySheet extends ConsumerStatefulWidget {
  final String word;
  final VoidCallback onClose;

  /// The available height from the parent Stack (always provided via LayoutBuilder).
  final double availableHeight;

  const _DictionarySheet({
    required this.word,
    required this.onClose,
    required this.availableHeight,
  });

  @override
  ConsumerState<_DictionarySheet> createState() => _DictionarySheetState();
}

class _DictionarySheetState extends ConsumerState<_DictionarySheet> {
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(wordLookupProvider(widget.word));
    final theme = Theme.of(context);

    // Use the actual Stack height from LayoutBuilder (always provided now).
    // This ensures the sheet expands to exactly fill the available space,
    // with the drag handle right below the tab bar when fully expanded.
    final sheetHeight = widget.availableHeight;

    return SizedBox(
      height: sheetHeight,
      child: DraggableScrollableSheet(
        controller: _sheetController,
        initialChildSize: DictionarySheetConstants.initialChildSize,
        minChildSize: DictionarySheetConstants.minChildSize,
        maxChildSize: DictionarySheetConstants.maxChildSize,
        snap: true,
        snapSizes: DictionarySheetConstants.snapSizes,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          // Clip content to rounded corners
          clipBehavior: Clip.antiAlias,
          // Use CustomScrollView so the entire sheet (handle + header + content)
          // responds to drag gestures, not just the results list.
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
              // Drag handle - now draggable!
              SliverToBoxAdapter(
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              // Header with word and close button - now draggable!
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.word,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: widget.onClose,
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                ),
              ),
              // Results content
              ...entriesAsync.when(
                data: (entries) {
                  if (entries.isEmpty) {
                    return [_buildNoResultsSliver(context)];
                  }
                  return _buildResultsSlivers(context, entries);
                },
                loading: () => [
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
                error: (error, stack) => [_buildErrorSliver(context, error)],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoResultsSliver(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off,
                size: 40,
                color:
                    Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 12),
              Text(
                AppLocalizations.of(context).noDefinitionsFound,
                style: context.typography.emptyStateMessage,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorSliver(BuildContext context, Object error) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 40,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text(
                AppLocalizations.of(context).errorLoadingDefinitions,
                style: context.typography.errorMessage,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds slivers for the results list with separators
  List<Widget> _buildResultsSlivers(
    BuildContext context,
    List<DictionaryEntry> entries,
  ) {
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        sliver: SliverList.separated(
          itemCount: entries.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final entry = entries[index];
            return _DictionaryEntryTile(entry: entry);
          },
        ),
      ),
    ];
  }
}

/// Tile widget displaying a single dictionary entry
class _DictionaryEntryTile extends StatelessWidget {
  final DictionaryEntry entry;

  const _DictionaryEntryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final dictInfo = DictionaryInfo.getById(entry.dictionaryId);
    final theme = Theme.of(context);
    final typography = context.typography;
    final dictColor = DictionaryInfo.getColor(entry.dictionaryId, theme);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dictionary badge and word
          Row(
            children: [
              // Dictionary badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: dictColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  dictInfo?.abbreviation ?? entry.dictionaryId,
                  style: typography.badgeLabel.copyWith(color: dictColor),
                ),
              ),
              const SizedBox(width: 8),
              // Word (if different from lookup word)
              Expanded(
                child: Text(
                  entry.word,
                  style: typography.resultTitle.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Meaning (rendered from HTML)
          SelectableText.rich(
            TextSpan(
              children: _parseHtmlToTextSpans(entry.meaning, theme),
            ),
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  /// Parses simple HTML content into TextSpans
  /// Handles: <b>, <i>, <br>, basic tags
  List<InlineSpan> _parseHtmlToTextSpans(String html, ThemeData theme) {
    final spans = <InlineSpan>[];

    // Simplified HTML parsing - handles common tags
    // For more complex HTML, consider using flutter_html package

    // Replace <br> and <br/> with newlines
    var text = html
        .replaceAll(RegExp(r'<br\s*/?>'), '\n')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"');

    // Process text with basic tag handling
    final buffer = StringBuffer();
    var isBold = false;
    var isItalic = false;

    int i = 0;
    while (i < text.length) {
      if (text[i] == '<') {
        // Found a tag - flush buffer first
        if (buffer.isNotEmpty) {
          spans.add(_createTextSpan(buffer.toString(), isBold, isItalic));
          buffer.clear();
        }

        // Find end of tag
        final tagEnd = text.indexOf('>', i);
        if (tagEnd == -1) {
          buffer.write(text[i]);
          i++;
          continue;
        }

        final tag = text.substring(i + 1, tagEnd).toLowerCase().trim();
        i = tagEnd + 1;

        // Handle tags
        if (tag == 'b' || tag == 'strong') {
          isBold = true;
        } else if (tag == '/b' || tag == '/strong') {
          isBold = false;
        } else if (tag == 'i' || tag == 'em') {
          isItalic = true;
        } else if (tag == '/i' || tag == '/em') {
          isItalic = false;
        } else if (tag.startsWith('a ') || tag == '/a') {
          // Skip link tags but keep content
        } else if (tag.startsWith('r ') || tag == 'r') {
          // Custom <r> tags used in Sinhala dictionaries
          // Just render the content without special styling
        } else if (tag == '/r') {
          // End of <r> tag
        }
        // Ignore other tags
      } else {
        buffer.write(text[i]);
        i++;
      }
    }

    // Flush remaining buffer
    if (buffer.isNotEmpty) {
      spans.add(_createTextSpan(buffer.toString(), isBold, isItalic));
    }

    return spans.isEmpty ? [const TextSpan(text: '')] : spans;
  }

  TextSpan _createTextSpan(String text, bool isBold, bool isItalic) {
    return TextSpan(
      text: text,
      style: TextStyle(
        fontWeight: isBold ? FontWeight.bold : null,
        fontStyle: isItalic ? FontStyle.italic : null,
      ),
    );
  }
}
