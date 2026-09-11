# App Reader: Subtree Units

> **State:** committed 2026-09-08 on `feat/reader-page-units`. Analysis is clean
> and the corpus invariants pass; the ~12 test files it breaks are **not yet
> updated**, and no manual walkthrough has been signed off. The rule itself is
> recorded in the owning doc — `reading-units-and-grouping.md`, Part 4, "The app
> does not adopt the grouping". This file is the plan it was built from and the
> record of what that turned into.

## Context

Phase B2 was built once against the static site's frozen grouping
(`foldedLeafKeys` → `SitePlan.pageOf`), and reverted before it was committed.

B2 made the reader **bounded**: a tab stopped being *"a content file + a scroll
cursor that runs to EOF"* and became *"a unit with an end"*. That is a genuine
win and is kept — tapping a sutta now ends instead of scrolling forever.

But the site's grouping turns a container into `PageKind.toc`, whose range is
only its **preamble** — the title block — and whose body is a list of child
links. Measured on the real tree: **1,106 containers that hold suttas turn into
link lists**, and many of those lists are meaningless. `an-1-10`
අජ්ඣත්තිකවග්ගො listed 25 children labelled `1. 10. 1`, `1. 10. 2`,
`1. 10. 3` …

So the pivot: **keep the boundedness, drop the site's grouping.** The site is
not touched — its grouping exists for SEO and duplicate-content reasons the app
does not have.

**The rule, in one line:** the unit is the node you tapped, bounded by its own
subtree.

- leaf → its own slice → it ends
- container → its preamble + every descendant's text, stopping where the next node *outside* the subtree begins
- container whose subtree crosses content files → the same, bounded to its own file (which is exactly what the app did before, so no regression)

### Decisions taken

| | |
|---|---|
| Multi-file containers (101 nodes: `sp`, `an`, `kn`, `atta-sp`, `ap-pat`, `anya-vm` …) | Text, bounded to its own file. Identical to previous behaviour for these nodes. |
| Short suttas | Open alone. No folding, no `focusKey`. |
| Jump index on container units | None. Text only. |
| Prev / Next | Out of the subtree, to the neighbouring **leaf**. |

### Facts this rests on — measured 2026-09-07, not assumed

- 2,004 containers; **1,903 have their whole subtree in one content file**, 101 do not.
- Container unit size: **median 8 printed pages, p90 44, max 253** — no worse than the old run-to-EOF.
- **0 containers** have a subtree whose only member in its own file is itself, so every unit renders real text. That is why no TOC-links view was built.
- **No content file crosses a real book boundary.** The 7 that appear to are a pitaka root sharing a file with its own first child (`dn-1` holds both `sp` and `dn`). AN cannot run into KN.
- The old reader was already single-file: `fromNode` set `pageStart: node.entryPageIndex`, `loadMorePages` clamped `pageEnd` to `document.pageCount`.

## What was built

### `lib/domain/entities/reader/` (new)

`ReaderUnit` holds the node, its content file and the `SliceRange` it owns —
by value, because it is rebuilt on every tab touch and handed to a `Provider`,
and an unequal-but-identical unit would re-scroll the reader.

`ReaderUnitResolver` is built from `TipitakaTree` alone — **not** `SitePlan`, so
the app stops consuming `foldedLeafKeys` for reading. One depth-first walk at
construction gives reading order, each key's position, subtree sizes and the
leaf list; a subtree is then a contiguous run, so bounding a unit is a slice
rather than a search:

```dart
({TipitakaNode lastNode, TipitakaNode? lastLeaf}) _subtreeEnd(
    TipitakaNode node, String fileId)
```

`lastNode` bounds the unit; `lastLeaf` is where "next" steps off. They differ
only on the 101 multi-file containers — which is what makes `an` (rendering
only `an-1`) hand Next the first sutta of දුකනිපාතො rather than whatever
follows AN. `leafBefore` / `leafAfter` take a node key and answer in that leaf
list. `keyAt` maps a row back to its owning node, for FTS hits.

`DocumentSlice` lays a range over a loaded `BJTDocument`. It exists because a
unit can begin *and end* mid-page, which is the one thing the panes' old "skip
some entries on the first page" could not express. `entriesOn` clamps, because
Pali and Sinhala do not always carry the same number of entries on a page while
the coordinate bounding them is one.

### `ReaderTab`

`nodeKey` is the whole of a tab's identity; the content file and the slice
bounds are derived from it. `contentFileId`, `pageIndex`, `pageStart`,
`pageEnd` and `entryStart` are gone. `landingPageIndex` / `landingEntryIndex`
are **scroll position only** — an FTS hit or a `?e=<page>.<entry>` link says
where inside the unit to stop, never which unit opens — and the reader clears
them the moment it lands, through `TabsNotifier.clearTabLanding`.

`StorageKeys.openTabs` is bumped to `'open_tabs_v2'`: a saved `_v1` tab would
decode into a tab pointing at nothing rather than failing loudly, so the
version is what protects it.

### Providers and widgets

- `reader_unit_provider.dart` (new) — `readerUnitResolverProvider` over `sharedTreeProvider`, plus `neighbourLeafProvider`. Its own file for the reason `navigator_sync_provider` has one: `document_provider` and `tab_provider` both reach it and would otherwise close an import loop.
- `previousReadableNodeProvider` deleted. It keyed on `isReadableContent`, which is `contentFileId != null` — true for every node in the tree, roots included — so "previous" could land the reader on සුත්තපිටක.
- The run-to-end-of-file pagination deleted: `loadMorePagesProvider`, `_loadMorePagesIfNeeded`, `updateActiveTabPagination`, `updateActiveTabPageIndex`, `TabsNotifier.updateTabPage`, and the `activePageIndex`/`Start`/`End`/`EntryStart` providers. The panes were already `ListView.builder`, so this was a *second* lazy layer over Flutter's own.
- In-page search is scoped to the same `DocumentSlice` the panes build from; `_computeSuttaBounds` / `_findNodeWithParent` / `_SuttaBounds` are gone.
- `openTabFromSearchResultProvider` derives the hit's node from its row via `keyAt` rather than trusting `result.nodeKey` (244 rows corpus-wide name an adjacent sibling), and returns the new tab index — a synchronous `activeTabIndexProvider` read after it named the tab the user came *from*, so the FTS highlight landed on the wrong tab.

Everything the page-keyed cut had turned `async` reverted: `openTabFromNodeKeyProvider`
is synchronous again, and `deep_link_provider`, `parallel_text_provider`,
`breadcrumb_widget`, `tree_navigator_widget` and `reader_action_buttons` are
untouched. `openTabFromSearchResultProvider` is the sole async producer.
`SitePlan` stays loaded for the **link codec** only, so a link copied out of the
app still matches the site's URL.

## Finished after the commit

Both are built now. The **tests** — ~12 files and ~122
references to the removed `ReaderTab` fields, which did not compile — were
carried across on 2026-09-10; the shapes that port taught are recorded in the
owning doc, B2. **Next** was wired the same day as a second button in the Mode 1
pill, and the group's one generic action slot became two step slots that own
their icons; the owning doc's B3 has the placement and the narrow-phone clip it
exposed.

## Verification

Done: `build_runner`, `flutter analyze lib packages static_site_generator`
(clean), and a throwaway corpus pass over every node — every one of `FIGURES.treeNodes`
resolves to a unit, none empty, none containing text from outside its own
subtree, none dropping a descendant that lives in its file.

Also `verify_corpus_invariants.dart`, which gained a **section 4** for the one
assumption `unitFor` makes that nothing else enforced: reading order and
coordinate order agree inside every content file. It passes on the shipped
tree, and is the check to re-run at an upstream re-sync.

Still to walk through by hand:

1. **It ends** — tap any sutta. Text stops at the sutta's end; no further content loads on scroll.
2. **The vagga case** — tap `an-1-10` අජ්ඣත්තිකවග්ගො. Title block, then all 25 suttas, ending exactly where vagga 11 begins. This is the regression the pivot exists to fix.
3. **Big folder** — tap අඞ්ගුත්තරනිකායො. Shows the Ekaka-nipāta and ends at the end of `an-1`. Does **not** continue into දුකනිපාතො or KN.
4. **In-page search scope** — open search inside `an-1-10`. Match count covers the whole vagga and nothing outside it. Next/prev match scrolls within the unit.
5. **Prev** — from `an-1-10`, Prev lands on the last sutta of vagga 9, not on vagga 9's title. From a sutta, Prev lands on the sutta before it.
6. **Search hit landing** — search a phrase, open a result. The tab is named after the sutta the matched row actually belongs to, and the view lands on the matched row inside the full unit. Then scroll to the beginning, switch away and back: it stays at the beginning.
7. **Deep link** — `sammaditthi://tipitaka/<key>?e=<page>.<entry>` opens the unit and lands on that row. A site-shaped `<chapter>#<leaf>` link opens the leaf.
8. **Layout switch** — switch pali-only ↔ dual mid-unit; the top-visible entry stays put.
9. **Restart** — quit and relaunch. Tabs restore (old `_v1` tabs are dropped, which is intended).
