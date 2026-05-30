# Search Labels & Tree-Lookup — Follow-up Findings

> **Status:** Backlog (not urgent — no correctness bugs)
> **Source:** `/simplify` review of the App Language / Content Language change
> **Date:** 2026-05-30
> **Related:** `docs/todo/app_language_and_content_language_plan.md`

This doc records cleanup/efficiency follow-ups surfaced while reviewing the
App/Content Language split. None are correctness bugs; they are
maintainability + efficiency items deliberately left out of the cleanup pass.

What was **already applied** in that pass (for context):

- Replaced two hand-rolled enum-by-name loops with `values.asNameMap()[value]`
  (`AppLanguage.fromStorage`, `ContentLanguageNotifier._parse`).
- Added `nodeIndexProvider` (a flat `Map<String, TipitakaTreeNode>` built once)
  and made `nodeByKeyProvider` an O(1) lookup instead of an O(N) recursive tree
  walk. This transitively fixed `ancestorKeysProvider` (now O(depth)), which the
  tree, breadcrumbs, and per-tile `searchResultLabels` all depend on.

---

## 1. Search repository still computes labels the UI now discards

**Where:** `lib/data/repositories/text_search_repository_impl.dart`

**What's happening:** The repository computes a display `title`, `subtitle`
(breadcrumb path), and `language` for every result. The new
`searchResultLabels` helper (presentation layer) now **re-derives** the title
and path from the tree node on the client, and the tiles render *those*
(`labels.title` / `labels.path`) — not the repo's values. So for any result
whose node is in the tree (the vast majority), the repo's strings are built and
then thrown away.

**Now-shadowed repo code:**

| Location | What it does | Status |
|---|---|---|
| `_searchTitles` ~line 374–377 | `sinhalaMatched ? sinhalaName : paliName` — picks title by *which name matched the query* | Discarded by tiles |
| `_searchFullText` ~line 494–496 | `match.language == 'sinh' ? … : …` — same query-matched title pick | Discarded by tiles |
| `_buildNavigationPath` ~line 578 | Builds the breadcrumb path **in Pali only** | Discarded by tiles |
| TODO ~line 373 | *"lets get the navigator display language as the preference later"* | **Stale** — decision was made (client-side); comment now misleads |

**Why the old behavior is now wrong:** Previously a result's title followed
whichever language *matched the search* (so searching a Pali word forced a Pali
label even when reading in Sinhala; a Sinhala result could get a Pali-only
path). The new design says **all data labels follow the single Content Language
setting**, re-derived from the tree node — same pipeline as the tree navigator
and breadcrumbs. The client override is correct; it just leaves the repo doing
the old work.

**Do NOT "clean up" these — they are still live:**

- `SearchResult.language` still drives **snippet highlighting** in
  `HighlightedFtsSearchText` (the matched word in the preview text). Keep it.
- `result.title` / `result.subtitle` are the genuine **fallback** when the node
  isn't in the tree — i.e. dictionary results (empty `nodeKey`).
  `searchResultLabels` returns them unchanged in that branch.
- `nodeKey` is load-bearing — the client looks the node up by it.

**Cost:** two sources of truth (repo computes labels, client recomputes them) +
a little double work (the path walk runs at search time *and* again per tile).
Maintainability smell, not a bug.

**Suggested fix (separate change, `/code-review`-style):** In the repo, stop
guessing the title language and stop building the Pali path for tree-backed
results — return them only for the dictionary / off-tree fallback. Keep
`language` for highlighting. Delete the stale TODO.

---

## 2. Tree-lookup reuse / duplication

Inventory of tree traversals related to the new `nodeIndexProvider`:

### ✅ Already fixed for free
- **`ancestorKeysProvider`** (`navigation_tree_provider.dart`) — walks the
  parent chain via `nodeByKeyProvider`, now O(1) per level → whole walk dropped
  from O(depth × N) to O(depth). No further change needed.

### 🟡 Good reuse candidate (could use the new provider)
- **`in_page_search_provider.dart` ~line 478 — `_findNodeWithParent`** — an
  O(N) recursive walk to find a node *and its parent*. With the index this
  becomes two O(1) lookups: `map[nodeKey]` for the node, `map[node.parentNodeKey]`
  for the parent. The class holds a `_ref`, so it **can** call
  `ref.read(nodeIndexProvider)`. The sibling scan that follows
  (`parent.childNodes`) is already cheap and stays. This is the one easy reuse
  win in the presentation layer.

### 🔴 Same map, but can't reach the provider (layering)
- **`text_search_repository_impl.dart` ~line 556 — `_buildNodeMap`** — this is
  **literally the same flat key→node index**, but in the data layer, and it's
  **rebuilt from scratch on every search** (called ~lines 77, 155, 234). It
  cannot use `nodeIndexProvider` because the repository has no Riverpod `Ref`
  (its own TODO ~line 573 admits this). So there are now **two identical index
  implementations** (presentation + data).
  **Proper fix (architectural, own ticket):** host *one* index lower down —
  compute it once when the tree loads and pass it in, or cache `_buildNodeMap`'s
  result instead of rebuilding per search. Not a quick cleanup.

### ⚪ Not applicable (a key→node map wouldn't help)
- **`previousReadableNodeProvider`** (`navigation_tree_provider.dart`) — needs
  *tree order* (depth-first "what comes before X"), which a key map can't
  answer. Leave the DFS.
- **`scope_operations.dart`** (descendants / ancestors-selected set math) —
  domain pure functions, no `Ref`, operate on tree *structure* not key lookups.
- **`navigation_tree_repository_impl.dart` ~line 140 — `indexNode`** — runs once
  at tree construction, not a hot lookup. (Natural home if a single canonical
  index is ever consolidated.)

---

## Suggested priority

1. **(small)** Reuse `nodeIndexProvider` in
   `in_page_search_provider._findNodeWithParent` — quick, contained.
2. **(medium)** Simplify the search repo to stop computing discarded
   title/subtitle for tree-backed results; remove the stale TODO (item 1).
3. **(larger, optional)** Consolidate the duplicated flat node index into one
   shared layer so the repo doesn't rebuild it per search (item 2 🔴).
