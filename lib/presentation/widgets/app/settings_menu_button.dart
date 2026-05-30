import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/l10n/app_localizations.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/theme_notifier.dart';
import '../../../domain/entities/content/content_language.dart';
import '../../providers/app_language_provider.dart';
import '../../providers/content_language_provider.dart';

/// Settings menu button for AppBar
class SettingsMenuButton extends ConsumerWidget {
  const SettingsMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<String>(
      icon: const Icon(Icons.settings),
      tooltip: l10n.settings,
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
              _MenuSectionLabel((l10n) => l10n.theme),
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
              _MenuSectionLabel((l10n) => l10n.fontSize),
              const SizedBox(height: 4),
              _FontSizeSelector(),
            ],
          ),
        ),

        const PopupMenuDivider(),

        // App Language selector — UI localization (English / Sinhala).
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MenuSectionLabel((l10n) => l10n.appLanguage),
              const SizedBox(height: 8),
              _AppLanguageSelector(),
            ],
          ),
        ),

        const PopupMenuDivider(),

        // Content Language selector — which text/translation labels appear in
        // (tree, breadcrumbs, search, dialogs, tabs). Options come from the
        // active edition.
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MenuSectionLabel((l10n) => l10n.contentLanguage),
              const SizedBox(height: 8),
              _ContentLanguageSelector(),
            ],
          ),
        ),
      ],
    );
  }
}

/// A localized section header inside the settings popup menu.
///
/// Why this is its own widget: the settings menu is a [PopupMenuButton], whose
/// `itemBuilder` runs only ONCE — when the menu opens. A plain `Text(l10n.xxx)`
/// built there would freeze at whatever App Language was active at open-time, so
/// switching the language with the menu open left stale headers until you closed
/// and reopened it.
///
/// Resolving [AppLocalizations.of] inside this widget's own `build` registers a
/// dependency on the [Localizations] ancestor. The open menu lives in the
/// navigator overlay (below that ancestor), so when the App Language changes —
/// which rebuilds the MaterialApp's [Localizations] — this header rebuilds with
/// it and the label switches live.
class _MenuSectionLabel extends StatelessWidget {
  const _MenuSectionLabel(this.selector);

  /// Picks the string to show, e.g. `(l10n) => l10n.theme`.
  final String Function(AppLocalizations l10n) selector;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Text(
      selector(l10n),
      style: context.typography.menuSectionLabel,
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
  static const int _scaleDivisions = 16;

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

/// App Language (UI localization) selector.
///
/// Options are self-labelled in their own language — standard for a language
/// picker — so a user can always find their language regardless of the current
/// UI language.
class _AppLanguageSelector extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(appLanguageProvider);

    return SegmentedButton<AppLanguage>(
      segments: const [
        ButtonSegment(
          value: AppLanguage.english,
          label: Text('English'),
        ),
        ButtonSegment(
          value: AppLanguage.sinhala,
          label: Text('සිංහල'),
        ),
      ],
      selected: {current},
      onSelectionChanged: (newSelection) {
        ref.read(appLanguageProvider.notifier).setLanguage(newSelection.first);
      },
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

/// Content Language selector.
///
/// The available options come from the active edition (BJT → Pali, Sinhala).
/// Labels are localized so they follow the App Language. `selected` reads the
/// *effective* value (clamped to the edition), while changes write the raw
/// preference.
class _ContentLanguageSelector extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final available = ref.watch(availableContentLanguagesProvider);
    final current = ref.watch(effectiveContentLanguageProvider);

    return SegmentedButton<ContentLanguage>(
      segments: [
        for (final language in available)
          ButtonSegment(
            value: language,
            label: Text(_contentLanguageLabel(language, l10n)),
          ),
      ],
      selected: {current},
      onSelectionChanged: (newSelection) {
        ref
            .read(contentLanguageProvider.notifier)
            .setLanguage(newSelection.first);
      },
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  /// Maps a [ContentLanguage] to its localized label.
  String _contentLanguageLabel(ContentLanguage language, AppLocalizations l10n) {
    switch (language) {
      case ContentLanguage.pali:
        return l10n.paliLanguageLabel;
      case ContentLanguage.sinhala:
        return l10n.sinhalaLanguageLabel;
    }
  }
}
