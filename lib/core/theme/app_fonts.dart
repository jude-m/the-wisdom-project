/// Centralized font configuration for The Wisdom Project
///
/// This file contains all font-related constants used throughout the app.
/// Font families must match the names declared in pubspec.yaml.
abstract class AppFonts {
  // ============================================
  // Font Family Names (must match pubspec.yaml)
  // ============================================

  /// Primary font for Sinhala script (used for both content and UI)
  /// Handles Pali text rendered in Sinhala script
  static const String sinhala = 'NotoSansSinhala';

  /// Serif font for romanized Pali with diacritics and English prose
  static const String serif = 'NotoSerif';

  // ============================================
  // Fallback Font Stacks
  // ============================================

  /// Fallback fonts for Sinhala content and UI
  /// NotoSans provides Latin characters with matching Noto design language
  /// Iskoola Pota is Windows default Sinhala font
  static const List<String> sinhalaFallback = [
    'NotoSans',
    'Iskoola Pota',
    'Roboto',
    'system-ui',
    'sans-serif',
  ];

  /// Fallback fonts for serif content
  /// Georgia has good diacritics support
  static const List<String> serifFallback = ['Georgia', 'serif'];

  // ============================================
  // Line Heights
  // ============================================

  /// Line height for paragraph text (body content)
  /// Optimized for Sinhala readability - slightly generous spacing
  static const double paragraphLineHeight = 1.5;

  /// Line height for gatha (verse) entries
  /// Tighter than paragraphs to visually group verse lines
  static const double gathaLineHeight = 1.4;

  /// Line height for headings
  /// Tight spacing for visual hierarchy
  static const double headingLineHeight = 1.2;

  /// Line height for UI elements (buttons, labels)
  /// Standard tight spacing for interface text
  static const double uiLineHeight = 1.4;

  // ============================================
  // Base Sizes
  // ============================================

  /// Base font size used for scaling calculations
  /// All other sizes are multipliers of this value
  static const double baseFontSize = 16.0;
}
