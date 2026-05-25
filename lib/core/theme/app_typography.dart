import 'package:flutter/material.dart';
import 'app_fonts.dart';

/// Theme extension for UI typography styles.
///
/// Centralizes all UI text styling (badges, labels, tabs, tree nodes, etc.)
/// in one place. Content styles (paragraphs, headings, gatha) are handled
/// by [TextEntryTheme].
///
/// Usage:
/// ```dart
/// Text('BJT', style: context.typography.badgeLabel)
/// Text('Results', style: context.typography.sectionHeader)
/// ```
@immutable
class AppTypography extends ThemeExtension<AppTypography> {
  // ============================================
  // Labels & Badges
  // ============================================

  /// Style for edition ID badges (BJT, SC)
  final TextStyle badgeLabel;

  /// Style for section headers (uppercase, letter-spaced)
  /// Example: "RECENT SEARCHES"
  final TextStyle sectionHeader;

  /// Style for count badges in tabs
  final TextStyle countBadge;

  // ============================================
  // Chips
  // ============================================

  /// Style for unselected filter chips
  final TextStyle chipLabel;

  /// Style for selected filter chips
  final TextStyle chipLabelSelected;

  // ============================================
  // List Items
  // ============================================

  /// Style for primary text in list items
  final TextStyle resultTitle;

  /// Style for secondary/breadcrumb text
  final TextStyle resultSubtitle;

  /// Style for base search highlight text
  final TextStyle resultMatchedText;

  /// Style for the primary text of a row in a compact list/dropdown
  /// (e.g. recent searches). Smaller and lighter than [resultTitle], which
  /// is reserved for prominent search-result tiles.
  final TextStyle listRowTitle;

  // ============================================
  // Actions
  // ============================================

  /// Style for the text label of an action button shown next to an icon
  /// (e.g. reader toolbar: Bookmark, Share). Color is left to the call site
  /// since it usually wants the theme's primary color.
  final TextStyle actionLabel;

  /// Style for small inline clickable text links / affordances
  /// (e.g. "View N more", "Show Less" inside grouped result rows).
  final TextStyle linkLabel;

  // ============================================
  // Reading Content (scaled by font slider)
  // ============================================

  /// Style for dictionary definition/meaning body text.
  /// Used inside the dictionary bottom sheet and any other place that
  /// renders longer-form definition prose. Scales with the font slider.
  final TextStyle definitionBody;

  // ============================================
  // Navigation
  // ============================================

  /// Style for active tabs
  final TextStyle tabLabelActive;

  /// Style for inactive tabs
  final TextStyle tabLabelInactive;

  /// Style for tree node labels
  final TextStyle treeNodeLabel;

  /// Style for selected tree node labels
  final TextStyle treeNodeLabelSelected;

  // ============================================
  // Dialogs & Menus
  // ============================================

  /// Style for modal/dialog titles
  final TextStyle dialogTitle;

  /// Style for settings section headers
  final TextStyle menuSectionLabel;

  /// Style for segmented button labels (P, P+S, S)
  final TextStyle segmentedButtonLabel;

  // ============================================
  // Input
  // ============================================

  /// Style for search placeholder text
  final TextStyle searchHint;

  /// Style for the editable text inside the app bar search input.
  /// Same metrics as [searchHint] but uses full-opacity [onSurface] color.
  final TextStyle searchInput;

  // ============================================
  // States & Feedback
  // ============================================

  /// Style for empty state messages ("No results found")
  final TextStyle emptyStateMessage;

  /// Style for error text
  final TextStyle errorMessage;

  /// Style for page number indicators
  final TextStyle pageNumber;

  const AppTypography({
    required this.badgeLabel,
    required this.sectionHeader,
    required this.countBadge,
    required this.chipLabel,
    required this.chipLabelSelected,
    required this.resultTitle,
    required this.resultSubtitle,
    required this.resultMatchedText,
    required this.listRowTitle,
    required this.actionLabel,
    required this.linkLabel,
    required this.definitionBody,
    required this.tabLabelActive,
    required this.tabLabelInactive,
    required this.treeNodeLabel,
    required this.treeNodeLabelSelected,
    required this.dialogTitle,
    required this.menuSectionLabel,
    required this.segmentedButtonLabel,
    required this.searchHint,
    required this.searchInput,
    required this.emptyStateMessage,
    required this.errorMessage,
    required this.pageNumber,
  });

  /// Standard typography configuration.
  /// Colors are derived from the provided ColorScheme.
  /// Uses sans-serif UI font (AppFonts.ui) for all interface elements.
  /// [fontScale] multiplies all font sizes (default 1.0).
  factory AppTypography.fromColorScheme(
    ColorScheme colorScheme, {
    double fontScale = 1.0,
  }) {
    final scaledFonts = AppFonts.scaled(fontScale);

    return AppTypography(
      // Labels & Badges
      badgeLabel: TextStyle(
        fontFamily: AppFonts.ui,
        fontFamilyFallback: AppFonts.uiFallback,
        fontSize: scaledFonts.badge,
        fontWeight: FontWeight.w600,
        color: colorScheme.onPrimaryContainer,
        height: AppFonts.uiLineHeight,
      ),
      sectionHeader: TextStyle(
        fontFamily: AppFonts.ui,
        fontFamilyFallback: AppFonts.uiFallback,
        fontSize: scaledFonts.label,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
        letterSpacing: 1.2,
        height: AppFonts.uiLineHeight,
      ),
      countBadge: TextStyle(
        fontFamily: AppFonts.ui,
        fontFamilyFallback: AppFonts.uiFallback,
        fontSize: scaledFonts.badge,
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurfaceVariant,
        height: AppFonts.uiLineHeight,
      ),

      // Chips
      chipLabel: TextStyle(
        fontFamily: AppFonts.ui,
        fontFamilyFallback: AppFonts.uiFallback,
        fontSize: scaledFonts.label,
        fontWeight: AppFonts.bodyWeight,
        color: colorScheme.onSurfaceVariant,
        height: AppFonts.uiLineHeight,
      ),
      chipLabelSelected: TextStyle(
        fontFamily: AppFonts.ui,
        fontFamilyFallback: AppFonts.uiFallback,
        fontSize: scaledFonts.label,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSecondary,
        height: AppFonts.uiLineHeight,
      ),

      // List Items
      resultTitle: TextStyle(
        fontFamily: AppFonts.ui,
        fontFamilyFallback: AppFonts.uiFallback,
        fontSize: scaledFonts.base,
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurface,
        height: AppFonts.uiLineHeight,
      ),
      resultSubtitle: TextStyle(
        fontFamily: AppFonts.ui,
        fontFamilyFallback: AppFonts.uiFallback,
        fontSize: scaledFonts.tree,
        fontWeight: AppFonts.bodyWeight,
        color: colorScheme.onSurfaceVariant,
        height: AppFonts.uiLineHeight,
      ),
      resultMatchedText: TextStyle(
        fontFamily: AppFonts.ui,
        fontFamilyFallback: AppFonts.uiFallback,
        fontSize: scaledFonts.tree,
        fontWeight: AppFonts.bodyWeight,
        color: colorScheme.onSurface,
        height: AppFonts.uiLineHeight,
      ),
      listRowTitle: TextStyle(
        fontFamily: AppFonts.ui,
        fontFamilyFallback: AppFonts.uiFallback,
        fontSize: scaledFonts.tree,
        fontWeight: AppFonts.bodyWeight,
        color: colorScheme.onSurface,
        height: AppFonts.uiLineHeight,
      ),

      // Actions — clickable affordances (button labels, inline links).
      // Color is intentionally left at onSurface; call sites that want the
      // primary color (selected state, highlighted action) apply .copyWith.
      actionLabel: TextStyle(
        fontFamily: AppFonts.ui,
        fontFamilyFallback: AppFonts.uiFallback,
        fontSize: scaledFonts.label,
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurface,
        height: AppFonts.uiLineHeight,
      ),
      linkLabel: TextStyle(
        fontFamily: AppFonts.ui,
        fontFamilyFallback: AppFonts.uiFallback,
        fontSize: scaledFonts.badge,
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurfaceVariant,
        height: AppFonts.uiLineHeight,
      ),

      // Reading Content — dictionary definitions, prose blocks.
      // Sized to match Material's bodyMedium (14sp) at scale=1.0 so existing
      // layouts don't shift, but driven by `scaledFonts.tree` so the font
      // slider takes effect.
      definitionBody: TextStyle(
        fontFamily: AppFonts.ui,
        fontFamilyFallback: AppFonts.uiFallback,
        fontSize: scaledFonts.tree,
        fontWeight: AppFonts.bodyWeight,
        color: colorScheme.onSurface,
        height: AppFonts.uiLineHeight,
      ),

      // Navigation
      tabLabelActive: TextStyle(
        fontFamily: AppFonts.ui,
        fontFamilyFallback: AppFonts.uiFallback,
        fontSize: scaledFonts.tab,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
        height: AppFonts.uiLineHeight,
      ),
      tabLabelInactive: TextStyle(
        fontFamily: AppFonts.ui,
        fontFamilyFallback: AppFonts.uiFallback,
        fontSize: scaledFonts.tab,
        fontWeight: AppFonts.bodyWeight,
        color: colorScheme.onSurface,
        height: AppFonts.uiLineHeight,
      ),
      treeNodeLabel: TextStyle(
        fontFamily: AppFonts.ui,
        fontFamilyFallback: AppFonts.uiFallback,
        fontSize: scaledFonts.tree,
        fontWeight: AppFonts.bodyWeight,
        color: colorScheme.onSurface,
        height: AppFonts.uiLineHeight,
      ),
      treeNodeLabelSelected: TextStyle(
        fontFamily: AppFonts.ui,
        fontFamilyFallback: AppFonts.uiFallback,
        fontSize: scaledFonts.tree,
        fontWeight: FontWeight.w600,
        color: colorScheme.onPrimaryContainer,
        height: AppFonts.uiLineHeight,
      ),

      // Dialogs & Menus
      dialogTitle: TextStyle(
        fontFamily: AppFonts.ui,
        fontFamilyFallback: AppFonts.uiFallback,
        fontSize: scaledFonts.base * 1.25,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
        height: AppFonts.uiLineHeight,
      ),
      menuSectionLabel: TextStyle(
        fontFamily: AppFonts.ui,
        fontFamilyFallback: AppFonts.uiFallback,
        fontSize: scaledFonts.label,
        fontWeight: AppFonts.bodyWeight,
        color: colorScheme.onSurfaceVariant,
        height: AppFonts.uiLineHeight,
      ),
      segmentedButtonLabel: TextStyle(
        fontFamily: AppFonts.ui,
        fontFamilyFallback: AppFonts.uiFallback,
        fontSize: scaledFonts.badge,
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurface,
        height: AppFonts.uiLineHeight,
      ),

      // Input
      searchHint: TextStyle(
        fontFamily: AppFonts.ui,
        fontFamilyFallback: AppFonts.uiFallback,
        fontSize: scaledFonts.base,
        fontWeight: AppFonts.bodyWeight,
        color: colorScheme.onSurfaceVariant,
        height: AppFonts.uiLineHeight,
      ),
      searchInput: TextStyle(
        fontFamily: AppFonts.ui,
        fontFamilyFallback: AppFonts.uiFallback,
        fontSize: scaledFonts.base,
        fontWeight: AppFonts.bodyWeight,
        color: colorScheme.onSurface,
        height: AppFonts.uiLineHeight,
      ),

      // States & Feedback
      emptyStateMessage: TextStyle(
        fontFamily: AppFonts.ui,
        fontFamilyFallback: AppFonts.uiFallback,
        fontSize: scaledFonts.base,
        fontWeight: AppFonts.bodyWeight,
        color: colorScheme.onSurface.withValues(alpha: 0.6),
        height: AppFonts.uiLineHeight,
      ),
      errorMessage: TextStyle(
        fontFamily: AppFonts.ui,
        fontFamilyFallback: AppFonts.uiFallback,
        fontSize: scaledFonts.tree,
        fontWeight: AppFonts.bodyWeight,
        color: colorScheme.error,
        height: AppFonts.uiLineHeight,
      ),
      pageNumber: TextStyle(
        fontFamily: AppFonts.ui,
        fontFamilyFallback: AppFonts.uiFallback,
        fontSize: scaledFonts.pageNumber,
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurface.withValues(alpha: 0.6),
        height: 1.0,
      ),
    );
  }

  @override
  ThemeExtension<AppTypography> copyWith({
    TextStyle? badgeLabel,
    TextStyle? sectionHeader,
    TextStyle? countBadge,
    TextStyle? chipLabel,
    TextStyle? chipLabelSelected,
    TextStyle? resultTitle,
    TextStyle? resultSubtitle,
    TextStyle? resultMatchedText,
    TextStyle? listRowTitle,
    TextStyle? actionLabel,
    TextStyle? linkLabel,
    TextStyle? definitionBody,
    TextStyle? tabLabelActive,
    TextStyle? tabLabelInactive,
    TextStyle? treeNodeLabel,
    TextStyle? treeNodeLabelSelected,
    TextStyle? dialogTitle,
    TextStyle? menuSectionLabel,
    TextStyle? segmentedButtonLabel,
    TextStyle? searchHint,
    TextStyle? searchInput,
    TextStyle? emptyStateMessage,
    TextStyle? errorMessage,
    TextStyle? pageNumber,
  }) {
    return AppTypography(
      badgeLabel: badgeLabel ?? this.badgeLabel,
      sectionHeader: sectionHeader ?? this.sectionHeader,
      countBadge: countBadge ?? this.countBadge,
      chipLabel: chipLabel ?? this.chipLabel,
      chipLabelSelected: chipLabelSelected ?? this.chipLabelSelected,
      resultTitle: resultTitle ?? this.resultTitle,
      resultSubtitle: resultSubtitle ?? this.resultSubtitle,
      resultMatchedText: resultMatchedText ?? this.resultMatchedText,
      listRowTitle: listRowTitle ?? this.listRowTitle,
      actionLabel: actionLabel ?? this.actionLabel,
      linkLabel: linkLabel ?? this.linkLabel,
      definitionBody: definitionBody ?? this.definitionBody,
      tabLabelActive: tabLabelActive ?? this.tabLabelActive,
      tabLabelInactive: tabLabelInactive ?? this.tabLabelInactive,
      treeNodeLabel: treeNodeLabel ?? this.treeNodeLabel,
      treeNodeLabelSelected:
          treeNodeLabelSelected ?? this.treeNodeLabelSelected,
      dialogTitle: dialogTitle ?? this.dialogTitle,
      menuSectionLabel: menuSectionLabel ?? this.menuSectionLabel,
      segmentedButtonLabel: segmentedButtonLabel ?? this.segmentedButtonLabel,
      searchHint: searchHint ?? this.searchHint,
      searchInput: searchInput ?? this.searchInput,
      emptyStateMessage: emptyStateMessage ?? this.emptyStateMessage,
      errorMessage: errorMessage ?? this.errorMessage,
      pageNumber: pageNumber ?? this.pageNumber,
    );
  }

  @override
  ThemeExtension<AppTypography> lerp(
    covariant ThemeExtension<AppTypography>? other,
    double t,
  ) {
    if (other is! AppTypography) return this;

    return AppTypography(
      badgeLabel: TextStyle.lerp(badgeLabel, other.badgeLabel, t)!,
      sectionHeader: TextStyle.lerp(sectionHeader, other.sectionHeader, t)!,
      countBadge: TextStyle.lerp(countBadge, other.countBadge, t)!,
      chipLabel: TextStyle.lerp(chipLabel, other.chipLabel, t)!,
      chipLabelSelected:
          TextStyle.lerp(chipLabelSelected, other.chipLabelSelected, t)!,
      resultTitle: TextStyle.lerp(resultTitle, other.resultTitle, t)!,
      resultSubtitle: TextStyle.lerp(resultSubtitle, other.resultSubtitle, t)!,
      resultMatchedText:
          TextStyle.lerp(resultMatchedText, other.resultMatchedText, t)!,
      listRowTitle: TextStyle.lerp(listRowTitle, other.listRowTitle, t)!,
      actionLabel: TextStyle.lerp(actionLabel, other.actionLabel, t)!,
      linkLabel: TextStyle.lerp(linkLabel, other.linkLabel, t)!,
      definitionBody: TextStyle.lerp(definitionBody, other.definitionBody, t)!,
      tabLabelActive: TextStyle.lerp(tabLabelActive, other.tabLabelActive, t)!,
      tabLabelInactive:
          TextStyle.lerp(tabLabelInactive, other.tabLabelInactive, t)!,
      treeNodeLabel: TextStyle.lerp(treeNodeLabel, other.treeNodeLabel, t)!,
      treeNodeLabelSelected:
          TextStyle.lerp(treeNodeLabelSelected, other.treeNodeLabelSelected, t)!,
      dialogTitle: TextStyle.lerp(dialogTitle, other.dialogTitle, t)!,
      menuSectionLabel:
          TextStyle.lerp(menuSectionLabel, other.menuSectionLabel, t)!,
      segmentedButtonLabel:
          TextStyle.lerp(segmentedButtonLabel, other.segmentedButtonLabel, t)!,
      searchHint: TextStyle.lerp(searchHint, other.searchHint, t)!,
      searchInput: TextStyle.lerp(searchInput, other.searchInput, t)!,
      emptyStateMessage:
          TextStyle.lerp(emptyStateMessage, other.emptyStateMessage, t)!,
      errorMessage: TextStyle.lerp(errorMessage, other.errorMessage, t)!,
      pageNumber: TextStyle.lerp(pageNumber, other.pageNumber, t)!,
    );
  }
}

/// Extension to easily access app typography from BuildContext.
extension AppTypographyExtension on BuildContext {
  /// Access the AppTypography theme extension.
  ///
  /// Falls back to a default instance if not found in the theme.
  AppTypography get typography =>
      Theme.of(this).extension<AppTypography>() ??
      AppTypography.fromColorScheme(Theme.of(this).colorScheme);
}
