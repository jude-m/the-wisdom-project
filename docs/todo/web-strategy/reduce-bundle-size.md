# Reduce bundle size

What actually shrinks the static site, ranked by payoff. Measured against the
2026-08-09 full-corpus build (14,752 pages).

Scope: the apex static site only. The Flutter app's payload on `app.<domain>` is
a separate problem with separate tooling.

Cross-refs: `static-html-site-build-plan.md` owns phasing, `seo-wins.md` owns
search performance, `static-web-hosting.md` owns the Cloudflare deploy path.

---

## 1. Two different "sizes" — don't conflate them

Every item below moves exactly one of these, and they have different stakes:

| | Number | Who pays | Stakes |
|---|---|---|---|
| **Wire size** | ~2.6 KB brotli for a median page | every visitor | already excellent |
| **Build size** | 394 MB on disk | the deploy | this is the painful one |

The site's stated audience — slow connections, crawlers — is served by the wire
number, and that number is already good. **Build size is a deploy problem, not a
user problem.** It matters because a shared-chrome edit invalidates all 14,752
content hashes and forces a full push, which is where the deploys documented in
`static-web-hosting.md` fail.

Optimising for build size at the cost of wire size would be backwards. Nothing
below does that; several items help both.

## 2. What already works — don't regress it

- **Zero inline CSS.** Verified 2026-08-10 three ways: no `style="` and no
  `<style>` in `lib/` or `bin/`, and neither pattern in any of the 14,752 built
  files. Every page carries one `<link rel="stylesheet" href="/assets/site.css">`
  (`render/document_shell.dart:41`) and nothing else. `site.css` is **12,578
  bytes**, fetched once and cached for the whole site — 0.003% of the build.
  Inline CSS is not a lever here because there is none.
- **Zero inline JS.** No `<script>` anywhere in the output.
- **No dead font faces.** All four weights (400/500/600/700) are requested by
  real rules in the built CSS, against both families — so all 8 WOFF2 subsets
  earn their place, and browsers fetch only the faces a page actually renders.
  Don't spend time pruning these.
- **Markup is already tight.** Mean 2.2 indented newlines per page; HTML
  minification would recover essentially nothing.

## 3. The numbers

```
build/                      394 MB
├── tipitaka/               393 MB   14,752 HTML pages   99.8%
├── fonts/                  336 KB   8 woff2 subsets
└── assets/                  64 KB   emblem.png 47 KB + site.css 12.5 KB
```

Page size distribution (bytes):

| min | p50 | p90 | p99 | max | mean |
|---|---|---|---|---|---|
| 1,446 | 11,774 | 54,055 | 230,712 | 1,364,020 | 25,953 |

Compression, corpus-wide sample: **gzip = 18.7% of raw** (≈68 MB equivalent).
A median page: 11,689 raw → 3,091 gzip → 2,567 brotli. Cloudflare Pages
negotiates brotli automatically for text types; nothing to configure.

Per-page repeated chrome, measured over a 400-page random sample:

| Component | Per page | × 14,752 |
|---|---|---|
| `class=` attributes | 1,516 B | 21.3 MB |
| `<head>` (incl. provenance comment) | 583 B | 8.2 MB |
| inline `<svg>` icons | 575 B | 8.1 MB |
| `aria-label` / `title` | 458 B | 6.4 MB |
| layout radio inputs | 424 B | 6.0 MB |
| `lang=""` attributes | 366 B | 5.2 MB |
| pager | 309 B | 4.6 MB |
| **head + toolbar + pager total** | **2,704 B** | **38 MB (11.2%)** |

---

## 4. Re-cut `emblem.png` — 47 KB → ~5 KB

`assets/emblem.png` is a 200×200 RGBA PNG rendered at 28×28 in every toolbar
(`render/site_chrome.dart:73`). At 47,115 bytes it is the heaviest single thing
a first-time visitor downloads apart from a font — **3.7× the entire
stylesheet**, to paint a 28px mark.

**The 200px size is already a reasoned decision, and this argues against it.**
`assets/make_emblem.sh` documents two reasons for not re-cutting to ~84px: the
bytes are paid once and cached site-wide, and P5's OG card wants a raster larger
than the toolbar does. Both are true; neither survives closely:

- *Paid once* is exactly the first-paint request. On the slow connections this
  site exists for, 47 KB before first paint is the worst-placed 47 KB on the
  site — and it isn't shared with anything, because…
- *The OG card needs its own file anyway.* OG images want ~1200×630; a 200×200
  square is the wrong shape and too small regardless. P5 will cut a dedicated
  raster, so the toolbar mark is not subsidising it.

**Action:** re-cut to 56×56 (2× for a 28px mark) in `make_emblem.sh`, expect
~4–6 KB, commit the output. If P5 wants an OG raster, add it as a second file.
Build-size gain is trivial; **first-paint gain is ~40 KB**, the largest available.

## 5. Move the toolbar SVG icons into the stylesheet — ~8 MB

Three icons are emitted verbatim into all 14,752 pages:

- the up-arrow — `render/site_chrome.dart:184` (`_upGlyph`)
- side-by-side and stacked layout marks — `render/reading_layouts.dart:71,77`,
  sharing `_iconFrame` at `:103`

That's **575 B/page → 8.1 MB corpus-wide** for three shapes that never change.
Declaring them once in `site.css` as `mask-image` data URIs moves them into the
12.5 KB file every visitor already caches.

This is the only item that improves **both** numbers meaningfully: ~8 MB off the
build, and ~575 B off every single page's wire payload.

Watch the details — `currentColor` stroke becomes `background-color` under
`mask-image`, and the icons must stay invisible to assistive tech exactly as
`aria-hidden="true"` makes them today.

## 6. Trim the per-page head — ~2.8 MB

Three fixed items in every `<head>`:

| Item | Per page | Corpus |
|---|---|---|
| provenance comment (`node:` / page slice) | 93 B | 1.3 MB |
| `<meta name="dc.source">` | 59 B | 0.8 MB |
| `<meta name="generator">` | 50 B | 0.7 MB |

These are cheap and they earn their keep — D8 in the build plan makes "every page
names its source JSON + entry slice" a deliberate contract, and it's what makes a
bad page traceable back to its input. **Recommend keeping all three.** Listed
here only so the 2.8 MB is accounted for rather than rediscovered later.

If the build ever needs to shed a last MB, the HTML comment is the one to drop —
`dc.source` carries the same provenance in a machine-readable form.

## 7. Known limit: 195 fat pages carry 18% of the build

195 pages exceed 200 KB and account for **66 MB**. The largest:

| bytes | page | rows |
|---|---|---|
| 1,364,002 | `vp-mv-1` මහාක්ඛන්ධකං | 704 |
| 1,021,368 | `atta-dn-2-3` | 355 |
| 995,025 | `atta-kn-mn-2-1` | 323 |
| 927,714 | `atta-dn-1-1` | 380 |
| 847,046 | `ap-kvu-1-1` | 1,518 |

**These are not grouped vaggas.** Every one of the top twelve carries exactly 4
`id=` attributes — the four layout radios and nothing else. A grouped chapter
would carry an anchor per sutta for the `:has(:target)` single-view. So these are
**single leaves that are genuinely one enormous text**, and the 1,500-char
grouping threshold neither caused them nor can relieve them: grouping only ever
merges small things.

At ~250 KB gzipped, `vp-mv-1` is the worst reading experience on the site — and
it is irreducible under the locked URL model, where one nodeKey is one page.
Splitting it would mean inventing sub-leaf URLs that don't exist in `tree.json`,
which reopens the deep-link contract in
`deep-linking-and-shareable-urls.md`.

**No action proposed.** Recorded so the size is understood and the grouping
threshold doesn't get blamed for it. Revisit only if real traffic shows these
pages being abandoned.

---

## 8. Recommended order

1. **§5 SVG icons → CSS** — helps build *and* wire, no contract touched.
2. **§4 re-cut the emblem** — biggest first-paint win, one script + one commit.
3. Nothing else. §6 stays as-is; §7 has no fix.

Together: ~8 MB off the build (2%), ~575 B off every page, ~40 KB off first
paint. The build stays ~386 MB, because **the corpus is the corpus** — 365 MB of
it is Sinhala and Pali text at 3 UTF-8 bytes per character, and no amount of
markup work touches that.

**Do both in one deploy.** Each is a shared-chrome edit that invalidates all
14,752 hashes; shipping them separately pays the full ~390 MB push twice.
