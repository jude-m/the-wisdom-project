import 'package:flutter/material.dart';

import '../../../core/utils/string_extensions.dart';
import '../../../domain/entities/dictionary/dictionary_info.dart';
import '../../../domain/entities/search/search_result.dart';

/// A search result tile for dictionary definition results.
///
/// Displays the word, dictionary name, and a truncated HTML meaning.
class DictionarySearchResultTile extends StatelessWidget {
  /// The search result (must be of type definition)
  final SearchResult result;

  /// Callback when the tile is tapped
  final VoidCallback? onTap;

  const DictionarySearchResultTile({
    super.key,
    required this.result,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dictInfo = DictionaryInfo.getById(result.editionId);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: DictionaryInfo.getColor(result.editionId, theme).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            dictInfo?.abbreviation ?? result.editionId,
            style: theme.textTheme.labelSmall?.copyWith(
              color: DictionaryInfo.getColor(result.editionId, theme),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      title: Text(
        result.title, // The word
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(
            result.subtitle, // Dictionary name
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          // Truncated meaning (strip HTML using extension method)
          Text(
            result.matchedText.stripHtml(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}
