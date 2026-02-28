import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SelectedContent;
import '../../../core/constants/constants.dart';
import '../../../domain/entities/bjt/bjt_page.dart';
import '../../models/in_page_search_state.dart';
import 'reader_entry_builder.dart';

/// A single-column reader pane for paliOnly or sinhalaOnly display modes.
///
/// Renders a lazy [ListView.builder] of page numbers and entries.
/// Parameterized by [languageCode] and [enableDictionaryLookup] to handle
/// both Pali and Sinhala modes without duplication.
class SingleColumnPane extends StatelessWidget {
  const SingleColumnPane({
    super.key,
    required this.scrollController,
    required this.pages,
    required this.entryStart,
    required this.absolutePageStart,
    required this.searchState,
    required this.languageCode,
    required this.enableDictionaryLookup,
    required this.currentMatchKey,
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

  /// 'pi' for Pali or 'si' for Sinhala.
  final String languageCode;
  final bool enableDictionaryLookup;

  /// Attached to the current search match entry for scroll-to-match.
  final GlobalKey currentMatchKey;

  /// Called when tapping empty space (clears highlights).
  final VoidCallback onTapEmpty;

  /// Called when a word is tapped (for dictionary lookup).
  final void Function(String word)? onWordTap;

  final void Function(SelectedContent?) onSelectionChanged;
  final Widget Function(BuildContext, SelectableRegionState) contextMenuBuilder;

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      onSelectionChanged: onSelectionChanged,
      contextMenuBuilder: contextMenuBuilder,
      child: GestureDetector(
        // Clear all highlights when tapping empty space
        onTap: onTapEmpty,
        behavior: HitTestBehavior.translucent,
        child: ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.all(24.0),
          itemCount: pages.length + 1, // +1 for top spacer
          itemBuilder: (context, index) {
            // First item is a spacer so content doesn't hide behind button group
            if (index == 0) {
              return const SizedBox(
                  height: PaneWidthConstants.readerActionButtonGroupHeight);
            }
            // Adjust index for pages (index-1 since spacer is at 0)
            final pageIndex = index - 1;
            final absolutePageIndex = absolutePageStart + pageIndex;
            final page = pages[pageIndex];
            // On first page, skip entries before entryStart
            final actualEntryStart = pageIndex == 0 ? entryStart : 0;
            final section = languageCode == 'pi'
                ? page.paliSection
                : page.sinhalaSection;
            final entries =
                section.entries.skip(actualEntryStart).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ReaderEntryBuilder.buildPageNumber(context, page.pageNumber),
                const SizedBox(height: 16),
                ...ReaderEntryBuilder.buildEntries(
                  context,
                  entries,
                  enableDictionaryLookup: enableDictionaryLookup,
                  searchState: searchState,
                  absolutePageIndex: absolutePageIndex,
                  entryStartOffset: actualEntryStart,
                  languageCode: languageCode,
                  currentMatchKey: currentMatchKey,
                  onWordTap: onWordTap,
                ),
                const SizedBox(height: 32), // Space between pages
              ],
            );
          },
        ),
      ),
    );
  }
}
