import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/theme/dictionary_badge_theme.dart';
import '../../../core/utils/pali_conjunct_transformer.dart';
import '../../../core/utils/string_extensions.dart';
import '../../../domain/entities/dictionary/dictionary_info.dart';
import '../../../domain/entities/search/search_result.dart';
import '../../providers/pali_letter_options_provider.dart';
import '../dictionary/dpd_read_more_link.dart';
import 'result_badge.dart';

/// A search result tile for dictionary definition results.
///
/// Displays the word, dictionary name, and a truncated HTML meaning.
class DictionarySearchResultTile extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final typography = context.typography;
    // Dictionary words are always Pali, but still gated by the switches so the
    // tile matches the rest of the app's rendering.
    final options = ref.watch(paliLetterOptionsProvider);
    final dictInfo = DictionaryInfo.getById(result.editionId);
    // Badge colour from the theme's shared dictionary badge palette.
    final dictColor = context.dictionaryBadgeColors
        .colorFor(result.editionId, theme.colorScheme.primary);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
          horizontal: ResultBadge.rowPadding, vertical: 8),
      leading: ResultBadge(
        label: dictInfo?.abbreviation ?? result.editionId,
        backgroundColor: dictColor.withValues(alpha: 0.15),
        labelColor: dictColor,
      ),
      title: Text(
        result.title.withPaliLetters(options),
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
          // "Read more" link for DPD dictionary entries
          if (result.editionId == 'DPD')
            DpdReadMoreLink(
              html: result.matchedText,
              baseStyle: typography.resultMatchedText,
              padding: const EdgeInsets.only(top: 4),
            ),
        ],
      ),
      onTap: onTap,
    );
  }
}
