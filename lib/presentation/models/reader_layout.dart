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
  stacked;

  /// Short label for compact UI controls (e.g. floating pills).
  /// Displayed as text for [paliOnly] and [sinhalaOnly]; [sideBySide] and
  /// [stacked] use icons instead but labels are kept for completeness.
  String get shortLabel => switch (this) {
        ReaderLayout.paliOnly => 'P',
        ReaderLayout.sideBySide => 'P|S',
        ReaderLayout.stacked => 'P/S',
        ReaderLayout.sinhalaOnly => 'S',
      };
}
