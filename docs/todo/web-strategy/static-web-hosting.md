# Static Web — Hosting (Cloudflare Pages), SEO Plumbing & the App Boundary

> **Page-count figures are owned by
> [`reading-units-and-grouping.md`](./reading-units-and-grouping.md).** What this
> doc owns is the *invariant*: with stubs the total is always **16,356**, so the
> 20,000-file cap is never in play whatever the grouping rule does.
>
> Status: **Direction decided 2026-06-11; hosting reworked for Cloudflare Pages
> 2026-07-20** (the Dart content server is being retired).
> This is the **hosting + deployment + crawl-plumbing** companion to the build
> spec, [`static-html-site-plan.md`](./static-html-site-plan.md), which
> owns the *generator* and the page shape (zero-JS navigator, the 4 reading
> layouts, per-sutta-vs-grouped file boundaries). To avoid duplication, page-shape
> detail is **not** repeated here — this doc is only *where the files live and how
> crawlers find them.*
> The demoted Jaspr-rewrite analysis (Options compare, clean-architecture audit,
> shared-package extraction) now lives in [`jaspr/`](./jaspr/).
> Companion todo docs: [`../serverless-deployment-decision.md`](../serverless-deployment-decision.md)
> (backends), [`./deep-linking-and-shareable-urls.md`](./deep-linking-and-shareable-urls.md)
> (in-app link receiving + URL grammar).
>
> ⚠️ **URL identity** is the bare `nodeKey` under `/tipitaka/` (e.g.
> `/tipitaka/sn-2-3-1-3`), locked 2026-07-06 — **not** the older `/sutta/<textId>`
> examples that predate that decision.

---

## TL;DR — the two decisions

1. **Discoverability surface = a standalone, honest static HTML site** (SSG flat
   files, in the spirit of [buddhadust.net](https://buddhadust.net)) — **not** a
   Jaspr rewrite of the rich app. It serves SEO, LLM crawlers, bots, the slowest
   connections, and casual "read one sutta from a link" readers. Full rationale
   (Options A / A′ / B / C, and the built Jaspr prototype) is in
   [`jaspr/`](./jaspr/); the short version is below.
2. **Hosting = Cloudflare Pages, fully static, no content server.** The Dart
   shelf server is being retired: all read-only canon (per-page text + FTS +
   dictionary) moves **client-side into SQLite via [Drift](https://pub.dev/packages/drift)**
   — native FFI on mobile/desktop, **wasm + OPFS** in the browser (download-once)
   — so **Flutter web becomes a static bundle too.** The only backend left is the
   scale-to-zero **research (RAG) Worker**. Net: **zero always-on infrastructure**
   (source: [`../serverless-deployment-decision.md`](../serverless-deployment-decision.md)
   update 2026-07-16).

Keep Flutter for the native apps **and** the web app. The static site *links into*
the web app via a plain button — it never secretly becomes it.

---

## Why static, in three lines

Flutter web paints to `<canvas>` (CanvasKit), so crawlers and LLMs see an opaque
canvas, not "Brahmajāla Sutta… එවං මෙ සුතං…". Real static HTML fixes all three of:
**SEO**, **AI/LLM ingestion** (most LLM crawlers don't run JS at all), and
**slow-device reading** (no multi-MB WASM cold-start). We *route around* Flutter's
SEO gap rather than fixing Flutter web itself.

> **Watch-item — Option C (HTML-in-Canvas).** A Chrome origin trial that would let
> Flutter web embed real HTML (crawlable text, native selection) *without leaving
> Flutter* — the single-codebase endgame that could make both the static site and
> a Jaspr rewrite unnecessary. Experimental, Chrome-only. **Track, don't bank.**

---

## App ↔ site boundary — share the core, not the HTML (2026-06-14)

The generated HTML is a **build output of the web surface, not a content source
for the app.** Feeding the same HTML into the Flutter app (WebView / `flutter_html`)
to collapse the two pipelines was **rejected** — it forfeits the app's native text
selection, word-tap dictionary, and in-page search, and the 4 layouts are CSS on
the web but Flutter widgets in the app regardless. The shared seam is the
**structured content + `wisdom_shared` logic** both renderers already consume
(→ native widgets for the app, → HTML/CSS for the site), *not* the rendered HTML.

Companion app decision: the app's **reading unit is a single sutta** (micro-suttas
grouped by vagga), dropping continuous cross-sutta scroll. A bounded sutta is only
tens of entries, so the app renders it eagerly — cheap *and* preserving cross-page
text selection — which is why the [`../../done/both_mode_lazy_builder.md`](../../done/both_mode_lazy_builder.md)
lazy migration was dropped.

---

## Hosting on Cloudflare Pages — two static builds, one scheme

Two things ship as **static builds**; one **Worker** stays. Nothing is always-on.

| Surface | Build artifact | Served by | Indexed? |
|---|---|---|---|
| Static HTML site (apex: `/`, `/tipitaka/*`) | SSG (`static_site_generator/`) → flat `.html` | **Cloudflare Pages** (own project) | ✅ canonical |
| Flutter web app (`app.<domain>`) | `flutter build web` (JS/wasm bundle) | **Cloudflare Pages** (own project — see "Project topology") | ❌ noindex |
| Canon DBs (content+FTS, `dict.db`) | prebuilt `.db` blobs → **Drift wasm/OPFS**, downloaded once | **Cloudflare R2** (too big for Pages — see 25 MiB note) | ❌ |
| Research Q&A | TypeScript on **Cloudflare Workers** (scale-to-zero) | Workers | ❌ |

- **No content API on this origin.** Text / FTS / dictionary are *client-side*
  (Drift). The app's only network backend is the research Worker.
- **The DBs live on R2, not Pages** (per-file size — see the 25 MiB bullet below).
  The Flutter bundle and the static HTML are **separate Pages projects** (see
  "Project topology"); the heavy canon blobs sit on R2 (zero egress) and are
  fetched once into OPFS.
- **CORS now applies to the research call** (the app on Pages → the Worker on a
  different origin). Today it's pinned to the tester origin, with the App Check
  gate deferred (serverless doc §6). Content reads have *no* API, so *no* CORS.

### Free-tier fit — files, HTTPS, bandwidth (verified 2026-07-20)

All of this is the **free** Pages plan:

- **HTTPS is automatic and free.** Every project is served over HTTPS on
  `‹project›.pages.dev` out of the box (Cloudflare wildcard cert). A custom domain
  (`sammaditthi.app`) gets a **free auto-provisioned SSL cert** (Universal SSL) +
  HTTP→HTTPS redirect. This is precisely what lets the App-Links `.well-known`
  files (below) be fetched over real HTTPS — the OS requirement for Universal /
  App Links.
- **File cap = 20,000 files per project.** The whole corpus (canon + `atta-*` +
  `anya-*`) generates **16,356 files** with stubs, and that number is an
  *invariant*: leaves (14,351) + containers (2,004) + root, always —
  **the grouping rule does not move the file count at all** (an exploded vagga
  = 1 TOC + N pages; a grouped one = 1 chapter + N stubs — same N+1). Grouping
  is a UX/SEO choice, not a file-budget knob, and this bullet needs no update
  when the rule changes. The split between real pages and stubs *does* move and
  is owned by
  [`reading-units-and-grouping.md`](./reading-units-and-grouping.md); it only
  matters here if the P5 gate below picks edge redirects, in which case the
  total is the real-page count instead. Either way the content project sits at
  **≤82% of the cap, and its corpus is fixed** — remaining additions (sitemaps,
  CSS, `.well-known`) are dozens of files, not thousands. (Canon DBs are **not**
  in this count — R2, next bullet. The Flutter bundle isn't either — own
  project, see "Project topology".)
- **Bandwidth and requests are unlimited** on the static side — Googlebot, GPTBot,
  ClaudeBot and human readers never hit a metered wall. This directly serves the
  SEO / LLM-ingestion / slow-connection goals.
- **Single-file max 25 MiB — this is the one real gotcha.** Every generated HTML
  page is far under it — verified 2026-07-23: the largest text in the corpus is
  `vp-mv-1` (මහාක්ඛන්ධකං, 455 K chars ≈ ~1 MB raw HTML) and the shared full-tree
  `nav.html` is ~2 MB raw — both **>10× under the limit**. **But the canon
  databases are not:** the content+FTS DB (~140–165 MB) and `dict.db` (~167 MB)
  each blow past 25 MiB, so they **cannot be Pages files.** Host the DB blobs on
  **Cloudflare R2** (no per-file cap, **zero egress**, edge-cached — already the
  media/audio store, see the TTS plan), fetched **once** into OPFS on first load;
  after that they're local + offline. Chunked range-loading (sql.js-httpvfs) was
  **rejected** in favour of download-once (Drift-migration decision). Net: the
  file-count budget above is HTML + the Flutter bundle only — the heavy DBs live on
  R2, same Cloudflare account, different service.
- **`_redirects` rule caps: 2,000 static + 100 dynamic = 2,100 total (verified
  2026-07-22).** The content project now needs few or zero rules (the app moved
  to its own project) — but the cap still rules out per-sutta redirect rules for
  the grouped leaves, under every rule considered (a looser one breaks it harder).
  Grouped-leaf clean URLs are therefore never `_redirects` lines — they are
  **stub HTML files or Bulk Redirects** (P5 decision gate — see "Grouped-leaf
  clean URLs" below; build plan §6/§13.2).

### Build & deploy pipeline — CI builds, `wrangler` direct upload (DECIDED 2026-07-31)

*Who* runs the generator and *how* its output reaches Cloudflare. Nothing above
this line answered that — the only prior mentions of `wrangler` were a tooling-list
entry (prototype plan §11) and a table row (build plan §3).

**Generated HTML is never committed.** Measured 2026-07-31 against the P1 output:
`assets/text/an-1.json` is 588 K and its 110 pages come to 578 K of HTML, so output
runs **~1:1 with the source JSON** — the full corpus is therefore **~340 MB across
16,356 files** (~21 K/page) landing on a `.git` already at 694 MB. It is derived
data: corpus + generator determine it exactly, and byte-determinism holds from P1
(build plan §11.8). `static_site_generator/build/` stays gitignored. Committing it
would also make one CSS-token change rewrite the wrapper of all 16,356 files, and
the real diff would be unreviewable underneath.

**Cloudflare's own build system does not run the generator.** Dart ships in neither
image (verified 2026-07-31):

| Build image | OS | Preinstalled |
|---|---|---|
| Pages v3 | Ubuntu 22.04 | Go 1.24.3, Node 22.16.0, Bun 1.2.15, Python 3.13.3, Ruby 3.4.4, Hugo, Zola |
| Workers Builds | Ubuntu 24.04 | Go 1.24.3, Node 22.16.0, Bun 1.2.15, Python 3.13.3, Ruby 3.4.4, Hugo |

A `curl` + `unzip` of the SDK zip into `$HOME` from the build command would work —
no root required, and both images carry `curl` and `unzip` — but this is the wrong
place for it. Cloudflare would clone 694 MB of history, check out the 340 MB corpus
and pull ~200 MB of SDK inside a **20-minute hard timeout** on **1 concurrent
build** (free), all before an 85 ms/110-file generator starts. Untested here, and
unofficial Dart means an image bump could break the site silently.

**GitHub Actions → `wrangler pages deploy` (direct upload)** is the path. The repo
is public, so Actions minutes are free and unlimited; `dart-lang/setup-dart` is
first-class; and the generator has **zero third-party runtime dependencies**
(`wisdom_shared` declares none; `static_site_generator` has only `lints`/`test`
under dev), so `dart pub get` cannot break on a transitive update. Direct upload
bypasses Cloudflare's build system entirely — it consumes **none** of the free
plan's 500 builds/month — and uploads are hash-incremental, so after the first
deploy only genuinely-changed pages transfer. That is exactly the property P1's
determinism work bought (build plan §11.8). A local `wrangler pages deploy build/`
from a workstation is the same path driven by hand.

```yaml
# .github/workflows/deploy-static-site.yml — sketch, not yet written
on:
  push:
    branches: [main]
    paths: ['static_site_generator/**', 'packages/wisdom_shared/**',
            'assets/text/**', 'assets/data/**']
jobs:
  build-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4        # shallow — skips the 694 MB history
        with: { ref: main }             # NOT detached HEAD — see below
      - uses: dart-lang/setup-dart@v1
        with: { sdk: stable }
      - uses: actions/setup-node@v4
        with: { node-version: 22 }      # wrangler 4.112 `engines`
      - run: cd static_site_generator && dart pub get
      - run: ./scripts/static_site/deploy.sh --prod --yes
        env:
          CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          CLOUDFLARE_ACCOUNT_ID: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
```

**CI calls the script, not `wrangler` directly** (corrected 2026-08-02). The
earlier sketch invoked `cloudflare/wrangler-action` with a raw `pages deploy`,
which skips every guard the script exists for: the 20,000-file and 25 MiB
preflights, the account-identity check, the clean-tree/on-`main` release rule and
the whole-corpus rule. Two paths to production that enforce different things is
one path too many. The secret *names* match the variables `.prod.env` sets, so a
release by hand and a release by Action authenticate identically — the script's
own `set -a` sourcing is simply replaced by the runner's `env:` block. (The
script writes `--project-name` itself; the project is fixed per target, so there
is nothing left for the workflow to name or get wrong.) There is no separate
generate step either: `--prod` always builds, and `--skip-build` is refused, so
what ships is what the commit produces.

Two things that will bite when this workflow is actually written: **`ref: main`
is load-bearing** — `actions/checkout` normally leaves a detached HEAD, where
`git rev-parse --abbrev-ref HEAD` answers `HEAD` and the script's "a release must
be cut from `main`" guard rejects the run; and the runner needs **Node 22**,
because the script's nvm fallback only exists for this laptop and finds nothing
in CI.

**`--root all` is not optional** (added 2026-08-01). The corpus has seven disjoint
roots, so `--root` takes a list and `all` means every one of them. Omitting it
used to fall back to `an-1` — a 110-page fragment whose 32 අට්ඨකථා cross-links
point at pages under `atta-sp`, a root it never touched. The default is now
`all`, and `deploy.sh` passes it explicitly on every build rather than leaning on
that default — a deploy path should say what it ships.
Measured on this machine: whole corpus = **32 s**, 14,752 pages, 14,762 files,
212 MB (`sutta 12,748 / chapter 146 / TOC 1,858` — the counts this doc predicts,
short only the root index page, which is not generated yet).

**A local run of the same path** is `./scripts/static_site/deploy.sh` (added
2026-08-01): build → file-cap + 25 MiB preflight → account check →
`wrangler pages deploy`.

### Two targets, one per account — the deploy script's shape (2026-08-02)

| | Account | Auth | Project | Branch | URL |
|---|---|---|---|---|---|
| **dev** (default) | personal | `wrangler login` | `sammaditthi-dev` | `dev` | `dev.sammaditthi-dev.pages.dev` — preview, **noindex** |
| **prod** (`--prod`) | wisdom.ops | `.prod.env` token | `sammaditthi` | `main` | `sammaditthi.pages.dev` — **indexable** |

**The production project name is `sammaditthi`** (settled 2026-08-02, closing the
naming half of open-Q #2 below; the custom *domain* is still open). It is fixed
in the script rather than read from `.prod.env`, so an account and the project it
deploys into cannot drift apart — `.prod.env` holds credentials only, and a stale
`CF_PAGES_PROJECT_PROD` line in it is rejected rather than obeyed. There is no
`--project` and no `--branch`: the three settings above are right or wrong
together, never separately.

**Dev is a preview branch on purpose.** Cloudflare noindexes every preview
deployment and does not noindex the production alias — a dev copy of the canon
must not compete with the real site for the exact queries this whole effort
exists to win. `--prod` is opt-in, prompts once, and is the only indexable target.

**A release is the whole corpus at a commit.** `--root` and `--skip-build` are
refused on `--prod`, which must also run from a clean `main`. Direct upload
*replaces* the deployment, so a subtree shipped to prod would not add a partial
site — it would take the rest of the canon offline. (On dev that same replacement
is the point: `--root an-1,atta-an-1` is the fast iteration loop.)

**Deferred — script standardization** (worth doing after the first green prod
release, not before; it touches all three deploy paths at once):

1. One shared `scripts/lib/` for the Node ≥ 22 guard — copy-pasted verbatim in
   `research_server/{deploy,run}.sh` and `static_site/deploy.sh` today, so a
   wrangler `engines` bump is three edits.
2. One wrangler idiom in that lib: `research_server/deploy.sh` uses `exec npx
   wrangler`, `static_site/deploy.sh` the explicit pinned `node_modules/.bin`
   path. Same binary today, but only one reasoning can be right.
3. Give `research_server/deploy.sh` the same `whoami` account check. Account
   separation is now an invariant that only one of the two Cloudflare scripts
   enforces — the Worker deploy still lands wherever the login points.
4. `set -euo pipefail` in both wrangler scripts (`scripts/web/deploy.sh` already
   does; the others are bare `set -e`, so pipeline failures are masked).
5. Move `scripts/web/deploy.sh`'s `usage()` to the `END-USAGE` sentinel idiom —
   it slices a hardcoded line range today, which desyncs on any header edit.

Also parked: a dev deploy from CI is currently impossible by design — the dev
path refuses an exported `CLOUDFLARE_API_TOKEN`, which is the only way an Action
can authenticate. That guard is right for a laptop; a "push to `dev` → preview"
workflow would need an explicit dev-CI door rather than a loosened one.

**The file cap does not move on migration.** 20,000 files free is the *same* number
on [Workers static assets](https://developers.cloudflare.com/workers/static-assets/billing-and-limitations/)
(verified 2026-07-31), so the eventual Pages → Workers move — Cloudflare now steers
new projects to Workers, with Pages supported but no longer where feature work
lands — buys no headroom whatsoever. Paid raises both to 100,000. This belongs on
the P5 gate below: stubs park the content project at ~82% of a cap that no platform
change relieves.

Note the CI side-effect worth collecting: the workflow runner *has* the 340 MB
corpus, so `tool/verify_corpus_invariants.dart` — today marked "needs the corpus,
does not run in CI" (build plan §7) — can start running there.

### Project topology — one Pages project per surface (DECIDED 2026-07-23)

The earlier lean was path-split (`/app/*` inside the content project); **reversed
2026-07-23**. The 20 K file cap is *per project*, projects are free and unlimited,
and the surfaces gain nothing from sharing an origin:

| Project | Domain | Files (budget of 20 K each) |
|---|---|---|
| Static content site | apex (`<domain>`) | ~16.4 K — corpus is fixed, never grows |
| Flutter web app | `app.<domain>` | a few hundred (until/if retired) |
| ටීකා (sub-commentaries), when digitized | `tika.<domain>` | ~6–7 K projected (≈ `atta-*` scale) |

Why (recorded from the 2026-07-23 discussion):

- **URL ownership is unambiguous.** The locked shareable URLs
  (`/tipitaka/<nodeKey>`) belong to the apex static site alone — a link recipient
  always gets the instant ~20 KB static page, never a multi-MB wasm boot.
- **Independent deploys + budgets.** An app release doesn't redeploy 16 K content
  files; a broken app build can never touch the reading site; the Flutter bundle
  stops eating the content project's file budget.
- **Service-worker isolation becomes physical, not procedural.** Each subdomain
  is its own origin, so the Flutter SW *cannot* intercept/cache static pages —
  the path-split plan needed a "verify it stays scoped" step for exactly this
  risk; now it's structural. Same for caching: each project gets its own
  `_headers` tuned to its surface.
- **Capacity: ටීකා breaks a single project anyway.** Corpus split (measured
  2026-07-23): canon 9,414 files / 46 M chars, `atta-*` 6,731 files / 57 M chars,
  `anya-*` 210 files. A ටීකා layer at `atta-*` scale ≈ 6–7 K files would push one
  project to ~23.5 K — over the cap. Per-corpus projects dissolve the problem
  with zero new technology, still fully static, still free.
- **App retirement becomes trivial**: delete one project + one redirect; nothing
  on the apex changes and no shared link ever breaks.

Costs accepted: subdomains are separate origins, so **no shared browser storage**
(fine — the static site is near-stateless; the app's Drift/OPFS state is
app-only), cross-surface links must be **absolute URLs**, one extra DNS record +
custom domain per project (minutes, one-time, free). The **research-Worker CORS
pin must include the `app.` origin** when it goes live. The app project carries
its own SPA fallback (`/* /index.html 200`) — harmless there, and the dangerous
"global fallback swallows indexed static URLs" gotcha disappears because the
surfaces no longer share a project.

### Grouped-leaf clean URLs — stub files vs Bulk Redirects (P5 decision gate, 2026-07-23)

Something must answer at each grouped-leaf URL
(`/tipitaka/<leafKey>` → `…/<vaggaKey>#<leafKey>`). How many there are is owned
by [`reading-units-and-grouping.md`](./reading-units-and-grouping.md) and has
stayed well inside the 10,000 free quota under every rule considered. The
*requirement* is locked (exact-sutta links for no-app recipients, 2026-07-22);
the *mechanism* is a **P5 decision — do NOT generate the stubs without asking
the maintainer**:

- **Stub HTML files** (build-plan default): meta-refresh-0 + canonical →
  chapter. In-repo and portable, work on `*.pages.dev` previews, no zone
  needed. Cost: one file per grouped leaf, and a momentary blank stub before
  the jump.
- **Cloudflare Bulk Redirects** (verified 2026-07-23): an account-level
  redirect list serving **real edge 301s**; target URLs **may carry
  `#fragment`**; free quota = **10,000 list items / 5 lists — verified on the
  dev account 2026-07-23** (re-verify on the production wisdom.ops account at
  creation: dash.cloudflare.com → account → **Bulk Redirects**; the legacy-20
  issue was old-account rollout lag). Cleaner (one fewer file per grouped leaf,
  no stub flash), but needs the custom domain
  as a Cloudflare zone (inert on `*.pages.dev`) and the list lives in the
  dashboard/API — the generator should emit the leaf→chapter#fragment mapping
  as CSV either way, so switching mechanisms is a re-upload, not a rebuild.

Fallbacks if a project ever nears 20 K (not expected): Bulk Redirects (above),
a tiny redirect Worker, or serving a corpus from **R2** (no file-count limit
at all). None is planned.

### The nav button (static → app) and the root rule

- **Button:** a plain absolute link,
  `<a href="https://app.<domain>/tipitaka/<nodeKey>">Open in the full reader
  app →</a>` (cross-origin now — always absolute). **No `flutter_bootstrap.js`
  auto-boot on the static pages** — that auto-swap-into-canvas is exactly what
  made the rejected "Option A" hacky.
- **Root `/` is the content home *and* the landing page** (carries the app CTA) —
  never a contentless splash, and **never auto-redirect `/` → `/app`**. Auto-redirect
  would hand the strongest SEO/LLM URL to the un-indexable canvas and punish
  weak-device readers.

### Browser caching — the generated `_headers` (DONE 2026-08-15)

Pages' default on **every** response, measured on the dev deployment:

```
$ curl -sI https://dev.sammaditthi-dev.pages.dev/assets/site.css
cache-control: public, max-age=0, must-revalidate
etag: "0840bb1bb743cdd63511ce9b32711e43"
```

The bytes are cached, but must be revalidated before reuse — a conditional
request and a round trip. Every link here is a fresh document, so **each page
view paid that round trip for the stylesheet, `site.js`, the emblem and every
WOFF2 face it used** (8 faces / 328 KB, 2–4 per page), none of which change
between one sutta and the next. On the connections this surface exists for,
that was the whole point of being static, given away at the last step.

The SSG now emits `_headers` at the root of the upload
(`lib/render/cache_headers.dart`, built from the same path constants the build
writes, so a renamed asset cannot leave a rule pointing at nothing):

| path | policy | why |
|---|---|---|
| `/assets/*` | `max-age=31536000, immutable` | every URL in it carries a content hash |
| `/fonts/*` | same | same |
| HTML | *(absent — keeps the default)* | stable URL, changing content |

**Every cache token is computed by the build. There is nothing to bump.**
`lib/render/site_assets.dart` is the one place that decides them:

| file | token |
|---|---|
| `site.css` | hash of the CSS |
| `site.js` | hash of the script **and** the index |
| `search-index.json` | the same hash |
| `emblem.png` | hash of the image |
| `fonts/*.woff2` | one hash of all eight faces, carried in the CSS |

Two things to know before editing it:

- **A year of `immutable` is only safe when a new file means a new URL**, which
  is the whole reason every asset is hashed. The first cut of this shipped a
  hand-bumped `searchContractVersion` on `site.js` + the index, to be bumped
  "when a field moves" — which misses a corpus re-sync, a regrouped vagga and a
  matcher bug fix, each of which leaves a reader holding a stale index *for a
  year*, resolving to URLs that no longer exist. The script and the index still
  share **one** token, because `site.js` reads a row by field position and two
  hashes could drift apart; a hash of both keeps the pair atomic and busts on
  any edit to either.
- **Rules must not overlap on the same header.** Pages merges all matching
  rules and joins duplicate header names with a comma, so `/assets/*` beside a
  `/assets/emblem.png` exception would emit both policies in one
  `Cache-Control` rather than overriding. The two patterns above are disjoint,
  which is the only reason the file is this short. A rule setting a *different*
  header (a CSP on `/*`) can safely span both.

**Deploy cost.** A change to any asset rewrites the `<head>` of **every** page
— fonts included, since their token rides inside the CSS the pages link —
so the hash-incremental deploy re-uploads the whole build instead of a handful
of files. That is what `immutable` costs, and a hand-bumped token paid it too;
the option it is being bought over is no version at all, which the point above
rules out. Practical consequence: **batch asset work**, and expect a full upload
after a stylesheet tweak. Content edits are unaffected — they touch the pages
they touch.

### App Links / `.well-known` — static files on Pages

When the production domain is live, the OS-interception files are **plain static
files Cloudflare Pages serves directly** (no server needed):

- iOS/macOS: `/.well-known/apple-app-site-association` (`"paths": ["/tipitaka/*"]`).
- Android: `/.well-known/assetlinks.json` (+ `autoVerify` intent-filter in the app).

Details and the app-side receiver live in the deep-linking plan; the app code
needs no change — the OS just starts delivering `https` URIs through the same
`app_links` stream the dev custom scheme already exercises.

---

## SEO / crawl plumbing (owned here, per the prototype plan)

The prototype plan (§10/§12) delegates the crawl-discovery layer to this doc.
The SSG emits all of it as static files:

- **Per page:** `<title>`, `<meta name="description">`, `<link rel="canonical">`
  (self), Open Graph / Twitter Card tags (chat previews), JSON-LD
  (`Book` / `CreativeWork`), language attributes — `lang="si"` on the page,
  `lang="pi-Sinh"` (Pali in Sinhala script) on Pali blocks: screen readers +
  crawler language detection, zero cost (2026-07-22).
- **`sitemap.xml`:** one `<url>` per **distinct sutta file + chapter file** (not
  the content-free redirect stubs) — this is what takes Google from "found one
  page" to "indexed ~13,000 pages" (full-canon count, §"Free-tier fit" above).
  Emit **`<lastmod>` per URL from the build manifest's content hashes**
  (2026-07-23 — the manifest already knows exactly which outputs changed): after
  a text correction Google recrawls just the changed pages fast, the C1 payoff.
- **`robots.txt`:** apex — allow crawl, point to the sitemap (no `/app/` rule
  needed anymore).
- **Keep the app out of the index — `noindex`, NOT `Disallow` (fixed 2026-07-23):**
  the app project sends `X-Robots-Tag: noindex` on every response (one
  `_headers` rule: `/*` → `X-Robots-Tag: noindex`) and its `robots.txt`
  **allows** crawling. The earlier `Disallow: /` idea backfires: a robots.txt
  block stops Google from ever *fetching* the page, so it never sees a noindex —
  yet every static page links `https://app.<domain>/tipitaka/…` ("Open in app"),
  so those URLs could still index as bare "indexed, though blocked by
  robots.txt" entries. Crawl-then-noindex removes them properly. (The Flutter
  `index.html` may keep `<meta name="robots" content="noindex">` as
  belt-and-braces.) Static pages canonical to their own apex `/tipitaka/...`
  URL, **never** to the `app.` origin.
- **Not cloaking:** the static site shows the *same* HTML to bots and humans;
  the Flutter app is a clearly separate surface the user opts into via the button.

---

## Open questions (post-server)

1. ~~**Static-site search.**~~ **Settled and built, 2026-08-14** (build plan P4).
   Server-rendered FTS stays gone with the content server; what shipped is a
   **client-side index over node names only** — 254 KB gzipped / 180 KB brotli,
   fetched on first dialog open rather than on page load, so a reader who never
   searches pays nothing for it. That is what answers the zero-JS objection this
   question raised against option (c): every page still renders, navigates and
   switches layout with JS off, and the search button simply never appears.
2. **Production domain** (`sammaditthi.app`?) — feeds canonical URLs, OG tags, and
   the App Links `.well-known` files. **Production Cloudflare account
   (2026-07-23): a separate account under wisdom.ops is planned** (today's
   personal account stays dev — it runs the research Worker). Everything
   production must land in that ONE account: the Pages projects, the
   custom-domain zone, R2, and the Worker (Bulk Redirects only fire on a zone
   in the same account; the Worker needs a re-deploy + CORS re-pin from there).
   ~~Pages *project* names.~~ **RESOLVED 2026-08-02: `sammaditthi` (prod) and
   `sammaditthi-dev` (dev)**, fixed in `scripts/static_site/deploy.sh` — see
   "Two targets, one per account" above. Only the **domain** is still open; the
   two are independent, since a project keeps its `.pages.dev` name whatever
   custom domain is later attached.
3. ~~One Pages project (path-split) vs two (subdomain).~~ **RESOLVED 2026-07-23:
   one project per surface** — apex = static content, `app.<domain>` = Flutter
   web, `tika.<domain>` = ටීකා later (see "Project topology" above).
4. **`LINK_BASE_URL`** for shared links moves from the `:8080` dev server default
   to the Pages production domain (deep-linking plan).

---

## Superseded — the old shelf-server hosting model (kept for provenance)

The former model served **both** surfaces from one origin via the Dart `shelf`
server: ordered prefix routing in `server_app.dart` (`healthz` / `api/` / `app/` /
static), gzip + cache middleware, `/api/…` same-origin (so "no CORS"), and a
global `index.html` fallback scoped to `/app/`. That is **retired with the content
server** (canon → client-side Drift; research → Worker). The *intent* carries over
— root is the content home, the app never swallows content URLs — but the
**mechanism** changed twice: first to Cloudflare Pages path-split (`/app/*` +
`_redirects`), then **2026-07-23 to one Pages project per surface** (app on
`app.<domain>` — see "Project topology"). The old per-sutta HTML was going
to be rendered by a shelf handler *or* SSG; now it is **only** SSG flat files.
