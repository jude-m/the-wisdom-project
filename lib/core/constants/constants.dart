// TipitakaNodeKeys now lives in the shared package (wisdom_shared).
// Re-exported here so all existing imports continue to work.
export 'package:wisdom_shared/wisdom_shared.dart' show TipitakaNodeKeys;

/// Constants for pane width constraints used in the reader layout.
/// These control the resizable navigator sidebar and search panel.
class PaneWidthConstants {
  // Private constructor prevents instantiation
  PaneWidthConstants._();

  // Navigator (left sidebar)
  static const double navigatorDefault = 350.0;
  static const double navigatorMin = 200.0;
  static const double navigatorMax = 500.0;

  // Search panel (right overlay)
  static const double searchDefault = 450.0;
  static const double searchMin = 300.0;
  static const double searchMaxAbsolute = 650.0;

  // Minimum reader content width to preserve
  static const double minReaderWidth = 400.0;

  // Resizable divider
  static const double dividerWidth = 8.0;

  // Dictionary bottom sheet (for tablets/desktops)
  static const double dictionarySheetMaxWidth = 800.0;

  // Reader split pane (for "both" column mode)
  // Ratio-based (0.0-1.0) for automatic adaptation to window resizing
  static const double readerSplitDefault = 0.5; // 50/50 ratio
  static const double readerSplitMin = 0.25; // Min 25% for left pane
  static const double readerSplitMax = 0.75; // Max 75% for left pane

  // Reader content padding (used for scroll area and divider overlay alignment)
  static const double readerContentPadding = 24.0;

  // Height reserved for the floating action button group at the top of the reader.
  // Used as a spacer in the ListView so content doesn't hide behind it.
  static const double readerActionButtonGroupHeight = 44.0;
}

/// Sizing for the dictionary bottom sheet. Uses adaptive fractions so the
/// collapsed sheet stays ~250px tall on phones (matching tipitaka.lk) while
/// preserving the ~28% feel on larger screens.
class DictionarySheetConstants {
  DictionarySheetConstants._();

  static const double minPixelHeight = 250.0;
  static const double minFractionFloor = 0.28;
  static const double minFractionCeiling = 0.5;
  static const double maxChildSize = 1.0;
  static const double maxHeightFraction = 0.9;

  /// Returns snap fractions sized to [availableHeight] (the pixel height
  /// the sheet has to work with, typically from a `LayoutBuilder`).
  static ({double min, double mid, double max}) adaptiveSnaps(
    double availableHeight,
  ) {
    final min = (minPixelHeight / availableHeight)
        .clamp(minFractionFloor, minFractionCeiling);
    final mid = ((min + maxChildSize) / 2).clamp(0.55, 0.8);
    return (min: min, mid: mid, max: maxChildSize);
  }
}
