import 'package:flutter/material.dart';
import 'app_colors.dart';
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
      fontFamily: 'Roboto',

      // Background colors
      scaffoldBackgroundColor: LightThemeColors.background,
      cardColor: LightThemeColors.surface,
      dividerColor: LightThemeColors.divider,

      // Color scheme
      colorScheme: ColorScheme.light(
        primary: LightThemeColors.primary,
        onPrimary: LightThemeColors.onPrimary,
        primaryContainer:
            LightThemeColors.accent.withOpacity(0.2), // Selection highlight
        onPrimaryContainer: LightThemeColors.primary,
        secondary: LightThemeColors.accent,
        onSecondary: LightThemeColors.onPrimary,
        surface: LightThemeColors.surface,
        onSurface: LightThemeColors.onBackground,
        surfaceContainerHighest: LightThemeColors.surfaceContainer,
        error: LightThemeColors.error,
        outline: LightThemeColors.divider,
      ),

      // Text entry typography (color-independent)
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
      fontFamily: 'Roboto',

      // Background colors
      scaffoldBackgroundColor: DarkThemeColors.background,
      cardColor: DarkThemeColors.surface,
      dividerColor: DarkThemeColors.divider,

      // Color scheme
      colorScheme: ColorScheme.dark(
        primary: DarkThemeColors.primary,
        onPrimary: DarkThemeColors.onPrimary,
        primaryContainer:
            DarkThemeColors.accent.withOpacity(0.2), // Selection highlight
        onPrimaryContainer: DarkThemeColors.primary,
        secondary: DarkThemeColors.accent,
        onSecondary: DarkThemeColors.onPrimary,
        surface: DarkThemeColors.surface,
        onSurface: DarkThemeColors.onBackground,
        surfaceContainerHighest: DarkThemeColors.surfaceContainer,
        error: DarkThemeColors.error,
        outline: DarkThemeColors.divider,
      ),

      // Text entry typography (color-independent)
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
      fontFamily: 'Roboto',

      // Background colors
      scaffoldBackgroundColor: WarmThemeColors.background,
      cardColor: WarmThemeColors.surface,
      dividerColor: WarmThemeColors.divider,

      // Color scheme
      colorScheme: ColorScheme.dark(
        primary: WarmThemeColors.primary,
        onPrimary: WarmThemeColors.onPrimary,
        primaryContainer:
            WarmThemeColors.accent.withOpacity(0.25), // Selection highlight
        onPrimaryContainer: WarmThemeColors.primary,
        secondary: WarmThemeColors.accent,
        onSecondary: WarmThemeColors.onPrimary,
        surface: WarmThemeColors.surface,
        onSurface: WarmThemeColors.onBackground,
        surfaceContainerHighest: WarmThemeColors.surfaceContainer,
        error: WarmThemeColors.error,
        outline: WarmThemeColors.divider,
      ),

      // Text entry typography (color-independent)
      extensions: [
        TextEntryTheme.standard(
          headingColor: WarmThemeColors.primary,
          bodyColor: WarmThemeColors.onBackground,
        ),
      ],
    );
  }
}
