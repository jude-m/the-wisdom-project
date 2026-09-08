import 'package:mockito/annotations.dart';
import 'package:the_wisdom_project/domain/repositories/navigation_tree_repository.dart';
import 'package:the_wisdom_project/domain/repositories/bjt_document_repository.dart';
import 'package:the_wisdom_project/domain/repositories/recent_searches_repository.dart';
import 'package:the_wisdom_project/domain/repositories/text_search_repository.dart';
import 'package:the_wisdom_project/domain/repositories/dictionary_repository.dart';
import 'package:the_wisdom_project/data/datasources/tree_local_datasource.dart';
import 'package:the_wisdom_project/data/datasources/bjt_document_datasource.dart';
import 'package:the_wisdom_project/data/datasources/fts_datasource.dart';
import 'package:the_wisdom_project/data/datasources/dictionary_datasource.dart';

/// This file defines which classes Mockito should generate mocks for.
/// After adding a class here, run:
///   dart run build_runner build --delete-conflicting-outputs
///
/// This will generate `mocks.mocks.dart` with mock implementations.
@GenerateMocks([
  // Domain layer - Repositories
  NavigationTreeRepository,
  BJTDocumentRepository,
  RecentSearchesRepository,
  TextSearchRepository,
  DictionaryRepository,

  // Data layer - Data sources
  TreeLocalDataSource,
  BJTDocumentDataSource,
  FTSDataSource,
  DictionaryDataSource,
])
void main() {}
