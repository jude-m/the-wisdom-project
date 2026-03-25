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

  // ============================================
  // Spacing Em Multipliers
  // ============================================
  // Used by TextEntryTheme for scaled layout spacing.
  // Values originate from the Vue.js app CSS (TextEntry.vue).

  /// Paragraph first-line indent: 1.4em
  static const double paragraphIndentEm = 1.4;

  /// Gatha (verse) left padding: 2.4em
  static const double gathaIndentEm = 2.4;

  /// Gatha level-2 left padding: 5em
  static const double gathaLevel2IndentEm = 5.0;

  // ============================================
  // Font Scale
  // ============================================

  /// Default font scale for web/desktop where fonts appear larger
  /// due to display density differences (desktop monitors vs phones).
  static const double webDefaultScale = 0.85;

  /// Returns all font sizes multiplied by [scale].
  ///
  /// Used by AppTypography and TextEntryTheme factories to build
  /// scale-aware text styles. The scale factor defaults to 1.0 on
  /// native and 0.85 on web — later a user font-size preference
  /// will control this same value.
  static ScaledFontSizes scaled(double scale) => ScaledFontSizes(scale);
}

/// All AppFonts size constants multiplied by a scale factor.
/// Created via [AppFonts.scaled].
class ScaledFontSizes {
  final double scale;

  const ScaledFontSizes(this.scale);

  double get base => AppFonts.baseFontSize * scale;
  double get badge => AppFonts.badgeFontSize * scale;
  double get label => AppFonts.labelFontSize * scale;
  double get tab => AppFonts.tabFontSize * scale;
  double get tree => AppFonts.treeFontSize * scale;
  double get pageNumber => AppFonts.pageNumberFontSize * scale;
}
