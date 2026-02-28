import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_wisdom_project/core/constants/constants.dart';
import 'package:the_wisdom_project/domain/entities/search/search_result_type.dart';
import 'package:the_wisdom_project/domain/entities/search/search_result.dart';
import 'package:the_wisdom_project/presentation/providers/in_page_search_provider.dart';
import 'package:the_wisdom_project/presentation/providers/navigation_tree_provider.dart';
import 'package:the_wisdom_project/presentation/providers/tab_lifecycle_provider.dart';
import 'package:the_wisdom_project/presentation/providers/tab_provider.dart';
import 'package:the_wisdom_project/presentation/models/reader_tab.dart';

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

    test('should derive activeContentFileIdProvider from tab', () {
      // ARRANGE
      final result = _createTestSearchResult(
        nodeKey: 'mn-1',
        contentFileId: 'mn-1',
      );

      // ACT
      container.read(openTabFromSearchResultProvider)(result);

      // ASSERT - contentFileId is now derived from the active tab
      expect(container.read(activeContentFileIdProvider), equals('mn-1'));
    });

    test('should derive activePageIndexProvider from tab', () {
      // ARRANGE
      final result = _createTestSearchResult(
        nodeKey: 'dn-1',
        contentFileId: 'dn-1',
        pageIndex: 7,
      );

      // ACT
      container.read(openTabFromSearchResultProvider)(result);

      // ASSERT - pageIndex is now derived from the active tab
      expect(container.read(activePageIndexProvider), equals(7));
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
      expect(container.read(activeContentFileIdProvider), equals('mn-1'));
    });

    test('should handle search result with title category', () {
      // ARRANGE
      final result = _createTestSearchResult(
        nodeKey: 'dn-1',
        contentFileId: 'dn-1',
        title: 'Brahmajālasutta',
        category: SearchResultType.title,
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
        category: SearchResultType.fullText,
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

    test('should derive content state for the switched tab', () {
      // ACT
      container.read(switchTabProvider)(1);

      // ASSERT - content state is now derived from the active tab
      expect(container.read(activeContentFileIdProvider), equals('mn-1'));
      expect(container.read(activePageIndexProvider), equals(5));
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

  group('closeTabProvider -', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('closing active tab should select previous tab', () {
      // ARRANGE - Add 3 tabs and make the last one active
      final notifier = container.read(tabsProvider.notifier);
      notifier
          .addTab(_createTestReaderTab(nodeKey: 'dn-1', contentFileId: 'dn-1'));
      notifier
          .addTab(_createTestReaderTab(nodeKey: 'mn-1', contentFileId: 'mn-1'));
      notifier
          .addTab(_createTestReaderTab(nodeKey: 'sn-1', contentFileId: 'sn-1'));

      // Set the last tab (index 2) as active
      container.read(activeTabIndexProvider.notifier).state = 2;
      expect(container.read(activeTabIndexProvider), equals(2));

      // ACT - Close the active tab (index 2)
      container.read(closeTabProvider)(2);

      // ASSERT - Should select previous tab (index 1)
      expect(container.read(activeTabIndexProvider), equals(1));
      expect(container.read(tabsProvider).length, equals(2));
      expect(container.read(activeContentFileIdProvider), equals('mn-1'));
    });

    test('closing active tab when it is the first tab should select next tab',
        () {
      // ARRANGE - Add 2 tabs and make the first one active
      final notifier = container.read(tabsProvider.notifier);
      notifier
          .addTab(_createTestReaderTab(nodeKey: 'dn-1', contentFileId: 'dn-1'));
      notifier
          .addTab(_createTestReaderTab(nodeKey: 'mn-1', contentFileId: 'mn-1'));

      container.read(activeTabIndexProvider.notifier).state = 0;

      // ACT - Close the first tab (index 0)
      container.read(closeTabProvider)(0);

      // ASSERT - Should select the next tab (which is now at index 0)
      expect(container.read(activeTabIndexProvider), equals(0));
      expect(container.read(tabsProvider).length, equals(1));
      expect(container.read(activeContentFileIdProvider), equals('mn-1'));
    });

    test('closing the only tab should set activeTabIndex to -1', () {
      // ARRANGE - Add only 1 tab and make it active
      final notifier = container.read(tabsProvider.notifier);
      notifier
          .addTab(_createTestReaderTab(nodeKey: 'dn-1', contentFileId: 'dn-1'));
      container.read(activeTabIndexProvider.notifier).state = 0;

      // ACT - Close the only tab
      container.read(closeTabProvider)(0);

      // ASSERT - activeTabIndex should be -1 (no tabs)
      expect(container.read(activeTabIndexProvider), equals(-1));
      expect(container.read(tabsProvider), isEmpty);
      expect(container.read(activeContentFileIdProvider), isNull);
    });

    test('closing tab before active should adjust activeTabIndex correctly',
        () {
      // ARRANGE - Add 3 tabs and make the last one (index 2) active
      final notifier = container.read(tabsProvider.notifier);
      notifier
          .addTab(_createTestReaderTab(nodeKey: 'dn-1', contentFileId: 'dn-1'));
      notifier
          .addTab(_createTestReaderTab(nodeKey: 'mn-1', contentFileId: 'mn-1'));
      notifier
          .addTab(_createTestReaderTab(nodeKey: 'sn-1', contentFileId: 'sn-1'));

      container.read(activeTabIndexProvider.notifier).state = 2;

      // ACT - Close the first tab (index 0), which is before the active tab
      container.read(closeTabProvider)(0);

      // ASSERT - Active tab index should be adjusted from 2 to 1
      expect(container.read(activeTabIndexProvider), equals(1));
      expect(container.read(tabsProvider).length, equals(2));
      // The active tab content should still be sn-1
      expect(container.read(activeContentFileIdProvider), equals('sn-1'));
    });

    test('closing tab after active should not change activeTabIndex', () {
      // ARRANGE - Add 3 tabs and make the first one (index 0) active
      final notifier = container.read(tabsProvider.notifier);
      notifier
          .addTab(_createTestReaderTab(nodeKey: 'dn-1', contentFileId: 'dn-1'));
      notifier
          .addTab(_createTestReaderTab(nodeKey: 'mn-1', contentFileId: 'mn-1'));
      notifier
          .addTab(_createTestReaderTab(nodeKey: 'sn-1', contentFileId: 'sn-1'));

      container.read(activeTabIndexProvider.notifier).state = 0;

      // ACT - Close the last tab (index 2), which is after the active tab
      container.read(closeTabProvider)(2);

      // ASSERT - Active tab index should remain 0
      expect(container.read(activeTabIndexProvider), equals(0));
      expect(container.read(tabsProvider).length, equals(2));
      expect(container.read(activeContentFileIdProvider), equals('dn-1'));
    });

    test('scroll positions should be shifted correctly after close', () {
      // ARRANGE - Add 3 tabs with scroll positions
      final notifier = container.read(tabsProvider.notifier);
      notifier
          .addTab(_createTestReaderTab(nodeKey: 'dn-1', contentFileId: 'dn-1'));
      notifier
          .addTab(_createTestReaderTab(nodeKey: 'mn-1', contentFileId: 'mn-1'));
      notifier
          .addTab(_createTestReaderTab(nodeKey: 'sn-1', contentFileId: 'sn-1'));

      // Set scroll positions for all tabs
      container.read(saveTabScrollPositionProvider)(0, 100.0);
      container.read(saveTabScrollPositionProvider)(1, 200.0);
      container.read(saveTabScrollPositionProvider)(2, 300.0);

      container.read(activeTabIndexProvider.notifier).state = 2;

      // ACT - Close tab at index 1
      container.read(closeTabProvider)(1);

      // ASSERT - Scroll positions should be shifted
      // Tab 0 remains at position 100.0
      // Tab 2 (now at index 1) should have position 300.0
      expect(container.read(getTabScrollPositionProvider)(0), equals(100.0));
      expect(container.read(getTabScrollPositionProvider)(1), equals(300.0));
      // Position for removed index should return default (0.0)
      expect(container.read(getTabScrollPositionProvider)(2), equals(0.0));
    });

    test('closing the only tab should clear selectedNode', () {
      // ARRANGE - Add 1 tab and set a selected node
      final notifier = container.read(tabsProvider.notifier);
      notifier
          .addTab(_createTestReaderTab(nodeKey: 'dn-1', contentFileId: 'dn-1'));
      container.read(activeTabIndexProvider.notifier).state = 0;
      container.read(selectedNodeProvider.notifier).state = 'dn-1';

      // ACT - Close the only tab
      container.read(closeTabProvider)(0);

      // ASSERT - selectedNode should be null
      expect(container.read(selectedNodeProvider), isNull);
    });

    test('closing the only tab should reset expandedNodes to default', () {
      // ARRANGE - Add 1 tab and expand some nodes
      final notifier = container.read(tabsProvider.notifier);
      notifier
          .addTab(_createTestReaderTab(nodeKey: 'dn-1', contentFileId: 'dn-1'));
      container.read(activeTabIndexProvider.notifier).state = 0;
      container.read(expandedNodesProvider.notifier).state = {
        TipitakaNodeKeys.dighaNikaya,
        TipitakaNodeKeys.majjhimaNikaya,
        TipitakaNodeKeys.samyuttaNikaya
      };

      // ACT - Close the only tab
      container.read(closeTabProvider)(0);

      // ASSERT - expandedNodes should reset to default (Sutta Pitaka)
      expect(container.read(expandedNodesProvider),
          equals({TipitakaNodeKeys.suttaPitaka}));
    });

    test('closing the only tab should clear scroll positions', () {
      // ARRANGE - Add 1 tab with scroll position
      final notifier = container.read(tabsProvider.notifier);
      notifier
          .addTab(_createTestReaderTab(nodeKey: 'dn-1', contentFileId: 'dn-1'));
      container.read(activeTabIndexProvider.notifier).state = 0;
      container.read(saveTabScrollPositionProvider)(0, 500.0);

      // ACT - Close the only tab
      container.read(closeTabProvider)(0);

      // ASSERT - Scroll positions should be empty
      expect(container.read(tabScrollPositionsProvider), isEmpty);
    });

    test('closing middle tab should correctly shift scroll positions', () {
      // ARRANGE - Add 4 tabs with scroll positions
      final notifier = container.read(tabsProvider.notifier);
      notifier
          .addTab(_createTestReaderTab(nodeKey: 'dn-1', contentFileId: 'dn-1'));
      notifier
          .addTab(_createTestReaderTab(nodeKey: 'mn-1', contentFileId: 'mn-1'));
      notifier
          .addTab(_createTestReaderTab(nodeKey: 'sn-1', contentFileId: 'sn-1'));
      notifier
          .addTab(_createTestReaderTab(nodeKey: 'an-1', contentFileId: 'an-1'));

      container.read(saveTabScrollPositionProvider)(0, 100.0);
      container.read(saveTabScrollPositionProvider)(1, 200.0);
      container.read(saveTabScrollPositionProvider)(2, 300.0);
      container.read(saveTabScrollPositionProvider)(3, 400.0);

      container.read(activeTabIndexProvider.notifier).state = 0;

      // ACT - Close tab at index 1 (middle tab)
      container.read(closeTabProvider)(1);

      // ASSERT - Verify scroll positions are shifted correctly
      // Index 0 stays the same
      expect(container.read(getTabScrollPositionProvider)(0), equals(100.0));
      // Index 2 becomes index 1 with value 300.0
      expect(container.read(getTabScrollPositionProvider)(1), equals(300.0));
      // Index 3 becomes index 2 with value 400.0
      expect(container.read(getTabScrollPositionProvider)(2), equals(400.0));
      // Old index 3 no longer exists
      expect(container.read(getTabScrollPositionProvider)(3), equals(0.0));
    });

    test('closing active middle tab should select previous and shift positions',
        () {
      // ARRANGE - Add 3 tabs, make middle one active
      final notifier = container.read(tabsProvider.notifier);
      notifier
          .addTab(_createTestReaderTab(nodeKey: 'dn-1', contentFileId: 'dn-1'));
      notifier
          .addTab(_createTestReaderTab(nodeKey: 'mn-1', contentFileId: 'mn-1'));
      notifier
          .addTab(_createTestReaderTab(nodeKey: 'sn-1', contentFileId: 'sn-1'));

      container.read(saveTabScrollPositionProvider)(0, 100.0);
      container.read(saveTabScrollPositionProvider)(1, 200.0);
      container.read(saveTabScrollPositionProvider)(2, 300.0);

      container.read(activeTabIndexProvider.notifier).state = 1;

      // ACT - Close the active middle tab
      container.read(closeTabProvider)(1);

      // ASSERT
      // Active index should be 0 (previous tab)
      expect(container.read(activeTabIndexProvider), equals(0));
      // Content should be from the first tab
      expect(container.read(activeContentFileIdProvider), equals('dn-1'));
      // Scroll positions should be shifted
      expect(container.read(getTabScrollPositionProvider)(0), equals(100.0));
      expect(container.read(getTabScrollPositionProvider)(1), equals(300.0));
    });

    // ==========================================================================
    // In-page search state cleanup on tab close
    // ==========================================================================

    test('closing tab should re-index in-page search state', () {
      // ARRANGE - Add 3 tabs with search state
      final notifier = container.read(tabsProvider.notifier);
      notifier
          .addTab(_createTestReaderTab(nodeKey: 'dn-1', contentFileId: 'dn-1'));
      notifier
          .addTab(_createTestReaderTab(nodeKey: 'mn-1', contentFileId: 'mn-1'));
      notifier
          .addTab(_createTestReaderTab(nodeKey: 'sn-1', contentFileId: 'sn-1'));

      // Open search on each tab
      final searchNotifier =
          container.read(inPageSearchStatesProvider.notifier);
      container.read(activeTabIndexProvider.notifier).state = 0;
      searchNotifier.openSearch();
      container.read(activeTabIndexProvider.notifier).state = 1;
      searchNotifier.openSearch();
      container.read(activeTabIndexProvider.notifier).state = 2;
      searchNotifier.openSearch();

      container.read(activeTabIndexProvider.notifier).state = 2;

      // ACT - Close tab 1 (middle tab)
      container.read(closeTabProvider)(1);

      // ASSERT - Search state should be re-indexed
      final states = container.read(inPageSearchStatesProvider);
      // Tab 0 preserved at key 0
      expect(states.containsKey(0), true);
      // Tab 2's search state shifted to key 1
      expect(states.containsKey(1), true);
      // Key 2 no longer exists
      expect(states.containsKey(2), false);
    });

    test('closing the only tab should clear all in-page search state', () {
      // ARRANGE - Add 1 tab with search state
      final notifier = container.read(tabsProvider.notifier);
      notifier
          .addTab(_createTestReaderTab(nodeKey: 'dn-1', contentFileId: 'dn-1'));
      container.read(activeTabIndexProvider.notifier).state = 0;
      container.read(inPageSearchStatesProvider.notifier).openSearch();

      // ACT - Close the only tab
      container.read(closeTabProvider)(0);

      // ASSERT - All search state should be cleared
      expect(container.read(inPageSearchStatesProvider), isEmpty);
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
  SearchResultType category = SearchResultType.title,
  int pageIndex = 0,
  int entryIndex = 0,
}) {
  return SearchResult(
    id: 'test_$nodeKey',
    editionId: 'bjt',
    resultType: category,
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
