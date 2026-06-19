# Simplify dictionary badges → one shared palette (text_entry_theme-structured)

## Context

File 2 just shipped (staged, not committed): `DictionaryBadgeColors` is a
`ThemeExtension` with a **per-theme `.light` factory**, raw `dict*` tokens in
`LightThemeColors`, registered in `AppTheme.light()` only, and **null-safe**
(`?.colorFor(…) ?? primary`) call sites — built to allow per-theme tuning later.

**New decision:** the user no longer wants per-theme badge colours. They want
**one shared palette used by all three themes** — to cut complexity and keep
badge colours consistent regardless of theme — modelled on the structure of
`text_entry_theme.dart`. This **supersedes** the "light-only / append-only
dark-warm" direction from the previous plan.

**What `text_entry_theme.dart` gives us to mirror** (it's theme-*aware*, but its
*structure* is the model):
- a single `.standard(...)` factory (not `.light`/`.dark`/`.warm`);
- a `BuildContext` accessor with a built-in fallback —
  `TextEntryThemeExtension` (`text_entry_theme.dart:262`) returns
  `Theme.of(this).extension<TextEntryTheme>() ?? TextEntryTheme.standard(...)`.
  This makes call sites non-null **by construction** → drop the `?.`/`??`;
- theme-independent constants live **in the extension's own file** (e.g.
  `_paragraphLineHeight` at `text_entry_theme.dart:12`), **not** in
  `app_colors.dart`. Our badge colours are now theme-independent, so they move
  out of `LightThemeColors` and into `dictionary_badge_theme.dart`.

**Outcome:** identical badge pixels (same 9 ARGB), but one palette, colours in
one file, cleaner call sites, and the same shape as the other extensions.

## Steps

### 1. `lib/core/theme/dictionary_badge_theme.dart` — single palette + accessor
- Add the 9 colours as **private file-level consts** at the top (mirrors
  `_paragraphLineHeight` & co.):
  ```dart
  const _dictDpd = Color(0xFF2196F3);          // was Colors.blue
  const _dictPts = Color(0xFF9C27B0);          // was Colors.purple
  const _dictBuddhadatta = Color(0xFF4CAF50);  // BUS/BUE (Colors.green)
  // … sumangala/vri/critical/dpdc/nyanatiloka/properNames
  ```
- Replace the `static const light = …` factory with a single theme-neutral
  factory, matching `TextEntryTheme.standard`:
  ```dart
  factory DictionaryBadgeColors.standard() => const DictionaryBadgeColors(
        dpd: _dictDpd, pts: _dictPts, buddhadatta: _dictBuddhadatta, …);
  ```
- Add the `BuildContext` accessor (mirror of `TextEntryThemeExtension`):
  ```dart
  extension DictionaryBadgeThemeExtension on BuildContext {
    DictionaryBadgeColors get dictionaryBadgeColors =>
        Theme.of(this).extension<DictionaryBadgeColors>() ??
        DictionaryBadgeColors.standard();
  }
  ```
- Keep `colorFor(id, fallback)`, `copyWith`, `lerp` unchanged. Update the
  class doc-comment (drop the "light only / add dark-warm later" note → "one
  shared palette across all themes").

### 2. `lib/core/theme/app_colors.dart` — remove the badge tokens
Delete the whole `// Dictionary badge tokens …` block (the 9 `dictDpd …`
consts) I just added to `LightThemeColors`. They now live in step 1.

### 3. `lib/core/theme/app_theme.dart` — register in all 3 builders
Append `DictionaryBadgeColors.standard()` to the `extensions: [...]` list in
**`light()`, `dark()`, and `warm()`** (same instance everywhere — consistent
with how `TextEntryTheme.standard(...)` / `AppTypography` appear in all three).
The accessor's fallback also covers any theme that forgets it (e.g. bare test
themes).

### 4. Call sites (2) — use the accessor, drop the null-safe dance
Both become a clean one-liner:
```dart
final dictColor =
    context.dictionaryBadgeColors.colorFor(<id>, theme.colorScheme.primary);
```
- `dictionary_search_result_tile.dart` (`<id>` = `result.editionId`)
- `dictionary_bottom_sheet.dart` (`<id>` = `entry.dictionaryId`)

`theme` stays in scope (still used for the `colorScheme.primary` fallback arg).
Remove the now-stale "null-safe …" explanatory comments I added.

### 5. Docs + memory
- `docs/todo/web-rewrite-phase1-domain-flutter-free.md` — update the File 2
  "shipped" note + "what landed" bullet: **one shared `.standard()` palette in
  all 3 themes, colours in `dictionary_badge_theme.dart`, `BuildContext`
  accessor, no per-theme tokens.** (Supersedes the light-only / append-only text.)
- Memory `feedback_theme_tokens_light_only.md` is now partly outdated — update
  it (and its MEMORY.md index line) to: badge colours are a **single shared
  palette** (theme-independent design token); the "light-only, append dark/warm
  later" guidance no longer applies to badges. Keep the general
  null-safe-accessor / "verify which themes are enabled" guidance.

## Alternative considered (not chosen)
A plain class of `static const` colours + a `static colorFor` (no
`ThemeExtension`, no registration) is the absolute least code — but it breaks
consistency with the two existing `ThemeExtension`s (`TextEntryTheme`,
`AppTypography`) and drops the theme-attached / web-CSS-variable framing. Since
the goal is *consistency* with `text_entry_theme`, we keep it a `ThemeExtension`.

## Verification
1. `flutter analyze lib` → **No issues found**.
2. `grep -rl "package:flutter" lib/domain` → **0** (unchanged; domain stays pure).
3. `grep -rn "DictionaryBadgeColors.light\b" lib` → **0** (factory renamed).
4. Smoke test (`flutter run -d macos`, light theme): dictionary search results
   + bottom sheet badges show the same colours as before.
