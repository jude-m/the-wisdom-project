import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/l10n/app_localizations.dart';
import '../../domain/entities/search/search_result.dart';
import '../../domain/entities/search/search_result_type.dart';
import '../providers/navigation_tree_provider.dart';
import '../providers/search_display_language_provider.dart';
import 'content_text_formatter.dart';

/// Resolves a [SearchResultType]'s localized label in the presentation layer.
///
/// The search tabs and their matching section sub-headers share this single
/// token, so both follow the locale. The enum itself (domain) stays pure; the
/// l10n lookup lives here. The canonical English strings live in `app_en.arb`
/// (e.g. `searchTabTitles`).
String searchResultTypeLabel(SearchResultType type, AppLocalizations l10n) =>
    switch (type) {
      SearchResultType.topResults => l10n.searchTabTopResults,
      SearchResultType.title => l10n.searchTabTitles,
      SearchResultType.fullText => l10n.searchTabFullText,
      SearchResultType.definition => l10n.searchTabDefinitions,
    };

/// A search result's display labels, rendered in the active Content Language.
///
/// - [title]: the matched sutta/section name.
/// - [path] : the navigation breadcrumb of its ancestors (root → parent).
typedef SearchResultLabels = ({String title, String path});

/// Re-derives a [SearchResult]'s [title] and navigation [path] in the active
/// Content Language, using the *same* tree-node pipeline as the breadcrumbs and
/// tree navigator. This is what keeps every **data label** (tree, breadcrumbs,
/// tabs, search) following the single Content Language setting.
///
/// Why not just use [SearchResult.title] / [SearchResult.subtitle]? The
/// repository tags each result with whichever language *matched the query*,
/// and builds the path in Pali only — so a Sinhala result can end up with a
/// Pali path, and searching a Pali word would force a Pali label even when the
/// user reads in Sinhala. Instead we look the node up by its
/// [SearchResult.nodeKey] and render its names in the chosen language, exactly
/// like `breadcrumbPathProvider` does.
///
/// Call this from inside a `ConsumerWidget.build`: it uses `ref.watch`, so the
/// tile re-renders the instant the language changes — even for results already
/// on screen.
///
/// The language comes from [effectiveSearchDisplayLanguageProvider], not the
/// raw Content Language: with both පාළි / සිංහල toggles on it *is* the reading
/// preference, but when the search is narrowed to one language the labels follow
/// that language so they contain the matched term.
///
/// Falls back to the repository-built strings when the node isn't in the tree
/// (e.g. dictionary results, which carry an empty `nodeKey`).
SearchResultLabels searchResultLabels(WidgetRef ref, SearchResult result) {
  final language = ref.watch(effectiveSearchDisplayLanguageProvider);

  // The result's own node. Null for dictionary results / unknown keys.
  final node = ref.watch(nodeByKeyProvider(result.nodeKey));
  if (node == null) {
    return (title: result.title, path: result.subtitle);
  }

  // Title: the node's own name, routed through the shared formatter (which
  // applies Pali conjunct ligatures only when the language is Pali).
  final title = formatContentLabel(node.getDisplayName(language), language);

  // Path: the node's ancestors. ancestorKeysProvider returns root → leaf
  // *including* the node itself, so we drop the last key — the title already
  // names the node, the path should show only what's above it.
  final keys = ref.watch(ancestorKeysProvider(result.nodeKey));
  final ancestorKeys =
      keys.length > 1 ? keys.sublist(0, keys.length - 1) : const <String>[];

  final path = ancestorKeys.map((key) {
    final ancestor = ref.watch(nodeByKeyProvider(key));
    return ancestor == null
        ? key
        : formatContentLabel(ancestor.getDisplayName(language), language);
  }).join(' > ');

  // Keep the repo-built path rather than an empty string for root-level nodes.
  return (title: title, path: path.isEmpty ? result.subtitle : path);
}
