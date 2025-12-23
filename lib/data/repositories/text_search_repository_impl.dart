import 'dart:convert';
import 'dart:developer' as developer;
import 'package:dartz/dartz.dart';
import 'package:flutter/services.dart';
import '../../domain/entities/failure.dart';
import '../../domain/entities/search/grouped_search_result.dart';
import '../../domain/entities/search/search_result_type.dart';
import '../../domain/entities/search/search_query.dart';
import '../../domain/entities/search/search_result.dart';
import '../../domain/entities/tipitaka_tree_node.dart';
import '../../domain/repositories/navigation_tree_repository.dart';
import '../../core/utils/text_utils.dart';
import '../../domain/repositories/text_search_repository.dart';
import '../datasources/fts_datasource.dart';

/// Implementation of TextSearchRepository using FTS database and navigation tree
/// Supports searching across multiple editions
class TextSearchRepositoryImpl implements TextSearchRepository {
  final FTSDataSource _ftsDataSource;
  final NavigationTreeRepository _treeRepository;

  TextSearchRepositoryImpl(
    this._ftsDataSource,
    this._treeRepository,
  );

  // ============================================================================
  // PUBLIC API
  // ============================================================================

  @override
  Future<Either<Failure, GroupedSearchResult>> searchTopResults(
    SearchQuery query, {
    int maxPerCategory = 3,
  }) async {
    try {
      final editionsToSearch =
          query.editionIds.isEmpty ? {'bjt'} : query.editionIds;

      final treeResult = await _treeRepository.loadNavigationTree();

      return await treeResult.fold(
        (failure) async => Left(failure),
        (tree) async {
          final nodeMap = _buildNodeMap(tree);
          final resultsByType = <SearchResultType, List<SearchResult>>{};

          // 1. Title matches (from navigation tree - in memory, fast)
          resultsByType[SearchResultType.title] = _searchTitles(
            nodeMap: nodeMap,
            queryText: query.queryText,
            editionId: 'bjt', // TODO: Support multiple editions
            isExactMatch: query.isExactMatch,
            limit: maxPerCategory,
          );

          // 2. Content matches (from FTS)
          resultsByType[SearchResultType.fullText] = await _searchFullText(
            nodeMap: nodeMap,
            queryText: query.queryText,
            editionIds: editionsToSearch,
            isExactMatch: query.isExactMatch,
            limit: maxPerCategory,
            offset: 0,
            loadMatchedText: true, // Preview needs text for display
          );

          // 3. Definition matches (future - placeholder)
          resultsByType[SearchResultType.definition] = [];

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
      final editionsToSearch =
          query.editionIds.isEmpty ? {'bjt'} : query.editionIds;

      final treeResult = await _treeRepository.loadNavigationTree();

      return await treeResult.fold(
        (failure) async => Left(failure),
        (tree) async {
          final nodeMap = _buildNodeMap(tree);

          switch (resultType) {
            case SearchResultType.topResults:
              // "All" category should use searchCategorizedPreview instead
              // This case should not be reached via normal flow
              throw StateError(
                'Use searchCategorizedPreview for SearchCategory.all',
              );

            case SearchResultType.title:
              return Right(_searchTitles(
                nodeMap: nodeMap,
                queryText: query.queryText,
                editionId: 'bjt',
                isExactMatch: query.isExactMatch,
                limit: query.limit,
              ));

            case SearchResultType.fullText:
              final results = await _searchFullText(
                nodeMap: nodeMap,
                queryText: query.queryText,
                editionIds: editionsToSearch,
                isExactMatch: query.isExactMatch,
                limit: query.limit,
                offset: query.offset,
                loadMatchedText: false, // Full results don't need text yet
              );
              return Right(results);

            case SearchResultType.definition:
              // Future: Dictionary search
              return const Right([]);
          }
        },
      );
    } catch (e) {
      return Left(
        Failure.dataLoadFailure(
          message: 'Failed to search by category',
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
      final editionsToSearch =
          query.editionIds.isEmpty ? {'bjt'} : query.editionIds;

      final treeResult = await _treeRepository.loadNavigationTree();

      return await treeResult.fold(
        (failure) async => Left(failure),
        (tree) async {
          final nodeMap = _buildNodeMap(tree);
          final count = <SearchResultType, int>{};

          // Title count (from navigation tree - in memory, fast)
          count[SearchResultType.title] = _searchTitles(
            nodeMap: nodeMap,
            queryText: query.queryText,
            editionId: 'bjt',
            isExactMatch: query.isExactMatch,
          ).length;

          // Content count (efficient SQL COUNT)
          count[SearchResultType.fullText] =
              await _ftsDataSource.countFullTextMatches(
            query.queryText,
            editionId: editionsToSearch.first,
            isExactMatch: query.isExactMatch,
          );

          // Definition count (future - placeholder)
          count[SearchResultType.definition] = 0;

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
  List<SearchResult> _searchTitles({
    required Map<String, TipitakaTreeNode> nodeMap,
    required String queryText,
    required String editionId,
    bool isExactMatch = false,
    int? limit,
  }) {
    final results = <SearchResult>[];

    // Normalize query for matching (caller handles Singlish conversion)
    final searchQuery = normalizeText(queryText, toLowerCase: true);

    // Helper function to check if a name matches the query
    // isExactMatch=false: prefix matching (startsWith)
    // isExactMatch=true: exact string match
    bool matchesQuery(String name) {
      if (isExactMatch) {
        return name == searchQuery;
      } else {
        return name.startsWith(searchQuery);
      }
    }

    for (final node in nodeMap.values) {
      final paliName = normalizeText(node.paliName, toLowerCase: true);
      final sinhalaName = normalizeText(node.sinhalaName, toLowerCase: true);

      // Match normalized query against both Pali and Sinhala names
      final paliMatched = matchesQuery(paliName);
      final sinhalaMatched = matchesQuery(sinhalaName);

      if ((paliMatched || sinhalaMatched) && node.contentFileId != null) {
        // Prefer Sinhala if it matched, otherwise use Pali
        // TODO: lets get the navigator display lanaguge as the preference later.
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

    // Sort: leaf nodes (individual suttas) appear first
    results.sort((a, b) {
      final nodeA = nodeMap[a.nodeKey];
      final nodeB = nodeMap[b.nodeKey];
      // Use the isLeafNode getter from TipitakaTreeNode
      final isLeafA = nodeA?.isLeafNode ?? true;
      final isLeafB = nodeB?.isLeafNode ?? true;

      if (isLeafA && !isLeafB) return -1;
      if (!isLeafA && isLeafB) return 1;
      return 0;
    });

    return limit != null ? results.take(limit).toList() : results;
  }

  /// Search for content matches using FTS database
  /// Optionally loads matched text from JSON files for preview display
  Future<List<SearchResult>> _searchFullText({
    required Map<String, TipitakaTreeNode> nodeMap,
    required String queryText,
    required Set<String> editionIds,
    bool isExactMatch = false,
    int? limit,
    int offset = 0,
    bool loadMatchedText = false,
  }) async {
    final ftsMatches = await _ftsDataSource.searchFullText(
      queryText,
      editionIds: editionIds,
      isExactMatch: isExactMatch,
      limit: limit ?? 50,
      offset: offset,
    );

    final results = <SearchResult>[];

    for (final match in ftsMatches) {
      // Find the node by contentFileId
      final node = nodeMap.values
          .where((n) => n.contentFileId == match.filename)
          .firstOrNull;

      if (node != null) {
        final eindParts = match.eind.split('-');
        final pageIndex = int.parse(eindParts[0]);
        final entryIndex = int.parse(eindParts[1]);

        // Optionally load actual text content for preview
        String matchedText = '';
        if (loadMatchedText) {
          matchedText = await _loadTextForMatch(
                match.filename,
                match.eind,
                match.language,
              ) ??
              '';
        }

        // Prefer Sinhala title if language is sinh, otherwise use Pali
        final title = match.language == 'sinh'
            ? (node.sinhalaName.isNotEmpty ? node.sinhalaName : node.paliName)
            : (node.paliName.isNotEmpty ? node.paliName : node.sinhalaName);

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
            language: match.language,
          ),
        );
      }
    }

    return results;
  }

  // ============================================================================
  // PRIVATE HELPER METHODS - Utilities
  // ============================================================================

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

  /// Load actual text content from JSON file for a given entry
  /// [language] should be 'pali' or 'sinh' - the language where the match was found
  Future<String?> _loadTextForMatch(
    String filename,
    String eind,
    String language,
  ) async {
    try {
      final eindParts = eind.split('-');
      final pageIndex = int.parse(eindParts[0]);
      final entryIndex = int.parse(eindParts[1]);

      final jsonString =
          await rootBundle.loadString('assets/text/$filename.json');
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;

      final pages = jsonData['pages'] as List<dynamic>?;
      if (pages == null || pageIndex >= pages.length) {
        return null;
      }

      final page = pages[pageIndex] as Map<String, dynamic>;

      // Try matched language first, then fallback
      final langOrder =
          language == 'pali' ? ['pali', 'sinh'] : ['sinh', 'pali'];
      for (final lang in langOrder) {
        final langData = page[lang] as Map<String, dynamic>?;
        if (langData != null) {
          final entries = langData['entries'] as List<dynamic>?;
          if (entries != null && entryIndex < entries.length) {
            final entry = entries[entryIndex] as Map<String, dynamic>;
            final text = entry['text'] as String?;
            if (text != null && text.isNotEmpty) {
              return text;
            }
          }
        }
      }
    } catch (e, stackTrace) {
      // Log the error for debugging - text loading is optional but
      // failures should be traceable during development
      developer.log(
        'Failed to load text for match: $filename/$eind',
        error: e,
        stackTrace: stackTrace,
        name: 'TextSearchRepository',
      );
    }
    return null;
  }
}
