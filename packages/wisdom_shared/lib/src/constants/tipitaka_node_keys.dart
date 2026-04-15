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

  /// Prefix shared by all commentary (atthakatha) node keys
  static const commentary = 'atta-';

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
