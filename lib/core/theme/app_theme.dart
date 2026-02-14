import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_fonts.dart';
import 'app_typography.dart';
import 'text_entry_theme.dart';

/// Application theme builder
/// Combines color palettes with typography to create complete Material 3 themes
class AppTheme {
  /// Light theme - Warm cream background with dark brown text
  /// Best for daytime reading, default theme
  static ThemeData light() {
    // Create ColorScheme once and reuse
    final colorScheme = ColorScheme.light(
      primary: LightThemeColors.primary,
      onPrimary: LightThemeColors.onPrimary,
      primaryContainer: LightThemeColors.accent.withValues(alpha: 0.2),
      onPrimaryContainer: LightThemeColors.primary,
      secondary: LightThemeColors.accent,
      onSecondary: LightThemeColors.onPrimary,
      tertiary: LightThemeColors.secondaryAccent,
      surface: LightThemeColors.surface,
      onSurface: LightThemeColors.onBackground,
      onSurfaceVariant: LightThemeColors.onBackground.withValues(alpha: 0.7),
      // Surface Container hierarchy (Flutter 3.22+)
      surfaceContainerLowest: LightThemeColors.surfaceContainerLowest,
      surfaceContainerLow: LightThemeColors.surfaceContainerLow,
      surfaceContainer: LightThemeColors.surface,
      surfaceContainerHigh: LightThemeColors.surfaceContainerHigh,
      surfaceContainerHighest: LightThemeColors.surfaceContainerHighest,
      // Utility
      error: LightThemeColors.error,
      onError: LightThemeColors.onError,
      outline: LightThemeColors.divider,
      outlineVariant: LightThemeColors.divider.withValues(alpha: 0.5),
      // Selection colors
      secondaryContainer: LightThemeColors.secondaryContainer,
      onSecondaryContainer: LightThemeColors.onSecondaryContainer,
      tertiaryContainer: LightThemeColors.tertiaryContainer,
      onTertiaryContainer: LightThemeColors.onTertiaryContainer,
    );

    return ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      // Global UI font (sans-serif) - reader content uses serif via TextEntryTheme
      fontFamily: AppFonts.ui,
      fontFamilyFallback: AppFonts.uiFallback,

      // Background colors
      scaffoldBackgroundColor: LightThemeColors.background,
      cardColor: LightThemeColors.surface,
      dividerColor: LightThemeColors.divider,

      colorScheme: colorScheme,

      // Typography extensions
      extensions: [
        TextEntryTheme.standard(
          headingColor: LightThemeColors.primary,
          bodyColor: LightThemeColors.onBackground,
        ),
        AppTypography.fromColorScheme(colorScheme),
      ],
    );
  }

  /// Dark theme - High contrast black with white text
  /// WCAG AAA compliant for accessibility, night reading
  static ThemeData dark() {
    // Create ColorScheme once and reuse
    final colorScheme = ColorScheme.dark(
      primary: DarkThemeColors.primary,
      onPrimary: DarkThemeColors.onPrimary,
      primaryContainer: DarkThemeColors.accent.withValues(alpha: 0.2),
      onPrimaryContainer: DarkThemeColors.primary,
      secondary: DarkThemeColors.accent,
      onSecondary: DarkThemeColors.onPrimary,
      tertiary: DarkThemeColors.secondaryAccent,
      surface: DarkThemeColors.surface,
      onSurface: DarkThemeColors.onBackground,
      onSurfaceVariant: DarkThemeColors.onBackground.withValues(alpha: 0.7),
      // Surface Container hierarchy (Flutter 3.22+)
      surfaceContainerLowest: DarkThemeColors.surfaceContainerLowest,
      surfaceContainerLow: DarkThemeColors.surfaceContainerLow,
      surfaceContainer: DarkThemeColors.surface,
      surfaceContainerHigh: DarkThemeColors.surfaceContainerHigh,
      surfaceContainerHighest: DarkThemeColors.surfaceContainerHighest,
      // Utility
      error: DarkThemeColors.error,
      onError: DarkThemeColors.onError,
      outline: DarkThemeColors.divider,
      outlineVariant: DarkThemeColors.divider.withValues(alpha: 0.5),
      // Search highlight
      tertiaryContainer: DarkThemeColors.tertiaryContainer,
      onTertiaryContainer: DarkThemeColors.onTertiaryContainer,
    );

    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      // Global UI font (sans-serif) - reader content uses serif via TextEntryTheme
      fontFamily: AppFonts.ui,
      fontFamilyFallback: AppFonts.uiFallback,

      // Background colors
      scaffoldBackgroundColor: DarkThemeColors.background,
      cardColor: DarkThemeColors.surface,
      dividerColor: DarkThemeColors.divider,

      colorScheme: colorScheme,

      // Typography extensions
      extensions: [
        TextEntryTheme.standard(
          headingColor: DarkThemeColors.primary,
          bodyColor: DarkThemeColors.onBackground,
        ),
        AppTypography.fromColorScheme(colorScheme),
      ],
    );
  }

  /// Warm theme - Earthy dark browns with warm text
  /// Signature Buddhist aesthetic, evening reading
  static ThemeData warm() {
    // Create ColorScheme once and reuse
    final colorScheme = ColorScheme.dark(
      primary: WarmThemeColors.primary,
      onPrimary: WarmThemeColors.onPrimary,
      primaryContainer: WarmThemeColors.accent.withValues(alpha: 0.25),
      onPrimaryContainer: WarmThemeColors.primary,
      secondary: WarmThemeColors.accent,
      onSecondary: WarmThemeColors.onPrimary,
      tertiary: WarmThemeColors.secondaryAccent,
      surface: WarmThemeColors.surface,
      onSurface: WarmThemeColors.onBackground,
      onSurfaceVariant: WarmThemeColors.onBackground.withValues(alpha: 0.7),
      // Surface Container hierarchy (Flutter 3.22+)
      surfaceContainerLowest: WarmThemeColors.surfaceContainerLowest,
      surfaceContainerLow: WarmThemeColors.surfaceContainerLow,
      surfaceContainer: WarmThemeColors.surface,
      surfaceContainerHigh: WarmThemeColors.surfaceContainerHigh,
      surfaceContainerHighest: WarmThemeColors.surfaceContainerHighest,
      // Utility
      error: WarmThemeColors.error,
      onError: WarmThemeColors.onError,
      outline: WarmThemeColors.divider,
      outlineVariant: WarmThemeColors.divider.withValues(alpha: 0.5),
      // Search highlight
      tertiaryContainer: WarmThemeColors.tertiaryContainer,
      onTertiaryContainer: WarmThemeColors.onTertiaryContainer,
    );

    return ThemeData(
      brightness: Brightness.dark, // Warm is a dark theme variant
      useMaterial3: true,
      // Global UI font (sans-serif) - reader content uses serif via TextEntryTheme
      fontFamily: AppFonts.ui,
      fontFamilyFallback: AppFonts.uiFallback,

      // Background colors
      scaffoldBackgroundColor: WarmThemeColors.background,
      cardColor: WarmThemeColors.surface,
      dividerColor: WarmThemeColors.divider,

      colorScheme: colorScheme,

      // Typography extensions
      extensions: [
        TextEntryTheme.standard(
          headingColor: WarmThemeColors.primary,
          bodyColor: WarmThemeColors.onBackground,
        ),
        AppTypography.fromColorScheme(colorScheme),
      ],
    );
  }
}
