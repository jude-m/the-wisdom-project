import 'package:flutter/material.dart';

/// Color palette for Light theme
/// Warm cream background with dark brown text - perfect for daytime reading
/// Color names follow M3 role semantics (primary = interactive brand color)
///
/// Brown tonal bands (4 distinct values, dark → light):
///   #2A2318 (16%) — heading, onPrimaryContainer, onTertiary, onSecondaryContainer, shadow
///   #422701 (26%) — onSurface (body text)
///   #5A3A18 (31%) — primary, surfaceTint (interactive elements)
///   #705E46 (48%) — secondary, onSurfaceVariant (muted/taupe)
///   #362F25 (22%) — inverseSurface (snackbar bg, separate context)
class LightThemeColors {
  // ============================================
  // Background & Surface
  // ============================================
  static const background = Color(0xFFFDF8F3); // Warm cream (scaffoldBg)
  static const surface = Color(0xFFFDF8F3); // M3 surface = lightest cream
  static const onSurface = Color(0xFF422701); // Deep brown (body text)
  static const onSurfaceVariant = Color(0xFF705E46); // Warm taupe (muted text)
  static const surfaceContainerLowest = Color(0xFFFDF8F3); // Same as bg
  static const surfaceContainerLow = Color(0xFFF5EEE5); // Subtle lift
  static const surfaceContainer = Color(0xFFEDE6DD); // Standard cards
  static const surfaceContainerHigh = Color(0xFFE8DFD0); // Gatha bg, highlights
  static const surfaceContainerHighest = Color(0xFFE0D7C8); // Dialogs, active tabs
  static const surfaceDim = Color(0xFFDED8CE); // Dimmer canvas
  static const surfaceBright = Color(0xFFFDF8F3); // Bright canvas (= bg)
  static const surfaceTint = Color(0xFF5A3A18); // Elevation tint (= primary)

  // ============================================
  // Primary group (interactive brand color)
  // ============================================
  static const primary = Color(0xFF5A3A18); // Warm cinnamon brown (interactive)
  static const onPrimary = Color(0xFFFFFFFF); // White
  static const primaryContainer = Color(0xFFFAEBD7); // Light antique peach
  static const onPrimaryContainer = Color(0xFF2A2318); // Dark brown (= heading)

  // ============================================
  // Secondary group (complementary understated accent)
  // ============================================
  static const secondary = Color(0xFF705E46); // Warm taupe
  static const onSecondary = Color(0xFFFFFFFF); // White
  static const secondaryContainer = Color(0xFFF0E6D8); // Light warm cream (M3 tonal fill)
  static const onSecondaryContainer = Color(0xFF2A2318); // Dark brown (= heading)

  // ============================================
  // Tertiary group (contrasting accent)
  // ============================================
  static const tertiary = Color(0xFFFFD36A); // Golden amber (match highlight)
  static const onTertiary = Color(0xFF2A2318); // Dark brown (= heading)
  static const tertiaryContainer = Color(0xB3B8C7AB); // Sage green (70% opacity)
  static const onTertiaryContainer = Color(0xFF2F3E28); // Dark green

  // ============================================
  // Error group
  // ============================================
  static const error = Color(0xFFB3261E); // M3 cherry red (distinct from primary)
  static const onError = Color(0xFFFFFFFF); // White
  static const errorContainer = Color(0xFFFFDAD0); // Soft peach-red
  static const onErrorContainer = Color(0xFF410001); // Dark maroon

  // ============================================
  // Outline & Dividers
  // ============================================
  static const outline = Color(0xFFD6C9B8); // Light tan
  static const outlineVariant = Color(0xFFE0D7C8); // Warm sand (solid)

  // ============================================
  // Inverse group (snackbars, tooltips)
  // ============================================
  static const inverseSurface = Color(0xFF362F25); // Dark warm brown
  static const inverseOnSurface = Color(0xFFF5EEE5); // Light cream
  static const inversePrimary = Color(0xFFFFB77C); // Light orange

  // ============================================
  // Utility
  // ============================================
  static const scrim = Color(0xFF000000); // Modal overlay
  static const shadow = Color(0xFF2A2318); // Dark brown (= heading)

  // ============================================
  // Custom (not M3 roles — app-specific)
  // ============================================
  static const heading = Color(0xFF2A2318); // Dark brown (reader headings only)
}

/// Color palette for Dark theme
/// High contrast black with white text - WCAG AAA compliant for accessibility
class DarkThemeColors {
  // Background & Surface Container Hierarchy (Material 3)
  static const background = Color(0xFF121212); // Near black
  static const surfaceContainerLowest =
      Color(0xFF121212); // Same as bg (inactive)
  static const surfaceContainerLow = Color(0xFF1A1A1A); // Subtle lift
  static const surface = Color(0xFF1E1E1E); // Standard cards
  static const surfaceContainerHigh = Color(0xFF2A2A2A); // Gatha bg, highlights
  static const surfaceContainerHighest =
      Color(0xFF333333); // Dialogs, active tabs

  // Text
  static const primary = Color(0xFFFFFFFF); // Pure white (headings)
  static const onPrimary = Color(0xFF121212); // Dark (text on light buttons)
  static const onBackground = Color(0xFFE0E0E0); // Light gray (body text)
  static const muted = Color(0xFF9E9E9E); // Medium gray (secondary text)

  // Interactive
  static const accent = Color(0xFFFF8C00); // Bright orange (links, buttons)
  static const secondaryAccent = Color(0xFFFFD36A); // Golden amber (current match highlight)

  // Utility
  static const divider = Color(0xFF424242); // Dark gray divider
  static const error = Color(0xFFFF6B6B); // Bright red
  static const onError = Color(0xFF000000); // Black text on error

  // Search highlight
  static const tertiaryContainer = Color(0xFF3D5A3D); // Dark sage green
  static const onTertiaryContainer = Color(0xFFD0E8D0); // Light green text
}

/// Color palette for Warm theme
/// Earthy dark browns with warm text - signature Buddhist aesthetic
class WarmThemeColors {
  // Background & Surface Container Hierarchy (Material 3)
  static const background = Color(0xFF2A2318); // Dark warm brown
  static const surfaceContainerLowest =
      Color(0xFF2A2318); // Same as bg (inactive)
  static const surfaceContainerLow = Color(0xFF332B1F); // Subtle lift
  static const surface = Color(0xFF3D3428); // Standard cards
  static const surfaceContainerHigh = Color(0xFF4A3E2E); // Gatha bg, highlights
  static const surfaceContainerHighest =
      Color(0xFF554838); // Dialogs, active tabs

  // Text
  static const primary = Color(0xFFD47E30); // Cinnamon orange (headings)
  static const onPrimary = Color(0xFF1A1408); // Very dark (text on buttons)
  static const onBackground = Color(0xFFE8DFD0); // Warm off-white (body text)
  static const muted = Color(0xFF8A7D6A); // Muted tan (secondary text)

  // Interactive
  static const accent = Color(0xFFD6B588); // Gold (links, buttons)
  static const secondaryAccent = Color(0xFFFFD36A); // Golden amber (current match highlight)

  // Utility
  static const divider = Color(0xFF524535); // Dark brown divider
  static const error = Color(0xFFFF8A65); // Soft orange-red
  static const onError = Color(0xFF1A1408); // Dark text on error

  // Search highlight
  static const tertiaryContainer = Color(0xFF4A4030); // Warm dark brown
  static const onTertiaryContainer = Color(0xFFE8DFD0); // Warm off-white
}
