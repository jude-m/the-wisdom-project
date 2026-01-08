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
  static const double searchDefault = 400.0;
  static const double searchMin = 300.0;
  static const double searchMaxAbsolute = 600.0;

  // Minimum reader content width to preserve
  static const double minReaderWidth = 400.0;

  // Resizable divider
  static const double dividerWidth = 8.0;
}
