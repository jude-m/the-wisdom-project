import 'package:flutter/widgets.dart' show Locale;

/// The user's preferred **UI language** (pure localization — "App Language").
///
/// This drives `MaterialApp.locale` and the generated `AppLocalizations`. It is
/// completely independent of `ContentLanguage` (which text/translation is shown
/// for data labels) and of the Pali *script* axis (a future, separate concept).
enum AppLanguage {
  english,
  sinhala;

  /// The Flutter [Locale] this maps to.
  /// Must stay in sync with `MaterialApp.supportedLocales`.
  Locale get locale => switch (this) {
        AppLanguage.english => const Locale('en'),
        AppLanguage.sinhala => const Locale('si'),
      };

  /// Resolves a device's *ordered* preferred locales to a supported
  /// [AppLanguage]. Mirrors how Flutter itself picks from
  /// `platformDispatcher.locales`: walk the list and take the first locale we
  /// support (the user's ranking is respected). Falls back to English when
  /// none match or the list is empty.
  ///
  /// Why a list and not just the primary: a device set to e.g.
  /// `[ta, si, en]` has Tamil first (which we don't support) but Sinhala
  /// second — the user clearly prefers Sinhala over English, so we honour that
  /// instead of defaulting to English off the primary locale alone.
  static AppLanguage fromLocales(Iterable<Locale> locales) {
    for (final locale in locales) {
      switch (locale.languageCode) {
        case 'si':
          return AppLanguage.sinhala;
        case 'en':
          return AppLanguage.english;
      }
    }
    return AppLanguage.english;
  }

  /// Parses a persisted value (the enum [name]). Returns null when absent or
  /// unrecognised — callers then fall back to the device locale.
  /// `asNameMap()[value]` returns null for both a null and an unknown key.
  static AppLanguage? fromStorage(String? value) =>
      AppLanguage.values.asNameMap()[value];
}
