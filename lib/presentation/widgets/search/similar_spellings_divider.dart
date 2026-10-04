import 'package:flutter/material.dart';

import '../../../core/localization/l10n/app_localizations.dart';
import '../../../core/theme/app_typography.dart';

/// Where the loose tier starts: the results below match a similar spelling of
/// a Singlish query, not the one leading the list (the typed one, unless a
/// far more common spelling outranks it).
class SimilarSpellingsDivider extends StatelessWidget {
  const SimilarSpellingsDivider({super.key});

  /// [tile] for `items[index]`, below the divider when that item is the
  /// first of the loose tier.
  static Widget aboveFirstLoose<T>(
    List<T> items,
    int index,
    bool Function(T item) isLoose,
    Widget tile,
  ) {
    final startsLoose =
        isLoose(items[index]) && (index == 0 || !isLoose(items[index - 1]));
    if (!startsLoose) return tile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [const SimilarSpellingsDivider(), tile],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
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
