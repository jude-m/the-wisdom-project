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
Four things are already decided — don't re-derive them:

- **Working directory is `static_site_generator/`.** Two paths in the suite are
  CWD-relative. From the repo root you hit a blunter error first: the root
  pubspec has no `test` dev_dependency, so resolution fails before any test runs.
- **The wiring guard runs ahead of the corpus run**, not beside it. A markup ⇄
  stylesheet disagreement should stop a deploy before the full build is
  generated.
- **Four rows need only a checkout**; the two corpus rows ride the deploy job,
  which checks the corpus out to generate the site anyway.
- **The deploy job calls `deploy.sh --prod --yes`**, not a raw wrangler action —
  every gate in §2 lives in that script.

**Workflow 1 — on push/PR.** Checkout, then:

| package | command |
|---|---|
| `static_site_generator/` | `dart test -x corpus` — the wiring contract, under a second |
| `packages/wisdom_shared/` | `dart test` — markers, tree, link codec |

**Workflow 2 — deploy.** Checkout with the corpus, `dart test` (full, ~45s),
build, `check_links.dart`, the HTML validator, then `deploy.sh --prod --yes`.

Workflow 1 is the half that catches the silent failures and needs nothing that
does not already exist. Build it first; it does not wait on workflow 2.

---

## 6. Flutter web — not in this release

Placeholder. `app.sammaditthi.net` has a Pages project reserved and nothing to
put in it.

**The gate.** `lib/presentation/providers/platform_providers.dart` swaps in three
remote HTTP datasources on web — FTS, dictionary, documents — all pointed at
same-origin `/api/…`. That origin is the Dart `shelf` content server, which is
the thing being retired. On static Pages with no server the app boots and every
content, search and dictionary call 404s.

The replacement is the Drift migration (`docs/todo/retiring-dart-server/`), which
has not started: `pubspec.yaml` has `sqflite`, no `drift`, and the one gate —
proving FTS5 and the Sinhala tokenizer return identical rows through the wasm
build — is still TODO. Until then the web app runs only where that server runs,
which today is the Windows box `scripts/web/deploy.sh` targets.

**Banked for when it is live** — cheap, and currently wrong:

- `web/index.html` and `web/manifest.json` are untouched Flutter scaffolding —
  title `the_wisdom_project`, description "A new Flutter project.", theme colour
  `#0175C2`.
- The font preload in `index.html` names `NotoSansSinhala-Regular.ttf`, the full
  face. The bundle ships only the `-Subset.ttf`, and not at that path.
- `X-Robots-Tag: noindex` **plus allow crawl** — not `Disallow`, which would stop
  a crawler ever fetching the response that carries the header.
- AASA / assetlinks on **both** origins.
- Research Worker CORS must include the `app.` origin.
