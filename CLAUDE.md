# CLAUDE.md

## Project Overview
The Wisdom Project - a Tipitaka and commentary browsing app with parallel Pali/Sinhala text viewing and hierarchical navigation.

## Architecture Summary
**Clean Architecture** with Riverpod state management:
- `lib/domain/` - Entities (Freezed), repository interfaces, failures (dartz Either)
- `lib/data/` - Repository implementations, datasources, JSON models
- `lib/presentation/` - Screens, widgets, Riverpod providers
- `lib/core/` - Localization (ARB), themes, constants

## Key Patterns
- **Immutability**: All entities use Freezed → regenerate with `dart run build_runner build --delete-conflicting-outputs`
- **Error Handling**: `Either<Failure, T>` return types throughout
- **Text Formatting**: Markers `**bold**`, `__underline__`, `{footnote}` in content
- **Multi-Edition**: Architecture supports multiple content sources (BJT, SuttaCentral) - see `docs/multi_edition_architecture.md`

## Code Style
- **Always use `const`**: Use `const` for constructors, variables, and collections when values are compile-time constants. Avoids `prefer_const_constructors` and `prefer_const_declarations` lint warnings.
- **Keep doc comments to a minimum.** Few lines max saying what it does and why,
  where the why is not obvious. No multi-paragraph essays, no restating the
  code, no worked examples. If a rule is subtle enough to need a long
  explanation, that belongs in a doc under `docs/`, not above the function.

## Localization
- ARB files: `lib/core/localization/l10n/app_en.arb`, `app_si.arb`
- Access: `AppLocalizations.of(context)`

## Static site generator (`static_site_generator/`)
Separate Dart package, no Flutter. Builds the public HTML Tipitaka site.
- Every `?v=` is a content hash from `lib/render/site_assets.dart`. Never add a
  version constant to bump by hand. (`generatorVersion` is provenance, not a
  cache key.)
- Two builds of the same input must produce identical bytes: no timestamps, no
  build ids, no `Map` order reaching the output.
- Every page must work with JavaScript off. `assets/site.js` is the only
  script; it holds no Sinhala and no URLs (those arrive on `data-` attributes)
  and never uses `innerHTML`.
- Which leaves get their own page is **frozen**, not measured. `foldedLeafKeys`
  (`packages/wisdom_shared/lib/src/grouping/grouping_snapshot.dart`) is the
  single source; the build counts no characters to decide a page. Regenerate
  deliberately with `dart run tool/plan_corpus.dart --write-snapshot` and review
  its git diff — one line per sutta whose URL moved. Never hand-edit it.
- **Never write a corpus count in a comment or a doc.** Page counts, node
  counts, file counts, character totals all live in one generated file,
  `static_site_generator/CORPUS_FIGURES.md` (`--write-figures`). Prose cites a
  figure by name — `` `FIGURES.realPages` `` — and carries no digits. Exceptions,
  all deliberate: thresholds in `GroupingPolicy` (inputs, not outputs), layout
  arithmetic in `stylesheet.dart`, external limits, and dated records of a
  measurement taken on a particular day. See `lib/figures/corpus_figures.dart`.


## DONT
- Create/Update tests unless the user specifically ask you to. Notify the user that tests were not generated. Except for basic changes, a seperate test generator agent will write the tests.

## DO
- When writing plans in Plan mode - save the filename with the title of plan instead of a random name and save it in the docs folder.
- Before running `flutter test` ask for confirmation — EXCEPT when the session/work is about modifying tests or test-related code, where you should run the affected tests automatically without asking (default `-d macos` for integration tests).
- full permission for grep commands in /Users/judemahipalamudali/Desktop/Dev/the-wisdom-project
- full permission to read from tipitaka.lk project that in the Dev folder available locally.
- full permission to proceed with web links specifically provided by the user.
- Follow clean architecture principles.
- Ensure the code:
    - Works across all platforms. 
    - Based on standard flutter patterns and best practices.
    - Reuse existing classes and methods wherever possible.
    - Identify and suggest merging any duplicated or overlapping logic
    - Focus on correctness, clarity, and extensibility.

## Misc
- Pali text is in Sinhala script: එවං මෙ සුතං (not "Evam me sutam"); important when generating tests