import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/bjt_document_local_datasource.dart';
import '../../data/repositories/bjt_document_repository_impl.dart';
import '../../domain/entities/bjt/bjt_document.dart';
import '../../domain/entities/text_layer.dart';
import '../../domain/entities/column_display_mode.dart';
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
final bjtDocumentProvider = FutureProvider.family<BJTDocument, String>((ref, fileId) async {
  final useCase = ref.watch(loadBJTDocumentUseCaseProvider);
  final result = await useCase.execute(fileId);

  return result.fold(
    (failure) => throw Exception(failure.userMessage),
    (document) => document,
  );
});

// Current content file ID provider
final currentContentFileIdProvider = StateProvider<String?>((ref) => null);

// Current BJT document provider (uses currentContentFileIdProvider)
final currentBJTDocumentProvider = Provider<AsyncValue<BJTDocument?>>((ref) {
  final fileId = ref.watch(currentContentFileIdProvider);

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

// Current page index provider (entry page)
final currentPageIndexProvider = StateProvider<int>((ref) => 0);

// Pagination providers for lazy loading
final pageStartProvider = StateProvider<int>((ref) => 0);
final pageEndProvider = StateProvider<int>((ref) => 1); // Load 1 page initially

// Provider to load content for a specific node
final loadContentForNodeProvider = Provider<void Function(String?, int)>((ref) {
  return (String? contentFileId, int pageIndex) {
    ref.read(currentContentFileIdProvider.notifier).state = contentFileId;
    ref.read(currentPageIndexProvider.notifier).state = pageIndex;
    // Reset pagination to show only the entry page
    ref.read(pageStartProvider.notifier).state = pageIndex;
    ref.read(pageEndProvider.notifier).state = pageIndex + 1;
  };
});

// Provider to load more pages
final loadMorePagesProvider = Provider<void Function(int)>((ref) {
  return (int additionalPages) {
    final contentAsync = ref.read(currentBJTDocumentProvider);
    contentAsync.whenData((document) {
      if (document != null) {
        final currentEnd = ref.read(pageEndProvider);
        final newEnd = (currentEnd + additionalPages).clamp(0, document.pageCount);
        ref.read(pageEndProvider.notifier).state = newEnd;

        // Also update the current tab's pageEnd
        final activeTabIndex = ref.read(activeTabIndexProvider);
        final tabs = ref.read(tabsProvider);
        if (activeTabIndex >= 0 && activeTabIndex < tabs.length) {
          final updatedTab = tabs[activeTabIndex].copyWith(pageEnd: newEnd);
          ref.read(tabsProvider.notifier).updateTab(activeTabIndex, updatedTab);
        }
      }
    });
  };
});

// Provider to navigate to next page
final nextPageProvider = Provider<void Function()>((ref) {
  return () {
    final contentAsync = ref.read(currentBJTDocumentProvider);
    contentAsync.whenData((document) {
      if (document != null) {
        final currentPage = ref.read(currentPageIndexProvider);
        if (currentPage < document.pageCount - 1) {
          ref.read(currentPageIndexProvider.notifier).state = currentPage + 1;
        }
      }
    });
  };
});

// Provider to navigate to previous page
final previousPageProvider = Provider<void Function()>((ref) {
  return () {
    final currentPage = ref.read(currentPageIndexProvider);
    if (currentPage > 0) {
      ref.read(currentPageIndexProvider.notifier).state = currentPage - 1;
    }
  };
});

// ============================================================================
// NEW: TextLayer Providers (Multi-Edition Foundation)
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

  return layers.map((layer) => {
    'layerId': layer.layerId,
    'displayName': layer.displayName,
    'editionId': layer.editionId,
    'languageCode': layer.languageCode,
    'scriptCode': layer.scriptCode,
    'segmentCount': layer.segmentCount.toString(),
  }).toList();
});
