# Search pane redesign — task plan

Started 2026-10-05.

## How to use this plan

Ten tasks in four chunks of related work. Build a chunk, review it, commit it; the next agent then picks up the next chunk. All work is on branch `feat/search-pane-redesign`.

Examples show this converter's real output: t → ට, th → ත, d → ඩ. So "satipatthana" becomes සටිපට්තන, not සතිපට්ඨාන.

The design is on the [Search pane review canvas](https://claude.ai/code/artifact/1b1d95dc-754a-46b3-bf95-d7f006a49e60). Follow the "Proposed" artboards. Blue numbers there match the "Canvas" column.

Chunks, in order:

| Chunk | Tasks | Theme | Status |
| --- | --- | --- | --- |
| A | 1, 2, 3 + Task 10: clear ✕ tooltip | Singlish preview everywhere | Done |
| B | 5, 6, 7 + Task 10: footer text, "View N more" button | Results list | Done |
| C | 4, 8 + Task 10: Treatises naming | Filter row and match menu | Done |
| D | 9 | Phone search | Not started |
| E | 11 | Sutta abbreviations | Not started |

B and C both edit `search_results_panel.dart`, so never run them side by side. D needs A and C. E can run any time after A. When a chunk is done, set its status and add a handover note at the end of this doc.

Tasks:

| Task | What | Canvas | Size | Needs |
| --- | --- | --- | --- | --- |
| 1 | Shared Singlish preview; fix "converted" check; use in find bar | 9 | S | — |
| 2 | Singlish preview inside the main search box | 1 | S | 1 |
| 3 | Recent searches show Sinhala | 8 | S | 1 |
| 4 | Filter row: close-panel icon, one shared chip | 10, 4 | M | — |
| 5 | Tabs: sized to text | 3 | S | — |
| 6 | "See all" in Top results section headers | 5 | S | 5 |
| 7 | Edition badge only when it helps | 6 | S | — |
| 8 | "Starts with ▾" match menu | 2 | L | 4 |
| 9 | Phone: search icon that expands | 7 | L | 2, 8 |
| 10 | Small fixes | — | S | — |
| 11 | No Singlish preview while typing a sutta reference | — | S | 1 |

Rules for every task:

- One chunk per commit. Run the app after each chunk. Check a desktop width and a phone width.
- New text goes in both `app_en.arb` and `app_si.arb`.
- No new tests (per CLAUDE.md). A separate agent writes them. Say so in the PR.
- Reuse what exists: `computeEffectiveQuery`, `SinglishTransliterator.isSinglishQuery`, `referenceSearchResultProvider`.
- **Performance: be extra careful in every task.** Search reacts to every keystroke, and lists can be long. Watch state with `select`, so widgets do not rebuild on every keystroke. Do no costly work in `build` or once per row (Singlish conversion, regexes, parsing, sorting): compute it once per change, in a provider or the notifier. The Singlish converter takes about 0.06–0.3 ms per call (measured 2026-10-06), so read its output through `singlishPreviewProvider`, never by calling it in `build`. Check a phone and the web too, not only the desktop.

What does NOT change:

- Panel order stays as today: filter row, then tabs, then results.
- The clear ✕ stays inside the search box.
- Refine stays at the end of the chips and scrolls with them. It is not pinned.

## Task 1 — Shared Singlish preview (canvas 9)

**Goal:** one widget shows the Sinhala for typed Singlish. Fix the check that decides when to show it. Use it in the find bar first.

**Files:** new `lib/presentation/widgets/search/singlish_preview.dart`, `lib/core/utils/search_query_utils.dart`, `lib/presentation/widgets/reader/in_page_search_bar.dart`.

**Steps:**

1. Create `SinglishPreview(text, fieldWidth:)`: the Sinhala in a light rounded tag. No arrow; the tag is enough. Upright text, no italic.
2. It must shrink: at most 45% of `fieldWidth`, `maxLines: 1`, ellipsis at the end.
3. Fix the "converted" check. It was true when raw and effective text differed, but trimming spaces or removing ZWJ also makes them differ, so Sinhala input like "සති " showed a preview of itself. New rule, all in `singlishPreviewText`: a preview only when the raw text has Latin letters (`isSinglishQuery`), is not a sutta reference (`SuttaCentralRefResolver.parseRef`), and converts to something non-empty.
4. In `InPageSearchBar`, replace the italic `Text` with `SinglishPreview`. It sits after the clear ✕, on purpose.
5. The preview keeps the joiners (ZWJ), so ්‍ර and ‍ය show joined, with no visible hal. Search keeps using the text without them.

**Done when:**

- [ ] "dukkha" in the find bar shows ඩුක්ඛ in a tag, upright.
- [ ] "tatra" shows ටට්‍ර, joined, with no visible hal.
- [ ] "සති " (with a trailing space) shows no preview.
- [ ] A long query does not overflow the bar at 320px width.

## Task 2 — Preview inside the main search box (canvas 1)

**Goal:** the main search box shows `satipatthana [සටිපට්තන] ✕`, like the find bar. No extra row in the panel.

**Files:** `lib/presentation/widgets/search/search_bar.dart`.

**Steps:**

1. Inside the box, place `SinglishPreview` after the typed text and before the clear ✕.
2. Cap the preview at about 45% of the box width. The typed text always stays visible.
3. Show it only when `singlishPreviewProvider` returns text (Task 1 rule, which also hides it for "SN 15.3").
4. The clear ✕ stays where it is.

**Done when:**

- [ ] "satipatthana" shows සටිපට්තන inside the box.
- [ ] Sinhala input and "SN 15.3" show no preview.
- [ ] A long Singlish query keeps the caret and typed text visible; the preview ends in "…".

## Task 3 — Recent searches show Sinhala (canvas 8)

**Goal:** the recent list shows සටිපට්තන, not "satipatthana".

**Files:** `lib/presentation/providers/search_state.dart`, `lib/presentation/widgets/search/recent_search_overlay.dart`.

**Steps:**

1. Save what the search used: `saveRecentSearchAndDismiss` stores `singlishPreviewText(raw) ?? raw`. Singlish becomes its Sinhala; Sinhala and references like "SN 15.3" stay as typed. Singlish is only a way to type, so "vedana" and "wedana" (both වෙදන) are one entry, not two rows that look the same. Decided 2026-10-08; a small subtitle with the typed text was tried first and dropped: it looked odd.
2. Each row shows the saved text, one line. Tapping it puts that text in the search box.
3. Make the ✕ a real `IconButton` with a tooltip and a 40px+ tap area.
4. Entries saved before 2026-10-08 stay as typed: clear the list by hand.

**Done when:**

- [ ] Existing saved searches still load.
- [ ] A Singlish search shows in the list as Sinhala. Sinhala and reference entries show as typed.
- [ ] Two Singlish spellings of one word ("vedana", "wedana") give one entry.
- [ ] The ✕ has a tooltip and is reachable by keyboard.

## Task 4 — Filter row: close-panel icon and one shared chip (canvas 10, 4)

**Goal:** the panel's top row keeps today's place and order. The ✕ becomes a "slide away to the right" icon. Chips become bigger, real buttons.

**Files:** `lib/presentation/widgets/search/search_results_panel.dart` (`_PanelHeader`), new `lib/presentation/widgets/common/pill_chip.dart`, `search/scope_filter_chips.dart`, `dictionary/dictionary_filter_chips.dart`.

**Steps:**

1. Replace the close ✕ with `Icons.arrow_forward`, same position (left end of the row). Tooltip: "Close panel" (new l10n key). Same action as today.
2. Phones: no close icon in the panel. The app bar back arrow closes search (Task 9). Until Task 9 lands, keep today's ✕ on phones.
3. Create `PillChip(label, selected, onPressed)` (and `PillChip.refine`) as a real button, so it has hover, focus, ripple and semantics. 32px tall, 13px text, tap area 40px or more.
4. Replace `_ScopeChip` and `_FilterChip` with it. Delete both.
5. Refine stays the last chip and scrolls with the others, as today.
6. Add a soft fade on the right edge of the scrolling chips.
7. Keep today's colours: the row on `surfaceContainerHighest`, chips and Refine as they were (decided after review, 2026-10-07). The row is 56px tall.

**Done when:**

- [ ] The → arrow closes the panel; Esc, tap outside and phone back still work.
- [ ] Tab reaches every chip; Enter or Space toggles it.
- [ ] Scope and dictionary rows use the same chip.

## Task 5 — Tabs: sized to text (canvas 3)

**Goal:** no cut-off labels. Counts stay on the tabs (`_CountBadge`); the canvas moves them to the headers, but the user chose tabs on 2026-10-07 after trying both. An empty tab is not dimmed: its "0" badge already says it is empty (decided 2026-10-07).

**Files:** `search_results_panel.dart` (`_SearchResultsTabBar`).

**Steps:**

1. Replace the four equal `Expanded` tabs with left-aligned tabs sized to their label. Scroll sideways if needed (`TabBar(isScrollable: true, tabAlignment: TabAlignment.start)` fits). Every count badge is as wide as "100+", so a tab keeps its width while its count changes.
2. Empty tabs stay tappable. Do not disable them. Tapping shows the existing "no results" message.
3. If the selected tab becomes empty, it stays selected. Do not jump to another tab.

**Done when:**

- [ ] No label is cut at 300px, in English and Sinhala.
- [ ] Tabs do not flicker or shift while typing.

## Task 6 — "See all" in Top results headers (canvas 5)

**Goal:** a quick way from a Top results section to its own tab. The header shows the label only; the count is on the tab (see Task 5).

**Files:** `search_results_panel.dart` (`_buildTopResultsTabContent`, `_sectionHeader`).

**Steps:**

1. Add a "See all →" text button on the right. It calls `selectResultType(type)`. New l10n key `seeAll`.
2. Hide "See all" when the section already shows every result.
3. Sections with no results stay hidden, as today.

**Done when:**

- [ ] Each visible section header that shows only part of its results has a working "See all".

## Task 7 — Edition badge only when it helps (canvas 6)

**Goal:** no "BJT" box on every row. More room for the text.

**Files:** `search/grouped_fts_tile.dart`, `search_results_panel.dart` (`_SearchResultTile`).

**Steps:**

1. Decide once per list: show badges only when results come from two or more editions.
2. Pass that flag to the tiles. When off: no leading badge, text starts at 16px.
3. Change the divider indent from 72 to 16 to match.
4. Dictionary tiles keep their badges (BUS, MS, DPD).

**Done when:**

- [ ] BJT-only results show no badge; mixed editions still do.

## Task 8 — "Starts with ▾" match menu (canvas 2, detail artboard)

**Goal:** one labelled menu replaces the "abc" toggle and the proximity dialog. The search box keeps only the search icon, text, preview and clear ✕.

**Files:** new `lib/presentation/widgets/search/match_options_menu.dart`, `search/search_bar.dart`, `search_results_panel.dart` (`_PanelHeader`), `search/proximity_dialog.dart`, `providers/search_state.dart`, both ARB files.

**Steps:**

1. Put the button in the filter row: after the → close arrow, before the chips, then a thin divider, then the chips. It scrolls with the chips.
2. Show it on every tab, Definitions too. Dictionary search also uses `isExactMatch`.
3. Label shows the current choice: "Starts with" or "Whole word". With two or more words, add " · Phrase", " · Anywhere" or " · Near 10".
4. Tap opens a menu anchored under the button (`MenuAnchor`). Changes apply at once. No Apply button.
5. Section "Match each word": Starts with / Whole word. Sets `isExactMatch`.
6. Section "How words sit together", only for two or more words, in this order: As a phrase / Anywhere in the same text / Near each other. Near each other has a − N + stepper (1–100, default 10). Every change goes through `setMatchOptions`, one search per change.
7. Under each option: one grey line, then one plain-text example built from the user's own words. No highlight. See the table below.
8. Add "Reset to default" at the bottom.
9. Remove both toggle buttons from the search box. Delete `ProximityDialog` if nothing else uses it.

| Option | Line | Example (query "කායෙ කායානුපස්සී") |
| --- | --- | --- |
| Starts with | Finds the word and its longer forms | කායෙ… · කායානුපස්සී… |
| Whole word | Finds only the exact word | Only කායෙ · කායානුපස්සී |
| As a phrase | Finds the words together, as typed | "කායෙ කායානුපස්සී" (the only example with quotes) |
| Anywhere in the same text | Finds the words in any order | කායානුපස්සී · · · · · · කායෙ |
| Near each other | Finds the words close together | කායෙ · · කායානුපස්සී |

**Done when:**

- [ ] The menu works with mouse, touch and keyboard.
- [ ] Results refresh after each change.
- [ ] Defaults unchanged: starts with, phrase, distance 10.

## Task 9 — Phone: search icon that expands (canvas 7)

**Goal:** on phones, search is an icon. Tap it, and search fills the whole app bar.

**First, confirm the problem.** Run on a phone about 390px wide, panel closed. The 360px box plus menu and settings buttons (about 464px) should overflow. If it does not, skip this task.

**Files:** `lib/presentation/screens/reader_screen.dart` (AppBar), `search/search_bar.dart`, `search_results_panel.dart`.

**Steps:**

1. On `isMobile`, show a search `IconButton` in the app bar instead of the 360px box.
2. Tap switches the app bar to search mode: back arrow, full-width field (with the Task 2 preview), clear ✕. Pass the field's real width as `fieldWidth` (from a `LayoutBuilder`), not `widget.width`: the 45% preview cap is a share of it, and an unbounded width removes the cap.
3. The back arrow and system back leave search mode and close the panel.
4. Remove the panel's close icon on phones (Task 4, step 2).
5. Keep the same focus node, so Ctrl/Cmd+Shift+F still works (`mainSearchFocusNodeProvider`).
6. Recent searches go full width under the bar on phones.
7. Tablet and desktop do not change.
8. If `SearchBar` can now be removed while the app runs, its `dispose` changes two providers (`_searchFocusController.state = null` and `_overlayStack.remove('recent-searches')`) and throws in debug. Move both into a post-frame callback, as `MatchOptionsButton.dispose` does.

**Done when:**

- [ ] No overflow at 360px width; breadcrumb shows when search is closed.
- [ ] Open, type, pick a result, go back: all work on Android and iOS.

## Task 10 — Small fixes

Quick, independent items. Each one ships with the chunk that edits the same file (see the chunk table).

- [x] Translate the footer "Viewing X out of Y results". It is hard-coded English (`search_results_panel.dart`, `_footer`).
- [x] Add a tooltip to the clear ✕ in the search box. The find bar's clear button has one.
- [x] Make "View N more" a real button with a 40px+ tap area (`grouped_fts_tile.dart`).
- [x] "Treatises" vs "වෙනත්": both now mean "Other": English "Other", Sinhala අන්‍ය, the name tree.json gives the `anya` section (decided 2026-10-07). Key `scopeOther`, chip id `other`.

## Task 11 — No Singlish preview while typing a sutta reference

**Goal:** typing "SN", "Dhp" or "SN 1" shows no Singlish preview. Today `singlishPreviewText` hides it only for what `parseRef` reads as a reference: a listed book plus a number, any case. So "SN" and "Dhp" alone still show a preview, and "an 3" is hidden although it should show.

**The rule:** hide the preview only when the typed text can never be the start of a real search: no word in the corpus, the dictionaries or the titles. That includes what the text grows into: "an" is අන් now, but අන… once a vowel follows.

**Measured 2026-10-06** (`bjt.db` fts5vocab, `dict.db` headwords, `tree.json` names). Each abbreviation was tried alone, with every possible next letter, and followed by a number.

| Typed | Can it start a real search? | Preview |
| --- | --- | --- |
| KN alone | Yes. "KN" is how this scheme types ඤ, as in ඤාණ: 1,970 corpus words, 1,078 dictionary words, 33 titles | Shown |
| AN alone | Yes. AN + a vowel → ඇණ…: 62 corpus words | Shown |
| Nd, Thig alone | Yes, barely: one corpus word each (ණ්ඩං; "Thigh…" → ථිඝාතකා) | Shown |
| The other 23 alone, in their listed case (SN, DN, MN, Dhp, Thag, Snp, …) | No | Hidden |
| Any abbreviation alone in lowercase ("an", "sn", "ud") | Lowercase is how Singlish is typed; "an" alone starts 3,501 words | Shown |
| Listed abbreviation + number, any case ("SN 1", "sn15.3", "AN 3", "KN 2") | No | Hidden |
| "an" + number ("an 3") | Yes: අන් followed by a number is in 2 texts | Shown |
| Single letters (A, D, M, S), with or without a number | Not checked; they start thousands of words | Shown |

**Keep it true:** zero today is not zero forever, because the corpus and the dictionaries can change. A test should re-run this check against the bundled databases and fail when a hidden form starts matching a word. The test agent writes it.

**Steps:**

1. One `const` table of abbreviations in `wisdom_shared`, next to the resolver: abbreviation, title, and whether it hides the preview when it stands alone. It replaces `SuttaCentralRefResolver.knownBooks` and `_displayBook`. Source: [Access to Insight](https://accesstoinsight.org/abbrev.html).
2. Keep every Access to Insight entry, with a comment on the ones the resolver cannot open yet: Vinaya (Cv, Mv), Khp, Miln, Nd, Nm, Nc, the commentaries (DhpA, KhpA, ThagA, ThigA) and the single letters. Later they can point at BJT sections, and the help docs list them all.
3. Sutta Nipāta is "Snp". In the table, "Sn" is noted as meaning SN here, because the resolver ignores case.
4. Replace the `parseRef` check in `singlishPreviewText` with this rule. The find bar, the main box and the recent list all read it from there.

**Optional, static site:** "SN 15.3" in the site's search dialog could open the BJT page. Cost: the concordance as extra rows in `search-index.json` (all of `sc-to-bjt.json` is 1,144 bytes on 2026-10-06; it grows as the concordance is authored), plus a small reference parser in `site.js`. The parser holds only Latin letters and digits, so the "no Sinhala, no URLs in site.js" rule still holds. Do it only while it stays this small.

**Files:** `packages/wisdom_shared/lib/src/refs/`, `lib/core/utils/search_query_utils.dart`.

**Decided 2026-10-06:**

- The table is a `const` in `wisdom_shared`, not a JSON asset: no new static files on the app side.
- Sutta Nipāta is "Snp". Checked: SuttaCentral's ID is `snp1.8`, shown as "Snp 1.8". Access to Insight, dhammatalks.org and Wikipedia use "Sn", but only case-sensitively, and phones auto-capitalise "sn 1.8" to "Sn 1.8".
- Every Access to Insight entry stays in the table; the ones that cannot open anything yet carry a comment.

**Done when:**

- [ ] "SN", "SN 1", "sn15.3", "AN 3" and "Dhp" show no preview in the find bar, the main box or the recent list.
- [ ] "AN", "KN", "an", "an 3", "a", "s" and "m" still show their previews.

## Handover notes

### Chunk A: done (f4ccc14, tests 4b01bd0)

Done: Tasks 1, 2 and 3, plus the clear ✕ tooltip in the search box (Task 10).

- `singlishPreviewText(raw)` in `search_query_utils.dart` returns the Sinhala to show, or null when there is none. It keeps the joiners: tatra → ටට්‍ර renders joined in the bundled font (HarfBuzz check, 2026-10-06). The Pali word තත්‍ර is typed thathra. Widgets read it through `singlishPreviewProvider(raw)` (`providers/singlish_preview_provider.dart`), which runs the conversion once per query. Calling it in `build` re-ran the converter on every rebuild: each find-bar match step, and every recent row each time the search bar rebuilt.
- `SinglishPreview` applies the 45% width cap itself; callers pass `fieldWidth`. No arrow: the tag alone marks the preview.
- The main box puts the preview at the right end of the field, before the clear ✕, not right after the typed text. Task 8 removed the two toggles that also sat there.
- The find bar, the main box and the recent list all hide the preview for a reference like "SN 15.3": `singlishPreviewText` checks `parseRef`. Task 11 refines that rule.
- The `isSinglishConverted` getters on both search states and `querySinglishConverted` were removed: nothing used them once the preview had its own rule.
- New l10n key: `removeRecentSearch`.
- Tests, all passing on macOS on 2026-10-06: new `test/core/utils/search_query_utils_test.dart` (the preview rule); `integration_test/in_page_search_test.dart` test 2 checks the find-bar preview; `integration_test/search_flow_integration_test.dart` 10.1 checks the main-box preview and that a Singlish recent entry shows only the Sinhala.
- Run on macOS on 2026-10-06. Two fixes found, listed below. The "…" fix was checked in the app the same day; the tooltip fix is not confirmed yet.

**Fixes after the first run (chunk A), both done:**

- [x] Recent searches: a long entry ends in "…". The title has `maxLines: 1` and `overflow: TextOverflow.ellipsis` (`recent_search_overlay.dart`).
- [x] Crash when the ✕ tooltip in recent searches shows: "The paint transform cannot be reliably computed because of RenderFollowerLayer(s)". `SearchBar` now places the dropdown with `OverlayPortal.overlayChildLayoutBuilder`, not a `CompositedTransformFollower`. A Flutter upgrade would not have fixed it: Flutter's docs say a follower between an `OverlayPortal` and its overlay is not supported. To check in the app: hover the ✕ in recent searches.

### Chunk B: done (64ff654, 4a98260)

Done: Tasks 5, 6 and 7, plus the footer text and the "View N more" button (Task 10).

- Tabs are a real `TabBar` (scrollable, start-aligned). Its `TabController` follows `selectedResultType`, so "See all" moves it from outside. Every tab but Top results keeps its count badge (`_CountBadge`, "100+" above 100). An invisible "100+" inside each badge keeps it at that width, so tabs don't slide while typing; a "3" sits in a wider pill.
- The `TabBar` draws its own full-width divider. Never set `dividerHeight: 0`: a scrollable `TabBar` then shrinks to its tabs and, on a wide panel, sits in the middle with a short line (seen 2026-10-07).
- No tab dims: an empty tab shows a "0" badge and looks like the others. Counts are not cleared while typing, so a badge keeps its last number until the new counts arrive: no flicker. If the count query fails, the counts are cleared and the tabs show no badges.
- Top results headers show the label and "See all →". "See all" shows only when the count is larger than the rows in the section, and stays hidden until counts load. Full text compares match rows, not groups.
- Edition badge: `_hasMixedEditions` decides once per list; in Top results, titles and full text decide together. With no badge: text at 16px, divider indent 16, and "View N more" and the expanded box line up with the text. Definitions keep their badges and the 72 indent. Every result is BJT today, so no badge shows.
- `GroupedFTSTile` watches only its own expanded flag (`select`). The panel still watches the whole search state and rebuilds every tile: item 5 in `docs/todo/perf-top10-killers.md`.
- Shared widgets: `SearchResultTile` (also the primary row of `GroupedFTSTile`, which had a copy), `ResultBadge` (edition and dictionary badges, plus the spacing numbers that line rows up) and `SearchLinkButton` ("See all" and "View N more").
- "View N more" is a `TextButton` with a 40px tap area, in the primary colour as on the canvas (it was grey).
- New l10n keys: `seeAll`, `viewingResults`. The English footer text is unchanged. Stray U+200B removed from four Sinhala strings: `viewMore`, `themeLight`, `expand` and `updateBannerRefreshAction`. The ZWJ in ප්‍රතිඵල stays.
- Tests, all passing on 2026-10-07: `search_results_panel_test.dart` adds "See all" (hidden before counts load and when every row shows; tapping opens the tab and moves the tab bar to it) and "View 2 more" (shows the hidden matches and "Show Less"); `search_state_notifier_test.dart` adds "a failed count clears the old counts". The tab count tests pass again. No edition badge test: every result is BJT today.
- Built and launched on macOS on 2026-10-06; the UI was not checked by eye yet. It is checked together with chunk C (list there). Also check that tabs don't shift when you switch: the active tab is bold, so it is wider. If they jump, use one weight and mark the active tab by colour and underline only.

### Chunk C: done (ec85971)

Done: Tasks 4 and 8, plus the Treatises naming (Task 10).

- `PillChip` (`common/pill_chip.dart`) replaces `_ScopeChip`, `_FilterChip` and both `_RefineChip` copies; `PillChip.refine` is the Refine chip, with its own colours as before. It is a `TextButton`: 32px pill, 13px text (`AppFonts.chipFontSize`), 48px tap area. Colours are the ones from before this chunk. `PillChip.styleOf` gives the same look to "Starts with ▾", with 8px corners.
- `PillChipRow` (`common/pill_chip_row.dart`) is the one scrolling row both chip widgets now use, with the right-edge fade. Its end padding equals the fade width, so the last chip is clear of the fade when scrolled to the end. Both chip widgets take `leading`: the match button and the divider, so they scroll with the chips.
- `ScopeFilterChips` watches only scope and the two language flags (`select`). It watched the whole search state and rebuilt on every keystroke.
- The chip font is 13px, so the research mode selector, which borrows `chipLabel`, grew from 12px to 13px too.
- Desktop shows → with the tooltip "Close panel". Phones keep ✕ until Task 9. The row is 56px, on the same `surfaceContainerHighest` as before.
- `MatchOptionsButton` and its menu are in `search/match_options_menu.dart`. The button watches one record (`select`), so it rebuilds only when its label changes. The "two or more words" check is a `\s\S` test on `effectiveQueryText`, the text that is searched (so " dhamma" is one word), run inside the selector, not in `build`. The menu body is built only while the menu is open.
- The notifier has one new method, `setMatchOptions`. "Anywhere", "Near" and "Reset" each change two to four fields, and one call per field would start one search each. A change to the distance alone waits 300 ms, as typing does, so tapping + ten times runs one search. There is no `setExactMatch`: `setMatchOptions(isExactMatch:)` covers it.
- Changing the distance also selects "Near each other". The stepper shows "Within N words" as text beside − and +, so Sinhala can put the number where it belongs (වචන 10ක් ඇතුළත).
- Esc: the menu registers on `overlayStackProvider` while open, and its `dispose` removes the entry too, because a menu closed by disposal never calls `onClose`. It does so after the frame: Riverpod forbids changing a provider while widgets are torn down.
- Deleted: `ProximityDialog`, and the l10n keys only it or the toggles used: `wordProximity`, `wordsApart`, `apply`, `searchAsPhrase`, `searchAsSeparateWords`. `anywhereInText` is reused for the menu option. `CircularToggleButton` stays (the dictionary sheet uses it). Also `toggleExactMatch`, `setPhraseSearch`, `setAnywhereInText` and `setProximityDistance` on the notifier; their tests moved to `setMatchOptions`.
- Not renamed: `TipitakaNodeKeys.treatises` and `isTreatise` (code names, never shown).
- New l10n keys: `closePanel`, `matchOptions`, `matchEachWord`, `matchStartsWith`, `matchStartsWithHint`, `matchWholeWord`, `matchWholeWordHint`, `matchWholeWordExample`, `matchHowWordsSit`, `matchPhrase`, `matchPhraseHint`, `matchPhraseShort`, `matchAnywhereHint`, `matchAnywhereShort`, `matchNear`, `matchNearHint`, `matchNearShort`, `matchNearWithin`, `fewerWords`, `moreWords`, `resetToDefault`; `scopeTreatises` became `scopeOther`. The Sinhala for the menu is a first draft: review it.

Review fixes (2026-10-07):

- A filter change now cancels a search still waiting on the typing pause. Typing, then tapping a chip within 300 ms, ran the same search twice. `_refreshSearchAfterPause` is merged into `_refreshSearchIfNeeded({afterPause})`.
- The menu's text uses `AppTypography`, so it follows the app's font scale (0.9 on web) like the chips. Its section labels use `sectionHeader`, like the panel's.
- "As a phrase" also turns off "Anywhere", so the same search hits the cache.
- `clearFilters` reads its defaults from `const SearchState()`, as the menu does.
- `OverlayStackNotifier.remove` does nothing when the id isn't there (the match button's `dispose` calls it on every tab switch).
- Deleted the unused l10n keys `phraseSearch` and `exactConsecutiveWords`.
- Moved to `perf-top10-killers.md`: the header rebuilding on every keystroke (item 5) and the fade's offscreen layer (B5).

Review fixes (2026-10-08):

- Removing the match button while its menu was open threw in debug ("Tried to modify a provider while the widget tree was building"). On a phone: backspace empties the query with the menu open. Fixed by the after-the-frame removal above. `SearchBar.dispose` has the same pattern but can't hit it: the bar is a fixed app-bar action, gone only when the app closes.
- Closing the panel within 300 ms of typing or − / + left the spinner up for good: `dismissResultsPanel` cancelled the waiting search, and reopening doesn't search. It no longer cancels.
- A tab tap within 300 ms of typing ran the search twice. `selectResultType` now cancels the wait.
- " dhamma" or "%& x" showed the phrase options, but search sees one word. "Two or more words" now reads `effectiveQueryText`.
- The menu examples leave out words the search drops whole ("එවං %&" showed `%&…`). Symbols stuck to a word still show; a full clean would need a cleaner that keeps ZWJ.
- "Reset to default" counts only the options on show. It lit up for one word when the hidden "how words sit" choice wasn't the default.
- Deleted `onBlur` from the notifier: nothing called it, and it cancelled the waiting search (the stuck spinner again, had anyone wired it to focus loss).

Tests, all passing on 2026-10-08 (unit suite, and on macOS `search_flow_integration_test`):

- Fixed: the panel test taps → (the 800px test screen is desktop), the scope chips test expects "Other", and `search_test_helper.dart` drives the menu (`toggleExactMatch`, `matchWordsAnywhere`, `matchWordsNear(n)` with − / +).
- Test 3.4 expects 17, not 14. The old slider was tapped by pixel and landed near 13, not 20 (checked against `bjt.db`); − / + sets 20 exactly.
- New: `match_options_menu_test.dart` (labels, options per word count, examples incl. Singlish, Esc stack, Reset, stepper limits), the `setMatchOptions` group in `search_state_notifier_test.dart` (incl. the 300 ms wait), the two notifier fixes above, and `overlay_stack_provider_test.dart` (removing an id that isn't there). One shared `test/helpers/fake_search_state_notifier.dart` replaces five copies.

To check by eye (with chunk B): desktop and phone width, English and Sinhala, light and dark.

- The chip row: arrow, "Starts with ▾", divider, chips, Refine last; the fade; Tab reaches every chip; Enter/Space toggles.
- The menu with one word, then two: labels, examples, the stepper, Reset. Esc with the menu open closes only the menu. Also with focus left in the search box.
- The Singlish preview in the main box at phone width, now that the toggles are gone.
- Dark-theme items found on the way are in `docs/todo/dark-theme.md`.

Next: Chunk D.

## Done outside the chunks (2026-10-08)

Found while working on the chunks. Also see the recent-search change in Task 3.

- [x] **`in_page_search_test` 3b failure: did not come back.** It passed alone, in its own file, and in `all_tests.dart` (78/78) on macOS. Nothing changed. If it fails again, keep the failure output.
- [x] **"As a phrase" is now an ordered phrase.** `buildFtsQuery` sends `w1* + w2*` (FTS5's phrase with prefix words), not `NEAR(w1* w2*, 1)`. For කර්ම ඵල that is 140 texts, down from 176. Test counts did not change: 3.1 is still 100+, 4.1 still 7. The highlighter already matched words in order.
- [x] **Recent searches drop Helakuru's invisible space.** `addRecentSearch` removes U+200B before saving and comparing; the joiner U+200D stays. Old entries are not cleaned: clear the list by hand.
- [x] **Recent searches keep letter case.** Adding and removing compare the text exactly, not lowercased. In Singlish "kana" (කන) and "kaNa" (කණ) are different words; "kaNa" used to drop "kana" from the list.

To check the space fix by hand:

1. Type අරුණව with Helakuru and open a result.
2. Copy අරුණව from the reader text, paste it into the search box, and open a result.
3. Empty the search box. Before the fix, the list shows අරුණව twice. After it, once.
4. Quit the app, then list what was saved. No `\u200b` should appear:

```bash
python3 -c "import plistlib,json,os; p=os.path.expanduser('~/Library/Containers/lk.tipitaka.theWisdomProject/Data/Library/Preferences/lk.tipitaka.theWisdomProject.plist'); [print(repr(e['queryText'])) for e in json.loads(plistlib.load(open(p,'rb'))['flutter.recent_searches'])]"
```
