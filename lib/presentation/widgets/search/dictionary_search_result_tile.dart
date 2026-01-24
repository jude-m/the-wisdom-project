import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
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
    final typography = context.typography;
    final dictInfo = DictionaryInfo.getById(result.editionId);
    final dictColor = DictionaryInfo.getColor(result.editionId, theme);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: dictColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            dictInfo?.abbreviation ?? result.editionId,
            style: typography.badgeLabel.copyWith(color: dictColor),
          ),
        ),
      ),
      title: Text(
        result.title, // The word
        style: typography.resultTitle.copyWith(fontWeight: FontWeight.w600),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(
            result.subtitle, // Dictionary name
            style: typography.resultSubtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          // Truncated meaning (strip HTML using extension method)
          Text(
            result.matchedText.stripHtml(),
            style: typography.resultMatchedText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}
