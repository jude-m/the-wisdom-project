import 'package:dartz/dartz.dart';
import '../../domain/entities/failure.dart';
import '../../domain/entities/search/categorized_search_result.dart';
import '../../domain/entities/search/search_category.dart';
import '../../domain/entities/search/search_query.dart';
import '../../domain/entities/search/search_result.dart';
import '../../domain/repositories/navigation_tree_repository.dart';
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

  @override
  Future<Either<Failure, List<SearchResult>>> search(SearchQuery query) async {
    try {
      // Determine which editions to search
      // If no editions specified, default to BJT for now
      // TODO: Get available editions from configuration
      final editionsToSearch =
          query.editionIds.isEmpty ? {'bjt'} : query.editionIds;

      // Determine language filter
      String? languageFilter;
      if (query.searchInPali && !query.searchInSinhala) {
        languageFilter = 'pali';
      } else if (!query.searchInPali && query.searchInSinhala) {
        languageFilter = 'sinh';
      }
      // If both or neither, search all languages (languageFilter = null)

      // Perform FTS search across selected editions
      final ftsMatches = await _ftsDataSource.searchContent(
        query.queryText,
        editionIds: editionsToSearch,
        language: languageFilter,
        nikayaFilter:
            query.nikayaFilters.isNotEmpty ? query.nikayaFilters : null,
        limit: query.limit,
        offset: query.offset,
      );

      // Load the navigation tree to get metadata
      final treeResult = await _treeRepository.loadNavigationTree();

      return treeResult.fold(
        (failure) => Left(failure),
        (tree) {
          // Build a map of nodeKey -> node for fast lookup
          final nodeMap = <String, dynamic>{};
          void buildMap(dynamic node) {
            if (node.nodeKey != null) {
              nodeMap[node.nodeKey] = node;
            }
            if (node.childNodes != null) {
              for (final child in node.childNodes) {
                buildMap(child);
              }
            }
          }

          for (final root in tree) {
            buildMap(root);
          }

          // Convert FTS matches to SearchResults
          final results = <SearchResult>[];
          for (final match in ftsMatches) {
            // Find the node that corresponds to this file
            final node = nodeMap.values.firstWhere(
              (n) => n.contentFileId == match.filename,
              orElse: () => null,
            );

            if (node != null) {
              // Build the subtitle (navigation path)
              final subtitle = _buildNavigationPath(node, nodeMap);

              // Parse eind (format: "pageIndex-entryIndex")
              final eindParts = match.eind.split('-');
              final pageIndex = int.parse(eindParts[0]);
              final entryIndex = int.parse(eindParts[1]);

              results.add(
                SearchResult(
                  id: '${match.editionId}_${match.filename}_${match.eind}',
                  editionId: match.editionId,
                  category:
                      SearchCategory.content, // FTS matches are content results
                  title: match.language == 'pali'
                      ? node.paliName
                      : node.sinhalaName,
                  subtitle: subtitle,
                  matchedText: '', // Will be filled from actual content
                  contextBefore: '',
                  contextAfter: '',
                  contentFileId: match.filename,
                  pageIndex: pageIndex,
                  entryIndex: entryIndex,
                  nodeKey: node.nodeKey,
                  language: match.language,
                ),
              );
            }
          }

          return Right(results);
        },
      );
    } catch (e) {
      return Left(
        Failure.dataLoadFailure(
          message: 'Failed to perform search',
          error: e,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, CategorizedSearchResult>> searchCategorizedPreview(
    SearchQuery query, {
    int maxPerCategory = 3,
  }) async {
    try {
      // For now, we perform a single search and categorize results
      // Title matches come from navigation tree name matching
      // Content matches come from FTS

      final editionsToSearch =
          query.editionIds.isEmpty ? {'bjt'} : query.editionIds;

      // Load the navigation tree for title matching
      final treeResult = await _treeRepository.loadNavigationTree();

      return await treeResult.fold(
        (failure) async => Left(failure),
        (tree) async {
          final resultsByCategory = <SearchCategory, List<SearchResult>>{};

          // Build nodeKey -> node map
          final nodeMap = <String, dynamic>{};
          void buildMap(dynamic node) {
            if (node.nodeKey != null) {
              nodeMap[node.nodeKey] = node;
            }
            if (node.childNodes != null) {
              for (final child in node.childNodes) {
                buildMap(child);
              }
            }
          }

          for (final root in tree) {
            buildMap(root);
          }

          // 1. Search for title matches (sutta/commentary names)
          final titleResults = <SearchResult>[];
          final queryLower = query.queryText.toLowerCase();
          for (final node in nodeMap.values) {
            final paliName = (node.paliName ?? '').toString().toLowerCase();
            final sinhalaName =
                (node.sinhalaName ?? '').toString().toLowerCase();

            if (paliName.contains(queryLower) ||
                sinhalaName.contains(queryLower)) {
              if (node.contentFileId != null) {
                titleResults.add(
                  SearchResult(
                    id: 'title_${node.nodeKey}',
                    editionId: 'bjt', // Default for now
                    category: SearchCategory.title,
                    title: node.paliName ?? node.sinhalaName ?? '',
                    subtitle: _buildNavigationPath(node, nodeMap),
                    matchedText: node.paliName ?? '',
                    contentFileId: node.contentFileId,
                    pageIndex: node.entryPageIndex ?? 0,
                    entryIndex: node.entryIndexInPage ?? 0,
                    nodeKey: node.nodeKey,
                    language: 'pali',
                  ),
                );
              }
              if (titleResults.length >= maxPerCategory) break;
            }
          }
          resultsByCategory[SearchCategory.title] = titleResults;

          // 2. Search for content matches (FTS)
          final ftsMatches = await _ftsDataSource.searchContent(
            query.queryText,
            editionIds: editionsToSearch,
            limit: maxPerCategory,
            offset: 0,
          );

          final contentResults = <SearchResult>[];
          for (final match in ftsMatches) {
            final node = nodeMap.values.firstWhere(
              (n) => n.contentFileId == match.filename,
              orElse: () => null,
            );

            if (node != null) {
              final eindParts = match.eind.split('-');
              final pageIndex = int.parse(eindParts[0]);
              final entryIndex = int.parse(eindParts[1]);

              contentResults.add(
                SearchResult(
                  id: '${match.editionId}_${match.filename}_${match.eind}',
                  editionId: match.editionId,
                  category: SearchCategory.content,
                  title: match.language == 'pali'
                      ? node.paliName
                      : node.sinhalaName,
                  subtitle: _buildNavigationPath(node, nodeMap),
                  matchedText: '', // Would need to fetch actual content
                  contentFileId: match.filename,
                  pageIndex: pageIndex,
                  entryIndex: entryIndex,
                  nodeKey: node.nodeKey,
                  language: match.language,
                ),
              );
            }
          }
          resultsByCategory[SearchCategory.content] = contentResults;

          // 3. Definition matches (future - placeholder for now)
          resultsByCategory[SearchCategory.definition] = [];

          final totalCount = resultsByCategory.values
              .fold(0, (sum, list) => sum + list.length);

          return Right(CategorizedSearchResult(
            resultsByCategory: resultsByCategory,
            totalCount: totalCount,
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
  Future<Either<Failure, List<SearchResult>>> searchByCategory(
    SearchQuery query,
    SearchCategory category,
  ) async {
    try {
      final editionsToSearch =
          query.editionIds.isEmpty ? {'bjt'} : query.editionIds;

      final treeResult = await _treeRepository.loadNavigationTree();

      return await treeResult.fold(
        (failure) async => Left(failure),
        (tree) async {
          final nodeMap = <String, dynamic>{};
          void buildMap(dynamic node) {
            if (node.nodeKey != null) {
              nodeMap[node.nodeKey] = node;
            }
            if (node.childNodes != null) {
              for (final child in node.childNodes) {
                buildMap(child);
              }
            }
          }

          for (final root in tree) {
            buildMap(root);
          }

          switch (category) {
            case SearchCategory.title:
              // Search in node names
              final results = <SearchResult>[];
              final queryLower = query.queryText.toLowerCase();
              for (final node in nodeMap.values) {
                final paliName = (node.paliName ?? '').toString().toLowerCase();
                final sinhalaName =
                    (node.sinhalaName ?? '').toString().toLowerCase();

                if (paliName.contains(queryLower) ||
                    sinhalaName.contains(queryLower)) {
                  if (node.contentFileId != null) {
                    results.add(
                      SearchResult(
                        id: 'title_${node.nodeKey}',
                        editionId: 'bjt',
                        category: SearchCategory.title,
                        title: node.paliName ?? node.sinhalaName ?? '',
                        subtitle: _buildNavigationPath(node, nodeMap),
                        matchedText: node.paliName ?? '',
                        contentFileId: node.contentFileId,
                        pageIndex: node.entryPageIndex ?? 0,
                        entryIndex: node.entryIndexInPage ?? 0,
                        nodeKey: node.nodeKey,
                        language: 'pali',
                      ),
                    );
                  }
                }
              }
              return Right(results.take(query.limit).toList());

            case SearchCategory.content:
              // Use FTS for content search
              final ftsMatches = await _ftsDataSource.searchContent(
                query.queryText,
                editionIds: editionsToSearch,
                limit: query.limit,
                offset: query.offset,
              );

              final results = <SearchResult>[];
              for (final match in ftsMatches) {
                final node = nodeMap.values.firstWhere(
                  (n) => n.contentFileId == match.filename,
                  orElse: () => null,
                );

                if (node != null) {
                  final eindParts = match.eind.split('-');
                  final pageIndex = int.parse(eindParts[0]);
                  final entryIndex = int.parse(eindParts[1]);

                  results.add(
                    SearchResult(
                      id: '${match.editionId}_${match.filename}_${match.eind}',
                      editionId: match.editionId,
                      category: SearchCategory.content,
                      title: match.language == 'pali'
                          ? node.paliName
                          : node.sinhalaName,
                      subtitle: _buildNavigationPath(node, nodeMap),
                      matchedText: '',
                      contentFileId: match.filename,
                      pageIndex: pageIndex,
                      entryIndex: entryIndex,
                      nodeKey: node.nodeKey,
                      language: match.language,
                    ),
                  );
                }
              }
              return Right(results);

            case SearchCategory.definition:
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

  /// Build a navigation path string from a node (e.g., "Dīgha Nikāya > Sīlakkhandhavagga")
  String _buildNavigationPath(dynamic node, Map<String, dynamic> nodeMap) {
    final parts = <String>[];
    dynamic current = node;

    // Traverse up the tree to build the path
    while (current != null && current.parentNodeKey != null) {
      final parent = nodeMap[current.parentNodeKey];
      if (parent != null) {
        parts.insert(0, parent.paliName ?? parent.sinhalaName ?? '');
        current = parent;
      } else {
        break;
      }
    }

    return parts.join(' > ');
  }

  @override
  Future<Either<Failure, List<String>>> getSuggestions(
    String prefix, {
    String? language,
  }) async {
    try {
      // Default to BJT edition for suggestions
      // TODO: Get available editions from configuration
      final suggestions = await _ftsDataSource.getSuggestions(
        prefix,
        editionIds: {'bjt'},
        language: language,
        limit: 10,
      );

      // Extract just the words
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
}
