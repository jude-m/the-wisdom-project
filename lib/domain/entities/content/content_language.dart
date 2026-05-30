/// A language a text/label can be **displayed** in across the app's data
/// surfaces (navigation tree, breadcrumbs, search results, dialogs, tabs) —
/// the "Content Language".
///
/// This is distinct from the UI/chrome language (`AppLanguage`) and from the
/// Pali *script* (a future, separate axis). The set of values actually offered
/// to the user is **edition-driven**: it comes from `Edition.availableLanguages`
/// (see `availableContentLanguagesProvider`).
///
/// Replaces the former `NavigationLanguage` enum, broadened from "navigation
/// only" to "all data labels".
enum ContentLanguage {
  /// Pali text. For BJT this is the Pali term written in Sinhala script
  /// (e.g. දීඝනිකාය = Dīghanikāya).
  pali,

  /// Sinhala translation (e.g. දික් සඟිය = "the long collection").
  sinhala;

  /// ISO 639-1 code — used to match against `Edition.availableLanguages`.
  String get isoCode => switch (this) {
        ContentLanguage.pali => 'pi',
        ContentLanguage.sinhala => 'si',
      };

  /// Maps an ISO 639-1 code to a [ContentLanguage], or null if unsupported.
  static ContentLanguage? fromIso(String code) => switch (code) {
        'pi' => ContentLanguage.pali,
        'si' => ContentLanguage.sinhala,
        _ => null,
      };
}
