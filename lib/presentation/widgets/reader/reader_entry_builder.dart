import 'package:flutter/material.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/text_entry_theme.dart';
import '../../models/in_page_search_state.dart';
import '../../../domain/entities/content/entry.dart';
import '../../../domain/entities/content/entry_type.dart';
import 'entry_key_registry.dart';
import 'text_entry_widget.dart';

/// Static utility for building reader entry widgets.
///
/// Used by [SingleColumnPane] and [DualColumnPane] to render
/// entries and page numbers without duplicating styling logic.
class ReaderEntryBuilder {
  ReaderEntryBuilder._();

  /// Builds a single entry widget styled by its [EntryType].
  ///
  /// [onWordTap] is called when a word is tapped (for dictionary lookup).
  /// [inPageSearchQuery] highlights matching text when non-null.
  /// [currentMatchIndexInEntry] marks the active match within the entry.
  static Widget buildEntry(
    BuildContext context,
    Entry entry, {
    bool enableDictionaryLookup = false,
    String? inPageSearchQuery,
    int? currentMatchIndexInEntry,
    void Function(String word)? onWordTap,
  }) {
    final textEntryTheme = context.textEntryTheme;
    // Wrap the word tap callback to match OnWordTap signature (word, position)
    final OnWordTap? wordTapHandler =
        onWordTap != null ? (word, _) => onWordTap(word) : null;
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
        return Center(
          child: TextEntryWidget(
            text: entry.plainText,
            style: textStyle,
            textAlign: TextAlign.center,
            enableTap: enableDictionaryLookup,
            onWordTap: wordTapHandler,
            markedRanges: entry.markedRanges,
            inPageSearchQuery: inPageSearchQuery,
            currentMatchIndexInEntry: currentMatchIndexInEntry,
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
            onWordTap: wordTapHandler,
            markedRanges: entry.markedRanges,
            inPageSearchQuery: inPageSearchQuery,
            currentMatchIndexInEntry: currentMatchIndexInEntry,
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
      onWordTap: wordTapHandler,
      markedRanges: entry.markedRanges,
      inPageSearchQuery: inPageSearchQuery,
      currentMatchIndexInEntry: currentMatchIndexInEntry,
    );
  }

  /// Builds a list of entry widgets with search highlight support.
  ///
  /// [searchState] provides the current in-page search state.
  /// [absolutePageIndex] is the page index in the full document (not the loaded slice).
  /// [entryStartOffset] accounts for skipped entries on the first page.
  /// [languageCode] is 'pi' for Pali or 'si' for Sinhala.
  /// [currentMatchKey] is attached to the current search match entry for scroll-to-match.
  static List<Widget> buildEntries(
    BuildContext context,
    List<Entry> entries, {
    bool enableDictionaryLookup = false,
    required InPageSearchState searchState,
    int absolutePageIndex = 0,
    int entryStartOffset = 0,
    String languageCode = 'pi',
    GlobalKey? currentMatchKey,
    void Function(String word)? onWordTap,
    EntryKeyRegistry? entryKeyRegistry,
  }) {
    final currentMatch = searchState.currentMatch;
    final effectiveQuery = searchState.effectiveQuery;
    final hasQuery = searchState.hasActiveQuery;

    return entries.asMap().entries.map((mapEntry) {
      final localIndex = mapEntry.key;
      final entry = mapEntry.value;
      // The actual entry index in the page (accounting for skipped entries)
      final absoluteEntryIndex = localIndex + entryStartOffset;

      // Determine if this entry contains the current match
      final isCurrentMatchEntry = currentMatch != null &&
          currentMatch.pageIndex == absolutePageIndex &&
          currentMatch.entryIndex == absoluteEntryIndex &&
          currentMatch.languageCode == languageCode;

      // Only highlight entries that have matches (prevents highlighting
      // entries in adjacent suttas that share the same document file)
      final entryHasMatch = hasQuery &&
          searchState.hasMatchInEntry(
            absolutePageIndex, absoluteEntryIndex, languageCode,
          );

      final entryWidget = Padding(
        key: isCurrentMatchEntry ? currentMatchKey : null,
        padding: const EdgeInsets.only(bottom: 12.0),
        child: buildEntry(
          context,
          entry,
          enableDictionaryLookup: enableDictionaryLookup,
          inPageSearchQuery: entryHasMatch ? effectiveQuery : null,
          currentMatchIndexInEntry:
              isCurrentMatchEntry ? currentMatch.matchIndexInEntry : null,
          onWordTap: onWordTap,
        ),
      );

      // Wrap with registry key for layout-switch scroll sync
      if (entryKeyRegistry != null) {
        return KeyedSubtree(
          key: entryKeyRegistry.keyFor(absolutePageIndex, absoluteEntryIndex),
          child: entryWidget,
        );
      }
      return entryWidget;
    }).toList();
  }

  /// Builds a page number label with fixed height for alignment.
  static Widget buildPageNumber(BuildContext context, int pageNumber) {
    return SizedBox(
      height: 20, // Fixed height to ensure alignment
      child: Text(
        '$pageNumber',
        style: context.typography.pageNumber,
      ),
    );
  }
}
