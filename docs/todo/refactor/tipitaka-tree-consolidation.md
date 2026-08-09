# Refactor — One Tipitaka Tree

> **Status:** Note / **not scheduled**, 2026-08-09. Spun out of the static-site
> breadcrumb review, where `TipitakaTree.parentOf` was added to absorb two
> hand-rolled copies of a parent lookup inside one generator file. That fix was
> local; this note is the general shape behind it. **No app code changed.**
> **Related:** `docs/todo/web-strategy/unified-reading-units-plan.md` (the other
> place the two surfaces were made to agree by moving code into `wisdom_shared`).

---

## 0. TL;DR

`tree.json` is decoded twice, into two unrelated types, and the operations over
it are then re-implemented per call site — six times for "walk to the parent"
alone. Nothing is broken. The cost is that a fix to one copy is invisible to the
others, and the sibling-ordering comparator has *already* had to be copied by
hand between them with a comment begging the two not to drift.

The consolidation is: one decoder, one type, one set of operations, in
`wisdom_shared`. The blocker is not difficulty — it is that the app's type is
Freezed and recursive while the shared one is flat and indexed, so the two
answer navigation questions in different shapes.

---

## 1. What exists today

### Two decoders of the same asset

| | `TipitakaTree` (wisdom_shared) | `TreeLocalDataSourceImpl` (app) |
|---|---|---|
| Reads | `assets/data/tree.json` | the same file |
| Produces | flat `Map<String, TipitakaNode>` + `rootKeys` | recursive `List<TipitakaTreeNode>` with `childNodes` |
| Node type | `TipitakaNode`, plain class | `TipitakaTreeNode`, Freezed |
| Used by | static site generator, corpus tools | every app navigation surface |
| Validates shape | yes — typed `FormatException` per row | no — `data[3][0]` straight into a `RangeError` |

Both walk the same six-field row. Both build a `parentKey → children` map. Both
sort siblings by the trailing integer in the key with document order as the
tiebreak — and that comparator is a **deliberate hand-copy**, flagged in both
files:

> `tree_local_datasource.dart:92` — *"Mirrors `TipitakaTree.fromJson` in
> wisdom_shared, which the static site generator uses; the two surfaces must
> order siblings identically or the same node lands in a different place on
> each."*

That is the duplication already costing something: sibling order is what the
site's prev/next pager and the app's navigator both derive position from, so the
two copies drifting apart is a *silent* wrong-answer bug on 14,752 pages.

### The same index, built twice

`TipitakaTree` holds `Map<String, TipitakaNode> _nodes` from decode. The app
throws that shape away in the datasource, then rebuilds it at runtime in the
presentation layer:

- `navigation_tree_provider.dart:62` — `nodeIndexProvider` walks the whole
  recursive tree to produce `Map<String, TipitakaTreeNode>`, with a comment
  explaining it exists to avoid "an O(N) recursive scan of the whole tree per
  call".

The scan it is avoiding is `TipitakaTreeNode.findDescendantByKey`
(`tipitaka_tree_node.dart:99`), which is what you are left with once the flat
index has been discarded. `scope_operations.dart:314` still calls it, in a loop
over roots, to find *one parent*.

### Six ways to walk to a parent

| Where | Shape |
|---|---|
| `TipitakaTree.ancestorsOf` | the canonical walk (wisdom_shared) |
| `TipitakaTree.parentOf` | one step of it — **added 2026-08-09** |
| `page_template.dart:_parentOf` | *deleted 2026-08-09*, folded into `parentOf` |
| `page_template.dart:_titleText` | *deleted 2026-08-09*, inline copy of the same two steps |
| `site_page.dart:131` | chain walk in a `for` loop (generator) |
| `navigation_tree_provider.dart:132` | `ancestorKeysProvider`, chain walk with a `maxDepth` guard |
| `text_search_repository_impl.dart:673` | `_buildNavigationPath`, chain walk over a `nodeMap` |
| `scope_operations.dart:305` | single step, via a `findDescendantByKey` scan of every root |

The data layer already knows about the presentation-layer copy and says so at
`text_search_repository_impl.dart:661`:

> *"Duplicates parent-walk logic from ancestorKeysProvider (presentation layer).
> Can't share because this data-layer class has no Riverpod Ref. If this grows
> complex, extract to a shared utility in core/utils/tree_utils.dart."*

That comment is the whole ticket, written before this note. The answer it
proposes — `core/utils/tree_utils.dart` — is now the wrong destination: the
utility exists, in `wisdom_shared`, and a third home would make it seven.

Note the guards differ, which is the tell that these are copies rather than one
idea: `ancestorsOf` uses a `seen` set (terminates on any cycle),
`ancestorKeysProvider` uses `maxDepth = 20` (terminates on a *short* cycle,
loops 20 times first), and the other three have no guard at all.

---

## 2. Why it hasn't been done

The two types are not interchangeable, and the difference is structural, not
cosmetic:

- **Recursive vs indexed.** `TipitakaTreeNode` *contains* its children, so a
  node is a subtree and can be handed to a widget whole. `TipitakaNode` holds
  `childKeys` and the tree owns the map, so a node is a record and every
  question goes through the tree. The app's navigator, scope selection and
  `allReadableDescendants` are all written against the first shape.
- **Freezed.** `TipitakaTreeNode` is a Freezed entity with `copyWith` and
  equality that the app relies on inside Riverpod. `wisdom_shared` is
  Flutter-free by design — that is the whole reason the generator can use it —
  so moving Freezed into it is not available.
- **Extra fields.** The app's node carries `hasAudioAvailable` and
  `sinhalaName`; the shared one carries `sinhalaName` but has no audio concept.
- **Nothing is failing.** Both surfaces work. This is a maintenance and
  correctness-under-change cost, not a bug list.

---

## 3. The shape a consolidation would take

Roughly in order of value per unit of risk. Each is independently shippable; none
of them requires the next.

1. **Delete the comparator copy.** Move sibling ordering into `wisdom_shared` as
   one exported function and have `tree_local_datasource.dart` call it. This is
   the change with a real bug behind it and it does not touch either node type.
2. **Delete the app's parent walks.** Three of the four (`ancestorKeysProvider`,
   `_buildNavigationPath`, `collapseToAncestors`) reduce to `ancestorsOf` /
   `parentOf` over a flat index. Doable *without* unifying the types, if the app
   keeps a `TipitakaTree` alongside its recursive one — cheap, since the index is
   already built at `nodeIndexProvider`.
3. **One decoder.** `TreeLocalDataSourceImpl` builds `TipitakaTree` and projects
   the recursive `TipitakaTreeNode` view from it, instead of parsing `tree.json`
   a second time. Gets the app row validation it currently lacks.
4. **One type.** Only worth attempting if the app's reader rework lands first —
   see the reading-units plan. Not recommended on its own.

**Do not start any of this while vagga grouping is in flight.** Both surfaces are
still changing where a node's page *is*, and this refactor changes how they agree
on where a node *sits*. One at a time.

---

## 4. What to check before believing this doc

Every line number above is from 2026-08-09 and will rot. The claims that matter,
restated so they can be re-derived:

- `grep -rn "parentNodeKey" lib/ packages/wisdom_shared/lib static_site_generator/lib`
  should show one walk per surface once step 2 is done. Today it shows six.
- `tree.json` should be `json.decode`d in exactly one place. Today it is two.
- The sibling comparator should appear once. Today it is two hand-synced copies.
