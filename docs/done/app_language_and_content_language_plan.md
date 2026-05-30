# App Language & Content Language — Decoupling Plan

> **Status:** Proposed (Phase 1 ready to implement)
> **Author:** design session, 2026-05-30
> **Related:** `docs/multi_edition_architecture.md`

## 1. Problem

Today a single setting — **"Navigation Language"** (`NavigationLanguage { pali, sinhala }`,
`navigationLanguageProvider`) — does one narrow thing (chooses which name the *tree
navigator* and *breadcrumbs* show) but is conceptually muddled. It conflates ideas that
are actually independent.

We are splitting it into **three orthogonal concepts**:

| # | Concept | Controls | Options (now) | Source of options |
|---|---------|----------|---------------|-------------------|
| 1 | **App Language** | All UI chrome (menus, buttons, labels) — pure localization | English, Sinhala | Fixed (the app's supported locales) |
| 2 | **Content Language** | Which *text/translation* shows for data **labels** everywhere except reading panes: tree, breadcrumbs, search results, dialogs, tabs | Pali, Sinhala | **The active edition** (`Edition.availableLanguages`) |
| 3 | **Pali Script** | How Pali is *rendered* (Sinhala script vs Roman) | (deferred) | independent axis |

**Decisions locked with the user:**
- Concept 1 is named **App Language**.
- Concept 2 is named **Content Language**.
- Content Language is stored **globally** and **validated** against the active edition
  (if the saved choice isn't offered by the edition, fall back to the edition's default).
- **App Language defaults to the device locale**, and is only persisted once the user
  explicitly changes it (so it keeps following the device until then).
- Concept 3 (**Pali Script**) is **out of scope for Phase 1**. We only leave a clean
  seam so the future Pali→Roman transliteration library plugs in without rework.
  (Note: `SinglishTransliterator` — romanized-Sinhala *search input* → Sinhala — is
  unrelated and must not be touched.)

## 2. What exists today (findings)

- **Localization is already set up** (`app_en.arb`, `app_si.arb` → generated
  `AppLocalizations`, `generate: true`). But `MaterialApp` sets **no `locale:`**, so the UI
  just follows the device with no user control, and several widgets hardcode English
  (e.g. the whole settings menu: `'Theme'`, `'Font Size'`, `'Navigation Language'`).
- Each `TipitakaTreeNode` stores **two Sinhala-script fields**:
  `paliName` (the Pali word, e.g. `දීඝනිකාය` = Dīghanikāya) and
  `sinhalaName` (a Sinhala *translation*, e.g. `දික් සඟිය` = "the long collection").
  So Concept 2 for BJT is literally `pali → paliName`, `sinhala → sinhalaName`.
- `applyConjunctConsonants` / `.withPaliConjuncts` is a **Sinhala-script rendering
  refinement** (ZWJ ligatures) — *not* romanization. It must be applied **only to Pali
  content shown in Sinhala script**, never to Sinhala translations.
- The **`Edition` entity already has `availableLanguages: List<String>`** (ISO codes
  `'pi'`, `'si'`, `'en'`). Perfect hook for edition-driven Content Language options.
- **Search** (`text_search_repository_impl.dart`) already computes both `paliName` and
  `sinhalaName`, sets `SearchResult.language = 'pali' | 'sinhala'`, and has a TODO:
  *"lets get the navigator display language as the preference later."* This is exactly
  what we'll wire.
- `KeyValueStore` (injected via `keyValueStoreProvider`, ready by the time providers
  build) has **synchronous** `getString` — so new notifiers can load in their constructor.
- `StorageKeys` centralises persistence keys with a `_v1` suffix convention.
- Surfaces that render node names: tree navigator, breadcrumbs, **search result tiles**
  (`search_results_panel`, `grouped_fts_tile`, title tiles), **refine-search dialog**
  (currently hardcodes Sinhala, ignores the setting), and **tabs** (`tab_bar_widget`;
  `ReaderTab` stores both `paliName` + `sinhalaName`).

## 3. Target architecture

### 3.1 Domain / core

**`AppLanguage`** — new, `lib/core/localization/app_language.dart`:

```dart
import 'package:flutter/widgets.dart' show Locale;

/// The user's preferred UI language (pure localization; Concept 1).
enum AppLanguage {
  english,
  sinhala;

  /// The Flutter [Locale] this maps to (matches MaterialApp.supportedLocales).
  Locale get locale => switch (this) {
        AppLanguage.english => const Locale('en'),
        AppLanguage.sinhala => const Locale('si'),
      };

  /// Resolve a device/platform locale to a supported AppLanguage.
  /// Anything that isn't Sinhala falls back to English.
  static AppLanguage fromLocale(Locale locale) =>
      locale.languageCode == 'si' ? AppLanguage.sinhala : AppLanguage.english;

  /// Parse a persisted value (enum name). Returns null if absent/unknown.
  static AppLanguage? fromStorage(String? value) {
    for (final v in AppLanguage.values) {
      if (v.name == value) return v;
    }
    return null;
  }
}
```

**`ContentLanguage`** — rename of `NavigationLanguage`, moved to
`lib/domain/entities/content/content_language.dart` (it's edition content, not just nav):

```dart
/// A language a text/label can be *displayed* in (Concept 2).
/// The set offered to the user is edition-driven (see availableContentLanguagesProvider).
enum ContentLanguage {
  pali,
  sinhala;
  // Phase 2+: english (SuttaCentral)

  /// ISO 639-1 code — used to match against Edition.availableLanguages.
  String get isoCode => switch (this) {
        ContentLanguage.pali => 'pi',
        ContentLanguage.sinhala => 'si',
      };

  static ContentLanguage? fromIso(String code) => switch (code) {
        'pi' => ContentLanguage.pali,
        'si' => ContentLanguage.sinhala,
        _ => null,
      };
}
```

- `TipitakaTreeNode.getDisplayName(NavigationLanguage)` → `getDisplayName(ContentLanguage)`
  (mechanical; keep the existing empty-string fallback).

**The "one pipeline" display seam** — new, `lib/core/utils/content_text_formatter.dart`:

```dart
import '../../domain/entities/content/content_language.dart';
import 'pali_conjunct_transformer.dart';

/// Single place that turns a raw content string into its display form for the
/// selected [ContentLanguage]. This is the seam the user described ("one
/// pipeline"): today it only applies Pali conjunct ligatures (Pali shown in
/// Sinhala script). When the Pali→Roman transliteration library lands (Phase 2),
/// route the Pali branch through it here based on the selected Pali *script* —
/// no caller needs to change.
String formatContentLabel(String raw, ContentLanguage language) {
  switch (language) {
    case ContentLanguage.pali:
      return raw.withPaliConjuncts; // Sinhala-script Pali → bound letters
    case ContentLanguage.sinhala:
      return raw; // Sinhala translation — conjuncts would corrupt it
  }
}
```

**Edition seam** — add the BJT edition definition + a current-edition provider
(hardcoded for now, structured for a future edition picker):

```dart
// lib/domain/entities/content/editions.dart (or wherever editions are declared)
const bjtEdition = Edition(
  editionId: 'bjt',
  displayName: 'Buddha Jayanti Tripitaka',
  abbreviation: 'BJT',
  type: EditionType.local,
  availableLanguages: ['pi', 'si'], // ← drives Content Language options
);
```

### 3.2 Presentation — providers

**`appLanguageProvider`** — `lib/presentation/providers/app_language_provider.dart`:

```dart
/// Device locale, isolated behind a provider so tests can override it.
final deviceLocaleProvider =
    Provider<Locale>((ref) => PlatformDispatcher.instance.locale);

final appLanguageProvider =
    StateNotifierProvider<AppLanguageNotifier, AppLanguage>((ref) {
  return AppLanguageNotifier(
    store: ref.watch(keyValueStoreProvider),
    deviceLocale: ref.watch(deviceLocaleProvider),
  );
});

class AppLanguageNotifier extends StateNotifier<AppLanguage> {
  AppLanguageNotifier({required KeyValueStore store, required Locale deviceLocale})
      : _store = store,
        super(
          // Saved choice wins; otherwise follow the device locale.
          AppLanguage.fromStorage(store.getString(StorageKeys.appLanguage)) ??
              AppLanguage.fromLocale(deviceLocale),
        );

  final KeyValueStore _store;

  /// Persist only on an explicit user change (so absent = keep following device).
  Future<void> setLanguage(AppLanguage language) async {
    state = language;
    await _store.setString(StorageKeys.appLanguage, language.name);
  }
}
```

**`contentLanguageProvider`** (repurpose `navigationLanguageProvider`) + derived helpers:

```dart
/// Active edition (hardcoded BJT for now; future: a real edition picker).
final currentEditionProvider = Provider<Edition>((ref) => bjtEdition);

/// Content-language options offered by the active edition, in declared order.
final availableContentLanguagesProvider = Provider<List<ContentLanguage>>((ref) {
  final edition = ref.watch(currentEditionProvider);
  return edition.availableLanguages
      .map(ContentLanguage.fromIso)
      .whereType<ContentLanguage>()
      .toList();
});

/// Raw saved preference (may be unsupported by the active edition).
final contentLanguageProvider =
    StateNotifierProvider<ContentLanguageNotifier, ContentLanguage>((ref) {
  return ContentLanguageNotifier(ref.watch(keyValueStoreProvider));
});

/// The value widgets should actually use: the saved choice clamped to what the
/// edition supports, else the edition default (first available). "Global + validated".
final effectiveContentLanguageProvider = Provider<ContentLanguage>((ref) {
  final available = ref.watch(availableContentLanguagesProvider);
  final chosen = ref.watch(contentLanguageProvider);
  if (available.contains(chosen)) return chosen;
  return available.isNotEmpty ? available.first : ContentLanguage.sinhala;
});
```

`ContentLanguageNotifier`: loads from `StorageKeys.contentLanguage` in constructor; if
absent, one-time read of the legacy `'navigation_language'` key (migration), else default
`sinhala`. `setLanguage` persists to the new key.

**`main.dart`:**
- `MaterialApp(locale: ref.watch(appLanguageProvider).locale, ...)` (supportedLocales
  already `[en, si]`).
- Drop the `navigationLanguageProvider.notifier.loadSavedLanguage()` startup call
  (load is now synchronous in the constructor). Theme/Font notifiers are **left as-is**
  (out of scope).

### 3.3 Presentation — apply Content Language to every label surface

All of these watch **`effectiveContentLanguageProvider`** and render via
`formatContentLabel(...)` (which handles the conjunct rule):

1. **`tree_navigator_widget.dart`** — swap provider + use `formatContentLabel`.
2. **`breadcrumb_provider.dart`** — swap provider + use `formatContentLabel`
   (removes the inline `language == pali ? withPaliConjuncts` branch).
3. **`tab_bar_widget.dart`** — compute the displayed label from `tab.paliName` /
   `tab.sinhalaName` via the effective language + `formatContentLabel`, instead of the
   fixed `tab.label` / unconditional `.withPaliConjuncts`. (`ReaderTab` already stores
   both names; `label`/`fullName` stay as persisted fallbacks.)
4. **`refine_search_dialog.dart`** — replace the hardcoded
   `node.sinhalaName.isNotEmpty ? node.sinhalaName : node.paliName` with
   `formatContentLabel(node.getDisplayName(lang), lang)`.
5. **Search results:**
   - **Repository** (`text_search_repository_impl.dart`): thread the effective
     `ContentLanguage` into the title/content search path (via the use case / query).
     Use it to (a) pick the title when both names match — resolving the existing TODO —
     and (b) build the navigation-path subtitle (`_buildNavigationPath`) in that
     language (with fallback). Set `SearchResult.language` to the chosen language.
   - **Tiles** (`search_results_panel.dart`, `grouped_fts_tile.dart`, title tiles):
     apply conjuncts **conditionally on `result.language`** instead of unconditionally —
     i.e. `result.language == 'pali' ? title.withPaliConjuncts : title` (or route the
     title through `formatContentLabel`). The matched **snippet** stays as-is (it's the
     actual Pali search hit, handled by `highlighted_fts_search_text`).
   - The provider that runs the search reads `effectiveContentLanguageProvider` and
     passes it down — keeps the data layer parameterised, not coupled to UI state.

### 3.4 Settings menu (`settings_menu_button.dart`)

Replace the single "Navigation Language" section with **two** sections:
- **App Language** → `SegmentedButton<AppLanguage>` `[English | සිංහල]` →
  `ref.read(appLanguageProvider.notifier).setLanguage(...)`.
- **Content Language** → `SegmentedButton<ContentLanguage>` whose segments are built from
  `availableContentLanguagesProvider` `[Pali | සිංහල]` →
  `ref.read(contentLanguageProvider.notifier).setLanguage(...)`.

While here, localize the section labels that are currently hardcoded (`Theme`,
`Font Size`, etc.) using `AppLocalizations`. Where a literal has no ARB key yet, **fall
back to the existing hardcoded English string** (acceptable per the user).

### 3.5 Localization (ARB)

Add to `app_en.arb` + `app_si.arb` (then run `flutter gen-l10n` / build):

| key | en | si |
|-----|----|----|
| `appLanguage` | App Language | යෙදුම් භාෂාව |
| `contentLanguage` | Content Language | අන්තර්ගත භාෂාව |
| `theme` | Theme | තේමාව |
| `languageEnglish` | English | ඉංග්‍රීසි |

Reuse existing `paliLanguageLabel` ("Pali"/"පාලි") and `sinhalaLanguageLabel`
("Sinhala"/"සිංහල") for the segment labels. The now-unused `navigationLanguage` key can be
left in place (harmless) and removed in a later cleanup.

### 3.6 Persistence (`StorageKeys`)

```dart
static const appLanguage = 'app_language_v1';
static const contentLanguage = 'content_language_v1';
```

Migration: `ContentLanguageNotifier` reads legacy `'navigation_language'` once if the new
key is absent. (App Language has no legacy key — absent simply means "follow device".)

## 4. Phase boundaries

**Phase 1 (this plan):**
- App Language: device default → persist on change → `MaterialApp.locale` → localized UI
  (new keys + obvious existing labels; rest fall back).
- Content Language: rename/repurpose, edition-driven + validated options, applied to
  tree / breadcrumbs / tabs / search / refine dialog.
- Pali Script: **not a setting**. Only the `formatContentLabel` seam is in place.

**Phase 2 (later, library provided):**
- Add **Pali Script** setting (Sinhala / Roman) + transliteration plugged into
  `formatContentLabel`'s Pali branch.
- SuttaCentral edition → `availableLanguages: ['pi', 'en']`, `ContentLanguage.english`.
- (Optional) per-edition Content Language memory.

## 5. Testability (tests NOT written here)

Per project rule, **no tests will be created** as part of implementation — flagging this
explicitly. The design is structured to be easily testable later (by the test-writer
agent):
- `AppLanguage.fromLocale` / `fromStorage` — pure, table-driven.
- `ContentLanguage.fromIso` / `isoCode` — pure.
- `formatContentLabel` — pure (Pali applies conjuncts, Sinhala unchanged). Use Pali text
  in **Sinhala script** for fixtures (e.g. `ධම්ම` → `ධම්‍ම`), per project guidance.
- `effectiveContentLanguageProvider` — override `currentEditionProvider` /
  `contentLanguageProvider`; assert clamp-to-default when the saved value is unsupported.
- `AppLanguageNotifier` — override `deviceLocaleProvider` + a fake `KeyValueStore`;
  assert device default vs persisted override.

## 6. Suggested implementation order (small, reviewable steps)

1. Add `AppLanguage`, `ContentLanguage` (rename), `formatContentLabel`, `StorageKeys`,
   `bjtEdition`. Run build_runner only if any Freezed file changed (none expected).
2. Add `appLanguageProvider` (+ `deviceLocaleProvider`) and wire `MaterialApp.locale`.
3. Repurpose `navigationLanguageProvider` → `contentLanguageProvider` +
   `availableContentLanguagesProvider` + `effectiveContentLanguageProvider`; update
   `main.dart`.
4. Update label surfaces 1–4 (tree, breadcrumb, tabs, refine dialog).
5. Thread Content Language into search (repo + tiles).
6. Settings menu: two controls; ARB additions; `flutter gen-l10n`.
7. Manual verification (run app): toggle App Language (en/si) and Content Language
   (Pali/Sinhala) and confirm scope — labels vs data — behave independently; reading panes
   unaffected.

## 7. Risks / notes

- Renaming `NavigationLanguage` touches ~6 files — mechanical but must be complete.
- `MaterialApp.locale` is global; verify Sinhala/English switch end-to-end.
- Search title language was previously *query-driven* (whichever name matched). It now
  prefers the Content Language; matched-language fallback remains when only one matched.
- Keep `SinglishTransliterator` untouched.
