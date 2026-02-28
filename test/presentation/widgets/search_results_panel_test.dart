/// Widget tests for SearchResultsPanel — edge cases that need mocked state.
///
/// These complement the E2E integration tests in `integration_test/search/`.
/// Only scenarios that are impossible to reproduce with real data are kept here:
/// loading states, error states, boundary badge values, and callback wiring.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_wisdom_project/core/localization/l10n/app_localizations.dart';
import 'package:the_wisdom_project/domain/entities/search/search_result_type.dart';
import 'package:the_wisdom_project/domain/entities/search/search_result.dart';
import 'package:the_wisdom_project/presentation/providers/search_provider.dart';
import 'package:the_wisdom_project/presentation/providers/search_state.dart';
import 'package:the_wisdom_project/presentation/widgets/search/search_results_panel.dart';

/// Fake implementation for testing — allows injecting arbitrary SearchState.
class FakeSearchStateNotifier extends StateNotifier<SearchState>
    implements SearchStateNotifier {
  FakeSearchStateNotifier(super.state);

  @override
  Future<void> selectResultType(SearchResultType category) async {
    state = state.copyWith(selectedResultType: category);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Helper to pump SearchResultsPanel with a given [SearchState].
Future<void> _pumpPanel(
  WidgetTester tester, {
  required SearchState state,
  VoidCallback? onClose,
  void Function(SearchResult)? onResultTap,
}) async {
  final notifier = FakeSearchStateNotifier(state);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        searchStateProvider.overrideWith((ref) => notifier),
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

    testWidgets('shows error state with retry button', (tester) async {
      await _pumpPanel(
        tester,
        state: SearchState(
          rawQueryText: 'test',
          effectiveQueryText: 'test',
          selectedResultType: SearchResultType.title,
          fullResults: AsyncValue.error(
            Exception('Test error'),
            StackTrace.current,
          ),
        ),
      );

      expect(find.text('Failed to load results'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
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
}
