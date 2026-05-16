# In-page search scroll regression + layout-switch test coverage

## Status

- **Part 1 — Fix:** ✅ Done (2026-05-15). See "Part 1 — implementation notes"
  below for what actually landed vs. what was planned.
- **Part 2 — Tighten test 3b:** ✅ Done (2026-05-16). All three edits landed
  as planned. See "Part 2 — implementation notes" below.
- **Part 3 — Layout-switch integration test:** ✅ Done (2026-05-16). New
  file `integration_test/layout_switch_test.dart` covers the
  `EntryKeyRegistry` / `findTopVisibleEntry` contract. See "Part 3 —
  implementation notes" below.

All three parts shipped.

## Bug report

When in-page search is active and the user taps the up/down arrows in the
search bar to navigate between matches, the highlighted match advances but
**the viewport does not scroll** to follow it. Reported as a regression.

## Root cause

Path taken on each up/down arrow tap:

1. `IconButton.onPressed` calls `InPageSearchNotifier.nextMatch()` /
   `previousMatch()` — both just bump `currentMatchIndex`
   (`lib/presentation/providers/in_page_search_provider.dart:130-152`).
2. `MultiPaneReaderWidget.build` has a `ref.listen<InPageSearchState>` on
   `activeInPageSearchStateProvider` that fires when `currentMatchIndex`
   changes and calls `_scrollToCurrentMatch`
   (`lib/presentation/widgets/reader/multi_pane_reader_widget.dart:432-438`).
3. `_scrollToCurrentMatch`
   (`lib/presentation/widgets/reader/multi_pane_reader_widget.dart:297-331`)
   does two things:
   - If the match is outside `[pageStart, pageEnd)`, it expands pagination
     via `updateActiveTabPaginationProvider`. This branch always "works" —
     pagination grows synchronously.
   - Schedules `WidgetsBinding.addPostFrameCallback`, reads
     `_currentMatchKey.currentContext`, and calls
     `Scrollable.ensureVisible(..., alignment: 0.3)`.

The actual scroll motion lives **only** in that second part — the post-frame
`Scrollable.ensureVisible` call.

The `_currentMatchKey` is attached to the `Padding` that wraps the current
match's entry in `ReaderEntryBuilder.buildEntries`
(`lib/presentation/widgets/reader/reader_entry_builder.dart:160-172`).
Commit `6d70ff6` ("fix(reader): sync scroll position by logical entry
across layout switches") wrapped that same `Padding` inside a
`KeyedSubtree(key: entryKeyRegistry.keyFor(...))`. The structure is now:

```
KeyedSubtree(GlobalKey A)        <- per-entry registry key
└── Padding(key = _currentMatchKey if current match else null)
    └── entry content
```

Each up/down tap requires Flutter to move `_currentMatchKey` from a
`Padding` inside one `KeyedSubtree` to a `Padding` inside a different
sibling `KeyedSubtree`. With nested GlobalKeys + a stateless wrapper, the
reparenting often leaves `_currentMatchKey.currentContext` either `null` on
the first post-frame tick, or pointing at a `RenderPadding` whose
viewport-relative geometry hasn't been recomputed yet. The
`if (keyContext != null) { ... }` guard then silently no-ops, and
`ensureVisible` doesn't get the chance to scroll. Result: highlighted match
changes, viewport stays put — exactly the reported bug.

The regression entered with `6d70ff6` (Mar 21, 2026). Before that commit,
`Padding(key: currentMatchKey)` was the entry-level widget with no
GlobalKey'd parent, and the GlobalKey re-attached cleanly each tap.

(Note: when the next match is on a page not yet in `[pageStart, pageEnd)`,
the pagination-expansion branch in step 3 still runs, which is why moving
to a far-away match sometimes appears to "work" — but that path is
incidental, not the scroll.)

## Why the existing integration test didn't catch it

`integration_test/in_page_search_test.dart`:

- **Test 1** (`'1. Tap search icon → … → navigate'`, lines 154-173) taps
  next/previous and only asserts `currentMatchIndex` advanced. No scroll
  check at all.
- **Test 3b** (`'3b. Navigating matches scrolls view and tracks current
  highlight'`, lines 277-351) is the one *supposed* to verify scrolling.
  Three problems:
  1. The forward-step loop (lines 302-307) and the back-step loop (lines
     317-321) only assert `currentMatchIndex`. No `controller.offset`
     comparison between consecutive taps — exactly the scenario the user
     is hitting.
  2. The only scroll-related assertion is at the wrap-around point (lines
     336-342):
     ```dart
     expect(
       offsetAtLast > offsetAtStart || pageEndAtLast > pageEndAtStart,
       isTrue, ...
     );
     ```
     This is an **OR**. Wrapping from match 0 to "last match" almost
     always lands on a page outside the currently loaded
     `[pageStart, pageEnd)`, which triggers the pagination-expansion
     branch in `_scrollToCurrentMatch`. That branch runs synchronously,
     before the post-frame `ensureVisible`. So
     `pageEndAtLast > pageEndAtStart` becomes true and satisfies the OR
     regardless of whether the actual `Scrollable.ensureVisible` scrolled
     anything.
  3. As a result, the test passes if the `ref.listen` callback fires at
     all and bumps pagination. The post-frame `ensureVisible` — which is
     the actual code that produces visible scroll motion in the normal
     arrow-tap case where pagination doesn't expand — is never validated.

So the gap is: **no test asserts `_scrollController.offset` actually moved
between two consecutive up/down taps on matches that live in
already-loaded pages.**

---

## Part 1 — The fix

**Fix idea**: drop `_currentMatchKey` entirely and reuse the per-entry
registry key (`_entryKeyRegistry.keyFor(page, entry)`) for scroll-to-match.
Registry keys are stable per `(page, entry)` and never move during
rebuilds — one GlobalKey per entry, no nesting.

### Files to change

1. `lib/presentation/widgets/reader/multi_pane_reader_widget.dart`
   - Delete `final GlobalKey _currentMatchKey = GlobalKey();` (line 57).
   - In `_scrollToCurrentMatch` (lines 297-331), replace
     `_currentMatchKey.currentContext` with
     `_entryKeyRegistry.keyFor(currentMatch.pageIndex, currentMatch.entryIndex).currentContext`.
   - **Optional but recommended**: wrap the post-frame `ensureVisible` in
     a bounded retry (≤10 frames) that calls `_loadMorePagesIfNeeded()`
     and re-checks `currentContext` — covers the "match on a page not yet
     lazy-built by ListView" edge case (same pattern as
     `_restoreScrollWithRetry`).
   - Drop the `currentMatchKey: _currentMatchKey,` line from each of the
     four pane constructors in `_buildContentLayout` (lines 686, 702, 716,
     730).

2. `lib/presentation/widgets/reader/reader_entry_builder.dart`
   - Remove the `GlobalKey? currentMatchKey` parameter from `buildEntries`
     (line 133).
   - Drop `key: isCurrentMatchEntry ? currentMatchKey : null` from the
     inner `Padding` (line 161). Keep `isCurrentMatchEntry` — it's still
     needed for `currentMatchIndexInEntry` (the active-match color).

3. `lib/presentation/widgets/reader/single_column_pane.dart`
   - Remove the `currentMatchKey` field/constructor param and the
     `currentMatchKey:` arg passed to `ReaderEntryBuilder.buildEntries`.

4. `lib/presentation/widgets/reader/dual_column_pane.dart`
   - Remove the `currentMatchKey` field/constructor param.
   - Delete the assert block at lines 232-237 and replace the
     `Padding(key: isThisSideCurrentMatch ? widget.currentMatchKey : null,
     …)` at line 281 with a plain `Padding(padding: …, child: side)`.
   - The KeyedSubtree(registry key) on the left side at line 290 is
     enough — `_PairHeightSync` keeps both sides on the same y, so the
     left registry key reveals either-side matches correctly.

5. `lib/presentation/widgets/reader/stacked_pane.dart`
   - Remove `currentMatchKey` field/constructor param.
   - Drop `key: isPaliCurrentMatch ? currentMatchKey : null` (line 156)
     and the Sinhala equivalent (line 178), plus the duplicate at line
     186 — replace with plain `Padding`. The pair-level
     KeyedSubtree(registry key) at line 194 is what scroll-to-match will
     use.

### Why this works

- The registry GlobalKey is stable per `(page, entry)`; it never moves
  between rebuilds. No reparenting timing fragility.
- One GlobalKey per entry instead of nested (registry + currentMatch). No
  nested-GlobalKey reparenting on every match navigation.
- For dual_column: the registry key is on the LEFT side only, but
  `_PairHeightSync` keeps both columns on the same y, so scrolling to the
  left key's position reveals either-side matches.
- For stacked: the registry key wraps the whole pair. Scrolling positions
  the Pali (top) at 30% from viewport top; if the match is on the Sinhala
  (bottom) it's slightly lower but still visible. Acceptable.

### Part 1 — implementation notes (what actually landed, 2026-05-15)

Done as planned, with one addition (bounded retry was opted in) and a few
small deviations worth flagging for the next agent.

**Files changed (Part 1 only — no tests touched per scope choice):**

1. `lib/presentation/widgets/reader/multi_pane_reader_widget.dart`
   - Deleted `final GlobalKey _currentMatchKey = GlobalKey();`.
   - `_scrollToCurrentMatch` now defers to `_ensureMatchVisibleWithRetry`
     inside the post-frame callback. That helper resolves the match entry
     via `_entryKeyRegistry.keyFor(match.pageIndex, match.entryIndex)`,
     calls `Scrollable.ensureVisible(..., alignment: 0.3, 300ms easeInOut)`
     when both `keyContext` and `renderObject.attached` are true, and
     otherwise calls `_loadMorePagesIfNeeded()` and reschedules itself for
     the next frame.
   - Retry bound: `_matchScrollMaxRetries = 10` (~165ms at 60fps). Mirrors
     the pattern of `_restoreScrollWithRetry`.
   - Dropped `currentMatchKey: _currentMatchKey,` from all four pane
     constructors in `_buildContentLayout`.
   - The `_entryKeyRegistry` field's doc comment updated to call out its
     dual purpose (layout-switch sync **and** scroll-to-match).

2. `lib/presentation/widgets/reader/reader_entry_builder.dart`
   - Removed the `GlobalKey? currentMatchKey` parameter from `buildEntries`.
   - Dropped `key: isCurrentMatchEntry ? currentMatchKey : null` from the
     inner `Padding`. `isCurrentMatchEntry` is still computed — still needed
     for `currentMatchIndexInEntry` (the active-match colour).
   - Docstring on `buildEntries` rewritten to describe the registry's role.

3. `lib/presentation/widgets/reader/single_column_pane.dart`
   - Removed `currentMatchKey` field + ctor param.
   - Dropped `currentMatchKey:` from the `ReaderEntryBuilder.buildEntries`
     call.

4. `lib/presentation/widgets/reader/dual_column_pane.dart`
   - Removed `currentMatchKey` field + ctor param.
   - Deleted the both-sides `assert` block (lines were 232-237 in the doc;
     it guarded against the shared GlobalKey being attached on both Pali
     and Sinhala sides — now moot).
   - The `Padding(key: isThisSideCurrentMatch ? widget.currentMatchKey :
     null, …)` became a plain `Padding(padding: …, child: side)`. The
     `isThisSideCurrentMatch` local was also removed (only used here).
   - `isPaliCurrentMatch` / `isSinhalaCurrentMatch` are still computed —
     `buildEntry` uses them for `currentMatchIndexInEntry`.
   - Left-only `KeyedSubtree(registry key)` is unchanged; `_PairHeightSync`
     keeps both sides on the same y, so the left key reveals either-side
     matches.

5. `lib/presentation/widgets/reader/stacked_pane.dart`
   - Removed `currentMatchKey` field + ctor param.
   - Dropped `key: ... ? currentMatchKey : null` from all three Padding
     sites (Pali path at line 156, Sinhala path at 178, no-Sinhala
     fallback at 186). All became plain `Padding`s.
   - The pair-level `KeyedSubtree(registry key)` at the bottom of
     `_buildStackedEntries` is the scroll target — unchanged.

**Deviations from the plan / things to be aware of:**

- The bounded retry was **opted in** (not skipped). It covers the
  far-match case where pagination just expanded but `ListView.builder`
  hasn't lazy-built the target item by the time the post-frame fires.
  Test 3b's wrap-around assertion (Part 2 Edit 3) should now exercise
  this path — the `pumpAndSettle(Duration(seconds: 1))` the doc suggests
  is more than enough headroom for 10 retry frames.
- The `_currentMatchKey` doc comment in `_scrollToCurrentMatch` was
  rewritten in general terms (per CLAUDE.md "don't reference the current
  task/fix"). If you grep for the old identifier in comments to find
  context, you won't see it — that's intentional.
- `flutter analyze` is clean across the whole project.
- No tests were modified or added (per CLAUDE.md "Don't create/update
  tests unless the user specifically asks"). User was notified.
- **Not manually verified in a running app yet** — the change is
  type-safe and analyzer-clean, but you should sanity-tap the up/down
  arrows in a sutta with several matches before declaring victory.

### What `6d70ff6` *should* have shipped as tests

The commit introduced `EntryKeyRegistry` + the per-entry `KeyedSubtree`
wrap — the exact mechanism that broke scroll-to-match. The shipping commit
should have included:

1. **Feature test** (what `6d70ff6` actually does): open a sutta, scroll
   to a known mid-document entry, switch layout (`paliOnly → sideBySide →
   stacked → paliOnly`), and after each switch assert the same logical
   entry sits at (or within a tolerance of) the viewport top — exercising
   `findTopVisibleEntry` and the pagination-reset path. Currently zero
   coverage. Added under **Part 3** below.
2. **Regression guard for sibling features**: assert
   `controller.offset` actually advances between consecutive in-page-search
   next-taps after the registry wrap was introduced. This is the missing
   assertion that allowed the current bug to ship. Added under **Part 2**
   below.

---

## Part 2 — Tighten existing integration test (no new tests in this file)

File: `integration_test/in_page_search_test.dart`. Modify **only test 3b**
(`'3b. Navigating matches scrolls view and tracks current highlight'`,
lines 277-351). Three edits, no new `testWidgets` blocks:

### Edit 1 — Forward-step loop (lines 302-307)

Currently only asserts `currentMatchIndex`. Capture `controller.offset`
before the loop and assert it strictly increased after the loop. Since
`'එවං'` matches in dn-1-1 span multiple entries down the page, three
`keyboard_arrow_down` taps should push the viewport past 0.

```dart
final offsetBeforeForward = controller.offset; // expect 0
for (var i = 1; i <= 3; i++) {
  await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
  await tester.pumpAndSettle();
  expect(readSearchState(container, 0).currentMatchIndex, i, ...);
}
expect(
  controller.offset, greaterThan(offsetBeforeForward),
  reason: 'Stepping forward through matches must move the viewport',
);
```

This is the assertion that directly catches the current regression.

### Edit 2 — Back-step loop (lines 317-320)

Capture offset before tapping up 3 times. After the loop, assert offset
decreased back toward 0. Catches the `previousMatch` path symmetrically.

```dart
final offsetAfterForward = controller.offset;
for (var i = 0; i < 3; i++) {
  await tester.tap(find.byIcon(Icons.keyboard_arrow_up));
  await tester.pumpAndSettle();
}
expect(
  controller.offset, lessThan(offsetAfterForward),
  reason: 'Stepping back must scroll up',
);
```

### Edit 3 — Wrap-around assertion (lines 336-342)

Replace the single OR'd `expect` with two stricter ones. The current OR
makes pagination expansion alone enough to pass, which is exactly the
loophole.

```dart
expect(
  pageEndAtLast, greaterThan(pageEndAtStart),
  reason: 'Wrap to last match must expand pagination to the match page',
);
// Give the retry / lazy-build a moment to complete.
await tester.pumpAndSettle(const Duration(seconds: 1));
expect(
  controller.offset, greaterThan(offsetAtStart),
  reason: 'After pagination expands, viewport must scroll to last match',
);
```

This forces the full chain (pagination expand → ListView builds new page
→ `ensureVisible` scrolls) to be exercised, not just step 1.

After Part 1 lands the test should pass; if any of the three assertions
above starts failing later, that's the same regression class returning.

### Part 2 — implementation notes (what actually landed, 2026-05-16)

Done as planned. File modified: `integration_test/in_page_search_test.dart`,
only the `'3b. Navigating matches scrolls view and tracks current
highlight'` test. No new `testWidgets` blocks; no other tests touched.

**Edits landed:**

1. **Forward-loop scroll assertion** — after the existing 3 down-arrow
   taps, captures `offsetAfterForward = controller.offset` and asserts
   `greaterThan(offsetAtStart)`. Reuses `offsetAtStart` already recorded
   earlier in the test (the doc-suggested `offsetBeforeForward` would have
   been a redundant capture). Comment in-test calls out the regression
   class.
2. **Back-loop scroll assertion** — after the 3 up-arrow taps, captures
   `offsetAfterBack` and asserts `lessThan(offsetAfterForward)`. Symmetric
   guard for the `previousMatch` path.
3. **Wrap-around assertion rewrite** — the loose
   `offsetAtLast > offsetAtStart || pageEndAtLast > pageEndAtStart` OR
   was replaced with two strict `expect`s: pagination must expand AND,
   after a `pumpAndSettle(const Duration(seconds: 1))` to let the bounded
   retry + lazy build complete, the offset must have grown. Both
   reasons quote the before→after values for easier failure triage.

**Deviations from the plan / things to be aware of:**

- **Confirmed 2026-05-16**: doc reviewed against the on-disk diff in
  `integration_test/in_page_search_test.dart`; all three edits landed and
  match the notes above. No production code changes for Part 2. Picking
  up Part 3 next.

- The doc's Edit 1 introduced a fresh `offsetBeforeForward` local. The
  test already had `offsetAtStart` captured immediately above the
  forward loop, so the new code reuses it. Behaviour is identical.
- The added 1-second `pumpAndSettle` before the wrap-around offset check
  comes after the existing 2-second settle at the wrap-around tap, so
  total headroom for the 10-frame retry is well over a second — plenty.
- `flutter analyze integration_test/in_page_search_test.dart` is clean.
- The tests have **not been run yet** — per CLAUDE.md, `flutter test`
  needs user confirmation before running. The edits are analyzer-clean
  and structurally consistent with the existing test, but a run is
  worth doing before declaring victory.
- No production code touched. No other test files touched.

---

## Part 3 — Add the missing layout-switch integration test

### Confirmed gap

`grep` across `integration_test/` and `test/` for `ReaderLayout`,
`EntryKeyRegistry`, `findTopVisibleEntry`, layout enum values, and the
layout-switch pill: **zero hits**. The feature shipped in `6d70ff6` (and
the later stacked layout in `12f4a1f`) has no test coverage at all.

### Placement

New file: `integration_test/layout_switch_test.dart`. Mirrors the pattern
of `in_page_search_test.dart` and `scroll_restoration_test.dart`. (One test
to start; can grow later.)

### Test design

The layout listener in `multi_pane_reader_widget.dart:403-429` runs
`findTopVisibleEntry` → `updateActiveTabPaginationProvider(pageStart,
entryStart)` → `jumpTo(0)`. The observable side effects on the tab state
are enough to verify it; no need to introspect the private registry. We
drive the layout switch through `updateActiveTabLayoutProvider`
(`lib/presentation/providers/tab_provider.dart:308-310`) — no widget-tap
needed.

Steps:

1. **Setup** — copy `pumpReaderApp` / `tabFromNode` / `openTab` helpers
   from `in_page_search_test.dart`. Open `dn-1-1` and pump until content
   is laid out.
2. **Pre-conditions** — read `tabs[0].pageStart`, `tabs[0].entryStart`.
   Both should be 0 (or the sutta's start). Capture as
   `pageStartBefore`, `entryStartBefore`. Default tab layout is
   `paliOnly`.
3. **Scroll to a known offset** — find the `ScrollController`,
   `controller.jumpTo(800)`. Pump frames so `_loadMorePagesIfNeeded`
   builds enough pages and the registry populates with mounted entries.
4. **Switch layout** —
   `container.read(updateActiveTabLayoutProvider)(ReaderLayout.sideBySide);`
   then `pumpAndSettle`.
5. **Assertions on the listener's contract**:
   - `controller.offset == 0` — listener calls `jumpTo(0)` after
     capturing the top entry.
   - `(tabs[0].pageStart, tabs[0].entryStart)` differs from
     `(pageStartBefore, entryStartBefore)` — proves `findTopVisibleEntry`
     returned a non-null entry and `updateActiveTabPaginationProvider`
     ran. Specifically `entryStart > 0` OR `pageStart > 0`.
   - `tabs[0].layout == ReaderLayout.sideBySide` — sanity check.
6. **Round-trip** — switch to `ReaderLayout.stacked`, `pumpAndSettle`.
   Repeat the same assertions (scroll back to 0, pagination updated,
   layout reflects the new selection). Won't exactly match the
   pre-switch state, that's fine — the property under test is "top
   entry is preserved across the switch", captured sufficiently by
   `(pageStart, entryStart) != (0, 0)` without overfitting to specific
   entry indices.

### Why this test catches the regression class

If someone later breaks `EntryKeyRegistry` (forgets to clear on tab
change, breaks the GlobalKey wrapping, removes `KeyedSubtree`, or breaks
`findTopVisibleEntry`'s math), `findTopVisibleEntry` returns `null` → the
pagination reset is skipped → `pageStart` / `entryStart` stay at `(0, 0)`
→ this test fails with a clear reason. It also exercises the actual
feature shipped by `6d70ff6`, which currently has none.

### Deliberate non-goals

- Doesn't assert "the exact same RenderObject is at the top before and
  after" — overfits to layout-specific entry heights.
- Doesn't tap the `ReaderLayoutPill` widget — drives layout via
  `updateActiveTabLayoutProvider` to keep the test independent of pill
  UI changes.

### Part 3 — implementation notes (what actually landed, 2026-05-16)

Done as planned. One new test file, one wiring change, no production
code touched.

**Files changed:**

1. `integration_test/layout_switch_test.dart` — **new file.** Single
   `testWidgets` block named `'switching layout preserves top-visible
   entry (paliOnly → sideBySide → stacked)'`. Uses inlined copies of the
   `pumpReaderApp` / `tabFromNode` / `openTab` helpers from
   `in_page_search_test.dart` (no shared helper module exists yet — same
   pattern `scroll_restoration_test.dart` follows).
2. `integration_test/all_tests.dart` — added `layout_switch_test.dart`
   to the imports and `main()` body in alphabetical position (between
   `in_page_search` and `previous_sutta`).

**Test flow (matches the plan):**

1. Open `dn-1-1`, capture `tabs[0].pageStart` / `entryStart` as the
   document-start baseline.
2. `controller.jumpTo(600)` to make the top-visible entry meaningfully
   different from the document start.
3. Drive layout via
   `container.read(updateActiveTabLayoutProvider)(ReaderLayout.sideBySide)`
   — same provider the `ReaderLayoutPill` ultimately calls, so the test
   stays independent of pill UI.
4. Assertions after the switch: `tab.layout == sideBySide`,
   `controller.offset == 0.0`, AND `(pageStart, entryStart)` moved away
   from the baseline. The third assertion is the load-bearing one — it
   proves both `findTopVisibleEntry` returned non-null AND
   `updateActiveTabPaginationProvider` ran.
5. Round-trip to `ReaderLayout.stacked` (re-scrolling first so the
   captured top entry is meaningfully non-zero), same three assertions.

**Deviations from the plan / things to be aware of:**

- The plan suggested `controller.jumpTo(800)`; landed on 600 / 400 to
  stay well within `dn-1-1`'s loaded page height under the default
  800×600 test viewport. Either works; 600/400 are conservative.
- The pre-switch baseline uses `tabs[0].pageStart` / `entryStart`
  rather than asserting they're literally `(0, 0)`. `ReaderTab.fromNode`
  pulls `entryPageIndex` / `entryIndexInPage` from the navigation tree,
  so the document start for `dn-1-1` might not be exactly `(0, 0)` — the
  test compares delta against whatever the baseline turns out to be.
- `_suppressLayoutListener` is only set during tab switches, not when
  the layout provider is driven directly — confirmed by reading the
  guard's only call sites in `multi_pane_reader_widget.dart`. Safe to
  drive the switch via the provider without a tab change.
- `flutter analyze integration_test/layout_switch_test.dart
  integration_test/all_tests.dart` is clean.
- **Tests have NOT been run yet** — per CLAUDE.md, `flutter test`
  needs user confirmation. The file is analyzer-clean and structurally
  mirrors the working scroll/search integration tests, but a run is
  worth doing before declaring victory.
- No production code touched.

---

## Order of work (suggested)

1. **Part 1** — implement the fix (remove `_currentMatchKey`, route
   scroll-to-match through `_entryKeyRegistry`). Optionally add the
   bounded retry for the lazy-build case. ✅ **Done 2026-05-15** — see
   "Part 1 — implementation notes" above. Bounded retry was included.
2. **Part 2** — tighten the three assertions in test 3b. With Part 1
   landed, all three should pass. ✅ **Done 2026-05-16** — see "Part 2
   — implementation notes" above.
3. **Part 3** — add `integration_test/layout_switch_test.dart`. With
   `EntryKeyRegistry` already in place, this should pass immediately and
   guard the feature going forward. ✅ **Done 2026-05-16** — see
   "Part 3 — implementation notes" above.

Each part is independently shippable.
