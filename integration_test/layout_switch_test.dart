import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_wisdom_project/core/localization/l10n/app_localizations.dart';
import 'package:the_wisdom_project/data/datasources/bjt_document_local_datasource.dart';
import 'package:the_wisdom_project/presentation/models/in_page_search_state.dart';
import 'package:the_wisdom_project/presentation/models/reader_layout.dart';
import 'package:the_wisdom_project/presentation/models/reader_tab.dart';
import 'package:the_wisdom_project/presentation/providers/document_provider.dart';
import 'package:the_wisdom_project/presentation/providers/in_page_search_provider.dart';
import 'package:the_wisdom_project/presentation/providers/last_reader_layout_provider.dart';
import 'package:the_wisdom_project/presentation/providers/navigation_tree_provider.dart';
import 'package:the_wisdom_project/presentation/providers/tab_provider.dart';
import 'package:the_wisdom_project/presentation/widgets/reader/multi_pane_reader_widget.dart';
import 'package:the_wisdom_project/presentation/widgets/navigation/tab_bar_widget.dart';

import 'test_overrides.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Layout Switch Integration Tests', () {
    // ---------------------------------------------------------------
    // Shared helpers (kept in-file to match the pattern of
    // in_page_search_test.dart and scroll_restoration_test.dart — no
    // shared helper module yet).
    // ---------------------------------------------------------------

    Future<ProviderContainer> pumpReaderApp(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bjtDocumentDataSourceProvider.overrideWithValue(
              BJTDocumentLocalDataSourceImpl(),
            ),
            keyValueStoreOverride(),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Column(
                children: [
                  TabBarWidget(),
                  Expanded(child: MultiPaneReaderWidget()),
                ],
              ),
            ),
          ),
        ),
      );

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );

      // Wait for the real navigation tree to load from assets.
      await container.read(navigationTreeProvider.future);
      await tester.pumpAndSettle();

      return container;
    }

    ReaderTab tabFromNode(ProviderContainer container, String nodeKey) {
      final node = container.read(nodeByKeyProvider(nodeKey));
      if (node == null) throw StateError('Node "$nodeKey" not found in tree');
      return ReaderTab.fromNode(
        nodeKey: node.nodeKey,
        paliName: node.paliName,
        sinhalaName: node.sinhalaName,
        contentFileId: node.isReadableContent ? node.contentFileId : null,
        pageIndex: node.isReadableContent ? node.entryPageIndex : 0,
        entryStart: node.isReadableContent ? node.entryIndexInPage : 0,
      );
    }

    Future<void> openTab(
      WidgetTester tester,
      ProviderContainer container,
      ReaderTab tab,
    ) async {
      container.read(tabsProvider.notifier).addTab(tab);
      container.read(activeTabIndexProvider.notifier).state =
          container.read(tabsProvider).length - 1;
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }

    // Reads the per-tab in-page search state from the provider.
    InPageSearchState readSearchState(
      ProviderContainer container,
      int tabIndex,
    ) {
      final states = container.read(inPageSearchStatesProvider);
      return states[tabIndex] ?? InPageSearchState();
    }

    // ---------------------------------------------------------------
    // Test: top-visible entry survives a full layout cycle AND updates
    // when the user re-scrolls mid-cycle.
    //
    // Covers the feature shipped in `6d70ff6` ("sync scroll position by
    // logical entry across layout switches") which had zero test coverage.
    // The listener under test lives in `multi_pane_reader_widget.dart` at
    // the `ref.listen<ReaderLayout>(activeReaderLayoutProvider, ...)`
    // block. It runs `findTopVisibleEntry` against `EntryKeyRegistry`,
    // calls `updateActiveTabPaginationProvider` so the new layout starts
    // from that entry, then resets the scroll to 0.
    //
    // Story this test tells:
    //   1. Scroll in sideBySide → capture position A.
    //   2. Cycle sideBySide → stacked → sinhalaOnly with NO further
    //      scrolling. Position A must survive each switch.
    //   3. Scroll again inside sinhalaOnly → capture a new position B.
    //   4. Cycle sinhalaOnly → paliOnly → sideBySide. Position B must
    //      survive these.
    //
    // The mid-cycle re-scroll + posB != posA assertion is the real
    // value-add: it catches a bug class where the captured entry gets
    // frozen on first capture and never updates on subsequent switches.
    //
    // Driving switches through `updateActiveTabLayoutProvider` keeps the
    // test independent of `ReaderLayoutPill` UI — the pill ultimately
    // calls the same provider.
    // ---------------------------------------------------------------
    testWidgets(
      'top-visible entry survives a full layout cycle and updates on re-scroll',
      (tester) async {
        final container = await pumpReaderApp(tester);

        final tab = tabFromNode(container, 'dn-1-1');
        await openTab(tester, container, tab);

        // The reader pane uses a single vertical ListView; the horizontal
        // ListView in TabBarWidget is excluded by `scrollDirection`.
        final scrollable = find.byWidgetPredicate(
          (w) => w is ListView && w.scrollDirection == Axis.vertical,
        );
        expect(scrollable, findsOneWidget,
            reason: 'Reader pane should expose a vertical ListView');
        final controller = tester.widget<ListView>(scrollable).controller!;

        // Pre-condition: a freshly opened tab defaults to paliOnly.
        expect(
          container.read(tabsProvider)[0].layout,
          ReaderLayout.paliOnly,
          reason: 'New tab should default to paliOnly',
        );

        // Document-start baseline. Compared against later to prove a
        // mid-document entry was actually captured (not just (0, 0) again).
        final tabsBefore = container.read(tabsProvider);
        final pageStartBefore = tabsBefore[0].pageStart;
        final entryStartBefore = tabsBefore[0].entryStart;

        // Helper — drive the layout provider, settle, then read back the
        // resulting state. Returns a record so each assertion can quote
        // the actual values in its `reason:` string for clean failures.
        Future<
                ({
                  int pageStart,
                  int entryStart,
                  double offset,
                  ReaderLayout layout,
                })>
            switchTo(ReaderLayout layout) async {
          container.read(updateActiveTabLayoutProvider)(layout);
          await tester.pumpAndSettle(const Duration(seconds: 1));
          final t = container.read(tabsProvider)[0];
          return (
            pageStart: t.pageStart,
            entryStart: t.entryStart,
            offset: controller.offset,
            layout: t.layout,
          );
        }

        // ---- PHASE 1: capture position A ----

        // paliOnly → sideBySide. No scroll yet, so this captures the
        // document-start entry. Mostly a warm-up switch — the meaningful
        // capture happens after the scroll below.
        final warmup = await switchTo(ReaderLayout.sideBySide);
        expect(warmup.layout, ReaderLayout.sideBySide);
        expect(warmup.offset, 0.0, reason: 'Layout switch must jumpTo(0)');

        // Scroll inside sideBySide so the top-visible entry is no longer
        // the sutta's first entry. Pixel target is intentionally generous
        // so we comfortably cross at least one entry boundary regardless
        // of layout-specific entry heights — Sinhala translation entries
        // can run ~1000px tall for long passages, so we use 1200 to keep
        // headroom even though sideBySide entries are usually shorter.
        controller.jumpTo(1200);
        await tester.pumpAndSettle(const Duration(seconds: 1));

        // sideBySide → stacked. Listener captures sideBySide's top entry
        // at offset=600 and writes it into pagination. That captured
        // entry is **position A** — we'll propagate it through the next
        // switch without scrolling again.
        final posA = await switchTo(ReaderLayout.stacked);
        expect(posA.layout, ReaderLayout.stacked);
        expect(posA.offset, 0.0, reason: 'Layout switch must jumpTo(0)');
        expect(
          posA.pageStart != pageStartBefore ||
              posA.entryStart != entryStartBefore,
          isTrue,
          reason: 'After scrolling and switching, pagination should have '
              'moved off the document start — baseline: '
              '($pageStartBefore, $entryStartBefore), '
              'posA: (${posA.pageStart}, ${posA.entryStart})',
        );

        // ---- PHASE 2: position A must survive a no-scroll switch ----

        // stacked → sinhalaOnly with NO re-scroll. The top entry of
        // stacked at offset=0 is the posA entry (placed there by the
        // previous switch), so the listener should capture posA again
        // and propagate it unchanged.
        final posASurvived = await switchTo(ReaderLayout.sinhalaOnly);
        expect(posASurvived.layout, ReaderLayout.sinhalaOnly);
        expect(posASurvived.offset, 0.0,
            reason: 'Layout switch must jumpTo(0)');
        expect(
          posASurvived.pageStart, posA.pageStart,
          reason: 'pageStart must survive stacked → sinhalaOnly with no '
              're-scroll — expected ${posA.pageStart}, got '
              '${posASurvived.pageStart}',
        );
        expect(
          posASurvived.entryStart, posA.entryStart,
          reason: 'entryStart must survive stacked → sinhalaOnly with no '
              're-scroll — expected ${posA.entryStart}, got '
              '${posASurvived.entryStart}',
        );

        // ---- PHASE 3: re-scroll mid-cycle, capture position B ----

        // Scroll again inside sinhalaOnly. Sinhala entries can be ~1000px
        // tall for long translated passages; using 1200 guarantees we
        // cross at least one entry boundary so posB ≠ posA holds even
        // when the current top entry is a long one.
        controller.jumpTo(1200);
        await tester.pumpAndSettle(const Duration(seconds: 1));

        // Precondition guard for Phase 3's load-bearing assertion below.
        // `ScrollController.jumpTo` silently clamps to `maxScrollExtent` —
        // if the loaded ListView is shorter than 1200px, the jump goes
        // nowhere, posB stays equal to posA, and `posB != posA` fails
        // with a message blaming the layout listener (which is innocent).
        // Phase 1's analogous jump doesn't need this guard because its
        // downstream assertion already names the scroll in its reason
        // string; Phase 3's downstream assertion blames the listener.
        expect(
          controller.offset, greaterThan(0),
          reason: 'jumpTo(1200) must produce a non-zero offset before '
              'Phase 3 can prove posB ≠ posA — if offset is 0, the '
              'loaded ListView is shorter than 1200px and the test '
              'setup, not the layout listener, is the real problem',
        );

        // sinhalaOnly → paliOnly. Listener captures sinhalaOnly's NEW top
        // entry → posB. This switch is the load-bearing one: posB must
        // differ from posA, proving the listener re-reads the viewport on
        // every switch instead of freezing on the first capture.
        final posB = await switchTo(ReaderLayout.paliOnly);
        expect(posB.layout, ReaderLayout.paliOnly);
        expect(posB.offset, 0.0, reason: 'Layout switch must jumpTo(0)');
        expect(
          posB.pageStart != posA.pageStart ||
              posB.entryStart != posA.entryStart,
          isTrue,
          reason: 'After re-scrolling mid-cycle, the captured entry must '
              'differ from posA — proves the listener re-reads viewport '
              'state on every switch instead of caching the first capture. '
              'posA: (${posA.pageStart}, ${posA.entryStart}), '
              'posB: (${posB.pageStart}, ${posB.entryStart})',
        );

        // ---- PHASE 4: position B must survive a no-scroll switch ----

        // paliOnly → sideBySide with NO re-scroll. Same property as
        // phase 2, but for posB — closes the full cycle through all
        // four layouts.
        final posBSurvived = await switchTo(ReaderLayout.sideBySide);
        expect(posBSurvived.layout, ReaderLayout.sideBySide);
        expect(posBSurvived.offset, 0.0,
            reason: 'Layout switch must jumpTo(0)');
        expect(
          posBSurvived.pageStart, posB.pageStart,
          reason: 'pageStart must survive paliOnly → sideBySide with no '
              're-scroll — expected ${posB.pageStart}, got '
              '${posBSurvived.pageStart}',
        );
        expect(
          posBSurvived.entryStart, posB.entryStart,
          reason: 'entryStart must survive paliOnly → sideBySide with no '
              're-scroll — expected ${posB.entryStart}, got '
              '${posBSurvived.entryStart}',
        );
      },
    );

    // ---------------------------------------------------------------
    // Test: layout switch recomputes in-page search matches.
    //
    // The recompute path: when `activeReaderLayoutProvider` changes,
    // `multi_pane_reader_widget.dart` calls
    // `InPageSearchNotifier.recomputeActiveTabMatches`, which re-runs
    // `_findAllMatches` against the NEW layout. Without this, the
    // match count goes stale after a layout switch — e.g. user has
    // 6 matches in sideBySide, switches to paliOnly, count still
    // says 6 but half of them sit in Sinhala entries the new layout
    // doesn't render. Arrow-nav then "jumps" to entries with no
    // visible highlight.
    //
    // Load-bearing assertion: sideBySide matchCount must equal
    // paliOnly + sinhalaOnly. This is a mathematical invariant
    // (sideBySide scans both sections; the single-section layouts
    // scan one each) that doesn't depend on whether 'එවං' happens
    // to appear in the Sinhala translation. It proves the layout
    // filter actually partitions matches per layout, not e.g.
    // returns a stale cached set or ignores layout entirely.
    // ---------------------------------------------------------------
    testWidgets(
      'layout switch recomputes in-page search matches against new layout',
      (tester) async {
        final container = await pumpReaderApp(tester);

        final tab = tabFromNode(container, 'dn-1-1');
        await openTab(tester, container, tab);

        // Pre-condition: a freshly opened tab defaults to paliOnly.
        expect(
          container.read(tabsProvider)[0].layout,
          ReaderLayout.paliOnly,
          reason: 'New tab should default to paliOnly',
        );

        // Drive the query straight through the notifier — this test
        // exercises the recompute pathway, not the InPageSearchBar UI.
        // 'එවං' is Pali "evaṃ" (= "thus") in Sinhala script; appears
        // throughout dn-1-1's Pali source.
        //
        // openSearch() before updateQuery: the layout-switch recompute
        // is gated on `isVisible == true` so that closing the bar +
        // changing layout doesn't leave stale matches misaligned with
        // pagination (see InPageSearchNotifier.recomputeActiveTabMatches).
        // Driving the notifier directly would skip the visibility flip
        // the real UI does — opening the bar restores parity.
        container.read(inPageSearchStatesProvider.notifier).openSearch();
        container
            .read(inPageSearchStatesProvider.notifier)
            .updateQuery('එවං');
        // 300 ms debounce + buffer, then settle for the match computation.
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();

        final paliOnlyState = readSearchState(container, 0);
        final paliCount = paliOnlyState.matchCount;
        expect(
          paliCount,
          greaterThan(0),
          reason: '"එවං" should match in dn-1-1 with the paliOnly layout',
        );
        expect(paliOnlyState.currentMatchIndex, 0);
        expect(paliOnlyState.effectiveQuery, isNotEmpty);

        // ACT 1 — switch to sinhalaOnly. Recompute must run against
        // ONLY the Sinhala entries, dropping all Pali matches from the set.
        container
            .read(updateActiveTabLayoutProvider)(ReaderLayout.sinhalaOnly);
        await tester.pumpAndSettle();

        final sinhalaState = readSearchState(container, 0);
        final sinhalaCount = sinhalaState.matchCount;
        // `_computeAndSetMatches` resets currentMatchIndex to 0 (or -1
        // when empty). This locks in current reset-to-0 semantics; when
        // the currentMatchIndex preservation follow-up lands, update
        // this assertion deliberately.
        expect(
          sinhalaState.currentMatchIndex,
          sinhalaCount > 0 ? 0 : -1,
          reason: 'Recompute should reset currentMatchIndex to 0 '
              '(or -1 if the new layout has no matches)',
        );

        // ACT 2 — switch to sideBySide. Both sections scanned, so
        // matchCount must equal paliCount + sinhalaCount. This is the
        // load-bearing assertion (see test header).
        container
            .read(updateActiveTabLayoutProvider)(ReaderLayout.sideBySide);
        await tester.pumpAndSettle();

        final sideBySideState = readSearchState(container, 0);
        expect(
          sideBySideState.matchCount,
          paliCount + sinhalaCount,
          reason: 'sideBySide count must equal paliOnly + sinhalaOnly: '
              '$paliCount + $sinhalaCount, got ${sideBySideState.matchCount}',
        );

        // ROUND-TRIP — back to paliOnly. The original match set must
        // return. Without the recompute being wired up, this would
        // still report sideBySide's count (or whatever was cached).
        container
            .read(updateActiveTabLayoutProvider)(ReaderLayout.paliOnly);
        await tester.pumpAndSettle();

        final restoredState = readSearchState(container, 0);
        expect(
          restoredState.matchCount,
          paliCount,
          reason: 'Returning to paliOnly must restore the original '
              'match count: expected $paliCount, got '
              '${restoredState.matchCount}',
        );
        expect(
          restoredState.currentMatchIndex,
          0,
          reason: 'Recompute resets index to 0 — update this when the '
              'currentMatchIndex preservation follow-up lands',
        );
        expect(
          restoredState.effectiveQuery,
          paliOnlyState.effectiveQuery,
          reason: 'Query should be unchanged across layout switches',
        );
      },
    );

    // ---------------------------------------------------------------
    // Test: in-page search match scroll past cacheExtent works after a
    // layout switch.
    //
    // Reproduces the bug fixed by `_stepViewportToward` in
    // `multi_pane_reader_widget.dart`. The repro path:
    //
    //   1. Search "සීල" in sideBySide → 10 matches across dn-1-1.
    //   2. Navigate to the 5th match (mid-sutta).
    //   3. Close search, switch to stacked. The layout listener resets
    //      pagination to a narrow range around the captured top entry
    //      and jumpTo(0). Recompute drops matches (search hidden).
    //   4. Reopen search. `openSearch` recomputes, currentMatchIndex
    //      = 0, the search-state listener auto-scrolls to match[0] —
    //      which expands pageStart *backward* to page 2, leaving a
    //      wide loaded range with scroll parked at the top.
    //   5. Step forward through matches. Matches several pages down
    //      sit in [pageStart, pageEnd) but *outside* ListView.builder's
    //      default ~250px cacheExtent → keys aren't mounted →
    //      ensureVisible silently fails after bounded retries → scroll
    //      stops at the cula-sila entry while currentMatchIndex keeps
    //      advancing. User reported: "scrolls down until චුල්ලසීල
    //      නිට්ඨිතං and doesnt scroll any further".
    //
    // Load-bearing assertion: the offset delta after 5 next-taps must
    // exceed one viewport height. Without the fix, ensureVisible never
    // builds the target page → delta ≈ one entry-height (~200–400px),
    // well below viewport. With the fix, `_stepViewportToward` pushes
    // the controller forward in viewport-sized steps until ListView
    // builds the target slab, then ensureVisible animates the rest.
    //
    // Tying the threshold to `viewportDimension` keeps the assertion
    // robust to entry-height variations across builds — the bug is
    // about not scrolling FAR ENOUGH, not about not scrolling at all.
    // ---------------------------------------------------------------
    testWidgets(
      'in-page search scrolls past cacheExtent after a layout switch',
      (tester) async {
        // Constrain the test view to a mobile-portrait size. On macOS the
        // default integration-test viewport is large enough that the entire
        // dn-1-1 "සීල" match range fits in ListView.builder's cacheExtent,
        // which masks case (b) entirely (every key stays mounted, the bug
        // can't manifest). A mobile viewport puts page 6 well outside the
        // ~250 px cacheExtent from match[0]'s rendered position — the
        // dimensions case (b) is born for.
        tester.view.physicalSize = const Size(414, 896);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final container = await pumpReaderApp(tester);

        final tab = tabFromNode(container, 'dn-1-1');
        await openTab(tester, container, tab);

        // Start in sideBySide so "සීල" matches both Pali and Sinhala
        // entries (10 total in dn-1-1).
        container
            .read(updateActiveTabLayoutProvider)(ReaderLayout.sideBySide);
        await tester.pumpAndSettle();

        // Drive search via the notifier (same pattern as the recompute
        // test above). openSearch first so the visibility flag flips
        // before updateQuery — matches the real UI path.
        container.read(inPageSearchStatesProvider.notifier).openSearch();
        container
            .read(inPageSearchStatesProvider.notifier)
            .updateQuery('සීල');
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();

        final matchCount = readSearchState(container, 0).matchCount;
        expect(
          matchCount, 10,
          reason: '"සීල" in dn-1-1 sideBySide should yield 10 matches '
              '(see _findAllMatches: Pali + Sinhala sections scanned). '
              'Got $matchCount — repro depends on this exact count.',
        );

        // Advance to the 5th match (index 4) — mirrors the user's repro
        // ("stop at the 5th match and change the layout").
        for (var i = 0; i < 4; i++) {
          container.read(inPageSearchStatesProvider.notifier).nextMatch();
        }
        await tester.pumpAndSettle(const Duration(seconds: 1));
        expect(readSearchState(container, 0).currentMatchIndex, 4);

        // Close search BEFORE switching layout. The layout pill in the
        // UI is gated on !searchState.isVisible, so the real-world path
        // always closes first. This also triggers the
        // recomputeActiveTabMatches drop-matches branch when the layout
        // listener fires next.
        container.read(inPageSearchStatesProvider.notifier).closeSearch();
        await tester.pumpAndSettle();

        // Switch to stacked. Listener captures top entry → narrow
        // pagination reset → jumpTo(0) → load forward to fill viewport.
        // Matches dropped (search hidden).
        container
            .read(updateActiveTabLayoutProvider)(ReaderLayout.stacked);
        await tester.pumpAndSettle(const Duration(seconds: 1));

        expect(
          readSearchState(container, 0).matches, isEmpty,
          reason: 'Layout switch with search hidden must drop stale '
              'matches — openSearch will recompute on reopen',
        );

        // Reopen search. openSearch sees retained query + empty matches
        // → recomputes against stacked → currentMatchIndex = 0 → search
        // state listener fires _scrollToCurrentMatch on match[0], which
        // expands pageStart backward to page 2 and rebuilds.
        container.read(inPageSearchStatesProvider.notifier).openSearch();
        await tester.pumpAndSettle(const Duration(seconds: 2));

        expect(
          readSearchState(container, 0).matchCount, 10,
          reason: 'Reopen must recompute against stacked (still both '
              'langs scanned) — count unchanged',
        );
        expect(
          readSearchState(container, 0).currentMatchIndex, 0,
          reason: 'Reopen recompute resets currentMatchIndex to 0',
        );

        // Capture viewport + offset right after the auto-scroll to
        // match[0]. This is our baseline — match[0] sits ~30% from top.
        final scrollable = find.byWidgetPredicate(
          (w) => w is ListView && w.scrollDirection == Axis.vertical,
        );
        final controller = tester.widget<ListView>(scrollable).controller!;
        final offsetAtFirstMatch = controller.offset;
        final viewport = controller.position.viewportDimension;
        final pageEndAfterFirst = container.read(activePageEndProvider);

        // Precondition guard for the load-bearing assertion below.
        // Case (b) ONLY exercises if match[5]'s page sits inside
        // [pageStart, pageEnd). match[5] is on page 6 (see
        // _findAllMatches output for "සීල" in dn-1-1). If pageEnd <= 6,
        // stepping triggers case (a) — pagination expansion — instead,
        // and the test would pass without proving the case (b) fix.
        expect(
          pageEndAfterFirst, greaterThan(6),
          reason: 'Test invariant: pageEnd ($pageEndAfterFirst) must '
              'cover match[5]\'s page (6) so the next-taps below '
              'exercise case (b) [in-range but unbuilt] rather than '
              'case (a) [past pageEnd]. If this fails, the viewport '
              'in the test is too small — adjust setup, not assertion.',
        );

        // Step forward 5 times — reaches match[5] (page 6 entry 4 si,
        // "මජ්ඣිමසීලය"). This is several pages below match[0]'s position
        // (page 2 entry 1) — well beyond default cacheExtent (~250px).
        for (var i = 0; i < 5; i++) {
          container.read(inPageSearchStatesProvider.notifier).nextMatch();
          await tester.pumpAndSettle(const Duration(milliseconds: 500));
        }
        expect(
          readSearchState(container, 0).currentMatchIndex, 5,
          reason: '5 next-taps should advance currentMatchIndex from 0 to 5',
        );

        // Load-bearing assertion (see test header). Without
        // _stepViewportToward, scroll stops at the cula-sila entry
        // (~one entry-height past match[0], well under viewport).
        final offsetAfterAdvance = controller.offset;
        final delta = offsetAfterAdvance - offsetAtFirstMatch;
        expect(
          delta, greaterThan(viewport),
          reason: 'After 5 next-taps past cacheExtent, scroll offset '
              'must advance by more than one viewport height '
              '($viewport px). Got delta $delta '
              '($offsetAtFirstMatch → $offsetAfterAdvance). '
              'A small delta means _ensureMatchVisibleWithRetry gave up '
              'before pushing ListView to build the match\'s page — '
              'the case (b) bug.',
        );
      },
    );

    // ---------------------------------------------------------------
    // Test: the last-used layout is persisted and seeds newly created
    // tabs, while existing tabs keep their own per-tab layout.
    //
    // Covers the feature in `last_reader_layout_provider.dart`: changing
    // a tab's layout records it as the global "last used" value, and the
    // tab-creation providers seed new tabs from it (falling back to the
    // orientation default only when nothing is saved).
    //
    // We drive a single creation path — `openTabFromNodeKeyProvider` —
    // since the tree, breadcrumb, search, and commentary/root-text paths
    // all read the same `lastReaderLayoutProvider` seed. The chosen
    // layout (sinhalaOnly) is deliberately NOT the default for either
    // orientation (portrait → stacked, landscape → sideBySide), so a new
    // tab landing on it proves the saved value drove the choice rather
    // than the orientation heuristic.
    // ---------------------------------------------------------------
    testWidgets(
      'last-used layout seeds new tabs; existing tabs keep their own',
      (tester) async {
        final container = await pumpReaderApp(tester);

        // Nothing chosen yet → nothing persisted.
        expect(
          container.read(lastReaderLayoutProvider),
          isNull,
          reason: 'No layout has been selected yet',
        );

        // 1. First tab via the real creator with nothing saved → falls
        //    back to the landscape orientation default (sideBySide).
        final idxA =
            container.read(openTabFromNodeKeyProvider)('dn-1-1');
        await tester.pumpAndSettle(const Duration(seconds: 2));
        expect(idxA, isNonNegative, reason: 'dn-1-1 should open');
        expect(
          container.read(tabsProvider)[idxA].layout,
          ReaderLayout.sideBySide,
          reason: 'With nothing saved, a landscape tab seeds to sideBySide',
        );

        // 2. User changes the layout → must update BOTH the active tab and
        //    the global last-used value.
        container.read(updateActiveTabLayoutProvider)(ReaderLayout.sinhalaOnly);
        await tester.pumpAndSettle(const Duration(seconds: 1));
        expect(
          container.read(tabsProvider)[idxA].layout,
          ReaderLayout.sinhalaOnly,
          reason: 'Changing layout updates the active tab',
        );
        expect(
          container.read(lastReaderLayoutProvider),
          ReaderLayout.sinhalaOnly,
          reason: 'Changing layout also records the last-used layout',
        );

        // 3. New tabs now seed from the saved layout, and the saved value
        //    wins over the orientation default in BOTH orientations
        //    (sinhalaOnly is neither orientation's default).
        final idxLandscape =
            container.read(openTabFromNodeKeyProvider)('dn-1-1');
        await tester.pumpAndSettle(const Duration(seconds: 2));
        expect(
          container.read(tabsProvider)[idxLandscape].layout,
          ReaderLayout.sinhalaOnly,
          reason: 'New landscape tab seeds from saved layout, not sideBySide',
        );

        final idxPortrait = container
            .read(openTabFromNodeKeyProvider)('dn-1-1', isPortraitMode: true);
        await tester.pumpAndSettle(const Duration(seconds: 2));
        expect(
          container.read(tabsProvider)[idxPortrait].layout,
          ReaderLayout.sinhalaOnly,
          reason: 'New portrait tab seeds from saved layout, not stacked',
        );

        // 4. Existing tab keeps its own layout — switching never re-seeds.
        //    Simulate a tab saved earlier in a different layout (sideBySide).
        final yesterdayTab = tabFromNode(container, 'dn-1-1')
            .copyWith(layout: ReaderLayout.sideBySide);
        container.read(tabsProvider.notifier).addTab(yesterdayTab);
        final idxYesterday = container.read(tabsProvider).length - 1;

        container.read(switchTabProvider)(idxYesterday);
        await tester.pumpAndSettle(const Duration(seconds: 1));

        expect(
          container.read(tabsProvider)[idxYesterday].layout,
          ReaderLayout.sideBySide,
          reason: 'Switching to an existing tab must not change its layout',
        );
        expect(
          container.read(activeReaderLayoutProvider),
          ReaderLayout.sideBySide,
          reason: 'Reader shows the active tab\'s own layout, not the global '
              'last-used value',
        );
        expect(
          container.read(lastReaderLayoutProvider),
          ReaderLayout.sinhalaOnly,
          reason: 'Merely switching tabs must not overwrite the last-used '
              'layout',
        );
      },
    );
  });
}
