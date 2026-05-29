# Memory snapshot — 2026-05-28 21:11

Source: `dart_devtools_2026-05-28_21_11_44.828.csv` (DevTools Memory tab → heap snapshot at a single moment in time)

## Snapshot at a glance

- Classes captured: **130** (project + select packages)
- Total instances: **42,908**
- Total heap (filtered view): **3.36 MB**
- Of that, project-owned classes: **3.21 MB (95.4%)**

> **Caveat — this is one snapshot, not a time-series.** A snapshot tells us *what's in memory right now*, not whether memory grows over time. To detect leaks you need 2+ snapshots taken after equivalent user actions (e.g., snapshot 1 → open & close a sutta 10 times → snapshot 2 → diff). Recommendation at the end.

## Top 8 by size

| Bytes | Instances | Class | File |
|---:|---:|---|---|
| **3,066 KB** | **32,710** | `_$TipitakaTreeNodeImpl` | `domain/entities/navigation/tipitaka_tree_node.dart` |
| 70 KB | 4,481 | `Matrix4` | vector_math |
| 69 KB | 1,476 | `_$EntryImpl` | `domain/entities/content/entry.dart` |
| 62 KB | 562 | `TextEntryWidget` | `presentation/widgets/reader/text_entry_widget.dart` |
| 37 KB | 213 | `ConsumerStatefulElement` | flutter_riverpod |
| 35 KB | 562 | `_AlignedEntry` | `presentation/widgets/reader/dual_column_pane.dart` |
| 26 KB | 1,668 | `Vector3` | vector_math |
| 21 KB | 194 | `_TextEntryWidgetState` | `presentation/widgets/reader/text_entry_widget.dart` |

## Verdict — memory is healthy

- **3.21 MB of project-owned memory is normal** for an app of this complexity. No leaks visible in a single snapshot, and singleton repositories all show exactly 1 instance each (`NavigationTreeRepositoryImpl: 1`, `BJTDocumentRepositoryImpl: 1`, `TextSearchRepositoryImpl: 1`, etc. — what we'd want).
- **No obvious leak candidates** — every class with high instance count has a plausible reason (the tree, vector math, open tabs' rendered widgets).

## Three findings worth noting

### Finding 1 — The Tipitaka tree dominates (intentionally)

`_$TipitakaTreeNodeImpl` accounts for **91% of project memory** with **32,710 instances**. That's the entire Tipitaka navigation hierarchy loaded eagerly into memory at startup.

This is **deliberate, not a leak**:
- Each node is 96 bytes — efficient
- Loaded once via `NavigationTreeRepositoryImpl` (1 instance)
- Keeping the tree in memory lets node expansion / search / breadcrumbs run without DB hits

Why it's worth being aware of:
- **Anywhere that copies, filters, or maps over this tree pays a 32,710-iteration cost.** That's a candidate for the spikes we saw in tree-view scenarios — opening or filtering the tree.
- Any future "tree search" or "tree filter" feature should mutate views/indexes, not copy the tree.

### Finding 2 — The smoking gun for tab switching (562 vs 194)

This is the most interesting number in the whole snapshot:

| Class | Instances |
|---|---:|
| `TextEntryWidget` (widget config) | **562** |
| `_TextEntryWidgetState` (mounted state) | **194** |
| `_AlignedEntry` (widget config) | **562** |
| `_AlignedEntryState` (mounted state) | **194** |
| `DualColumnPane` (mounted) | **3** |

**Reading this**:
- 3 dual-column reader panes are currently mounted (likely the active reader stack)
- They have ~194 mounted entry states between them = **~65 visible/recently-visible text entries per pane**
- But there are **562 widget configs**, meaning ~187 *additional* widget configs exist in memory that aren't currently mounted — these are sitting in the build tree from other places (offscreen, parent rebuilds, etc.)

The **3× ratio (562 / 194)** suggests that when the reader rebuilds, it creates ~3× as many widget configs as it actually mounts. This matches the tab-switch spike pattern from the frame data perfectly — **each switch rebuilds ~187 entry widgets per pane × 3 panes = ~561 widgets at once**, which lines up with the ~170ms UI thread spike on tab switch (≈ 0.3ms per widget build, very plausible).

This is **strong evidence** that the tab-switch fix is about **keeping the reader pane alive across switches** rather than rebuilding from scratch.

### Finding 3 — You had 33 open reader tabs

`_TabItem: 33 instances`, `_$ReaderTabImpl: 34 instances` (33 user tabs + 1 likely "currently being added/edited").

33 tabs is a lot. If the tab data model holds anything heavy per tab (cached content, scroll positions, etc.), this compounds the tab-switch cost. Worth checking the size of `ReaderTab` later — at 128 bytes per instance currently (4,352 bytes / 34) it's fine, but if you ever cache parsed content per tab, that grows.

This also means **the user can plausibly accumulate 30+ open tabs in real use** → any per-tab fix needs to scale.

## Things that look healthy and don't need attention

- **Provider counts are reasonable**: 28 `ProviderElement`, 10 `AutoDisposeProviderElement`, 9 `StateNotifierProviderElement` → no provider explosion
- **State objects match expected singletons**: `TabsNotifier: 1`, `ThemeNotifier: 1`, `InPageSearchNotifier: 1`, `SearchStateNotifier: 1`, etc.
- **LRUCache: 3 instances** — matches expected caches in the app (likely search cache, tree node cache, document cache). Healthy.
- **No orphaned screen states**: `_ReaderScreenState: 1`, `_TabBarWidgetState: 1`, `_MyAppState: 1`. If a previous screen wasn't being cleaned up we'd see >1.

## Connecting to the frame-rate findings

The memory data **reinforces** the conclusion from `REPORT-00-SUMMARY.md`:

| Frame finding | Memory data that supports it |
|---|---|
| 170ms tab-switch UI spike | 562 TextEntryWidget configs / 194 states ⇒ ~3× rebuild ratio per switch |
| Tree-view 123ms spike | 32,710 tree nodes — any traversal/copy of the full tree is expensive |
| Sutta-open spike | ~187 entries per pane × 3 = ~562 widgets created when a sutta is rendered |
| Scrolling is clean | Mounted entries (~194) is small — small mounted set = cheap scroll |

The bottleneck story is consistent: **per-entry widget work, multiplied across many entries during specific user actions**.

## Recommended memory follow-ups

> Still no code changes yet — the punch list for when you're ready.

### 1. Take a "before/after" snapshot pair to confirm no leaks

The single snapshot we have can't prove there are no leaks. Workflow:

1. Open app, navigate to reader → **take snapshot A**
2. Open and close 10 different suttas (return to a known state)
3. Force GC: click the trash-can icon in DevTools Memory tab
4. **Take snapshot B**
5. In DevTools, Diff A → B. If `_$EntryImpl` or `TextEntryWidget` counts in B > A, those objects are being retained between sessions — a leak.

This is the actual test for memory health. The current snapshot is just a baseline.

### 2. Check if reader tab limit / eviction exists

With 33 tabs open and per-tab caching possible, what's the upper bound? If a user opens 200 tabs over time, does anything cap it? If the model in `presentation/models/reader_tab.dart` grows with content, this needs a ceiling. Worth confirming when we look at the tab code.

### 3. (Low priority) Defer / chunk tree load

If startup time matters for the desktop app, the 3MB / 32k-node tree might be loadable lazily by section (Tipitaka has clear top-level divisions: Vinaya / Sutta / Abhidhamma + their subnikayas). Only do this if startup is currently slow — it's a real architectural change.

---

## Updated overall picture

Combining frame + memory data, the **top action** is unchanged but now better supported:

**Investigate tab switching first.** The 562:194 widget-to-state ratio is the strongest single signal across all 6 reports that reader panes are being rebuilt unnecessarily on tab switch.

Everything else (tree-view spike, search-then-sutta cost, etc.) is secondary and may share root causes with the tab fix.
