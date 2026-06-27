import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wisdom_shared/wisdom_shared.dart';

import '../../data/datasources/suttacentral_concordance_datasource.dart';
import '../../domain/entities/search/search_result.dart';
import '../../domain/entities/search/search_result_type.dart';
import 'navigation_tree_provider.dart';
import 'search_provider.dart';

/// Datasource that loads the committed SuttaCentral→BJT concordance asset.
final suttaCentralConcordanceDataSourceProvider =
    Provider<SuttaCentralConcordanceDataSource>(
  (ref) => SuttaCentralConcordanceDataSourceImpl(),
);

/// The pure [SuttaCentralRefResolver], built once from the loaded concordance.
///
/// Async because the asset load is async. Consumers treat "not loaded yet" (or
/// a load error) as "no reference search" — FTS keeps working regardless, so
/// the reference feature degrades to nothing rather than blocking search.
final suttaCentralRefResolverProvider =
    FutureProvider<SuttaCentralRefResolver>((ref) async {
  final map = await ref.watch(suttaCentralConcordanceDataSourceProvider).load();
  return SuttaCentralRefResolver(map);
});

/// A single, high-priority "jump to this sutta" hit, produced when the current
/// search query is a canonical reference (e.g. "SN 15.3") that resolves to a
/// readable BJT node.
///
/// Returns `null` when the query isn't a reference, the concordance hasn't
/// loaded, the uid isn't mapped, or the node isn't readable content. This is a
/// pure in-memory lookup — it issues **no** database query, so it adds zero load
/// to the FTS path (resolver plan, "SQLite strategy").
///
/// The result carries the resolved node's own navigation coordinates
/// (`contentFileId` / `pageIndex` / `entryIndex`), so a tap reuses the exact
/// same open-in-tab path as every other [SearchResult] — no special-case
/// navigation wiring.
final referenceSearchResultProvider = Provider<SearchResult?>((ref) {
  final query = ref.watch(searchStateProvider.select((s) => s.rawQueryText));
  if (query.trim().isEmpty) return null;

  // valueOrNull is null while the asset is still loading or if it failed.
  final resolver = ref.watch(suttaCentralRefResolverProvider).valueOrNull;
  if (resolver == null) return null;

  final uid = SuttaCentralRefResolver.parseRef(query);
  if (uid == null) return null;

  final nodeKey = resolver.nodeKeyForUid(uid);
  if (nodeKey == null) return null;

  final node = ref.watch(nodeByKeyProvider(nodeKey));
  if (node == null || !node.isReadableContent) return null;

  return SearchResult(
    id: 'ref:$uid',
    editionId: 'bjt',
    resultType: SearchResultType.reference,
    // The display reference ("SN 15.3") is shown as the leading badge; the tile
    // re-derives the actual sutta name + path from nodeKey via searchResultLabels.
    title: SuttaCentralRefResolver.displayRef(uid),
    subtitle: '',
    matchedText: '',
    contentFileId: node.contentFileId ?? '', // readable ⇒ non-null
    pageIndex: node.entryPageIndex,
    entryIndex: node.entryIndexInPage,
    nodeKey: nodeKey,
    language: '',
  );
});
