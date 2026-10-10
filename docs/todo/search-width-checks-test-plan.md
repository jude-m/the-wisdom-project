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
- A simulated key names its physical key (`sendKeyEvent(…, physicalKey: …)`). Without one, the key simulator looks it up by debug name, which a release web build drops, so the test fails in Chrome with a null error.

## Checks

All covered (2026-10-10). Each `search_mode_test` test is named here by its opening words: "phone width" (400px), "360px phone", "400px phone" (recent searches), "tablet" and "desktop". Their steps are numbered in the code.

| ID | Check | Width | Covered by |
| --- | --- | --- | --- |
| W1 | The icon opens search mode: field focused, back arrow, no menu or settings button, the field 8px from each side of the bar. | 400 | `search_mode_test` "phone width", step 2 |
| W2 | Close paths: tap below the bar (empty query), back arrow (keeps the query), system back, Esc, picking a result (the breadcrumb names it). | 400 | `search_mode_test` "phone width", steps 3, 6, 8, 9, 13 |
| W3 | Reopening shows the last query, all selected, with its results, field focused. | 400 | `search_mode_test` "phone width", step 7 |
| W4 | Ctrl+Shift+F and Cmd+Shift+F with no field open search mode; on another section the shortcut does nothing; back on another section leaves search open. | 400 | `search_mode_test` "phone width", steps 10–12 |
| W5 | Widening to the box ends search mode; narrowing again shows the breadcrumb. | 400 → 1200 → 400 | `search_mode_test` "phone width", step 4 |
| W6 | Desktop box: back arrow only while the panel is open; it closes the panel and keeps the query and the Sutta filter; focusing again gives the same counts. | harness | `search_flow` A4 |
| W7 | The clear ✕ empties only the query; filters stay; the recent list comes back. | harness, 400, 1280 | `search_flow` A4; `search_mode_test` "400px phone", and "desktop" step 3 |
| W8 | Singlish preview in the box; a Singlish recent entry shows only the Sinhala. | harness | `search_flow` 10.1 |
| M1 | No overflow at 360, search closed and open. A long Singlish query keeps the typed text visible, and the preview is at most 45% of the field's real width. | 360 | `search_mode_test` "360px phone" |
| M2 | Breadcrumb with a long trail: one line, opens at its end, a touch drag and a mouse drag reach the first parent; another sutta opens at its end again. At least 16px between the trail and the search icon. | 200px bar, 360 | `breadcrumb_widget_test`; the 16px in `search_mode_test` "360px phone" |
| M3 | Search mode with an empty field: recent searches are a card at the app bar's bottom edge, lined up with the field; tapping a row searches it. | 400 | `search_mode_test` "400px phone" |
| M4 | The recent list ends above a 300px keyboard. The test first checks that, in full, the list would reach the keyboard. | 400×560, 900×560 | `search_mode_test` "400px phone", and "tablet" step 3 |
| M5 | Tablet: the 360px box; the results panel is a side panel; the box's back arrow closes it, and so does system back (`handlePopRoute`). | 900 | `search_mode_test` "tablet", steps 2, 4–6 |
| M6 | The switch: 767 shows the search icon, 768 the box. | 767, 768 | `search_mode_test` "tablet", step 1 |
| M7 | Desktop: the box is 360px wide, and its hint is only `searchHint`. | 1280 | `search_mode_test` "desktop", step 1 |
| M8 | Desktop: the panel has no close button of its own; the box's back arrow is the only `BackButton` on screen. | 1280 | `search_mode_test` "desktop", step 2 |
| M9 | Desktop: a click outside the recent list closes it and keeps the scope and match options. | 1280 | `search_mode_test` "desktop", step 4 |
| M10 | Desktop with the panel open, narrowed: at 900 the box keeps its back arrow and the side panel; at 400 the panel fills the screen under the full-width field. One tap closes it. | 1280 → 900 → 400 | `search_mode_test` "desktop", steps 5–7 |
| M11 | Result tabs in a 300px panel: a mouse drag and a touch drag bring the last tab on screen, at least 24px (`RightEdgeFade.width`) from the panel's right edge. | 300px panel | `search_results_panel_test` |
| M12 | The chip row and the reader's tab bar scroll with a mouse drag. | any | `pill_chip_row_test`, `tab_bar_widget_test` |

Proved by breaking a scratch copy, each failing only the tests meant to catch it: no mouse in `MouseDragScroll`, the breadcrumb not reversed or not keyed by its path, no end padding on the result tabs, the recent list ignoring the keyboard, the preview capped by 360px instead of the field's width, the phone card not lined up with the field, and system back ignoring the tablet panel.

## By eye only

No test can judge these. The user checks them after each layout change.

- At tablet width, the box and the side panel look right together (Task 12).
- The fade at the end of the result tabs looks right, and the line under the tabs runs to the panel's edge without fading (Task 12).
- Android system back, and everything on iOS: Android builds are broken on Flutter 3.44.1, and iOS was never built.
