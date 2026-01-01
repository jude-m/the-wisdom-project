// Constants for tree navigation node keys
// These keys correspond to the node identifiers in tree.json

/// The Sutta Pitaka (සූත්‍ර පිටකය) node key - expanded by default on app load
const String kSuttaPitakaNodeKey = 'sp';

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
