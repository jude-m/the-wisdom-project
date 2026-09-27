# Retire the personal Cloudflare account

> **Opened 2026-09-26.** Branch `chore/retire-personal-cloudflare-account`.
> Moves everything off the personal bk.anigha account onto two project
> accounts, then deletes what is left there.

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

## Steps

### 1. Static site dev → wisdomproject.dev — code done, first upload pending

Code: `use_cloudflare` helper; `static_site/deploy.sh` uses it for both targets
(no `wrangler login` path, no `pages.json` cache handling); dev target is
`sammaditthi-test`, branch `main`, origin `https://sammaditthi-test.pages.dev`,
noindex from the generator's `https://:project.pages.dev/*` rule in `_headers`.

Your part:
- [x] Token (`pages-deploy-dev`), secrets, project — done 2026-09-26; production
      branch confirmed `main` through the API.
- [ ] **First upload — from a fast connection.**
      `./scripts/static_site/deploy.sh --dev`; it checks the site answers 200
      with `noindex` itself.

**Handover (2026-09-26):** the first `--dev` deploy got through everything but
the upload — account verified (`Wisdomproject.dev@gmail.com's Account`), build
and every preflight passed — then failed twice at `Uploading... (0/10302)` with
`Error: {})`. The wrangler log says `UND_ERR_HEADERS_TIMEOUT` / `EPIPE` on
`pages/assets/upload`. Cause: home upload measured at **~80 KB/s**; wrangler
sends ~50 MB batches, three at a time, and gives up on a batch with no reply
after ~5 min, so no batch can finish. A new project needs the whole build once
(~400 MB); after that, deploys send only changed files, as they did on the old
project. So: run the first upload from a line with several MB/s up (or retry
if the line was just slow that day). Seeding by small `--root` deploys was
considered and not done — it assumes a page is byte-identical in a subtree
build and a full one, which is unchecked. Until then the site answers `522`.

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

Pending:
- [ ] **Research release right after merging** (releases need `main`): it drops
      the unclaimed `sammaditthi-app-test.pages.dev` from the live Worker's CORS
      list, and must pass the new `/health` check — the first proof that a
      deploy leaves the dashboard-attached domain alone.
- [ ] `release_all_dryrun.sh` sends `--prod --dry-run` to a prod-only target,
      and the placeholder deploys (`scripts/app/*/deploy.sh`) swallow
      `--dry-run`. Safe while none is live; a placeholder that flips to
      `prod=live` must honour `--dry-run` first, or the sweep releases it.

### 3. R2 bucket (ops) + Flutter web dev

Code, planned (`deploy.sh` is still a placeholder):
`scripts/app/web/deploy.sh --dev` — release build with
`RESEARCH_BASE_URL` + `DATABASE_BASE_URL`, strip the `.db` files (keep
`manifest.json`), write `_headers` (COOP/COEP + noindex), upload any missing
`<db>-<16 hex>.db.gz` to the bucket, deploy to `app-sammaditthi-test`. `--prod`
stays a placeholder with empty keys.

- [x] Pages project `app-sammaditthi-test` created in the dev account with a
      Hello World, production branch `main` (2026-09-27). The first `--dev`
      deploy replaces it. **The live Worker still allows the old, unclaimed
      `sammaditthi-app-test.pages.dev`** until the next research release, which
      picks up the new name from `wrangler.jsonc`.

Your part, all dashboard, one-time (prompted when the code is in): turn on R2
in ops, bucket, custom domain `db.sammaditthi.net`, CORS rule, a bucket-only
upload token. Only uploading a new database version is scripted — it
recurs.

**Handover:** —

### 4. Sweep and delete bk.anigha

Code: every remaining bk-anigha / personal-account reference in scripts, live
docs (`static-web-hosting.md`, `web-release.md`, research plans) and memory.
In `static-web-hosting.md`, rewrite the decision "dev is a preview branch on
purpose" itself — dev is now a production deploy, noindexed by the generated
`_headers` — not just the names.
`docs/done/` stays as it was — dated records.

Your part: delete the Worker, `sammaditthi-dev` and anything else in
bk.anigha; `wrangler logout` on this machine.

**Handover:** —
