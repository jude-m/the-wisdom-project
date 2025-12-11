import 'package:freezed_annotation/freezed_annotation.dart';
import 'search_category.dart';

part 'search_result.freezed.dart';

/// Represents a single search result
@freezed
class SearchResult with _$SearchResult {
  const factory SearchResult({
    /// Unique identifier for this result
    required String id,

    /// Edition this result came from (e.g., 'bjt', 'sc')
    required String editionId,

    /// Category this result belongs to (title, content, or definition)
    required SearchCategory category,

    /// Title of the sutta/document
    required String title,

    /// Subtitle showing the navigation path (e.g., "Dīgha Nikāya > Sīlakkhandhavagga")
    required String subtitle,

    /// The actual text that matched the search query
    required String matchedText,

    /// Text before the match (for context preview)
    @Default('') String contextBefore,

    /// Text after the match (for context preview)
    @Default('') String contextAfter,

    /// File ID for navigation (e.g., "dn-1")
    required String contentFileId,

    /// Page index where the match is located
    required int pageIndex,

    /// Entry index within the page
    required int entryIndex,

    /// Reference to the tree node
    required String nodeKey,

    /// Language of the matched text
    required String language,

    /// Relevance score for ranking (optional)
    double? relevanceScore,
  }) = _SearchResult;
}
