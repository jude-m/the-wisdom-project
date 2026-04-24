import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/theme_notifier.dart';
import '../../domain/entities/navigation/navigation_language.dart';
import '../providers/navigation_tree_provider.dart';

/// Settings menu button for AppBar
class SettingsMenuButton extends ConsumerWidget {
  const SettingsMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.settings),
      tooltip: 'Settings',
      onSelected: (value) {
        // Menu items are handled by their own callbacks
      },
      itemBuilder: (context) => [
        // Theme selector
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Theme',
                style: context.typography.menuSectionLabel,
              ),
              const SizedBox(height: 8),
              _ThemeSelector(),
            ],
          ),
        ),

        const PopupMenuDivider(),

        // Font size slider
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Font Size',
                style: context.typography.menuSectionLabel,
              ),
              const SizedBox(height: 4),
              _FontSizeSelector(),
            ],
          ),
        ),

        const PopupMenuDivider(),

        // Language selector
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Navigation Language',
                style: context.typography.menuSectionLabel,
              ),
              const SizedBox(height: 8),
              _LanguageSelector(),
            ],
          ),
        ),

      ],
    );
  }
}

/// Theme selection buttons
class _ThemeSelector extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(themeNotifierProvider);

    return SegmentedButton<AppThemeMode>(
      segments: const [
        ButtonSegment(
          value: AppThemeMode.light,
          label: Text('Light'),
          icon: Icon(Icons.light_mode, size: 16),
        ),
        // ButtonSegment(
        //   value: AppThemeMode.dark,
        //   label: Text('Dark'),
        //   icon: Icon(Icons.dark_mode, size: 16),
        // ),
        // ButtonSegment(
        //   value: AppThemeMode.warm,
        //   label: Text('Warm'),
        //   icon: Icon(Icons.palette, size: 16),
        // ),
      ],
      selected: {currentTheme},
      onSelectionChanged: (Set<AppThemeMode> newSelection) {
        ref.read(themeNotifierProvider.notifier).setTheme(newSelection.first);
      },
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

/// Font size slider with A-/A+ labels and reset button.
///
/// Label styles are intentionally NOT scaled — they stay fixed so the
/// slider UI remains stable while the user adjusts the scale.
class _FontSizeSelector extends ConsumerWidget {
  /// Number of discrete steps between min and max (0.05 increments)
  static const int _scaleDivisions = 12;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = ref.watch(fontScaleProvider);
    final notifier = ref.read(fontScaleProvider.notifier);
    final colors = Theme.of(context).colorScheme;
    final isDefault = (scale - notifier.platformDefault).abs() < 0.01;
    final percentage = (scale * 100).round();

    return Column(
      children: [
        // Slider row: A- [slider] A+
        Row(
          children: [
            Text(
              'A-',
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: AppFonts.labelFontSize,
                fontWeight: FontWeight.w500,
                color: colors.onSurfaceVariant,
              ),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 7),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 14),
                ),
                child: Slider(
                  value: scale.clamp(
                    FontScaleNotifier.minScale,
                    FontScaleNotifier.maxScale,
                  ),
                  min: FontScaleNotifier.minScale,
                  max: FontScaleNotifier.maxScale,
                  divisions: _scaleDivisions,
                  onChanged: (value) {
                    // Round to avoid floating point drift
                    final rounded =
                        (value * 20).round() / 20; // nearest 0.05
                    notifier.setScale(rounded);
                  },
                ),
              ),
            ),
            Text(
              'A+',
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: AppFonts.baseFontSize,
                fontWeight: FontWeight.w600,
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        // Percentage and reset row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$percentage%',
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: AppFonts.labelFontSize,
                color: colors.onSurfaceVariant,
              ),
            ),
            if (!isDefault)
              TextButton(
                onPressed: () => notifier.reset(),
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 36),
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Reset',
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
                    fontSize: AppFonts.labelFontSize,
                    color: colors.primary,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Language selection buttons
class _LanguageSelector extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLanguage = ref.watch(navigationLanguageProvider);

    return SegmentedButton<NavigationLanguage>(
      segments: const [
        ButtonSegment(
          value: NavigationLanguage.pali,
          label: Text('Pali'),
        ),
        ButtonSegment(
          value: NavigationLanguage.sinhala,
          label: Text('සිංහල'),
        ),
      ],
      selected: {currentLanguage},
      onSelectionChanged: (Set<NavigationLanguage> newSelection) {
        final notifier = ref.read(navigationLanguageProvider.notifier);
        notifier.setLanguage(newSelection.first);
      },
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
