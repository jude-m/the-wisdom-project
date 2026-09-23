# The Wisdom Project - Build Tools

This directory contains build-time tools for The Wisdom Project.

## BJT Database Generator

### Purpose

Builds `bjt.db` for the BJT (Buddha Jayanti Tripitaka) edition: the full-text search index and the page text, in one SQLite file.

### Quick Start

```bash
# Install dependencies (first time only)
npm install

# Generate the BJT database
npm run generate-bjt
```

The database is written to `assets/databases/bjt.db`.

### What It Does

1. **Reads** every JSON text file in `../assets/text/`
2. **Indexes** every entry, Pali and Sinhala, into a contentless FTS5 table
3. **Stores** the page text in `bjt_content`, one zlib blob per page per language
4. **Finalizes** the file for shipping (`db-finalize.js`): 8 KiB pages, no WAL flag, `ANALYZE`

### Why Contentless

The FTS5 index stores no text of its own, so the text is not kept twice. Search reads the index for locations; the text sits beside it in `bjt_content`. The app still reads the JSON until step 8 of `docs/todo/retiring-dart-server/reduce-mobile-size-and-move-to-drift.md`, which also has the sizes and measurements behind this layout.

### When to Regenerate

- After cloning the repository (first time setup)
- After updating text files in `assets/text/`
- After modifying the database schema

### Database Schema

**bjt_fts** (FTS5 virtual table)
- Contentless search index, ranked with bm25()
- Fields: text (searchable)

**bjt_meta** (metadata table)
- id: Integer primary key
- filename: Text file identifier (e.g., "dn-1")
- eind: Entry index (e.g., "0-5" = page 0, entry 5)
- language: "pali" or "sinh"
- type: Entry type (paragraph, heading, centered, etc.)
- level: Hierarchy level (0-4)
- nodeKey: The tree node the entry belongs to

**bjt_content** (page text)
- filename, pageIndex, language: primary key
- pageNum: The printed page number
- blob: That page's language side from the JSON, verbatim, plain zlib

### Technical Details

- **Technology**: Node.js with better-sqlite3
- **FTS Version**: SQLite FTS5 with unicode61 tokenizer
- **Sinhala Support**: Custom tokenchars for Sinhala Unicode range (U+0D80-0x0DFF)

### Troubleshooting

**"better-sqlite3 not installed"**
```bash
npm install
```

**"Input folder not found"**
Make sure you're running from the `tools/` directory and that `../assets/text/` exists.

**Database not appearing in assets/databases/**
Check that the script completed without errors. It writes the database there directly.

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

- `bjt-populate.js` - Database generation script (writes `../assets/databases/bjt.db`, gitignored)
- `package.json` - Node.js dependencies
- `validate-release.sh` - Pre-release validation script
- `README.md` - This file

### Credits

Based on the FTS population script from [tipitaka.lk](https://github.com/pathnirvana/tipitaka.lk), adapted for The Wisdom Project's multi-edition architecture.
