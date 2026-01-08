import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/l10n/app_localizations.dart';
import '../providers/search_provider.dart';

/// Simple dialog for configuring word proximity in multi-word searches.
///
/// Features:
/// - Slider (1-30 words) for proximity distance
/// - Phrase search checkbox (disables slider when checked)
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
  late int _proximityDistance;
  late bool _isPhraseSearch;

  @override
  void initState() {
    super.initState();
    _initializeFromSearchState();
  }

  void _initializeFromSearchState() {
    final searchState = ref.read(searchStateProvider);
    _proximityDistance = searchState.proximityDistance ?? 10;
    _isPhraseSearch = searchState.proximityDistance == null;
  }

  void _resetToDefaults() {
    setState(() {
      _proximityDistance = 10;
      _isPhraseSearch = false;
    });
  }

  void _applyChanges() {
    final notifier = ref.read(searchStateProvider.notifier);
    notifier.setProximityDistance(_isPhraseSearch ? null : _proximityDistance);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 320,
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
              const SizedBox(height: 20),

              // Proximity slider
              Row(
                children: [
                  Text(
                    '1',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _isPhraseSearch
                          ? theme.colorScheme.onSurface.withValues(alpha: 0.38)
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Expanded(
                    child: Slider(
                      value: _proximityDistance.toDouble(),
                      min: 1,
                      max: 30,
                      divisions: 29,
                      label: '$_proximityDistance',
                      onChanged: _isPhraseSearch
                          ? null
                          : (value) => setState(() {
                                _proximityDistance = value.round();
                              }),
                    ),
                  ),
                  Text(
                    '30',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _isPhraseSearch
                          ? theme.colorScheme.onSurface.withValues(alpha: 0.38)
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),

              // Current value display
              Center(
                child: Text(
                  _isPhraseSearch
                      ? l10n.exactConsecutiveWords
                      : l10n.wordsApart(_proximityDistance),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Phrase search checkbox
              InkWell(
                onTap: () => setState(() {
                  _isPhraseSearch = !_isPhraseSearch;
                }),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: _isPhraseSearch,
                          onChanged: (value) => setState(() {
                            _isPhraseSearch = value ?? false;
                          }),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.phraseSearch,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
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
}
