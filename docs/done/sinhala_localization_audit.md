# Sinhala Localization Audit

**Goal:** Close the gap where Sinhala labels are either (a) not going through the
localization system at all, or (b) translated awkwardly / non-conventionally.

**Scope (agreed):** User-facing UI only. tipitaka.lk term overrides proposed for
approval (nothing existing changes without sign-off). Staged: this audit →
approve → proposed translation table → approve → apply.

---

## Key finding: nothing is *missing* from `app_si.arb`

The EN and SI ARB files have **identical key sets** (~82 keys each). The earlier
impression of a "big gap" came from the EN file's `@key` metadata/description
blocks inflating its line count. Every English key already has a Sinhala value.

So the gap is **two real problems**, not missing keys:

1. **Part 1 — Hardcoded strings** that bypass `AppLocalizations` and therefore
   render English in *both* locales.
2. **Part 2 — Translation quality** of the ~82 existing Sinhala values, where
   tipitaka.lk often has the established/conventional term.

---

## Part 1 — Hardcoded (un-tokenized) strings

### 1a. Token already exists — just not wired up (pure fixes)

| # | Location | Current code | Use existing token |
|---|----------|--------------|--------------------|
| 1 | `lib/presentation/widgets/app/settings_menu_button.dart:242` | `Text('Reset')` (font-size reset) | `l10n.reset` → "යළි සකසන්න" |
| 2 | `lib/presentation/widgets/search/refine_search_dialog.dart:130` | `Text('Error loading tree: $error')` | `l10n.errorLoadingTree` → "සංචාලන ව්‍යූහය පූරණය කිරීමේ දෝෂයකි" |
| 3 | `lib/presentation/widgets/search/search_results_panel.dart:416` | `tooltip: 'Close'` | `l10n.close` → "වසන්න" |
| 4 | `lib/presentation/widgets/dictionary/dictionary_bottom_sheet.dart:396` | `tooltip: 'Close'` | `l10n.close` |
| 5 | `lib/presentation/widgets/search/refine_search_dialog.dart:162` | `tooltip: 'Close'` | `l10n.close` |

> Note on #2: `errorLoadingTree` has no placeholder, so the raw `$error` detail
> would be dropped (recommended — it's developer info; can be logged instead).

### 1b. Needs a NEW token

| # | Location | Current code | Proposed key | EN | SI (to confirm in Part 2) |
|---|----------|--------------|--------------|----|----|
| 6 | `settings_menu_button.dart:129` | `label: Text('Light')` (theme) | `themeLight` | "Light" | (tipitaka.lk / suggest) |
| 7 | `dictionary_bottom_sheet.dart:352` | `tooltip: 'Backspace'` | `backspace` | "Backspace" | (tipitaka.lk / suggest) |

### 1c. Intentionally NOT localized (leave as-is)

| Location | String | Why keep |
|----------|--------|----------|
| `settings_menu_button.dart:271,275` | `'English'`, `'සිංහල'` | Language **endonyms** in the App-Language picker — standard practice; each option is self-labelled so it's findable regardless of current UI language. |
| `settings_menu_button.dart:176,211` | `'A-'`, `'A+'` | Universal typographic symbols for the font-size slider, not words. |

### 1d. Excluded by scope (user-facing-only) — flagged for awareness

| Location | String | Note |
|----------|--------|------|
| `reader_selection_handler.dart:93` | `SnackBar … Text('More options coming soon')` | Dev placeholder for an unimplemented feature. It *is* user-visible. Recommend: localize **or** remove when that feature lands. |
| `settings_menu_button.dart:134,139` | commented-out `'Dark'` / `'Warm'` theme labels | Leave untouched (commented code preserved). Add `themeDark`/`themeWarm` tokens only if/when re-enabled. |

### 1e. To verify (not yet confirmed)

- `lib/core/utils/url_launcher_utils.dart:40,46` — `SnackBar(content: Text(errorMessage))`
  uses an `errorMessage` parameter. Confirm callers pass `l10n.couldNotOpenLink`
  (token exists: "සබැඳිය විවෘත කළ නොහැකිය") and not a hardcoded English string.

---

## Part 2 — Translation quality review (Stage 2)

**Source of authoritative terms:** `Desktop/Dev/tipitaka.lk/src` (Vue, Sinhala-first).
Highest-value files to mine:
`views/Settings.vue`, `views/Dictionary.vue`, `views/TSearch.vue`,
`components/DictionaryFilter.vue`, `components/FilterTree.vue`,
`components/DictionaryResults.vue`, `App.vue`, `constants.js`.

**Process:** for each of the ~82 SI keys, find the matching tipitaka.lk term →
if it differs from ours, flag as an **override candidate** for approval. Where
tipitaka.lk has nothing suitable, propose a Sinhala term (web-search-informed for
dhamma/Pali conventions).

**Already-spotted override candidate (teaser):**

| Key | App now | tipitaka.lk | Note |
|-----|---------|-------------|------|
| `settings` | සැකසීම් | සැකසුම් | Both valid; tipitaka.lk uses සැකසුම්. |

Full table to be produced in Stage 2 and presented for per-term approval.
