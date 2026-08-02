/// The app's theme, as exported by `tools/dump_theme_tokens.dart`.
///
/// Mirrors: lib/core/theme/text_entry_theme.dart, app_colors.dart, app_fonts.dart
/// Any change there must be re-exported with
/// `flutter test tools/dump_theme_tokens.dart`, not hand-edited here.
///
/// The generator is Flutter-free and so cannot read `TextStyle`. Rather than
/// hand-copy the values into CSS — which rots the first time someone tweaks a
/// colour — it reads the committed JSON the app itself produced. This class is
/// only the typed view over that file; it invents nothing.
///
/// Takes an already-decoded map rather than a path, so it stays free of
/// `dart:io` and `render/` can depend on it without reaching into `data/`.
/// `bin/generate.dart` does the reading.
class ThemeTokens {
  final Map<String, dynamic> _json;

  const ThemeTokens(this._json);

  Map<String, dynamic> get _fonts => _json['fonts'] as Map<String, dynamic>;
  Map<String, dynamic> get _spacing => _json['spacing'] as Map<String, dynamic>;

  /// Light-theme colour roles: `onSurface`, `heading`, `background` …
  Map<String, String> get lightColors => {
        for (final entry
            in (_json['colors']['light'] as Map<String, dynamic>).entries)
          entry.key: entry.value as String,
      };

  /// Reader (serif) family, e.g. `NotoSerifSinhala`.
  String get readerFont => _fonts['reader'] as String;

  /// UI (sans) family.
  String get uiFont => _fonts['ui'] as String;

  List<String> get readerFallback =>
      (_fonts['readerFallback'] as List).cast<String>();

  List<String> get uiFallback => (_fonts['uiFallback'] as List).cast<String>();

  /// The app's web font scale (0.9). Applied to the root font size so every
  /// `em` below it lands on the same rendered pixel size as the app's web build.
  double get webDefaultScale => (_fonts['webDefaultScale'] as num).toDouble();

  /// A raw spacing token by name — `entryGapPx`, `gathaIndentEm`.
  ///
  /// One accessor, not an `…Em`/`…Px` pair: the unit is part of the key, and
  /// two identically-bodied getters only invited call sites to pick the wrong
  /// one and read as if a conversion had happened.
  double spacing(String key) => (_spacing[key] as num).toDouble();

  /// Style for a plain entry type (`paragraph`, `gatha`, `unindented`).
  EntryStyle entryStyle(String type) => EntryStyle._(
        (_json['entryStyles'][type] as Map<String, dynamic>),
      );

  /// Style for a levelled entry type (`heading`, `centered`), levels 1–5.
  EntryStyle levelledEntryStyle(String type, int level) => EntryStyle._(
        (_json['entryStyles'][type]['$level'] as Map<String, dynamic>),
      );

  /// A weight a *pane* applies over an entry style rather than one the entry
  /// style carries — `paliStacked`, `body`. See `_paneWeights` in the dump
  /// script for why these are the native values even though this is the web.
  int paneWeight(String key) =>
      ((_json['paneWeights'] as Map<String, dynamic>)[key] as num).toInt();
}

/// One resolved text style from the app's `TextEntryTheme`.
class EntryStyle {
  final Map<String, dynamic> _json;

  const EntryStyle._(this._json);

  /// Size as a multiple of the base — preferred over the px value so the page
  /// still scales with a reader's browser font-size preference.
  double get fontSizeEm => (_json['fontSizeEm'] as num).toDouble();

  int get fontWeight => (_json['fontWeight'] as num).toInt();

  /// `normal` or `italic`.
  String get fontStyle => _json['fontStyle'] as String;

  double get lineHeight => (_json['lineHeight'] as num).toDouble();

  /// Name of the colour role to resolve against the palette — `onSurface`,
  /// `heading`. Not a literal colour, so light and dark share this file.
  String get colorRole => _json['colorRole'] as String;
}
