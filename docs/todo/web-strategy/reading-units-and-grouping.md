# Reading units and grouping

> **This document owns the page-count figures.** Every other doc that quotes them points here rather than repeating them — `static-html-site-plan.md` §6/§13.1, `static-html-site-build-plan.md`, `static-web-hosting.md`, `static-site-backlog.md`. The one exception, deliberately: dated phase records in the build plan keep the number that build actually measured.
>
> | | today (shipped) | after rules (a)(b)(c) |
> |---|---:|---:|
> | grouped containers | 146 | **508** |
> | grouped leaves (→ stubs) | 1,603 | **3,580** |
> | real pages | 14,753 | **12,776** |
> | with stubs | 16,356 | **16,356** |
>
> **Status:** rules (a)(b)(c) ready to implement, all classifier-only · the frozen snapshot (Part 2) is ready to build · the app rework (Part 4) is deliberately deferred.
>
> **History.** Merged 2026-08-15 from `unified-reading-units-plan.md` (decided 2026-07-29, reworked 2026-08-09 when the hand-override map was dropped for a frozen snapshot) and `collapse-single-leaf-containers-and-small-vaggas.md` (measured 2026-08-14/15). They were separate documents describing one subject, and they had begun to contradict each other.

---

## The question this document answers

**What is a "document"?** The app and the static site disagree.

- **App:** the unit is the *content file*. `ReaderTab` = `(contentFileId, pageStart, pageEnd, entryStart)`; opening any node jumps to its coordinate and paginates forward one printed page at a time to the end of the file (`lib/presentation/widgets/reader/multi_pane_reader_widget.dart:170`). Three consequences:
  - Every one of the 16,355 tree nodes has a `contentFileId` — including `sp` (සුත්තපිටක → `dn-1`) — so a folder or root tap dumps raw text. The reader has no TOC concept at all.
  - Only `navigateToPreviousSuttaProvider` exists. **There is no "next".**
  - Tab label and breadcrumb never update while scrolling (`_onScroll` touches only `pageStart/entryStart/scrollOffset`), so scrolling from Mūlapariyāya into Sabbāsava leaves the app claiming you are still in Mūlapariyāya.
- **Static site:** the unit is the *page* — `sutta` (own file) · `chapter` (grouped micro-run vagga) · `toc` (container: preamble + links), prev/next walking readable pages only.

**Decisions (2026-07-29):** the app adopts the site's bounded model at **strict parity**; grouped vaggas open in the app as a **chapter scrolled to the anchor**; the app rework is **deferred** until site review settles the vagga grouping; and **no new static/asset files may be added on the app side** — the shared truth is code, not a bundled data file.

### Where a book's opening headings go

The slice rule (a node owns rows from its coordinate up to the start of the next node **of any kind**) puts each heading on the page of the node it names. `an-1.json` page 0:

```
0 centered  සුත්තන්තපිටකෙ      ┐
1 centered  අඞ්ගුත්තරනිකායො     ├─ an        (container) coord (0,0)   → TOC page body
2 centered  පඨමො භාගො           ┘
3 heading   1. එකක නිපාතො       ─ an-1      (container) coord (0,3)   → TOC page body
4 heading   1. චිත්තපරියාදානවග්ගො ┐─ an-1-1   (container) coord (0,4)  → chapter page head
5 centered  නමො තස්ස …           ┘
6 heading   1. 1. 1.            ┐
7 paragraph එවං මෙ සුතං …        ├─ an-1-1-1 (leaf)      coord (0,6)   → its own page
8 paragraph නාහං භික්ඛවෙ …       ┘
```

Nothing is orphaned, nothing renders twice. The site already does this (`sitegen.dart` passes a container's own slice as `preamble`). **In the app these entries currently have no owner** — visible only if you happen to tap the container, and swallowed by the preceding leaf when you scroll past a boundary (1,418 leaves differ under the wrong rule; worst case 204,809 chars on `atta-kn-nett-3-3`). This change gives them a definite home for the first time.

---

# Part 1 — The grouping rules

The base rule, shipped: **group iff the container is a deepest container (all children leaves, all in one content file) with at least `minLeaves`(6) children, none of them `maxLeafChars`(1,500) or longer.** Otherwise explode. Rules (a), (b) and (c) below are additions beside it. **Canon keeps the 1,500 line untouched.**

Every character count in this document is **combined pali+sinh raw characters**, never pali alone — the distinction that `static-html-site-plan.md` §3 still carries a ⚠ about, and that `GroupingVerdict.maxLeafChars` documents in the code.

## What triggered the revision

Three vaggas in sequence under `sn-2-1` (අභිසමයසංයුත්තං) each render as a pile of tiny files that read like they should be one page:

- `sn-2-1-8` සමණබ්‍රාහ්මණවග්ගො
- `sn-2-1-9` අන්තරපෙය්‍යාලො
- `sn-2-1-10` අභිසමයවග්ගො

**No generator bug.** Each fails for a different, correct reason:

| vagga | shape | reason | numbers |
|---|---|---|---|
| `sn-2-1-8` | 11 leaves | `hasSubstantialLeaf` | max **1,788**; whole vagga **4,825** chars |
| `sn-2-1-9` | **0 leaves**, 12 sub-containers | `notDeepest` | never measured |
| `sn-2-1-10` | 11 leaves | `hasSubstantialLeaf` | max **2,227**; whole vagga 16,261 chars |

The one mechanical culprit worth ruling out was checked and cleared: the last leaf of every vagga swallows the colophon + uddāna under the slicing rule, and 53 of 120 near-miss containers do peak at their last leaf. But the mean tail is only **174 chars** and just **9** containers corpus-wide would drop under 1,500 without it. Not worth a rule change.

### `sn-2-1-8` — one template, ten abbreviations

Nine of eleven leaves are ~200-char peyyāla stubs:

```
72. [යෙ හි කෙචි -පෙ-] ජාතිං නප්පජානන්ති -පෙ- [යෙ ච ඛො කෙචි -පෙ- ජාතිං පජානන්ති -පෙ-]
```

It explodes only because leaf 1 (ජරාමරණසුත්තං) is written out in full as the template the rest abbreviate — 1,788 chars, **288 over the line**. Sizes: `1788, 194, 184, 208, 204, 199, 197, 207, 207, 217, 1220`.

The signal the classifier misses is not "max leaf < N". It is **the whole vagga is smaller than one ordinary sutta**.

### `sn-2-1-9` — the one no threshold can reach

Not a vagga. A container of 12 sub-vaggas:

- `sn-2-1-9-1` සත්ථුවග්ගො — 11 leaves, max 1,041 → **already grouped correctly** into one page.
- `sn-2-1-9-2` … `-12` — **11 sub-vaggas holding exactly one leaf each** (ජරාමරණාදීසුත්තානි, 260–911 chars). BJT already collapsed those runs itself.

Each of those 11 burns **two files**: a TOC page whose entire body is one link (3,887 bytes) plus the leaf (6,866 bytes for 355 chars of text). Subtree total today: **24 HTML files for ~4,600 characters.** Blocked by `minLeaves = 6`, not by the char threshold, so moving the threshold does nothing here at any value.

### `sn-2-1-10` — leave it exploded

Eleven suttas averaging 1,478 chars with distinct names (නඛසිඛා, පොක්ඛරණී, පබ්බතූපම …). Four are already over 1,500. The only rule that reaches it is a flat threshold at ≥2,228, which also swallows `an-1-14 එතදග්ගපාළි`, `sn-1-1-1 නළවග්ගො`, `kn-thag-5/6` and a 77-leaf `sn-4-9-2`. **Not worth it.** This vagga stays as it is.

---

## Rule (a) — collapse single-leaf containers

**A container whose only child is a leaf becomes one page instead of two.**

A TOC page holding a single link has no reason to exist. **159** containers corpus-wide. Judgment-free: no threshold, no measurement, no reviewable verdict needed.

It is not a merge of two texts. The container's slice is its preamble (heading, `namo tassa`); the leaf's slice is the text. They already belong on adjacent pages and now share one. The biggest case, `atta-kn-mn-2` → `atta-kn-mn-2-1` at 333,558 chars, **already ships today** as a 996 KB leaf page; the largest file on the site stays `vp-mv-1.html` at 1.37 MB either way. Median single-leaf container's leaf: 1,754 chars. Smallest: 190.

### The BJT structure is untouched — this is a file-count change only

**The container keeps the URL. The leaf loses its file.** That direction is forced, not a preference.

Breadcrumbs and TOC lists are built from the tree, never from the page set — `tree.ancestorsOf(page.nodeKey)` at `page_template.dart:68`, `tree.childrenOf(page.nodeKey)` at `:97`. So the rendered hierarchy is independent of how many files it is spread across, and both levels stay visible on the merged page:

```
breadcrumb  … › ‹ancestors of X›       ← tree.ancestorsOf(X), byte-identical to today's X.html
<h1>        X's name                    ← the container, from the tree
<section id="X-1">
   ‹leaf's heading rows›                ← from the BJT JSON, exactly as its own page renders them
   …text…
```

A **leaf is never anyone's ancestor**, so no breadcrumb anywhere in the site links to `X-1`; removing its file breaks nothing. The reverse — letting the leaf win the URL — would delete `X.html`, and `X` *is* an ancestor, so every page below it would carry a breadcrumb segment pointing at a missing file. Container-wins is the only direction that preserves the structure.

Two knock-on effects, both benign:

- **Pager.** `X` changes from `toc` (not in the chain) to `chapter` (in it), replacing `X-1`. Chain length and reading order are unchanged.
- **Search.** `X-1` becomes a grouped leaf, so its result row links to `X.html#X-1` — the path the other grouped leaves already take.

One cosmetic item: `_chapter` always emits the `සම්පූර්ණ පරිච්ඡේදය` bar, which on a one-section chapter offers a return to a view identical to the one you are in. Suppress it when `page.suttas.length == 1`.

## Rule (b) — group when the whole vagga is small

**`max < 1500` OR `total < 5000`**, both still behind the existing `minLeaves`/`deepest`/`one content file` gates.

Catches `sn-2-1-8` exactly, and pulls in only **8 others** (69 leaves total) — all peyyāla or commentary echo-vaggas:

```
atta-sn-2-6-1   3,397      sn-5-12-10      3,738      atta-sn-5-4-6   4,264
atta-an-5-5-3   4,495      atta-sn-2-1-10  4,502      atta-sn-2-7-2   4,655
atta-an-5-2-5   4,691      sn-2-1-8        4,825      sn-4-1-5        4,917
```

**Why 5,000 and not higher.** It is the largest cap that touches nothing named. `kn-thig-6` (10,247 total — the eight named elder nuns the strict `<` was written to protect), `sn-1-1-1 නළවග්ගො` (9,408) and `an-1-14 එතදග්ගපාළි` (11,062) are all untouched. At 6,000 the list doubles to 20 and starts taking `an-1-13 එකපුග්ගලවග්ගො`; at 8,000 it is 44 containers. The error asymmetry from `GroupingClassifier`'s header still holds — a wrong explode is cheap, a wrong group buries a named text — so this cap stays where nothing named is at risk.

## Rule (c) — raise the line for commentary, not for canon

**`maxLeafChars` becomes 15,000 for `atta-*` and stays 1,500 for canon — except `atta-kn-jat`, `atta-kn-thag` and `atta-kn-thig`, which stay at 1,500 with the canon.**

### Why commentary is different

`maxLeafChars` is an SEO guard: one substantial sutta in a vagga explodes the whole vagga so that sutta keeps its own rankable page. A *vaṇṇanā* does not need that guard. Nobody searches for ජරාසුත්තවණ්ණනා — they search the sutta, whose canonical page already exists and already carries the අට්ඨකථා cross-link.

The generator already treats canon and commentary as different in four places, always the same one-line test (`nodeKey.startsWith(TipitakaNodeKeys.commentary)`):

| where | what it does |
|---|---|
| `node_labels.dart:43` | `carriesCommentaryMarker` — appends අට්ඨකථා to a title |
| `page_template.dart:263-274` | the canon ↔ commentary cross-link |
| `search_index.dart:74-82` | ships that flag as a column — without it **127 commentary results were byte-identical to a canon result** |
| `page_template.dart:186` | canonical URL is always self: *"a commentary and its canon twin are different texts, not duplicates"* |

`search_index.dart` is the precedent that counts: it was changed *because* a vaṇṇanā and its sutta compete for the same searches, and the sutta should win. Rule (c) applies that same judgment to page structure.

### Why 15,000

Page weight is the only hard cost, and it does not bite until 20,000:

| commentary max | real pages | biggest chapter | chapters >100k chars |
|---:|---:|---|---:|
| 1,500 (today) | 14,753 | 24k ch ≈ 72 KB | 0 |
| 6,000 | 13,653 | 49k ≈ 143 KB | 0 |
| 10,000 | 13,199 | 75k ≈ 219 KB | 0 |
| **15,000** | **12,803** | **90k ≈ 264 KB** | **0** |
| 20,000 | 12,523 | 206k ≈ **604 KB** | 1 |
| no gate | 10,162 | 897k ≈ 2.6 MB | 18 |

15,000 is the last value at which **no chapter page exceeds 100k characters** (~3 bytes/char in this corpus, measured against four built pages). For scale, the build already ships `atta-kn-mn-2-1.html` at **996 KB** as a single leaf page, so a 264 KB chapter sets no record.

**20,000 was considered and rejected** — not on weight (604 KB would be the site's 4th largest file, unremarkable) but on consistency. Its extra 253 pages come mostly from `atta-kn-snp-4` (the Aṭṭhakavagga, 16 named suttas), Dhammapada story-commentary, Apadāna and Vimānavatthu — the same "named people and named short texts" category the carve-out below exists to protect. Taking them would make the carve-out a list of three prefixes rather than a principle.

### Why jat / thag / thig are carved back out

Those three commentaries are not subsection prose. Their children are **distinct named people**:

```
atta-kn-thag-4  "4. චතුක්කනිපාතො"        ← twelve named elders
   atta-kn-thag-4-3   13,103  සභියත්ථෙරගාථාවණ්ණනා
   atta-kn-thag-4-8    9,908  රාහුලත්ථෙරගාථාවණ්ණනා
   atta-kn-thag-4-10   9,550  ධම්මිකත්ථෙරගාථාවණ්ණනා
```

The canon side already concedes the point: `kn-thig-6` — the eight elder *nuns* — is the container the strict `<` was written to protect, by a single character. Protecting Therīgāthā in the canon by one char while burying Theragāthā wholesale in the commentary is not a position. Jātaka is the same case for a different reason: there the aṭṭhakathā **is** the story, and the canonical entry is often just the closing verse.

Cost: **32 containers / 319 leaves** stay exploded — about 159 pages against the uncarved figure.

**The carve-out is load-bearing on the canon side too, which is easy to miss.** These same three books are the biggest single block of *already-grouped canon*: `kn-jat-*` (33), `kn-thag-*` (19) and `kn-thig-*` (4) are **56 of today's 146 grouped vaggas**, because BJT's Jātaka pali is only the gāthās and each Theragāthā leaf is one short verse. `static-html-site-plan.md` §13.1 accepted that grouping on one condition — *the searched* **stories** *live in `atta-kn-jat-*`, which explodes* — and today it does (0 of the 146 grouped vaggas are `atta-kn-jat`). Rule (c) without this carve-out would group the commentary too, and the Jātaka stories would then have **no** page of their own on either side. That, not page count, is why these three prefixes cannot be traded away later.

`atta-kn-ap` (Apadāna), `atta-kn-vv` and `atta-kn-pv` are the same argument one step weaker; adding all three costs a further ~150 pages. Left out for now, and the cheapest thing to change if it ever looks wrong.

### One place where grouping is a straight gain

```
atta-mn-1-1-4  "භයභෙරවසුත්තවණ්ණනා"      ← ONE commentary, split into 13 subsections
   atta-mn-1-1-4-1     4,883  කායකම්මන්තවාරකථා
   atta-mn-1-1-4-2    14,955  වචීකම්මන්තවාරාදිවණ්ණනා
   atta-mn-1-1-4-3     8,565  භයභෙරවසෙනාසනාදිවණ්ණනා
```

Today the site has 13 pages holding chunks of the Bhayabherava Sutta commentary and **not one page that is** the Bhayabherava Sutta commentary. After (c), one page is. Where a container is itself a single named work, the rule does not bury a document — it repairs one BJT fragmented. Many of the largest containers (c) recruits are this shape.

### What it costs

**200 commentary containers / 1,791 leaves** grouped. Their largest leaves run 13–15k chars (`atta-kn-khp-9`, `atta-sn-5-1-1`, `atta-ap-yam-7`). Every one keeps its text, its `#fragment` and its search row; what it loses is a standalone URL.

---

## Impact

(a) touches only 1-leaf containers and (b) only ≥6-leaf ones, so those two are additive. (c) overlaps (b) — 22 containers qualify under both — so the total is **not** the sum of the rows.

| rule | grouped containers | leaves swallowed | real pages | with stubs |
|---|---|---|---|---|
| locked (`max<1500`) | 146 | 1,603 | 14,753 | 16,356 |
| + (a) | 305 | 1,762 | 14,594 | 16,356 |
| + (b) | 155 | 1,672 | 14,684 | 16,356 |
| + (c) | 346 | 3,394 | 12,962 | 16,356 |
| + (a) + (b) | 314 | 1,831 | 14,525 | 16,356 |
| **all three** | **508** | **3,580** | **12,776** | **16,356** |

**12,776 real pages** = 12,775 under `/tipitaka/` plus the root `/`. Down **1,977** from today, a 13.4% cut. Biggest chapter page produced: 90,252 chars ≈ 264 KB.

By page kind, which is where the real pages actually go:

| | sutta | chapter | container TOC | root | real pages |
|---|---:|---:|---:|---:|---:|
| today | 12,748 | 146 | 1,858 | 1 | 14,753 |
| all three | **10,771** | **508** | **1,496** | 1 | **12,776** |

Both rows are derived, not counted, from two fixed corpus totals — **14,351 leaves** and **2,004 containers** (`static-web-hosting.md`): sutta = leaves − grouped leaves, chapter = grouped containers, TOC = containers − grouped containers. Any row of the impact table above expands the same way, which is the cheapest check that a new measurement is self-consistent.

**The 16,356 does not move**, and cannot: every leaf gets either a real page or a stub, so `leaves + containers + 1` is invariant to any grouping rule. The P5 stub gate and the Cloudflare file cap are untouched. Only the stub count moves — 1,603 → **3,580**, still inside the Bulk Redirects free 10K quota.

Concretely:

- `sn-2-1-9` subtree: **24 → 13** pages
- `sn-2-1-8`: **12 → 1** page
- `sn-2-1-10`: unchanged at 12 — canon, and it stays exploded on purpose
- `atta-sn-1-1-6` ජරාවග්ගො (max 2,572): **11 → 1** page, via (c)

---

## Deferred — the 42 one-vagga saṃyuttas

Same wart one level up: **42 containers whose only child is another container.** Almost all are saṃyuttas containing exactly one vagga:

```
sn-1-5   භික්ඛුනීසංයුත්තං  → sn-1-5-1   භික්ඛුනීවග්ගො   (10 suttas below)
sn-3-13  ඣානසංයුත්තං      → sn-3-13-1  ඣානවග්ගො       (55 suttas below)
anya     අන්‍ය             → anya-vm    විසුද්ධිමග්ගො    (183 leaves below)
```

The saṃyutta TOC page holds one link, to the vagga TOC page, which then lists the suttas. Two clicks and two files where one would do — worth ~42 pages.

**Why it is not in this change — it breaks the structure, which rule (a) does not.**

Rule (a) removes a **leaf's** file, and a leaf is never anyone's ancestor, so nothing links to it in a breadcrumb. These 42 would remove a **mid-tree container's** file. Whichever of the pair survives, the other stays in `ancestorsOf` for the whole subtree below it while no longer having a page to point at: roughly **634 leaves** sit under these 42, and every one of them would carry a dead breadcrumb segment. That is a change to the navigable BJT hierarchy, not a file-count optimisation.

Two further complications:

- **It chains.** 7 of the 42 run deeper (`atta-sn-3-4 ඔක්කන්තිසංයුත්තං → atta-sn-3-4-1 චක්ඛුවග්ගො → 1 leaf` — three pages for one sutta). Collapsing one level exposes the next, so the rule has to decide how far to run and what the survivor is called.
- **`anya` is in the list.** Its only child is the whole Visuddhimagga (183 leaves). Any rule here needs a root exemption, or a top-level pitaka node disappears.

It also partly solves itself: those 7 deep chains each contain a single-leaf container that rule (a) removes anyway, so the remaining win is under 42 pages once (a) lands. Revisit then, if at all.

---

# Part 2 — Freezing the verdicts

The rules above are re-measured from the text on every run, and the measurement sits on a knife edge. Freeze the verdicts into shared code; demote the classifier to a sync-time advisor.

## Why frozen — the measurement has no safe place to draw a line

Measured 2026-08-08 over all 1,165 measured vaggas, by longest-leaf chars:

```
 1000–1249  ██████████████████████████████ 30       vaggas per 250-char bucket
 1250–1499  ██████████████████████████████████████ 38
 1500–1749  ██████████████████████████████████████ 38   ← the line is here
 1750–1999  ███████████████████████████████████████ 39
 2000–2249  ████████████████████████ 24
```

The line sits in the densest region of the whole distribution — a vagga every ~6.5 chars. Every datapoint from 1448 to 1558:

```
1448 1456 │ 1485 1489 1490 ‖1500‖ 1504 1508 1509 │ 1529 1529 │ 1558
                               └ kn-thig-6 — ON the line; one edited char flips it
```

Candidate placements, all bad:

| line at | drift margin | flips vs today |
|---|---|---|
| 1,500 (today) | 10 down / **0 up** | — (`kn-thig-6` exactly on it) |
| 1,502 (i.e. `<=`) | ±2 | `kn-thig-6` groups; the knife edge is mirrored, not removed |
| 1,520 | ±10 | 4 vaggas / 36 suttas |
| 2,266 (first gap ≥40 chars) | ±20 | **101 vaggas / 1,134 suttas lose their own pages** — voids "famous suttas keep own pages" |

So *any* measured rule stays one resync away from a flip, and the `--expect` lock only converts silent breakage into recurring human decisions. Also rejected:

- **Hand-override map** (this plan's first design): human-curated exceptions bolted onto a live rule — every unlisted vagga stays exposed, and the list only grows.
- **Structural-only rule** (leaf count / tree shape, nothing a typo can move): would group all 1,165 candidates — buries substantial suttas.

**Rule (c) does not escape this** — it moves the commentary line to 15,000, where the nearest datapoint above is `atta-sn-1-8-1` at 15,006, six characters away. What changes is the *stake*: a flip at 1,500 can bury a named sutta, a flip at 15,000 regroups one commentary vagga. Freezing is what makes both safe, and rule (c) is the first exercise of the regenerate path.

**Decision (2026-08-09): stop measuring at build time.** Snapshot the verdicts; a resync may change page *contents*, never page *structure*.

## A1. Generate the snapshot into `wisdom_shared`

`classify_corpus.dart --write-snapshot` emits `packages/wisdom_shared/lib/src/grouping/grouping_snapshot.dart`, exported from `wisdom_shared.dart`:

```dart
/// GENERATED — the vaggas rendered as one chapter page, frozen from the
/// classifier's full-corpus run. Every other container explodes.
/// Regenerating or editing this file is a deliberate act with URL
/// consequences; a resync must never touch it.
const Set<String> groupedVaggaKeys = { 'an-1-1', /* … */ };
```

Generated *code*, not an asset: strict parity means the app must read the same snapshot, the app may gain no new bundled file, and a `const` compiles into both surfaces from one place. Absent key = exploded, which makes new content self-handling: a container the snapshot has never heard of gets a page per sutta — the safe direction (a wrong explode costs thin pages; a wrong group buries named texts). Grouping a *new* micro-run later is a deliberate snapshot edit, never an obligation.

**Regeneration is the supported way to move the cutoff.** The snapshot is always re-derivable from the rule: change the constants, rerun `--write-snapshot`, and the git diff of `grouping_snapshot.dart` *is* the impact review — every key added or removed is one vagga whose URLs change. Freezing removes the *accidental* path to a structure change (resync drift), not the deliberate one; a regenerate ships with the rebuilt site in a single commit, and the with-stubs total (16,356) never moves regardless of where the cutoff lands.

## A2. Demote the classifier to sync-time advisor

The classifier stays in `static_site_generator/` and stops running at build and app runtime. After a re-sync, `classify_corpus.dart` becomes a *report*: which new containers the rule would group (proposals), and which frozen verdicts it now disagrees with (informational — the snapshot wins). The `--expect` policy lock dies with the knife edge: the policy rows in `_locked` (`grouped vaggas`, `grouped leaves`, `real pages`, `with stubs`, both `nearest … chars`) and the whole `_lockedKeys` map guard a decision that no longer exists at build time. Their replacement is an integrity check with no judgment in it — every snapshot key must still exist in the tree as a deepest, single-content-file container; `orphan containers: 0` stays. `corpus_tools_test.dart`'s lock test keeps its shape and becomes the integrity test. The check fires only when upstream renumbers `nodeKey`s: the one event no local design survives, and the sync workflow's stop-the-line moment.

## A3. The CSV stays a human review artifact

`--write-csv` keeps regenerating the grouped-vaggas CSV beside this doc — now from the snapshot plus fresh measurements, so a reviewer can see how far each frozen verdict has drifted from what the rule would say today. Read by humans, parsed by nothing.

## A4. Document the seam

Name the snapshot as the single source in `static-html-site-plan.md` §6 and `static-html-site-build-plan.md` §5, noting the no-app-assets constraint as the reason. `static-html-site-plan.md` still calls for a committed `grouping.json` in §6, §8, §10, §12 and §13 — every place `grep -n 'grouping.json'` reports, all superseded by A1. Don't record the count here; it goes stale the moment one of them is touched. The knife-edge commentary goes in the same sweep — the exactly-1,500 margin note in `grouping_classifier.dart` and the nearest-to-line rows in `_locked` document a fragility A1 removes.

**Verify Part 2:** `--write-snapshot` emits exactly the keys today's classifier reports, and `dart run static_site_generator/bin/generate.dart --root an-1` still emits its current file set, byte-identical to the current build — same verdicts, different source. Remove one key from the snapshot, confirm the counts and that vagga's file list move as predicted, restore.

---

# Part 3 — Implementation

All three rules are pure `GroupingClassifier` changes. `SitePlan.build` already turns any `grouped` verdict into a `PageKind.chapter`, so nothing downstream changes structurally — a single-leaf chapter is a chapter with one `<section>`, and the `:has(:target)` single-view CSS handles it unchanged.

1. **`packages/wisdom_shared` — lift `isCommentary` onto `TipitakaNode`.** It has only `isLeaf` today, which is why the generator inlines `nodeKey.startsWith(TipitakaNodeKeys.commentary)` twice while the app has the getter (`tipitaka_tree_node.dart:69`). Rule (c) would be the third inline copy. Move it up, then use it in `node_labels.dart:43`, `page_template.dart:254` and the classifier.

2. **`domain/grouping_classifier.dart`**
   - Three new `GroupingReason` values: `singleLeafContainer`, `smallWholeVagga`, `commentaryRun`.
   - Move the `children.length == 1` check **above** the `minLeaves` gate and return grouped.
   - Add `static const int maxVaggaChars = 5000;` beside `maxLeafChars`, and group when `longest < maxLeafChars || total < maxVaggaChars`. `GroupingVerdict` needs a `totalLeafChars` field so the CSV stays reviewable.
   - Add `static const int commentaryMaxLeafChars = 15000;` and `static const Set<String> commentaryLineExemptions = {'atta-kn-jat', 'atta-kn-thag', 'atta-kn-thig'};`, with the reasoning from Part 1 kept next to them — 15,000 is where the biggest chapter page stops growing, and the three prefixes are the books whose children are named people.
   - Rewrite the `minLeaves` doc comment: its "85 of them single-leaf nodes where BJT already collapsed the run itself" is exactly what rule (a) now handles, so that sentence stops being a justification and becomes stale.
   - The class header's "**Group iff** the container is a deepest container … with at least `minLeaves` children, none of them `maxLeafChars` or longer" is now wrong on all three counts. Rewrite it, not patch it.

3. **`tool/classify_corpus.dart`** — update `_locked`: grouped vaggas 146 → **508**, grouped leaves 1,603 → **3,580**, real pages 14,753 → **12,776**. `with stubs` stays 16,356. The two nearest-the-line rows (`atta-an-10-1-1` 1490 / `kn-thig-6` 1500) now describe only the canon gate and only one of four; either scope them explicitly to canon or retire them in favour of per-reason counts. (Under Part 2 these rows go away entirely — do whichever lands first, not both.)

4. **`grouped-vaggas-threshold-1500.csv`** — regenerate with `--write-csv`. The filename names a rule that is now one of four; rename to `grouped-vaggas.csv` and add a `reason` column.

5. **Stale figures in comments** (located 2026-08-16; `grep -rn '1,603\|14,753' lib bin test` finds all six) — `render/search_index.dart:16,20` and `test/wiring_contract_test.dart:201,228` say 1,603; `render/site_assets.dart:66`, `render/document_shell.dart:30`, `render/search_dialog.dart:109` and `render/stylesheet.dart:926` say 14,753. Note `site_assets.dart` — it is the one the earlier draft of this list missed, and `sitegen.dart` no longer carries either figure.

6. **The frozen snapshot** — `groupedVaggaKeys` grows 146 → **508** and must be regenerated in the same commit, or the app and the site disagree about what a document is.

7. **`render/page_template.dart`** — suppress the `සම්පූර්ණ පරිච්ඡේදය` bar in `_chapter` when `page.suttas.length == 1`.

8. **Rebuild and re-measure.** The build is byte-deterministic, so the deploy is hash-incremental; expect ~1,977 deletions and a large rewrite of the commentary tree. Check the biggest chapter page lands near the predicted 264 KB.

---

# Part 4 — The app half (deferred)

Trigger: vagga grouping stops moving during static-site P2–P6. Rules (a)(b)(c) are part of that settling, so this waits on them.

## B1. Share the remaining logic

- **`SitePlan` / `PageKind`** (`static_site_generator/lib/domain/site_page.dart`) → `wisdom_shared`. It needs only `TipitakaTree` + the snapshot lookup, so the move is mechanical. This carries the prev/next order and the chapter-swallows-its-leaves rule; the app must not re-derive either.
- **Split `ContentSlicer`** (`static_site_generator/lib/domain/content_slicer.dart`) into a shared coordinate half — entry-counts-per-page + the file's nodes → `(startPage,startEntry) → (endPage,endEntry)` — and a generator-side half that materialises `DocRow`s. The app maps the same range onto its `BJTDocument`. The slicer serves bounded rendering only; grouping verdicts are compiled in via the snapshot.
- Cache slice ranges per content file (the generator already does, via `SlicerCache`); the app computes them once per document load, over entries already parsed in memory.

## B2. Reader renders one page unit

`multi_pane_reader_widget.dart` + `document_provider.dart`:
- Provider resolving `nodeKey → SitePage` (kind + owning page key) from the shared `SitePlan`.
- `sutta` → render the bounded slice; **drop the run-to-end-of-file pagination** (`loadMorePagesProvider`, `_loadMorePagesIfNeeded`) for this kind. Printed page numbers stay.
- `chapter` → all leaves of the grouped vagga with anchors; tapping a grouped leaf opens the chapter scrolled to it (the app equivalent of `#fragment`).
- `toc` → **container preamble + child links** — the heading block shown above, then the list. 258 of 285 files carry preamble entries; rendering links only would delete that text from the app.

## B3. Navigation

- Add "next sutta" beside `navigateToPreviousSuttaProvider` (`lib/presentation/providers/previous_sutta_provider.dart`); both read `SitePlan.previousOf`/`nextOf`, so a chapter is one stop and crossing a vagga lands on a sutta, not a TOC — identical to the site.
- Tree-node tap (`tree_navigator_widget.dart:193`) and `openTabFromNodeKeyProvider` (`tab_provider.dart:450`) route through the page-unit resolver instead of `node.contentFileId` directly.
- When the neighbouring unit lives in another content file, resolve it on tap (its file loads anyway); the card label comes from the tree, which needs no verdict.

## B4. Landing from search and deep links

- `openTabFromSearchResultProvider` (`tab_provider.dart:~400`) — results already carry `nodeKey`; resolve to the owning page unit, scroll to `(pageIndex, entryIndex)`. A hit inside a preamble correctly lands on the container's TOC page.
- `?e=<page>.<entry>` becomes scroll-position-only: the unit comes from the nodeKey.
- In-page search becomes naturally unit-scoped — a simplification, not extra work.

## B5. Persistence and known data hazards

- `ReaderTab`'s `pageStart/pageEnd/entryStart` change meaning. Per the warning at `lib/presentation/models/reader_tab.dart:11-19`, bump `StorageKeys.openTabs` to `_v2` rather than misread saved tabs.
- **77 trailing-colophon leaves** (68 in `vp-pct-1-2`): BJT prints those names *after* their text, so the coordinate sits at the end of what it names and a bounded slice opens with the wrong title. Continuous scroll hides this today; bounded units expose it in the app exactly as on the site. Build the detector once, in shared code — static-site P6 owes it too.
- `ap-pat*` row misalignment (1,660 pages, all 7 files) is unchanged by this work.

## B6. Two reading surfaces are still capped in fixed px

`researchContentMaxWidth` (760 — `research_chat_view.dart`, `citation_source_sheet.dart`) and `dictionarySheetMaxWidth` (800 — `dictionary_bottom_sheet.dart`) are still pixels while the reader panes have moved to an em measure that tracks the 0.7x–1.5x font scale. A large-type reader therefore gets bigger words in the same 760/800px: answers and dictionary entries never widen with their text.

**Verify Part 4:** `flutter run -d macos`. Tap සුත්තපිටක → TOC, not DN-1 text. Tap `an` → the three-line title block + nipāta links. Tap Mūlapariyāya → text ends at the sutta boundary with prev/next; title and breadcrumb correct at every scroll position. Tap a leaf inside a grouped `an-1` vagga → chapter opens scrolled to it, vagga heading + *namo tassa* at the top. Open an FTS result matching mid-sutta, and one matching inside a preamble. Open `sammaditthi://tipitaka/<key>?e=<p>.<e>` for a grouped and an exploded leaf. Cross-check ~20 suttas against the generated HTML — same text, same boundaries, same prev/next targets. Per project convention, no tests unless asked.

---

## Constraints this plan respects

- **No new static/asset files on the app side** — the shared truth is generated Dart in `wisdom_shared`; the CSV under `docs/` stays human-only, parsed by nothing.
- **Verdicts are frozen** — a resync may change what pages *say*, never which pages *exist*. Only a deliberate snapshot edit, or genuinely new content, moves URLs.
- **The BJT hierarchy survives intact.** Every rule here changes how many files the tree is spread across, never the tree. Breadcrumbs and TOC lists read `tree.ancestorsOf` / `tree.childrenOf` and are unaffected by any of it.
- **The same text never appears in two files.** A grouped leaf gets a `#fragment` inside its chapter and a stub or redirect at its old URL — never a second copy.
- Edition scope, URL grammar, hosting topology and the zero-JS site model stay exactly as locked.
