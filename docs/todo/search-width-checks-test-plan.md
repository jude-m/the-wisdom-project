# Search at every width — test plan

Started 2026-10-09. For the test agent. It turns the user's by-eye check of the search pane redesign (chunks D and D2, `search-pane-redesign-plan.md`) into tests, so a later change can't quietly break a width.

Since Task 12 (D2) only phones (below 768px) have the search icon and search mode. Tablets and desktop have the 360px box, with the results as a side panel.

## Widths

| Width | Why |
| --- | --- |
| 360 | Smallest phone. Where the app bar overflowed before Task 9. |
| 400 | Phone. `search_mode_test` already runs here. |
| 900 | Tablet. With the navigator open (350px) the panel drops to its 300px minimum, so the result tabs don't fit. |
| 1280 | Desktop. |
| 767 / 768 | Phone ↔ tablet: where the search icon becomes the box. |

## Rules

- Pump the real `ReaderScreen`, as `search_mode_test` does. The `pumpSearchApp` harness builds a bare `SearchBar(width: 400)`, so it never sees the app bar, search mode or the side panel.
- Pin the size: `tester.view.physicalSize` and `devicePixelRatio = 1`. Unpinned, the macOS test window lays out 502px wide.
- A layout overflow fails a Flutter test by itself, so pumping at a width already checks it for overflow.
- Each check once, at the width where it can break. All close paths go through `closeSearchProvider`, so each path is tested at one width, not at every width.
- Push a check down to a widget test when a single widget proves it (breadcrumb, tab bar, recent list). Keep integration tests for what needs the whole screen.
- The same files run on macOS (`flutter test <file> -d macos`) and in Chrome (`scripts/app/web/test_chrome.sh <file>`, which picks up every file in `all_tests.dart`).

## Checks

Status: **Covered**, **Partly** (what is missing is in the row), **Missing**. Covered rows need no new work; they are listed so nothing is tested twice.

| ID | Check | Width | Covered by | Status |
| --- | --- | --- | --- | --- |
| W1 | The icon opens search mode: field focused, back arrow, no menu button. | 400 | `search_mode_test` step 2 | Partly: also check the settings button is gone and the field spans the bar (8px gap each side). |
| W2 | Close paths: tap below the bar (empty query), back arrow (keeps the query), system back, Esc, picking a result (the breadcrumb names it). | 400 | `search_mode_test` steps 3, 6, 8, 9, 13 | Covered |
| W3 | Reopening shows the last query with its results, field focused. | 400 | `search_mode_test` step 7 | Partly: also check the whole query is selected. |
| W4 | Ctrl/Cmd+Shift+F with no field opens search mode; on another section it does nothing; back on another section leaves search open. | 400 | `search_mode_test` steps 10–12 | Partly: only Ctrl is pressed. Add Cmd (`meta`), the macOS binding. |
| W5 | Widening to the box ends search mode; narrowing again shows the breadcrumb. | 400 → 1200 → 400 | `search_mode_test` step 4 | Covered |
| W6 | Desktop box: back arrow only while the panel is open; it closes the panel and keeps the query and the Sutta filter; focusing again gives the same counts. | harness | `search_flow` A4 | Covered |
| W7 | The clear ✕ empties only the query; filters stay. | harness | `search_flow` A4 | Partly: also check the recent list comes back, in the box and in search mode. |
| W8 | Singlish preview in the box; a Singlish recent entry shows only the Sinhala. | harness | `search_flow` 10.1 | Covered |
| M1 | No overflow at 360, search closed and open. A long Singlish query in search mode keeps the typed text visible, and the preview is at most 45% of the field's real width. | 360 | — | Missing |
| M2 | Breadcrumb with a long trail (a deep sutta): one line, opens at its end so the sutta name is on screen, a touch drag and a mouse drag reach the first parent, at least 16px between the trail and the search icon. Opening another sutta opens at its end again. | 360 | — | Missing. A widget test is enough. |
| M3 | Search mode with an empty field: recent searches show as a card at the app bar's bottom edge, its left and right edges lined up with the field's (8px from the screen's sides); tapping a row searches it. | 400 | — | Missing. Seed one recent search. |
| M4 | The recent list leaves room for the keyboard: with a 300px bottom view inset, the list ends above it. | 400, 900 | — | Missing |
| M5 | Tablet: the 360px box and no search icon; the results panel is a side panel, not full screen (its left edge is past 0); the box's back arrow closes it, and so does system back (`tester.binding.handlePopRoute()`). | 900 | — | Missing |
| M6 | The switch: 767 shows the search icon, 768 the box. | 767, 768 | — | Missing |
| M7 | Desktop: the box is 360px wide, and its hint is only `searchHint` (no shortcut text). | 1280 | — | Missing. `search_mode_test` step 4 only checks a `SearchBar` exists. |
| M8 | Desktop: the panel has no close button of its own; the box's back arrow is the only `BackButton` on screen. | 1280 | — | Missing |
| M9 | Desktop: a click outside the recent list closes it and keeps the scope and match options. | 1280 | — | Missing |
| M10 | Desktop with the panel open, narrowed: at 900 the box keeps its back arrow and the side panel; at 400 the panel goes full screen under the full-width field, with a back arrow. One tap closes it. | 1280 → 900 → 400 | — | Missing |
| M11 | Result tabs in a 300px panel: a mouse drag and a touch drag scroll the row until the last tab is on screen, and the last tab then ends at least 24px (`RightEdgeFade.width`) from the panel's right edge. | 300px panel | — | Missing. A widget test in `search_results_panel_test` is enough. |
| M12 | The chip row and the reader's tab bar still scroll with a mouse drag (they share `MouseDragScroll` since Task 12; the breadcrumb is M2). | any | — | Missing. Widget tests are enough. |

## By eye only

No test can judge these. The user checks them after each layout change.

- At tablet width, the box and the side panel look right together (Task 12).
- The fade at the end of the result tabs looks right, and the line under the tabs runs to the panel's edge without fading (Task 12).
- Android system back, and everything on iOS: Android builds are broken on Flutter 3.44.1, and iOS was never built.

## Where the tests go

Suggested, not binding:

- `integration_test/search_mode_test.dart`: one `testWidgets` per width (phone, tablet, desktop) for W1, W3, W4, M1, M3–M10. Its header comment still says "Below 1024px"; since Task 12 it is 768px.
- A new `test/presentation/widgets/breadcrumb_widget_test.dart` for M2.
- `test/presentation/widgets/search_results_panel_test.dart` for M11; `tab_bar_widget_test.dart` and a chip-row widget test for M12.
