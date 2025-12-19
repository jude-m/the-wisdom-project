# Project Context: The Wisdom Project

> **Single Source of Truth** — All agents reference this file for current architecture, patterns, and conventions.

## Overview

**The Wisdom Project** is a Tipitaka and commentary browsing app with parallel Pali/Sinhala text viewing and hierarchical navigation. The app supports multiple editions (BJT, SuttaCentral) and full-text search with transliteration.

---

## Architecture

**Clean Architecture** with strict layer separation:

```
┌─────────────────────────────────────┐
│  Presentation Layer                 │
│  - Widgets, Screens                 │
│  - Riverpod Providers               │
│  - StateNotifiers                   │
└──────────────┬──────────────────────┘
               │ depends on
┌──────────────▼──────────────────────┐
│  Domain Layer                       │
│  - Freezed Entities (immutable)     │
│  - Repository Interfaces            │
│  - Use Cases                        │
└──────────────┬──────────────────────┘
               │ implemented by
┌──────────────▼──────────────────────┐
│  Data Layer                         │
│  - Repository Implementations       │
│  - Data Sources (FTS, JSON, Cache)  │
│  - Models & Mappers                 │
└─────────────────────────────────────┘
```

**Key Rule**: Dependencies point INWARD only. Presentation → Domain ← Data.

---

## Tech Stack

| Category | Technology | Version |
|----------|------------|---------|
| **Framework** | Flutter | 3.5.2+ |
| **State Management** | Riverpod | ^2.5.0 |
| **Immutability** | Freezed | ^2.5.0 |
| **Error Handling** | dartz Either | ^0.10.1 |
| **Persistence** | sqflite, SharedPreferences | ^2.3.0, ^2.2.2 |
| **Testing** | flutter_test, mockito, integration_test | — |

---

## Databases

| Database | Purpose | Location |
|----------|---------|----------|
| `bjt-fts.db` | Full-text search (FTS4), sutta metadata | `assets/databases/` |
| SharedPreferences | User settings, recent searches | Device storage |
| **Future**: Supabase | User sync, cloud features | Remote |

### FTS Database Schema
- `bjt_fts` — FTS4 virtual table (contentless)
- `bjt_meta` — Metadata (filename, eind, language, type, level)
- `bjt_suggestions` — Word frequency for autocomplete

---

## Key Patterns

### 1. Repositories with Caching
```dart
// Repository interface (domain layer)
abstract class SuttaRepository {
  Future<Either<Failure, Sutta>> loadSutta(String id);
}

// Implementation with cache (data layer)
class SuttaRepositoryImpl implements SuttaRepository {
  final Map<String, Sutta> _cache = {};
  // ... caching logic
}
```

### 2. StateNotifier for Complex State
```dart
class SearchStateNotifier extends StateNotifier<SearchState> {
  // Debouncing, cancellation, multi-step flows
}
```

### 3. Either for Error Handling
```dart
Future<Either<Failure, T>> methodName() async {
  try {
    return Right(data);
  } catch (e) {
    return Left(Failure.dataLoadFailure(message: e.toString()));
  }
}
```

### 4. Freezed Entities
All domain entities are immutable:
```dart
@freezed
class Sutta with _$Sutta {
  const factory Sutta({...}) = _Sutta;
}
```

---

## Directory Structure

```
lib/
├── core/           # Localization (ARB), themes, constants
├── data/           # Repository impls, datasources, models
├── domain/         # Entities (Freezed), repository interfaces
└── presentation/   # Screens, widgets, providers

test/
├── data/           # Repository & datasource tests
├── domain/         # Use case tests
├── presentation/   # Widget & provider tests
├── helpers/        # Mocks, test data, pump utilities
└── integration_test/

docs/               # Architecture docs, implementation plans
.agent/workflows/   # Agent prompts
```

---

## Code Conventions

| Convention | Rule |
|------------|------|
| **const** | Always use for compile-time constants |
| **Naming** | `camelCase` vars, `PascalCase` classes, `snake_case` files |
| **Riverpod** | `ref.watch` in build, `ref.read` in callbacks |
| **Async** | No `!` operator, proper null-aware operators |
| **Localization** | ARB files in `lib/core/localization/l10n/` |

---

## Testing

| Type | Location | Run Command |
|------|----------|-------------|
| Unit | `test/data/`, `test/domain/` | `flutter test` |
| Widget | `test/presentation/` | `flutter test` |
| Integration | `integration_test/` | `flutter test integration_test/` |

**Current Coverage**: 135+ tests

---

## Pre-Commit Checklist

```bash
flutter analyze         # No lint errors
flutter test            # All tests pass
flutter test integration_test/  # E2E tests pass
dart format lib/ test/  # 2-space indentation
dart run build_runner build --delete-conflicting-outputs  # Regenerate Freezed
```

---

## Multi-Edition Support

Architecture supports multiple Tipitaka editions:
- **BJT** (Buddha Jayanti Tripitaka) — Currently implemented
- **SuttaCentral** — Future integration

Each edition has its own FTS database (`{editionId}-fts.db`) and can be searched in parallel.

---

## Key Documentation

| Document | Purpose |
|----------|---------|
| `docs/multi_edition_architecture.md` | Multi-edition design |
| `docs/search_implementation_plan.md` | Search feature details |
| `docs/test_strategy.md` | Testing approach |
| `docs/theme_implementation_guide.md` | Theming system |
| `CLAUDE.md` | Quick reference for AI assistants |

---

**Last Updated**: 2025-12-19
