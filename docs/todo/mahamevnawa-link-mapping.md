# Mahamevnawa (tripitaka.online) link mapping

**Goal:** when a user opens a BJT sutta, show a button that opens the matching
**simple-Sinhala (සරල සිංහල)** sutta on Mahamevnawa's site in the browser.

URL to open:  `https://www.tripitaka.online/sutta/{id}`

## What we found

1. **tripitaka.online has a public JSON API** (it is a Next.js app).
   - Whole navigation tree: `GET /api/tree`  (~440 KB, one request, no crawling).
   - One sutta:            `GET /api/sutta/{id}`  (full content + a `link` field).

2. Every leaf in `/api/tree` looks like:
   ```json
   { "id": 42, "label": "මූල පරියාය සූත්‍රය", "data": "265" }
   ```
   `data` is the **sutta page id** → `/sutta/265`. So the tree alone gives the
   Sinhala title **and** the page id for every sutta.

## How the map is built — propose, then confirm

Both editions are the **same canon in canonical order**, so we align this
project's `assets/data/tree.json` against `/api/tree`. But two things make a
naive title match unsafe, so the build has **two stages**:

**Stage 1 — propose (titles, then position).** Walk both trees together
(nikāya → … → sutta) and match each level by Sinhala title, scoped to the
already-matched parent. Three wrinkles are handled here:
   - *Generic ordinal vagga names differ by language.* BJT uses Pali ordinals
     (`පඨමො වග්ගො` = "first vagga"), Mahamevnawa uses Sinhala (`පළමු වර්ගය`). These
     are the **same level** but never title-match, so under that vagga we align the
     leftover sutta leaves by **position**, but only across a region the two editions
     enumerate identically (same sutta count, same canonical order). Fixing this
     recovered ~110 clear-cut suttas like `ආණි` (Āṇi), mostly in SN.
   - *The sutta titles themselves differ* — spelling variants and unnamed suttas.
     Even where the position is unambiguous the two editions often spell a name
     differently: `වජ්ජිපුත්ත` vs `වජ්ජිපුත්තක`, `පඤ්චක` vs `පඤ්ච`, or the
     Sanskritised `කස්සප` → `කාශ්‍යප`, `සිගාල` → `සිඟාල`. Sometimes BJT leaves a
     sutta **unnamed** (a bare `3. 1. 1. 1`) while Mahamevnawa names it generically
     (`ප්‍රථම සූත්‍රය`, "first sutta"). The positional alignment still proposes these
     pairs, and we keep them **only when the `link` field actively confirms** them
     (Stage 2). This recovered **~290** more suttas — including the last stray
     title-variant in **DN and MN, so both nikāyas are now complete**. (Previously
     Stage 1 demanded title agreement and silently dropped every one of these.)
   - *BJT has an extra grouping level Mahamevnawa omits* (the AN *paṇṇāsaka*). We
     flatten through it so the named vaggas inside still line up.

**Stage 2 — confirm (the `link` field).** Stage 1 only *proposes*. Every proposed
pair is then checked against Mahamevnawa's own `link` field — its declared
back-reference to the BJT coordinate (e.g. `mn1_1-1-1`, `sn2_8-1-7`). A link's
**last two numbers are always (vagga ordinal, sutta ordinal)**; we require those
to equal the BJT key's. Any pair the link **contradicts** is dropped, so no guess
survives. This is what keeps *peyyāla* (repetition) sections from leaking in —
the two editions expand those differently, so their numbers disagree and they are
dropped automatically.

A **title-matched** pair is **kept** when the link confirms it, or when the page has
**no link at all** (absence is not a contradiction — these are clean suttas whose page
simply omits the field; all 92 were separately verified by title). A **position-only**
pair — one Stage 1 proposed *despite* the titles differing — is kept **only** when the
link *actively confirms* it; an absent link is not enough for a positional guess, so it
is left unmatched. A pair is **dropped** when a present link points elsewhere — which
also catches positional slots that drifted where the editions bundle a region
differently (e.g. the mixed singleton/plural vagga SN `4-1-17`).

**Two edge cases the confirmation handles** (see `link_verdict()` in `build_map.py`):
   - *Vagga-less SN saṃyuttas.* A few SN saṃyuttas have no vagga level in BJT (a
     3-deep key like `sn-4-4-1`), yet Mahamevnawa still inserts vagga 1. For those the
     BJT vagga is read as **implicitly 1** — otherwise whole saṃyuttas (e.g. Asaṅkhata)
     would be wrongly dropped.
   - *Slug-format links.* A handful of pages store the back-reference as a URL slug
     (`4-4-2-4-<sinhala-title>`) instead of the code form (`an4_…`); we match on its
     **leading numeric coordinate** (e.g. `an-4-4-2-4` → `/sutta/8936`).

### Khuddaka Nikāya (books 1–9) — position-trusted, link-corroborated

Mahamevnawa serves only the **first 9 Khuddaka books** as per-sutta pages. Each is a
**verified 1:1 enumeration** — the leaf counts agree exactly (khp 9, dhp 26, ud 80, iti
112, snp 72, vv 85, pv 51, thag 264, thig 73) — so the build pins each book by name and
aligns its leaves by **position** (`strict_pool`, one book at a time). Here the `link`
field can only **corroborate**, never veto, because Mahamevnawa's link numbering is
structurally incompatible with BJT in several books *without meaning wrong content*:

   - an **extra grouping level BJT flattens** — a lone vagga under Itivuttaka's
     Catukkanipāta or Theragāthā's higher nipātas (`kn-iti-4-1` → link `kn1_4-4-1-1`);
   - **nipātas named by verse-count, not sequential ordinal** (BJT Theragāthā nipāta 16 ↔
     link `kn5_20`, the Vīsatinipāta);
   - **single-sutta nipātas served as one header page** with no sutta number (Therīgāthā
     `kn6_4` — whose page nonetheless carries the Bhaddā Kāpilānī verses, verified);
   - **Theragāthā pages with no `link` at all**.

So a Khuddaka pair is **link-confirmed** when the BJT tail is an ordered subsequence of the
link anchored at the sutta number, and otherwise **kept by trusted position**. Counts must
still agree exactly per book (a mismatch would skip the book), so position is reliable.

**One Mahamevnawa-only surplus leaf is skipped:** `12933` (*Suttanipāta* Pārāyana
*pārāyanatthutigāthā*), a closing section Mahamevnawa breaks out as its own page while BJT
folds it into the preceding **Piṅgiya** sutta. Dropping it makes Suttanipāta a clean
**72 ↔ 72**. Because its presence shifts Mahamevnawa's own numbering, the *anugītigāthā*
right after it links as `5-18` vs BJT `5-17` — kept anyway by position.

## The deliverable — a concrete 1-to-1 map

`tools/mahamevnawa_map/bjt-to-mahamevnawa.json`

```json
{ "urlPattern": "https://www.tripitaka.online/sutta/{id}",
  "map": { "dn-1-1": 17, "mn-1-1-1": 265, "sn-2-8-1-7": 2924, ... } }
```

**3747 concrete one-to-one mappings.** Coverage:

| Nikāya | BJT suttas | mapped 1:1 | skipped |
|--------|-----------:|-----------:|--------:|
| Dīgha     |   34 |   34 |   0 |
| Majjhima  |  152 |  152 |   0 |
| Saṃyutta  | 2190 | 1707 | 483 |
| Aṅguttara | 1849 | 1082 | 767 |
| Khuddaka (books 1–9) |  772 |  772 |   0 |

The Khuddaka row counts **books 1–9 only** (Khuddakapāṭha, Dhammapada, Udāna, Itivuttaka,
Suttanipāta, Vimānavatthu, Petavatthu, Theragāthā, Therīgāthā). **Books 10–18** (Apadāna,
Jātaka, Buddhavaṃsa, Cariyāpiṭaka, both Niddesas, Paṭisambhidāmagga, Nettippakaraṇa,
Peṭakopadesa) have **no translated text on Mahamevnawa yet** → out of scope (neither mapped
nor listed as skipped).

Of the kept pairs, **3396 are link-confirmed** and **351 rest on verified positional
alignment** — a clean page whose Mahamevnawa link is simply absent, or (in Khuddaka) a page
whose link numbering is structurally incompatible with BJT (see the Khuddaka section above).
**512** of the confirmed pairs were *recovered by position + link* — the spelling-variant
and unnamed-sutta cases, each kept **only** because the link vouched for it. **34 proposed
pairs were dropped** by the link check — *peyyāla* / bundled pages (e.g. `විනයපෙය්‍යාලං`,
the plural-named `...සුත්තානි` groups) plus a few positional slots that drifted where the
editions bundle differently; see `link-dropped.txt`. (All 34 are SN/AN — no Khuddaka pair
is dropped.)

**Why the rest are skipped:** they are written to `unmatched.txt` **grouped by reason**,
with a header explaining each group:

| Group | Count | What it is |
|-------|------:|------------|
| `maha-bundled-subtree`   | 1148 | A whole BJT branch that Mahamevnawa serves on **one page** — no per-sutta target. |
| `region-mismatch`        |   62 | A stretch the two editions enumerate with different counts, so the positional step skips it whole. |
| `link-elsewhere`         |   34 | A positional proposal whose link pointed to a different coordinate (editions bundle the run differently). |
| `positional-unconfirmed` |    6 | A position-only guess whose Mahamevnawa page carries no link to confirm it. |

The overwhelming majority is genuine bundling (Mahamevnawa collapses the repetitive
*peyyāla* series of SN/AN onto fewer pages, so those BJT suttas have no clean 1-to-1
target). **DN and MN are now fully covered** (the former lone title-form variants — e.g.
BJT `චක්කවත්ති` vs Mahamevnawa `චක්කවත්ති සීහනාද` — are recovered automatically by the
position + link step).

⚠️ **Not *every* skip is peyyāla.** The `region-mismatch` group hides ~15 ordinary named
suttas (e.g. `an-10-3-2` අජිත / සඞ්ගාරව, `sn-2-6-1` විඤ්ඤාණ / වෙදනා / ධාතු) that **do**
have a separate Mahamevnawa page but get dropped because their *vagga* title is a spelling
variant, so the whole region is skipped. These are recoverable with a finer per-title
alignment inside mismatched regions (still link-gated) — a worthwhile follow-up.

## Validation

- **Link field:** every kept pair with a *confirming* link agrees with it (the map is built
  from that agreement). The **512** position-only recoveries are kept *only* on that
  agreement — their titles differ by design, so the link is their sole and sufficient
  proof: Mahamevnawa's own back-reference to the BJT coordinate.
- **Live page titles (independent):** a random 50-pair sample fetched each live
  page's title and fold-compared it to the BJT title — **50/50 correct**.
- **Khuddaka position-trusted pairs (independent):** the pairs whose link numbering is
  incompatible were title/content spot-checked against the live page — e.g. `kn-thag-16-1`
  → *Adhimutta*, `kn-thig-13-1` → *Ambapālī*, and `kn-thig-4-1` → page `13592`, whose body
  carries the *Bhaddā Kāpilānī* verses under its nipāta heading.
- **Injectivity:** the map is 1:1 in both directions — **3747 distinct BJT keys**
  map to **3747 distinct Mahamevnawa ids** (no target is claimed twice).

## How the app should use it

1. Ship `bjt-to-mahamevnawa.json` as an asset (or fold `map` into the content DB).
2. In the reader, take the current BJT sutta key (e.g. `mn-1-1-1`).
3. If it is in `map`, show an "Open in Mahamevnawa (සරල සිංහල)" button →
   `https://www.tripitaka.online/sutta/{map[key]}` via `url_launcher`.
4. If it is not in `map`, hide the button.

## Regenerating

```bash
cd tools/mahamevnawa_map
python3 build_map.py          # uses cached tree + cached links
python3 build_map.py --fetch  # re-download /api/tree first
```

Outputs:
- `bjt-to-mahamevnawa.json` — the map (kept pairs).
- `unmatched.txt`          — BJT suttas with no clean 1:1, **grouped by reason** with a
  header per group (bundled subtrees, size-mismatch regions, link-rejected, …), for review.
- `link-dropped.txt`       — proposed pairs the link field rejected, for review.
- `maha-tree-cache.json`   — cached `/api/tree`.
- `maha-links-cache.json`  — cached `link` per sutta id (so re-runs need no network).
