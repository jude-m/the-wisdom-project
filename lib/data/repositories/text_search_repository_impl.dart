import 'dart:developer' as developer;
import 'dart:math' as math;
import 'package:dartz/dartz.dart';
import 'package:wisdom_shared/wisdom_shared.dart' show spellingCombinations;
import '../../domain/entities/failure.dart';
import '../../domain/entities/search/grouped_search_result.dart';
import '../../domain/entities/search/search_result_type.dart';
import '../../domain/entities/search/search_query.dart';
import '../../domain/entities/search/search_language_scope.dart';
import '../../domain/entities/search/search_result.dart';
import '../../domain/entities/search/scope_operations.dart';
import '../../domain/entities/navigation/tipitaka_tree_node.dart';
import '../../domain/entities/dictionary/dictionary_entry.dart';
import '../../domain/entities/dictionary/dictionary_info.dart';
import '../../domain/repositories/navigation_tree_repository.dart';
import '../../domain/repositories/dictionary_repository.dart';
import '../../core/utils/text_utils.dart';
import '../../domain/repositories/text_search_repository.dart';
import '../datasources/bjt_content_datasource.dart';
import '../datasources/fts_datasource.dart';

/// Implementation of TextSearchRepository using FTS database and navigation tree
/// Supports searching across multiple editions
class TextSearchRepositoryImpl implements TextSearchRepository {
  final FTSDataSource _ftsDataSource;
  final NavigationTreeRepository _treeRepository;
  final DictionaryRepository? _dictionaryRepository;

  /// Where snippet text comes from.
  final BJTContentDataSource _contentDataSource;

  TextSearchRepositoryImpl(
    this._ftsDataSource,
    this._treeRepository, {
    DictionaryRepository? dictionaryRepository,
    required BJTContentDataSource contentDataSource,
  })  : _dictionaryRepository = dictionaryRepository,
        _contentDataSource = contentDataSource;

  /// Overfetch multiplier for grouped results.
  /// We fetch more records than needed to ensure enough unique groups (nodeKeys).
  /// Example: For 3 groups, fetch 21 records (7x multiplier).
  ///
  /// Alternative considered: DB-level grouping using window functions:
  /// ```sql
  /// WITH ranked AS (
  ///   SELECT m.nodeKey, bm25(bjt_fts) AS score,
  ///     ROW_NUMBER() OVER (PARTITION BY m.nodeKey ORDER BY bm25(bjt_fts)) AS rn
  ///   FROM bjt_fts JOIN bjt_meta m ON bjt_fts.rowid = m.id
  ///   WHERE bjt_fts MATCH ?
  /// )
  /// SELECT nodeKey FROM ranked WHERE rn = 1 ORDER BY score LIMIT ?
  /// ```
  /// Overfetching chosen for better performance (single query, no window functions).
  static const int _groupedSearchOverfetchMultiplier = 7;

  /// Room Top Results keeps per category for the loose tier, so similar
  /// spellings stay visible however many lead results there are.
  static const int _maxLooseInTopResults = 2;

  /// The Top Results room for one category's loose tier: a few after its
  /// [lead] results, or all of it when the lead tier found nothing.
  static int _looseRoom(List<SearchResult> lead, int maxPerCategory) =>
      lead.isEmpty ? maxPerCategory : _maxLooseInTopResults;

  // ============================================================================
  // PUBLIC API
  // ============================================================================

  @override
  Future<Either<Failure, GroupedSearchResult>> searchTopResults(
    SearchQuery query, {
    int maxPerCategory = 3,
  }) async {
    try {
      // Defensive guard - StateNotifier should validate before calling
      if (query.queryText.trim().isEmpty) {
        return const Right(GroupedSearchResult(resultsByType: {
          SearchResultType.title: [],
          SearchResultType.fullText: [],
          SearchResultType.definition: [],
        }));
      }

      final editionsToSearch = query.editionsToSearch;

      final treeResult = await _treeRepository.loadNavigationTree();

      return await treeResult.fold(
        (failure) async => Left(failure),
        (tree) async {
          final nodeMap = _buildNodeMap(tree);
          final resultsByType = <SearchResultType, List<SearchResult>>{};

          // Derive the language scope ONCE; it drives both the title gating and
          // the FTS filter below — one source of truth for the two toggles.
          final languageScope = SearchLanguageScope.fromFlags(
            searchInPali: query.searchInPali,
            searchInSinhala: query.searchInSinhala,
          );
          // Similar spellings of a Singlish query, for the loose tier. Each
          // category below keeps room for them after its lead results.
          final looseSpellings = query.looseSpellings;

          // 1. Title matches (from navigation tree - in memory, fast)
          final titles = _searchTitles(
            nodeMap: nodeMap,
            queryText: query.leadText,
            editionId: 'bjt', // TODO: Support multiple editions
            scope: query.scope,
            isExactMatch: query.isExactMatch,
            languageScope: languageScope,
            looseSpellings: looseSpellings.words,
          );
          final leadTitles = titles
              .where((r) => !r.isLooseMatch)
              .take(maxPerCategory)
              .toList();
          resultsByType[SearchResultType.title] = [
            ...leadTitles,
            ...titles
                .where((r) => r.isLooseMatch)
                .take(_looseRoom(leadTitles, maxPerCategory)),
          ];

          // 2. Content matches (from FTS)
          // Overfetch to ensure enough unique groups (suttas) after grouping
          final overfetchLimit =
              maxPerCategory * _groupedSearchOverfetchMultiplier;
          final ftsResults = await _searchFullText(
            nodeMap: nodeMap,
            queryText: query.leadText,
            editionIds: editionsToSearch,
            scope: query.scope,
            isExactMatch: query.isExactMatch,
            isPhraseSearch: query.isPhraseSearch,
            isAnywhereInText: query.isAnywhereInText,
            proximityDistance: query.proximityDistance,
            language: _ftsLanguageFilter(languageScope),
            limit: overfetchLimit,
            offset: 0,
          );

          // Group by nodeKey and limit to maxPerCategory groups
          final leadGroups = _limitToGroups(
            ftsResults,
            maxGroups: maxPerCategory,
          );

          // The loose tier asked for separately: with many lead rows it
          // would never reach the overfetch window. Suttas already shown above
          // are left out, so the room goes to new ones.
          var looseGroups = const <SearchResult>[];
          if (looseSpellings.words.isNotEmpty) {
            final shown = {for (final r in leadGroups) r.nodeKey};
            final room = _looseRoom(leadGroups, maxPerCategory);
            final looseResults = await _searchFullText(
              nodeMap: nodeMap,
              queryText: query.leadText,
              editionIds: editionsToSearch,
              scope: query.scope,
              isExactMatch: query.isExactMatch,
              isPhraseSearch: query.isPhraseSearch,
              isAnywhereInText: query.isAnywhereInText,
              proximityDistance: query.proximityDistance,
              language: _ftsLanguageFilter(languageScope),
              looseSpellings: looseSpellings.words,
              looseOnly: true,
              limit: room * _groupedSearchOverfetchMultiplier,
              offset: 0,
            );
            looseGroups = _limitToGroups(
              [
                for (final r in looseResults)
                  if (!shown.contains(r.nodeKey)) r,
              ],
              maxGroups: room,
            );
          }
          resultsByType[SearchResultType.fullText] = [
            ...leadGroups,
            ...looseGroups,
          ];

          // 3. Definition matches (from dictionary), the strict query first
          // whatever leads above.
          final strictDefinitions = await _searchDefinitions(
            query.queryText,
            isExactMatch: query.isExactMatch,
            dictionaryIds: query.selectedDictionaryIds,
            limit: maxPerCategory,
          );
          resultsByType[SearchResultType.definition] = [
            ...strictDefinitions,
            if (looseSpellings.headwords.isNotEmpty)
              ...await _searchDefinitions(
                query.queryText,
                isExactMatch: query.isExactMatch,
                dictionaryIds: query.selectedDictionaryIds,
                looseSpellings: looseSpellings.headwords,
                looseOnly: true,
                limit: _looseRoom(strictDefinitions, maxPerCategory),
              ),
          ];

          return Right(GroupedSearchResult(
            resultsByType: resultsByType,
          ));
        },
      );
    } catch (e) {
      return Left(
        Failure.dataLoadFailure(
          message: 'Failed to perform categorized search',
          error: e,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, List<SearchResult>>> searchByResultType(
    SearchQuery query,
    SearchResultType resultType,
  ) async {
    try {
      // Defensive guard - StateNotifier should validate before calling
      if (query.queryText.trim().isEmpty) {
        return const Right([]);
      }

      final editionsToSearch = query.editionsToSearch;

      final treeResult = await _treeRepository.loadNavigationTree();

      return await treeResult.fold(
        (failure) async => Left(failure),
        (tree) async {
          final nodeMap = _buildNodeMap(tree);
          final languageScope = SearchLanguageScope.fromFlags(
            searchInPali: query.searchInPali,
            searchInSinhala: query.searchInSinhala,
          );

          // Every tab lists the lead results (definitions: the strict ones),
          // then the similar spellings.
          switch (resultType) {
            case SearchResultType.topResults:
              // "All" category should use searchCategorizedPreview instead
              // This case should not be reached via normal flow
              throw StateError(
                'Use searchTopResults for SearchResultType.topResults',
              );
            case SearchResultType.reference:
              // Reference jumps are resolved in-memory by
              // referenceSearchResultProvider, never via FTS (resolver plan,
              // Part C). Excluded from the tab bar, so this is unreachable.
              throw StateError(
                'SearchResultType.reference is not an FTS category',
              );
            case SearchResultType.title:
              return Right(_searchTitles(
                nodeMap: nodeMap,
                queryText: query.leadText,
                editionId: 'bjt',
                scope: query.scope,
                isExactMatch: query.isExactMatch,
                languageScope: languageScope,
                looseSpellings: query.looseSpellings.words,
                limit: query.limit,
              ));

            case SearchResultType.fullText:
              final results = await _searchFullText(
                nodeMap: nodeMap,
                queryText: query.leadText,
                editionIds: editionsToSearch,
                scope: query.scope,
                isExactMatch: query.isExactMatch,
                isPhraseSearch: query.isPhraseSearch,
                isAnywhereInText: query.isAnywhereInText,
                proximityDistance: query.proximityDistance,
                language: _ftsLanguageFilter(languageScope),
                looseSpellings: query.looseSpellings.words,
                limit: query.limit,
                offset: query.offset,
              );
              return Right(results);

            case SearchResultType.definition:
              // Dictionary search
              final results = await _searchDefinitions(
                query.queryText,
                isExactMatch: query.isExactMatch,
                dictionaryIds: query.selectedDictionaryIds,
                looseSpellings: query.looseSpellings.headwords,
                limit: query.limit,
                offset: query.offset,
              );
              return Right(results);
          }
        },
      );
    } catch (e) {
      return Left(
        Failure.dataLoadFailure(
          message: 'Failed to search by type',
          error: e,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, Map<SearchResultType, int>>> countByResultType(
    SearchQuery query,
  ) async {
    try {
      // Defensive guard - StateNotifier should validate before calling
      if (query.queryText.trim().isEmpty) {
        return const Right({
          SearchResultType.title: 0,
          SearchResultType.fullText: 0,
          SearchResultType.definition: 0,
        });
      }

      final editionsToSearch = query.editionsToSearch;

      final treeResult = await _treeRepository.loadNavigationTree();

      return await treeResult.fold(
        (failure) async => Left(failure),
        (tree) async {
          final nodeMap = _buildNodeMap(tree);
          final count = <SearchResultType, int>{};
          final languageScope = SearchLanguageScope.fromFlags(
            searchInPali: query.searchInPali,
            searchInSinhala: query.searchInSinhala,
          );
          // Counts cover both tiers, as the tabs list them.
          final looseSpellings = query.looseSpellings;

          // Title count (from navigation tree - in memory, fast)
          count[SearchResultType.title] = _searchTitles(
            nodeMap: nodeMap,
            queryText: query.leadText,
            editionId: 'bjt',
            scope: query.scope,
            isExactMatch: query.isExactMatch,
            languageScope: languageScope,
            looseSpellings: looseSpellings.words,
          ).length;

          // Content count (efficient SQL COUNT) — same language filter as the
          // FTS search above, so the tab badge matches the rows shown.
          count[SearchResultType.fullText] =
              await _ftsDataSource.countFullTextMatches(
            query.leadText,
            editionId: editionsToSearch.first,
            scope: query.scope,
            isExactMatch: query.isExactMatch,
            isPhraseSearch: query.isPhraseSearch,
            isAnywhereInText: query.isAnywhereInText,
            proximityDistance: query.proximityDistance,
            language: _ftsLanguageFilter(languageScope),
            looseSpellings: looseSpellings.words,
          );

          // Definition count (from dictionary)
          count[SearchResultType.definition] = await _countDefinitions(
            query.queryText,
            isExactMatch: query.isExactMatch,
            dictionaryIds: query.selectedDictionaryIds,
            looseSpellings: looseSpellings.headwords,
          );

          return Right(count);
        },
      );
    } catch (e) {
      return Left(
        Failure.dataLoadFailure(
          message: 'Failed to get count by result type',
          error: e,
        ),
      );
    }
  }

  // ============================================================================
  // PRIVATE HELPER METHODS - Search Logic
  // ============================================================================

  /// Search for title matches in navigation tree names
  /// Returns results sorted with leaf nodes (individual suttas) first
  /// Prefers Sinhala name if both languages match
  /// Supports Singlish (romanized Sinhala) transliteration search
  ///
  /// When [isExactMatch] is false (default), uses prefix matching (startsWith).
  /// When [isExactMatch] is true, requires exact string match.
  ///
  /// [scope] - Tree node keys (e.g., 'sp', 'dn', 'dn-1') for filtering.
  /// Empty set = search all content.
  ///
  /// [languageScope] - The පාළි / සිංහල toggle as a single derived scope. A name
  /// field is only tested when the scope includes that language, so narrowing to
  /// one language drops results that matched only the *other* language's name.
  ///
  /// [looseSpellings] - Similar spellings of each word of a Singlish query,
  /// in search order. Names only they match follow the [queryText] results,
  /// flagged `isLooseMatch`, those of a more common spelling first. They must
  /// start a word of the name: inside a compound, a similar spelling is
  /// mostly noise.
  List<SearchResult> _searchTitles({
    required Map<String, TipitakaTreeNode> nodeMap,
    required String queryText,
    required String editionId,
    Set<String> scope = const {},
    bool isExactMatch = false,
    SearchLanguageScope languageScope = SearchLanguageScope.both,
    List<List<String>> looseSpellings = const [],
    int? limit,
  }) {
    final results = <SearchResult>[];

    // Normalize query for matching (caller handles Singlish conversion)
    final searchQuery = normalizeText(queryText, toLowerCase: true);

    // The loose tier's queries: each combination of spellings, as one string
    // like [queryText], in search order.
    final looseQueries = looseSpellings.isEmpty
        ? const <String>[]
        : [
            for (final words in spellingCombinations(looseSpellings))
              normalizeText(words.join(' '), toLowerCase: true),
          ];

    // Get scope patterns for filtering
    final scopePatterns = ScopeOperations.getPatternsForScope(scope);

    // Helper function to check if a name matches a query
    // isExactMatch=false: contains matching (includes startsWith), or with
    //   [atWordStart] only where a word of the name starts
    // isExactMatch=true: word boundary match (query appears as complete word)
    bool matchesQuery(String name, String query, {bool atWordStart = false}) {
      if (isExactMatch) {
        // Word boundary match: query must appear as a complete word
        return name == query ||
            name.startsWith('$query ') ||
            name.endsWith(' $query') ||
            name.contains(' $query ');
      }
      if (!atWordStart) return name.contains(query);
      for (var i = name.indexOf(query);
          i != -1;
          i = name.indexOf(query, i + 1)) {
        if (i == 0 || !_isWordCharacter(name.codeUnitAt(i - 1))) return true;
      }
      return false;
    }

    // Where [name] stands in the loose tier: the first loose query it
    // matches, or null for none.
    int? looseRank(String name) {
      final rank = looseQueries
          .indexWhere((query) => matchesQuery(name, query, atWordStart: true));
      return rank == -1 ? null : rank;
    }

    final looseRanks = <String, int>{}; // by nodeKey

    // Helper function to check if contentFileId matches any scope pattern
    // Patterns from getPatternsForScope are prefix-only (e.g., 'dn-')
    // SQL LIKE wildcard (%) is added by the service layer, not here
    bool matchesScope(String? contentFileId) {
      if (scopePatterns.isEmpty) return true; // No filter = match all
      if (contentFileId == null) return false;
      return scopePatterns.any((pattern) => contentFileId.startsWith(pattern));
    }

    for (final node in nodeMap.values) {
      final paliName =
          normalizeText(node.paliName, toLowerCase: true).replaceAll('.', '');
      final sinhalaName = normalizeText(node.sinhalaName, toLowerCase: true)
          .replaceAll('.', '');

      // Match normalized query against each name, but only when the language
      // scope includes that language. Narrowed to one language, a node that
      // matched only the other language's name is excluded.
      // (both → both true; pali → only pali; sinhala → only sinhala.)
      final searchPali = languageScope != SearchLanguageScope.sinhala;
      final searchSinhala = languageScope != SearchLanguageScope.pali;
      var paliMatched = searchPali && matchesQuery(paliName, searchQuery);
      var sinhalaMatched =
          searchSinhala && matchesQuery(sinhalaName, searchQuery);

      // No match for [queryText]: try the similar spellings (the loose tier).
      var isLooseMatch = false;
      if (!paliMatched && !sinhalaMatched && looseQueries.isNotEmpty) {
        final paliRank = searchPali ? looseRank(paliName) : null;
        final sinhalaRank = searchSinhala ? looseRank(sinhalaName) : null;
        paliMatched = paliRank != null;
        sinhalaMatched = sinhalaRank != null;
        isLooseMatch = paliMatched || sinhalaMatched;
        if (isLooseMatch) {
          looseRanks[node.nodeKey] = math.min(
            paliRank ?? looseQueries.length,
            sinhalaRank ?? looseQueries.length,
          );
        }
      }

      // Check both name match AND scope match
      if ((paliMatched || sinhalaMatched) &&
          node.contentFileId != null &&
          matchesScope(node.contentFileId)) {
        // Prefer Sinhala if it matched, otherwise use Pali
        final matchedName = sinhalaMatched
            ? (node.sinhalaName.isNotEmpty ? node.sinhalaName : node.paliName)
            : (node.paliName.isNotEmpty ? node.paliName : node.sinhalaName);
        final matchedLanguage = sinhalaMatched ? 'sinhala' : 'pali';

        results.add(
          SearchResult(
            id: 'title_${node.nodeKey}',
            editionId: editionId,
            resultType: SearchResultType.title,
            title: matchedName,
            subtitle: _buildNavigationPath(node, nodeMap),
            matchedText: matchedName,
            contentFileId: node.contentFileId!, // Safe: checked above
            pageIndex: node.entryPageIndex,
            entryIndex: node.entryIndexInPage,
            nodeKey: node.nodeKey,
            language: matchedLanguage,
            isLooseMatch: isLooseMatch,
          ),
        );
      }
    }

    // Whether the title starts with what it matched: the query, or (loose
    // tier) one of its similar spellings.
    bool startsWithQuery(SearchResult result) {
      final title =
          normalizeText(result.title, toLowerCase: true).replaceAll('.', '');
      return result.isLooseMatch
          ? looseQueries.any(title.startsWith)
          : title.startsWith(searchQuery);
    }

    // Sort with three criteria:
    // 1. Query matches before similar spellings (the loose tier), and those
    //    in search order
    // 2. startsWith matches before contains-only matches
    // 3. Leaf nodes (individual suttas) before parent nodes
    results.sort((a, b) {
      if (a.isLooseMatch != b.isLooseMatch) return a.isLooseMatch ? 1 : -1;
      final byRank =
          (looseRanks[a.nodeKey] ?? 0).compareTo(looseRanks[b.nodeKey] ?? 0);
      if (byRank != 0) return byRank;

      // Then startsWith first
      final aStartsWith = startsWithQuery(a);
      final bStartsWith = startsWithQuery(b);

      if (aStartsWith && !bStartsWith) return -1;
      if (!aStartsWith && bStartsWith) return 1;

      // Secondary sort: leaf nodes first
      final nodeA = nodeMap[a.nodeKey];
      final nodeB = nodeMap[b.nodeKey];
      final isLeafA = nodeA?.isLeafNode ?? true;
      final isLeafB = nodeB?.isLeafNode ?? true;

      if (isLeafA && !isLeafB) return -1;
      if (!isLeafA && isLeafB) return 1;
      return 0;
    });

    return limit != null ? results.take(limit).toList() : results;
  }

  /// Whether [codeUnit] belongs inside a word: a Sinhala letter or sign, a
  /// Latin letter or a digit (names are lowercased before matching).
  static bool _isWordCharacter(int codeUnit) =>
      (codeUnit >= 0x0D80 && codeUnit <= 0x0DFF) ||
      (codeUnit >= 0x61 && codeUnit <= 0x7A) ||
      (codeUnit >= 0x30 && codeUnit <= 0x39);

  /// Search for content matches using FTS database
  /// Always loads matched text from JSON files for display
  ///
  /// [scope] - Tree node keys (e.g., 'sp', 'dn', 'dn-1') for filtering.
  /// Empty set = search all content.
  ///
  /// [isPhraseSearch] - true for phrase matching (consecutive/adjacent words),
  /// false for separate-word search (words within proximity).
  ///
  /// [isAnywhereInText] - When true and isPhraseSearch is false, ignores
  /// proximity distance and searches anywhere in the text.
  ///
  /// [proximityDistance] - Distance for NEAR/n proximity (1-100).
  /// Only used when isPhraseSearch is false and isAnywhereInText is false.
  Future<List<SearchResult>> _searchFullText({
    required Map<String, TipitakaTreeNode> nodeMap,
    required String queryText,
    required Set<String> editionIds,
    Set<String> scope = const {},
    bool isExactMatch = false,
    bool isPhraseSearch = true,
    bool isAnywhereInText = false,
    int proximityDistance = 10,
    String? language,
    List<List<String>> looseSpellings = const [],
    bool looseOnly = false,
    int? limit,
    int offset = 0,
  }) async {
    final ftsMatches = await _ftsDataSource.searchFullText(
      queryText,
      editionIds: editionIds,
      scope: scope,
      isExactMatch: isExactMatch,
      isPhraseSearch: isPhraseSearch,
      isAnywhereInText: isAnywhereInText,
      proximityDistance: proximityDistance,
      language: language,
      looseSpellings: looseSpellings,
      looseOnly: looseOnly,
      limit: limit ?? 50,
      offset: offset,
    );

    // FTS rows carry only metadata (filename, eind, language) — not the snippet
    // text the result preview needs. That text comes out of `bjt_content`: one
    // batched query for every hit's page here, BEFORE the loop, so a page of
    // results costs one round trip rather than a file read each.
    //
    // Both language sides of a page are asked for, because a snippet falls
    // back to the other language when the matched one carries no text at that
    // entry — the order the JSON loader used, kept so snippets do not move.
    final wanted = <ContentPageKey>{};
    for (final match in ftsMatches) {
      final pageIndex = int.parse(match.eind.split('-')[0]);
      for (final language in _snippetLanguages) {
        wanted.add((
          fileId: match.filename,
          pageIndex: pageIndex,
          language: language,
        ));
      }
    }
    // A whole-query failure — a database that will not open, say — costs the
    // snippets and nothing else. Losing the previews is survivable; losing the
    // results because of them is not, and the JSON loader degraded the same
    // way. Single bad rows are already left out inside loadPageSides.
    var pageSides = const <ContentPageKey, Map<String, dynamic>>{};
    if (wanted.isNotEmpty) {
      try {
        pageSides = await _contentDataSource.loadPageSides(wanted);
      } catch (e, stackTrace) {
        developer.log(
          'Failed to read snippet text for ${wanted.length} page sides',
          error: e,
          stackTrace: stackTrace,
          name: 'TextSearchRepository',
        );
      }
    }

    final results = <SearchResult>[];

    for (final match in ftsMatches) {
      // Parse match position from eind (format: "pageIndex-entryIndex")
      final eindParts = match.eind.split('-');
      final pageIndex = int.parse(eindParts[0]);
      final entryIndex = int.parse(eindParts[1]);

      // Direct O(1) lookup using nodeKey stored in database
      // nodeKey was computed at FTS build time to identify the containing sutta
      final node = nodeMap[match.nodeKey];

      if (node != null) {
        // The entry in one of the two rows fetched for its page, or '' when
        // it is unavailable — a missing or corrupt row degrades only its own
        // hit and never fails the search.
        final matchedText = _entryTextFrom(
              pageSides,
              match.filename,
              pageIndex,
              entryIndex,
              match.language,
            ) ??
            '';

        // Prefer Sinhala title if language is sinh, otherwise use Pali
        final title = match.language == 'sinh'
            ? (node.sinhalaName.isNotEmpty ? node.sinhalaName : node.paliName)
            : (node.paliName.isNotEmpty ? node.paliName : node.sinhalaName);

        // Normalize language: FTS uses 'sinh' but app uses 'sinhala'
        final normalizedLanguage =
            match.language == 'sinh' ? 'sinhala' : match.language;

        results.add(
          SearchResult(
            id: '${match.editionId}_${match.filename}_${match.eind}',
            editionId: match.editionId,
            resultType: SearchResultType.fullText,
            title: title,
            subtitle: _buildNavigationPath(node, nodeMap),
            matchedText: matchedText,
            contentFileId: match.filename,
            pageIndex: pageIndex,
            entryIndex: entryIndex,
            nodeKey: node.nodeKey,
            language: normalizedLanguage,
            relevanceScore: match.relevanceScore,
            isLooseMatch: match.isLooseMatch,
          ),
        );
      }
    }

    return results;
  }

  // ============================================================================
  // PRIVATE HELPER METHODS - Utilities
  // ============================================================================

  /// Maps a [SearchLanguageScope] to the FTS `language` filter value (the DB
  /// code). This is the ONE place the DB codes live; the scope enum itself
  /// stays database-agnostic so the presentation layer can reuse it.
  ///
  /// - [SearchLanguageScope.both]    → null  (search both languages — default)
  /// - [SearchLanguageScope.pali]    → 'pali'
  /// - [SearchLanguageScope.sinhala] → 'sinh'  (DB stores Sinhala as 'sinh')
  String? _ftsLanguageFilter(SearchLanguageScope scope) => switch (scope) {
        SearchLanguageScope.both => null,
        SearchLanguageScope.pali => 'pali',
        SearchLanguageScope.sinhala => 'sinh',
      };

  /// Limits results to maxGroups unique nodeKeys (suttas).
  /// Returns all results belonging to the first maxGroups groups.
  ///
  /// Used by Top Results tab to ensure we show 3 distinct suttas,
  /// even when multiple FTS matches come from the same sutta.
  List<SearchResult> _limitToGroups(
    List<SearchResult> results, {
    required int maxGroups,
  }) {
    final seenNodeKeys = <String>{};
    final limitedResults = <SearchResult>[];

    for (final result in results) {
      // Include result if:
      // 1. We haven't reached maxGroups yet, OR
      // 2. This result belongs to a nodeKey we've already seen
      if (seenNodeKeys.length < maxGroups ||
          seenNodeKeys.contains(result.nodeKey)) {
        limitedResults.add(result);
        seenNodeKeys.add(result.nodeKey);
      }
    }

    return limitedResults;
  }

  /// Build a flat map of nodeKey -> node from tree hierarchy
  /// Allows O(1) lookup of nodes by their key
  Map<String, TipitakaTreeNode> _buildNodeMap(List<TipitakaTreeNode> tree) {
    final nodeMap = <String, TipitakaTreeNode>{};

    void traverse(TipitakaTreeNode node) {
      nodeMap[node.nodeKey] = node;
      for (final child in node.childNodes) {
        traverse(child);
      }
    }

    for (final root in tree) {
      traverse(root);
    }

    return nodeMap;
  }

  /// Duplicates parent-walk logic from ancestorKeysProvider (presentation layer).
  /// Can't share because this data-layer class has no Riverpod Ref.
  /// If this grows complex, extract to a shared utility in core/utils/tree_utils.dart.
  /// Build a navigation path string from a node
  /// e.g., "Dīgha Nikāya > Sīlakkhandhavagga"
  String _buildNavigationPath(
    TipitakaTreeNode node,
    Map<String, TipitakaTreeNode> nodeMap,
  ) {
    final parts = <String>[];
    TipitakaTreeNode? current = node;

    while (current != null && current.parentNodeKey != null) {
      final parent = nodeMap[current.parentNodeKey];
      if (parent != null) {
        parts.insert(0,
            parent.paliName.isNotEmpty ? parent.paliName : parent.sinhalaName);
        current = parent;
      } else {
        break;
      }
    }

    return parts.join(' > ');
  }

  /// The two language sides a snippet may come from, in the table's spelling.
  static const List<String> _snippetLanguages = ['pali', 'sinh'];

  /// Picks one entry's text out of the rows fetched for its page.
  ///
  /// Pure: the rows are already inflated, so this is index arithmetic. The
  /// matched language is tried first and the other as a fallback — the order
  /// the JSON loader used, so snippets are byte-for-byte what they were.
  ///
  /// [language] is spelled the way `bjt_content` and FTS matches spell it
  /// (`pali`/`sinh`). `SearchResult`'s `sinhala` is a different vocabulary and
  /// would miss every Sinhala row.
  static String? _entryTextFrom(
    Map<ContentPageKey, Map<String, dynamic>> sides,
    String fileId,
    int pageIndex,
    int entryIndex,
    String language,
  ) {
    final order =
        language == 'pali' ? _snippetLanguages : _snippetLanguages.reversed;
    for (final lang in order) {
      final side =
          sides[(fileId: fileId, pageIndex: pageIndex, language: lang)];
      final entries = side?['entries'] as List<dynamic>?;
      if (entries != null && entryIndex < entries.length) {
        final entry = entries[entryIndex] as Map<String, dynamic>;
        final text = entry['text'] as String?;
        if (text != null && text.isNotEmpty) return text;
      }
    }
    return null;
  }

  // ============================================================================
  // PRIVATE HELPER METHODS - Dictionary Search
  // ============================================================================

  /// Search definitions from dictionary
  /// Returns SearchResult objects for integration with the search UI
  Future<List<SearchResult>> _searchDefinitions(
    String queryText, {
    bool isExactMatch = false,
    Set<String> dictionaryIds = const {},
    List<String> looseSpellings = const [],
    bool looseOnly = false,
    int limit = 50,
    int offset = 0,
  }) async {
    if (_dictionaryRepository == null) {
      return [];
    }

    final result = await _dictionaryRepository.searchDefinitions(
      queryText,
      isExactMatch: isExactMatch,
      dictionaryIds: dictionaryIds,
      looseSpellings: looseSpellings,
      looseOnly: looseOnly,
      limit: limit,
      offset: offset,
    );

    return result.fold(
      (failure) {
        developer.log(
          'Dictionary search failed: ${failure.userMessage}',
          name: 'TextSearchRepository',
        );
        return <SearchResult>[];
      },
      (entries) => entries.map(_mapDictionaryEntryToSearchResult).toList(),
    );
  }

  /// Count definition matches from dictionary
  Future<int> _countDefinitions(
    String queryText, {
    bool isExactMatch = false,
    Set<String> dictionaryIds = const {},
    List<String> looseSpellings = const [],
  }) async {
    if (_dictionaryRepository == null) {
      return 0;
    }

    final result = await _dictionaryRepository.countDefinitions(
      queryText,
      isExactMatch: isExactMatch,
      dictionaryIds: dictionaryIds,
      looseSpellings: looseSpellings,
    );

    return result.fold(
      (failure) {
        developer.log(
          'Dictionary count failed: ${failure.userMessage}',
          name: 'TextSearchRepository',
        );
        return 0;
      },
      (count) => count,
    );
  }

  /// Maps a DictionaryEntry to SearchResult for UI integration
  SearchResult _mapDictionaryEntryToSearchResult(DictionaryEntry entry) {
    return SearchResult(
      id: 'dict_${entry.id}',
      editionId: entry.dictionaryId,
      resultType: SearchResultType.definition,
      title: entry.word,
      subtitle: DictionaryInfo.getDisplayName(entry.dictionaryId),
      matchedText: entry.meaning,
      contentFileId: '', // Dictionary entries don't have content files
      pageIndex: 0,
      entryIndex: 0,
      nodeKey: '', // Dictionary entries don't have node keys
      language: entry.sourceLanguage,
      relevanceScore: entry.relevanceScore,
      isLooseMatch: entry.isLooseMatch,
    );
  }
}
