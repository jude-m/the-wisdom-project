import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/constants.dart';
import '../../../core/localization/l10n/app_localizations.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/utils/pali_conjunct_transformer.dart';
import '../../../domain/entities/dictionary/dictionary_entry.dart';
import '../../../domain/entities/dictionary/dictionary_filter_operations.dart';
import '../../../domain/entities/dictionary/dictionary_info.dart';
import '../../../domain/entities/dictionary/dictionary_params.dart';
import '../../../core/utils/search_query_utils.dart';
import '../../providers/dictionary_provider.dart';
import '../common/circular_toggle_button.dart';
import 'dpd_read_more_link.dart';
import 'refine_dictionary_dialog.dart';

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
  late final TextEditingController _wordController;
  late final FocusNode _wordFocusNode;
  Timer? _debounceTimer;

  /// The word currently used for dictionary lookup.
  /// Updated after 300ms debounce when user edits the text field.
  late String _currentLookupWord;

  /// Threshold above which the sheet is considered "expanded" for the
  /// chevron toggle icon. Chosen between the min snap (0.28) and mid snap
  /// (0.55) so the icon flips as soon as the sheet grows past collapsed.
  static const double _expandedThreshold = 0.4;

  /// Cached expansion state — used to avoid redundant setState calls on
  /// every pixel of drag. We only rebuild when the size crosses the
  /// threshold.
  bool _wasExpanded = false;

  @override
  void initState() {
    super.initState();
    // Display word with conjuncts (ZWJ) in text field, but strip for lookup
    _currentLookupWord = removeConjunctFormatting(widget.word);
    _wordController = TextEditingController(text: widget.word);
    _wordFocusNode = FocusNode();
    // Listen so the chevron icon flips when the user drags the sheet.
    _sheetController.addListener(_onSheetSizeChanged);
  }

  @override
  void didUpdateWidget(covariant _DictionarySheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When a new word is tapped, reset the text field and lookup word
    if (oldWidget.word != widget.word) {
      _debounceTimer?.cancel();
      _wordController.text = widget.word;
      _currentLookupWord = removeConjunctFormatting(widget.word);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _wordFocusNode.dispose();
    _wordController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  /// Called whenever the DraggableScrollableController's size changes
  /// (from dragging or animateTo). Rebuilds only when the expansion state
  /// flips, keeping setState cost minimal.
  void _onSheetSizeChanged() {
    if (!_sheetController.isAttached) return;
    final nowExpanded = _sheetController.size > _expandedThreshold;
    if (nowExpanded != _wasExpanded) {
      _wasExpanded = nowExpanded;
      if (mounted) setState(() {});
    }
  }

  /// True when the sheet is currently expanded past the collapsed snap.
  /// Sourced from the cached flag the listener maintains — inside `build`
  /// this is always in sync with the live size, and defaults to `false`
  /// before the controller attaches.
  bool get _isExpanded => _wasExpanded;

  /// Chevron button handler — toggles between the collapsed min snap and
  /// the fully expanded max snap. Skips the mid snap by design.
  void _toggleExpansion() {
    if (!_sheetController.isAttached) return;
    final target = _isExpanded
        ? DictionarySheetConstants.minChildSize
        : DictionarySheetConstants.maxChildSize;
    _sheetController.animateTo(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  void _openRefineDialog(BuildContext context) {
    final currentIds = ref.read(bottomSheetDictionaryFilterProvider);
    RefineDictionaryDialog.show(
      context,
      selectedIds: currentIds,
      onFilterChanged: (ids) {
        ref.read(bottomSheetDictionaryFilterProvider.notifier).state = ids;
      },
    );
  }

  void _onWordChanged(String value) {
    _debounceTimer?.cancel();
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      final effective = computeEffectiveQuery(trimmed);
      if (effective.isEmpty) return;
      setState(() => _currentLookupWord = effective);
    });
  }

  @override
  Widget build(BuildContext context) {
    final filterIds = ref.watch(bottomSheetDictionaryFilterProvider);
    final isExactMatch = ref.watch(bottomSheetExactMatchProvider);
    final lookupParams = DictionaryLookupParams(
      word: _currentLookupWord,
      exactMatch: isExactMatch,
      dictionaryIds: filterIds,
    );
    final entriesAsync = ref.watch(dictionaryLookupProvider(lookupParams));
    final totalCount = ref.watch(
      dictionaryLookupCountProvider(lookupParams)
          .select((asyncValue) => asyncValue.valueOrNull),
    );
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
              // Pinned header: drag handle + editable word + close button.
              // PinnedHeaderSliver keeps this at the top of the scroll view
              // so it's always visible, even when the user scrolls through
              // many results or the content changes after editing the word.
              PinnedHeaderSliver(
                child: Container(
                  color: theme.colorScheme.surface,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Drag handle
                      Center(
                        child: Container(
                          margin: const EdgeInsets.only(top: 12),
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      // Editable word + filter button + close button
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 4, 8),
                        child: Row(
                          children: [
                            // Word input field
                            Expanded(
                              child: TextField(
                                controller: _wordController,
                                focusNode: _wordFocusNode,
                                onChanged: _onWordChanged,
                                style:
                                    theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  border: UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: theme.colorScheme.outline,
                                    ),
                                  ),
                                  enabledBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: theme.colorScheme.outline,
                                    ),
                                  ),
                                  focusedBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: theme.colorScheme.primary,
                                      width: 2,
                                    ),
                                  ),
                                  suffixIcon: IconButton(
                                    icon: const Icon(
                                      Icons.backspace_outlined,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      if (_wordController.text.isEmpty) return;
                                      // Delete last character
                                      final text = _wordController.text;
                                      _wordController.text =
                                          text.substring(0, text.length - 1);
                                      // Move cursor to end and focus
                                      _wordController.selection =
                                          TextSelection.collapsed(
                                        offset: _wordController.text.length,
                                      );
                                      _wordFocusNode.requestFocus();
                                      _onWordChanged(_wordController.text);
                                    },
                                    tooltip: 'Backspace',
                                  ),
                                ),
                              ),
                            ),
                            CircularToggleButton(
                              isActive: isExactMatch,
                              icon: Icons.abc,
                              // Icons.abc has heavy internal padding — bump
                              // the size so the letters read clearly.
                              iconSize: 28,
                              tooltip: AppLocalizations.of(context)
                                  .isExactMatchToggle,
                              onPressed: () {
                                ref
                                    .read(bottomSheetExactMatchProvider.notifier)
                                    .state = !isExactMatch;
                              },
                            ),
                            // Refine dictionaries button
                            _DictionaryFilterButton(
                              filterIds: filterIds,
                              onTap: () => _openRefineDialog(context),
                            ),
                            // Chevron toggle: collapsed ↔ fully expanded.
                            // Skips the mid snap; drag the handle for that.
                            IconButton(
                              icon: Icon(
                                _isExpanded
                                    ? Icons.keyboard_arrow_down
                                    : Icons.keyboard_arrow_up,
                              ),
                              onPressed: _toggleExpansion,
                              tooltip: _isExpanded
                                  ? AppLocalizations.of(context).collapse
                                  : AppLocalizations.of(context).expand,
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: widget.onClose,
                              tooltip: 'Close',
                            ),
                          ],
                        ),
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
                  return _buildResultsSlivers(context, entries, totalCount);
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

  /// Builds slivers for the results list with separators and optional footer.
  List<Widget> _buildResultsSlivers(
    BuildContext context,
    List<DictionaryEntry> entries,
    int? totalCount,
  ) {
    final hasMore = totalCount != null && totalCount > entries.length;

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
      // "Viewing X out of Y results" footer when results are truncated
      if (hasMore)
        SliverToBoxAdapter(
          child: _buildResultsFooter(
            Theme.of(context),
            entries.length,
            totalCount,
          ),
        ),
    ];
  }

  /// Footer showing "Viewing X out of Y results" with decorative dividers.
  Widget _buildResultsFooter(ThemeData theme, int displayed, int total) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: theme.colorScheme.outlineVariant,
              thickness: 1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Viewing $displayed out of $total results',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: theme.colorScheme.outlineVariant,
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Icon button that opens the dictionary refine dialog.
/// Shows a colored dot indicator when a custom filter is active.
class _DictionaryFilterButton extends StatelessWidget {
  final Set<String> filterIds;
  final VoidCallback onTap;

  const _DictionaryFilterButton({
    required this.filterIds,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasFilter = !DictionaryFilterOperations.isAllSelected(filterIds);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(
            Icons.tune,
            color: hasFilter
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
          onPressed: onTap,
          tooltip: AppLocalizations.of(context).refine,
        ),
        // Active filter indicator dot
        if (hasFilter)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
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
          // Meaning (rendered from HTML).
          // SelectionArea + Text.rich replaces SelectableText.rich:
          // SelectableText wraps EditableText/RenderEditable (designed for
          // editable fields), which throws on double-tap with multi-child
          // TextSpan trees (effectiveOffset < 0 assertion in getWordAtOffset).
          // SelectionArea uses the modern SelectableRegion/RenderParagraph
          // stack — more robust, memory-efficient, and the direction the
          // framework is moving (flutter/flutter#104547).
          SelectionArea(
            child: Text.rich(
              TextSpan(
                children: _parseHtmlToTextSpans(entry.meaning, theme),
              ),
              style: theme.textTheme.bodyMedium,
            ),
          ),
          // "Read more" link rendered outside SelectionArea so tap gestures
          // aren't intercepted by the text selection handler (especially on
          // desktop where mouse clicks trigger selection, not tap recognizers).
          if (entry.dictionaryId == 'DPD')
            DpdReadMoreLink(html: entry.meaning),
        ],
      ),
    );
  }

  /// Parses simple HTML content into TextSpans
  /// Handles: <b>, <i>, <br>, basic tags
  List<InlineSpan> _parseHtmlToTextSpans(String html, ThemeData theme) {
    final spans = <InlineSpan>[];

    // Replace <br> and <br/> with newlines, decode HTML entities
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
    var isInsideLink = false;

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
        } else if (tag.startsWith('a ')) {
          // Skip link content — rendered as a separate widget below
          isInsideLink = true;
        } else if (tag == '/a') {
          isInsideLink = false;
        } else if (tag.startsWith('r ') || tag == 'r') {
          // Custom <r> tags used in Sinhala dictionaries
          // Just render the content without special styling
        } else if (tag == '/r') {
          // End of <r> tag
        }
        // Ignore other tags
      } else {
        if (!isInsideLink) {
          buffer.write(text[i]);
        }
        i++;
      }
    }

    // Flush remaining buffer
    if (buffer.isNotEmpty) {
      spans.add(_createTextSpan(buffer.toString(), isBold, isItalic));
    }

    // Trim trailing whitespace/newlines from the last span (e.g. a <br>
    // before a stripped <a> tag would leave a dangling newline).
    if (spans.isNotEmpty && spans.last is TextSpan) {
      final last = spans.last as TextSpan;
      if (last.text != null) {
        final trimmed = last.text!.trimRight();
        if (trimmed != last.text) {
          spans[spans.length - 1] = TextSpan(
            text: trimmed,
            style: last.style,
          );
        }
      }
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
