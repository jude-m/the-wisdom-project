# Collapse single-leaf containers and whole-small vaggas

> **Status:** ready to implement · both rules are classifier-only changes.
> **Measured 2026-08-14** over the vendored corpus (16,355 nodes).
> The **1,500 threshold does not move.** These are two new grouping reasons beside it, not a loosening of it.

## What triggered this

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

Breadcrumbs and TOC lists are built from the tree, never from the page set — `tree.ancestorsOf(page.nodeKey)` at `page_template.dart:59`, `tree.childrenOf(page.nodeKey)` at `:88`. So the rendered hierarchy is independent of how many files it is spread across, and both levels stay visible on the merged page:

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
- **Search.** `X-1` becomes a grouped leaf, so its result row links to `X.html#X-1` — the path the other 1,603 already take.

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

---

## Impact

The two rules do not overlap: (a) touches only 1-leaf containers, (b) only ≥6-leaf ones. The saving is additive, 159 + 69 = 228.

| rule | grouped containers | leaves swallowed | real pages | with stubs |
|---|---|---|---|---|
| locked (`max<1500`) | 146 | 1,603 | 14,753 | 16,356 |
| + (a) | 305 | 1,762 | 14,594 | 16,356 |
| + (b) | 155 | 1,672 | 14,684 | 16,356 |
| **+ (a) + (b)** | **314** | **1,831** | **14,525** | **16,356** |

**14,525 real pages** = 14,524 under `/tipitaka/` plus the root `/`. Down 228.

**The 16,356 does not move**, and cannot: every leaf gets either a real page or a stub, so `leaves + containers + 1` is invariant to any grouping rule. The P5 stub gate and the Cloudflare file cap are untouched. Only the stub count moves — 1,603 → **1,831**, still far inside the Bulk Redirects free 10K quota.

Concretely:

- `sn-2-1-9` subtree: **24 → 13** pages
- `sn-2-1-8`: **12 → 1** page
- `sn-2-1-10`: unchanged at 12

---

## Implementation

Both rules are pure `GroupingClassifier` changes. `SitePlan.build` already turns any `grouped` verdict into a `PageKind.chapter`, so nothing downstream changes structurally — a single-leaf chapter is a chapter with one `<section>`, and the `:has(:target)` single-view CSS handles it unchanged.

1. **`domain/grouping_classifier.dart`**
   - Two new `GroupingReason` values: `singleLeafContainer` and `smallWholeVagga`.
   - Move the `children.length == 1` check **above** the `minLeaves` gate and return grouped.
   - Add `static const int maxVaggaChars = 5000;` beside `maxLeafChars`, and group when `longest < maxLeafChars || total < maxVaggaChars`. `GroupingVerdict` needs a `totalLeafChars` field so the CSV stays reviewable.
   - Rewrite the `minLeaves` doc comment: its "85 of them single-leaf nodes where BJT already collapsed the run itself" is exactly what rule (a) now handles, so that sentence stops being a justification and becomes stale.

2. **`tool/classify_corpus.dart`** — update `_locked`: grouped vaggas 146 → **314**, grouped leaves 1,603 → **1,831**, real pages 14,753 → **14,525**. `with stubs` stays 16,356. The nearest-either-side-of-the-line rows still track `maxLeafChars` and stay as they are (`atta-an-10-1-1` 1490 / `kn-thig-6` 1500) — but they now only describe one of two gates, so add the small-vagga boundary alongside them.

3. **`docs/todo/web-strategy/grouped-vaggas-threshold-1500.csv`** — regenerate with `--write-csv`. The filename now names only one of two rules; rename to `grouped-vaggas.csv` and add a `reason` column.

4. **Stale figures in comments** — `sitegen.dart:169-172`, `render/search_index.dart:10-14`, `test/wiring_contract_test.dart:197,224` all say 1,603; `document_shell.dart:23`, `search_dialog.dart:94`, `stylesheet.dart:932` all say 14,753.

5. **Plan docs** — `static-html-site-plan.md` §6/§13.1 and `unified-reading-units-plan.md` Phase A both quote **146 / 1,603 / 14,753 / 16,356** as locked. Update in the same commit, per the `_locked` header's own rule.

6. **`unified-reading-units-plan.md`'s frozen snapshot** — `groupedVaggaKeys` in `wisdom_shared` is generated from these verdicts. It grows 146 → 314 and must be regenerated, or the app and the site disagree about what a document is.

7. **`render/page_template.dart`** — suppress the `සම්පූර්ණ පරිච්ඡේදය` bar in `_chapter` when `page.suttas.length == 1`.

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
