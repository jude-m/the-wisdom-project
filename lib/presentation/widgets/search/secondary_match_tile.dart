import 'package:flutter/material.dart';

import '../../../domain/entities/search/search_result.dart';
import '../../../domain/entities/search/search_result_type.dart';
import '../../providers/fts_highlight_provider.dart';
import 'highlighted_fts_search_text.dart';

/// A compact, muted tile for displaying secondary FTS matches.
///
/// Used within [GroupedFTSTile] to show additional matches from the same text.
/// Has a simpler design than the primary tile:
/// - No edition badge (already shown in parent)
/// - Smaller padding
/// - Just the highlighted matched text
class SecondaryMatchTile extends StatelessWidget {
  /// The search result to display
  final SearchResult result;

  /// What to highlight in the matched text
  final FtsHighlightState highlight;

  /// Callback when the tile is tapped
  final VoidCallback? onTap;

  const SecondaryMatchTile({
    super.key,
    required this.result,
    required this.highlight,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Show highlighted text for fullText results
            if (result.resultType == SearchResultType.fullText &&
                result.matchedText.isNotEmpty)
              HighlightedFtsSearchText(
                matchedText: result.matchedText,
                highlight: highlight,
                language: result.language,
              ),
          ],
        ),
      ),
    );
  }
}
