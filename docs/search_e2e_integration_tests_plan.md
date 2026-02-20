# Search Flow E2E Integration Tests Plan

## Context

The search system is the heart of the app, but all existing tests use **mocked data**. No tests run real queries against the real FTS database. This means nothing catches when actual search results change due to database rebuilds, query pipeline fixes, or transliteration changes.

This plan adds **full E2E integration tests** that simulate a real user: type in the search bar, wait for results, check tab badge counts, switch tabs, toggle exact match, open proximity dialog, etc. - all backed by the real FTS database, navigation tree, and dictionary.

## 1. Test Type: Full E2E Integration Tests

- **Location:** `integration_test/search/`
- **Run command:** `flutter test integration_test/search/ -d macos`
- **Binding:** `IntegrationTestWidgetsFlutterBinding`
- **Data:** Real FTS database (`bjt-fts.db`), real tree (`tree.json`), real dictionary (`dict.db`)
- **UI:** Pumps real `SearchBar` + `SearchResultsPanel` widgets with real providers
- **No production code changes needed**

### How It Works

We create a minimal test widget that includes the search bar and results panel, backed by real providers:

```
ProviderScope (only override SharedPreferences)
  └─ MaterialApp (with localization)
      └─ Scaffold
          └─ Column
              ├─ SearchBar (real widget)
              └─ SearchResultsPanel (shown when query entered)
```

All search providers (`ftsDataSourceProvider`, `navigationTreeRepositoryProvider`, `dictionaryRepositoryProvider`, `textSearchRepositoryProvider`, `searchStateProvider`) use their **real implementations** - no mocks.

### Verification Approach

For each test, we verify both:
1. **Provider state** (precise): Read `searchStateProvider` from the container to check exact `countByResultType` values
2. **Widget tree** (visual): Check that tab badge text, result tiles, and empty state messages render correctly

## 2. Test File Structure

```
integration_test/
  search/
    search_test_helper.dart           # Shared setup, helper extensions
    search_flow_integration_test.dart  # All test cases in organized groups
```

### `search_test_helper.dart` Will Provide

```dart
// Extension on WidgetTester for search-specific helpers:
extension SearchTestHelpers on WidgetTester {
  /// Pump the search test widget with real providers
  Future<void> pumpSearchApp(SharedPreferences prefs);

  /// Enter query and wait for search to complete (debounce + DB query)
  Future<void> searchFor(String query);

  /// Wait for search results to load (polling for CircularProgressIndicator to disappear)
  Future<void> waitForSearchResults();

  /// Read search state counts from provider
  Map<SearchResultType, int> getResultCounts();

  /// Toggle exact match via the ABC icon button
  Future<void> toggleExactMatch();

  /// Open proximity dialog and apply settings
  Future<void> setProximitySettings({
    bool? isPhraseSearch,
    bool? isAnywhereInText,
    int? proximityDistance,
  });

  /// Switch to a specific tab
  Future<void> switchToTab(String tabName);

  /// Tap a scope filter chip (e.g., "Sutta", "Commentaries")
  Future<void> tapScopeChip(String chipLabel);

  /// Open Refine dialog, select specific tree nodes by Sinhala name, close
  Future<void> refineScope(List<String> nodeNames);

  /// Clear search and reset
  Future<void> clearSearch();
}
```

### Key Widget Finders

| Element | Finder | Source |
|---|---|---|
| Search text field | `find.byType(TextField)` | `search_bar.dart:168` |
| Exact match toggle | `find.byIcon(Icons.abc)` | `search_bar.dart:199` |
| Proximity button | `find.byIcon(Icons.space_bar)` | `search_bar.dart:225` |
| Clear button | `find.byIcon(Icons.clear)` | `search_bar.dart:240` |
| Tab: "Top Results" | `find.text('Top Results')` | `search_result_type.dart:23` |
| Tab: "Titles" | `find.text('Titles')` | `search_result_type.dart:25` |
| Tab: "Full text" | `find.text('Full text')` | `search_result_type.dart:27` |
| Tab: "Definitions" | `find.text('Definitions')` | `search_result_type.dart:29` |
| Invalid query msg | `find.text('Enter a valid search query')` | `search_results_panel.dart:391` |
| No results: titles | `find.text('No titles found')` | `search_results_panel.dart:393` |
| No results: FTS | `find.text('No full text found')` | `search_results_panel.dart:393` |
| No results: defs | `find.text('No definitions found')` | `search_results_panel.dart:393` |
| Loading spinner | `find.byType(CircularProgressIndicator)` | `search_results_panel.dart:95` |
| Phrase radio | `find.text(l10n.searchAsPhrase)` | `proximity_dialog.dart:121` |
| Separate words radio | `find.text(l10n.searchAsSeparateWords)` | `proximity_dialog.dart:131` |
| Anywhere checkbox | Checkbox within proximity dialog | `proximity_dialog.dart:204` |
| Apply button | `find.text(l10n.apply)` | `proximity_dialog.dart:231` |
| Count badge text | e.g., `find.text('44')` | `search_results_panel.dart:538` |
| Refine chip | `find.text('Refine')` | `scope_filter_chips.dart:104` |
| Sutta chip | `find.text('Sutta')` (or localized) | `scope_filter_chips.dart` |
| Commentaries chip | Localized label | `scope_filter_chips.dart` |
| Refine dialog | `find.byType(Dialog)` | `refine_search_dialog.dart` |
| Dialog "Done" btn | `find.text('Done')` | `refine_search_dialog.dart` |
| Dialog "Clear" btn | `find.text('Clear')` | `refine_search_dialog.dart` |
| Tree node: මැදුම් සඟිය | `find.text('මැදුම් සඟිය')` | tree.json nodeKey=`mn` |
| Tree node: සංයුක්ත නිකාය | `find.text('සංයුත්ත නිකාය')` | tree.json nodeKey=`sn` |
| Tree node: සූත්‍ර අටුවාව | `find.text('සූත්‍ර අටුවාව')` | tree.json nodeKey=`atta-sp` |
| Tree node: විනය අටුවාව | `find.text('විනය අටුවාව')` | tree.json nodeKey=`atta-vp` |
| Tree node: අභිධර්ම අටුවාව | `find.text('අභිධර්ම අටුවාව')` | tree.json nodeKey=`atta-ap` |

## 3. Complete Test Cases

### Group 1: Singlish/Sinhala Equivalence (Tests 1-2)

**Test 1.1:** Type `mahaasathi` (Singlish) → wait → verify badge counts: Titles=2, Full text=44, Definitions=19

**Test 1.2:** Clear, type `මහාසති` (Sinhala) → wait → verify same counts: Titles=2, Full text=44, Definitions=19

**Test 1.3:** Toggle exact match ON → wait → verify all counts = 0. Verify "No results found" messages appear.

**Test 2.1:** Type `waasawa` → verify: Titles=2, Full text=100+, Definitions=23

**Test 2.2:** Type `වාසව` → verify same counts

**Test 2.3:** Check Top Results tab composition:
- Switch to "Top Results" tab
- Verify TITLES section shows results including "සත්තාවසවග්ගො" and "සත්තාවාසවග්ගො"
- Verify FTS section shows results including "මිච්ඡාකථා", "භසජාතකවණ්ණනා"
- Verify DEFINITIONS section shows "වාසව"

**Test 2.4:** Toggle exact match ON → verify: Titles=0, Full text=40, Definitions=6

### Group 2: Multi-word Search Modes (Tests 3-4)

**Test 3.1:** Type `කර්ම ඵල` (default phrase mode) → verify: Titles=0, Full text=100+, Definitions=0

**Test 3.2:** Toggle exact match ON → verify: Titles=0, Full text=5, Definitions=0

**Test 3.3:** With exact match ON, switch to Full text tab → verify first 3 results are visible → verify `HighlightedFtsSearchText` widgets exist (highlighting works)

**Test 3.4:** Toggle exact match OFF. Open proximity dialog → select "Separate words" radio → set slider to 20 → tap Apply → wait → verify Full text count = 14

**Test 3.5:** Open proximity dialog → check "Anywhere in text" checkbox → tap Apply → wait → verify Full text count = 45

**Test 4.1:** Clear search, type `ජායෙථ වා` → verify Full text = 7

**Test 4.2:** Open proximity dialog → select "Separate words" → set slider to 50 → tap Apply → verify Full text = 13

**Test 4.3:** Toggle exact match ON → verify Full text = 12

### Group 3: Special Characters & Numbers (Tests 5-6)

**Test 5.1:** Type `16. සමු%` → verify: Titles=2, Full text=4, Definitions=0

**Test 6.1:** Type `356` → verify: Titles=2, Full text=86, Definitions=0

### Group 4: Invalid & Empty Input (Tests 7, 9)

**Test 7.1:** Type `%&` → verify all tabs show "Enter a valid search query" message (icon: `Icons.edit_note`)

**Test 9.1:** Type `Empty` → verify: Titles=0, Full text=0, Definitions=0. Switch to each tab and verify respective "No titles found" / "No full text found" / "No definitions found" messages

**Test 9.2:** Type nothing (empty field) → verify results panel is NOT visible (`isResultsPanelVisible` = false)

### Group 5: Recent Search (Test 10)

**Test 10.1:** Search `මහාසති` → tap a result → verify search saved to recent. Clear search → focus search bar → verify recent search overlay appears with "මහාසති" visible

### Group 6: Scope Filtering & Refine Dialog

**Test A1: Quick scope chip** — Search `මහාසති` → tap "Sutta" scope chip → wait → verify: Titles=1, Full text=3, Definitions=19

**Test A2: Refine dialog - select specific nikayas**
1. Search `aanandha` → verify: Titles=53, Full text=100+, Definitions=100+
2. Tap "Sutta" scope chip → wait → verify: Titles=26, Full text=100+, Definitions=100+
3. Tap "Refine" chip → dialog opens
4. Select only "මැදුම් සඟිය" (`mn`) and "සංයුක්ත නිකාය" (`sn`) → tap "Done"
5. Wait → verify: Titles=14

**Test A3: Refine dialog - commentaries**
1. (Continuing from A2 or fresh search of `aanandha`)
2. Tap "Refine" chip → dialog opens
3. Select "සූත්‍ර අටුවාව" (`atta-sp`), "විනය අටුවාව" (`atta-vp`), "අභිධර්ම අටුවාව" (`atta-ap`) → tap "Done"
4. Verify "Commentaries" scope chip is highlighted
5. Wait → verify: Titles=27

### Group 7: Additional Coverage

**Test B1: BM25 ordering** — Search `මහාසති`, read FTS results from provider → verify `relevanceScore` values are non-decreasing

**Test B2: Pagination** — Search `මහා` (large result set) → switch to each tab and verify pagination footer: Full text shows "50 out of 29769", Titles shows "50 out of 340", Definitions shows "50 out of 3252"

## 4. Impact on Existing Tests

### Tests That Stay (different purpose)

| Test File | Lines | Why Keep |
|---|---|---|
| `search_state_notifier_test.dart` | 1079 | Tests debouncing, race conditions, error recovery - hard to test in E2E |
| `text_search_repository_impl_test.dart` | 1885 | Fast unit feedback for repository logic, precise failure location |
| `fts_datasource_test.dart` | 367 | Tests FTS5 query syntax building specifically |
| `search_match_finder_test.dart` | 187 | Tests highlighting match ranges (pure Dart) |
| `text_utils_test.dart` | 122 | Tests text normalization (pure Dart) |
| `scope_operations_test.dart` | 1010 | Tests scope filtering logic (pure Dart) |
| `grouped_fts_match_test.dart` | 336 | Tests result grouping (pure Dart) |
| `recent_searches_repository_impl_test.dart` | 181 | Tests persistence with SharedPreferences |

### Tests That Become Redundant (candidates for removal)

| Test File | Lines | Why Redundant |
|---|---|---|
| `search_bar_widget_test.dart` | ~150 | E2E tests exercise the same widget with real data |
| `search_results_panel_test.dart` | ~150 | E2E tests exercise the same widget with real data |

**Recommendation:** Remove these two widget test files once the E2E tests are passing. They test the same widget interactions but with mocked data, which provides less confidence than E2E tests with real data.

## 5. Implementation Steps

1. **Create `integration_test/search/search_test_helper.dart`**
   - `pumpSearchApp()` extension that builds the test widget with real providers
   - `searchFor(query)` that enters text + waits for debounce + waits for results
   - `waitForSearchResults()` with polling (wait for `CircularProgressIndicator` to disappear)
   - `getResultCounts()` that reads provider state
   - `toggleExactMatch()`, `setProximitySettings()`, `switchToTab()` helpers

2. **Create `integration_test/search/search_flow_integration_test.dart`**
   - Groups 1-7 with `testWidgets` for each test case
   - Each test uses the helpers for clean, readable code

3. **Run and calibrate** - Run tests, adjust any counts that differ from manually-observed values

4. **Remove redundant widget tests** - Delete `search_bar_widget_test.dart` and `search_results_panel_test.dart`

## 6. Critical Files

| File | Role |
|---|---|
| `lib/presentation/widgets/search/search_bar.dart` | Search input widget (pumped in tests) |
| `lib/presentation/widgets/search/search_results_panel.dart` | Results display widget (pumped in tests) |
| `lib/presentation/widgets/search/proximity_dialog.dart` | Settings dialog (interacted with in tests) |
| `lib/presentation/widgets/search/scope_filter_chips.dart` | Scope filter chips (tapped in tests) |
| `lib/presentation/widgets/search/refine_search_dialog.dart` | Refine dialog (interacted in tests) |
| `lib/presentation/providers/search_provider.dart` | Provider definitions (real providers used) |
| `lib/presentation/providers/search_state.dart` | SearchState + SearchStateNotifier |
| `lib/data/datasources/fts_datasource.dart` | Real FTS database queries |
| `lib/data/datasources/dictionary_datasource.dart` | Real dictionary queries |
| `lib/data/datasources/tree_local_datasource.dart` | Real tree loading |
| `lib/data/repositories/text_search_repository_impl.dart` | Search orchestration |
| `lib/core/utils/search_query_utils.dart` | Query pipeline |
| `lib/domain/entities/search/search_result_type.dart` | Tab names/display names |
| `test/helpers/pump_app.dart` | Existing test helper pattern to follow |

## 7. Verification

```bash
# Run search integration tests on macOS
flutter test integration_test/search/ -d macos

# Run all remaining unit tests to ensure nothing broke
flutter test test/
```

## 8. Timing Considerations

- **First run** will be slower: FTS database (95MB) and dictionary (167MB) are copied from assets to documents directory
- **Subsequent runs** are faster: databases already exist
- Each `searchFor()` call needs ~3-5 seconds (300ms debounce + DB query + widget rebuild)
- Full test suite should run in ~2-3 minutes
