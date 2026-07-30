import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_wisdom_project/core/theme/app_colors.dart';
import 'package:the_wisdom_project/core/theme/app_fonts.dart';
import 'package:the_wisdom_project/core/theme/text_entry_theme.dart';

/// Exports the app's theme into `static_site_generator/assets/theme_tokens.json`.
///
///     flutter test tools/dump_theme_tokens.dart
///
/// **This is a code generator, not a test.** It lives under `tools/` precisely
/// so `flutter test` (which only scans `test/`) never runs it by accident. The
/// `flutter test` harness is just the cheapest way to execute code that touches
/// `Color` and `TextStyle` headlessly — those need a bound `dart:ui`, which a
/// plain `dart run` does not provide.
///
/// ## Why generate instead of hand-copying
///
/// The static site must look identical to the app, but the generator is
/// Flutter-free and so cannot import `TextEntryTheme` at build time. The only
/// two options are to copy the values into CSS by hand — which silently rots
/// the first time someone tweaks a colour — or to emit them from the real
/// theme objects and commit the result. This is the second. Drift becomes
/// impossible by construction rather than by discipline: change the theme,
/// re-run this, and the diff shows up in review.
///
/// ## Determinism
///
/// The output carries **no timestamp**. Cloudflare Pages deduplicates uploads
/// by content hash, so a build-stamped token file would re-hash every page that
/// embeds it and re-upload all 16,356 files on every deploy (build plan §11.8).
void main() {
  test('dump theme tokens', () {
    // Light only. Dark ships later (D3 — "light theme with provision for
    // dark"), but its palette is emitted now so the CSS can carry a
    // prefers-color-scheme block without a second round-trip through here.
    final tokens = <String, dynamic>{
      'meta': _meta,
      'fonts': _fonts,
      'colors': {
        'light': _lightColors,
        'dark': _darkColors,
      },
      'entryStyles': _entryStyles(),
      'spacing': _spacing(),
    };

    const encoder = JsonEncoder.withIndent('  ');
    final file = File('static_site_generator/assets/theme_tokens.json');
    file.parent.createSync(recursive: true);
    // Trailing newline so the file is POSIX-clean and diffs stay one-line.
    file.writeAsStringSync('${encoder.convert(tokens)}\n');

    // ignore: avoid_print
    print('Wrote ${file.path}');
  });
}

/// Provenance, in the same spirit as the `dc.source` meta tag every generated
/// HTML page carries (D8) — the file says what produced it and from what.
const Map<String, dynamic> _meta = {
  'generator': 'tools/dump_theme_tokens.dart',
  'note': 'GENERATED — do not edit by hand. Re-run: '
      'flutter test tools/dump_theme_tokens.dart',
  'sources': [
    'lib/core/theme/app_colors.dart',
    'lib/core/theme/app_fonts.dart',
    'lib/core/theme/text_entry_theme.dart',
  ],
};

/// `Color` → `#rrggbb`, or `#rrggbbaa` when not fully opaque.
///
/// CSS hex is the target, so alpha goes last — the opposite of Flutter's ARGB.
String _hex(Color color) {
  final argb = color.toARGB32();
  final rgb = (argb & 0x00FFFFFF).toRadixString(16).padLeft(6, '0');
  final alpha = (argb >> 24) & 0xFF;
  return alpha == 0xFF
      ? '#$rgb'
      : '#$rgb${alpha.toRadixString(16).padLeft(2, '0')}';
}

/// Font families and stacks, ready to drop into a CSS `font-family`.
Map<String, dynamic> get _fonts => {
      'reader': AppFonts.reader,
      'ui': AppFonts.ui,
      'readerFallback': AppFonts.readerFallback,
      'uiFallback': AppFonts.uiFallback,
      'baseFontSize': AppFonts.baseFontSize,
      // The site is a web surface, so it inherits the web default rather than
      // the native 1.0 — see AppFonts.webDefaultScale.
      'webDefaultScale': AppFonts.webDefaultScale,
      'uiLineHeight': AppFonts.uiLineHeight,
      'uiSizes': {
        'badge': AppFonts.badgeFontSize,
        'label': AppFonts.labelFontSize,
        'tab': AppFonts.tabFontSize,
        'tree': AppFonts.treeFontSize,
        'pageNumber': AppFonts.pageNumberFontSize,
      },
    };

Map<String, String> get _lightColors => {
      'background': _hex(LightThemeColors.background),
      'surface': _hex(LightThemeColors.surface),
      'onSurface': _hex(LightThemeColors.onSurface),
      'onSurfaceVariant': _hex(LightThemeColors.onSurfaceVariant),
      'surfaceContainerLowest': _hex(LightThemeColors.surfaceContainerLowest),
      'surfaceContainerLow': _hex(LightThemeColors.surfaceContainerLow),
      'surfaceContainer': _hex(LightThemeColors.surfaceContainer),
      'surfaceContainerHigh': _hex(LightThemeColors.surfaceContainerHigh),
      'surfaceContainerHighest': _hex(LightThemeColors.surfaceContainerHighest),
      'surfaceDim': _hex(LightThemeColors.surfaceDim),
      'surfaceBright': _hex(LightThemeColors.surfaceBright),
      'primary': _hex(LightThemeColors.primary),
      'onPrimary': _hex(LightThemeColors.onPrimary),
      'primaryContainer': _hex(LightThemeColors.primaryContainer),
      'onPrimaryContainer': _hex(LightThemeColors.onPrimaryContainer),
      'secondary': _hex(LightThemeColors.secondary),
      'secondaryContainer': _hex(LightThemeColors.secondaryContainer),
      'onSecondaryContainer': _hex(LightThemeColors.onSecondaryContainer),
      'tertiary': _hex(LightThemeColors.tertiary),
      'tertiaryContainer': _hex(LightThemeColors.tertiaryContainer),
      'outline': _hex(LightThemeColors.outline),
      'outlineVariant': _hex(LightThemeColors.outlineVariant),
      'error': _hex(LightThemeColors.error),
      // Reader-specific roles — the two the content stylesheet leans on most.
      'heading': _hex(LightThemeColors.heading),
      'highlight': _hex(LightThemeColors.highlight),
    };

/// Emitted for the deferred dark mode. `DarkThemeColors` deliberately exposes a
/// smaller, differently-named set than the light palette, so this is not a
/// mirror of [_lightColors] and the CSS cannot assume role-for-role parity.
Map<String, String> get _darkColors => {
      'background': _hex(DarkThemeColors.background),
      'surface': _hex(DarkThemeColors.surface),
      'surfaceContainerLow': _hex(DarkThemeColors.surfaceContainerLow),
      'surfaceContainerHigh': _hex(DarkThemeColors.surfaceContainerHigh),
      'primary': _hex(DarkThemeColors.primary),
      'onPrimary': _hex(DarkThemeColors.onPrimary),
      'onBackground': _hex(DarkThemeColors.onBackground),
      'muted': _hex(DarkThemeColors.muted),
      'accent': _hex(DarkThemeColors.accent),
      'divider': _hex(DarkThemeColors.divider),
      'error': _hex(DarkThemeColors.error),
    };

/// The five corpus entry types plus the levelled heading/centered variants,
/// exactly as `TextEntryTheme` styles them.
///
/// Built at `fontScale: 1.0` and with placeholder colours: the generator
/// re-derives sizes in `em` against `fonts.baseFontSize`, and takes colours
/// from the `colors` block by role. Baking a scale in here would make the CSS
/// unable to honour a reader font-size preference.
Map<String, dynamic> _entryStyles() {
  final theme = TextEntryTheme.standard(
    headingColor: LightThemeColors.heading,
    bodyColor: LightThemeColors.onSurface,
  );

  /// [name] is only ever used to name the offender if a style is missing its
  /// size — a bare null-check error here would say nothing about *which* of the
  /// sixteen styles broke.
  Map<String, dynamic> style(TextStyle s, String colorRole, String name) {
    final size = s.fontSize;
    if (size == null) {
      throw StateError(
        'TextEntryTheme style "$name" has no fontSize. The CSS derives every '
        'size as a multiple of AppFonts.baseFontSize, so it cannot be omitted.',
      );
    }
    final height = s.height;
    return {
      'fontFamily': s.fontFamily,
      // Every double goes through _round, not just fontSizeEm: these come
      // straight off the theme, and one arithmetic expression there (16 * 1.1)
      // would put 17.600000000000001 in the file and re-hash all 16,356 pages.
      'fontSize': _round(size),
      // The multiple of baseFontSize — what actually becomes `em` in CSS.
      'fontSizeEm': _round(size / AppFonts.baseFontSize),
      'fontWeight': s.fontWeight?.value,
      'fontStyle': s.fontStyle == FontStyle.italic ? 'italic' : 'normal',
      'lineHeight': height == null ? null : _round(height),
      'colorRole': colorRole,
    };
  }

  return {
    'paragraph': style(theme.paragraphStyle, 'onSurface', 'paragraphStyle'),
    'gatha': style(theme.gathaStyle, 'onSurface', 'gathaStyle'),
    'unindented': style(theme.unindentedStyle, 'onSurface', 'unindentedStyle'),
    'heading': {
      for (final entry in theme.headingStyles.entries)
        entry.key.toString():
            style(entry.value, 'heading', 'headingStyles[${entry.key}]'),
    },
    'centered': {
      for (final entry in theme.centeredStyles.entries)
        entry.key.toString():
            style(entry.value, 'onSurface', 'centeredStyles[${entry.key}]'),
    },
  };
}

/// Layout indents, in `em` — the unit the CSS wants, and the unit the values
/// were authored in before `TextEntryTheme` multiplied them by the base size.
Map<String, dynamic> _spacing() => {
      'paragraphIndentEm': AppFonts.paragraphIndentEm,
      'gathaIndentEm': AppFonts.gathaIndentEm,
      'gathaLevel2IndentEm': AppFonts.gathaLevel2IndentEm,
      // The reader's vertical rhythm, read from the same constants the panes
      // lay out with — never re-typed here. `AppFonts.pageNumberGapPx` is
      // deliberately absent: it spaces a page-number chip the static site does
      // not render, and an exported token with no consumer only invites one.
      'entryGapPx': AppFonts.entryGapPx,
      'pageGapPx': AppFonts.pageGapPx,
    };

/// Trims binary floating-point noise (1.0999999999999999 → 1.1) so re-running
/// the dump on an unchanged theme produces a byte-identical file.
double _round(double value) => double.parse(value.toStringAsFixed(6));
