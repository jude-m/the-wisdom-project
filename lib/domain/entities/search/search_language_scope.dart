/// Which language(s) a search looks in — derived from the two toggle flags
/// (`searchInPali` / `searchInSinhala`) set by the පාළි / සිංහල control in the
/// refine dialog.
///
/// This is the **single source of truth** for "what do the two language toggles
/// mean". Every consumer reads this instead of re-deriving the pali/sinhala
/// logic itself, so the rule can't drift between them:
/// - the FTS `language` filter (data layer maps this → DB code),
/// - the title-name gating (which name fields a title search tests),
/// - the result-label display language (presentation maps this → ContentLanguage).
///
/// Note this stays a pure *domain* concept: it does NOT know the database codes
/// `'pali'` / `'sinh'` — that mapping belongs to the data layer (see
/// `TextSearchRepositoryImpl._ftsLanguageFilter`). Keeping DB codes out of here
/// is what lets the presentation layer use the same enum without learning a
/// SQLite detail.
enum SearchLanguageScope {
  /// Both toggles on (the default) — search every available language.
  both,

  /// Only Pali.
  pali,

  /// Only Sinhala.
  sinhala;

  /// Derives the scope from the two stored toggle flags.
  ///
  /// "Both off" is unreachable in practice (the SegmentedButton uses
  /// `emptySelectionAllowed: false` and the flags aren't persisted, so they
  /// default to true/true); it maps to [both] defensively — i.e. degrade to
  /// "search everything" rather than "search nothing".
  factory SearchLanguageScope.fromFlags({
    required bool searchInPali,
    required bool searchInSinhala,
  }) {
    if (searchInPali && !searchInSinhala) return SearchLanguageScope.pali;
    if (searchInSinhala && !searchInPali) return SearchLanguageScope.sinhala;
    return SearchLanguageScope.both;
  }
}
