/// Centralized font configuration for The Wisdom Project
///
/// This file contains all font-related constants used throughout the app.
/// Font families must match the names declared in pubspec.yaml.
abstract class AppFonts {
  // ============================================
  // Font Family Names (must match pubspec.yaml)
  // ============================================

  /// Serif font for Sinhala script content (Pali text)
  /// Better conjunct consonant rendering with ZWJ
  static const String sinhala = 'NotoSerifSinhala';

  /// Sans-serif font for Sinhala UI elements (buttons, labels, etc.)
  static const String sinhalaUi = 'NotoSansSinhala';

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
  // Line Heights (UI only)
  // ============================================
  // Note: Content-specific line heights (paragraph, gatha, heading)
  // are defined in TextEntryTheme for better separation of concerns.

  /// Line height for UI elements (buttons, labels, badges)
  /// Standard tight spacing for interface text
  static const double uiLineHeight = 1.4;

  // ============================================
  // Base Sizes
  // ============================================

  /// Base font size used for scaling calculations
  /// All other sizes are multipliers of this value
  static const double baseFontSize = 16.0;

  // ============================================
  // UI Font Sizes
  // ============================================

  /// Font size for small badges and edition IDs (BJT, SC)
  static const double badgeFontSize = 11.0;

  /// Font size for small labels and chip text
  static const double labelFontSize = 12.0;

  /// Font size for tabs and secondary UI elements
  static const double tabFontSize = 13.0;

  /// Font size for tree nodes and primary UI text
  static const double treeFontSize = 14.0;

  /// Font size for page numbers and counts
  static const double pageNumberFontSize = 12.0;
}
