import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_fonts.dart';
import 'text_entry_theme.dart';

/// Application theme builder
/// Combines color palettes with typography to create complete Material 3 themes
class AppTheme {
  /// Light theme - Warm cream background with dark brown text
  /// Best for daytime reading, default theme
  static ThemeData light() {
    return ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      fontFamily: AppFonts.sinhala,
      fontFamilyFallback: AppFonts.sinhalaFallback,

      // Background colors
      scaffoldBackgroundColor: LightThemeColors.background,
      cardColor: LightThemeColors.surface,
      dividerColor: LightThemeColors.divider,

      // Color scheme with full Surface Container hierarchy
      colorScheme: ColorScheme.light(
        primary: LightThemeColors.primary,
        onPrimary: LightThemeColors.onPrimary,
        primaryContainer: LightThemeColors.accent.withValues(alpha: 0.2),
        onPrimaryContainer: LightThemeColors.primary,
        secondary: LightThemeColors.accent,
        onSecondary: LightThemeColors.onPrimary,
        surface: LightThemeColors.surface,
        onSurface: LightThemeColors.onBackground,
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

        secondaryContainer: LightThemeColors.secondaryContainer,
        onSecondaryContainer: LightThemeColors.onSecondaryContainer


      ),

      // Text entry typography
      extensions: [
        TextEntryTheme.standard(
          headingColor: LightThemeColors.primary,
          bodyColor: LightThemeColors.onBackground,
        ),
      ],
    );
  }

  /// Dark theme - High contrast black with white text
  /// WCAG AAA compliant for accessibility, night reading
  static ThemeData dark() {
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      fontFamily: AppFonts.sinhala,
      fontFamilyFallback: AppFonts.sinhalaFallback,

      // Background colors
      scaffoldBackgroundColor: DarkThemeColors.background,
      cardColor: DarkThemeColors.surface,
      dividerColor: DarkThemeColors.divider,

      // Color scheme with full Surface Container hierarchy
      colorScheme: ColorScheme.dark(
        primary: DarkThemeColors.primary,
        onPrimary: DarkThemeColors.onPrimary,
        primaryContainer: DarkThemeColors.accent.withValues(alpha: 0.2),
        onPrimaryContainer: DarkThemeColors.primary,
        secondary: DarkThemeColors.accent,
        onSecondary: DarkThemeColors.onPrimary,
        surface: DarkThemeColors.surface,
        onSurface: DarkThemeColors.onBackground,
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
      ),

      // Text entry typography
      extensions: [
        TextEntryTheme.standard(
          headingColor: DarkThemeColors.primary,
          bodyColor: DarkThemeColors.onBackground,
        ),
      ],
    );
  }

  /// Warm theme - Earthy dark browns with warm text
  /// Signature Buddhist aesthetic, evening reading
  static ThemeData warm() {
    return ThemeData(
      brightness: Brightness.dark, // Warm is a dark theme variant
      useMaterial3: true,
      fontFamily: AppFonts.sinhala,
      fontFamilyFallback: AppFonts.sinhalaFallback,

      // Background colors
      scaffoldBackgroundColor: WarmThemeColors.background,
      cardColor: WarmThemeColors.surface,
      dividerColor: WarmThemeColors.divider,

      // Color scheme with full Surface Container hierarchy
      colorScheme: ColorScheme.dark(
        primary: WarmThemeColors.primary,
        onPrimary: WarmThemeColors.onPrimary,
        primaryContainer: WarmThemeColors.accent.withValues(alpha: 0.25),
        onPrimaryContainer: WarmThemeColors.primary,
        secondary: WarmThemeColors.accent,
        onSecondary: WarmThemeColors.onPrimary,
        surface: WarmThemeColors.surface,
        onSurface: WarmThemeColors.onBackground,
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
      ),

      // Text entry typography
      extensions: [
        TextEntryTheme.standard(
          headingColor: WarmThemeColors.primary,
          bodyColor: WarmThemeColors.onBackground,
        ),
      ],
    );
  }
}
