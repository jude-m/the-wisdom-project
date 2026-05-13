/// Integration tests for the four panels that consume [StatusMessageView]:
/// search results, navigation tree, multi-pane reader, dictionary sheet.
///
/// Pure widget/unit coverage (every variant rendered correctly +
/// [statusVariantForError] classification table) lives in
/// `test/presentation/widgets/common/status_message_view_test.dart` and
/// runs as part of the regular `flutter test` suite. This file is reserved
/// for tests that require a real Riverpod provider tree.
///
/// What this covers
///   - Each consumer panel in each AsyncValue state (loading, data-empty,
///     error, offline) plus the "select a sutta" info hint on the reader.
///     Error states are non-actionable on purpose — no Retry button is
///     rendered (web users can refresh; mobile assets are bundled, so a
///     retry can't fix an inherent failure).
///
/// Run with:
///   flutter test integration_test/status_message_view_integration_test.dart -d macos
library;

import 'dart:io' show SocketException;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:the_wisdom_project/core/localization/l10n/app_localizations.dart';
import 'package:the_wisdom_project/domain/entities/bjt/bjt_document.dart';
import 'package:the_wisdom_project/domain/entities/dictionary/dictionary_entry.dart';
import 'package:the_wisdom_project/domain/entities/dictionary/dictionary_params.dart';
import 'package:the_wisdom_project/domain/entities/failure.dart';
import 'package:the_wisdom_project/domain/entities/navigation/tipitaka_tree_node.dart';
import 'package:the_wisdom_project/domain/entities/search/search_result.dart';
import 'package:the_wisdom_project/domain/entities/search/search_result_type.dart';
import 'package:the_wisdom_project/presentation/providers/dictionary_provider.dart';
import 'package:the_wisdom_project/presentation/providers/document_provider.dart';
import 'package:the_wisdom_project/presentation/providers/navigation_tree_provider.dart';
import 'package:the_wisdom_project/presentation/providers/search_provider.dart';
import 'package:the_wisdom_project/presentation/providers/search_state.dart';
import 'package:the_wisdom_project/presentation/providers/tab_provider.dart';
import 'package:the_wisdom_project/presentation/widgets/dictionary/dictionary_bottom_sheet.dart';
import 'package:the_wisdom_project/presentation/widgets/reader/multi_pane_reader_widget.dart';
import 'package:the_wisdom_project/presentation/widgets/search/search_results_panel.dart';
import 'package:the_wisdom_project/presentation/widgets/navigation/tree_navigator_widget.dart';

import 'test_overrides.dart';

// ===========================================================================
// Test infrastructure
// ===========================================================================

/// Wraps a widget in [MaterialApp] with l10n, an in-memory KV store, and any
/// caller-supplied provider overrides. Used for every integration assertion
/// in this file.
Future<void> _pumpHosted(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        keyValueStoreOverride(),
        ...overrides,
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // Fixed size so layout doesn't depend on the host device.
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: child,
          ),
        ),
      ),
    ),
  );
}

/// A [SearchStateNotifier] stand-in that lets each test pin the panel to an
/// arbitrary [SearchState]. Implements only what the panel actually calls;
/// every other method throws a clear [UnimplementedError] naming the call.
class _FakeSearchStateNotifier extends StateNotifier<SearchState>
    implements SearchStateNotifier {
  _FakeSearchStateNotifier(super.state);

  @override
  Future<void> selectResultType(SearchResultType type) async {
    state = state.copyWith(selectedResultType: type);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      '_FakeSearchStateNotifier does not implement '
      '${invocation.memberName} — add it to the fake if your test needs it.',
    );
  }
}

/// A minimal [BJTDocument] stub used only as a non-null value for
/// [currentBJTDocumentProvider] in the few cases where we need "data" rather
/// than "no document". Pages are an empty list — fine for the tests below
/// since none of them render the reader's page list.
BJTDocument _emptyDocument() => const BJTDocument(
      fileId: 'stub',
      pages: [],
    );

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // =========================================================================
  // GROUP 1 — TreeNavigatorWidget integration
  // =========================================================================

  group('TreeNavigatorWidget — status states', () {
    testWidgets('loading: spinner before the future resolves', (tester) async {
      await _pumpHosted(
        tester,
        const TreeNavigatorWidget(),
        overrides: [
          // Future that never completes within the test → stays in loading.
          navigationTreeProvider.overrideWith(
            (ref) => Future<List<TipitakaTreeNode>>.delayed(
              const Duration(seconds: 30),
              () => const <TipitakaTreeNode>[],
            ),
          ),
        ],
      );
      // First frame after build: still loading.
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('empty data → empty variant with folder icon override',
        (tester) async {
      await _pumpHosted(
        tester,
        const TreeNavigatorWidget(),
        overrides: [
          navigationTreeProvider
              .overrideWith((ref) async => const <TipitakaTreeNode>[]),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('No content available'), findsOneWidget);
      // Tree empty uses folder_off_outlined; the variant's default
      // search_off icon is wrong for a non-search context.
      expect(find.byIcon(Icons.folder_off_outlined), findsOneWidget);
      expect(find.byIcon(Icons.search_off), findsNothing);
      // No retry on empty — only on errors.
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets(
        'generic error → error variant with errorLoadingTree, raw error not shown, no Retry',
        (tester) async {
      await _pumpHosted(
        tester,
        const TreeNavigatorWidget(),
        overrides: [
          navigationTreeProvider.overrideWith(
            (ref) => Future<List<TipitakaTreeNode>>.error(
              Exception('LEAKED-RAW-MESSAGE'),
            ),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Error loading navigation tree'), findsOneWidget);
      expect(find.text('Please try again in a moment.'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      // Retry was deliberately removed — error states are non-actionable.
      expect(find.text('Retry'), findsNothing);
      expect(find.byIcon(Icons.refresh), findsNothing);
      // Critical: error.toString() must NOT be on screen.
      expect(find.textContaining('LEAKED-RAW-MESSAGE'), findsNothing);
    });

    testWidgets('offline error → cloud_off + offline copy, no Retry',
        (tester) async {
      await _pumpHosted(
        tester,
        const TreeNavigatorWidget(),
        overrides: [
          navigationTreeProvider.overrideWith(
            (ref) => Future<List<TipitakaTreeNode>>.error(
              const SocketException('Failed host lookup'),
            ),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Cannot reach the server'), findsOneWidget);
      expect(
        find.text('Check your connection and try again.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
      // No Retry; web users can refresh the page instead.
      expect(find.text('Retry'), findsNothing);
    });
  });

  // =========================================================================
  // GROUP 2 — SearchResultsPanel integration (specific-tab path)
  // =========================================================================

  group('SearchResultsPanel — fullResults states (specific tab)', () {
    Widget panel() => SearchResultsPanel(onClose: () {});

    testWidgets('loading: spinner', (tester) async {
      final notifier = _FakeSearchStateNotifier(
        const SearchState(
          rawQueryText: 'metta',
          effectiveQueryText: 'metta',
          selectedResultType: SearchResultType.title,
          fullResults: AsyncValue.loading(),
        ),
      );
      await _pumpHosted(
        tester,
        panel(),
        overrides: [
          searchStateProvider.overrideWith((ref) => notifier),
        ],
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('null results (invalid query) → invalid variant',
        (tester) async {
      final notifier = _FakeSearchStateNotifier(
        const SearchState(
          rawQueryText: '',
          effectiveQueryText: '',
          selectedResultType: SearchResultType.title,
          fullResults: AsyncValue.data(null),
        ),
      );
      await _pumpHosted(
        tester,
        panel(),
        overrides: [
          searchStateProvider.overrideWith((ref) => notifier),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid search query'), findsOneWidget);
      expect(find.byIcon(Icons.edit_note), findsOneWidget);
    });

    testWidgets('empty results → "No <category> found"', (tester) async {
      final notifier = _FakeSearchStateNotifier(
        const SearchState(
          rawQueryText: 'xqzmwk',
          effectiveQueryText: 'xqzmwk',
          selectedResultType: SearchResultType.title,
          fullResults: AsyncValue<List<SearchResult>?>.data(<SearchResult>[]),
        ),
      );
      await _pumpHosted(
        tester,
        panel(),
        overrides: [
          searchStateProvider.overrideWith((ref) => notifier),
        ],
      );
      await tester.pumpAndSettle();

      // displayName is "Titles" (plural), lowercased into the placeholder.
      expect(find.text('No titles found'), findsOneWidget);
      expect(find.byIcon(Icons.search_off), findsOneWidget);
    });

    testWidgets('generic error → error variant, no Retry',
        (tester) async {
      const failure = Failure.dataParseFailure(
        message: 'bad json',
        error: FormatException('boom'),
      );
      final notifier = _FakeSearchStateNotifier(
        SearchState(
          rawQueryText: 'metta',
          effectiveQueryText: 'metta',
          selectedResultType: SearchResultType.title,
          fullResults: AsyncValue.error(failure, StackTrace.current),
        ),
      );
      await _pumpHosted(
        tester,
        panel(),
        overrides: [
          searchStateProvider.overrideWith((ref) => notifier),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Error loading results'), findsOneWidget);
      expect(find.text('Please try again in a moment.'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      // Retry was deliberately removed — error states are non-actionable.
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets(
        'offline error (Failure wraps SocketException) → offline copy, no Retry',
        (tester) async {
      const failure = Failure.dataLoadFailure(
        message: 'fts',
        error: SocketException('failed host lookup'),
      );
      final notifier = _FakeSearchStateNotifier(
        SearchState(
          rawQueryText: 'metta',
          effectiveQueryText: 'metta',
          selectedResultType: SearchResultType.title,
          fullResults: AsyncValue.error(failure, StackTrace.current),
        ),
      );
      await _pumpHosted(
        tester,
        panel(),
        overrides: [
          searchStateProvider.overrideWith((ref) => notifier),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Cannot reach the server'), findsOneWidget);
      expect(
        find.text('Check your connection and try again.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
      // No Retry; on web the user can refresh the page instead.
      expect(find.text('Retry'), findsNothing);
    });
  });

  // =========================================================================
  // GROUP 3 — SearchResultsPanel integration (Top Results / "All" tab)
  // =========================================================================

  group('SearchResultsPanel — Top Results tab states', () {
    Widget panel() => SearchResultsPanel(onClose: () {});

    testWidgets('isLoading=true → spinner on All tab', (tester) async {
      final notifier = _FakeSearchStateNotifier(
        const SearchState(
          rawQueryText: 'metta',
          effectiveQueryText: 'metta',
          isLoading: true,
          selectedResultType: SearchResultType.topResults,
        ),
      );
      await _pumpHosted(
        tester,
        panel(),
        overrides: [
          searchStateProvider.overrideWith((ref) => notifier),
        ],
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('null grouped results → invalid variant on All tab',
        (tester) async {
      final notifier = _FakeSearchStateNotifier(
        const SearchState(
          rawQueryText: '',
          effectiveQueryText: '',
          selectedResultType: SearchResultType.topResults,
        ),
      );
      await _pumpHosted(
        tester,
        panel(),
        overrides: [
          searchStateProvider.overrideWith((ref) => notifier),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid search query'), findsOneWidget);
      expect(find.byIcon(Icons.edit_note), findsOneWidget);
    });
  });

  // =========================================================================
  // GROUP 4 — MultiPaneReaderWidget integration
  // =========================================================================

  group('MultiPaneReaderWidget — content states', () {
    testWidgets('no sutta selected → info variant + book-icon override',
        (tester) async {
      await _pumpHosted(
        tester,
        const MultiPaneReaderWidget(),
        overrides: [
          activeContentFileIdProvider.overrideWith((ref) => null),
          // No file → currentBJTDocumentProvider naturally returns
          // AsyncValue.data(null), but override explicitly so the test
          // doesn't depend on activeTabIndex/tabs hydration.
          currentBJTDocumentProvider
              .overrideWith((ref) => const AsyncValue<BJTDocument?>.data(null)),
        ],
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Select a sutta from the tree to begin reading'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
      // Must not show the generic info_outline — override should win.
      expect(find.byIcon(Icons.info_outline), findsNothing);
    });

    testWidgets('loading state → spinner', (tester) async {
      await _pumpHosted(
        tester,
        const MultiPaneReaderWidget(),
        overrides: [
          activeContentFileIdProvider.overrideWith((ref) => 'dn-1'),
          currentBJTDocumentProvider.overrideWith(
            (ref) => const AsyncValue<BJTDocument?>.loading(),
          ),
        ],
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('generic error → errorLoadingContent + clean copy, raw not shown, no Retry',
        (tester) async {
      await _pumpHosted(
        tester,
        const MultiPaneReaderWidget(),
        overrides: [
          activeContentFileIdProvider.overrideWith((ref) => 'dn-1'),
          currentBJTDocumentProvider.overrideWith(
            (ref) => AsyncValue<BJTDocument?>.error(
              Exception('LEAKED-READER-RAW'),
              StackTrace.current,
            ),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Error loading content'), findsOneWidget);
      expect(find.text('Please try again in a moment.'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      // Reader has no Retry — error states are non-actionable.
      expect(find.text('Retry'), findsNothing);
      expect(find.byIcon(Icons.refresh), findsNothing);
      expect(find.textContaining('LEAKED-READER-RAW'), findsNothing);
    });

    testWidgets('offline error → cloud_off + offline copy', (tester) async {
      await _pumpHosted(
        tester,
        const MultiPaneReaderWidget(),
        overrides: [
          activeContentFileIdProvider.overrideWith((ref) => 'dn-1'),
          currentBJTDocumentProvider.overrideWith(
            (ref) => AsyncValue<BJTDocument?>.error(
              const SocketException('failed host lookup'),
              StackTrace.current,
            ),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Cannot reach the server'), findsOneWidget);
      expect(
        find.text('Check your connection and try again.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    });

    testWidgets('document with zero pages in range → empty variant',
        (tester) async {
      // Document loads successfully but `pagesToShow` ends up empty because
      // there are no pages at all. This exercises the StatusVariant.empty
      // branch added by the change.
      await _pumpHosted(
        tester,
        const MultiPaneReaderWidget(),
        overrides: [
          activeContentFileIdProvider.overrideWith((ref) => 'stub'),
          currentBJTDocumentProvider.overrideWith(
            (ref) => AsyncValue<BJTDocument?>.data(_emptyDocument()),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('No content to display'), findsOneWidget);
      // Reader empty state uses the menu_book override, not search_off —
      // user didn't search, so the search icon would be misleading.
      expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
      expect(find.byIcon(Icons.search_off), findsNothing);
    });
  });

  // =========================================================================
  // GROUP 5 — DictionaryBottomSheet integration
  // =========================================================================

  group('DictionaryBottomSheet — lookup states', () {
    /// Sets the selected word so the sheet decides to mount, then pumps.
    Future<ProviderContainer> pumpSheet(
      WidgetTester tester, {
      required AsyncValue<List<DictionaryEntry>> entriesValue,
    }) async {
      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            keyValueStoreOverride(),
            // Pre-set the lookup word so the sheet mounts.
            selectedDictionaryWordProvider.overrideWith((ref) => 'metta'),
            // Override every lookup with the desired AsyncValue regardless of
            // params. We can't use `overrideWithValue` on a family directly,
            // so we use `overrideWith` and synchronously throw / return.
            dictionaryLookupProvider.overrideWith(
              (ref, DictionaryLookupParams params) async {
                return entriesValue.when(
                  data: (entries) => entries,
                  loading: () =>
                      Future<List<DictionaryEntry>>.delayed(
                          const Duration(seconds: 30), () => const []),
                  error: (e, st) =>
                      Future<List<DictionaryEntry>>.error(e, st),
                );
              },
            ),
            dictionaryLookupCountProvider.overrideWith(
              (ref, DictionaryLookupParams params) async => 0,
            ),
          ],
          child: Builder(
            builder: (ctx) {
              container = ProviderScope.containerOf(ctx);
              return const MaterialApp(
                localizationsDelegates:
                    AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: SizedBox(
                    width: 600,
                    height: 800,
                    child: Stack(children: [DictionaryBottomSheet()]),
                  ),
                ),
              );
            },
          ),
        ),
      );
      return container;
    }

    testWidgets('loading → spinner', (tester) async {
      await pumpSheet(
        tester,
        entriesValue: const AsyncValue<List<DictionaryEntry>>.loading(),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('no definitions → empty variant', (tester) async {
      await pumpSheet(
        tester,
        entriesValue:
            const AsyncValue<List<DictionaryEntry>>.data(<DictionaryEntry>[]),
      );
      await tester.pumpAndSettle();

      expect(find.text('No definitions found'), findsOneWidget);
      expect(find.byIcon(Icons.search_off), findsOneWidget);
    });

    testWidgets('generic error → errorLoadingDefinitions + clean copy',
        (tester) async {
      await pumpSheet(
        tester,
        entriesValue: AsyncValue<List<DictionaryEntry>>.error(
          Exception('LEAKED-DICT-RAW'),
          StackTrace.current,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Error loading definitions'), findsOneWidget);
      expect(find.text('Please try again in a moment.'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.textContaining('LEAKED-DICT-RAW'), findsNothing);
    });

    testWidgets('offline error → cloud_off + offline copy', (tester) async {
      await pumpSheet(
        tester,
        entriesValue: AsyncValue<List<DictionaryEntry>>.error(
          const SocketException('failed host lookup'),
          StackTrace.current,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cannot reach the server'), findsOneWidget);
      expect(
        find.text('Check your connection and try again.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    });
  });
}
