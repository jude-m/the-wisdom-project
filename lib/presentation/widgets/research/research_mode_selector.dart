import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/l10n/app_localizations.dart';
import '../../../domain/entities/research/research_mode.dart';
import '../../providers/research_mode_provider.dart';
import 'research_mode_ui.dart';

/// The Fast/Thinking mode switch shown in the Research header (the reference
/// mockup's top-right chip). Tapping it opens a menu of the two modes, each
/// with a one-line hint and a check on the active one. The choice applies to
/// the current chat and is remembered per-chat ([researchModeProvider] seeds
/// it; the chat's summary stores it) — a new chat always starts on Fast.
///
/// Presentation is deliberately friendly — "Fast" / "Thinking", never raw
/// Gemini model IDs. The per-tier fallback ladder stays a backend detail.
class ResearchModeSelector extends ConsumerWidget {
  const ResearchModeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final mode = ref.watch(researchModeProvider);

    return PopupMenuButton<ResearchMode>(
      tooltip: l10n.researchModeTooltip,
      position: PopupMenuPosition.under,
      onSelected: (m) => ref.read(researchModeProvider.notifier).set(m),
      itemBuilder: (context) => [
        for (final m in ResearchMode.values)
          PopupMenuItem<ResearchMode>(
            value: m,
            child: _ModeMenuRow(
              icon: m.icon,
              title: m.label(l10n),
              hint: m.hint(l10n),
              selected: m == mode,
            ),
          ),
      ],
      // The resting chip: current mode + a dropdown caret. It reads as a raised
      // pill by being a step LIGHTER than the composer fill it sits inside
      // (surfaceContainerHigh) — same trick the search scope-filter chips use,
      // so no border is needed for it to stand out.
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(mode.icon, size: 18, color: colors.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(mode.label(l10n)),
            Icon(Icons.arrow_drop_down, size: 20, color: colors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// One row in the mode menu: leading check (only for the active mode) + icon,
/// then the title over a muted one-line hint.
class _ModeMenuRow extends StatelessWidget {
  const _ModeMenuRow({
    required this.icon,
    required this.title,
    required this.hint,
    required this.selected,
  });

  final IconData icon;
  final String title;
  final String hint;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        // Fixed-width check slot so titles align whether or not a row is ticked.
        SizedBox(
          width: 24,
          child: selected
              ? Icon(Icons.check, size: 18, color: colors.primary)
              : null,
        ),
        Icon(icon, size: 18, color: colors.onSurfaceVariant),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title),
            Text(
              hint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ],
    );
  }
}
