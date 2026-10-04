import 'package:flutter/material.dart';

import '../../../core/localization/l10n/app_localizations.dart';
import '../../../core/theme/app_typography.dart';

/// Where the loose tier starts: the results below match a similar spelling of
/// a Singlish query, not the typed one exactly.
class SimilarSpellingsDivider extends StatelessWidget {
  /// Zero where the list already provides the side gutter.
  final double horizontalPadding;

  const SimilarSpellingsDivider({super.key, this.horizontalPadding = 16});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 16, horizontalPadding, 4),
      child: Row(
        children: [
          Text(
            AppLocalizations.of(context).similarSpellings,
            style: context.typography.resultSubtitle,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Divider(
              color: theme.colorScheme.outlineVariant,
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }
}
