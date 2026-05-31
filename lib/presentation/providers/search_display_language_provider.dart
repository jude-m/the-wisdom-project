import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/content/content_language.dart';
import '../../domain/entities/search/search_language_scope.dart';
import 'content_language_provider.dart';
import 'search_provider.dart';

/// The Content Language that **search-result labels** (the title + breadcrumb
/// path on each result tile) should be rendered in.
///
/// Normally this is the global [effectiveContentLanguageProvider] — your reading
/// preference. But when you narrow the search to a *single* language with the
/// පාළි / සිංහල toggles in the refine dialog, the labels follow **that** language
/// instead. That way a narrowed search always shows titles in the language it
/// actually searched, so the title visibly contains your query term (and it
/// agrees with the FTS snippet, which is verbatim in that same language). With
/// both toggles on (the default) it falls back to the reading preference.
///
/// Scope: only the search-results panel reads this. The tree, breadcrumbs and
/// reader tabs keep using [effectiveContentLanguageProvider] directly — so a
/// title here can legitimately differ from the same node elsewhere while a
/// one-language filter is active. That divergence is intended: it reflects an
/// explicit search filter the user set.
final effectiveSearchDisplayLanguageProvider = Provider<ContentLanguage>((ref) {
  // `.select` so this only recomputes when the two flags change, not on every
  // keystroke / result update in the search state.
  final pali = ref.watch(searchStateProvider.select((s) => s.searchInPali));
  final sinhala =
      ref.watch(searchStateProvider.select((s) => s.searchInSinhala));

  // Same derived scope the repo uses, so labels and search can't disagree.
  final scope = SearchLanguageScope.fromFlags(
    searchInPali: pali,
    searchInSinhala: sinhala,
  );
  return switch (scope) {
    // Narrowed to exactly one language → that language drives the labels.
    SearchLanguageScope.pali => ContentLanguage.pali,
    SearchLanguageScope.sinhala => ContentLanguage.sinhala,
    // Both on (or, defensively, both off) → the global reading preference.
    SearchLanguageScope.both => ref.watch(effectiveContentLanguageProvider),
  };
});
