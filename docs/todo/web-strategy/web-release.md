# Web Release

> **Opened 2026-09-11.** The checklist for putting the two web surfaces live.
> Open *work* lives in [`static-site-backlog.md`](./static-site-backlog.md);
> hosting, topology and `_headers` in
> [`static-web-hosting.md`](../../decisions/static-web-hosting.md); the bar the
> site has to clear in
> [`static-site-constraints.md`](../../decisions/static-site-constraints.md); how
> it was built in `docs/done/web/`. This doc owns the release itself and the CI
> that runs it, and nothing else.
>
> **Scope: the apex static site.** Flutter web is not in this release — the
> placeholder at the end says why.

---

## The blocker

**The production Cloudflare account does not exist yet.** A separate account
under wisdom.ops is planned; today's personal account stays dev (it runs the
research Worker).

Everything production must land in that **one** account — the Pages projects, the
`sammaditthi.net` zone, R2, and the research Worker. Bulk Redirects only fire on
a zone in the same account, and the Worker needs a re-deploy plus a CORS re-pin
from there. Pages projects **cannot be moved between accounts**.

**Attaching the apex to the `sammaditthi` project is the next physical step, and
it must happen before the first `--prod`.** Until then a release bakes
canonicals, `og:url`s and every sitemap entry with an origin nobody can resolve.

---

## 1. Before the release build

Ranked. Only the first is a must.

| | item | why |
|---|---|---|
| **must** | **C9 — HTML validator over a full build** | The last unshipped verification. Every page comes off one template, so a markup defect ships to the crawler on all of them. Cheap now, a full re-push later. |
| should | **C1 — asset-wiring tests** | The one failure that is silent at build time and unrecallable for a year. `/assets/*` is a wildcard `immutable` rule; an asset linked without a `?v=` is cached on readers' disks and no purge reaches it. |
| should | **B2 + B1 in one deploy** | Toolbar SVGs into the stylesheet, re-cut the emblem. Both edit shared chrome, so shipping them apart pays the full push twice. Do them before the first prod push or well after it, never between. |
| should | **C2 — CSP header** | One `_headers` line; the site already qualifies for a strict policy with no refactor. |
| optional | A9 font preload, A8 heading duplication | Small, measure first. |

All five are specified in [`static-site-backlog.md`](./static-site-backlog.md).

---

## 2. Verify the build

**Lifted from the archived site plan §11**, which was the only live procedure in
it. `deploy.sh` already enforces the first three; the rest is by hand.

**Automatic, in `deploy.sh` — a release forbids `--root` and `--skip-build`
both, so what ships is always the whole corpus and always checked:**

- the baked origin matches the deploy target, and every canonical names it
- `robots.txt` carries the matching `Sitemap:` line
- `check_links.dart` — every internal reference and every `#fragment` resolves,
  case-exact, no duplicate ids; it fails on zero links or zero fragments, so a
  pattern that stops matching cannot pass by checking nothing

**By hand, once:**

1. **Determinism — the hard one.** Rebuild with no input change → **zero** files
   differ. Cloudflare's upload dedup is purely content-hash, so a timestamp, a
   build id or unstable `Map` ordering re-uploads the entire site every deploy.
2. **Re-sync.** Edit one entry in a content file, rebuild → only the affected
   outputs change in `git status`.
3. **JS off** → every page still renders, navigates and switches layout; the
   search button simply never appears.
4. **Webfont off** → system Sinhala is readable.
5. **Back/Forward across `#anchors`** → the `:has(:target)` filter re-evaluates.
   Degradation is the whole chapter scrolled to the anchor, which is acceptable.
6. **From several page shapes** — leaf, chapter, container TOC, `/` — the
   breadcrumb climbs and the toolbar reaches home.
7. **No text in two files.** `grep` a distinctive phrase across `build/` →
   exactly one file.

---

## 3. Deploy

1. **Dev preview first** — `sammaditthi-dev`, preview branch `dev`. Kept out of
   the index by `X-Robots-Tag: noindex`, which is free on previews.
2. **Prod** — `./scripts/static_site/deploy.sh --prod --yes`.

Both project names are hardcoded in `deploy.sh`; `.prod.env` is credentials only.
If a deploy dies with `Error: {})` and no message, the real cause is only in
`~/Library/Preferences/.wrangler/logs/`. Never run two deploys at once — there is
no lock, and the second wipes `build/` mid-upload.

---

## 4. After the first prod deploy

- [ ] `curl -I https://sammaditthi.net/tipitaka/does-not-exist` → **404, not 200**.
      This is owed from backlog A1: the soft-404 fix shipped but has never been
      checked against live Pages, and it is the one defect that silently told
      Google every missing URL was the front page.
- [ ] `curl -I` an asset → `immutable`; a page → revalidating. The preview server
      does not apply `_headers` (backlog C4), so this is the first honest test.
- [ ] A canonical, an `og:url` and a sitemap `<loc>` all name `sammaditthi.net`.
- [ ] CSP present, if C2 shipped.
- [ ] Search Console: submit `sitemap.xml`.
- [ ] Research Worker: re-deploy from the prod account, CORS re-pinned.
- [ ] Start watching the 404 logs — they are the trigger for backlog **D3**
      (stub files vs Bulk Redirects). Decide from traffic, not projection.

---

## 5. CI

**Moved here from backlog C7, 2026-09-11** — it is release plumbing, so it lives
with the release. `.github/workflows/` is empty; every test is run by hand today.

**A workflow calls the project's scripts and holds no logic of its own** — plan
in [`test-all-and-release-all.md`](../test-all-and-release-all.md). Each
product's `scripts/<product>/test.sh` is its release gate and its `deploy.sh`
runs that first, so what was decided here now lives inside those scripts —
don't re-derive it:

- **`static_site/test.sh` runs from `static_site_generator/`.** Two paths in the
  suite are CWD-relative, and the root pubspec has no `test` dev_dependency.
- **The wiring guard runs ahead of the corpus run**, not beside it. A markup ⇄
  stylesheet disagreement should stop a deploy before the full build is
  generated.
- **`--quick` is the checkout-only half**; the corpus rows ride the release job,
  which checks the corpus out to generate the site anyway.
- **The release job calls `deploy.sh --prod --yes`**, not a raw wrangler action —
  every gate in §2 lives in that script.
- **Repo secrets use the names in `scripts/config/secrets.env`**, so a script
  reads the environment in CI and the file on a workstation.

| job | runs |
|---|---|
| every push / PR | `scripts/test_all.sh --quick` |
| release | `scripts/release_all.sh static_site --prod --yes` — full `static_site/test.sh`, build, `check_links.dart`, the HTML validator once it exists, upload |
| integration (optional, macOS runner) | build the databases (`tools/`), then `scripts/app/test.sh` |

The push/PR job is the half that catches the silent failures. Build it first,
once the product scripts exist; it does not wait on the release job.

---

## 6. Flutter web — not in this release

Placeholder. **Where it lives on Cloudflare is not decided** — reopened
2026-09-14. The likely shape is the static site's: two new Pages projects, one in
the dev (personal) account and one in the prod (ops) account, the prod one
serving `app.sammaditthi.net`. Names are not chosen, and `.pages.dev` names are
first-come, so check before creating. `docs/decisions/static-web-hosting.md`
still records a single reserved project; revise it once this is settled.

**Three targets**, all in `scripts/app/web/`
([`test-all-and-release-all.md`](../test-all-and-release-all.md)):

| target | command | today |
|---|---|---|
| local | `run_mac.sh` | works: `flutter run -d web-server`, with the databases downloaded into the browser |
| dev | `deploy.sh --dev` | placeholder |
| prod | `deploy.sh --prod` | placeholder |

Project names and origins go in `scripts/config/targets.env`, credentials in
`scripts/config/secrets.env` — never in the deploy script.

**The gate is met locally, 2026-09-20.** Web no longer needs a server: the
browser downloads `bjt.db` and `dict.db` into its own file system and reads them
through Drift, the way native reads its copies. There is no web-only datasource
left, and `server/` and the Windows-box deploy are in `deprecated/`. What
remains here is the host's half, below —
[`move-web-onto-drift.md`](../retiring-dart-server/move-web-onto-drift.md) (step
3 of [`retiring-dart-server/README.md`](../retiring-dart-server/README.md)) owns
the app's, and its step 8 is still open.

**What web Drift needs from hosting.** The app side is decided in
`move-web-onto-drift.md`; this is the host's half.

- **COOP/COEP on every file** — `/*` in `_headers`:
  `Cross-Origin-Opener-Policy: same-origin` and
  `Cross-Origin-Embedder-Policy: require-corp`. Not just the page: Drift starts
  its worker from `drift_worker.js`. Without them Chrome can't use OPFS, and the
  app shows its unsupported-browser message. Confirmed to be enough on
  2026-09-20: with exactly these two on Flutter's dev server, `opfsLocks` was
  offered and the real `bjt.db` opened from OPFS.
- **CanvasKit may need `--no-web-resources-cdn` in the build.** Under
  `require-corp` a cross-origin subresource has to send
  `Cross-Origin-Resource-Policy`, and Flutter loads CanvasKit from Google's CDN
  by default. Untested either way — `move-web-onto-drift.md` step 8 settles it
  locally first, and the answer carries straight over here. The flag self-hosts
  the files from the Flutter cache, costing bundle size only.
- **The deploy strips `assets/assets/databases/*.db` and keeps
  `manifest.json`** — the app reads each database's version from it. The
  Windows-box `deploy.sh` deleted the whole folder, and it is in `deprecated/`,
  so **nothing strips them today**: an unset `DATABASE_BASE_URL` makes the app
  read the databases straight out of its own bundle, which is what every local
  run does. A build for Pages without this is ~350 MB of assets.
- **No `immutable` rule on the app's `/assets/*`**, unlike the static site.
  Flutter's asset URLs carry no hash, so a cached old manifest would pair a new
  app with an old database. Pages' default (revalidate) is right.
- **One R2 file per database version**, named like its OPFS folder:
  `bjt-<first 16 hex of SHA-256>.db.gz`. Upload it before deploying the app,
  never overwrite it, and keep old ones — a tab on the old build may still be
  downloading its version; delete them by hand now and then. The base URL is
  the build's `DATABASE_BASE_URL`, per target in `scripts/config/targets.env`.
- **Upload with** `wrangler r2 object put <bucket>/<name> --file <name>
  --content-encoding gzip --content-type application/octet-stream
  --cache-control "public, max-age=31536000, immutable" --remote` (the docs
  don't state wrangler's default, so pass `--remote`). Check the first one:
  `curl -sI -H 'Accept-Encoding: gzip' <url>` shows `content-encoding: gzip`,
  and the app's size check passes — a file gzipped twice arrives still gzipped.
  There are community reports of R2 doing that.
- **A CORS rule on the bucket** for the app's dev and prod origins (`GET`): the
  database comes from another origin. `r2.dev` is rate-limited and for
  development only; prod needs a custom domain in the bucket's account.
- **To confirm at setup:** whether turning R2 on needs a card on file
  (community reports say yes).
- **Later:** `require-corp` blocks media from another host unless it sends
  `Cross-Origin-Resource-Policy` (e.g. recordings for the TTS plan), and COOP
  `same-origin` breaks popup sign-in. Nothing in the app today.

**Banked for when it is live** — cheap, and currently wrong:

- `web/index.html` and `web/manifest.json` are untouched Flutter scaffolding —
  title `the_wisdom_project`, description "A new Flutter project.", theme colour
  `#0175C2`.
- The font preload in `index.html` names `NotoSansSinhala-Regular.ttf`, the full
  face. The bundle ships only the `-Subset.ttf`, and not at that path.
- `X-Robots-Tag: noindex` **plus allow crawl** — not `Disallow`, which would stop
  a crawler ever fetching the response that carries the header.
- AASA / assetlinks on **both** origins.
- Research Worker CORS must include the app's dev and prod origins.
- **Buttons linking the two products, both ways** — the site's "Open in the full
  reader" (planned in `static-web-hosting.md`) and a matching one in the app back
  to the site.
