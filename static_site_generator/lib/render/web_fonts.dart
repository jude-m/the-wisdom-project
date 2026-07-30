import '../domain/theme_tokens.dart';

/// One WOFF2 face the site ships.
class WebFontFace {
  /// CSS `font-family` name — matches the app's family, so a rule written
  /// against one surface means the same thing on the other.
  final String family;

  /// Path under `assets/fonts/`, which is also its path under the site's
  /// `fonts/`. The copier and the `@font-face` `src` read the same string.
  final String relativePath;

  final int weight;

  const WebFontFace({
    required this.family,
    required this.relativePath,
    required this.weight,
  });
}

/// Every face the stylesheet declares — and therefore every face worth copying
/// into the build.
///
/// The single source of truth for both. `_writeFontFaces` used to hold this
/// mapping while `_copyFonts` globbed for `*-Subset.woff2`, which shipped the
/// 9 Latin-only faces (`noto-sans/`, `noto-serif/`) that no rule ever names.
/// They are in `assets/fonts/` for the Flutter app, which bundles them for UI
/// chrome the static site does not have.
List<WebFontFace> webFontFaces(ThemeTokens tokens) {
  const weights = {
    'Regular': 400,
    'Medium': 500,
    'SemiBold': 600,
    'Bold': 700,
  };
  // A list of pairs rather than a map keyed by family name: the two names come
  // from the theme, and if it ever pointed both at one family a map would
  // collapse to a single entry and quietly ship 4 faces instead of 8 — a
  // failure that surfaces as unstyled text, not as an error.
  final families = <(String family, String path)>[
    (tokens.readerFont, 'noto-serif-sinhala/NotoSerifSinhala'),
    (tokens.uiFont, 'noto-sans-sinhala/NotoSansSinhala'),
  ];

  return [
    for (final (family, path) in families)
      for (final weight in weights.entries)
        WebFontFace(
          family: family,
          relativePath: '$path-${weight.key}-Subset.woff2',
          weight: weight.value,
        ),
  ];
}

/// Families the app bundles but the site does not self-host.
///
/// They appear in the theme's fallback lists because Flutter resolves them from
/// the app bundle. A browser cannot: with no `@font-face` behind it the name
/// matches nothing installed, so `NotoSans` in a CSS stack is a silent no-op
/// that only makes the stack longer. Filtered out of the emitted stacks rather
/// than shipped, because the two Sinhala faces already cover the script and
/// these two are Latin-only.
const Set<String> appOnlyFallbackFamilies = {'NotoSans', 'NotoSerif'};
