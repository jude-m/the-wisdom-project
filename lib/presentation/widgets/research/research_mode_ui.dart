import 'package:flutter/material.dart';

import '../../../core/localization/l10n/app_localizations.dart';
import '../../../domain/entities/research/research_mode.dart';

/// Presentation-layer look-up for how each [ResearchMode] appears: its icon and
/// the localised chip label, menu hint, and in-flight busy label.
///
/// One `switch` expression per facet, kept in a single place. Because these
/// switches are exhaustive over the enum, adding a third mode fails to COMPILE
/// until every facet handles it — a plain `mode == thinking ? … : …` would
/// instead silently treat a new mode as Fast. This lives in the presentation
/// layer (not on the domain enum) so the domain stays free of Flutter + l10n.
extension ResearchModeUi on ResearchMode {
  /// The glyph shown on the chip and beside each menu row.
  IconData get icon => switch (this) {
        ResearchMode.fast => Icons.bolt_outlined,
        ResearchMode.thinking => Icons.psychology_outlined,
      };

  /// Short chip/menu label ("Fast" / "Thinking").
  String label(AppLocalizations l10n) => switch (this) {
        ResearchMode.fast => l10n.researchModeFast,
        ResearchMode.thinking => l10n.researchModeThinking,
      };

  /// One-line hint under the menu label ("Fastest answers" / "Deeper reasoning").
  String hint(AppLocalizations l10n) => switch (this) {
        ResearchMode.fast => l10n.researchModeFastHint,
        ResearchMode.thinking => l10n.researchModeThinkingHint,
      };

  /// The in-flight busy-row label ("Answering…" / "Thinking…"). The differing
  /// word also quietly signals the longer wait the Thinking tier takes.
  String busyLabel(AppLocalizations l10n) => switch (this) {
        ResearchMode.fast => l10n.researchBusyFast,
        ResearchMode.thinking => l10n.researchBusyThinking,
      };
}
