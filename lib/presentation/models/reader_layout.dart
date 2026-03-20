/// Represents the layout mode for the bilingual reader
///
/// TODO: Persist user's layout preference (SharedPreferences or similar)
enum ReaderLayout {
  /// Display only Pali content in a single column
  paliOnly,

  /// Display only Sinhala content in a single column
  sinhalaOnly,

  /// Display both Pali and Sinhala content side by side (horizontal)
  sideBySide,

  /// Display Pali and Sinhala content stacked vertically
  /// (Pali paragraph followed by its Sinhala translation, repeating)
  stacked,
}
