# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

The Wisdom Project is a comprehensive Tipitaka and commentary browsing application built with Flutter. It provides parallel Pali and Sinhala text viewing with a hierarchical navigation system.

## Development Commands

### Setup and Dependencies
```bash
# Install/update dependencies
flutter pub get

# Generate code (Freezed models, JSON serialization)
dart run build_runner build --delete-conflicting-outputs

# Watch mode for continuous code generation during development
dart run build_runner watch --delete-conflicting-outputs
```

### Running the Application
```bash
# Run on default device
flutter run

# Run on specific device
flutter devices  # List available devices
flutter run -d <device-id>

# Run with hot reload (default in debug mode)
# Press 'r' for hot reload, 'R' for hot restart
```

### Testing and Quality
```bash
# Run all tests
flutter test

# Run a specific test file
flutter test test/widget_test.dart

# Analyze code for issues
flutter analyze

# Format code
dart format lib/ test/
```

### Building
```bash
# Build for Android
flutter build apk
flutter build appbundle

# Build for iOS
flutter build ios

# Build for Web
flutter build web

# Build for Desktop
flutter build macos
flutter build windows
flutter build linux
```

### Localization
```bash
# Generate localization files (after modifying .arb files)
flutter gen-l10n
```

## Architecture

### Clean Architecture Layers

The codebase follows Clean Architecture principles with clear separation of concerns:

**Domain Layer** (`lib/domain/`):
- **Entities**: Immutable business objects using Freezed
  - `TipitakaTreeNode`: Hierarchical navigation tree nodes with Pali/Sinhala names
  - `TextContent`: Contains pages of actual content
  - `ContentPage`: Single page with parallel Pali/Sinhala sections
  - `ContentSection`: Language-specific section with entries and footnotes
  - `ContentEntry`: Individual text units with type and formatting markers
  - `Failure`: Typed error handling (DataLoadFailure, DataParseFailure, NotFoundFailure, etc.)
- **Repositories**: Abstract interfaces for data access
  - `NavigationTreeRepository`: Load and search the Tipitaka tree structure
  - `TextContentRepository`: Load text content by file ID
- **Usecases**: Business logic (directory exists but empty - implement use cases here)

**Data Layer** (`lib/data/`):
- **Datasources**: Raw data access (empty - implement JSON/file loading here)
- **Models**: Data transfer objects (empty - implement here)
- **Repositories**: Concrete implementations of domain repositories (empty - implement here)

**Presentation Layer** (`lib/presentation/`):
- **Providers**: Riverpod state management (empty - implement here)
- **Screens**: Full-screen UI components (empty - implement here)
- **Widgets**: Reusable UI components (empty - implement here)

**Core Layer** (`lib/core/`):
- **Localization**: ARB files for English and Sinhala (l10n/app_en.arb, l10n/app_si.arb)
- **Theme**: Application theming (empty)
- **Utils**: Shared utilities (empty)
- **Constants**: Application-wide constants (empty)

### Key Architecture Patterns

**Error Handling**:
- Uses `dartz` package for functional error handling with `Either<Failure, Success>`
- All repository methods return `Either<Failure, T>` for explicit error handling
- Typed failures in domain layer for better error categorization

**Immutability**:
- All entities use Freezed for immutable data classes with copyWith, equality, and toString
- Generated code in `*.freezed.dart` files - regenerate after modifying entities

**State Management**:
- Flutter Riverpod (v2.5.0) configured but not yet implemented
- Plan to use providers in `lib/presentation/providers/`

**Content Structure**:
- Tipitaka content organized as a tree with `TipitakaTreeNode`
- Each node has: nodeKey, paliName, sinhalaName, hierarchyLevel, parent/child relationships
- Content nodes have `contentFileId` linking to actual text files
- Text content split into pages → sections (Pali/Sinhala) → entries (paragraphs/headings)

**Text Formatting**:
- Raw content uses markers: `**bold**`, `__underline__`, `{footnote}`
- `ContentEntry.plainText` provides stripped version
- Entry types defined in `EntryType` enum

**Navigation**:
- Dual language support: Pali and Sinhala for navigation labels
- `NavigationLanguage` enum controls tree display language
- `ContentLanguage` enum controls which content to display

**Display Modes**:
- `ColumnDisplayMode` enum: paliOnly, sinhalaOnly, both
- Parallel text viewing supported via ContentPage structure

## Code Generation

This project heavily uses code generation. After modifying any entity with `@freezed` or `@JsonSerializable` annotations:

1. Run `dart run build_runner build --delete-conflicting-outputs`
2. Commit both the source and generated `.freezed.dart` files
3. For active development, use `watch` mode to auto-generate

## Localization Setup

- Localization config: `l10n.yaml`
- ARB files: `lib/core/localization/l10n/app_en.arb` (English) and `app_si.arb` (Sinhala)
- Generated files appear after `flutter gen-l10n` or `flutter run`
- Access via `AppLocalizations.of(context)`

## SDK Requirements

- Dart SDK: >=3.5.2 <4.0.0
- Flutter: Latest stable version recommended
