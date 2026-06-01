# Refactor candidate: `tableAlias` / `columnName` params on the SQL clause builders

**Status:** Noted, not actioned — intentionally left as-is for now (2026-06-01).
**Severity:** Cosmetic / mild YAGNI. No correctness impact.

## Where

`packages/wisdom_shared/lib/src/scope/scope_filter_sql.dart`

- `ScopeFilterSql.buildWhereClause(scope, {tableAlias = 'm', columnName = 'filename'})`
- `ScopeFilterSql.buildLanguageClause(language, {tableAlias = 'm', columnName = 'language'})`

(`ScopeFilterService` in `lib/data/services/` just re-exports both for the client.)

## The observation

Both clause builders take `tableAlias` / `columnName` named params with defaults,
but **every call site uses the defaults** — nothing ever passes `'m'` or the column
name explicitly. The flexibility is currently dead.

`buildLanguageClause` was given these params to **match its sibling**
`buildWhereClause`, so the two read as a matched pair. That consistency is the only
reason they're there today.

## Why the params are unused (and stay unused under the current design)

Two architectural facts make the alias/column non-variable:

1. **Editions are searched in separate queries, merged in Dart.**
   `searchFullText` fans out one query *per edition* (`editionIds.map(...)` +
   `Future.wait`), not one combined SQL. Each query joins its meta table with the
   same fixed alias `m` (`JOIN ${editionId}_meta m`). The *table name* varies per
   edition; the *alias* never does, so two `m`s never collide → `tableAlias` is
   never needed.

2. **The meta schema is uniform across editions.**
   The CTE hardcodes the column set `m.id, m.filename, m.eind, m.language, m.type,
   m.level, m.nodeKey`. All editions are normalized into this schema on import, so
   `language` (and `filename`) are fixed contracts the whole query depends on — not
   per-edition variables → `columnName` is never needed.

## When it *would* become useful

Only under a future design change, not from simply adding editions:

- **`tableAlias`** would earn its keep if we ever joined **two editions' meta tables
  in a single SQL statement** (cross-edition `UNION` / self-join needing `m1.language`
  vs `m2.language`). The current fan-out-in-Dart approach deliberately avoids this.
- **`columnName`** would matter only if we **abandoned the uniform meta schema** and
  let editions keep differently-named columns — a bigger (and probably worse) choice
  than normalizing on import.

## What adding PTS / SuttaCentral actually needs (for contrast)

Multi-edition work touches the **value path**, not these params:

- `Edition.availableLanguages` already declares ISO codes (e.g. SuttaCentral → `['pi','en']`).
- `ContentLanguage` needs a new value (e.g. `english`) + `fromIso` mapping for `'en'`.
- `_ftsLanguageFilter` (in `text_search_repository_impl.dart`) maps the toggle to the
  DB language code, which flows through `getLanguageParams` as a bound `?` value.

The genuinely valuable multi-edition asset is that `buildLanguageClause` lives in the
**shared `wisdom_shared` package**, so the language column/value contract
(`m.language`, `'pali'`/`'sinh'`) is single-sourced across the Flutter client and the
Dart server. The two params ride inside that helper but aren't what does the work.

## Recommendation

**Leave as-is.** Removing the params would create an asymmetry with `buildWhereClause`
for no real gain (code is read more than written; a matched pair is easier to follow).
Revisit only if a cross-edition single-query join is ever introduced — at which point
the params are already there and ready.
