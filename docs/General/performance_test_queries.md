# Performance Testing Queries: FTS4 vs FTS5

## Test Setup
- Database: bjt-fts.db
- Test search term: "buddha" (common word for meaningful results)
- Test with and without scope filter
- Test with LIMIT and OFFSET for pagination

---

## FTS4 Query (Previous Version - Commit c46e475)

### Basic Search (No Scope Filter)
```sql
-- FTS4: Simple search with pagination
SELECT m.id, m.filename, m.eind, m.language, m.type, m.level
FROM bjt_fts t
JOIN bjt_meta m ON t.rowid = m.id
WHERE bjt_fts MATCH 'buddha*'
LIMIT 50 OFFSET 0;
```

### With Scope Filter (e.g., Digha Nikaya only)
```sql
-- FTS4: Search within scope (nodeKey starts with 'dn')
SELECT m.id, m.filename, m.eind, m.language, m.type, m.level
FROM bjt_fts t
JOIN bjt_meta m ON t.rowid = m.id
WHERE bjt_fts MATCH 'buddha*'
  AND (m.nodeKey = 'dn' OR m.nodeKey LIKE 'dn-%')
LIMIT 50 OFFSET 0;
```

### Phrase Search (Exact)
```sql
-- FTS4: Exact phrase search
SELECT m.id, m.filename, m.eind, m.language, m.type, m.level
FROM bjt_fts t
JOIN bjt_meta m ON t.rowid = m.id
WHERE bjt_fts MATCH '"සති* ධම්​ම*"'
LIMIT 50 OFFSET 0;
```

### Proximity Search (NEAR operator)
```sql
-- FTS4: Words within 10 tokens
SELECT m.id, m.filename, m.eind, m.language, m.type, m.level
FROM bjt_fts t
JOIN bjt_meta m ON t.rowid = m.id
WHERE bjt_fts MATCH 'සති* NEAR/100 ධම්​ම*'
LIMIT 50 OFFSET 0;
```

---

## FTS5 Query (Current Version - Commit 996d816)

### Basic Search (No Scope Filter) - WITH BM25 RANKING
```sql
-- FTS5: Search with BM25 ranking using CTE
WITH ranked AS (
  SELECT
    m.id, m.filename, m.eind, m.language, m.type, m.level, m.nodeKey,
    bm25(bjt_fts) AS score
  FROM bjt_fts
  JOIN bjt_meta m ON bjt_fts.rowid = m.id
  WHERE bjt_fts MATCH 'buddha*'
)
SELECT * FROM ranked ORDER BY score LIMIT 50 OFFSET 0;
```

### With Scope Filter (e.g., Digha Nikaya only) - WITH BM25 RANKING
```sql
-- FTS5: Search within scope with BM25 ranking
WITH ranked AS (
  SELECT
    m.id, m.filename, m.eind, m.language, m.type, m.level, m.nodeKey,
    bm25(bjt_fts) AS score
  FROM bjt_fts
  JOIN bjt_meta m ON bjt_fts.rowid = m.id
  WHERE bjt_fts MATCH 'buddha*'
    AND (m.nodeKey = 'dn' OR m.nodeKey LIKE 'dn-%')
)
SELECT * FROM ranked ORDER BY score LIMIT 50 OFFSET 0;
```

### Phrase Search (Adjacent words with prefix)
```sql
-- FTS5: Adjacent words with prefix matching
WITH ranked AS (
  SELECT
    m.id, m.filename, m.eind, m.language, m.type, m.level, m.nodeKey,
    bm25(bjt_fts) AS score
  FROM bjt_fts
  JOIN bjt_meta m ON bjt_fts.rowid = m.id
  WHERE bjt_fts MATCH 'NEAR(සති* ධම්​ම*, 1)'
)
SELECT * FROM ranked ORDER BY score LIMIT 50 OFFSET 0;
```

### Proximity Search (NEAR operator with BM25)
```sql
-- FTS5: Words within 10 tokens with BM25 ranking
WITH ranked AS (
  SELECT
    m.id, m.filename, m.eind, m.language, m.type, m.level, m.nodeKey,
    bm25(bjt_fts) AS score
  FROM bjt_fts
  JOIN bjt_meta m ON bjt_fts.rowid = m.id
  WHERE bjt_fts MATCH 'NEAR(buddha* dhamma*, 10)'
)
SELECT * FROM ranked ORDER BY score LIMIT 50 OFFSET 0;
```

---

## Performance Testing Script (SQLite CLI)

```bash
# Test FTS4 database (if you have it)
sqlite3 bjt-fts-fts4.db

# Enable timing
.timer ON

# Run queries and compare

# Test FTS5 database (current)
sqlite3 assets/databases/bjt-fts.db

# Enable timing
.timer ON

# Run queries and compare
```

---

## Sinhala Search Examples

### FTS4 - Sinhala Search
```sql
SELECT m.id, m.filename, m.eind, m.language, m.type, m.level
FROM bjt_fts t
JOIN bjt_meta m ON t.rowid = m.id
WHERE bjt_fts MATCH 'බුදු*'
LIMIT 50 OFFSET 0;
```

### FTS5 - Sinhala Search with BM25
```sql
WITH ranked AS (
  SELECT
    m.id, m.filename, m.eind, m.language, m.type, m.level, m.nodeKey,
    bm25(bjt_fts) AS score
  FROM bjt_fts
  JOIN bjt_meta m ON bjt_fts.rowid = m.id
  WHERE bjt_fts MATCH 'බුදු*'
)
SELECT * FROM ranked ORDER BY score LIMIT 50 OFFSET 0;
```

---

## Key Differences

1. **FTS4**:
   - No BM25 ranking
   - Results in undefined order (insertion order typically)
   - Slightly simpler query structure
   - No nodeKey in metadata table

2. **FTS5**:
   - BM25 relevance scoring
   - Results ordered by relevance (best matches first)
   - Uses CTE for proper bm25() context
   - nodeKey stored in metadata for O(1) sutta lookup
   - More complex query structure but better results

## Performance Metrics to Compare

1. **Query execution time** - Which is faster?
2. **Result quality** - Which returns more relevant results first?
3. **Memory usage** - Any difference in peak memory?
4. **Database size** - Already known (~114MB FTS4, ~110-120MB FTS5)
5. **Complex queries** - How do NEAR and phrase searches compare?
