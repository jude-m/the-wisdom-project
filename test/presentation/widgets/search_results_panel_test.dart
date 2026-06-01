/// Widget tests for SearchResultsPanel — edge cases that need mocked state.
///
/// These complement the E2E integration tests in `integration_test/search/`.
/// Only scenarios that are impossible to reproduce with real data are kept here:
/// loading states, error states, boundary badge values, and callback wiring.
library;

import 'dart:io' show SocketException;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_wisdom_project/core/localization/l10n/app_localizations.dart';
import 'package:the_wisdom_project/domain/entities/content/content_language.dart';
import 'package:the_wisdom_project/domain/entities/failure.dart';
import 'package:the_wisdom_project/domain/entities/navigation/tipitaka_tree_node.dart';
import 'package:the_wisdom_project/domain/entities/search/search_result_type.dart';
import 'package:the_wisdom_project/domain/entities/search/search_result.dart';
import 'package:the_wisdom_project/presentation/providers/content_language_provider.dart';
import 'package:the_wisdom_project/presentation/providers/navigation_tree_provider.dart';
import 'package:the_wisdom_project/presentation/providers/search_provider.dart';
import 'package:the_wisdom_project/presentation/providers/search_state.dart';
import 'package:the_wisdom_project/presentation/widgets/search/search_results_panel.dart';

import '../../helpers/pump_app.dart';

/// Fake implementation for testing — allows injecting arbitrary SearchState.
///
/// Implements only the methods the panel actually calls. Anything else
/// throws an [UnimplementedError] that names the missing member, so a
/// future panel change that calls a new method fails loudly with a useful
/// message (instead of the cryptic NoSuchMethodError you'd get from
/// super.noSuchMethod).
class FakeSearchStateNotifier extends StateNotifier<SearchState>
    implements SearchStateNotifier {
  FakeSearchStateNotifier(super.state);

  @override
  Future<void> selectResultType(SearchResultType category) async {
    state = state.copyWith(selectedResultType: category);
  }

  // Lets the §4b live-update test flip the search language at runtime.
  @override
  void setLanguageFilter({bool? pali, bool? sinhala}) {
    state = state.copyWith(
      searchInPali: pali ?? state.searchInPali,
      searchInSinhala: sinhala ?? state.searchInSinhala,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      'FakeSearchStateNotifier does not implement '
      '${invocation.memberName} — add it to the fake if your test needs it.',
    );
  }
}

/// Helper to pump SearchResultsPanel with a given [SearchState].
///
/// Returns the [FakeSearchStateNotifier] so a test can mutate state at runtime
/// (e.g. flip the search language). Extra [overrides] let a test supply a real
/// navigation tree / display language for the result-tile label tests.
Future<FakeSearchStateNotifier> _pumpPanel(
  WidgetTester tester, {
  required SearchState state,
  VoidCallback? onClose,
  void Function(SearchResult)? onResultTap,
  List<Override> overrides = const [],
}) async {
  final notifier = FakeSearchStateNotifier(state);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // The result tile re-derives its labels in the active Content
        // Language (`searchResultLabels`), which reads keyValueStoreProvider —
        // defaultTestOverrides() supplies an in-memory store for it.
        ...defaultTestOverrides(),
        searchStateProvider.overrideWith((ref) => notifier),
        ...overrides,
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SearchResultsPanel(
            onClose: onClose ?? () {},
            onResultTap: onResultTap,
          ),
        ),
      ),
    ),
  );
  return notifier;
}

void main() {
  group('SearchResultsPanel — edge cases (mocked state)', () {
    // ── Loading states ──────────────────────────────────────────────────

    testWidgets('shows loading indicator when isLoading is true (All tab)',
        (tester) async {
      await _pumpPanel(
        tester,
        state: const SearchState(
          rawQueryText: 'test',
          effectiveQueryText: 'test',
          isLoading: true,
          selectedResultType: SearchResultType.topResults,
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets(
        'shows loading indicator when fullResults is loading (specific tab)',
        (tester) async {
      await _pumpPanel(
        tester,
        state: const SearchState(
          rawQueryText: 'test',
          effectiveQueryText: 'test',
          selectedResultType: SearchResultType.title,
          fullResults: AsyncValue.loading(),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    // ── Error state ─────────────────────────────────────────────────────

    testWidgets('generic error → errorLoadingSearch, no raw leak, no Retry',
        (tester) async {
      await _pumpPanel(
        tester,
        state: SearchState(
          rawQueryText: 'metta',
          effectiveQueryText: 'metta',
          selectedResultType: SearchResultType.title,
          fullResults: AsyncValue.error(
            Exception('LEAKED-RAW-MESSAGE'),
            StackTrace.current,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Error loading results'), findsOneWidget);
      expect(find.text('Please try again in a moment.'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      // Retry was removed — error states are non-actionable now.
      expect(find.text('Retry'), findsNothing);
      expect(find.byIcon(Icons.refresh), findsNothing);
      // Raw error.toString() must NOT be on screen.
      expect(find.textContaining('LEAKED-RAW-MESSAGE'), findsNothing);
    });

    testWidgets('Failure wrapping a SocketException → offline copy, no Retry',
        (tester) async {
      // SocketException's runtime type name is matched by the classifier,
      // and `Failure.error` is unwrapped one level — so this routes the
      // panel to the offline preset.
      const failure = Failure.dataLoadFailure(
        message: 'fts',
        error: SocketException('failed host lookup'),
      );
      await _pumpPanel(
        tester,
        state: SearchState(
          rawQueryText: 'metta',
          effectiveQueryText: 'metta',
          selectedResultType: SearchResultType.title,
          fullResults: AsyncValue.error(failure, StackTrace.current),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cannot reach the server'), findsOneWidget);
      expect(
        find.text('Check your connection and try again.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
      // Retry was removed; on web the user can refresh the page instead.
      expect(find.text('Retry'), findsNothing);
    });

    // ── Badge boundary values ───────────────────────────────────────────

    testWidgets('zero count badges show "0" on all 3 category tabs',
        (tester) async {
      await _pumpPanel(
        tester,
        state: const SearchState(
          rawQueryText: 'test',
          effectiveQueryText: 'test',
          countByResultType: {
            SearchResultType.topResults: 0,
            SearchResultType.title: 0,
            SearchResultType.fullText: 0,
            SearchResultType.definition: 0,
          },
        ),
      );

      // Three "0" badges (Title, Full text, Definition — not Top Results).
      expect(find.text('0'), findsNWidgets(3));
    });

    testWidgets('badge at exactly 100 shows "100", not "100+"',
        (tester) async {
      await _pumpPanel(
        tester,
        state: const SearchState(
          rawQueryText: 'test',
          effectiveQueryText: 'test',
          countByResultType: {
            SearchResultType.title: 100,
          },
        ),
      );

      expect(find.text('100'), findsOneWidget);
      expect(find.text('100+'), findsNothing);
    });

    // ── Callback wiring ─────────────────────────────────────────────────

    testWidgets('onClose callback fires when close button tapped',
        (tester) async {
      bool closeCalled = false;

      await _pumpPanel(
        tester,
        state: const SearchState(
          rawQueryText: 'test',
          effectiveQueryText: 'test',
        ),
        onClose: () => closeCalled = true,
      );

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(closeCalled, isTrue);
    });

    testWidgets('onResultTap callback fires when result is tapped',
        (tester) async {
      SearchResult? tappedResult;
      const result = SearchResult(
        id: 'test_id',
        editionId: 'bjt',
        resultType: SearchResultType.title,
        title: 'Metta Sutta',
        subtitle: 'Sutta Nipata',
        matchedText: '',
        contentFileId: 'sn-1',
        pageIndex: 0,
        entryIndex: 0,
        nodeKey: 'sn-1',
        language: 'pali',
      );

      await _pumpPanel(
        tester,
        state: const SearchState(
          rawQueryText: 'metta',
          effectiveQueryText: 'metta',
          fullResults: AsyncValue.data([result]),
          selectedResultType: SearchResultType.title,
        ),
        onResultTap: (r) => tappedResult = r,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ListTile));
      await tester.pump();

      expect(tappedResult, isNotNull);
      expect(tappedResult?.title, equals('Metta Sutta'));
    });
  });

  // ── Result-tile label follows the search-display language (§4b) ──────────
  //
  // The payoff of the whole feature: a result tile renders its title in the
  // language the search is scoped to (not the repo-tagged language), and flips
  // live when the toggle changes. This transitively exercises
  // effectiveSearchDisplayLanguageProvider → searchResultLabels → the tile.
  group('SearchResultsPanel — tile label tracks the search language', () {
    // A node whose Pali and Sinhala names differ, so the rendered title reveals
    // which display language won. (Pali is in Sinhala script in real data; here
    // the Pali name is Latin only so the two are unmistakably distinct on screen.)
    final tree = [
      const TipitakaTreeNode(
        nodeKey: 'dn-1',
        paliName: 'Brahmajālasutta',
        sinhalaName: 'බ්‍රහ්මජාලසූත්‍රය',
        hierarchyLevel: 2,
        entryPageIndex: 0,
        entryIndexInPage: 0,
        parentNodeKey: null,
        contentFileId: 'dn-1',
      ),
    ];

    const result = SearchResult(
      id: 'title_dn-1',
      editionId: 'bjt',
      resultType: SearchResultType.title,
      title: 'Brahmajālasutta',
      subtitle: 'Dīgha Nikāya',
      matchedText: '',
      contentFileId: 'dn-1',
      pageIndex: 0,
      entryIndex: 0,
      nodeKey: 'dn-1',
      language: 'pali',
    );

    SearchState stateWith({required bool pali, required bool sinhala}) =>
        SearchState(
          rawQueryText: 'metta',
          effectiveQueryText: 'metta',
          selectedResultType: SearchResultType.title,
          fullResults: const AsyncValue.data([result]),
          searchInPali: pali,
          searchInSinhala: sinhala,
        );

    List<Override> treeOverrides(ContentLanguage reading) => [
          navigationTreeProvider.overrideWith((ref) async => tree),
          effectiveContentLanguageProvider.overrideWithValue(reading),
        ];

    testWidgets('both on + reading Sinhala → tile shows the Sinhala name',
        (tester) async {
      await _pumpPanel(
        tester,
        state: stateWith(pali: true, sinhala: true),
        overrides: treeOverrides(ContentLanguage.sinhala),
      );
      await tester.pumpAndSettle();

      expect(find.text('බ්‍රහ්මජාලසූත්‍රය'), findsOneWidget);
      expect(find.text('Brahmajālasutta'), findsNothing);
    });

    testWidgets(
        'Pali-only overrides a Sinhala reading pref → tile shows the Pali name',
        (tester) async {
      // Narrowing the search to Pali must reach the pixels, even though the
      // user reads in Sinhala.
      await _pumpPanel(
        tester,
        state: stateWith(pali: true, sinhala: false),
        overrides: treeOverrides(ContentLanguage.sinhala),
      );
      await tester.pumpAndSettle();

      expect(find.text('Brahmajālasutta'), findsOneWidget);
      expect(find.text('බ්‍රහ්මජාලසූත්‍රය'), findsNothing);
    });

    testWidgets('flipping the toggle re-renders the tile into the other language',
        (tester) async {
      final notifier = await _pumpPanel(
        tester,
        state: stateWith(pali: true, sinhala: true),
        overrides: treeOverrides(ContentLanguage.sinhala),
      );
      await tester.pumpAndSettle();

      // Starts in Sinhala (both on + Sinhala reading pref).
      expect(find.text('බ්‍රහ්මජාලසූත්‍රය'), findsOneWidget);

      // Narrow to Pali-only → the same tile must switch to the Pali name live.
      notifier.setLanguageFilter(pali: true, sinhala: false);
      await tester.pumpAndSettle();

      expect(find.text('Brahmajālasutta'), findsOneWidget);
      expect(find.text('බ්‍රහ්මජාලසූත්‍රය'), findsNothing);
    });
  });
}
