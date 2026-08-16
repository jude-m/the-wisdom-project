# Static site backlog

Every small, independently shippable item on the apex static site — search
performance, build size, and the leftovers from review. None of these blocks
anything; each can go on its own.

**Scope:** the apex static site only. `app.<domain>` stays `X-Robots-Tag:
noindex` (crawlable, not indexed) and the Flutter payload there is a separate
problem with separate tooling — see `static-web-hosting.md`.

**Cross-refs.** Phasing lives in `static-html-site-build-plan.md`; the deploy
path in `static-web-hosting.md`; **all page-count figures in
`reading-units-and-grouping.md`**, which owns them. Where an item below is also
named in the build plan, the build plan owns the schedule and this doc owns the
reasoning. Don't restate a decision in both.

> **Merged 2026-08-15** from `seo-wins.md`, `reduce-bundle-size.md` and
> `further-improvements.md`. Three ranked lists of the same kind of item, each
> carrying its own snapshot of the build — and by the merge they disagreed. The
> corrections are marked ⚠ below.

---

## Measured state — 2026-08-15

One place, so no item below has to carry its own copy.

```
build/                      425 MB
├── tipitaka/               422 MB   14,752 HTML pages
├── assets/                 2.2 MB   search-index.json 2,248,384 B
│                                    site.js 20,882 · site.css 16,206 · emblem.png 47,115
└── fonts/                  336 KB   8 woff2 subsets
```

Page size distribution, bytes (measured on the 2026-08-09 build, before the
search dialog landed):

| min | p50 | p90 | p99 | max | mean |
|---|---|---|---|---|---|
| 1,446 | 11,774 | 54,055 | 230,712 | 1,364,020 | 25,953 |

Compression, corpus-wide sample: **gzip = 18.7% of raw**. A median page:
11,689 raw → 3,091 gzip → 2,567 brotli. Cloudflare Pages negotiates brotli
automatically for text types; nothing to configure.

Missing at this date: `404.html`, `sitemap.xml`, `robots.txt`,
`<meta name="description">`. `_headers` exists.

⚠ **Correction on the merge.** `reduce-bundle-size.md` measured 394 MB and
`site.css` at 12,578 B against the 2026-08-09 build. **P4's search dialog added
~31 MB** — 2.2 MB of search index plus a script tag and dialog markup on all
14,752 pages. Both figures above are current.

## Two different "sizes" — don't conflate them

Every size item moves exactly one of these, and they have different stakes:

| | Number | Who pays | Stakes |
|---|---|---|---|
| **Wire size** | ~2.6 KB brotli for a median page | every visitor | already excellent |
| **Build size** | 425 MB on disk | the deploy | this is the painful one |

The site's stated audience — slow connections, crawlers — is served by the wire
number, and that number is already good. **Build size is a deploy problem, not a
user problem.** It matters because a shared-chrome edit invalidates all 14,752
content hashes and forces a full push, which is where the deploys documented in
`static-web-hosting.md` fail.

Optimising for build size at the cost of wire size would be backwards. Nothing
below does that; several items help both.

## What already works — don't regress it

Worth stating, because most static sites pay for these and this one gets them
free.

- **One stylesheet, self-hosted subset fonts** with `font-display: swap`
  (`stylesheet.dart:216`). Core Web Vitals should be near-perfect out of the box.
- **Zero inline CSS.** Verified 2026-08-10 three ways: no `style="` and no
  `<style>` in `lib/` or `bin/`, and neither pattern in any built file. Every
  page carries one `<link rel="stylesheet">` and nothing else. Inline CSS is not
  a lever here because there is none.
- **Zero inline JS.** ⚠ *Both source docs claimed "zero JS" outright; that is no
  longer true.* All 14,752 pages now carry a `<script src>` for the search
  dialog. What survives is the stronger property: **no inline script, no inline
  event handlers, no `eval`** — `site.js` builds result rows with
  `createElement`/`textContent`. That is what keeps the strict CSP in Part C
  available with no refactor.
- **The `<title>` grammar** — `<leaf> — <vagga> — <collection>`
  (`page_template.dart:476`, built by `_titleText` at `:486`). This is doing
  nearly all the keyword work on the
  site. It exists because 1,165 leaves are titled with only a number and 2,216
  share a name; without the trailing parts, thousands of pages would carry an
  identical `<title>`, which is the duplicate-content signal C2 was written to
  avoid.
- **Self-canonical on commentary.** The `atta-*` pages point at themselves, never
  at their canon twin — they're different texts, not duplicates.
- **One text, one URL.** The grouped-vagga rule means no passage is ever
  reachable at two addresses, so there is no internal duplicate-content problem
  to clean up later.
- **No dead font faces.** All four weights (400/500/600/700) are requested by
  real rules in the built CSS, against both families — so all 8 WOFF2 subsets
  earn their place, and browsers fetch only the faces a page actually renders.
  Don't spend time pruning these.
- **Markup is already tight.** Mean 2.2 indented newlines per page; HTML
  minification would recover essentially nothing.

---

# Part A — Search performance

## A1. `404.html` — missing

Nothing in the generator writes one and there is none in the build.

Cloudflare Pages needs a `404.html` at the output root to serve a real 404.
Without one it falls back to `index.html`, so — as observed on 2026-08-03 —
**every missing path returns HTTP 200**, serving the landing page complete with
`<link rel="canonical" href="/">`. Google classifies that as a **soft 404**, and
the canonical tag actively tells it these are all the same page.

At 16,356 addresses the surface for typo'd and stale inbound links is large, and
soft 404s spend crawl budget and get logged as quality problems against the whole
site. This is the worst item on the list and the cheapest to fix.

The page should carry the toolbar and a link back to `/`, so a wrong URL still
lands somewhere useful.

**Verify after deploying:** `curl -I https://<host>/tipitaka/does-not-exist`
must return `404`, not `200`.

## A2. `<meta name="description">` — missing

`document_shell.dart:66-71` emits six things: charset, viewport, title,
canonical, stylesheet, generator. No description.

Google writes the SERP snippet from the description when there is one and from
scraped page text when there isn't. Scraped text on a canon page is the opening
line of Pali — accurate, but it tells a searcher nothing about what they found.
This is the **click-through** lever, and it's the largest one available.

Descriptions have to be generated, not written — there are thousands. The
material is already on hand: node name, its place in the tree, the collection,
and how many suttas the page holds. Something like *"<leaf>, from <vagga> of
<collection>. Pali with Sinhala translation."* Keep it under ~155 characters and
never emit an empty one — no description beats a blank description.

`/` gets a hand-written description, not a generated one. It's the highest-value
page on the site.

## A3. `sitemap.xml` + `robots.txt` — missing

Neither is generated. Discovery currently depends entirely on Google crawling the
TOC chain down from `/`.

- **`sitemap.xml`** — all pages, one file (the 50,000-URL / 50 MB limit is not
  close). `<lastmod>` from the manifest hashes, as P5 already specifies, so a
  rebuild that doesn't change a page doesn't claim it changed. Lying in
  `<lastmod>` gets the whole signal ignored.
- **`robots.txt`** — allow all, plus a `Sitemap:` line. That line is the main
  reason the file needs to exist; the apex has nothing to hide.

Note the app origin is handled differently and deliberately: `X-Robots-Tag:
noindex` on `app.<domain>`, **not** `Disallow`. Disallow would block the crawl
and the `noindex` would never be read.

## A4. Absolute canonical — currently root-relative

`document_shell.dart:13-15` parks this on purpose: an absolute canonical needs a
settled apex domain, and a wrong one points every page at a host that doesn't
serve it. That was the right call at the time.

The domain is settled now, so this is unblocked. Relative canonicals are legal
and resolve against the document URL, but they can't do the one job canonicals
are for — telling Google which of several hosts serving identical bytes is the
real one. Preview deployments are covered today by Cloudflare's automatic
`noindex`, so this is insurance rather than a live bug. Do it when the domain is
wired.

## A5. Open Graph tags — missing

Parked at P5 alongside JSON-LD. Not a ranking factor at all — this is the
**sharing** story, and for this audience sharing happens in WhatsApp and
Facebook, not in search results. A pasted link with no OG tags renders as a bare
URL; with them it renders as a card carrying the sutta name.

`og:title` (un-welded per D2, same as `<title>`), `og:description` (reuse A2),
`og:url`, `og:type`, `og:site_name`, `og:locale`. An `og:image` needs a real
image — a generated one per page is out of scope, so a single site-wide image is
the sane version. See B1: the OG raster is its own file, not the toolbar emblem.

## A6. JSON-LD structured data — missing

Also parked at P5. The one with visible payoff is **`BreadcrumbList`**: it
replaces the URL line in a search result with the readable trail, which is worth
more to a browsing reader than the path ever was. The tree already has
everything needed — the breadcrumb is built in `site_chrome.dart:122`.

Beyond that, `Book` / `Chapter` for the canon structure is defensible but has no
rich-result treatment, so it's speculative. Do `BreadcrumbList` first and stop
there unless there's a reason not to.

## A7. Pali text isn't marked as Pali

Every page is `<html lang="si">` (`document_shell.dart:64`), and the Pali cells
carry no `lang` of their own — they inherit Sinhala.

The Pali *is* in Sinhala script, so the rendering is right, but the language
declaration isn't: `lang` is a language attribute, not a script one. The correct
value on `.pali` cells is `lang="pi-Sinh"` — Pali, Sinhala script.

Modest SEO effect (it sharpens language targeting on pages that are half
non-Sinhala). Real accessibility effect: a screen reader currently pronounces
Pali using Sinhala rules.

## A8. Duplicate headings when both languages render

Flagged in the build plan (§ around line 727) and carried to P5: rendering both
languages emits two `<hN>` per heading row, so the document outline says
everything twice. Rendering only one would leave the single-language layouts with
no outline at all, which is why it wasn't fixed inline.

Low priority — Google is tolerant of messy outlines — but it belongs on this list
because the fix probably falls out of the structured-data work rather than
standing on its own.

## A9. Preload the primary font

`font-display: swap` is set, so there's no invisible-text stall. But the font
request can't start until the stylesheet has been fetched and parsed, which puts
it two round-trips deep on the critical path.

One `<link rel="preload" as="font" type="font/woff2" crossorigin>` for the single
most-used weight would pull that forward. Only the primary weight — preloading
fonts a page never uses is a net loss. Worth measuring before and after rather
than assuming.

## Not worth doing

- **Shortening `/tipitaka/` in the URL.** Words in the URL are a very small
  ranking factor by Google's own repeated guidance. The `<title>` and `<h1>` do
  that work. The segment is worth keeping for reasons that have nothing to do
  with SEO — it scopes AASA/assetlinks to `/tipitaka/*` instead of `/*`, and the
  codec is shared with the app.
- **Keyword-stuffing titles.** The current grammar is already at the right
  density; adding "Tipitaka" or "Buddhism" to every title would read as spam and
  dilute the part that identifies the page.
- **Backlink or directory schemes.** The site earns links by being the readable
  copy of the canon, or it doesn't earn them.

---

# Part B — Size

## B1. Re-cut `emblem.png` — 47 KB → ~5 KB

`assets/emblem.png` is a 200×200 RGBA PNG rendered at 28×28 in every toolbar
(`render/site_chrome.dart:69`). At 47,115 bytes it is the heaviest single thing
a first-time visitor downloads apart from a font — **2.9× the entire
stylesheet**, to paint a 28px mark.

**The 200px size is already a reasoned decision, and this argues against it.**
`assets/make_emblem.sh` documents two reasons for not re-cutting to ~84px: the
bytes are paid once and cached site-wide, and P5's OG card wants a raster larger
than the toolbar does. Both are true; neither survives closely:

- *Paid once* is exactly the first-paint request. On the slow connections this
  site exists for, 47 KB before first paint is the worst-placed 47 KB on the
  site — and it isn't shared with anything, because…
- *The OG card needs its own file anyway.* OG images want ~1200×630; a 200×200
  square is the wrong shape and too small regardless. A5 will cut a dedicated
  raster, so the toolbar mark is not subsidising it.

**Action:** re-cut to 56×56 (2× for a 28px mark) in `make_emblem.sh`, expect
~4–6 KB, commit the output. If A5 wants an OG raster, add it as a second file.
Build-size gain is trivial; **first-paint gain is ~40 KB**, the largest available.

## B2. Move the toolbar SVG icons into the stylesheet — ~8 MB

Three icons are emitted verbatim into all 14,752 pages:

- the up-arrow — `render/site_chrome.dart:181` (`_upGlyph`)
- side-by-side and stacked layout marks — `render/reading_layouts.dart:71,77`,
  sharing `_iconFrame` at `:103`

That's **575 B/page → 8.1 MB corpus-wide** for three shapes that never change.
Declaring them once in `site.css` as `mask-image` data URIs moves them into the
one file every visitor already caches.

This is the only item that improves **both** numbers meaningfully: ~8 MB off the
build, and ~575 B off every single page's wire payload.

Watch the details — `currentColor` stroke becomes `background-color` under
`mask-image`, and the icons must stay invisible to assistive tech exactly as
`aria-hidden="true"` makes them today.

Per-page repeated chrome for context, measured over a 400-page random sample
(pre-search-dialog):

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

## B3. Trim the per-page head — ~2.8 MB, and don't

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

## B4. Known limit: 195 fat pages carry 18% of the build

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
**single leaves that are genuinely one enormous text**, and the grouping
threshold neither caused them nor can relieve them: grouping only ever merges
small things.

At ~250 KB gzipped, `vp-mv-1` is the worst reading experience on the site — and
it is irreducible under the locked URL model, where one nodeKey is one page.
Splitting it would mean inventing sub-leaf URLs that don't exist in `tree.json`,
which reopens the deep-link contract in `deep-linking-and-shareable-urls.md`.

**No action proposed.** Recorded so the size is understood and the grouping
threshold doesn't get blamed for it. Revisit only if real traffic shows these
pages being abandoned.

## B5. The search index is now the second-largest asset

`search-index.json` is 2,248,384 B uncompressed (~252 KB gzip, which is the
number that matters — it is fetched on first search, not on page load). New since
the two size docs were written, and the reason `build/assets/` went from 64 KB to
2.2 MB.

No action proposed; recorded so it is not rediscovered as a regression.

## B6. The 29% no markup edit can reach — and why to stop trimming

Brotli compresses by pointing back at repeats it has already seen, and **its
memory covers one response**. Every page is compressed from a blank slate, so
the `<head>`, toolbar, pager and search dialog are spelled out in full 14,752
times — even though the reader downloaded all of them on the previous page.

Measured by handing the compressor a sibling page first: `br(A+B) − br(A)`
against `br(B)`, over 150 random pages, `A` a real page from the build.

| | brotli B/page |
|---|---|
| page compressed alone (today) | 4,741 |
| with a sibling page already in the window | 3,360 |
| **repeated chrome** | **1,381 — 29% of a page** |

**Raw bytes are not wire bytes, and this is where the two part company.** Every
other figure in Part B is raw, which is right for the build and the upload and
wrong for what a reader waits on. Repeated markup is the most compressible thing
on a page, so hand-trimming it returns a fraction of its raw weight:

| | raw B/page | brotli B/page |
|---|---|---|
| B2's three toolbar icons | 581 | **92** |
| all five inline SVGs (incl. search, close) | 981 | 232 |
| search dialog + trigger | 1,757 | 400 |

⚠ **Correction to B2.** It is still worth doing for the ~8.6 MB it takes off the
build, but "~575 B off every single page's wire payload" is a raw number; the
wire saving is **~92 B/page, 1.4 MB corpus-wide**. Step 5 of the order repeats
the same figure.

**Compression Dictionary Transport** collects the whole 1,381 B without touching
a template: page 1 is served with `Use-As-Dictionary`, the browser keeps it, and
the next navigation sends `Available-Dictionary` so the server compresses
against it — the measurement above, in production.

**Why it waits.** Pages serves files off a disk; picking a dictionary per request
and compressing against it needs a Worker in front. Chrome ships CDT, Safari and
Firefox do not, so it is a bonus tier and never the baseline.

**No action proposed.** Recorded as the standing answer to "this repeated markup
looks wasteful". The search dialog is 400 B of the 1,381 and the toolbar icons
92 B; the only edit that collects a meaningful share of the rest by hand is
moving the dialog's markup into `site.js`, which puts Sinhala and URLs back in
the script and is forbidden by `CLAUDE.md`. Measured 2026-08-16 — re-measure
before acting, the chrome has grown twice already.

---

# Part C — Correctness and hygiene

Opened 2026-08-15 out of the review of the P4 search dialog and the `_headers`
caching work. What that review found and we *did* fix — the hand-bumped cache
token, the `/fonts/*` literal, the wrong 404 message — is recorded in
`static-web-hosting.md` and `render/site_assets.dart`, not here.

## C1. Tests for `buildCacheHeaders()` and the asset wiring

**Not hygiene — the one hazard the `_headers` work introduced.** Everything else
in Part C is a tidy-up that fails visibly. This one fails silently, on other
people's machines, for a year. Rank it above C2.

**Why it waited:** tests in this repo are written on request, not by reflex.

Nothing currently tests `render/cache_headers.dart` at all, and the wiring test
hard-codes its asset URLs (`?v=test`), so the hashing in `sitegen.dart` is
uncovered — an unhashed build would ship green. Three belong in
`test/wiring_contract_test.dart`, which already exists to catch exactly this
class of bug (two files that must agree with nothing connecting them):

| test | catches |
|---|---|
| no two `_headers` rules match the same path | the comma-join hazard the whole file is shaped around — Pages merges matching rules and joins duplicate header names, so an overlap silently emits two policies in one `Cache-Control` |
| every non-wildcard rule names a file the build writes | a renamed asset leaving a rule pointing at nothing |
| a page's `<link rel="stylesheet">` equals `SiteAssets.forContent(...)`'s | the hashing wiring itself, which no test sees today |

Collapsing to `/assets/*` made the third of those matter more than it did.
Five exact paths failed **safe**: an asset with no rule of its own simply kept
the revalidating default, so forgetting one cost speed. A wildcard fails
**unsafe** — anything that lands in that directory linked without a `?v=` is
served `immutable` for a year, so forgetting one costs a year of a stale file on
readers' disks. "Every asset URL comes from `SiteAssets`" went from a tidiness
convention to the load-bearing invariant of the whole caching scheme, and
nothing enforces it.

Three properties make that worth a test rather than care:

- **Purging Cloudflare's cache does not fix it.** That clears the edge, not the
  copy on a reader's disk, and no API reaches a browser cache. The only exit is
  to change the URL — i.e. add the `?v=` that was missing — which rewrites every
  page's `<head>` and re-uploads the full ~425 MB.
- **You will not notice.** Hard-refresh bypasses the browser cache, so the bug
  is invisible to whoever shipped it and visible only to readers who already
  loaded the page once.
- **It is silent at build time.** An unhashed asset produces a valid build, a
  green deploy, and a correct-looking page.

The properties `SiteAssets` is supposed to hold are cheap to assert and were
verified by hand once (2026-08-15, all passing): same inputs → same URLs;
editing the CSS moves only the stylesheet URL; editing *either* `site.js` or the
index moves **both** of their URLs; editing the emblem moves only the emblem;
and the NUL join makes `("ab","c")` and `("a","bc")` hash differently.

## C2. A Content-Security-Policy header

**Why it waited:** it changes the response headers on every URL, which is its
own change to deploy and verify — not something to fold into a caching diff.

`_headers` is now the file where one goes, and the site already qualifies for a
strict policy **with no refactor**. Verified on the full build: zero `<form>`,
zero inline event handlers, zero inline `<script>`, zero `style=` attributes,
and `site.js` builds result rows with `createElement`/`textContent` and calls no
`eval`.

```
/*
  Content-Security-Policy: default-src 'self'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'
```

`/*` overlaps the two `Cache-Control` rules, which is safe: the merge hazard is
per header *name*, and this is a different one.

Live headers already carry `x-content-type-options: nosniff` and
`referrer-policy: strict-origin-when-cross-origin` from Pages' own defaults; CSP
is the one that is missing.

## C3. `.manifest.json` is publicly fetchable

**Why it waited:** it is harmless, and the fix belongs with the `404.html` work.

Measured on the dev deployment (2026-08-15): `GET /.manifest.json` → `200`,
595 KB. It is the source-file → output-path map with content hashes — nothing
secret, nothing linked from any page, and it has to stay in `build/` because
`_clearOutputDir` uses it as the marker that says "this directory is mine".

If it ever matters, the fix is a rule in `_headers`, not a deletion:

```
/.manifest.json
  X-Robots-Tag: noindex
```

Worth doing in the same pass as A1 (`404.html`), since that is when unknown and
non-page URLs get their answer sorted out generally.

## C4. The preview server does not apply `_headers`

**Why it waited:** the preview deliberately serves `no-store` so you always see
the build that is on disk right now, and a `_headers` parser would be a second
implementation of Cloudflare's semantics to keep in sync — including the
merge-and-comma-join rule that is the easiest part to get wrong.

`tool/serve.dart` mirrors the two Pages behaviours the *output* depends on (the
extensionless rewrite and the `.html` → 308) plus a 404 on `/_headers` itself.
It does not mirror caching, so a mistake in the rule set is invisible locally.

The honest test is a real Pages preview deploy (`scripts/static_site/deploy.sh`)
and a `curl -I`. Revisit only if the rule set ever grows past the two lines it
is today.

## C5. `utf8.decode` on the way to hashing `site.js`

**Why it waited:** it cannot fire on a committed file, and it is a one-line
change to a path that is otherwise correct.

`SiteGenerator.generate` reads `site.js` as bytes, decodes it to a `String`
only to hand it to `SiteAssets.forContent`, which encodes it straight back to
hash it. The round trip does not change the digest — the comment there says so
and it is right — but it is the only step in the asset path that can *throw*:
`utf8.decode` rejects a malformed sequence with a `FormatException`, failing a
whole build over a file it never needed to interpret.

Hashing the bytes directly drops the round trip and the failure mode with it,
at the cost of `forContent` taking `List<int> script` and joining on a `0`
byte rather than the NUL string literal it uses today:

```dart
contentHashOfBytes([...script, 0, ...utf8.encode(searchIndex)])
```

That literal is one `0x00` in UTF-8, so this is the same digest over the same
bytes: no URL moves, and no page re-uploads because of the change.

---

# Order to do them in

1. **A1 `404.html`** — a correctness bug, not an optimisation. Take C3 with it.
2. **C1 the asset-wiring tests** — before the next asset change, not after. A
   `/assets/*` miss is unrecallable for a year and silent at build time, and
   steps 5 and 9 below are both asset changes.
3. **A3 `robots.txt` + `sitemap.xml`** — discovery for 16K addresses.
4. **A2 `<meta name="description">`** — the click-through lever.
5. **B2 SVG icons → CSS** and **B1 re-cut the emblem** — *in one deploy.* Each is
   a shared-chrome edit that invalidates all 14,752 hashes; shipping them
   separately pays the full push twice. Together: ~8 MB off the build, ~575 B off
   every page, ~40 KB off first paint.
6. **A4 absolute canonical** — cheap now that the domain is settled.
7. **A5 OG tags** — distribution, and this audience shares in messaging apps.
8. **A6 `BreadcrumbList` JSON-LD.**
9. **C2 CSP** — its own deploy and verify.
10. **A7 `lang="pi-Sinh"`** — mostly an accessibility fix.
11. **A9 font preload, A8 heading duplication** — measure first, both are small.

No action: **B3** (keep the provenance), **B4** (no fix exists), **B5**
(recorded only), **B6** (needs a Worker). **C4** and **C5** are hygiene — do them
when touching the code they cover, not as a campaign.

The build stays ~417 MB after all of it (425 less B2's ~8 MB; B1 is ~40 KB and
does not show), because **the corpus is the corpus** — **365 MB of the 394 MB
2026-08-09 build was Sinhala and Pali text** at 3 UTF-8 bytes per character, and
no amount of markup work touches that. The page-count reduction in
`reading-units-and-grouping.md` is the only change that moves the total
meaningfully.
