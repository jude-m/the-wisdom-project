# SuttaCentral ↔ BJT Concordance — Investigation Findings

> **Status:** Findings / evidence log. Captured 2026-06-27 while building Step 4
> (the resolver). The runtime resolver + search-by-reference **shipped** on the
> 3-entry seed in §5; this doc is the spec for the **build tool** that grows it to
> all suttas. **Read this before writing `tools/suttacentral_map/build_map.py`.**
> **Companion to** [`ai-qa-and-suttacentral-reference-resolver-plan.md`](./ai-qa-and-suttacentral-reference-resolver-plan.md)
> (Part B). The plan settled the *architecture* (build-time Python → committed
> JSON → pure-Dart lookup). This doc records what the *data* actually looks like —
> including two ways the plan's worked example is wrong.

---

## 0. TL;DR (the headline)

- The plan's example **`sn15.3 → sn-2-4-3` is wrong on both counts.** The correct
  node is **`sn15.3 → sn-2-3-1-3`** (අස්සුසුත්තං, the Assu / "stream of tears"
  sutta — which is also the citation hard-coded in the `ask_server` stub).
- It's wrong because (a) it skips a **vagga-inside-saṁyutta** level, and (b) BJT
  **bundles SN 12 + SN 13 into one node**, so the saṁyutta positions shift.
- **Therefore the concordance cannot be computed by arithmetic or by trusting
  saṁyutta titles.** It must be built by **leaf-sutta-title confirmation** — the
  same "propose, then confirm against an independent signal" discipline the
  `tools/mahamevnawa_map/` tool already uses.

---

## 1. Data sources — what is and isn't available

| Source | Has SC↔BJT mapping? | Notes |
|---|---|---|
| `../tipitaka.lk` (our BJT source project) | **No** | Checked `db/`, `src/`, `public/`: zero `suttacentral`/`scid`/`sc` fields, zero `sn15.3`-style uids. Only `dict.db` + static assets. |
| Our bundled `assets/data/tree.json` | **No** | Carries no SC ids — pure BJT node keys + titles. |
| `bilara-data` (SuttaCentral) | not checked out | The translation corpus `ask_server` ingests. Gives SC's **enumeration/order**, but **not** BJT coordinates — it can seed the SC side, never confirm the BJT side. |

**Consequence:** unlike the Mahamevnawa map (where Mahamevnawa published a `link`
field back-referencing BJT coordinates), **no source hands us the mapping.** There
is no shortcut. The concordance must be *authored* by aligning the two trees and
confirming by leaf-title agreement.

---

## 2. `tree.json` schema (the build tool's BJT input)

`assets/data/tree.json` is a **flat dict**, **16,355 keys**, keyed by nodeKey
(`sn`, `sn-2`, `sn-2-3`, `sn-2-3-1`, `sn-2-3-1-3`, …). Each value is a **list**:

```
index  0            1               2               3                                    4          5
      [ paliTitle,  sinhalaTitle,   hierarchyLevel, [entryPageIndex, entryIndexInPage],  parentKey, contentFileId ]
```

- **[0]** Pali title, *in Sinhala script* (e.g. `'3. අනමතග්ගසංයුත්තං'`).
- **[1]** Sinhala title (e.g. `'නිදාන වර්‍ගය'`).
- **[2]** `hierarchyLevel` (int); **[3]** `[entryPageIndex, entryIndexInPage]`
  nav coords; **[4]** parent nodeKey (`'root'` sentinel at the top level — the
  reliable way to walk the tree); **[5]** `contentFileId` (`String?`; null ⇒
  container node, non-null ⇒ readable leaf — confirmed in `tree_local_datasource.dart`).
- Example: `d['sn-2'] = ['නිදානවග්ගො', 'නිදාන වර්‍ගය', 5, [0, 3], 'sn', 'sn-2']`.

**Gotchas for the build tool:**

1. **Numeric-suffix sort, not lexical.** Children of `sn-2-1` are `sn-2-1-1 …
   sn-2-1-10`; a string sort puts `-10` before `-2`. Sort by the integer tail.
2. **Titles contain ZWJ (U+200D).** Seen in `'නිදාන වර්‍ගය'`. An exact-substring
   grep for a title can silently miss nodes — **normalise (strip ZWJ / NFC)**
   before matching titles.
3. **Commentary nodes are prefixed `atta-`** (aṭṭhakathā) and their titles end in
   **වණ්ණනා** (vaṇṇanā), e.g. `atta-sn-2-3-1-3`. The **mūla (canonical) text** is
   the un-prefixed node `sn-2-3-1-3`. **The resolver must target the un-prefixed
   node.** (There are parallel `atta-*` keys for most of the canon.)

---

## 3. BJT nesting depth is non-uniform across nikāyas

A single flat→nested formula is impossible — each nikāya nests differently:

| Nikāya | Levels | Example chain |
|---|---|---|
| **SN** | 4: book/vagga → saṁyutta → vagga → sutta | `sn-2` → `sn-2-3` → `sn-2-3-1` → `sn-2-3-1-3` |
| **DN** | 2: vagga → sutta | `dn-2` (මහාවග්ගො) → `dn-2-2` (මහානිදානසුත්තං) |
| **MN** | 3: paṇṇāsaka → vagga → sutta | `mn-1` (මූලපණ්ණාසකො) → … |
| **Dhp** | 2: vagga → verse-group | `kn-dhp-1` (යමකවග්ගො) → … |

SN's five books: `sn-1` සගාථවග්ගො, `sn-2` නිදානවග්ගො, `sn-3` ඛන්ධකවග්ගො,
`sn-4` සළායතනවග්ගො, `sn-5` මහාවග්ගො.

DN's three vaggas are **suttas-direct** (`dn-1` Sīlakkhandha, `dn-2` Mahā,
`dn-3` Pāthika) — so `dn1` (Brahmajāla) is `dn-1-1`, not seeded yet (verify first).
MN groups by paṇṇāsaka then vagga, so `mn1` is ~3 deep — also not yet seeded.

---

## 4. The proof that position & saṁyutta-titles cannot be trusted

This is the most important section. Two independent anomalies, both proven from
the data:

### 4a. The vagga-inside-saṁyutta level (why `sn-2-4-3` has too few segments)

SN 15 (Anamatagga) is `sn-2-3`. It nests **two vaggas**, then suttas:

```
sn-2-3        3. අනමතග්ගසංයුත්තං        (Anamatagga-saṁyutta = SN 15)
  sn-2-3-1    1. තිණකට්ඨවග්ගො           (Tiṇakaṭṭha-vagga)
    sn-2-3-1-1  තිණකට්ඨසුත්තං           = SN 15.1  ✓ (Tiṇakaṭṭha)
    sn-2-3-1-2  පඨවීසුත්තං              = SN 15.2  ✓ (Pathavī)
    sn-2-3-1-3  අස්සුසුත්තං             = SN 15.3  ✓ (Assu, "stream of tears")
  sn-2-3-2    2. දුග්ගතවග්ගො            (Duggata-vagga)  → SN 15.11 … onward
```

So the leaf is `sn-2-3-1-3` (4 segments), not `sn-2-4-3` (3). The vagga between
saṁyutta and sutta is mandatory in SN.

### 4b. BJT bundles SN 12 + SN 13 → the saṁyutta numbers shift

`sn-2` (Nidānavagga, canonically 10 saṁyuttas SN 12–21) has only **9 children**:

```
sn-2-1  1. අභිසමයසංයුත්තං     ← titled "Abhisamaya" (SN 13) …
sn-2-2  2. ධාතුසංයුත්තං        (Dhātu      = SN 14)
sn-2-3  3. අනමතග්ගසංයුත්තං    (Anamatagga = SN 15)
sn-2-4  4. කස්සපසංයුත්තං       (Kassapa    = SN 16)
sn-2-5  5. ලාභසක්කාරසංයුත්තං   (Lābhasakkāra = SN 17)
sn-2-6  6. රාහුලසංයුත්තං       (Rāhula     = SN 18)
sn-2-7  7. ලක්ඛණසංයුත්තං       (Lakkhaṇa   = SN 19)
sn-2-8  8. ඔපම්මසංයුත්තං       (Opamma     = SN 20)
sn-2-9  9. භික්ඛුසංයුත්තං      (Bhikkhu    = SN 21)
```

But **`sn-2-1`'s content is actually the Nidāna-saṁyutta (SN 12)**, not Abhisamaya:

- `sn-2-1-1-1` = **පටිච්චසමුප්පාදසුත්තං** (Paṭiccasamuppāda) = **SN 12.1**, the
  opening sutta on dependent origination — unmistakably SN 12, not SN 13.
- `sn-2-1` has **10 vaggas** (`sn-2-1-1` බුද්ධවග්ගො … `sn-2-1-10` අභිසමයවග්ගො) —
  the nine Nidāna vaggas **plus** an "Abhisamayavagga" as the 10th.
- There is **no standalone `නිදානසංයුත්ත` node** anywhere in the tree.

**Strong interpretation:** BJT folds SN 12 (Nidāna) **and** SN 13 (Abhisamaya)
into a single node `sn-2-1`, labelling it after its tail section "Abhisamaya" and
appending SN 13 as the 10th vagga. That collapses 10 canonical saṁyuttas into 9
BJT nodes, so from SN 14 onward the BJT index = (SC saṁyutta number − 12):
SN 14→`sn-2-2`, SN 15→`sn-2-3`, SN 16→`sn-2-4`. (Whether it's literally a "merge"
matters less than the proven fact that the offset is **not** uniform and the
boundary is a bundling seam.)

### 4c. The takeaway for the build tool

- **Saṁyutta-level title fields are unreliable** — `sn-2-1` says "Abhisamaya" but
  holds Nidāna (SN 12).
- **Position is unreliable** — bundling shifts everything after the seam.
- **Leaf sutta titles are the reliable anchor.** Confirm every proposed pair by
  matching the BJT leaf's Pali title (ZWJ-normalised) against SC's sutta name, and
  **drop** any pair the leaf titles contradict. This is precisely the
  `mahamevnawa_map` "propose by position, confirm by independent signal, reject on
  contradiction" recipe — reuse it. Expect bundling seams (SN 12/13 here) and
  *peyyāla* (abbreviated-repetition) regions to need the same handling that build
  already does.

---

## 5. Verified seed entries (shipping in Step 4 now)

Hand-verified by **leaf-title match** against SC's known sutta names. This is the
entire `assets/data/sc-to-bjt.json` seed for now — same shape the full build tool
will emit, just small:

| SC uid | BJT nodeKey | BJT leaf title | SC sutta |
|---|---|---|---|
| `sn15.1` | `sn-2-3-1-1` | තිණකට්ඨසුත්තං | Tiṇakaṭṭha |
| `sn15.2` | `sn-2-3-1-2` | පඨවීසුත්තං | Pathavī |
| `sn15.3` | `sn-2-3-1-3` | අස්සුසුත්තං | Assu ("stream of tears") — matches the `ask_server` stub citation |

Everything else (rest of SN 15, other saṁyuttas, DN/MN/KN, Vinaya `pli-tv-*`) is
**deferred to the build tool**. The resolver code does not care how large the map
is, so the seed grows by swapping the JSON — no code change.

---

## 6. Notes for Part C (search-by-reference) wiring

Discovered while tracing the search pipeline; recorded so the integration stays
thin:

- **A correct `nodeKey` gives correct labels for free.** `searchResultLabels()`
  (`lib/presentation/utils/search_result_labels.dart`) re-derives a result's title
  + breadcrumb path from `nodeByKeyProvider(result.nodeKey)`. So a reference hit
  only needs the right `nodeKey` — the tile renders "අස්සුසුත්තං" + its path
  automatically, in the active Content Language.
- **`searchResultTypeLabel()` is an exhaustive `switch`** (no `default`). Adding
  `SearchResultType.reference` forces a new `case` + a new ARB key, or it won't
  compile.
- **The tab bar maps over `SearchResultType.values`**
  (`search_results_panel.dart:484`). Adding `reference` to the enum would
  auto-create a browsable "Reference" **tab** with a count badge — undesirable. So
  surface a reference hit **without** a new tab: e.g. prepend it into the Top
  Results group (and/or pin it), and exclude `reference` from the tab row + badge
  loop. A reference match is a *jump*, not a category to browse.
- **A reference hit is an in-memory lookup, not a DB query** — compute it in the
  notifier/provider layer, never in `TextSearchRepository` (which is FTS-over-
  SQLite). Keeps the concordance off the DB path, per the plan's SQLite section.

---

## 7. Commands used (reproducible)

```bash
# tipitaka.lk has no SC mapping:
grep -rIlE 'suttacentral|"scid"|"sc":' ../tipitaka.lk/{db,src,public}   # → nothing
# Walk our tree by parentKey, read Pali titles (index 0):
python3 -c "import json;d=json.load(open('assets/data/tree.json'));\
print([(k,v[0]) for k,v in d.items() if isinstance(v,list) and len(v)>4 and v[4]=='sn-2'])"
# Prove sn-2-1 holds SN 12: its first leaf is Paṭiccasamuppāda:
#   d['sn-2-1-1-1'][0] == 'පටිච්චසමුප්පාදසුත්තං'
```
