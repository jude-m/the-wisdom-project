// TODO: Both ThemeNotifier and FontScaleNotifier call
// SharedPreferences.getInstance() directly instead of using the injected
// sharedPreferencesProvider. Refactor to inject SharedPreferences via
// constructor — requires moving sharedPreferencesProvider from
// presentation/providers/ to core/ to avoid a layer violation.
// Do both notifiers together for consistency.
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_fonts.dart';
import 'app_theme.dart';

/// Available theme modes
enum AppThemeMode {
  light, // ☀️ Warm cream background - daytime reading
  dark, // 🌙 High contrast black - night reading, accessibility
  warm, // 🔥 Earthy browns - evening reading, signature look
}

/// State notifier for managing app theme
class ThemeNotifier extends StateNotifier<AppThemeMode> {
  static const String _storageKey = 'app_theme_mode';

  ThemeNotifier() : super(AppThemeMode.light);

  /// Load saved theme preference from storage
  Future<void> loadSavedTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_storageKey);

      if (saved != null) {
        final mode = AppThemeMode.values.firstWhere(
          (e) => e.name == saved,
          orElse: () => AppThemeMode.light,
        );
        state = mode;
      }
    } catch (e) {
      // If loading fails, keep default (light)
      debugPrint('Failed to load theme preference: $e');
    }
  }

  /// Set theme and persist the choice
  Future<void> setTheme(AppThemeMode mode) async {
    state = mode;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, mode.name);
    } catch (e) {
      // Theme still changes in UI even if persistence fails
      debugPrint('Failed to save theme preference: $e');
    }
  }
}

/// Provider for theme state management
final themeNotifierProvider =
    StateNotifierProvider<ThemeNotifier, AppThemeMode>((ref) {
  return ThemeNotifier();
});

/// Font scale factor for the entire app.
///
/// Defaults to 0.85 on web (desktop monitors make fonts appear larger)
/// and 1.0 on native (mobile/tablet). The user can adjust this via the
/// font size slider in settings. The value is persisted to SharedPreferences.
final fontScaleProvider =
    StateNotifierProvider<FontScaleNotifier, double>((ref) {
  return FontScaleNotifier();
});

/// Manages font scale state with persistence.
class FontScaleNotifier extends StateNotifier<double> {
  static const String _storageKey = 'font_scale';

  /// Valid scale range (0.7x – 1.3x)
  static const double minScale = 0.7;
  static const double maxScale = 1.3;

  static const double _platformDefault =
      kIsWeb ? AppFonts.webDefaultScale : 1.0;

  FontScaleNotifier() : super(_platformDefault);

  /// The platform-appropriate default scale (1.0 native, 0.85 web)
  double get platformDefault => _platformDefault;

  /// Load saved font scale from storage
  Future<void> loadSavedScale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getDouble(_storageKey);
      if (saved != null) {
        state = saved.clamp(minScale, maxScale);
      }
    } catch (e) {
      debugPrint('Failed to load font scale: $e');
    }
  }

  /// Set font scale and persist (clamped to valid range)
  Future<void> setScale(double scale) async {
    state = scale.clamp(minScale, maxScale);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_storageKey, state);
    } catch (e) {
      debugPrint('Failed to save font scale: $e');
    }
  }

  /// Reset to platform default
  Future<void> reset() async {
    await setScale(_platformDefault);
  }
}

/// Provider that returns current ThemeData based on selected mode and font scale
final currentThemeDataProvider = Provider<ThemeData>((ref) {
  final mode = ref.watch(themeNotifierProvider);
  final fontScale = ref.watch(fontScaleProvider);

  switch (mode) {
    case AppThemeMode.light:
      return AppTheme.light(fontScale: fontScale);
    case AppThemeMode.dark:
      return AppTheme.dark(fontScale: fontScale);
    case AppThemeMode.warm:
      return AppTheme.warm(fontScale: fontScale);
  }
});
