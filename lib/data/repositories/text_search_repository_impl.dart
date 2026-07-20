import 'dart:convert';
import 'dart:developer' as developer;
import 'package:dartz/dartz.dart';
import 'package:flutter/services.dart';
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
import '../cache/lru_cache.dart';
import '../datasources/fts_datasource.dart';

/// Implementation of TextSearchRepository using FTS database and navigation tree
/// Supports searching across multiple editions
class TextSearchRepositoryImpl implements TextSearchRepository {
  final FTSDataSource _ftsDataSource;
  final NavigationTreeRepository _treeRepository;
  final DictionaryRepository? _dictionaryRepository;

  TextSearchRepositoryImpl(
    this._ftsDataSource,
    this._treeRepository, [
    this._dictionaryRepository,
  ]);

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

  /// Caches parsed sutta JSON files across searches (native only).
  ///
  /// FTS snippet text isn't stored in the index, so on native we read it from
  /// the bundled JSON. Memoising parsed files here means a repeated, refined, or
  /// paginated query that touches the same file skips the expensive
  /// `json.decode` — the dominant cost between "Enter" and "results appear."
  ///
  /// No TTL by design: the Tipitaka corpus is immutable, so cached files never
  /// go stale (see [LRUCache]). Capacity bounds memory — each entry is a parsed
  /// map sourced from a ~200–400 KB file; [_fileJsonCacheCapacity] is a safe
  /// starting point. On web this is never populated: the server pre-fills
  /// `matchedText`, so the `match.matchedText == null` guard below skips the
  /// load entirely.
  static const int _fileJsonCacheCapacity = 20;
  final LRUCache<String, Map<String, dynamic>> _fileJsonCache =
      LRUCache(_fileJsonCacheCapacity);

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

      final editionsToSearch =
          query.editionIds.isEmpty ? {'bjt'} : query.editionIds;

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

          // 1. Title matches (from navigation tree - in memory, fast)
          resultsByType[SearchResultType.title] = _searchTitles(
            nodeMap: nodeMap,
            queryText: query.queryText,
            editionId: 'bjt', // TODO: Support multiple editions
            scope: query.scope,
            isExactMatch: query.isExactMatch,
            languageScope: languageScope,
            limit: maxPerCategory,
          );

          // 2. Content matches (from FTS)
          // Overfetch to ensure enough unique groups (suttas) after grouping
          final overfetchLimit =
              maxPerCategory * _groupedSearchOverfetchMultiplier;
          final ftsResults = await _searchFullText(
            nodeMap: nodeMap,
            queryText: query.queryText,
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
          resultsByType[SearchResultType.fullText] = _limitToGroups(
            ftsResults,
            maxGroups: maxPerCategory,
          );

          // 3. Definition matches (from dictionary)
          resultsByType[SearchResultType.definition] = await _searchDefinitions(
            query.queryText,
            isExactMatch: query.isExactMatch,
            dictionaryIds: query.selectedDictionaryIds,
            limit: maxPerCategory,
          );

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

      final editionsToSearch =
          query.editionIds.isEmpty ? {'bjt'} : query.editionIds;

      final treeResult = await _treeRepository.loadNavigationTree();

      return await treeResult.fold(
        (failure) async => Left(failure),
        (tree) async {
          final nodeMap = _buildNodeMap(tree);
          final languageScope = SearchLanguageScope.fromFlags(
            searchInPali: query.searchInPali,
            searchInSinhala: query.searchInSinhala,
          );

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
                queryText: query.queryText,
                editionId: 'bjt',
                scope: query.scope,
                isExactMatch: query.isExactMatch,
                languageScope: languageScope,
                limit: query.limit,
              ));

            case SearchResultType.fullText:
              final results = await _searchFullText(
                nodeMap: nodeMap,
                queryText: query.queryText,
                editionIds: editionsToSearch,
                scope: query.scope,
                isExactMatch: query.isExactMatch,
                isPhraseSearch: query.isPhraseSearch,
                isAnywhereInText: query.isAnywhereInText,
                proximityDistance: query.proximityDistance,
                language: _ftsLanguageFilter(languageScope),
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

      final editionsToSearch =
          query.editionIds.isEmpty ? {'bjt'} : query.editionIds;

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

          // Title count (from navigation tree - in memory, fast)
          count[SearchResultType.title] = _searchTitles(
            nodeMap: nodeMap,
            queryText: query.queryText,
            editionId: 'bjt',
            scope: query.scope,
            isExactMatch: query.isExactMatch,
            languageScope: languageScope,
          ).length;

          // Content count (efficient SQL COUNT) — same language filter as the
          // FTS search above, so the tab badge matches the rows shown.
          count[SearchResultType.fullText] =
              await _ftsDataSource.countFullTextMatches(
            query.queryText,
            editionId: editionsToSearch.first,
            scope: query.scope,
            isExactMatch: query.isExactMatch,
            isPhraseSearch: query.isPhraseSearch,
            isAnywhereInText: query.isAnywhereInText,
            proximityDistance: query.proximityDistance,
            language: _ftsLanguageFilter(languageScope),
          );

          // Definition count (from dictionary)
          count[SearchResultType.definition] = await _countDefinitions(
            query.queryText,
            isExactMatch: query.isExactMatch,
            dictionaryIds: query.selectedDictionaryIds,
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

  @override
  Future<Either<Failure, List<String>>> getSuggestions(
    String prefix, {
    String? language,
  }) async {
    try {
      final suggestions = await _ftsDataSource.getSuggestions(
        prefix,
        editionIds: {'bjt'},
        language: language,
        limit: 10,
      );

      final words = suggestions.map((s) => s.word).toList();
      return Right(words);
    } catch (e) {
      return Left(
        Failure.dataLoadFailure(
          message: 'Failed to get suggestions',
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
  List<SearchResult> _searchTitles({
    required Map<String, TipitakaTreeNode> nodeMap,
    required String queryText,
    required String editionId,
    Set<String> scope = const {},
    bool isExactMatch = false,
    SearchLanguageScope languageScope = SearchLanguageScope.both,
    int? limit,
  }) {
    final results = <SearchResult>[];

    // Normalize query for matching (caller handles Singlish conversion)
    final searchQuery = normalizeText(queryText, toLowerCase: true);

    // Get scope patterns for filtering
    final scopePatterns = ScopeOperations.getPatternsForScope(scope);

    // Helper function to check if a name matches the query
    // isExactMatch=false: contains matching (includes startsWith)
    // isExactMatch=true: word boundary match (query appears as complete word)
    bool matchesQuery(String name) {
      if (isExactMatch) {
        // Word boundary match: query must appear as a complete word
        return name == searchQuery ||
            name.startsWith('$searchQuery ') ||
            name.endsWith(' $searchQuery') ||
            name.contains(' $searchQuery ');
      } else {
        return name.contains(searchQuery);
      }
    }

    // Helper function to check if contentFileId matches any scope pattern
    // Patterns from getPatternsForScope are prefix-only (e.g., 'dn-')
    // SQL LIKE wildcard (%) is added by the service layer, not here
    bool matchesScope(String? contentFileId) {
      if (scopePatterns.isEmpty) return true; // No filter = match all
      if (contentFileId == null) return false;
      return scopePatterns
          .any((pattern) => contentFileId.startsWith(pattern));
    }

    for (final node in nodeMap.values) {
      final paliName =
          normalizeText(node.paliName, toLowerCase: true).replaceAll('.', '');
      final sinhalaName =
          normalizeText(node.sinhalaName, toLowerCase: true).replaceAll('.', '');

      // Match normalized query against each name, but only when the language
      // scope includes that language. Narrowed to one language, a node that
      // matched only the other language's name is excluded.
      // (both → both true; pali → only pali; sinhala → only sinhala.)
      final searchPali = languageScope != SearchLanguageScope.sinhala;
      final searchSinhala = languageScope != SearchLanguageScope.pali;
      final paliMatched = searchPali && matchesQuery(paliName);
      final sinhalaMatched = searchSinhala && matchesQuery(sinhalaName);

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
          ),
        );
      }
    }

    // Sort with dual criteria:
    // 1. Primary: startsWith matches before contains-only matches
    // 2. Secondary: leaf nodes (individual suttas) before parent nodes
    results.sort((a, b) {
      // Primary sort: startsWith first
      final titleA =
          normalizeText(a.title, toLowerCase: true).replaceAll('.', '');
      final titleB =
          normalizeText(b.title, toLowerCase: true).replaceAll('.', '');
      final aStartsWith = titleA.startsWith(searchQuery);
      final bStartsWith = titleB.startsWith(searchQuery);

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
      limit: limit ?? 50,
      offset: offset,
    );

    // FTS rows carry only metadata (filename, eind, language) — not the snippet
    // text the result preview needs. On native we read that text from the
    // bundled JSON; load each DISTINCT file exactly once here, BEFORE the loop,
    // so 50 hits clustered in a handful of files cost a few decodes instead of
    // one full-file decode per hit (the old per-hit reload).
    //
    // Files the server already pre-filled (web: match.matchedText != null) are
    // skipped — their snippet travels inline in the response.
    final filesToLoad = ftsMatches
        .where((m) => m.matchedText == null)
        .map((m) => m.filename)
        .toSet();
    final parsedFiles = <String, Map<String, dynamic>>{};
    for (final filename in filesToLoad) {
      final fileJson = await _loadFileJson(filename);
      if (fileJson != null) parsedFiles[filename] = fileJson;
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
        // Snippet text resolution (same fallback chain as before, just sourced
        // from the pre-parsed map instead of a fresh per-hit file read):
        //   web    → match.matchedText (server pre-filled).
        //   native → extract from the file parsed above.
        //   either → '' if unavailable, so a single missing/corrupt file
        //            degrades only its own hits and never fails the search.
        final fileJson = parsedFiles[match.filename];
        final matchedText = match.matchedText ??
            (fileJson != null
                ? _extractEntryText(
                    fileJson, pageIndex, entryIndex, match.language)
                : null) ??
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

  /// Loads and decodes a sutta JSON file from the asset bundle, memoised across
  /// searches by [_fileJsonCache].
  ///
  /// Returns null (and logs once) if the file is missing or can't be parsed, so
  /// a single bad file never fails the whole search — its hits just get an empty
  /// snippet. Split out from extraction so the (expensive) read + decode happens
  /// once per distinct file, while [_extractEntryText] runs per hit with no I/O.
  Future<Map<String, dynamic>?> _loadFileJson(String filename) async {
    final cached = _fileJsonCache.get(filename);
    if (cached != null) return cached;

    try {
      final jsonString =
          await rootBundle.loadString('assets/text/$filename.json');
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;
      _fileJsonCache.put(filename, jsonData);
      return jsonData;
    } catch (e, stackTrace) {
      // Log the error for debugging - text loading is optional but
      // failures should be traceable during development.
      developer.log(
        'Failed to load text file: $filename',
        error: e,
        stackTrace: stackTrace,
        name: 'TextSearchRepository',
      );
      return null;
    }
  }

  /// Extracts a single entry's text from an already-parsed sutta file.
  ///
  /// Pure: no I/O, no decode — just indexes into the in-memory map, so it is
  /// cheap to call once per hit. [language] is the matched language ('pali' or
  /// 'sinh'); it is tried first, then the other is used as a fallback — the same
  /// order the old per-hit loader used. Returns null if the position is out of
  /// range or no non-empty text exists for either language.
  String? _extractEntryText(
    Map<String, dynamic> jsonData,
    int pageIndex,
    int entryIndex,
    String language,
  ) {
    final pages = jsonData['pages'] as List<dynamic>?;
    if (pages == null || pageIndex >= pages.length) return null;

    final page = pages[pageIndex] as Map<String, dynamic>;

    // Try matched language first, then fallback to the other.
    final langOrder = language == 'pali' ? ['pali', 'sinh'] : ['sinh', 'pali'];
    for (final lang in langOrder) {
      final langData = page[lang] as Map<String, dynamic>?;
      final entries = langData?['entries'] as List<dynamic>?;
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
  }) async {
    if (_dictionaryRepository == null) {
      return 0;
    }

    final result = await _dictionaryRepository.countDefinitions(
      queryText,
      isExactMatch: isExactMatch,
      dictionaryIds: dictionaryIds,
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
    );
  }
}
