import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_wisdom_project/core/constants/constants.dart';
import 'package:the_wisdom_project/domain/entities/search/search_scope_chip.dart';
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
      testWidgets('should render all chips with "All" selected by default',
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

        // Verify all 5 scope chips are present
        expect(searchScopeChips.length, equals(5));
      });
    });

    group('Scope selection behavior', () {
      testWidgets(
          'tapping a specific scope should deselect "All" and select that scope',
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

        // Verify initial state - "All" is selected (empty scope)
        expect(capturedState?.scope, isEmpty);
        expect(capturedState?.isAllSelected, isTrue);

        // ACT - Tap on "Sutta" chip
        await tester.tap(find.text('Sutta'));
        await tester.pumpAndSettle();

        // ASSERT - Sutta should be selected, "All" should be deselected
        expect(capturedState?.scope, contains(TipitakaNodeKeys.suttaPitaka));
        expect(capturedState?.scope.length, equals(1));
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
        expect(capturedState?.scope, contains(TipitakaNodeKeys.suttaPitaka));
        expect(capturedState?.scope, contains(TipitakaNodeKeys.vinayaPitaka));
        expect(capturedState?.scope.length, equals(2));
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
        expect(capturedState?.scope, contains(TipitakaNodeKeys.suttaPitaka));

        // ACT - Tap on Sutta again to deselect it
        await tester.tap(find.text('Sutta'));
        await tester.pumpAndSettle();

        // ASSERT - Sutta should be deselected, "All" is effectively selected (empty set)
        expect(capturedState?.scope, isEmpty);
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

        expect(capturedState?.scope.length, equals(3));

        // ACT - Tap on "All" to clear selections
        await tester.tap(find.text('All'));
        await tester.pumpAndSettle();

        // ASSERT - All selections should be cleared
        expect(capturedState?.scope, isEmpty);
        expect(capturedState?.isAllSelected, isTrue);
      });

      testWidgets('tapping chips toggles them individually', (tester) async {
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

        // ACT - Select several scopes
        await tester.tap(find.text('Sutta'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Vinaya'));
        await tester.pumpAndSettle();

        // ASSERT - Should have 2 scopes (multi-select behavior)
        expect(capturedState?.scope.length, equals(2));
        expect(capturedState?.isAllSelected, isFalse);
      });
    });

    group('Layout structure', () {
      testWidgets('should have correct layout constraints and scrolling',
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

        // ASSERT - SizedBox with correct height
        final sizedBox = tester.widget<SizedBox>(
          find.byType(SizedBox).first,
        );
        expect(sizedBox.height, equals(48));

        // ListView with horizontal scroll
        final listView = tester.widget<ListView>(find.byType(ListView));
        expect(listView.scrollDirection, equals(Axis.horizontal));

        // All chips should render correctly
        final allChip = find.ancestor(
          of: find.text('All'),
          matching: find.byType(GestureDetector),
        );
        expect(allChip, findsOneWidget);
      });
    });
  });
}
