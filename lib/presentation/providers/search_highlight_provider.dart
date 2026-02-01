import 'package:flutter_riverpod/flutter_riverpod.dart';

/// State for highlighting search terms in the reader after clicking an FTS result.
///
/// This is transient UI state that is:
/// - Set when opening a tab from a search result
/// - Cleared when the user taps anywhere in the reader
///
/// Separate from dictionary highlight (which uses `highlightStateProvider`).
class SearchHighlightState {
  /// The search query text (already sanitized + Singlish converted).
  final String queryText;

  /// Phrase mode: words must appear adjacent. Otherwise within proximity.
  final bool isPhraseSearch;

  /// Exact mode: exact token match. Otherwise prefix matching.
  final bool isExactMatch;

  const SearchHighlightState({
    required this.queryText,
    required this.isPhraseSearch,
    required this.isExactMatch,
  });
}

/// Holds search highlight state for the reader.
///
/// When non-null, search terms should be highlighted in the reader.
/// Set to null to clear highlighting (e.g., on tap).
final searchHighlightProvider = StateProvider<SearchHighlightState?>((ref) => null);
