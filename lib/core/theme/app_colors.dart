import 'package:flutter/material.dart';

/// Color palette for Light theme
/// Warm cream background with dark brown text - perfect for daytime reading
class LightThemeColors {
  // Backgrounds
  static const background = Color(0xFFFDF8F3); // Warm cream
  static const surface = Color(0xFFEDE6DD); // Slightly darker cream (cards)
  static const surfaceContainer = Color(0xFFE8DFD0); // Gatha/verse background

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
}

/// Color palette for Dark theme
/// High contrast black with white text - WCAG AAA compliant for accessibility
class DarkThemeColors {
  // Backgrounds
  static const background = Color(0xFF121212); // Near black
  static const surface = Color(0xFF1E1E1E); // Slightly lighter (cards)
  static const surfaceContainer = Color(0xFF2A2A2A); // Gatha/verse background

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
}

/// Color palette for Warm theme
/// Earthy dark browns with warm text - signature Buddhist aesthetic
class WarmThemeColors {
  // Backgrounds
  static const background = Color(0xFF2A2318); // Dark warm brown
  static const surface = Color(0xFF3D3428); // Slightly lighter brown (cards)
  static const surfaceContainer = Color(0xFF4A3E2E); // Gatha/verse background

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
}
