import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_wisdom_project/presentation/models/in_page_search_state.dart';
import 'package:the_wisdom_project/presentation/models/reader_tab.dart';
import 'package:the_wisdom_project/presentation/providers/in_page_search_provider.dart';
import 'package:the_wisdom_project/presentation/providers/tab_provider.dart';

void main() {
  late ProviderContainer container;

  /// Sets up a container with [tabCount] tabs and activates the first one.
  ProviderContainer createContainerWithTabs(int tabCount) {
    final c = ProviderContainer();
    for (var i = 0; i < tabCount; i++) {
      c.read(tabsProvider.notifier).addTab(
            ReaderTab.fromNode(
              nodeKey: 'node-$i',
              paliName: 'Tab $i',
              sinhalaName: 'Tab $i',
              contentFileId: 'file-$i',
            ),
          );
    }
    if (tabCount > 0) {
      c.read(activeTabIndexProvider.notifier).state = 0;
    }
    return c;
  }

  setUp(() {
    container = createContainerWithTabs(1);
  });

  tearDown(() {
    container.dispose();
  });

  group('InPageSearchNotifier -', () {
    group('openSearch / closeSearch', () {
      test('toggles isVisible and retains query on close', () {
        final notifier = container.read(inPageSearchStatesProvider.notifier);

        notifier.openSearch();
        expect(container.read(activeInPageSearchStateProvider).isVisible, true);

        notifier.updateQuery('ධම්ම');
        notifier.closeSearch();

        final state = container.read(activeInPageSearchStateProvider);
        expect(state.isVisible, false);
        expect(state.rawQuery, 'ධම්ම');
      });

      test('does nothing when no active tab (index < 0)', () {
        container.read(activeTabIndexProvider.notifier).state = -1;
        container.read(inPageSearchStatesProvider.notifier).openSearch();
        expect(container.read(inPageSearchStatesProvider), isEmpty);
      });
    });

    group('clearQuery', () {
      test('resets rawQuery, effectiveQuery, matches, and currentMatchIndex',
          () {
        final notifier = container.read(inPageSearchStatesProvider.notifier);
        notifier.openSearch();
        notifier.updateQuery('සුතං');
        notifier.clearQuery();

        final state = container.read(activeInPageSearchStateProvider);
        expect(state.rawQuery, '');
        expect(state.effectiveQuery, '');
        expect(state.matches, isEmpty);
        expect(state.currentMatchIndex, -1);
      });
    });

    group('updateQuery', () {
      test('empty query clears immediately, non-empty updates before debounce',
          () {
        fakeAsync((async) {
          final notifier = container.read(inPageSearchStatesProvider.notifier);
          notifier.openSearch();

          // Non-empty: rawQuery updates immediately
          notifier.updateQuery('සුතං');
          expect(container.read(activeInPageSearchStateProvider).rawQuery, 'සුතං');
          expect(
            container.read(activeInPageSearchStateProvider).effectiveQuery,
            isNotEmpty,
          );

          // Empty: clears immediately without debounce
          notifier.updateQuery('');
          final state = container.read(activeInPageSearchStateProvider);
          expect(state.rawQuery, '');
          expect(state.effectiveQuery, '');
          expect(state.matches, isEmpty);
        });
      });

      test('rapid typing only keeps the last query (debounce)', () {
        fakeAsync((async) {
          final notifier = container.read(inPageSearchStatesProvider.notifier);
          notifier.openSearch();
          notifier.updateQuery('ධ');
          notifier.updateQuery('ධම්');
          notifier.updateQuery('ධම්ම');

          async.elapse(const Duration(milliseconds: 300));

          expect(
            container.read(activeInPageSearchStateProvider).rawQuery,
            'ධම්ම',
          );
        });
      });
    });

    group('nextMatch / previousMatch', () {
      test('nextMatch wraps from last to first', () {
        container.dispose();
        container = _createContainerWithMatches(3, currentIndex: 2);

        container.read(inPageSearchStatesProvider.notifier).nextMatch();
        expect(
          container.read(activeInPageSearchStateProvider).currentMatchIndex,
          0,
        );
      });

      test('previousMatch wraps from first to last', () {
        container.dispose();
        container = _createContainerWithMatches(3, currentIndex: 0);

        container.read(inPageSearchStatesProvider.notifier).previousMatch();
        expect(
          container.read(activeInPageSearchStateProvider).currentMatchIndex,
          2,
        );
      });

      test('both do nothing when matches is empty', () {
        container.read(inPageSearchStatesProvider.notifier).openSearch();

        container.read(inPageSearchStatesProvider.notifier).nextMatch();
        expect(
          container.read(activeInPageSearchStateProvider).currentMatchIndex,
          -1,
        );

        container.read(inPageSearchStatesProvider.notifier).previousMatch();
        expect(
          container.read(activeInPageSearchStateProvider).currentMatchIndex,
          -1,
        );
      });
    });

    group('onTabClosed', () {
      test('removes closed tab state and re-indexes remaining', () {
        container.dispose();
        container = createContainerWithTabs(3);

        final notifier = container.read(inPageSearchStatesProvider.notifier);

        // Open search on tab 0 and tab 2 with different queries
        container.read(activeTabIndexProvider.notifier).state = 0;
        notifier.openSearch();
        notifier.updateQuery('query-0');
        container.read(activeTabIndexProvider.notifier).state = 2;
        notifier.openSearch();
        notifier.updateQuery('query-2');

        // Close tab 0
        notifier.onTabClosed(0);

        final states = container.read(inPageSearchStatesProvider);
        // Original tab 2 (query-2) should now be at key 1
        expect(states[1]?.rawQuery, 'query-2');
        expect(states.containsKey(2), false);
      });

      test('closing last remaining tab leaves state empty', () {
        final notifier = container.read(inPageSearchStatesProvider.notifier);
        notifier.openSearch();
        notifier.onTabClosed(0);
        expect(container.read(inPageSearchStatesProvider), isEmpty);
      });
    });

    group('clearAll', () {
      test('removes all search state', () {
        container.dispose();
        container = createContainerWithTabs(3);

        final notifier = container.read(inPageSearchStatesProvider.notifier);
        for (var i = 0; i < 3; i++) {
          container.read(activeTabIndexProvider.notifier).state = i;
          notifier.openSearch();
        }

        notifier.clearAll();
        expect(container.read(inPageSearchStatesProvider), isEmpty);
      });
    });
  });

  group('activeInPageSearchStateProvider -', () {
    test('search state is independent per tab', () {
      container.dispose();
      container = createContainerWithTabs(2);

      final notifier = container.read(inPageSearchStatesProvider.notifier);

      container.read(activeTabIndexProvider.notifier).state = 0;
      notifier.openSearch();
      notifier.updateQuery('භගවා');

      container.read(activeTabIndexProvider.notifier).state = 1;
      notifier.openSearch();
      notifier.updateQuery('සුතං');

      // Verify isolation
      container.read(activeTabIndexProvider.notifier).state = 0;
      expect(
        container.read(activeInPageSearchStateProvider).rawQuery,
        'භගවා',
      );
      container.read(activeTabIndexProvider.notifier).state = 1;
      expect(
        container.read(activeInPageSearchStateProvider).rawQuery,
        'සුතං',
      );
    });
  });
}

// =============================================================================
// Test helpers
// =============================================================================

/// Creates a [ProviderContainer] with 1 tab and pre-populated search matches.
ProviderContainer _createContainerWithMatches(
  int matchCount, {
  int currentIndex = 0,
}) {
  final matches = List.generate(
    matchCount,
    (i) => InPageMatch(
      pageIndex: 0,
      entryIndex: i,
      languageCode: 'pi',
      matchIndexInEntry: 0,
    ),
  );

  return ProviderContainer(
    overrides: [
      inPageSearchStatesProvider.overrideWith(
        (ref) => _TestableSearchNotifier(ref, {
          0: InPageSearchState(
            isVisible: true,
            rawQuery: 'test',
            effectiveQuery: 'test',
            matches: matches,
            currentMatchIndex: currentIndex,
          ),
        }),
      ),
      activeTabIndexProvider.overrideWith((ref) => 0),
      tabsProvider.overrideWith((ref) {
        final notifier = TabsNotifier();
        notifier.addTab(
          ReaderTab.fromNode(
            nodeKey: 'test-node',
            paliName: 'Test',
            sinhalaName: 'Test',
            contentFileId: 'test-file',
          ),
        );
        return notifier;
      }),
    ],
  );
}

/// Subclass that allows injecting initial state for testing.
class _TestableSearchNotifier extends InPageSearchNotifier {
  _TestableSearchNotifier(
    super.ref,
    Map<int, InPageSearchState> initialState,
  ) {
    state = initialState;
  }
}
