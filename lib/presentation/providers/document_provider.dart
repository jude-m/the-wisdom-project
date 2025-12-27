import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/bjt_document_local_datasource.dart';
import '../../data/repositories/bjt_document_repository_impl.dart';
import '../../domain/entities/bjt/bjt_document.dart';
import '../../domain/entities/content/text_layer.dart';
import '../models/column_display_mode.dart';
import '../../domain/repositories/bjt_document_repository.dart';
import '../../domain/usecases/load_bjt_document_usecase.dart';
import 'tab_provider.dart';

// Datasource provider
final bjtDocumentDataSourceProvider = Provider<BJTDocumentDataSource>((ref) {
  return BJTDocumentLocalDataSourceImpl();
});

// Repository provider
final bjtDocumentRepositoryProvider = Provider<BJTDocumentRepository>((ref) {
  final dataSource = ref.watch(bjtDocumentDataSourceProvider);
  return BJTDocumentRepositoryImpl(dataSource);
});

// Use case provider
final loadBJTDocumentUseCaseProvider = Provider<LoadBJTDocumentUseCase>((ref) {
  final repository = ref.watch(bjtDocumentRepositoryProvider);
  return LoadBJTDocumentUseCase(repository);
});

// BJT document provider (loads document by file ID)
final bjtDocumentProvider =
    FutureProvider.family<BJTDocument, String>((ref, fileId) async {
  final useCase = ref.watch(loadBJTDocumentUseCaseProvider);
  final result = await useCase.execute(fileId);

  return result.fold(
    (failure) => throw Exception(failure.userMessage),
    (document) => document,
  );
});

// ============================================================================
// CONTENT STATE
// Content file ID and page index are derived from the active tab in tab_provider.dart:
// - activeContentFileIdProvider
// - activePageIndexProvider
// This eliminates state duplication and ensures consistency.
// ============================================================================

// Current BJT document provider (uses activeContentFileIdProvider from tab state)
final currentBJTDocumentProvider = Provider<AsyncValue<BJTDocument?>>((ref) {
  final fileId = ref.watch(activeContentFileIdProvider);

  if (fileId == null || fileId.trim().isEmpty) {
    return const AsyncValue.data(null);
  }

  // Return the AsyncValue directly to properly propagate loading/error states
  return ref.watch(bjtDocumentProvider(fileId));
});

// Column display mode provider
final columnDisplayModeProvider = StateProvider<ColumnDisplayMode>((ref) {
  return ColumnDisplayMode.both;
});

// Provider to load more pages
// Updates only the active tab's pageEnd; widgets react via activePageEndProvider
final loadMorePagesProvider = Provider<void Function(int)>((ref) {
  return (int additionalPages) {
    final activeTabIndex = ref.read(activeTabIndexProvider);
    final tabs = ref.read(tabsProvider);
    if (activeTabIndex < 0 || activeTabIndex >= tabs.length) return;

    final currentTab = tabs[activeTabIndex];
    final contentAsync = ref.read(currentBJTDocumentProvider);
    contentAsync.whenData((document) {
      if (document != null) {
        final newEnd =
            (currentTab.pageEnd + additionalPages).clamp(0, document.pageCount);
        final updatedTab = currentTab.copyWith(pageEnd: newEnd);
        ref.read(tabsProvider.notifier).updateTab(activeTabIndex, updatedTab);
      }
    });
  };
});

// ============================================================================
// TextLayer Providers (Multi-Edition Foundation)
// ============================================================================

/// Converts current BJTDocument to TextLayers
/// This demonstrates the foundation for multi-edition support
final currentTextLayersProvider = Provider<List<TextLayer>>((ref) {
  final contentAsync = ref.watch(currentBJTDocumentProvider);

  return contentAsync.when(
    data: (document) {
      if (document == null) return [];

      // Convert page-based BJTDocument to segment-based TextLayers
      // This creates two layers: BJT Pali (Sinhala script) and BJT Sinhala
      final layers = document.toTextLayers();

      return layers;
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

/// Example provider showing available layers for current content
/// In the future, this will include SuttaCentral, PTS, etc.
final availableLayersProvider = Provider<List<Map<String, String>>>((ref) {
  final layers = ref.watch(currentTextLayersProvider);

  return layers
      .map((layer) => {
            'layerId': layer.layerId,
            'displayName': layer.displayName,
            'editionId': layer.editionId,
            'languageCode': layer.languageCode,
            'scriptCode': layer.scriptCode,
            'segmentCount': layer.segmentCount.toString(),
          })
      .toList();
});
