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

**Attaching the apex to the `sammaditthi` project is the next physical step, and
it must happen before the first `--prod`.** Until then a release bakes
canonicals, `og:url`s and every sitemap entry with an origin nobody can resolve.

Everything production lives in the **ops** account — the Pages projects, the
`sammaditthi.net` zone, R2, and the research Worker. Bulk Redirects only fire on
a zone in the same account, and Pages projects **cannot be moved between
accounts**.

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

1. **Dev first** — `./scripts/static_site/deploy.sh --dev`: `sammaditthi-test`
   in the dev account, its production branch `main`. Kept out of the index by
   the generated `_headers`, which noindexes every `*.pages.dev` host.
2. **Prod** — `./scripts/static_site/deploy.sh --prod --yes`.

Both project names are in `scripts/config/targets.env`; `secrets.env` is credentials only.
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
in [`test-all-and-release-all.md`](../../done/test-all-and-release-all.md). Each
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
| release | `scripts/static_site/deploy.sh --prod --yes` — full `static_site/test.sh`, build, `check_links.dart`, the HTML validator once it exists, upload |
| integration (optional, macOS runner) | build the databases (`tools/`), then `scripts/app/test.sh` |

The push/PR job is the half that catches the silent failures. Build it first,
once the product scripts exist; it does not wait on the release job.

---

## 6. Flutter web — dev live, prod later

**Dev is live since 2026-09-27.** `./scripts/app/web/deploy.sh --dev` uploads
each new database version to R2 in the ops account (`db.sammaditthi.net`), then
the app to the `app-sammaditthi-test` Pages project in the dev account. What it
does, the one-time setup and rollback are in
[`scripts/app/web/README.md`](../../../scripts/app/web/README.md). Prod —
`app-sammaditthi` in ops, at `app.sammaditthi.net` — is not created yet, and
`--prod` is a placeholder.

**Three targets**, all in `scripts/app/web/`
([`test-all-and-release-all.md`](../../done/test-all-and-release-all.md)):

| target | command | today |
|---|---|---|
| local | `run_mac.sh` | works: `flutter run -d web-server`, with the databases downloaded into the browser |
| dev | `deploy.sh --dev` | live |
| prod | `deploy.sh --prod` | placeholder |

Project names, the bucket and origins are in `scripts/config/targets.env`,
credentials in `scripts/config/secrets.env` — never in the deploy script.

[`move-web-onto-drift.md`](../../done/retiring-dart-server/move-web-onto-drift.md)
owns the app's half: the browser downloads `bjt.db` and `dict.db` into its own
file system and reads them through Drift, the way native reads its copies. The
host's half, all in place for dev:

- **COOP/COEP on every file** — `web/_headers`:
  `Cross-Origin-Opener-Policy: same-origin` and
  `Cross-Origin-Embedder-Policy: require-corp`. Not just the page: Drift starts
  its worker from `drift_worker.js`. Without them Chrome can't use OPFS, and the
  app shows its unsupported-browser message.
- **CanvasKit needs no flag.** Under `require-corp` a cross-origin subresource
  has to send `Cross-Origin-Resource-Policy`, and Google's CDN, where Flutter
  loads CanvasKit from by default, sends `cross-origin` (settled 2026-09-21,
  `move-web-onto-drift.md` step 8).
- **The build carries no `.db`.** The deploy takes both out and keeps
  `manifest.json`, which names each version the app downloads.
- **No `immutable` rule on the app's `/assets/*`**, unlike the static site.
  Flutter's asset URLs carry no hash, so a cached old manifest would pair a new
  app with an old database, and a cached old `tree.json` or `sc-to-bjt.json`
  would outlive the build that changed it. Pages' default (revalidate) is
  right.
- **One R2 file per database version**, never overwritten, old ones kept until
  deleted by hand — a tab on an older build may still be downloading one.
- **CORS for any origin**: the bucket's rule, plus a response-header rule on
  `db.sammaditthi.net` for requests without `Origin`. Cloudflare caches each
  file with the CORS header of the first request, so a list of origins would
  lock out all but the first.

Still open:

- **One test run against the bucket**, once the installer tests exist
  ([`web-database-installer-tests.md`](../retiring-dart-server/web-database-installer-tests.md)):
  run its file 1 with `--dart-define=DATABASE_BASE_URL=https://db.sammaditthi.net`.
  Every other run downloads the app's own asset copy, so this is the only
  automated check of the gzip and the cross-origin download. Its fetch spy
  counts URLs ending `.db`; from the bucket they end `.db.gz`, so widen it first.
- **Later:** `require-corp` blocks media from another host unless it sends
  `Cross-Origin-Resource-Policy` (e.g. recordings for the TTS plan), and COOP
  `same-origin` breaks popup sign-in. Nothing in the app today.

**Banked for prod** — cheap, and currently wrong:

- `web/index.html` and `web/manifest.json` are untouched Flutter scaffolding —
  title `the_wisdom_project`, description "A new Flutter project.", theme colour
  `#0175C2`.
- The font preload in `index.html` names `NotoSansSinhala-Regular.ttf`, the full
  face. The bundle ships only the `-Subset.ttf`, and not at that path.
- **A connection lost mid-download shows the error icon, not the offline one.**
  In `_download` (`web_database_installer.dart`) a `fetch` that throws or a
  `reader.read()` that fails reaches `_asFailure` and becomes `other`. Wrap
  each in its own `try` that throws `DatabaseInstallFailure(download, …)`;
  leave `sink.write` and `sink.close` to `_asFailure`, so a full disk stays
  `outOfSpace`. Step 4.2 of the installer tests can then check the kind.
- AASA / assetlinks on **both** origins.
- Research Worker CORS must include the app's prod origin (dev's is in
  `research_server/wrangler.jsonc`).
- **Buttons linking the two products, both ways** — the site's "Open in the full
  reader" (planned in `static-web-hosting.md`) and a matching one in the app back
  to the site.
