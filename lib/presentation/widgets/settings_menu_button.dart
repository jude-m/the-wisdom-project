import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/theme_notifier.dart';
import '../../domain/entities/navigation/navigation_language.dart';
import '../models/column_display_mode.dart';
import '../providers/navigation_tree_provider.dart';
import '../providers/document_provider.dart';

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
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              _ThemeSelector(),
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
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              _LanguageSelector(),
            ],
          ),
        ),

        const PopupMenuDivider(),

        // Sutta language selector
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sutta Language',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              _SuttaLanguageSelector(),
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
        ButtonSegment(
          value: AppThemeMode.dark,
          label: Text('Dark'),
          icon: Icon(Icons.dark_mode, size: 16),
        ),
        ButtonSegment(
          value: AppThemeMode.warm,
          label: Text('Warm'),
          icon: Icon(Icons.palette, size: 16),
        ),
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
        ref.read(navigationLanguageProvider.notifier).state =
            newSelection.first;
      },
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

/// Sutta language selection buttons
class _SuttaLanguageSelector extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(columnDisplayModeProvider);

    return SegmentedButton<ColumnDisplayMode>(
      segments: const [
        ButtonSegment(
          value: ColumnDisplayMode.paliOnly,
          label: Text('P', style: TextStyle(fontSize: 11)),
        ),
        ButtonSegment(
          value: ColumnDisplayMode.both,
          label: Text('P+S', style: TextStyle(fontSize: 11)),
        ),
        ButtonSegment(
          value: ColumnDisplayMode.sinhalaOnly,
          label: Text('S', style: TextStyle(fontSize: 11)),
        ),
      ],
      selected: {currentMode},
      onSelectionChanged: (Set<ColumnDisplayMode> newSelection) {
        ref.read(columnDisplayModeProvider.notifier).state = newSelection.first;
      },
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
