# Test All and Release All

> **Opened 2026-09-14, reviewed 2026-09-15.** One command tests the whole
> project, one builds and releases it, and every product can do both on its own.
> CI then becomes one line per job. Nothing here is built yet. **Implement after**
> [`reduce-mobile-size-and-move-to-drift.md`](retiring-dart-server/reduce-mobile-size-and-move-to-drift.md)
> lands.

## The principle

- **A product stands alone.** Each product folder under `scripts/` holds a
  `test.sh` — that product's release-quality gate — and a `deploy.sh` that runs
  it first. No product script calls another product's script.
- **The project level only delegates.** `scripts/test_all.sh` and
  `scripts/release_all.sh` call the product scripts and print one summary. They
  hold no test logic of their own.
- **Targets and secrets live in `scripts/config/`**, never inside a script.
- **`tools/` holds build inputs only** — the database builders and the
  font/emblem/theme-token generators. No tests, no deploys.

## The tree

```
scripts/
├── test_all.sh                    every product's test.sh, one summary
├── release_all.sh                 every target's deploy.sh, one summary
├── lib/common.sh                  shared helpers — sourced, never run
├── config/                        targets + secrets (below)
│
├── app/                           Flutter app: one codebase, several targets
│   ├── test.sh
│   ├── web/       run_mac.sh   deploy.sh (placeholder)
│   ├── android/   run.sh       deploy.sh (placeholder)
│   ├── ios/       run.sh       deploy.sh (placeholder)
│   ├── macos/     run.sh       deploy.sh (placeholder)
│   └── windows/   run.bat
├── static_site/        test.sh   run.sh   deploy.sh
├── research_server/    test.sh   run.sh   deploy.sh
└── bjt-sync-regen/sync-regen.sh   maintenance, not a product — verifies with static_site/test.sh
```

`test_all` / `release_all` rather than `master_*`: they are the only two files
at the top of `scripts/`, which is what makes them stand out, and `_all` says
what they do.

## What every product script promises

**`test.sh`**
- Runs from any directory; it `cd`s where each tool needs.
- `--quick` leaves out anything that needs the built databases, the whole
  corpus, or a device. It is the checkout-only run CI does on every push.
- Without `--quick` every step must run. A step that cannot run on this machine
  is a FAIL, not a skip.
- Exits 0 or 1 and prints its own step summary.

**`deploy.sh`**
- Refuses before it tests. A bad flag — and for `--prod` the wrong branch, a
  dirty tree or a missing credential — stops it in seconds. Then its product's
  `test.sh`, then the build.
- `--dev` (default) or `--prod`; `--prod --yes` skips the confirmation (CI).
- `--dry-run` builds and checks, uploads nothing.
- `--skip-tests` is dev-only. `--prod` refuses it, as the static site's deploy
  already refuses `--root` and `--skip-build`.
- A target that does not exist yet prints why and exits **3** at once, before
  any test. `release_all.sh` reports it as NOT SET UP — never as a pass.

**`run*.sh`** — local only. Moved one folder deeper, with two edits each: the
`cd` to the repo root gains a `..`, and `RESEARCH_BASE_URL` defaults from
`targets.env`. An exported value still wins, so
`RESEARCH_BASE_URL=http://10.0.2.2:8082 ./scripts/app/android/run.sh` keeps
working. `run.bat` cannot source a bash file and keeps its own default.

## What each `test.sh` runs

### `scripts/app/test.sh`

| step | command | `--quick` |
|---|---|---|
| format | `dart format --output=none --set-exit-if-changed lib test integration_test tools packages/wisdom_shared` | ✓ |
| analyze | `flutter analyze` over the same folders | ✓ |
| generated code is current | hash the generated files, run `build_runner build` and `flutter gen-l10n`, fail if a hash changed. Before/after hashes, not `git diff`, so a fresh but uncommitted regen passes | ✓ |
| unit + widget | `flutter test` | ✓ |
| wisdom_shared | `dart test` in `packages/wisdom_shared` | ✓ |
| shipped databases | exist, SQLite magic, not WAL-flagged (from `validate-release.sh`); each file's SHA-256 equals its entry in `assets/databases/manifest.json`, since phones keep their old copy of a database changed outside `tools/db-finalize.js` | – built, not committed |
| integration | `flutter test integration_test/all_tests.dart -d macos`, then `integration_test/bundled_database_copy_test.dart` the same way — it swaps a database file, so it can't share the suite's one app launch ([proposal](./retiring-dart-server/bundled-database-copy-tests.md)) | – needs macOS and the databases |

`a3f6c46` formatted every Dart package once. If the format gate is red by step
4, format in a commit of its own first.

### `scripts/static_site/test.sh`

Needs a plain `dart`, no Flutter SDK — which keeps the site's CI job light.

| step | command | `--quick` |
|---|---|---|
| format | `dart format … static_site_generator packages/wisdom_shared` | ✓ |
| analyze | `dart analyze --fatal-infos` in both packages — today `flutter analyze` covers them, and it fails on infos by default | ✓ |
| wisdom_shared | `dart test` | ✓ |
| wiring contract | `dart test -x corpus` in `static_site_generator/` | ✓ |
| corpus | `dart test -t corpus` — `plan_corpus.dart` and `verify_corpus_invariants.dart` | – |

Runs from `static_site_generator/`: two paths in its suite are CWD-relative, and
the root pubspec has no `test` dev_dependency. The wiring contract runs before
the corpus step, so a markup ⇄ stylesheet break stops first. `check_links.dart`
stays in `deploy.sh` — it checks a build, and building is the deploy's job.

### `scripts/research_server/test.sh`

| step | command | `--quick` |
|---|---|---|
| typecheck | Node ≥ 22 guard, `npm ci` if needed, `npm run typecheck` | ✓ |

There are no tests, and `wrangler deploy` strips types without checking them, so
today a type error ships. Writing tests is a separate task.

## Targets

| product | local | dev | prod |
|---|---|---|---|
| static site | `run.sh` | `deploy.sh --dev` → `sammaditthi-dev`, branch `dev` | `deploy.sh --prod` → `sammaditthi.net` |
| research server | `run.sh` | `deploy.sh --dev` → today's only Worker, personal account | **placeholder** — moves to the ops account ([`web-release.md`](web-strategy/web-release.md) §4) |
| app · web | `run_mac.sh` — from step 4 it only builds: no local host, no content (see **Moves**) | **placeholder** — home not decided | **placeholder** — `app.sammaditthi.net` |
| app · android, ios, macos | `run.sh` | **placeholder** | **placeholder** — no signing or store upload; Android release builds use the debug key |
| app · windows | `run.bat` | – | – |

Where Flutter web lives on Cloudflare is open — [`web-release.md`](web-strategy/web-release.md) §6.

## Targets and secrets — `scripts/config/`

```
scripts/config/
├── targets.env            committed — every project, branch, origin and URL
├── secrets.env            gitignored — every token, key and account ID
└── secrets.env.example    committed — the same keys, empty, with how to get each
```

Two files in one folder: targets must be committed so a fresh clone and CI know
where things go; secrets must never be.

```bash
# targets.env — sketch
STATIC_SITE_DEV_PROJECT=sammaditthi-dev
STATIC_SITE_DEV_BRANCH=dev
STATIC_SITE_PROD_PROJECT=sammaditthi
STATIC_SITE_PROD_BRANCH=main
STATIC_SITE_PROD_ORIGIN=https://sammaditthi.net

APP_WEB_DEV_PROJECT=            # not decided — web-release.md §6
APP_WEB_PROD_PROJECT=
APP_WEB_PROD_ORIGIN=https://app.sammaditthi.net

# The run scripts' default (an exported value wins there) and the web deploy's.
RESEARCH_BASE_URL=https://wisdom-research.bk-anigha.workers.dev
```

```bash
# secrets.env.example — sketch
CLOUDFLARE_PROD_API_TOKEN=      # ops account — today scripts/static_site/.prod.env
CLOUDFLARE_PROD_ACCOUNT_ID=
RESEARCH_GEMINI_API_KEY=        # the Worker's GEMINI_API_KEY — today research_server/.dev.vars
RESEARCH_APP_TOKEN=             # leave empty — see below
```

- **Deploy scripts read targets from the file only**, keeping the static site's
  rule that an account, a project and a branch are right or wrong together. Run
  scripts are local, so an exported `RESEARCH_BASE_URL` still wins there.
- **Every secret name carries a prefix.** `CLOUDFLARE_PROD_API_TOKEN`, not
  `CLOUDFLARE_API_TOKEN`: the prod branch of a deploy maps it to wrangler's name
  at the moment it needs it, so loading the file can never arm the variable the
  dev path refuses to run with. `RESEARCH_GEMINI_API_KEY`, not `GEMINI_API_KEY`:
  the environment outranks the file, and a shell already exporting the generic
  name for another tool would upload that key to the Worker.
- **Read by key, never loaded whole.** One helper in `lib/common.sh` returns a
  named secret — from the environment when set (CI repo secrets use the same
  names), else by sourcing `secrets.env` in a subshell that prints only that
  key. A prod token must not reach a dev command, and `wrangler deploy
  --secrets-file` uploads every key it is handed. Sourcing keeps a keychain
  lookup working, as `.prod.env` allows today:
  `CLOUDFLARE_PROD_API_TOKEN=$(security find-generic-password -s wisdom-cf-prod -w)`.
- **wrangler takes a file we hand it.** The pinned wrangler has `--env-file` on
  `dev` and `deploy` and `--secrets-file` on `deploy` (checked 2026-09-14). The
  research scripts write a temporary file holding only the research keys, under
  the Worker's names, and **leave out every empty key**: a key left out stays on
  the Worker as it is, an empty one may blank it. `.dev.vars` retires, and a key
  change is an edit plus a deploy.
- **`RESEARCH_APP_TOKEN` stays empty for now.** Once on the Worker it rejects
  every request without `x-app-token` (`research_server/src/app.ts`), and no run
  or deploy script passes the app's matching `--dart-define` yet. Turning it on
  is its own change —
  [`research-endpoint-security-before-testers.md`](research/research-endpoint-security-before-testers.md).
- **`run.sh --node` reads `RESEARCH_STUB` and `RESEARCH_STORE` from
  `wrangler.jsonc`.** Today it sources them from `.dev.vars`. Plain Node never
  reads `wrangler.jsonc`, and without them it quietly serves stub replies.
- **You move the values by hand, in step 1.** Copy `.prod.env` and `.dev.vars`
  into `secrets.env` before the next deploy — until then a prod static-site
  deploy stops at "not set" and the local research server has no Gemini key. No
  script or agent reads the old files. Leave them where they are, still
  gitignored, and delete them when you are ready; never move them into
  `deprecated/`, where nothing ignores them.
- **`research_server/wrangler.jsonc` stays.** wrangler reads the Worker's name,
  vars, placement and CORS list from it; no secret goes in it. Step 4 drops the
  Windows box from its CORS list and keeps `http://localhost:8080` for the local
  web host.
- **Two live changes.** The first research deploy after step 1 uploads the
  Worker's secrets from `secrets.env`; the first after step 4 drops the Windows
  origin. Deploy knowingly.

## The two project-level scripts

```text
./scripts/test_all.sh                    # every product's test.sh
./scripts/test_all.sh app static_site    # only these
./scripts/test_all.sh --quick            # passes --quick to each
```

Keeps going after a failure, then prints `product | PASS/FAIL | time` and exits 1
if anything failed. `wisdom_shared` runs twice, inside `app` and `static_site` —
seconds, and the price of each product standing alone.

```text
./scripts/release_all.sh                       # every deploy.sh once, --dry-run to its dev target
./scripts/release_all.sh --list                # every target, live or placeholder
./scripts/release_all.sh static_site --prod    # one target → its deploy.sh
```

The sweep never dry-runs prod, which needs the release branch, a clean tree and
prod credentials. `--prod` takes exactly one target: three destinations, two
accounts and a confirmation each. The summary shows PASS, FAIL or NOT SET UP,
and the sweep exits 1 only on a FAIL. A named target passes its `deploy.sh` exit
code through, so CI never reads a placeholder's 3 as released.

## What the web deploy keeps from the Windows-box one

`scripts/web/deploy.sh` moves to `deprecated/web_windows_box/`. When
`app/web/deploy.sh` stops being a placeholder, take from it:

| | |
|---|---|
| **keep** | the `--dart-define` block — `RESEARCH_BASE_URL`, `BUILD_SHA`, `VERSION_CHECK_ENABLED`, `VERSION_CHECK_POLL_SECONDS` |
| **keep** | removing `flutter_service_worker.js`, so a redeploy shows without a hard reload |
| **keep** | the `RELEASE_NOTES.md` → notes JSON parser behind the update banner |
| **keep** | waiting after the upload until the live site reports the new SHA |
| **change** | rsync + SSH → a wrangler Pages upload, with the static site's dev/prod and account guards moved into `lib/common.sh` rather than copied |
| **change** | `/healthz` is served by the Dart server, which Pages does not have: the build writes a static version file and `version_check_provider.dart` polls that — a small app change |
| **change** | which assets are stripped depends on how Drift delivers the databases on web |
| **drop** | the SMB mount and the SSH restart |

## Moves — confirmed 2026-09-14

Nothing is deleted: a retired file moves to `deprecated/`. The two secret
templates are the one exception — every line in them moves to
`secrets.env.example`, and a template left behind points at a file nothing reads.

| file | action |
|---|---|
| `tools/validate-release.sh` | move → `deprecated/tools/`; replaced by `scripts/app/test.sh`. Its integration step ran `flutter test integration_test/`, file by file — the crash `all_tests.dart` exists to avoid |
| `tools/check-dart-packages.sh` | move → `deprecated/tools/`; replaced by the `app` and `static_site` `test.sh` |
| `scripts/web/deploy.sh`, `run_win.bat`, `restart_win.bat` | move → `deprecated/web_windows_box/` |
| `server/` | move → `deprecated/server/`, **without waiting for web Drift**. Its `wisdom_shared` path dependency no longer resolves from there; `deprecated/**` is excluded from analysis. No new script tests it. |
| `scripts/{android,ios,macos}/run.sh`, `scripts/windows/run.bat` | `git mv` → `scripts/app/<platform>/` |
| `scripts/web/run_mac.sh` | `git mv` → `scripts/app/web/run_mac.sh` — name kept, it says which machine. Loses its serve step (below) |
| `scripts/static_site/.prod.env.example`, `research_server/.dev.vars.example` | fold into `scripts/config/secrets.env.example`, then delete |

**`run_mac.sh` loses its host, not just its content.** The Dart server did two
jobs: `/api/…` content, and hosting `build/web` (`--web-root`). From step 4
`run_mac.sh` builds, then says there is nowhere local to serve it yet — the
replacement is its own item (**Not in this plan**).

Then repoint every live mention of a moved file, `.dev.vars`, `.prod.env`, or
the Windows box's port 8081:

```bash
grep -rnE 'scripts/(web|android|ios|macos|windows)/|validate-release|check-dart-packages|\.dev\.vars|\.prod\.env|_win\.bat|8081' . \
  --exclude-dir={.git,.claude,node_modules,build,.dart_tool,deprecated,done}
```

On 2026-09-15 that finds code comments (`build_info.dart`,
`version_check_provider.dart`, `research_provider.dart`, `tool/serve.dart`,
`tools/db-finalize.js`), `pubspec.yaml`, `research_server/wrangler.jsonc` and
its `README.md`, the research and static-site scripts, `sync-regen.sh`,
`RELEASE_NOTES.md`, `tools/README.md`, and live docs under `docs/general/`,
`docs/todo/` and `docs/decisions/`. The grep misses
`docs/general/test_strategy.md`, which still runs `flutter test
integration_test` — point it at `scripts/app/test.sh`. Leave alone the old
secret files themselves, the two `.gitignore` lines that guard them until you
delete them,
`ios/Runner.xcodeproj` (8081 inside an object id), and `docs/done/`, which is
history.

`sync-regen.sh` also gets its two hooks fixed: Step 5 calls
`scripts/static_site/test.sh`, and Step 6's static-site "[stub]" calls
`scripts/static_site/deploy.sh --dry-run --skip-tests`, which builds the whole
site and checks its links — Step 5 has just run the tests.

## Steps

Each leaves the static-site and research deploys working, once you have copied
the secrets in step 1.

1. **`scripts/lib/common.sh` and `scripts/config/`.** The helpers — the Node ≥ 22
   guard copied in three scripts today, colours, the secret lookup — and the
   config files. Static site and research server read from them; nothing else
   about them changes but the two live changes above. You copy the secrets
   before the next deploy.
2. **`scripts/static_site/test.sh`**, called by its `deploy.sh`.
3. **`scripts/research_server/test.sh`**, called by its `deploy.sh`; `--prod`
   placeholder.
4. **`scripts/app/`.** Move the run scripts, write `app/test.sh`, add the four
   placeholder deploys, and move the Windows-box files and `server/` to
   `deprecated/`. In the same step drop the Windows box from the Worker's CORS
   list, and `server` from `check-dart-packages.sh`, so that gate keeps passing
   until step 6 moves it.
5. **`test_all.sh` and `release_all.sh`.**
6. **Move** `validate-release.sh` and `check-dart-packages.sh` to
   `deprecated/tools/`; fix `sync-regen.sh`; repoint the paths and docs above.

**Verify.** First rebuild both databases from `tools/` — gitignored build
outputs, safe to regenerate. On 2026-09-15 both on this Mac were WAL-flagged,
which the full `app/test.sh` rightly fails. Then: each `test.sh` passes alone,
with and without `--quick`; `release_all.sh` sweeps every `deploy.sh` and names
each placeholder without running a test; `static_site/deploy.sh --dry-run` and
`research_server/deploy.sh --dry-run` behave as before. No live deploy without
asking.

## CI, once the steps land

Owned by [`web-release.md`](web-strategy/web-release.md) §5:

| job | runs |
|---|---|
| every push / PR | `scripts/test_all.sh --quick` |
| release | `scripts/release_all.sh static_site --prod --yes` |
| integration (optional, macOS runner) | build the databases (`tools/`), then `scripts/app/test.sh` |

## Not in this plan

Gaps the investigation found, each its own item:

- **A local host for `build/web`**, replacing the Dart server's `--web-root`.
  Like `static_site_generator/tool/serve.dart`, it imitates Cloudflare Pages
  rather than serving plain files: unknown paths fall back to `index.html`, as
  Pages does for a project with no `404.html`, so reloading a `/tipitaka/…` deep
  link works; and it sends COOP/COEP, which Drift's wasm build needs for OPFS
  ([`drift-fts5-wasm-spike-results.md`](retiring-dart-server/drift-fts5-wasm-spike-results.md)
  §4). `python3 -m http.server` does neither. Port **8080**, the one
  `run_mac.sh`'s Dart server holds today and already in the Worker's CORS list.
  `run_mac.sh` calls it once it exists.
- `theme_tokens.json` is never checked against the app theme it is dumped from.
- `CORPUS_FIGURES.md` is never checked against a fresh `--write-figures`.
- Build-twice determinism is checked by hand (`web-release.md` §2).
- The HTML validator (backlog C9).
- `research_server` has no tests.
- Mobile release: signing, iOS export, store upload.
