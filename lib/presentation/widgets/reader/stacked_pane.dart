import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SelectedContent;
import '../../../core/constants/constants.dart';
import '../../../domain/entities/bjt/bjt_page.dart';
import '../../../domain/entities/content/entry_type.dart';
import '../../models/in_page_search_state.dart';
import 'entry_key_registry.dart';
import 'reader_entry_builder.dart';

/// A stacked reader pane that renders Pali and Sinhala entries vertically.
///
/// For each entry index, renders the Pali entry first (semi-bold) followed by
/// its Sinhala translation (regular weight), then moves to the next index.
/// This layout is ideal for smaller screens where side-by-side is too cramped.
///
/// Uses [ListView.builder] with one item per page for lazy rendering,
/// following the same pattern as [SingleColumnPane].
class StackedPane extends StatelessWidget {
  const StackedPane({
    super.key,
    required this.scrollController,
    required this.pages,
    required this.entryStart,
    required this.absolutePageStart,
    required this.searchState,
    required this.currentMatchKey,
    required this.entryKeyRegistry,
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

  /// Attached to the current search match entry for scroll-to-match.
  final GlobalKey currentMatchKey;

  /// Registry for entry-level GlobalKeys used to sync scroll position
  /// across layout switches.
  final EntryKeyRegistry entryKeyRegistry;

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
        onTap: onTapEmpty,
        behavior: HitTestBehavior.translucent,
        child: ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.all(24.0),
          itemCount: pages.length + 1, // +1 for top spacer
          itemBuilder: (context, index) {
            if (index == 0) {
              return const SizedBox(
                  height: PaneWidthConstants.readerActionButtonGroupHeight);
            }
            final pageIndex = index - 1;
            final absolutePageIndex = absolutePageStart + pageIndex;
            final page = pages[pageIndex];
            final actualEntryStart = pageIndex == 0 ? entryStart : 0;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ReaderEntryBuilder.buildPageNumber(context, page.pageNumber),
                const SizedBox(height: 16),
                ..._buildStackedEntries(
                    context, page, absolutePageIndex, actualEntryStart),
                const SizedBox(height: 32),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Builds stacked Pali/Sinhala entry widgets for a single page.
  ///
  /// For each entry index, emits the Pali entry (semi-bold, dictionary-tappable)
  /// then the Sinhala entry (regular weight), with a small gap between them
  /// and a larger gap between pairs.
  List<Widget> _buildStackedEntries(
    BuildContext context,
    BJTPage page,
    int absolutePageIndex,
    int startEntry,
  ) {
    final widgets = <Widget>[];
    final currentMatch = searchState.currentMatch;
    final effectiveQuery = searchState.effectiveQuery;
    final hasQuery = searchState.hasActiveQuery;
    final entryCount = page.paliSection.entries.length - startEntry;

    for (var i = 0; i < entryCount; i++) {
      final entryIndex = i + startEntry;
      final paliEntry = page.paliSection.entries[entryIndex];
      final sinhalaEntry = entryIndex < page.sinhalaSection.entries.length
          ? page.sinhalaSection.entries[entryIndex]
          : null;

      // Check if either entry is the current search match
      final isPaliCurrentMatch = currentMatch != null &&
          currentMatch.pageIndex == absolutePageIndex &&
          currentMatch.entryIndex == entryIndex &&
          currentMatch.languageCode == 'pi';
      final isSinhalaCurrentMatch = currentMatch != null &&
          currentMatch.pageIndex == absolutePageIndex &&
          currentMatch.entryIndex == entryIndex &&
          currentMatch.languageCode == 'si';

      // Add extra space before title entries (heading/centered) to
      // visually separate them from preceding content
      final isTitle = paliEntry.entryType == EntryType.heading ||
          paliEntry.entryType == EntryType.centered;
      if (isTitle && i > 0) {
        widgets.add(const SizedBox(height: 12.0));
      }

      // Pali entry — semi-bold, dictionary lookup enabled
      final paliHasMatch = hasQuery &&
          searchState.hasMatchInEntry(absolutePageIndex, entryIndex, 'pi');
      final paliWidget = DefaultTextStyle.merge(
        style: const TextStyle(fontWeight: FontWeight.w600),
        child: ReaderEntryBuilder.buildEntry(
          context,
          paliEntry,
          enableDictionaryLookup: true,
          inPageSearchQuery: paliHasMatch ? effectiveQuery : null,
          currentMatchIndexInEntry:
              isPaliCurrentMatch ? currentMatch.matchIndexInEntry : null,
          onWordTap: onWordTap,
        ),
      );

      // Build the entry pair children
      final pairChildren = <Widget>[
        Padding(
          key: isPaliCurrentMatch ? currentMatchKey : null,
          padding: const EdgeInsets.only(bottom: 8.0),
          child: paliWidget,
        ),
      ];

      // Sinhala entry — regular weight, no dictionary lookup
      if (sinhalaEntry != null) {
        final sinhalaHasMatch = hasQuery &&
            searchState.hasMatchInEntry(absolutePageIndex, entryIndex, 'si');
        final sinhalaWidget = ReaderEntryBuilder.buildEntry(
          context,
          sinhalaEntry,
          enableDictionaryLookup: false,
          inPageSearchQuery: sinhalaHasMatch ? effectiveQuery : null,
          currentMatchIndexInEntry:
              isSinhalaCurrentMatch ? currentMatch.matchIndexInEntry : null,
          onWordTap: onWordTap,
        );

        pairChildren.add(
          Padding(
            key: isSinhalaCurrentMatch ? currentMatchKey : null,
            padding: const EdgeInsets.only(bottom: 20.0),
            child: sinhalaWidget,
          ),
        );
      } else {
        // No Sinhala entry — use 20px spacing for consistent pair gap
        pairChildren[0] = Padding(
          key: isPaliCurrentMatch ? currentMatchKey : null,
          padding: const EdgeInsets.only(bottom: 20.0),
          child: paliWidget,
        );
      }

      // Wrap the entry pair with a registry key for layout-switch scroll sync
      widgets.add(
        KeyedSubtree(
          key: entryKeyRegistry.keyFor(absolutePageIndex, entryIndex),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: pairChildren,
          ),
        ),
      );
    }

    return widgets;
  }
}
