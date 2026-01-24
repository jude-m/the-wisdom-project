/// Centralized font configuration for The Wisdom Project
///
/// This file contains all font-related constants used throughout the app.
/// Font families must match the names declared in pubspec.yaml.
///
/// The font system separates:
/// - **Reader fonts** (serif): For reading content (Pali text, paragraphs)
/// - **UI fonts** (sans-serif): For interface elements (buttons, labels, nav)
abstract class AppFonts {
  // ============================================
  // Font Family Names (must match pubspec.yaml)
  // ============================================

  // --- Reader Fonts (serif - for reading content) ---

  /// Serif font for Sinhala script content (Pali text)
  /// Better conjunct consonant rendering with ZWJ
  static const String readerSinhala = 'NotoSerifSinhala';

  /// Serif font for romanized Pali with diacritics and English prose
  static const String readerEnglish = 'NotoSerif';

  // --- UI Fonts (sans-serif - for interface elements) ---

  /// Sans-serif font for Sinhala UI elements (buttons, labels, etc.)
  static const String uiSinhala = 'NotoSansSinhala';

  /// Sans-serif font for English UI elements
  static const String uiEnglish = 'NotoSans';

  // --- Current App Fonts (easy to switch for locale later) ---

  /// Current reader font - used for text content display
  /// Change this to `readerEnglish` for English locale
  static const String reader = readerSinhala;

  /// Current UI font - used for buttons, labels, navigation
  /// Change this to `uiEnglish` for English locale
  static const String ui = uiSinhala;

  // ============================================
  // Fallback Font Stacks
  // ============================================

  /// Fallback fonts for reader content (serif-based)
  /// Georgia has good diacritics support for romanized Pali
  static const List<String> readerFallback = [
    'NotoSans', // Noto design language consistency
    'Georgia', // Good diacritics
    'Iskoola Pota', // Windows Sinhala fallback
    'serif',
  ];

  /// Fallback fonts for UI elements (sans-serif based)
  /// Prioritizes clean, readable interface fonts
  static const List<String> uiFallback = [
    'NotoSans',
    'Iskoola Pota',
    'Roboto',
    'system-ui',
    'sans-serif',
  ];

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
