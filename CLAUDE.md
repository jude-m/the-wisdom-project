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

### Generating the FTS Search Database

The full-text search database needs to be generated before running the app:

```bash
# Navigate to tools directory
cd tools

# Install Node.js dependencies (first time only)
npm install

# Generate the FTS database (this will take a few minutes)
npm run generate-fts
# OR
node bjt-fts-populate.js

# The database will be automatically copied to assets/databases/bjt-fts.db
```

**When to regenerate:**
- After cloning the repository (first time setup)
- After updating text files in `assets/text/`
- When the database structure changes

**Database details:**
- Size: ~114 MB (optimized contentless FTS4)
- Entries: ~457,000 searchable text entries
- Suggestions: 100,000 words for auto-complete
- Languages: Pali and Sinhala

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

**Asset Validation**:
- `main.dart` includes a quick startup check for the FTS database
- If database is missing, shows error screen with instructions
- Zero performance impact - only runs if database is actually missing
- Prevents confusing runtime errors when search is used

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
- Node.js: Required for FTS database generation

## Building for Release

**CRITICAL**: The FTS database is required for the app to function but is not committed to git (it's gitignored due to its 114 MB size). Before building a release, you MUST generate the database.

### Pre-Release Validation

**Automated (Recommended):**
```bash
# This script runs all validations, tests, and checks
./tools/validate-release.sh
```

The validation script will:
- ✅ Verify FTS database exists and is valid
- ✅ Run code generation
- ✅ Run Flutter analyzer
- ✅ Check code formatting
- ✅ Run all unit & widget tests
- ✅ Run all integration tests

**Manual Steps (if validation script not available):**
```bash
# 1. Generate FTS database
cd tools && npm run generate-fts && cd ..

# 2. Run code generation
dart run build_runner build --delete-conflicting-outputs

# 3. Run analyzer
flutter analyze

# 4. Run all tests
flutter test
flutter test integration_test/

# 5. Check formatting
dart format lib/ test/ --set-exit-if-changed

# 6. Build
flutter build apk          # Android
flutter build appbundle    # Android App Bundle
flutter build ios          # iOS
flutter build web          # Web
```

### CI/CD Setup

If you use CI/CD (GitHub Actions, GitLab CI, etc.), add these steps BEFORE the Flutter build:

```yaml
# Example for GitHub Actions
- name: Setup Node.js
  uses: actions/setup-node@v3
  with:
    node-version: '18'

- name: Generate FTS Database
  run: |
    cd tools
    npm install
    npm run generate-fts
    cd ..

- name: Run Release Validation
  run: ./tools/validate-release.sh

- name: Build Flutter App
  run: flutter build apk --release
```

The validation script will run all pre-release checks. If any step fails, the CI build will fail, preventing broken releases.

### Release Workflow

1. **Generate database** (if not already present):
   ```bash
   cd tools && npm run generate-fts && cd ..
   ```

2. **Run validation script**:
   ```bash
   ./tools/validate-release.sh
   ```
   This runs all checks: database validation, code generation, analyzer, formatting, and all tests.

3. **Test locally** - Run the app and verify:
   - Navigation works
   - Text content loads
   - Search functionality works (once implemented)
   - No runtime errors

4. **Build** for your target platform:
   ```bash
   flutter build apk          # Android
   flutter build appbundle    # Android App Bundle
   flutter build ios          # iOS
   ```

5. **Verify** the app bundle includes `assets/databases/bjt-fts.db`

The database will be bundled into the final app package during the Flutter build process.

**IMPORTANT**: The validation script will fail if any test fails or the analyzer reports issues. Do not bypass these checks before releasing.

## Before every commit
- Run Flutter Analyzer
- Run all the tests
- Check whether the code is formatted with 2-space indentation
- Check whether the necessary tests are added (integration, unit, widget)
- Do not commit if any of the above fails