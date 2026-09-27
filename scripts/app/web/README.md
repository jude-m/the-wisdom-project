# App on the web — deploy setup

`deploy.sh --dev` uploads the databases to R2, then the app to Cloudflare
Pages. `--prod` is a placeholder until `app.sammaditthi.net` exists.

| Target | Account | Pages project | Serves at |
|---|---|---|---|
| dev | wisdomproject.dev | `app-sammaditthi-test` | `https://app-sammaditthi-test.pages.dev` — noindex |
| prod | ops | `app-sammaditthi` — not created yet | `https://app.sammaditthi.net`, later |

The databases come from one R2 bucket in the **prod (ops)** account,
`wisdom-databases` at `https://db.sammaditthi.net`, read by every web build:
R2 is paid, so there is no dev bucket. The names are in
`scripts/config/targets.env`.

Locally, `./scripts/app/web/run_mac.sh` needs none of this: the app reads the
databases from its own build.

Everything below is done once, by hand.

## One-time setup

1. **Tokens.** The dev token needs *Cloudflare Pages: Edit*; the prod (ops)
   token also needs *Workers R2 Storage: Write*. Both need *Account Settings:
   Read*. The recipe is in `scripts/config/secrets.env.example`.
2. **Pages project (dev account).** Workers & Pages → Create → Pages → *Use
   direct upload*, named `app-sammaditthi-test`, production branch `main`. The
   deploy checks both and stops if either is wrong.
3. **R2 (ops account).** Turn R2 on, then create the bucket `wisdom-databases`.
4. **Domain.** wisdom-databases → Settings → Custom Domains → Add →
   `db.sammaditthi.net`. Wait for *Active*. Not `r2.dev`: it is rate-limited and
   for development only.
5. **CORS.** wisdom-databases → Settings → CORS Policy → Add, as JSON:

   ```json
   [
     {
       "AllowedOrigins": ["*"],
       "AllowedMethods": ["GET", "HEAD"],
       "MaxAgeSeconds": 86400
     }
   ]
   ```

   Any origin, not a list: Cloudflare caches each file with the CORS header
   of the first request, so with a list every other origin is refused. The
   files are public and read-only anyway.

   Then the same header for a request with no `Origin` (a pasted link, a
   crawler), which R2 answers without one — cached, that copy would block
   everyone. sammaditthi.net → Rules → Create rule → **Response** Header
   Transform Rule: `(http.host eq "db.sammaditthi.net")`, Set static
   `Access-Control-Allow-Origin` = `*`. Only this host: the research Worker
   keeps its own list.
6. **Research CORS.** The research Worker must list the app's origin too
   (`RESEARCH_CORS_ORIGINS` in `research_server/wrangler.jsonc`), then be
   released.

## What a deploy does

1. Checks both tokens, the Pages project's branch, and that the bucket can be
   listed — before the tests, so a bad one stops it in seconds.
2. Runs `scripts/app/test.sh` (skip with `--skip-tests`).
3. `flutter build web --release` with `RESEARCH_BASE_URL` and
   `DATABASE_BASE_URL`. `_headers` comes from `web/_headers`.
4. Checks each `.db` in the build against `manifest.json`, then takes it out
   of the build.
5. Uploads each database version the bucket doesn't have yet, as
   `<db>-<16 hex of its SHA-256>.db.gz`, gzipped with `Content-Encoding: gzip`.
   Then, for every version, new or not, asks for its headers from the app's
   origin: 200, the CORS header, gzip.
6. Deploys the app, then checks it answers 200 with cross-origin isolation and
   noindex.

A new database means a new name, so a file on R2 is never overwritten. Old
versions stay until you delete them by hand: a tab on an older build may still
be downloading one.

## Rollback

The app: Pages project → Deployments → the last good deployment → ⋯ →
*Rollback to this deployment*. It names its own database versions, and those
are still on R2.

A failed database check stops the deploy before the app goes out. Fix what it
names, then purge that URL, because Cloudflare keeps serving the copy it
cached: sammaditthi.net → Caching → Configuration → Purge Cache → Custom Purge.
Then deploy again.

## Good to know

- **The first upload sends everything**: both databases, then the app. On a slow uplink wrangler gives up with `Error: {})`; do it from a fast
  connection. Later deploys send only a changed database and changed app files.
- When a deploy dies with `Error: {})` and nothing else, the real cause is in
  `~/Library/Preferences/.wrangler/logs/`.
- The deploy uploads whatever is in `assets/databases`. To ship newer text,
  rebuild the databases first (`scripts/bjt-sync-regen/sync-regen.sh`, or
  `cd tools && npm run generate-bjt`).
