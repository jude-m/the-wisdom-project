import 'package:flutter/material.dart';

/// Color palette for Light theme
/// Warm cream background with dark brown text - perfect for daytime reading
class LightThemeColors {
  // Background & Surface Container Hierarchy (Material 3)
  static const background = Color(0xFFFDF8F3); // Warm cream
  static const surfaceContainerLowest =
      Color(0xFFFDF8F3); // Same as bg (inactive)
  static const surfaceContainerLow = Color(0xFFF5EEE5); // Subtle lift
  static const surface = Color(0xFFEDE6DD); // Standard cards
  static const surfaceContainerHigh = Color(0xFFE8DFD0); // Gatha bg, highlights
  static const surfaceContainerHighest =
      Color(0xFFE0D7C8); // Dialogs, active tabs

  // Text
  static const primary = Color(0xFF2A2318); // Dark brown (headings)
  static const onPrimary = Color(0xFFFFFFFF); // White (text on buttons)
  static const onBackground = Color(0xFF422701); // Deep brown (body text)
  static const muted = Color(0xFF705E46); // Muted brown (secondary text)

  // Interactive
  static const accent = Color(0xFFD47E30); // Cinnamon orange (links, buttons)

  // Utility
  static const divider = Color(0xFFD6C9B8); // Light tan divider
  static const error = Color(0xFFC04000); // Dark orange-red
  static const onError = Color(0xFFFFFFFF); // White text on error


  static const secondaryContainer = Color(0xFF705E46); // Warm Taupe (Selected)
  static const onSecondaryContainer = Color(0xFFFFFFFF); // Dark Brown (Text)

  // Other options:
  // Option 2 - Deeper Sage: secondaryContainer = 0xFFB8C7AB, onSecondaryContainer = 0xFF2F3E28
  // Option 3 - Dusty Clay: secondaryContainer = 0xFFD4BEB0, onSecondaryContainer = 0xFF4A3830
  // Option 4 - Wheat:      secondaryContainer = 0xFFD8CCBA, onSecondaryContainer = 0xFF4A3F30
  // Option 5 - Warm Stone: secondaryContainer = 0xFFC9C0B5, onSecondaryContainer = 0xFF3D3832


  // const Color robeDeepRust = Color(0xFF68261E); // Deep Rust / Mahogany
  // const Color robeDarkUmber = Color(0xFF734023); // Dark Umber Brown
  // const Color robeRustBrown = Color(0xFF903B23); // Rust Brown
  // const Color robeBurntOchre = Color(0xFF984928); // Burnt Ochre
  // const Color robeCinnamon = Color(0xFF856231); // Cinnamon Brown
  // const Color robeKhakiSand = Color(0xFFA59679); // Muted Sand / Khaki Beige
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

  // Utility
  static const divider = Color(0xFF424242); // Dark gray divider
  static const error = Color(0xFFFF6B6B); // Bright red
  static const onError = Color(0xFF000000); // Black text on error
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

  // Utility
  static const divider = Color(0xFF524535); // Dark brown divider
  static const error = Color(0xFFFF8A65); // Soft orange-red
  static const onError = Color(0xFF1A1408); // Dark text on error
}
