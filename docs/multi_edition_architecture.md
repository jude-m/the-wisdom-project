# Multi-Edition Architecture

The Wisdom Project supports multiple Tipitaka editions (BJT, SuttaCentral, etc.) through a flexible, scalable architecture.

## Core Principles

1. **BJT JSON files are sacred** - Never modified; all metadata generated at runtime
2. **Edition-agnostic UI** - All editions converge to `TextLayer` for display
3. **N-column flexibility** - Dynamic column layout driven by data, not hardcoded

---

## Entity Hierarchy

```
lib/domain/entities/
├── bjt/                    # BJT-specific (page-based format)
│   ├── bjt_document.dart   # Document with pages
│   ├── bjt_page.dart       # Single page with parallel sections
│   └── bjt_section.dart    # Language-specific section
├── entry.dart              # Universal: Text segment with segmentId
├── edition.dart            # Universal: Edition metadata
├── text_layer.dart         # Universal: Presentation layer for UI
├── reader_pane.dart        # UI concept: Single column
└── reader_tab.dart         # UI concept: Contains multiple panes
```

### Data Flow

```
BJT:    BJT JSON → BJTDocument → TextLayer → UI
SC:     SC JSON → TextLayer (direct) → UI
```

---

## Key Entities

### Entry (Universal)
```dart
Entry(
  entryType: EntryType.paragraph,
  rawText: "Evaṁ me sutaṁ",
  segmentId: "dn-1:bjt:0",  // Generated at runtime, NOT stored in JSON
)
```

### TextLayer (Universal Presentation)
```dart
TextLayer(
  layerId: "dn-1-pi-sinh",   // {fileId}-{lang}-{script}
  editionId: "bjt",
  languageCode: "pi",         // ISO 639-1: 'pi', 'si', 'en'
  scriptCode: "sinh",         // Script: 'sinh', 'latn', 'thai', 'deva'
  segments: [...entries],
)
```

### Edition
```dart
Edition(
  editionId: "bjt",
  displayName: "Buddha Jayanti Tripitaka",
  abbreviation: "BJT",
  type: EditionType.local,
)
```

---

## Multi-Edition Search

### Database Structure
Each edition has its own FTS database: `{editionId}-fts.db`
- `bjt-fts.db` - BJT search index (contentless FTS4)
- `sc-fts.db` - SuttaCentral (future)

### Table Naming
```sql
{edition}_fts         -- FTS virtual table
{edition}_meta        -- Metadata (filename, eind, language, type, level)
{edition}_suggestions -- Word frequency for auto-complete
```

### Search Query
```dart
SearchQuery(
  queryText: "බුද්ධ",
  editionIds: {"bjt", "sc"},  // Search across editions
  searchInPali: true,
  nikayaFilters: ["dn", "mn"],
)
```

### Implementation Files
- `lib/data/datasources/fts_datasource.dart` - Multi-edition FTS search
- `lib/data/repositories/text_search_repository_impl.dart` - Search orchestration
- `lib/domain/entities/search/search_query.dart` - Query with edition filter

---

## Current Status

### ✅ Phase 1 Complete (Foundation)
- [x] `Edition`, `TextLayer`, `ReaderPane` entities
- [x] BJT entities renamed: `BJTDocument`, `BJTPage`, `BJTSection`, `Entry`
- [x] Runtime segment ID generation (format: `{fileId}:bjt:{index}`)
- [x] `TextContent.toTextLayers()` extension
- [x] Multi-edition FTS datasource with parallel search
- [x] Search repository with edition filtering

### 🔜 Phase 2 (Data Layer)
- [ ] SuttaCentral datasource (segment-based JSON → TextLayer direct)
- [ ] Edition registry (available editions configuration)
- [ ] Alignment mapping (BJT segment → SC segment) - optional curation

### 🔮 Phase 3 (UI)
- [ ] PaneProvider (Riverpod state for active panes)
- [ ] MultiPaneReaderWidget consuming `List<TextLayer>`
- [ ] Edition selector UI
- [ ] N-column responsive layout

---

## Script Support

TextLayer supports same Pali text in multiple scripts:
| scriptCode | Display |
|------------|---------|
| `sinh` | සද්ධම්මං |
| `latn` | Saddhammaṁ |
| `thai` | สัทธัมมัง |
| `deva` | सद्धम्मं |

---

## Adding a New Edition

1. **Create FTS database**: `{editionId}-fts.db` with tables `{editionId}_fts`, `{editionId}_meta`, `{editionId}_suggestions`
2. **Create datasource**: If edition is segment-based like SC, return `TextLayer` directly. If page-based, create intermediate model.
3. **Register edition**: Add to edition registry
4. **Update search**: Edition automatically included via `editionIds` parameter

---

## File Reference

| Layer | Key Files |
|-------|-----------|
| Entities | `entry.dart`, `edition.dart`, `text_layer.dart`, `bjt/bjt_document.dart` |
| Data | `fts_datasource.dart`, `bjt_document_local_datasource.dart` |
| Repository | `text_search_repository_impl.dart`, `bjt_document_repository_impl.dart` |
| Providers | `text_content_provider.dart` |
