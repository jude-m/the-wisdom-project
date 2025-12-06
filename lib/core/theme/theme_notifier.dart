import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

/// Provider that returns current ThemeData based on selected mode
final currentThemeDataProvider = Provider<ThemeData>((ref) {
  final mode = ref.watch(themeNotifierProvider);

  switch (mode) {
    case AppThemeMode.light:
      return AppTheme.light();
    case AppThemeMode.dark:
      return AppTheme.dark();
    case AppThemeMode.warm:
      return AppTheme.warm();
  }
});
