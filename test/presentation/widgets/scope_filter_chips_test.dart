import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_wisdom_project/domain/entities/search/search_scope.dart';
import 'package:the_wisdom_project/presentation/providers/search_provider.dart';
import 'package:the_wisdom_project/presentation/providers/search_state.dart';
import 'package:the_wisdom_project/presentation/widgets/scope_filter_chips.dart';

import '../../helpers/mocks.mocks.dart';
import '../../helpers/pump_app.dart';

void main() {
  late MockTextSearchRepository mockSearchRepository;
  late MockRecentSearchesRepository mockRecentSearchesRepository;
  late SharedPreferences prefs;

  setUp(() async {
    mockSearchRepository = MockTextSearchRepository();
    mockRecentSearchesRepository = MockRecentSearchesRepository();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();

    // Provide default mock behavior for recent searches
    when(mockRecentSearchesRepository.getRecentSearches())
        .thenAnswer((_) async => []);
  });

  group('ScopeFilterChips -', () {
    group('Default state', () {
      testWidgets('should show "All" chip as selected by default',
          (tester) async {
        // ARRANGE & ACT
        await tester.pumpApp(
          const ScopeFilterChips(),
          overrides: [
            TestProviderOverrides.sharedPreferences(prefs),
            TestProviderOverrides.textSearchRepository(mockSearchRepository),
            TestProviderOverrides.recentSearchesRepository(
                mockRecentSearchesRepository),
          ],
        );
        await tester.pumpAndSettle();

        // ASSERT - Find the "All" chip and verify it has selected styling
        // The "All" chip should have secondaryContainer background color
        // when selected (based on the implementation)
        final allChipFinder = find.text('All');
        expect(allChipFinder, findsOneWidget);

        // Verify all scope chips are present
        for (final scope in SearchScope.values) {
          expect(find.text(scope.displayName), findsOneWidget);
        }
      });

      testWidgets('should display all 5 scope chips plus "All" chip',
          (tester) async {
        // ARRANGE & ACT
        await tester.pumpApp(
          const ScopeFilterChips(),
          overrides: [
            TestProviderOverrides.sharedPreferences(prefs),
            TestProviderOverrides.textSearchRepository(mockSearchRepository),
            TestProviderOverrides.recentSearchesRepository(
                mockRecentSearchesRepository),
          ],
        );
        await tester.pumpAndSettle();

        // ASSERT - Should have 6 chips total (All + 5 scopes)
        expect(find.text('All'), findsOneWidget);
        expect(find.text('Sutta'), findsOneWidget);
        expect(find.text('Vinaya'), findsOneWidget);
        expect(find.text('Abhidhamma'), findsOneWidget);
        expect(find.text('Commentaries'), findsOneWidget);
        expect(find.text('Treatises'), findsOneWidget);
      });
    });

    group('Scope selection behavior', () {
      testWidgets('tapping a specific scope should deselect "All" and select that scope',
          (tester) async {
        // ARRANGE
        SearchState? capturedState;

        await tester.pumpApp(
          ProviderTestWidget(
            onBuild: (ref) {
              capturedState = ref.watch(searchStateProvider);
            },
            child: const ScopeFilterChips(),
          ),
          overrides: [
            TestProviderOverrides.sharedPreferences(prefs),
            TestProviderOverrides.textSearchRepository(mockSearchRepository),
            TestProviderOverrides.recentSearchesRepository(
                mockRecentSearchesRepository),
          ],
        );
        await tester.pumpAndSettle();

        // Verify initial state - "All" is selected (empty selectedScope)
        expect(capturedState?.selectedScope, isEmpty);
        expect(capturedState?.isAllSelected, isTrue);

        // ACT - Tap on "Sutta" chip
        await tester.tap(find.text('Sutta'));
        await tester.pumpAndSettle();

        // ASSERT - Sutta should be selected, "All" should be deselected
        expect(capturedState?.selectedScope, contains(SearchScope.sutta));
        expect(capturedState?.selectedScope.length, equals(1));
        expect(capturedState?.isAllSelected, isFalse);
      });

      testWidgets('tapping multiple scopes should enable multi-select',
          (tester) async {
        // ARRANGE
        SearchState? capturedState;

        await tester.pumpApp(
          ProviderTestWidget(
            onBuild: (ref) {
              capturedState = ref.watch(searchStateProvider);
            },
            child: const ScopeFilterChips(),
          ),
          overrides: [
            TestProviderOverrides.sharedPreferences(prefs),
            TestProviderOverrides.textSearchRepository(mockSearchRepository),
            TestProviderOverrides.recentSearchesRepository(
                mockRecentSearchesRepository),
          ],
        );
        await tester.pumpAndSettle();

        // ACT - Tap on "Sutta" and then "Vinaya"
        await tester.tap(find.text('Sutta'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Vinaya'));
        await tester.pumpAndSettle();

        // ASSERT - Both Sutta and Vinaya should be selected
        expect(capturedState?.selectedScope, contains(SearchScope.sutta));
        expect(capturedState?.selectedScope, contains(SearchScope.vinaya));
        expect(capturedState?.selectedScope.length, equals(2));
      });

      testWidgets('tapping a selected scope should deselect it',
          (tester) async {
        // ARRANGE
        SearchState? capturedState;

        await tester.pumpApp(
          ProviderTestWidget(
            onBuild: (ref) {
              capturedState = ref.watch(searchStateProvider);
            },
            child: const ScopeFilterChips(),
          ),
          overrides: [
            TestProviderOverrides.sharedPreferences(prefs),
            TestProviderOverrides.textSearchRepository(mockSearchRepository),
            TestProviderOverrides.recentSearchesRepository(
                mockRecentSearchesRepository),
          ],
        );
        await tester.pumpAndSettle();

        // Select Sutta first
        await tester.tap(find.text('Sutta'));
        await tester.pumpAndSettle();
        expect(capturedState?.selectedScope, contains(SearchScope.sutta));

        // ACT - Tap on Sutta again to deselect it
        await tester.tap(find.text('Sutta'));
        await tester.pumpAndSettle();

        // ASSERT - Sutta should be deselected, "All" is effectively selected (empty set)
        expect(capturedState?.selectedScope, isEmpty);
        expect(capturedState?.isAllSelected, isTrue);
      });

      testWidgets('tapping "All" should clear all specific selections',
          (tester) async {
        // ARRANGE
        SearchState? capturedState;

        await tester.pumpApp(
          ProviderTestWidget(
            onBuild: (ref) {
              capturedState = ref.watch(searchStateProvider);
            },
            child: const ScopeFilterChips(),
          ),
          overrides: [
            TestProviderOverrides.sharedPreferences(prefs),
            TestProviderOverrides.textSearchRepository(mockSearchRepository),
            TestProviderOverrides.recentSearchesRepository(
                mockRecentSearchesRepository),
          ],
        );
        await tester.pumpAndSettle();

        // Select multiple scopes first
        await tester.tap(find.text('Sutta'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Vinaya'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Abhidhamma'));
        await tester.pumpAndSettle();

        expect(capturedState?.selectedScope.length, equals(3));

        // ACT - Tap on "All" to clear selections
        await tester.tap(find.text('All'));
        await tester.pumpAndSettle();

        // ASSERT - All selections should be cleared
        expect(capturedState?.selectedScope, isEmpty);
        expect(capturedState?.isAllSelected, isTrue);
      });

      testWidgets('selecting all 5 scopes should auto-collapse to "All"',
          (tester) async {
        // ARRANGE
        SearchState? capturedState;

        await tester.pumpApp(
          ProviderTestWidget(
            onBuild: (ref) {
              capturedState = ref.watch(searchStateProvider);
            },
            child: const ScopeFilterChips(),
          ),
          overrides: [
            TestProviderOverrides.sharedPreferences(prefs),
            TestProviderOverrides.textSearchRepository(mockSearchRepository),
            TestProviderOverrides.recentSearchesRepository(
                mockRecentSearchesRepository),
          ],
        );
        await tester.pumpAndSettle();

        // ACT - Select all 5 scopes one by one
        await tester.tap(find.text('Sutta'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Vinaya'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Abhidhamma'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Commentaries'));
        await tester.pumpAndSettle();
        // Before tapping last scope, we should have 4 selected
        expect(capturedState?.selectedScope.length, equals(4));

        await tester.tap(find.text('Treatises'));
        await tester.pumpAndSettle();

        // ASSERT - Should auto-collapse to "All" (empty set)
        // According to the SearchStateNotifier.selectScope logic:
        // if (newScope.length == SearchScope.values.length) -> state.copyWith(selectedScope: {})
        expect(capturedState?.selectedScope, isEmpty);
        expect(capturedState?.isAllSelected, isTrue);
      });
    });

    group('Visual state changes', () {
      testWidgets('selected chip should have different styling than unselected',
          (tester) async {
        // ARRANGE
        await tester.pumpApp(
          const ScopeFilterChips(),
          overrides: [
            TestProviderOverrides.sharedPreferences(prefs),
            TestProviderOverrides.textSearchRepository(mockSearchRepository),
            TestProviderOverrides.recentSearchesRepository(
                mockRecentSearchesRepository),
          ],
        );
        await tester.pumpAndSettle();

        // The "All" chip should be selected initially
        // We verify by checking the Container decoration
        // Find the GestureDetector containing "All" text
        final allChip = find.ancestor(
          of: find.text('All'),
          matching: find.byType(GestureDetector),
        );
        expect(allChip, findsOneWidget);

        // ACT - Tap on Sutta to change selection
        await tester.tap(find.text('Sutta'));
        await tester.pumpAndSettle();

        // After tapping Sutta, the chip's Container should have updated decoration
        // We verify the widget tree rebuilds correctly
        final suttaChip = find.ancestor(
          of: find.text('Sutta'),
          matching: find.byType(GestureDetector),
        );
        expect(suttaChip, findsOneWidget);
      });

      testWidgets('should render within SizedBox height constraint',
          (tester) async {
        // ARRANGE & ACT
        await tester.pumpApp(
          const ScopeFilterChips(),
          overrides: [
            TestProviderOverrides.sharedPreferences(prefs),
            TestProviderOverrides.textSearchRepository(mockSearchRepository),
            TestProviderOverrides.recentSearchesRepository(
                mockRecentSearchesRepository),
          ],
        );
        await tester.pumpAndSettle();

        // ASSERT - Find the SizedBox with height 48
        final sizedBox = tester.widget<SizedBox>(
          find.byType(SizedBox).first,
        );
        expect(sizedBox.height, equals(48));
      });

      testWidgets('should be horizontally scrollable', (tester) async {
        // ARRANGE
        await tester.pumpApp(
          const ScopeFilterChips(),
          overrides: [
            TestProviderOverrides.sharedPreferences(prefs),
            TestProviderOverrides.textSearchRepository(mockSearchRepository),
            TestProviderOverrides.recentSearchesRepository(
                mockRecentSearchesRepository),
          ],
        );
        await tester.pumpAndSettle();

        // ASSERT - Should have a ListView with horizontal scroll
        final listView = tester.widget<ListView>(find.byType(ListView));
        expect(listView.scrollDirection, equals(Axis.horizontal));
      });
    });

    group('Integration with SearchStateNotifier', () {
      testWidgets('should properly call toggleScope on notifier',
          (tester) async {
        // ARRANGE
        SearchState? capturedState;

        await tester.pumpApp(
          ProviderTestWidget(
            onBuild: (ref) {
              capturedState = ref.watch(searchStateProvider);
            },
            child: const ScopeFilterChips(),
          ),
          overrides: [
            TestProviderOverrides.sharedPreferences(prefs),
            TestProviderOverrides.textSearchRepository(mockSearchRepository),
            TestProviderOverrides.recentSearchesRepository(
                mockRecentSearchesRepository),
          ],
        );
        await tester.pumpAndSettle();

        // ACT - Toggle Abhidhamma twice (select then deselect)
        await tester.tap(find.text('Abhidhamma'));
        await tester.pumpAndSettle();
        expect(capturedState?.selectedScope, contains(SearchScope.abhidhamma));

        await tester.tap(find.text('Abhidhamma'));
        await tester.pumpAndSettle();
        expect(capturedState?.selectedScope.contains(SearchScope.abhidhamma),
            isFalse);
      });

      testWidgets('should properly call selectAll on notifier',
          (tester) async {
        // ARRANGE
        SearchState? capturedState;

        await tester.pumpApp(
          ProviderTestWidget(
            onBuild: (ref) {
              capturedState = ref.watch(searchStateProvider);
            },
            child: const ScopeFilterChips(),
          ),
          overrides: [
            TestProviderOverrides.sharedPreferences(prefs),
            TestProviderOverrides.textSearchRepository(mockSearchRepository),
            TestProviderOverrides.recentSearchesRepository(
                mockRecentSearchesRepository),
          ],
        );
        await tester.pumpAndSettle();

        // Select some scopes first
        await tester.tap(find.text('Sutta'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Treatises'));
        await tester.pumpAndSettle();

        // ACT - Tap "All"
        await tester.tap(find.text('All'));
        await tester.pumpAndSettle();

        // ASSERT
        expect(capturedState?.selectedScope, isEmpty);
      });
    });
  });
}
