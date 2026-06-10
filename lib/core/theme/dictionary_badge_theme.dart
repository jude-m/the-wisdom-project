import 'package:flutter/material.dart';

// ============================================
// Dictionary badge colours (theme-independent)
// ============================================
// One distinctive colour per dictionary, used by the badge chips in search
// results and the dictionary bottom sheet. These are a single shared palette
// across all themes (light/dark/warm) — like TextEntryTheme keeps its layout
// constants in-file, the badge colours live here rather than in app_colors.dart.
// Values match the original hard-coded Material swatch primaries (the old
// DictionaryInfo.getColor) so badges look identical to before.
const _dictDpd = Color(0xFF2196F3); // was Colors.blue
const _dictPts = Color(0xFF9C27B0); // was Colors.purple
const _dictBuddhadatta = Color(0xFF4CAF50); // BUS/BUE (was Colors.green)
const _dictSumangala = Color(0xFF009688); // MS (was Colors.teal)
const _dictVri = Color(0xFFFF9800); // was Colors.orange
const _dictCritical = Color(0xFFF44336); // CR (was Colors.red)
const _dictDpdc = Color(0xFF3F51B5); // DPDC (was Colors.indigo)
const _dictNyanatiloka = Color(0xFF795548); // ND (was Colors.brown)
const _dictProperNames = Color(0xFFFFC107); // PN (was Colors.amber)

/// Semantic colour tokens for dictionary badges, attached to [ThemeData] as a
/// [ThemeExtension].
///
/// Lives in the theme layer (not in `DictionaryInfo`, which is now a pure,
/// Flutter-free domain entity). The id → colour mapping that used to live in
/// `DictionaryInfo.getColor` now lives in [colorFor].
///
/// It is a **single shared palette** across all themes — [standard] is
/// registered identically in light/dark/warm. Access it via
/// `context.dictionaryBadgeColors` (see the extension below), which falls back
/// to [standard] if no theme registered it.
@immutable
class DictionaryBadgeColors extends ThemeExtension<DictionaryBadgeColors> {
  final Color dpd;
  final Color pts;
  final Color buddhadatta; // BUS / BUE
  final Color sumangala; // MS
  final Color vri;
  final Color critical; // CR
  final Color dpdc; // DPDC
  final Color nyanatiloka; // ND
  final Color properNames; // PN

  const DictionaryBadgeColors({
    required this.dpd,
    required this.pts,
    required this.buddhadatta,
    required this.sumangala,
    required this.vri,
    required this.critical,
    required this.dpdc,
    required this.nyanatiloka,
    required this.properNames,
  });

  /// The shared badge palette used by every theme.
  factory DictionaryBadgeColors.standard() => const DictionaryBadgeColors(
        dpd: _dictDpd,
        pts: _dictPts,
        buddhadatta: _dictBuddhadatta,
        sumangala: _dictSumangala,
        vri: _dictVri,
        critical: _dictCritical,
        dpdc: _dictDpdc,
        nyanatiloka: _dictNyanatiloka,
        properNames: _dictProperNames,
      );

  /// Maps a dictionary id to its badge colour. [fallback] (the caller's
  /// theme-aware default, e.g. `colorScheme.primary`) is returned for any
  /// unknown id — mirroring the old `DictionaryInfo.getColor` fallback.
  Color colorFor(String dictId, Color fallback) => switch (dictId) {
        'DPD' => dpd,
        'PTS' => pts,
        'BUS' || 'BUE' => buddhadatta,
        'MS' => sumangala,
        'VRI' => vri,
        'CR' => critical,
        'DPDC' => dpdc,
        'ND' => nyanatiloka,
        'PN' => properNames,
        _ => fallback,
      };

  @override
  DictionaryBadgeColors copyWith({
    Color? dpd,
    Color? pts,
    Color? buddhadatta,
    Color? sumangala,
    Color? vri,
    Color? critical,
    Color? dpdc,
    Color? nyanatiloka,
    Color? properNames,
  }) =>
      DictionaryBadgeColors(
        dpd: dpd ?? this.dpd,
        pts: pts ?? this.pts,
        buddhadatta: buddhadatta ?? this.buddhadatta,
        sumangala: sumangala ?? this.sumangala,
        vri: vri ?? this.vri,
        critical: critical ?? this.critical,
        dpdc: dpdc ?? this.dpdc,
        nyanatiloka: nyanatiloka ?? this.nyanatiloka,
        properNames: properNames ?? this.properNames,
      );

  @override
  DictionaryBadgeColors lerp(
    covariant ThemeExtension<DictionaryBadgeColors>? other,
    double t,
  ) {
    if (other is! DictionaryBadgeColors) return this;
    return DictionaryBadgeColors(
      dpd: Color.lerp(dpd, other.dpd, t)!,
      pts: Color.lerp(pts, other.pts, t)!,
      buddhadatta: Color.lerp(buddhadatta, other.buddhadatta, t)!,
      sumangala: Color.lerp(sumangala, other.sumangala, t)!,
      vri: Color.lerp(vri, other.vri, t)!,
      critical: Color.lerp(critical, other.critical, t)!,
      dpdc: Color.lerp(dpdc, other.dpdc, t)!,
      nyanatiloka: Color.lerp(nyanatiloka, other.nyanatiloka, t)!,
      properNames: Color.lerp(properNames, other.properNames, t)!,
    );
  }
}

/// Easy access to the dictionary badge palette from a [BuildContext], with a
/// built-in fallback to [DictionaryBadgeColors.standard] (mirrors
/// `TextEntryThemeExtension`). Never returns null.
extension DictionaryBadgeThemeExtension on BuildContext {
  DictionaryBadgeColors get dictionaryBadgeColors =>
      Theme.of(this).extension<DictionaryBadgeColors>() ??
      DictionaryBadgeColors.standard();
}
