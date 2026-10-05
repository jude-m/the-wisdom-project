/// Every ARB key the site reads. All are checked when the ARB is loaded, so a
/// bad one stops the build before `build/` is cleared, not halfway through it.
const List<String> appStringKeys = [
  'layoutPaliOnly',
  'layoutSinhalaOnly',
  'layoutSideBySide',
  'layoutStacked',
  'paliLanguageLabel',
  'sinhalaLanguageLabel',
  'searchPlaceholder',
  'searchHint',
  'noResultsFound',
  'close',
  'loading',
  'errorLoadingSearch',
  'statusSelectSuttaToRead',
  'statusNoTreeContent',
  'navHome',
  'readInApp',
  'moreOptions',
];

/// The app's Sinhala UI strings, looked up by ARB key.
///
/// Source: lib/core/localization/l10n/app_si.arb
/// The site says what the app says, so it reads the app's file rather than
/// keeping copies. A pure view over the decoded map, like `ThemeTokens`;
/// `bin/generate.dart` does the reading.
class AppStrings {
  final Map<String, dynamic> _arb;

  /// Stops the build if any of [appStringKeys] is missing or has a
  /// `{placeholder}` — the app fills those at runtime, the site cannot.
  AppStrings(this._arb) {
    for (final key in appStringKeys) {
      final value = _arb[key];
      if (value is! String) {
        throw StateError('app_si.arb has no string "$key".');
      }
      if (value.contains('{')) {
        throw StateError('app_si.arb "$key" has a placeholder the site cannot '
            'fill: "$value".');
      }
    }
  }

  /// The value under [key], unescaped. For HTML use `.html(key)` instead.
  String operator [](String key) {
    if (!appStringKeys.contains(key)) {
      throw StateError('"$key" is not in appStringKeys.');
    }
    return _arb[key] as String;
  }
}
