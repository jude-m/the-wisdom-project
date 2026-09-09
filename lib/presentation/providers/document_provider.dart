import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/bjt_document_datasource.dart';
import '../../data/datasources/bjt_document_local_datasource.dart';
import '../../data/repositories/bjt_document_repository_impl.dart';
import '../../domain/entities/bjt/bjt_document.dart';
import '../../domain/entities/content/text_layer.dart';
import '../../domain/entities/reader/document_slice.dart';
import '../../domain/entities/reader/reader_unit.dart';
import '../../domain/repositories/bjt_document_repository.dart';
import '../../domain/usecases/load_bjt_document_usecase.dart';
import 'reader_unit_provider.dart';
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
// Uses autoDispose to clean up when no listeners remain.
// keepAlive() caches successful loads; failed loads can be retried.
final bjtDocumentProvider =
    FutureProvider.autoDispose.family<BJTDocument, String>((ref, fileId) async {
  final useCase = ref.watch(loadBJTDocumentUseCaseProvider);
  final result = await useCase.execute(fileId);

  return result.fold(
    (failure) => throw Exception(failure.userMessage),
    (document) {
      ref.keepAlive(); // Cache successful loads
      return document;
    },
  );
});

// ============================================================================
// CONTENT STATE
// Everything the reader shows is derived from the active tab's node key:
//   activeNodeKeyProvider → activeReaderUnitProvider → the file and the span
//     → currentBJTDocumentProvider → activeDocumentSliceProvider
// The tab stores no coordinates, so nothing here can disagree with the
// resolver about where a unit starts or stops.
// ============================================================================

/// The bounded unit the active tab is reading.
///
/// Async because the resolver is: the reader shows its loading state until the
/// tree is up, the same way it already waited on the content file. Null inside
/// the data case means "this tab has no unit" — no tab open, or a key the tree
/// has never heard of.
final activeReaderUnitProvider = Provider<AsyncValue<ReaderUnit?>>((ref) {
  final nodeKey = ref.watch(activeNodeKeyProvider);
  // Answered without the resolver, so a session with no tab open never builds
  // it and the "select a sutta" hint is not held behind a spinner.
  if (nodeKey == null) return const AsyncValue.data(null);
  return ref
      .watch(readerUnitResolverProvider)
      .whenData((resolver) => resolver.unitFor(nodeKey));
});

/// The content file the active tab's unit lives in — derived, never stored.
final activeContentFileIdProvider = Provider<String?>((ref) {
  return ref.watch(activeReaderUnitProvider).valueOrNull?.contentFileId;
});

// Current BJT document provider (uses activeContentFileIdProvider above)
final currentBJTDocumentProvider = Provider<AsyncValue<BJTDocument?>>((ref) {
  final fileId = ref.watch(activeContentFileIdProvider);

  if (fileId == null || fileId.trim().isEmpty) {
    return const AsyncValue.data(null);
  }

  // Return the AsyncValue directly to properly propagate loading/error states
  return ref.watch(bjtDocumentProvider(fileId));
});

/// The unit's span cut out of the loaded document — the pages the panes build.
///
/// This is the whole of what replaced `pageStart`/`pageEnd`: the reader is
/// handed a finite list once, and `ListView.builder` keeps it lazy for free.
/// Null while either half is still loading, or when the tab has no unit.
final activeDocumentSliceProvider = Provider<DocumentSlice?>((ref) {
  final unit = ref.watch(activeReaderUnitProvider).valueOrNull;
  final document = ref.watch(currentBJTDocumentProvider).valueOrNull;
  if (unit == null || document == null) return null;
  return DocumentSlice.of(document, unit.range);
});

/// Where the active tab should land when its content first renders.
///
/// The row a search hit or a `?e=` link named; null otherwise, and the unit
/// opens at its own top. Only consulted while the tab's own `scrollOffset` is
/// still 0: once the reader has moved, where they left off outranks where they
/// arrived.
final activeLandingEntryProvider = Provider<(int, int)?>((ref) {
  final tab = ref.watch(activeTabProvider);
  final page = tab?.landingPageIndex;
  final entry = tab?.landingEntryIndex;
  return page != null && entry != null ? (page, entry) : null;
});

// Note: Reader layout is now per-tab, stored in ReaderTab.layout
// Access via activeReaderLayoutProvider in tab_provider.dart
// Update via updateActiveTabLayoutProvider in tab_provider.dart

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
