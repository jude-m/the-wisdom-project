# The Wisdom Project - Build Tools

This directory contains build-time tools for The Wisdom Project.

## FTS Database Generator

### Purpose

Generates an optimized SQLite FTS4 (Full-Text Search) database from the BJT (Buddha Jayanti Tripitaka) text files.

### Quick Start

```bash
# Install dependencies (first time only)
npm install

# Generate the FTS database
npm run generate-fts
```

The database will be automatically created at `assets/databases/bjt-fts.db` (~114 MB).

### What It Does

1. **Reads** all 285 JSON text files from `../assets/text/`
2. **Indexes** ~457,000 text entries (Pali and Sinhala)
3. **Generates** 100,000 word suggestions for auto-complete
4. **Creates** optimized contentless FTS4 database (75% smaller than standard FTS4)
5. **Copies** the database to `assets/databases/bjt-fts.db`

### Database Optimization

The script uses a "contentless" FTS4 approach:

- **Standard FTS4**: Stores text + index = 455 MB
- **Contentless FTS4**: Stores only index + metadata = 114 MB

This works because the actual text is already stored in the JSON files. The database only needs the search index and location metadata (filename, page, entry index).

### When to Regenerate

- After cloning the repository (first time setup)
- After updating text files in `assets/text/`
- After modifying the database schema

### Database Schema

**bjt_fts** (FTS4 virtual table)
- Contentless search index
- Fields: text (searchable)

**bjt_meta** (metadata table)
- id: Integer primary key
- filename: Text file identifier (e.g., "dn-1")
- eind: Entry index (e.g., "0-5" = page 0, entry 5)
- language: "pali" or "sinh"
- type: Entry type (paragraph, heading, centered, etc.)
- level: Hierarchy level (0-4)

**bjt_suggestions** (auto-complete)
- word: Suggestion text
- language: "pali" or "sinh"
- frequency: Word occurrence count

### Technical Details

- **Technology**: Node.js with better-sqlite3
- **FTS Version**: SQLite FTS4 with unicode61 tokenizer
- **Sinhala Support**: Custom tokenchars for Sinhala Unicode range (U+0D80-0x0DFF)
- **Performance**: ~4ms search time across 457K entries

### Troubleshooting

**"better-sqlite3 not installed"**
```bash
npm install
```

**"Input folder not found"**
Make sure you're running from the `tools/` directory and that `../assets/text/` exists.

**Database not appearing in assets/databases/**
Check that the script completed without errors. The database should be automatically copied.

---

## Release Validation Script

### Purpose

The `validate-release.sh` script runs comprehensive pre-release checks to ensure your code is ready for production.

### Usage

```bash
./validate-release.sh
```

### What It Checks

1. ✅ **FTS Database** - Exists and is valid size (~114 MB)
2. ✅ **pubspec.yaml** - Includes the database in assets
3. ✅ **Code Generation** - Freezed models are up to date
4. ✅ **Flutter Analyzer** - No issues or warnings
5. ✅ **Code Formatting** - Follows 2-space indentation
6. ✅ **Unit & Widget Tests** - All tests pass
7. ✅ **Integration Tests** - All integration tests pass

If any check fails, the script exits with an error message showing which check failed.

### When to Run

- Before building a release (required)
- Before creating a pull request (recommended)
- In CI/CD pipelines

---

### Files

- `bjt-fts-populate.js` - Database generation script
- `package.json` - Node.js dependencies
- `validate-release.sh` - Pre-release validation script
- `bjt-fts.db` - Generated database (gitignored)
- `README.md` - This file

### Credits

Based on the FTS population script from [tipitaka.lk](https://github.com/pathnirvana/tipitaka.lk), adapted for The Wisdom Project's multi-edition architecture.
