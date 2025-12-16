import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_wisdom_project/domain/entities/search/search_category.dart';
import 'package:the_wisdom_project/domain/entities/search/search_result.dart';
import 'package:the_wisdom_project/presentation/providers/tab_provider.dart';
import 'package:the_wisdom_project/presentation/providers/document_provider.dart';
import 'package:the_wisdom_project/domain/entities/reader_tab.dart';

void main() {
  group('TabsNotifier -', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('addTab should add a tab and return its index', () {
      // ARRANGE
      final notifier = container.read(tabsProvider.notifier);

      // ACT
      final tab = _createTestReaderTab(nodeKey: 'dn-1', contentFileId: 'dn-1');
      final index = notifier.addTab(tab);

      // ASSERT
      expect(index, equals(0));
      expect(container.read(tabsProvider).length, equals(1));
      expect(container.read(tabsProvider)[0].nodeKey, equals('dn-1'));
    });

    test('addTab should add multiple tabs with incremental indices', () {
      // ARRANGE
      final notifier = container.read(tabsProvider.notifier);

      // ACT
      final tab1 = _createTestReaderTab(nodeKey: 'dn-1', contentFileId: 'dn-1');
      final tab2 = _createTestReaderTab(nodeKey: 'mn-1', contentFileId: 'mn-1');
      final index1 = notifier.addTab(tab1);
      final index2 = notifier.addTab(tab2);

      // ASSERT
      expect(index1, equals(0));
      expect(index2, equals(1));
      expect(container.read(tabsProvider).length, equals(2));
    });

    test('removeTab should remove tab at specified index', () {
      // ARRANGE
      final notifier = container.read(tabsProvider.notifier);
      notifier
          .addTab(_createTestReaderTab(nodeKey: 'dn-1', contentFileId: 'dn-1'));
      notifier
          .addTab(_createTestReaderTab(nodeKey: 'mn-1', contentFileId: 'mn-1'));

      // ACT
      notifier.removeTab(0);

      // ASSERT
      expect(container.read(tabsProvider).length, equals(1));
      expect(container.read(tabsProvider)[0].nodeKey, equals('mn-1'));
    });

    test('updateTabPage should update pageIndex of specified tab', () {
      // ARRANGE
      final notifier = container.read(tabsProvider.notifier);
      notifier.addTab(_createTestReaderTab(nodeKey: 'dn-1', pageIndex: 0));

      // ACT
      notifier.updateTabPage(0, 5);

      // ASSERT
      expect(container.read(tabsProvider)[0].pageIndex, equals(5));
    });
  });

  group('openTabFromSearchResultProvider -', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('should create a new tab from search result', () {
      // ARRANGE
      final result = _createTestSearchResult(
        nodeKey: 'dn-1',
        contentFileId: 'dn-1',
        pageIndex: 3,
      );

      // ACT
      container.read(openTabFromSearchResultProvider)(result);

      // ASSERT
      final tabs = container.read(tabsProvider);
      expect(tabs.length, equals(1));
      expect(tabs[0].nodeKey, equals('dn-1'));
      expect(tabs[0].contentFileId, equals('dn-1'));
      expect(tabs[0].pageIndex, equals(3));
    });

    test('should set active tab index to new tab', () {
      // ARRANGE
      final result = _createTestSearchResult(
        nodeKey: 'dn-1',
        contentFileId: 'dn-1',
      );

      // ACT
      container.read(openTabFromSearchResultProvider)(result);

      // ASSERT
      expect(container.read(activeTabIndexProvider), equals(0));
    });

    test('should set currentContentFileIdProvider', () {
      // ARRANGE
      final result = _createTestSearchResult(
        nodeKey: 'mn-1',
        contentFileId: 'mn-1',
      );

      // ACT
      container.read(openTabFromSearchResultProvider)(result);

      // ASSERT
      expect(container.read(currentContentFileIdProvider), equals('mn-1'));
    });

    test('should set currentPageIndexProvider', () {
      // ARRANGE
      final result = _createTestSearchResult(
        nodeKey: 'dn-1',
        contentFileId: 'dn-1',
        pageIndex: 7,
      );

      // ACT
      container.read(openTabFromSearchResultProvider)(result);

      // ASSERT
      expect(container.read(currentPageIndexProvider), equals(7));
    });

    test(
        'should set pagination state via derived providers (activePageStartProvider/activePageEndProvider)',
        () {
      // ARRANGE
      final result = _createTestSearchResult(
        nodeKey: 'dn-1',
        contentFileId: 'dn-1',
        pageIndex: 5,
      );

      // ACT
      container.read(openTabFromSearchResultProvider)(result);

      // ASSERT
      // pageStart should be set to pageIndex (5)
      // pageEnd should be pageIndex + 1 (6) based on ReaderTab.fromNode logic
      // These are now derived from the active tab, not global StateProviders
      expect(container.read(activePageStartProvider), equals(5));
      expect(container.read(activePageEndProvider), equals(6));
    });

    test('should add multiple tabs from multiple search results', () {
      // ARRANGE
      final result1 = _createTestSearchResult(
        nodeKey: 'dn-1',
        contentFileId: 'dn-1',
      );
      final result2 = _createTestSearchResult(
        nodeKey: 'mn-1',
        contentFileId: 'mn-1',
      );

      // ACT
      container.read(openTabFromSearchResultProvider)(result1);
      container.read(openTabFromSearchResultProvider)(result2);

      // ASSERT
      final tabs = container.read(tabsProvider);
      expect(tabs.length, equals(2));
      expect(container.read(activeTabIndexProvider),
          equals(1)); // Second tab active
      expect(container.read(currentContentFileIdProvider), equals('mn-1'));
    });

    test('should handle search result with title category', () {
      // ARRANGE
      final result = _createTestSearchResult(
        nodeKey: 'dn-1',
        contentFileId: 'dn-1',
        title: 'Brahmajālasutta',
        category: SearchCategory.title,
      );

      // ACT
      container.read(openTabFromSearchResultProvider)(result);

      // ASSERT
      final tabs = container.read(tabsProvider);
      expect(tabs[0].paliName, equals('Brahmajālasutta'));
    });

    test('should handle search result with content category', () {
      // ARRANGE
      final result = _createTestSearchResult(
        nodeKey: 'mn-1',
        contentFileId: 'mn-1',
        title: 'Mūlapariyāyasutta',
        category: SearchCategory.content,
        pageIndex: 10,
        entryIndex: 3,
      );

      // ACT
      container.read(openTabFromSearchResultProvider)(result);

      // ASSERT
      final tabs = container.read(tabsProvider);
      expect(tabs[0].contentFileId, equals('mn-1'));
      expect(tabs[0].pageIndex, equals(10));
    });
  });

  group('switchTabProvider -', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
      // Add some initial tabs
      final notifier = container.read(tabsProvider.notifier);
      notifier.addTab(_createTestReaderTab(
        nodeKey: 'dn-1',
        contentFileId: 'dn-1',
        pageIndex: 0,
      ));
      notifier.addTab(_createTestReaderTab(
        nodeKey: 'mn-1',
        contentFileId: 'mn-1',
        pageIndex: 5,
      ));
    });

    tearDown(() {
      container.dispose();
    });

    test('should update active tab index', () {
      // ACT
      container.read(switchTabProvider)(1);

      // ASSERT
      expect(container.read(activeTabIndexProvider), equals(1));
    });

    test('should load content for the switched tab', () {
      // ACT
      container.read(switchTabProvider)(1);

      // ASSERT
      expect(container.read(currentContentFileIdProvider), equals('mn-1'));
      expect(container.read(currentPageIndexProvider), equals(5));
    });

    test('should derive pagination state from tab via active*Provider', () {
      // ARRANGE - Update the tab's page state
      final tabs = container.read(tabsProvider);
      final updatedTab = tabs[1].copyWith(pageStart: 3, pageEnd: 8);
      container.read(tabsProvider.notifier).updateTab(1, updatedTab);

      // ACT
      container.read(switchTabProvider)(1);

      // ASSERT
      // Pagination is now derived from the active tab, not restored to global providers
      expect(container.read(activePageStartProvider), equals(3));
      expect(container.read(activePageEndProvider), equals(8));
    });
  });
}

// Helper function to create test ReaderTab

ReaderTab _createTestReaderTab({
  required String nodeKey,
  String? contentFileId,
  int pageIndex = 0,
}) {
  return ReaderTab.fromNode(
    nodeKey: nodeKey,
    paliName: 'Test Pali Name',
    sinhalaName: 'Test Sinhala Name',
    contentFileId: contentFileId,
    pageIndex: pageIndex,
  );
}

// Helper function to create test SearchResult
SearchResult _createTestSearchResult({
  required String nodeKey,
  required String contentFileId,
  String title = 'Test Title',
  SearchCategory category = SearchCategory.title,
  int pageIndex = 0,
  int entryIndex = 0,
}) {
  return SearchResult(
    id: 'test_$nodeKey',
    editionId: 'bjt',
    category: category,
    title: title,
    subtitle: 'Test Subtitle',
    matchedText: 'Test matched text',
    contentFileId: contentFileId,
    pageIndex: pageIndex,
    entryIndex: entryIndex,
    nodeKey: nodeKey,
    language: 'pali',
  );
}
