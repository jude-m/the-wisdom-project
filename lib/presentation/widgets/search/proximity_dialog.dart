import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/l10n/app_localizations.dart';
import '../../providers/search_provider.dart';

/// Dialog for configuring word proximity and phrase/separate-word search mode.
///
/// Features:
/// - Radio buttons for phrase search vs separate-word search (default: phrase)
/// - Slider (1-100 words) for proximity distance (only when separate-word mode)
/// - "Anywhere in text" checkbox (only when separate-word mode)
/// - Apply button to save changes
///
/// Opened from the proximity button in the search bar.
class ProximityDialog extends ConsumerStatefulWidget {
  const ProximityDialog({super.key});

  /// Show the dialog and return true if changes were applied.
  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => const ProximityDialog(),
    );
  }

  @override
  ConsumerState<ProximityDialog> createState() => _ProximityDialogState();
}

class _ProximityDialogState extends ConsumerState<ProximityDialog> {
  // Local state (applied on "Apply" button)
  late bool _isPhraseSearch;
  late bool _isAnywhereInText;
  late int _proximityDistance;

  @override
  void initState() {
    super.initState();
    _initializeFromSearchState();
  }

  void _initializeFromSearchState() {
    final searchState = ref.read(searchStateProvider);
    _isPhraseSearch = searchState.isPhraseSearch;
    _isAnywhereInText = searchState.isAnywhereInText;
    _proximityDistance = searchState.proximityDistance;
  }

  void _resetToDefaults() {
    setState(() {
      _isPhraseSearch = true; // Default is phrase search
      _isAnywhereInText = false;
      _proximityDistance = 10;
    });
  }

  void _applyChanges() {
    final notifier = ref.read(searchStateProvider.notifier);
    notifier.setPhraseSearch(_isPhraseSearch);
    notifier.setAnywhereInText(_isAnywhereInText);
    notifier.setProximityDistance(_proximityDistance);
    Navigator.of(context).pop(true);
  }

  /// Whether the proximity controls (slider and anywhere checkbox) should be enabled.
  /// Only enabled when separate-word search mode is selected.
  bool get _isProximityControlsEnabled => !_isPhraseSearch;

  /// Whether the slider should be enabled.
  /// Only enabled when separate-word mode and "anywhere" is not checked.
  bool get _isSliderEnabled => _isProximityControlsEnabled && !_isAnywhereInText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 340,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    Icons.space_bar,
                    color: theme.colorScheme.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.wordProximity,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(false),
                    tooltip: l10n.close,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Phrase search radio
              _buildRadioOption(
                theme: theme,
                value: true,
                groupValue: _isPhraseSearch,
                label: l10n.searchAsPhrase,
                onChanged: (value) => setState(() {
                  _isPhraseSearch = value!;
                }),
              ),

              // Separate-word search radio
              _buildRadioOption(
                theme: theme,
                value: false,
                groupValue: _isPhraseSearch,
                label: l10n.searchAsSeparateWords,
                onChanged: (value) => setState(() {
                  _isPhraseSearch = value!;
                }),
              ),

              const SizedBox(height: 16),

              // Proximity controls section (only enabled for separate-word mode)
              AnimatedOpacity(
                opacity: _isProximityControlsEnabled ? 1.0 : 0.5,
                duration: const Duration(milliseconds: 200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Proximity slider
                    Row(
                      children: [
                        Text(
                          '1',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: _isSliderEnabled
                                ? theme.colorScheme.onSurfaceVariant
                                : theme.colorScheme.onSurface
                                    .withValues(alpha: 0.38),
                          ),
                        ),
                        Expanded(
                          child: Slider(
                            value: _proximityDistance.toDouble(),
                            min: 1,
                            max: 100,
                            divisions: 99,
                            label: '$_proximityDistance',
                            onChanged: _isSliderEnabled
                                ? (value) => setState(() {
                                      _proximityDistance = value.round();
                                    })
                                : null,
                          ),
                        ),
                        Text(
                          '100',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: _isSliderEnabled
                                ? theme.colorScheme.onSurfaceVariant
                                : theme.colorScheme.onSurface
                                    .withValues(alpha: 0.38),
                          ),
                        ),
                      ],
                    ),

                    // Current value display
                    Center(
                      child: Text(
                        _isAnywhereInText
                            ? l10n.anywhereInText
                            : l10n.wordsApart(_proximityDistance),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _isProximityControlsEnabled
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface
                                  .withValues(alpha: 0.38),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Anywhere in text checkbox
                    _buildCheckboxOption(
                      theme: theme,
                      value: _isAnywhereInText,
                      label: l10n.anywhereInText,
                      enabled: _isProximityControlsEnabled,
                      onChanged: (value) => setState(() {
                        _isAnywhereInText = value ?? false;
                      }),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _resetToDefaults,
                    child: Text(l10n.reset),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _applyChanges,
                    child: Text(l10n.apply),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a radio option row.
  Widget _buildRadioOption({
    required ThemeData theme,
    required bool value,
    required bool groupValue,
    required String label,
    required ValueChanged<bool?> onChanged,
  }) {
    return RadioGroup<bool>(
      groupValue: groupValue,
      onChanged: (bool? newValue) {
        if (newValue != null) {
          onChanged(newValue);
        }
      },
      child: InkWell(
        onTap: () => onChanged(value),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Radio<bool>(
                  value: value,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a checkbox option row.
  Widget _buildCheckboxOption({
    required ThemeData theme,
    required bool value,
    required String label,
    required bool enabled,
    required ValueChanged<bool?> onChanged,
  }) {
    return InkWell(
      onTap: enabled ? () => onChanged(!value) : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: value,
                onChanged: enabled ? onChanged : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: enabled
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurface.withValues(alpha: 0.38),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
