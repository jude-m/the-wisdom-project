# Refactor candidate: purge `AppLocalizations` from the domain layer

**Status:** Noted, not actioned — deferred deliberately (2026-06-01).
**Severity:** Architectural wrinkle. No correctness or runtime impact.

## Where

Exactly **two** domain files import the Flutter-side localization type
`AppLocalizations` (verified: `grep -rln app_localizations lib/domain/`):

1. `lib/domain/entities/search/search_result_type.dart`
   - `String displayLabel(AppLocalizations l10n)` on `SearchResultTypeExtension`.
2. `lib/domain/entities/search/search_scope_chip.dart`
   - imports **both** `package:flutter/widgets.dart` *and* `AppLocalizations`.
   - `final String Function(AppLocalizations) getLabel;` field.
   - `String label(BuildContext context)` method.
   - the `searchScopeChips` list literal with inline `getLabel: (l10n) => l10n.scopeSutta`, etc.

## The observation

Clean Architecture says the **domain** layer is the innermost ring: it should not
depend on outer rings (presentation, framework). `AppLocalizations` is generated
Flutter code (`flutter gen-l10n`) and `BuildContext` is a Flutter widget type — both
are squarely *presentation/framework* concerns. Two domain types reaching outward
for them is a dependency-direction inversion.

`search_scope_chip.dart` is the **deeper** offender: it pulls in
`package:flutter/widgets.dart` (for `BuildContext`), so that domain file cannot even
compile without Flutter. `search_result_type.dart` is milder — only the generated
localization class, no widget types.

This is *consistent* today: both search types follow the same "carry a label that
takes `AppLocalizations`" convention. That internal consistency is exactly why we
shouldn't fix only one of them (see "Why do both, or neither").

## Why do it (the case for purification)

1. **Restores the dependency rule.** Domain entities become pure Dart — no Flutter
   import anywhere under `lib/domain/`. The layer can be unit-tested, reused on the
   Dart server (`server/`), or moved into a shared package without dragging Flutter
   along. (`wisdom_shared` already demonstrates the value of framework-free shared
   code — see `scope_filter_clause_param_generality.md`.)
2. **Labels are presentation policy, not domain truth.** *What* result categories
   exist (`topResults`, `title`, `fullText`, `definition`) is domain. *How they read
   to a user in a given locale* is presentation. The enum should own the former; a
   presentation util should own the latter.
3. **Co-location with existing pattern.** `lib/presentation/utils/search_result_labels.dart`
   already houses presentation-side label logic. The localized mappings belong next
   to it, not in the entity.

## Current impact / blast radius (small and contained)

The consumer surface is tiny — this is a low-risk move:

| Type | Localized API | Consumers | Tests touching it |
|---|---|---|---|
| `SearchResultType` | `displayLabel(l10n)` | `search_results_panel.dart` — **3 sites** (tab label, section sub-header, no-results text) | none reference the label method |
| `SearchScopeChip` | `label(context)` + `getLabel` field | `scope_filter_chips.dart` — **1 site** (`chip.label(context)`) | `scope_filter_chips_test.dart` asserts on `length`/`id`/`nodeKeys` only — **not** the label |

No test asserts on either localized label, so behaviour-preserving moves won't break
the suite. Runtime output is identical (same ARB tokens resolved).

## The move (both types, one convention)

### 1. `SearchResultType` (the easy half)

- **Domain** `search_result_type.dart`: delete the `import` of `app_localizations.dart`
  and the `displayLabel` method. What remains is a pure enum + the `iconName` getter
  (plain strings, no Flutter).
- **Presentation** new `lib/presentation/utils/search_result_type_labels.dart`:

  ```dart
  import '../../core/localization/l10n/app_localizations.dart';
  import '../../domain/entities/search/search_result_type.dart';

  /// Localized labels for search result categories. Lives in presentation
  /// because locale wording is a UI concern, not domain truth.
  extension SearchResultTypeLabels on SearchResultType {
    String displayLabel(AppLocalizations l10n) {
      switch (this) {
        case SearchResultType.topResults: return l10n.searchTabTopResults;
        case SearchResultType.title:      return l10n.searchTabTitles;
        case SearchResultType.fullText:   return l10n.searchTabFullText;
        case SearchResultType.definition: return l10n.searchTabDefinitions;
      }
    }
  }
  ```
- **Consumer** `search_results_panel.dart`: add one import for the new util. The 3
  `.displayLabel(...)` call sites stay **byte-for-byte identical** — Dart resolves the
  extension method through the import.

### 2. `SearchScopeChip` (the harder half — why this is the real work)

`SearchScopeChip` is a *class with data* (`id`, `nodeKeys`), not just an enum, and the
`searchScopeChips` list embeds the label closures inline. Purifying it means separating
the **chip data** (domain) from the **label lookup** (presentation). Two shapes to choose:

- **Option α — drop `getLabel`/`label`, key off `id`.** Domain keeps
  `SearchScopeChip { id, nodeKeys }` (no Flutter import at all). Presentation adds a
  `scopeChipLabel(SearchScopeChip chip, AppLocalizations l10n)` that switches on
  `chip.id`. Cleanest domain, but introduces an `id → label` switch that must stay in
  sync with the chip list (a small, localized drift risk — same shape as the one we
  just removed from `SearchResultType`).
- **Option β — keep `getLabel` as injected behaviour, define the list in presentation.**
  Move the `searchScopeChips` literal (with its `(l10n) => l10n.scopeSutta` closures)
  out of domain into a presentation provider/const. Domain keeps a *pure* `SearchScopeChip`
  class with no `AppLocalizations` import; the closures only exist where the list is
  built (presentation). Preserves the injected-function design, no `id` switch.

Option β is the smaller conceptual change and keeps the data-driven feel; Option α gives
the strictly purest domain. Either way, `scope_filter_chips.dart` switches from
`chip.label(context)` to the presentation-side helper.

## Why do both, or neither

Doing **only** `SearchResultType` (the easy half) is the trap. It purifies one file but
leaves `SearchScopeChip` — the *worse* offender — still importing Flutter into domain.
The codebase would then carry **two competing conventions** for the same problem
("search labels"), and a future reader can't tell which is the house pattern. A
half-purified domain is arguably worse than a consistent-but-imperfect one.

So this is an all-or-nothing refactor: migrate **both** types in one PR to land on a
single clean convention ("domain holds the category/chip; presentation holds the
localized label"), or leave both as the current consistent wrinkle.

## What this is *not*

Not a localization PR and not urgent. It was explicitly carved out of the Sinhala
localization work (where `displayLabel` was introduced) to avoid scope creep. The dead
`displayName` getter was already removed under that work (Option A), which eliminated the
only *drift* concern; what's left here is purely the dependency-direction question.

## Recommendation

**Do it as a standalone, deliberate refactor — both types together — when domain purity
is the actual goal of the change.** Until then, leave both as-is: the coupling is
documented, consistent, and has zero runtime/test cost. Prefer **Option β** for
`SearchScopeChip` (smaller change, preserves the injected-label design) paired with the
straightforward `SearchResultType` extension move. Run `flutter analyze` after — the only
realistic failure is a missing import on a consumer, caught instantly.
