# Integration Test Suite — Performance & Duplication Audit

**Status:** TODO
**Suite runtime today:** ~10 min (`flutter test integration_test/all_tests.dart -d macos`)
**Target:** Shave ≥20 s purely via structural changes — no test flow changes.

---

## 1. Background: how `pumpAndSettle` actually behaves here

This is the load-bearing fact behind most of the recommendations below.

`IntegrationTestWidgetsFlutterBinding` extends `LiveTestWidgetsFlutterBinding`. In that binding:

- `pumpAndSettle(duration)`'s **first** argument is **the real wall-clock interval between pumped frames**, not a max-timeout. The max-timeout is the third arg (defaults to 10 minutes).
- Each iteration of the settle loop calls `await Future.delayed(duration)` before drawing the next frame.
- So `pumpAndSettle(const Duration(seconds: 2))` blocks **≥2 real seconds per iteration**, even when the UI was already idle after the first frame.
- The default `pumpAndSettle()` uses a 100 ms interval — 20× faster per iteration.

This is the dominant time sink across the suite.

---

## 2. Performance findings (ordered by impact)

### Finding 1 — Replace `pumpAndSettle(const Duration(seconds: 2))` calls

**Occurrences:** 36 (grep: `pumpAndSettle(const Duration(seconds: 2))`).
**Estimated savings:** 40–70 s.

Most live in `openTab` helpers or right after tab/layout switches. Typical UI settle is <500 ms, so each call wastes ~1.5 s minimum.

**Hot spots (helpers fix many sites at once):**

| File | Line | Used by N callers |
|---|---|---|
| `in_page_search_test.dart` | 87 (`openTab`) | 8 tests |
| `previous_sutta_navigation_test.dart` | 109 (`openTab`) | 7 tests |
| `breadcrumb_navigation_test.dart` | 113 (`openTab`) | 7 tests |
| `dictionary_editable_word_test.dart` | 152 (`openTab`) | 4 tests |
| `layout_switch_test.dart` | 85 (`openTab`) | 3 tests |
| `scroll_restoration_test.dart` | 96, 114, 140, 157, 223, 229, 238, 259, 318, 372 | 10 inline calls |

**Recommended structural fix** (no flow change). Replace blind interval-based waits with awaiting the actual async work that was being implicitly waited on:

```dart
Future<void> openTab(
  WidgetTester tester,
  ProviderContainer container,
  ReaderTab tab,
) async {
  container.read(tabsProvider.notifier).addTab(tab);
  container.read(activeTabIndexProvider.notifier).state =
      container.read(tabsProvider).length - 1;
  // Wait for the actual document load instead of guessing 2s.
  if (tab.contentFileId != null) {
    await container.read(currentBJTDocumentProvider.future);
  }
  await tester.pumpAndSettle(); // 100 ms interval, settles fast
}
```

For non-tab-open sites (tab switches, navigation taps), just drop the argument:

```dart
await tester.pumpAndSettle(); // was: pumpAndSettle(const Duration(seconds: 2))
```

### Finding 2 — Replace `pumpAndSettle(const Duration(seconds: 1))` calls

**Occurrences:** 15.
**Estimated savings:** 10–15 s.

Same root cause, smaller per-call cost. Same fix (drop the interval argument).

**Hot spots:**

| File | Lines |
|---|---|
| `in_page_search_test.dart` | 388, 513, 584 (one is inside a loop — see Finding 5) |
| `dictionary_editable_word_test.dart` | 185, 212, 245, 291, 314, 390, 459, 504 |
| `layout_switch_test.dart` | 167, 193, 242, 529 |

### Finding 3 — Cache the navigation tree across tests

**Estimated savings:** 5–15 s.

Every `pumpReaderApp` / `pumpBreadcrumbApp` (~30 invocations across the suite, since `navigationTreeProvider` appears in 10 setup blocks and most tests pump the app once) re-reads + decodes the full Tipitaka tree from assets via:

```dart
await container.read(navigationTreeProvider.future);
```

Because `all_tests.dart` runs everything in a single app instance, the asset bundle is shared but the JSON parse happens per test.

**Recommended structural fix** (no flow change). Add to `integration_test/test_overrides.dart`:

```dart
// Lazy-loaded once per process. Subsequent reads return the cached future.
Future<List<TipitakaTreeNode>>? _cachedTreeFuture;

Future<List<TipitakaTreeNode>> _loadTreeOnce() {
  return _cachedTreeFuture ??= _realTreeLoader();
}

Override navigationTreeOverride() =>
    navigationTreeProvider.overrideWith((ref) => _loadTreeOnce());
```

Then every `ProviderScope` that needs the tree adds `navigationTreeOverride()` alongside `keyValueStoreOverride()`. Same data, same provider semantics — just no per-test re-parse.

### Finding 4 — Tighten `waitForSearchResults` polling

**Estimated savings:** 2–5 s.

`integration_test/search_test_helper.dart:96–113` polls with `pump(const Duration(milliseconds: 250))`. Halving to 100 ms halves the average detection latency. Called ~25× across the search suite.

The post-success `pumpAndSettle(const Duration(milliseconds: 200))` afterwards has the same interval issue — should be `pumpAndSettle()`.

Same problem in the **duplicated** `_waitForSearchResults` in `search_tab_highlight_test.dart:126–138` (see Duplication finding 8).

### Finding 5 — `pumpAndSettle(const Duration(milliseconds: 500))` inside loops

**Estimated savings:** 2–4 s.

Both of these pump 500 ms × 5 iterations = ~2.5 s minimum per loop, for animations that probably settle in <100 ms:

- `in_page_search_test.dart:584` — inside a 5-iteration `nextMatch()` loop.
- `layout_switch_test.dart:584` — inside another 5-iteration `nextMatch()` loop.

Drop the interval.

---

## 3. Estimated total savings

| Scenario | Savings |
|---|---|
| Conservative (Finding 1 helpers + Finding 2) | **45–60 s** |
| Aggressive (all 5 findings) | **60–100 s** (10–17 % of a 10-min suite) |

Comfortably beats the 20 s target.

---

## 4. Duplicated / overlapping test paths

> **Note:** Per the user's direction, test flows should not be changed. This section is informational only — it flags overlap so a future intentional cleanup can decide what to keep.

### 4.1 Functional overlap — same flow covered twice

#### Duplicate 1 — `search_flow_integration_test.dart` 1.1 vs 1.2 (Singlish/Sinhala equivalence pair)

**Test 1.1:** Pump search app → type `"mahaasathi"` (Singlish input) → expect `(titles: 2, fullText: 44, definitions: 19)`.
**Test 1.2:** Pump search app → type `"මහාසති"` (Sinhala input) → expect `(titles: 2, fullText: 44, definitions: 19)`.

The two inputs map to the same FTS query after the Singlish→Sinhala transliteration step. The whole search pipeline downstream of transliteration is exercised identically. The only differentiating logic is whether the transliteration step fires, and that's already implied by the count parity itself.

Same pattern repeats at:

#### Duplicate 2 — `search_flow_integration_test.dart` 2.1 vs 2.2

Same shape: `"waasawa"` (Singlish) vs `"වාසව"` (Sinhala) → both expect `(titles: 2, fullTextGreaterThan100: true, definitions: 23)`.

**Why this duplicates effort:** Each `searchFor` triggers a full FTS query + tree scan + dictionary scan. Doing the same heavy work twice for symmetry — when one parameterised test with two input rows would prove equivalence in a single pump — is the cost.

#### Duplicate 3 — `previous_sutta_navigation_test.dart` Test 2 vs Test 3

**Test 2:** Open `dn-1-1` → assert tooltip mentions `සීලක්ඛන්ධවග්ගො` → tap skip_previous → assert active node is `dn-1`.
**Test 3:** Open `dn-1-1` → tap skip_previous → assert active node is `dn-1` → tap again → `dn` → tap again → `sp`.

Test 3 fully subsumes Test 2's navigation assertion (the first-hop step is identical). The only unique content in Test 2 is the tooltip-message check — a single `expect(tooltip.message, contains('සීලක්ඛන්ධවග්ගො'))` that could live in Test 3's first-hop section without changing Test 3's flow.

#### Duplicate 4 — `in_page_search_test.dart` Test 1 vs Test 3b

**Test 1:** Open `dn-1-1` → search `"එවං"` → assert matches found → tap arrow_down → index = 1 → tap arrow_up → index = 0 → tap arrow_up → wraps to `matchCount-1`.
**Test 3b:** Open `dn-1-1` → search `"එවං"` → step forward 3× with arrow_down → assert `currentMatchIndex == i` after each tap → assert viewport actually scrolled (new value-add) → step back 3× → assert viewport scrolled back → wrap to last match → assert pagination expanded + viewport jumped.

Test 3b's scroll-behaviour assertions are the new coverage (the regression guard called out in its own comments). The arrow-down/up index-tracking inside Test 3b's loop duplicates Test 1's index assertions verbatim — but Test 1 runs the same up/down work to verify nothing more than the index value.

**Why this duplicates effort:** Both tests pump the full reader app and load the same DN 1 document, search the same query, drive the same navigation icons. Test 3b alone would cover the index-correctness assertions Test 1 makes, since Test 3b already asserts index after each tap.

#### Duplicate 5 — `scroll_restoration_test.dart` Test 1 vs Test 3

**Test 1:** Open two tabs → scroll Tab A → tap Tab B → assert Tab B is active at offset 0 → scroll Tab B → tap Tab A → assert each tab kept its position.
**Test 3:** Open a new tab → assert `readScrollOffset(container, 0) == 0.0`.

Test 1's STEP 1 already implicitly verifies "new tabs start at offset 0" (it asserts Tab B starts at 0 after activation). Test 3 is essentially a one-line restatement of that invariant on its own pumped app. Reading Test 3 as a regression guard for the "tab init never gets a stale offset" path is the only reason to keep it as a separate pump.

### 4.2 Repeated variant-table coverage

#### Duplicate 6 — `status_message_view_integration_test.dart` — repeated "loading/empty/error/offline" matrix

Four consumer panels, each tested across four AsyncValue states:

| Panel | Loading | Empty | Generic Error | Offline |
|---|---|---|---|---|
| TreeNavigatorWidget | ✓ | ✓ | ✓ | ✓ |
| SearchResultsPanel (specific tab) | ✓ | ✓ (+ "invalid" variant) | ✓ | ✓ |
| SearchResultsPanel (Top Results tab) | ✓ | ✓ (+ "invalid" variant) | — | — |
| MultiPaneReaderWidget | ✓ | ✓ (+ "no sutta" + "empty pages") | ✓ | ✓ |
| DictionaryBottomSheet | ✓ | ✓ | ✓ | ✓ |

≈20 tests, each pumping a fresh `MaterialApp` + `ProviderScope`. The variant-rendering logic (`statusVariantForError` + `StatusMessageView`) is shared, so each repeat exercises mostly the same code path with a different consumer.

**Why this duplicates effort:** It's defensive completeness — proving every panel renders every variant. The cost is N panels × M variants pumped separately. A parameterised matrix walking `(panel, variant)` pairs over a single pumped app would compress this dramatically without losing assertions.

### 4.3 Code (not test) duplication that adds time per file

#### Duplicate 7 — `pumpReaderApp` helper copy-pasted in 5 files

`in_page_search_test.dart`, `layout_switch_test.dart`, `breadcrumb_navigation_test.dart`, `previous_sutta_navigation_test.dart`, `dictionary_editable_word_test.dart` all define a near-identical `pumpReaderApp`:

```dart
ProviderScope(
  overrides: [
    bjtDocumentDataSourceProvider.overrideWithValue(BJTDocumentLocalDataSourceImpl()),
    keyValueStoreOverride(),
  ],
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: Column(children: [TabBarWidget(), Expanded(child: MultiPaneReaderWidget())])),
  ),
);
await container.read(navigationTreeProvider.future);
```

Lifting it into `test_overrides.dart` makes Finding 1 (helper-level `openTab` fix) and Finding 3 (cached tree) a single edit applied to every file.

#### Duplicate 8 — `openTab` helper copy-pasted in those same 5 files

Identical body in every file:

```dart
container.read(tabsProvider.notifier).addTab(tab);
container.read(activeTabIndexProvider.notifier).state =
    container.read(tabsProvider).length - 1;
await tester.pumpAndSettle(const Duration(seconds: 2));
```

This is the single biggest leverage point — fixing this one helper eliminates ~24 of the 36 `seconds: 2` sites.

#### Duplicate 9 — `_waitForSearchResults` duplicated in two files

`search_test_helper.dart:96–113` (as the `waitForSearchResults` extension method) and `search_tab_highlight_test.dart:126–138` (as a top-level function). Identical polling logic, identical 30 s timeout, identical 250 ms interval. The latter could call the former.

#### Duplicate 10 — `tabFromNode` / `tabAtBeginning` helpers copy-pasted

`in_page_search_test.dart`, `layout_switch_test.dart`, `breadcrumb_navigation_test.dart`, `previous_sutta_navigation_test.dart`, `dictionary_editable_word_test.dart` all build a `ReaderTab` from a tree node with trivial variations (label truncation, `pageEnd` offsets). Could unify behind a single helper in `test_overrides.dart`.

---

## 5. Recommended execution order

If/when this gets actioned, pick changes from lowest risk → highest leverage:

1. **(Lowest risk, highest leverage)** Lift `pumpReaderApp` + `openTab` + `tabFromNode` into `test_overrides.dart`, with the `openTab` body changed to `await currentBJTDocumentProvider.future; await pumpAndSettle();`. Migrate the 5 reader-test files to import the shared helpers. **This alone closes ~24 of the 36 `seconds: 2` sites.**
2. Add the cached `navigationTreeOverride()` to `test_overrides.dart`. Drop it into the same shared `ProviderScope`.
3. Sweep the remaining 12 inline `pumpAndSettle(const Duration(seconds: 2))` sites and the 15 `seconds: 1` sites. Drop the interval argument.
4. Tighten `waitForSearchResults` polling to 100 ms; consolidate the duplicate copy.
5. Drop the `milliseconds: 500` intervals inside the two 5-iteration loops.

After step 1+2, re-time the suite — that should already be at or past the 20 s target.

---

## 6. What was deliberately NOT changed

- **No test flow changes.** Every assertion in every test stays exactly as written. Only the timing/structure of how the test waits and sets up state changes.
- **No deletions of "overlapping" tests.** Section 4 is informational; the team can decide separately whether the redundancy is intentional defensive coverage.
