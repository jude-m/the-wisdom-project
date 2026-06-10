# Phase 1 — Make the Domain Layer Flutter-Free

> Status: **In progress** — Files 1, 3, 4 done (2026-06-09); **File 2 remaining.**
> Captured: 2026-06-06.
> Parent: [`web-rewrite-clean-architecture-audit.md`](./web-rewrite-clean-architecture-audit.md) (§4, Phase 1).
> Decision-independent: this is worth doing **regardless** of the eventual web
> framework (Jaspr vs Next.js). It also improves the native app's layering.

---

## Progress (2026-06-09)

| # | Domain file | State |
|---|---|---|
| 1 | `dictionary_filter_operations.dart` | ✅ Done |
| 2 | `dictionary_info.dart` | ⏳ Remaining (the `ThemeExtension` work) |
| 3 | `search_result_type.dart` | ✅ Done |
| 4 | `search_scope_chip.dart` | ✅ Done |

**Verification so far:** `grep "AppLocalizations" lib/domain` → **0**;
`flutter analyze lib` → **No issues found**. The only remaining
`package:flutter` in `lib/domain` is `dictionary_info.dart` (File 2).

What landed:
- **File 1** — dropped `flutter/foundation`; replaced `setEquals` with a private
  `_setEquals` helper. No call-site changes.
- **File 3** — enum reduced to pure Dart; deleted `SearchResultTypeExtension`
  (`displayLabel` moved out, `iconName` was dead code). Label helper folded into
  the existing `presentation/utils/search_result_labels.dart` as
  `searchResultTypeLabel(...)`. 3 call sites updated in `search_results_panel.dart`.
- **File 4** — chip reduced to pure `const` data (`{id, nodeKeys}`); deleted the
  unused `SearchScopeChipListX` extension. New helper
  `presentation/utils/scope_chip_labels.dart` (`scopeChipLabel(...)`). 1 call
  site updated in `scope_filter_chips.dart`. The chip list is now `const`.
- No tests written/modified (per project convention). Existing
  `scope_filter_chips_test.dart` still asserts `searchScopeChips.length == 5`
  (still true).

---

## Goal

Remove every Flutter/UI dependency from `lib/domain/`. Concretely:

```bash
grep -rl "package:flutter" lib/domain        # must return 0
grep -rln "AppLocalizations" lib/domain      # must return 0
```

`AppLocalizations` counts as a Flutter dependency — it's generated code that
needs a `BuildContext`. So "Flutter-free domain" also means "no l10n lookups in
domain."

**Nothing about behaviour, colours, or translations changes.** This is pure
relocation of UI concerns (a label, a colour) up into `presentation/` /
`core/theme/`, where they belong. The domain keeps the **stable data and keys**;
the UI layer maps those keys → strings/colours.

---

## The 4 offenders (today)

| # | Domain file | Flutter dependency | Why it's wrong |
|---|---|---|---|
| 1 | `domain/entities/dictionary/dictionary_filter_operations.dart` | `flutter/foundation` (for `setEquals` only) | Pure filter logic; only the import is dirty |
| 2 | `domain/entities/dictionary/dictionary_info.dart` | `flutter/material` (`Color`, `ThemeData`, `@immutable`) | Data is pure, but `getColor()` is a UI method in domain |
| 3 | `domain/entities/search/search_result_type.dart` | `AppLocalizations` (`displayLabel`) | Enum is pure; the localized label is a UI concern |
| 4 | `domain/entities/search/search_scope_chip.dart` | `flutter/widgets` (`BuildContext`) + `AppLocalizations` | Chip *data* (node keys) is domain; the *label* is UI |

Shared rule applied throughout: **labels stay in l10n, but are resolved in
presentation** (domain holds the key/id only); **colours move to the theme token
system** (domain holds none).

---

## File 1 — `dictionary_filter_operations.dart`  *(trivial, zero ripple)*

**Change:** drop the Flutter import; replace the single `setEquals` call (line 52)
with a tiny private helper.

```dart
// REMOVE: import 'package:flutter/foundation.dart';

// line ~52: change `setEquals(ids, group)` → `_setEquals(ids, group)`
// add:
static bool _setEquals(Set<String> a, Set<String> b) =>
    a.length == b.length && a.containsAll(b);
```

**Call sites affected:** none. All 6 consumers
(`search_state.dart`, `dictionary_filter_chips.dart`, `dictionary_bottom_sheet.dart`,
`refine_dictionary_dialog.dart`, and 2 integration-test helpers) call only the
*static methods* (`toggleKeys`, `normalize`, `hasCustomSelections`, …). The
`setEquals` swap is internal.

*(Alternative: add `collection:` to pubspec and use
`const SetEquality<String>().equals(a, b)`. The inline helper is simpler and
needs no new dependency — preferred.)*

---

## File 2 — `dictionary_info.dart` → ThemeExtension (Option B, chosen)

This is the largest change. The colour leaves the domain entirely and becomes a
proper **design token** via a `ThemeExtension`, matching the existing
`AppTypography` / `TextEntryTheme` pattern. Bonus: badges become **theme-aware**
(today `getColor` returns theme-blind `Colors.blue/purple/…` while only the
fallback respected the theme — an inconsistency this fixes).

### 2a. Domain: strip the colour out

```dart
// dictionary_info.dart
// CHANGE: import 'package:flutter/material.dart';
// TO:     import 'package:meta/meta.dart';   // pure Dart, provides @immutable

// DELETE the entire getColor(String dictId, ThemeData theme) method (lines 97-114).
```

`DictionaryInfo` now holds only pure data (`id`, `name`, `abbreviation`,
`targetLanguage`, the `all` map, and the `getById` / `getDisplayName` /
`getAbbreviation` lookups). Flutter-free.

### 2b. `app_colors.dart`: add the raw badge palette per theme

Following the existing convention (each theme class holds its raw `Color`
constants), add a badge group to each of `LightThemeColors`, `DarkThemeColors`,
`WarmThemeColors`. Values can start identical to today's and be tuned per theme
later:

```dart
// inside LightThemeColors (repeat with tuned values in Dark/Warm)
// ---- Dictionary badge tokens (app-specific) ----
static const dictDpd = Color(0xFF1E88E5);          // was Colors.blue
static const dictPts = Color(0xFF8E24AA);          // was Colors.purple
static const dictBuddhadatta = Color(0xFF43A047);  // BUS/BUE (was Colors.green)
static const dictSumangala = Color(0xFF00897B);    // MS (was Colors.teal)
static const dictVri = Color(0xFFFB8C00);          // was Colors.orange
static const dictCritical = Color(0xFFE53935);     // CR (was Colors.red)
static const dictDpdc = Color(0xFF3949AB);         // was Colors.indigo
static const dictNyanatiloka = Color(0xFF6D4C41);  // ND (was Colors.brown)
static const dictProperNames = Color(0xFFFFB300);  // PN (was Colors.amber)
```

### 2c. New file: `core/theme/dictionary_badge_theme.dart`

```dart
import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Semantic colour tokens for dictionary badges, attached to [ThemeData] so
/// each theme (light/dark/warm) can tune them and they lerp on theme switch.
/// Lives in the theme layer — keeps `DictionaryInfo` (domain) Flutter-free.
@immutable
class DictionaryBadgeColors extends ThemeExtension<DictionaryBadgeColors> {
  final Color dpd, pts, buddhadatta, sumangala, vri, critical, dpdc,
      nyanatiloka, properNames;

  const DictionaryBadgeColors({
    required this.dpd,
    required this.pts,
    required this.buddhadatta,
    required this.sumangala,
    required this.vri,
    required this.critical,
    required this.dpdc,
    required this.nyanatiloka,
    required this.properNames,
  });

  /// The id→colour mapping lives here (theme layer), not in domain.
  /// [fallback] is the caller's theme-aware default (e.g. colorScheme.primary).
  Color colorFor(String dictId, Color fallback) => switch (dictId) {
        'DPD' => dpd,
        'PTS' => pts,
        'BUS' || 'BUE' => buddhadatta,
        'MS' => sumangala,
        'VRI' => vri,
        'CR' => critical,
        'DPDC' => dpdc,
        'ND' => nyanatiloka,
        'PN' => properNames,
        _ => fallback,
      };

  // One factory per theme, reading raw values from app_colors.dart.
  static const light = DictionaryBadgeColors(
    dpd: LightThemeColors.dictDpd,
    pts: LightThemeColors.dictPts,
    buddhadatta: LightThemeColors.dictBuddhadatta,
    sumangala: LightThemeColors.dictSumangala,
    vri: LightThemeColors.dictVri,
    critical: LightThemeColors.dictCritical,
    dpdc: LightThemeColors.dictDpdc,
    nyanatiloka: LightThemeColors.dictNyanatiloka,
    properNames: LightThemeColors.dictProperNames,
  );
  static const dark = DictionaryBadgeColors(/* DarkThemeColors.dict… */);
  static const warm = DictionaryBadgeColors(/* WarmThemeColors.dict… */);

  @override
  DictionaryBadgeColors copyWith({
    Color? dpd, Color? pts, Color? buddhadatta, Color? sumangala, Color? vri,
    Color? critical, Color? dpdc, Color? nyanatiloka, Color? properNames,
  }) =>
      DictionaryBadgeColors(
        dpd: dpd ?? this.dpd,
        pts: pts ?? this.pts,
        buddhadatta: buddhadatta ?? this.buddhadatta,
        sumangala: sumangala ?? this.sumangala,
        vri: vri ?? this.vri,
        critical: critical ?? this.critical,
        dpdc: dpdc ?? this.dpdc,
        nyanatiloka: nyanatiloka ?? this.nyanatiloka,
        properNames: properNames ?? this.properNames,
      );

  @override
  DictionaryBadgeColors lerp(ThemeExtension<DictionaryBadgeColors>? other, double t) {
    if (other is! DictionaryBadgeColors) return this;
    return DictionaryBadgeColors(
      dpd: Color.lerp(dpd, other.dpd, t)!,
      pts: Color.lerp(pts, other.pts, t)!,
      buddhadatta: Color.lerp(buddhadatta, other.buddhadatta, t)!,
      sumangala: Color.lerp(sumangala, other.sumangala, t)!,
      vri: Color.lerp(vri, other.vri, t)!,
      critical: Color.lerp(critical, other.critical, t)!,
      dpdc: Color.lerp(dpdc, other.dpdc, t)!,
      nyanatiloka: Color.lerp(nyanatiloka, other.nyanatiloka, t)!,
      properNames: Color.lerp(properNames, other.properNames, t)!,
    );
  }
}
```

### 2d. `app_theme.dart`: register the extension in all 3 themes

Add to each `extensions: [...]` list (alongside `TextEntryTheme` and
`AppTypography`):

```dart
// light()
extensions: [
  TextEntryTheme.standard(/* … */),
  AppTypography.fromColorScheme(colorScheme, fontScale: fontScale),
  DictionaryBadgeColors.light,   // ← add
],
// dark()  → DictionaryBadgeColors.dark
// warm()  → DictionaryBadgeColors.warm
```
(Import `dictionary_badge_theme.dart` at the top of `app_theme.dart`.)

### 2e. Update the 2 call sites

```dart
// BEFORE: final dictColor = DictionaryInfo.getColor(result.editionId, theme);
// AFTER:
final badges = theme.extension<DictionaryBadgeColors>()!;
final dictColor = badges.colorFor(result.editionId, theme.colorScheme.primary);
```

- `lib/presentation/widgets/search/dictionary_search_result_tile.dart:31`
- `lib/presentation/widgets/dictionary/dictionary_bottom_sheet.dart:580`

> **Web-rewrite bonus:** a `ThemeExtension` of semantic tokens maps almost 1:1
> to CSS custom properties (`--dict-dpd: …`). Doing this now pre-shapes the
> eventual web theme — a "good anyway" move.

---

## File 3 — `search_result_type.dart`  *(move label + delete dead code)*

**Domain shrinks to the pure enum:**

```dart
// search_result_type.dart — no imports
enum SearchResultType { topResults, title, fullText, definition }
```

- Drop the `AppLocalizations` import and the `SearchResultTypeExtension.displayLabel`.
- **Delete `iconName`** — confirmed **unused** anywhere (dead code).

**Move the label into presentation** (l10n preserved — same keys), e.g. add to
the existing `lib/presentation/utils/search_result_labels.dart`:

```dart
String searchResultTypeLabel(SearchResultType type, AppLocalizations l10n) =>
    switch (type) {
      SearchResultType.topResults => l10n.searchTabTopResults,
      SearchResultType.title => l10n.searchTabTitles,
      SearchResultType.fullText => l10n.searchTabFullText,
      SearchResultType.definition => l10n.searchTabDefinitions,
    };
```

**Call sites affected (3, all in one file):**
`lib/presentation/widgets/search/search_results_panel.dart:136, 242, 510` —
change `type.displayLabel(l10n)` → `searchResultTypeLabel(type, l10n)`.

> Trap: `tab_bar_widget.dart` has a *local variable* also named `displayLabel`
> (it's `formatContentLabel(...)`) — unrelated; leave it alone.

---

## File 4 — `search_scope_chip.dart`  *(split data from label + delete dead code)*

**Domain becomes pure data — and the list can now be `const`:**

```dart
// search_scope_chip.dart — no imports
class SearchScopeChip {
  final String id;
  final Set<String> nodeKeys;
  const SearchScopeChip({required this.id, required this.nodeKeys});
}

const List<SearchScopeChip> searchScopeChips = [
  SearchScopeChip(id: 'sutta',        nodeKeys: {'sp'}),
  SearchScopeChip(id: 'vinaya',       nodeKeys: {'vp'}),
  SearchScopeChip(id: 'abhidhamma',   nodeKeys: {'ap'}),
  SearchScopeChip(id: 'commentaries', nodeKeys: {'atta-vp', 'atta-sp', 'atta-ap'}),
  SearchScopeChip(id: 'treatises',    nodeKeys: {'anya'}),
];
```

- **Delete the `SearchScopeChipListX` extension** (`findByNodeKeys`/`findById`/
  `matchesAnyChip`) — confirmed **unused** anywhere (dead code).

**Presentation helper for the label** (l10n preserved):

```dart
// e.g. lib/presentation/utils/scope_chip_labels.dart
String scopeChipLabel(SearchScopeChip chip, AppLocalizations l10n) =>
    switch (chip.id) {
      'sutta' => l10n.scopeSutta,
      'vinaya' => l10n.scopeVinaya,
      'abhidhamma' => l10n.scopeAbhidhamma,
      'commentaries' => l10n.scopeCommentaries,
      'treatises' => l10n.scopeTreatises,
      _ => chip.id,
    };
```

**Call site affected (1):**
`lib/presentation/widgets/search/scope_filter_chips.dart:103` —
change `chip.label(context)` → `scopeChipLabel(chip, l10n)`
(`l10n` is already in scope there; it uses `l10n.scopeAll` just above).

---

## Bonus dead-code removed along the way
- `SearchResultType.iconName` (File 3) — unused.
- `SearchScopeChipListX` extension (File 4) — unused.

---

## Execution order

Independent, so the tree stays compilable after each step. Suggested order:

1. **File 1** (zero ripple) — warm-up.
2. **File 3** (enum + 3 call sites in one file).
3. **File 4** (data/label split + 1 call site).
4. **File 2** (ThemeExtension — most steps; do last so it's a clean, focused change).

---

## Verification

```bash
# 1. Domain is Flutter-free:
grep -rl "package:flutter" lib/domain         # expect 0
grep -rln "AppLocalizations" lib/domain       # expect 0

# 2. Static analysis clean:
flutter analyze

# 3. Smoke test (per global pref, macOS):
#    - dictionary badges still coloured (and now adapt across light/dark/warm)
#    - search tab labels render in EN + SI
#    - scope chips (Sutta/Vinaya/…/Treatises) render in EN + SI
```

---

## Test impact (flagging only — not writing tests here)

Per project convention, production refactors don't auto-generate tests. Two
existing tests *reference* this code and may need a **one-line import/path
update** (no logic change):
- `test/presentation/widgets/scope_filter_chips_test.dart` — asserts
  `searchScopeChips.length == 5` (still true).
- `test/presentation/widgets/common/status_message_view_panels_test.dart` —
  comment referencing the "Titles" label.

If real test changes are needed (e.g. a unit test for `colorFor` or the label
helpers), that's a job for the test-writer agent.

---

## Effort & risk

| | |
|---|---|
| Effort | ~½ day total (File 2 is ~⅔ of it) |
| Risk | Low — mechanical relocation, no behaviour change |
| New files | `core/theme/dictionary_badge_theme.dart`, `presentation/utils/scope_chip_labels.dart` (+ optional `search_result_type_labels` or fold into `search_result_labels.dart`) |
| Touched call sites | 6 total (2 colour, 3 result-type, 1 scope chip) |

---

## Explicitly out of scope for Phase 1
(Tracked in the parent audit doc — do **not** pull these in here.)
- Completing/removing the vestigial use-case layer (§2.5).
- Moving the 2 Riverpod providers out of `core/` (§2.1).
- Any package extraction (`wisdom_domain` / `wisdom_text`) — that's **Jaspr-only**
  Phase 2A; pointless if the web target is Next.js.
- Pushing client-only logic into the server — that's **Next.js-only** Phase 2B.

→ After Phase 1, the framework decision (Jaspr vs Next.js) gates which Phase 2 we do.
