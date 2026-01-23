import 'package:flutter/material.dart';
import 'app_fonts.dart';

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
    this.paragraphFirstLineIndent = 22.4, // 1.4em at 16px base
    this.gathaLeftPadding = 38.4, // 2.4em at 16px base
    this.gathaLevel2LeftPadding = 80.0, // 5em at 16px base
  });

  /// Standard typography configuration (color-independent)
  /// Colors should be provided by the theme's ColorScheme
  factory TextEntryTheme.standard({
    required Color headingColor,
    required Color bodyColor,
  }) {
    return TextEntryTheme(
      // Heading styles by level (1-5)
      // Uses Sinhala font for Pali headings rendered in Sinhala script
      headingStyles: {
        5: TextStyle(
          fontFamily: AppFonts.sinhala,
          fontFamilyFallback: AppFonts.sinhalaFallback,
          fontSize: AppFonts.baseFontSize * 1.8,
          fontWeight: FontWeight.bold,
          color: headingColor,
          height: AppFonts.headingLineHeight,
        ),
        4: TextStyle(
          fontFamily: AppFonts.sinhala,
          fontFamilyFallback: AppFonts.sinhalaFallback,
          fontSize: AppFonts.baseFontSize * 1.7,
          fontWeight: FontWeight.bold,
          color: headingColor,
          height: AppFonts.headingLineHeight,
        ),
        3: TextStyle(
          fontFamily: AppFonts.sinhala,
          fontFamilyFallback: AppFonts.sinhalaFallback,
          fontSize: AppFonts.baseFontSize * 1.6,
          fontWeight: FontWeight.bold,
          color: headingColor,
          height: AppFonts.headingLineHeight,
        ),
        2: TextStyle(
          fontFamily: AppFonts.sinhala,
          fontFamilyFallback: AppFonts.sinhalaFallback,
          fontSize: AppFonts.baseFontSize * 1.4,
          fontWeight: FontWeight.bold,
          color: headingColor,
          height: AppFonts.headingLineHeight,
        ),
        1: TextStyle(
          fontFamily: AppFonts.sinhala,
          fontFamilyFallback: AppFonts.sinhalaFallback,
          fontSize: AppFonts.baseFontSize * 1.3,
          fontWeight: FontWeight.bold,
          color: headingColor,
          height: AppFonts.headingLineHeight,
        ),
      },

      // Centered styles by level (0-5)
      // Uses Sinhala font for centered Pali content
      centeredStyles: {
        5: TextStyle(
          fontFamily: AppFonts.sinhala,
          fontFamilyFallback: AppFonts.sinhalaFallback,
          fontSize: AppFonts.baseFontSize * 2.1,
          fontWeight: FontWeight.w600,
          color: bodyColor,
          height: AppFonts.headingLineHeight,
        ),
        4: TextStyle(
          fontFamily: AppFonts.sinhala,
          fontFamilyFallback: AppFonts.sinhalaFallback,
          fontSize: AppFonts.baseFontSize * 1.8,
          fontWeight: FontWeight.w600,
          color: bodyColor,
          height: AppFonts.headingLineHeight,
        ),
        3: TextStyle(
          fontFamily: AppFonts.sinhala,
          fontFamilyFallback: AppFonts.sinhalaFallback,
          fontSize: AppFonts.baseFontSize * 1.5,
          fontWeight: FontWeight.w600,
          color: bodyColor,
          height: AppFonts.headingLineHeight,
        ),
        2: TextStyle(
          fontFamily: AppFonts.sinhala,
          fontFamilyFallback: AppFonts.sinhalaFallback,
          fontSize: AppFonts.baseFontSize * 1.25,
          fontWeight: FontWeight.w600,
          color: bodyColor,
          height: AppFonts.headingLineHeight,
        ),
        1: TextStyle(
          fontFamily: AppFonts.sinhala,
          fontFamilyFallback: AppFonts.sinhalaFallback,
          fontSize: AppFonts.baseFontSize * 1.1,
          fontWeight: FontWeight.w600,
          color: bodyColor,
          height: AppFonts.headingLineHeight,
        ),
        0: TextStyle(
          fontFamily: AppFonts.sinhala,
          fontFamilyFallback: AppFonts.sinhalaFallback,
          fontSize: AppFonts.baseFontSize,
          fontWeight: FontWeight.normal, // Non-bold for level 0
          color: bodyColor,
          height: AppFonts.headingLineHeight,
        ),
      },

      // Paragraph: normal text with first-line indent
      // Uses Sinhala font for Pali content rendered in Sinhala script
      paragraphStyle: TextStyle(
        fontFamily: AppFonts.sinhala,
        fontFamilyFallback: AppFonts.sinhalaFallback,
        fontSize: AppFonts.baseFontSize * 1.1,
        height: AppFonts.paragraphLineHeight,
        color: bodyColor,
      ),

      // Gatha (verse): italic, left-padded
      // Uses Sinhala font with tighter line height for verse grouping
      gathaStyle: TextStyle(
        fontFamily: AppFonts.sinhala,
        fontFamilyFallback: AppFonts.sinhalaFallback,
        fontSize: AppFonts.baseFontSize * 1.1,
        fontStyle: FontStyle.italic,
        height: AppFonts.gathaLineHeight,
        color: bodyColor,
      ),

      // Unindented: same as paragraph but NO indent/padding
      // Uses Sinhala font, same line height as paragraph
      unindentedStyle: TextStyle(
        fontFamily: AppFonts.sinhala,
        fontFamilyFallback: AppFonts.sinhalaFallback,
        fontSize: AppFonts.baseFontSize * 1.1,
        height: AppFonts.paragraphLineHeight,
        color: bodyColor,
      ),
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
