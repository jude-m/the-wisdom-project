# App on the web — deploy setup

**Not set up yet.** `deploy.sh` is a placeholder for both targets; the plan is
step 3 of `docs/todo/retire-personal-cloudflare-account.md`. This README gets
the one-time setup when that lands.

| Target | Account | Pages project | Serves at |
|---|---|---|---|
| dev | wisdomproject.dev | `app-sammaditthi-test` | `https://app-sammaditthi-test.pages.dev` — noindex |
| prod | ops | `app-sammaditthi` — not created yet | `https://app.sammaditthi.net`, later |

`app-sammaditthi-test` already exists (a Hello World, to hold the name: it is
in the research Worker's CORS list). The first `deploy.sh --dev` replaces it.

The databases come from one R2 bucket in the **prod (ops)** account at
`https://db.sammaditthi.net`, used by both targets: R2 is paid, so there is no
dev bucket.

Locally, `./scripts/app/web/run_mac.sh` needs none of this: the app reads the
databases from its own build.
