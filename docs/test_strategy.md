# Testing Strategy

## Overview

This document outlines the automated testing strategy for The Wisdom Project.

## Tools (Official Flutter)

| Tool | Purpose |
|---|---|
| `flutter_test` | Unit & Widget tests |
| `integration_test` | End-to-end tests |
| `mockito` | Mocking dependencies |

## Test Types

### Unit Tests
**Location:** `test/domain/`, `test/data/`  
**Target:** Use Cases, Repositories, Data Sources  
**Run:** `flutter test`

### Widget Tests
**Location:** `test/presentation/`  
**Target:** Individual widgets, Screens  
**Run:** `flutter test`

### Integration Tests
**Location:** `integration_test/`  
**Target:** Full user flows  
**Run:** `flutter test integration_test`

## Testable Units

| Layer | Components |
|---|---|
| Domain | `LoadNavigationTreeUseCase`, `LoadBJTDocumentUseCase` |
| Data | `NavigationTreeRepositoryImpl`, `BJTDocumentRepositoryImpl` |
| Presentation | `TreeNavigatorWidget`, `TabBarWidget`, `MultiPaneReaderWidget` |

## Running Tests

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Generate mocks (after modifying test/helpers/mocks.dart)
dart run build_runner build --delete-conflicting-outputs
```

## CI/CD (Future)

GitHub Actions workflow will be added once the test suite is established.

---

## Implementation Summary

### Test Infrastructure (Phase 1)

Created test helpers in `test/helpers/`:

| File | Purpose |
|---|---|
| `mocks.dart` | Mockito `@GenerateMocks` for repositories and data sources |
| `test_data.dart` | Reusable test fixtures (nodes, documents, failures) |
| `pump_app.dart` | `pumpApp()` extension for Riverpod widget testing |

### Test Coverage (Phases 2-4)

| Layer | File | Tests |
|---|---|---|
| Domain | `load_navigation_tree_usecase_test.dart` | 3 |
| Domain | `load_bjt_document_usecase_test.dart` | 4 |
| Data | `navigation_tree_repository_impl_test.dart` | 14 |
| Data | `bjt_document_repository_impl_test.dart` | 11 |
| Presentation | `tree_navigator_widget_test.dart` | 11 |
| Presentation | `tab_bar_widget_test.dart` | 13 |
| Presentation | `multi_pane_reader_widget_test.dart` | 7 |
| Infrastructure | `widget_test.dart` | 2 |
| Integration | `scroll_restoration_test.dart` | 4 |
| **Total** | | **69** |

### Bugs Discovered & Fixed

Testing revealed real bugs in production code:

| Widget | Bug | Fix |
|---|---|---|
| `MultiPaneReaderWidget` | Using `ref.read()` after widget disposed | Removed ref call from `dispose()`, only dispose ScrollController |
| `TabBarWidget` | Tabs not scrollable on desktop/web (mouse drag didn't work) | Added `ScrollConfiguration` with all pointer device types |
| `MultiPaneReaderWidget` | Header Row overflow by 90 pixels | Made page navigation compact (smaller icons, shorter text) |
| `TabBarWidget` | No visual indicator for hidden tabs | Added animated chevron scroll buttons |
| `MultiPaneReaderWidget` + `closeTabProvider` | Closing active tab caused next tab to inherit closed tab's scroll position | Skip saving scroll when transitioning to -1 (tab closing); use -1 intermediate state to force listener to fire |

### Key Patterns Used

- **AAA Pattern**: Arrange-Act-Assert structure in all tests
- **Provider Overrides**: Injecting mock dependencies via Riverpod
- **Mockito**: `when()` for stubbing, `verify()` for interaction testing
- **Either type**: Testing both `Left` (failure) and `Right` (success) paths
