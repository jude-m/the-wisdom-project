import 'package:flutter/material.dart';
import 'app_fonts.dart';

// ============================================
// Content-Specific Line Heights
// ============================================
// These are only used by TextEntryTheme, so they live here
// rather than in AppFonts (which holds shared UI constants).

/// Line height for paragraph text (body content)
/// Optimized for Sinhala readability - slightly generous spacing
const double _paragraphLineHeight = 1.5;

/// Line height for gatha (verse) entries
/// Tighter than paragraphs to visually group verse lines
const double _gathaLineHeight = 1.4;

/// Line height for headings
/// Tight spacing for visual hierarchy
const double _headingLineHeight = 1.2;

/// Theme extension for text entry styles
/// Centralizes all text rendering styles in one place
/// Based on the original Vue.js app CSS styles (TextEntry.vue)
@immutable
class TextEntryTheme extends ThemeExtension<TextEntryTheme> {
  /// Styles for heading entries by hierarchy level (1-5)
  final Map<int, TextStyle> headingStyles;

  /// Styles for centered entries by hierarchy level (0-5)
  final Map<int, TextStyle> centeredStyles;

  /// Style for paragraph entries
  final TextStyle paragraphStyle;

  /// Style for gatha (verse) entries
  final TextStyle gathaStyle;

  /// Style for unindented entries
  final TextStyle unindentedStyle;

  /// Layout spacing values
  final double paragraphFirstLineIndent; // text-indent: 1.4em
  final double gathaLeftPadding; // padding-left: 2.4em (default)
  final double gathaLevel2LeftPadding; // padding-left: 5em (level 2)

  const TextEntryTheme({
    required this.headingStyles,
    required this.centeredStyles,
    required this.paragraphStyle,
    required this.gathaStyle,
    required this.unindentedStyle,
    this.paragraphFirstLineIndent =
        AppFonts.baseFontSize * AppFonts.paragraphIndentEm,
    this.gathaLeftPadding = AppFonts.baseFontSize * AppFonts.gathaIndentEm,
    this.gathaLevel2LeftPadding =
        AppFonts.baseFontSize * AppFonts.gathaLevel2IndentEm,
  });

  /// Standard typography configuration (color-independent)
  /// Colors should be provided by the theme's ColorScheme
  /// Uses serif reader font (AppFonts.reader) for all reading content.
  /// [fontScale] multiplies all font sizes (default 1.0).
  factory TextEntryTheme.standard({
    required Color headingColor,
    required Color bodyColor,
    double fontScale = 1.0,
  }) {
    final scaledFonts = AppFonts.scaled(fontScale);

    return TextEntryTheme(
      // Heading styles by level (1-5)
      // Level 5 = largest (book titles), Level 1 = smallest (sub-sections)
      // Uses serif reader font for Pali headings rendered in Sinhala script
      headingStyles: {
        5: TextStyle(
          fontFamily: AppFonts.reader,
          fontFamilyFallback: AppFonts.readerFallback,
          fontSize: scaledFonts.base * 1.8,
          fontWeight: FontWeight.bold,
          color: headingColor,
          height: _headingLineHeight,
        ),
        4: TextStyle(
          fontFamily: AppFonts.reader,
          fontFamilyFallback: AppFonts.readerFallback,
          fontSize: scaledFonts.base * 1.7,
          fontWeight: FontWeight.bold,
          color: headingColor,
          height: _headingLineHeight,
        ),
        3: TextStyle(
          fontFamily: AppFonts.reader,
          fontFamilyFallback: AppFonts.readerFallback,
          fontSize: scaledFonts.base * 1.6,
          fontWeight: FontWeight.bold,
          color: headingColor,
          height: _headingLineHeight,
        ),
        2: TextStyle(
          fontFamily: AppFonts.reader,
          fontFamilyFallback: AppFonts.readerFallback,
          fontSize: scaledFonts.base * 1.4,
          fontWeight: FontWeight.bold,
          color: headingColor,
          height: _headingLineHeight,
        ),
        1: TextStyle(
          fontFamily: AppFonts.reader,
          fontFamilyFallback: AppFonts.readerFallback,
          fontSize: scaledFonts.base * 1.3,
          fontWeight: FontWeight.bold,
          color: headingColor,
          height: _headingLineHeight,
        ),
      },

      // Centered styles by level (0-5)
      // Uses serif reader font for centered Pali content
      centeredStyles: {
        5: TextStyle(
          fontFamily: AppFonts.reader,
          fontFamilyFallback: AppFonts.readerFallback,
          fontSize: scaledFonts.base * 2.1,
          fontWeight: FontWeight.w600,
          color: bodyColor,
          height: _headingLineHeight,
        ),
        4: TextStyle(
          fontFamily: AppFonts.reader,
          fontFamilyFallback: AppFonts.readerFallback,
          fontSize: scaledFonts.base * 1.8,
          fontWeight: FontWeight.w600,
          color: bodyColor,
          height: _headingLineHeight,
        ),
        3: TextStyle(
          fontFamily: AppFonts.reader,
          fontFamilyFallback: AppFonts.readerFallback,
          fontSize: scaledFonts.base * 1.5,
          fontWeight: FontWeight.w600,
          color: bodyColor,
          height: _headingLineHeight,
        ),
        2: TextStyle(
          fontFamily: AppFonts.reader,
          fontFamilyFallback: AppFonts.readerFallback,
          fontSize: scaledFonts.base * 1.25,
          fontWeight: FontWeight.w600,
          color: bodyColor,
          height: _headingLineHeight,
        ),
        1: TextStyle(
          fontFamily: AppFonts.reader,
          fontFamilyFallback: AppFonts.readerFallback,
          fontSize: scaledFonts.base * 1.1,
          fontWeight: FontWeight.w500,
          color: bodyColor,
          height: _headingLineHeight,
        ),
        0: TextStyle(
          fontFamily: AppFonts.reader,
          fontFamilyFallback: AppFonts.readerFallback,
          fontSize: scaledFonts.base,
          fontWeight: FontWeight.normal, // Non-bold for level 0
          color: bodyColor,
          height: _headingLineHeight,
        ),
      },

      // Paragraph: normal text with first-line indent
      // Uses serif reader font for Pali content rendered in Sinhala script
      paragraphStyle: TextStyle(
        fontFamily: AppFonts.reader,
        fontFamilyFallback: AppFonts.readerFallback,
        fontSize: scaledFonts.base * 1.1,
        height: _paragraphLineHeight,
        color: bodyColor,
      ),

      // Gatha (verse): italic, left-padded
      // Uses serif reader font with tighter line height for verse grouping
      gathaStyle: TextStyle(
        fontFamily: AppFonts.reader,
        fontFamilyFallback: AppFonts.readerFallback,
        fontSize: scaledFonts.base * 1.1,
        fontStyle: FontStyle.italic,
        height: _gathaLineHeight,
        color: bodyColor,
      ),

      // Unindented: same as paragraph but NO indent/padding
      // Uses serif reader font, same line height as paragraph
      unindentedStyle: TextStyle(
        fontFamily: AppFonts.reader,
        fontFamilyFallback: AppFonts.readerFallback,
        fontSize: scaledFonts.base * 1.1,
        height: _paragraphLineHeight,
        color: bodyColor,
      ),

      // Scale layout spacing values proportionally
      paragraphFirstLineIndent:
          AppFonts.baseFontSize * AppFonts.paragraphIndentEm * fontScale,
      gathaLeftPadding:
          AppFonts.baseFontSize * AppFonts.gathaIndentEm * fontScale,
      gathaLevel2LeftPadding:
          AppFonts.baseFontSize * AppFonts.gathaLevel2IndentEm * fontScale,
    );
  }

  @override
  ThemeExtension<TextEntryTheme> copyWith({
    Map<int, TextStyle>? headingStyles,
    Map<int, TextStyle>? centeredStyles,
    TextStyle? paragraphStyle,
    TextStyle? gathaStyle,
    TextStyle? unindentedStyle,
    double? paragraphFirstLineIndent,
    double? gathaLeftPadding,
    double? gathaLevel2LeftPadding,
  }) {
    return TextEntryTheme(
      headingStyles: headingStyles ?? this.headingStyles,
      centeredStyles: centeredStyles ?? this.centeredStyles,
      paragraphStyle: paragraphStyle ?? this.paragraphStyle,
      gathaStyle: gathaStyle ?? this.gathaStyle,
      unindentedStyle: unindentedStyle ?? this.unindentedStyle,
      paragraphFirstLineIndent:
          paragraphFirstLineIndent ?? this.paragraphFirstLineIndent,
      gathaLeftPadding: gathaLeftPadding ?? this.gathaLeftPadding,
      gathaLevel2LeftPadding:
          gathaLevel2LeftPadding ?? this.gathaLevel2LeftPadding,
    );
  }

  @override
  ThemeExtension<TextEntryTheme> lerp(
    covariant ThemeExtension<TextEntryTheme>? other,
    double t,
  ) {
    if (other is! TextEntryTheme) return this;

    return TextEntryTheme(
      headingStyles: headingStyles, // Maps don't lerp well
      centeredStyles: centeredStyles,
      paragraphStyle: TextStyle.lerp(paragraphStyle, other.paragraphStyle, t)!,
      gathaStyle: TextStyle.lerp(gathaStyle, other.gathaStyle, t)!,
      unindentedStyle:
          TextStyle.lerp(unindentedStyle, other.unindentedStyle, t)!,
      paragraphFirstLineIndent: paragraphFirstLineIndent,
      gathaLeftPadding: gathaLeftPadding,
      gathaLevel2LeftPadding: gathaLevel2LeftPadding,
    );
  }
}

/// Extension to easily access text entry theme from BuildContext
extension TextEntryThemeExtension on BuildContext {
  TextEntryTheme get textEntryTheme =>
      Theme.of(this).extension<TextEntryTheme>() ??
      TextEntryTheme.standard(
        headingColor: Theme.of(this).colorScheme.primary,
        bodyColor: Theme.of(this).colorScheme.onSurface,
      );
}
