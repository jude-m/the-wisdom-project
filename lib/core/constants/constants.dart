// Constants for tree navigation node keys
// These keys correspond to the node identifiers in tree.json

/// String constants for Tipitaka tree node keys used in scope filtering.
///
/// Uses descriptive names following standard Pali Tipitaka terminology.
/// These keys correspond to the node identifiers in tree.json.
class TipitakaNodeKeys {
  TipitakaNodeKeys._();

  // ============================================================================
  // PITAKA LEVEL (Three Baskets)
  // ============================================================================

  /// Vinaya Pitaka - Monastic discipline rules
  static const vinayaPitaka = 'vp';

  /// Sutta Pitaka - Discourses of the Buddha
  static const suttaPitaka = 'sp';

  /// Abhidhamma Pitaka - Higher philosophical teachings
  static const abhidhammaPitaka = 'ap';

  // ============================================================================
  // NIKAYA LEVEL (Under Sutta Pitaka)
  // ============================================================================

  /// Digha Nikaya - Long discourses
  static const dighaNikaya = 'dn';

  /// Majjhima Nikaya - Middle-length discourses
  static const majjhimaNikaya = 'mn';

  /// Samyutta Nikaya - Connected discourses
  static const samyuttaNikaya = 'sn';

  /// Anguttara Nikaya - Numerical discourses
  static const anguttaraNikaya = 'an';

  /// Khuddaka Nikaya - Minor collection
  static const khuddakaNikaya = 'kn';

  // ============================================================================
  // COMMENTARIES (Atthakatha)
  // ============================================================================

  /// Vinaya Atthakatha - Commentary on Vinaya
  static const vinayaAtthakatha = 'atta-vp';

  /// Sutta Atthakatha - Commentary on Sutta
  static const suttaAtthakatha = 'atta-sp';

  /// Abhidhamma Atthakatha - Commentary on Abhidhamma
  static const abhidhammaAtthakatha = 'atta-ap';

  // ============================================================================
  // OTHER
  // ============================================================================

  /// Treatises and other texts
  static const treatises = 'anya';

  // ============================================================================
  // CONVENIENCE SETS
  // ============================================================================

  /// All three Pitakas
  static const pitakas = {vinayaPitaka, suttaPitaka, abhidhammaPitaka};

  /// All five Nikayas (under Sutta Pitaka)
  static const nikayas = {
    dighaNikaya,
    majjhimaNikaya,
    samyuttaNikaya,
    anguttaraNikaya,
    khuddakaNikaya,
  };

  /// All commentaries
  static const commentaries = {
    vinayaAtthakatha,
    suttaAtthakatha,
    abhidhammaAtthakatha,
  };

  /// All root-level scopes (used by chips)
  static const allRoots = {
    vinayaPitaka,
    suttaPitaka,
    abhidhammaPitaka,
    vinayaAtthakatha,
    suttaAtthakatha,
    abhidhammaAtthakatha,
    treatises,
  };
}

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
}

/// Constants for dictionary bottom sheet sizing and behavior.
/// Controls the draggable sheet dimensions and snap points.
class DictionarySheetConstants {
  // Private constructor prevents instantiation
  DictionarySheetConstants._();

  // Sheet size constraints (as fractions of available height)
  // Note: Available height is 90% of screen, so 0.28 * 0.9 = ~25% of screen
  static const double initialChildSize = 0.28; // Opens at minimum height (~25% of screen)
  static const double minChildSize = 0.28; // 28% of 90% = ~25% of screen
  static const double maxChildSize = 1.0; // Full 90%

  // Maximum height as fraction of screen
  static const double maxHeightFraction = 0.9; // 90% of screen

  // Snap positions for dragging behavior
  static const List<double> snapSizes = [0.28, 0.55, 1.0];
}
