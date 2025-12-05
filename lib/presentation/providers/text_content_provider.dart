import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/text_content_local_datasource.dart';
import '../../data/repositories/text_content_repository_impl.dart';
import '../../domain/entities/text_content.dart';
import '../../domain/entities/column_display_mode.dart';
import '../../domain/repositories/text_content_repository.dart';
import '../../domain/usecases/load_text_content_usecase.dart';
import 'tab_provider.dart';

// Datasource provider
final textContentLocalDataSourceProvider = Provider<TextContentLocalDataSource>((ref) {
  return TextContentLocalDataSourceImpl();
});

// Repository provider
final textContentRepositoryProvider = Provider<TextContentRepository>((ref) {
  final dataSource = ref.watch(textContentLocalDataSourceProvider);
  return TextContentRepositoryImpl(dataSource);
});

// Use case provider
final loadTextContentUseCaseProvider = Provider<LoadTextContentUseCase>((ref) {
  final repository = ref.watch(textContentRepositoryProvider);
  return LoadTextContentUseCase(repository);
});

// Text content provider (loads content by file ID)
final textContentProvider = FutureProvider.family<TextContent, String>((ref, contentFileId) async {
  final useCase = ref.watch(loadTextContentUseCaseProvider);
  final result = await useCase.execute(contentFileId);

  return result.fold(
    (failure) => throw Exception(failure.userMessage),
    (content) => content,
  );
});

// Current content file ID provider
final currentContentFileIdProvider = StateProvider<String?>((ref) => null);

// Current content provider (uses currentContentFileIdProvider)
final currentTextContentProvider = Provider<AsyncValue<TextContent?>>((ref) {
  final fileId = ref.watch(currentContentFileIdProvider);

  if (fileId == null || fileId.trim().isEmpty) {
    return const AsyncValue.data(null);
  }

  // Return the AsyncValue directly to properly propagate loading/error states
  return ref.watch(textContentProvider(fileId));
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
    final contentAsync = ref.read(currentTextContentProvider);
    contentAsync.whenData((content) {
      if (content != null) {
        final currentEnd = ref.read(pageEndProvider);
        final newEnd = (currentEnd + additionalPages).clamp(0, content.pageCount);
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
    final contentAsync = ref.read(currentTextContentProvider);
    contentAsync.whenData((content) {
      if (content != null) {
        final currentPage = ref.read(currentPageIndexProvider);
        if (currentPage < content.pageCount - 1) {
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
