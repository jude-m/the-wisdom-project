# The Wisdom Project

Read the Tipitaka and its commentaries in Pali and Sinhala, side by side, with
search, a dictionary and an AI research assistant.

## The products

| Product | What it is | Code |
|---|---|---|
| **app** | The Flutter reader — macOS, Windows, iOS, Android and web. Reads the canon from local SQLite databases (Drift). | `lib/` |
| **static site** | The public HTML Tipitaka at `sammaditthi.net`. Plain pages, no JavaScript needed. | `static_site_generator/` |
| **research server** | The `/research` AI Q&A backend, a Cloudflare Worker. | `research_server/` |

Shared Dart code for the app and the site is in `packages/wisdom_shared/`. The
databases the app reads are built by `tools/` (see `tools/README.md`).

## Running and testing

Every product has its own scripts under `scripts/<product>/`: `run.sh`,
`test.sh` and `deploy.sh`. Each prints its usage with `-h`.

```sh
./scripts/app/macos/run.sh            # the app on macOS
./scripts/app/web/run_mac.sh          # the app in Chrome, served locally
./scripts/static_site/run.sh          # preview the static site
./scripts/research_server/run.sh      # the research server, locally

./scripts/test_all.sh                 # every product's test.sh
./scripts/release_all_dryrun.sh       # every deploy, dry run only
```

The app needs its databases first: `npm install`, `npm run generate-bjt` and
`npm run generate-dict` in `tools/`.

## Deploying

Two Cloudflare accounts, one per target:

- **dev** — the wisdomproject.dev account. Free things only.
- **prod** — the ops account.

**Anything paid lives in prod only, and dev uses it too** — the research
Worker and the R2 bucket for the app's databases. Both are read-only to every
client, so sharing them is safe.

Where things deploy is in `scripts/config/targets.env` (committed).
Credentials go in `scripts/config/secrets.env` (gitignored) — copy
`secrets.env.example`, which also says how to make each token.

Each product's one-time setup — the projects, domains, buckets and tokens made
by hand in the Cloudflare dashboard — is in its own README:

- [Static site](scripts/static_site/README.md)
- [Research server](scripts/research_server/README.md)
- [App on the web](scripts/app/web/README.md)

A release is always the product's own `deploy.sh --prod`.

## Docs

Plans and decisions are in `docs/`: `todo/` is open work, `done/` is finished
work, `decisions/` records why things are the way they are. `CLAUDE.md` has the
code conventions.
