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

## Localization
- ARB files: `lib/core/localization/l10n/app_en.arb`, `app_si.arb`
- Access: `AppLocalizations.of(context)`


## DONT
- Create/Update tests unless the user specifically ask you to. Notify the user that tests were not generated. Except for basic changes, a seperate test generator agent will write the tests.

## DO
- Before running `flutter test` ask for user confirmation
- full permission for grep commands in /Users/judemahipalamudali/Desktop/Dev/the-wisdom-project
- full permission to read from tipitaka.lk project
- full permission to proceed with web links provided by the user and general web search