# Retire the personal Cloudflare account

> **Opened 2026-09-26, done 2026-09-27.** Branch
> `chore/retire-personal-cloudflare-account`, merged to `main` (`baef405`).
> Moved everything off the personal bk.anigha account onto two project
> accounts, then deleted what was left there.

## The shape

Two accounts, one per target. **ops = prod.**

| | dev — wisdomproject.dev | prod — ops |
|---|---|---|
| static site | `sammaditthi-test.pages.dev` | `sammaditthi.net` |
| Flutter web | `app-sammaditthi-test.pages.dev` | placeholder (`app.sammaditthi.net` later) |
| research Worker | — uses prod's | `research.sammaditthi.net` |
| R2 databases | — uses prod's | `db.sammaditthi.net` |

**Rule: anything paid lives in prod only, and dev uses it.** The Worker and
the databases are read-only to every client, so sharing them is safe. Dev holds
only free Pages projects. A dev instance of a paid thing stays possible later:
the deploy scripts keep a `--dev` placeholder and the config keeps the slot.

Both accounts sign in the same way: an account-owned token plus the account ID
(`CLOUDFLARE_DEV_*`, `CLOUDFLARE_PROD_*` in `scripts/config/secrets.env`),
checked by `use_cloudflare` in `scripts/lib/common.sh`. Nothing uses
`wrangler login`.

Dev deploys to its projects' **production** branch for the clean URL, so the
static site's generated `_headers` sends `X-Robots-Tag: noindex` on every
`*.pages.dev` host (prod's `sammaditthi.pages.dev` twin too); Cloudflare only
adds it to preview branches.

**The one-time setup itself lives in each product's README** —
`scripts/static_site/`, `scripts/research_server/`, `scripts/app/web/` — linked
from the root `README.md`. This doc is the dated record of the move.

---

## Finish line — done 2026-09-27

Merged at the end, not before the research release: only that release needs
`main`.

1. First uploads, on the branch: `./scripts/static_site/deploy.sh --dev` (a
   full build), then `./scripts/app/web/deploy.sh --dev`. Both sites answer 200
   with `noindex`; the app also sends COOP/COEP.
2. Merged to `main`.
3. `./scripts/research_server/deploy.sh --prod` from `main`. It swapped the
   CORS list to the new app origin: a preflight from
   `https://app-sammaditthi-test.pages.dev` gets 204 with that origin allowed,
   and `/health` answers `mode: live`, `key_configured: true`. It was the first
   deploy after the custom domain was attached in the dashboard, so wrangler
   warned the remote config "differs" and listed the domain as removed. That
   warning is only a diff: wrangler 4.112 touches routes and custom domains
   only when the config lists some, and ours lists none. The domain stayed.
4. bk.anigha emptied by hand, `wrangler logout` on this Mac, and the stale
   `.wrangler/cache/wrangler-account.json` (it named bk.anigha) deleted. Both
   accounts checked afterwards with `use_cloudflare dev` and `use_cloudflare
   prod`.

---

## Steps

### 1. Static site dev → wisdomproject.dev — done 2026-09-27

Code: `use_cloudflare` helper; `static_site/deploy.sh` uses it for both targets
(no `wrangler login` path, no `pages.json` cache handling); dev target is
`sammaditthi-test`, branch `main`, origin `https://sammaditthi-test.pages.dev`,
noindex from the generator's `https://:project.pages.dev/*` rule in `_headers`.

Your part:
- [x] Token (`pages-deploy-dev`), secrets, project — done 2026-09-26; production
      branch confirmed `main` through the API.
- [x] First upload, from a fast connection: `./scripts/static_site/deploy.sh
      --dev` (2026-09-27). The site answers 200 with `noindex`.

**Why the first upload needed a fast line (2026-09-26):** the first `--dev`
deploy got through everything but the upload, then failed twice at
`Uploading... (0/10302)` with `Error: {})`. The wrangler log said
`UND_ERR_HEADERS_TIMEOUT` / `EPIPE` on `pages/assets/upload`. Home upload
measured **~80 KB/s**; wrangler sends ~50 MB batches, three at a time, and gives
up on a batch with no reply after ~5 min, so no batch could finish. A new
project needs the whole build once (~400 MB); after that, deploys send only
changed files. Seeding by small `--root` deploys was considered and not done:
it assumes a page is byte-identical in a subtree build and a full one, which is
unchecked.

### 2. Research Worker → prod (ops) — done 2026-09-27

Code: `research_server/deploy.sh --prod` live via `use_cloudflare prod` (asks
to confirm; `--yes` for CI), `--dev` a placeholder (exit 3); `wrangler.jsonc`
sets `workers_dev: false`, `preview_urls: false` and declares **no route** — the
custom domain is a dashboard step, so the token needs no zone permission; CORS
allows `localhost:8080` and `https://app-sammaditthi-test.pages.dev`;
`RESEARCH_BASE_URL`, `run.bat`, the provider's doc comment and the README point
at `https://research.sammaditthi.net`.

Your part:
- [x] ops token: **Editor — Workers**, entire account (2026-09-26).
- [x] `RESEARCH_GEMINI_API_KEY` from the Google project that owns
      `RESEARCH_STORE` — the **personal** one, for now (2026-09-26).
- [x] Dashboard: create the Worker once — Workers & Pages → Create → Worker
      ("Hello World"), name `wisdom-research`. Creating needs the Workers
      **Admin** role; the token's Editor can only deploy to one that exists.
- [x] `./scripts/research_server/deploy.sh --prod --yes` (replaces the Hello
      World and turns its workers.dev URL off) — 2026-09-26, version
      `0870b50a`; "No targets deployed", as expected before the domain.
- [x] Dashboard: Workers & Pages → wisdom-research → Settings → Domains &
      Routes → Add → Custom domain → `research.sammaditthi.net`, enabled for
      **Production only** (no preview subdomains).
- [x] `/health` → 200, `mode: live`, `store_configured: true`; CORS preflight
      allows `localhost:8080` and `sammaditthi-app-test.pages.dev` (2026-09-27).
- [x] Dashboard: the rate-limiting rule on `/research` — recipe in
      `scripts/research_server/README.md`. Checked with preflights: 429 from
      the 8th in a burst, `/health` untouched (2026-09-27).

**Handover (2026-09-26):** the token has no Zone permission on purpose: Cloudflare's
Workers role system (2026-09-15) marks "Workers Scripts" legacy, the picker offered
no Zone/Workers Routes rows, and wrangler has an open bug (workers-sdk #15863) where
`workers_dev: false` + a `custom_domain` route fails every deploy after the first
without Workers Routes: Read. Attaching the domain by hand avoids both. The first
`--prod` run passed the ops account check, then stopped — nothing uploaded — at
`check_research_store`: `HTTP 403`, because the key was from another Google
project than the store. With the personal project's key the check passed, tests
passed, and the upload got as far as `PUT …/workers/scripts/wisdom-research` →
"No access to the specified resource": the Worker did not exist, and creating one
needs Workers **Admin**. Nothing was created or uploaded.

**The Google side is still personal.** This step moves only the Cloudflare half
of research. The key and the store stay in the personal Google project until
`research/ingestion-node-rewrite-and-chunking-plan.md` ingests into the ops
`wisdom-research` project; then `RESEARCH_STORE` and the key change together in
one deploy, and the personal project can go.

### Review follow-ups — done 2026-09-27

- Research `--prod` refuses unless on `RESEARCH_PROD_BRANCH` (`main`) with a
  clean tree — `require_release_commit` in `common.sh`, shared with the static
  site — tags the Worker version with the commit, and ends by checking
  `/health`: 200, `mode: live` and `key_configured: true` — a new field: the
  Worker holds a key at all, which `mode` can't tell. It fails only for a new
  Worker or a key deleted in the dashboard; an empty
  `RESEARCH_GEMINI_API_KEY` keeps the key the Worker has.
  `--skip-tests` is dry-run only: the typecheck is the only one.
- `release_all_dryrun.sh` runs `--prod --dry-run` for a target that is
  `dev=placeholder prod=live`, so the research Worker is built again.
- Static site: the account is checked before the tests on both targets;
  `use_cloudflare` loads wrangler itself; then the Pages API must confirm the
  project exists and its production branch is the target's branch (else the
  upload lands on a preview and the after-upload check reads the old
  deployment); after the upload the site must answer 200, noindex on dev and
  indexable on prod. Tokens go to curl on stdin, not the command line.
- Noindex moved from a `deploy.sh` append into the generator (host rule, see
  above) — one writer for `_headers`, no marker, no prod refusal.
- Both deploys run their tests without the deploy token (`env -u`).
  `use_cloudflare` unsets `CLOUDFLARE_API_KEY`/`CLOUDFLARE_EMAIL`, which
  wrangler would prefer over the token. `confirm_release` and `git_stamp` in
  `common.sh` are shared by both deploys; the Worker version message is passed
  as `--message=`, so a subject starting with `-` is not a flag.
- `expect_http` passes `--suppress-connect-headers`: behind a proxy, `curl -i`
  printed the proxy's `200 Connection Established` first, so every status read
  200 and dev's noindex check always failed.
- Rollback steps in both READMEs; stale wording fixed; "test copy" → "dev copy".
- **Decided: one ops token** for Pages and Workers, not split per product.

### 3. R2 bucket (ops) + Flutter web dev — done 2026-09-27

Code: `scripts/app/web/deploy.sh --dev` is live (`--prod` still a placeholder).
It checks both tokens, the Pages project's branch and the bucket before the
tests; runs `scripts/app/test.sh`; builds with `RESEARCH_BASE_URL` +
`DATABASE_BASE_URL`; checks each `.db` in the build against `manifest.json` and
takes it out; uploads each version the bucket lacks as `<db>-<16 hex>.db.gz`;
asks every version's headers from the app's origin on every deploy (200, CORS
header, gzip — the size the app checks itself); deploys to
`app-sammaditthi-test` and checks 200,
COOP/COEP and noindex. Whether a version is on R2 is asked through the API, not
the public URL, so Cloudflare can't cache a 404 the after-upload check reads.
`--dry-run` builds and checks, uploads nothing and needs no credentials.
`_headers` is a committed `web/_headers`: the app is noindex on every host, so
one file serves both targets. `targets.env` has `DATABASE_BUCKET`,
`DATABASE_BASE_URL`, `APP_WEB_DEV_PROJECT`, `APP_WEB_DEV_BRANCH`. The Pages
branch check is `check_pages_branch` in `common.sh`, shared with the static
site. Setup and rollback: `scripts/app/web/README.md`.

- [x] Pages project `app-sammaditthi-test` created in the dev account with a
      Hello World, production branch `main` (2026-09-27). The first `--dev`
      deploy replaced it; the research release then moved the Worker's CORS
      list from the old, unclaimed `sammaditthi-app-test.pages.dev` to it.

- [x] R2 on in ops; bucket `wisdom-databases`; custom domain
      `db.sammaditthi.net` (active) (2026-09-27).
- [x] **CORS for any origin**, never a list: Cloudflare caches each file with
      the first request's CORS header. The bucket's rule allows `*` (GET/HEAD),
      and a response-header rule on `db.sammaditthi.net` sets
      `Access-Control-Allow-Origin: *` on every answer, since R2 sends none to a
      request without `Origin`. Checked: `*` with and without `Origin`; the
      research Worker keeps its own list (2026-09-27).
- [x] Token: *Workers R2 Storage Write* added to the one ops token, not a
      bucket-only token — that can't pass `use_cloudflare`'s `wrangler whoami`
      check (2026-09-27).
- [x] Canon synced to upstream `8d7eefc` and both databases rebuilt
      (2026-09-27): `bjt-c0bbb2894d88edda`, `dict-ee389b00f5ab1f26`.
- [x] First upload, with the static site's (2026-09-27): both database
      versions are on R2 (`bjt-c0bbb2894d88edda.db.gz`,
      `dict-ee389b00f5ab1f26.db.gz`), and the app answers 200, isolated
      (COOP/COEP) and noindex.

Note: `flutter build web` writes the Flutter SDK's cache, so from Claude the
app deploy runs outside the sandbox.

### 4. Sweep and delete bk.anigha — done 2026-09-27

Code done 2026-09-27. `static-web-hosting.md`: the targets table, "dev is noindex
because the build says so" in place of the preview-branch decision, and the
stale deferred-standardization list. `web-release.md`: the blocker, the dev
target, and §6 rewritten (dev live). The deep-linking doc's C2 sheet points at
`sammaditthi-test.pages.dev`. Memory updated. Scripts had none left. Kept on
purpose: the `curl` output in `static-web-hosting.md`'s caching section, a dated
measurement on the old host. `docs/done/` stays as it was — dated records.

- [x] The old Worker, `sammaditthi-dev` and everything else in bk.anigha
      deleted by hand; `wrangler logout` on this Mac (2026-09-27).

---

## Left open

Not part of the move; tracked only here.

- **The Google side of research is still personal** — see step 2.
- `release_all_dryrun.sh` sends `--prod --dry-run` to a prod-only target, and
  the placeholder deploys (`scripts/app/{android,ios,macos}/deploy.sh`) swallow
  `--dry-run`. Safe while none is live; a placeholder that flips to live must
  honour `--dry-run` first, or the sweep releases it. (`app/web` does.)
