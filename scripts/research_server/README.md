# Research server — deploy setup

One Worker, `wisdom-research`, in the **prod (ops)** account at
`https://research.sammaditthi.net`. It is paid, so there is no dev copy: dev
builds, local runs and every app call this one. `deploy.sh --prod` deploys it;
`--dev` explains that and exits.

A release must be cut from `main` (`RESEARCH_PROD_BRANCH`) with a clean tree.
It tags the Worker version with the commit, and ends by checking `/health`.

Everything below is done once, by hand.

## One-time setup

1. **Token.** The prod account's token (`CLOUDFLARE_PROD_*` in
   `scripts/config/secrets.env`) also needs **Workers — Editor**, scope *entire
   account*. No zone permission: the domain is attached by hand (step 3). The
   recipe is in `scripts/config/secrets.env.example`.
2. **Create the Worker.** Workers & Pages → Create → Worker → the *Hello World*
   starter, named exactly `wisdom-research`. Creating a Worker needs the
   *Admin* role, which the token does not have; *Editor* can only deploy to one
   that exists. The first `deploy.sh --prod` then replaces the Hello World and
   turns its `workers.dev` address off.
3. **Attach the domain.** wisdom-research → Settings → Domains & Routes → Add →
   Custom domain → `research.sammaditthi.net`, enabled for **Production only**
   (no preview subdomains).
   It is not in `wrangler.jsonc` on purpose: declaring it there needs a zone
   permission on the token. A deploy should leave the attached domain alone;
   the next release's `/health` check is the first proof.
4. **Gemini key.** `RESEARCH_GEMINI_API_KEY` in `secrets.env` must come from the
   Google project that made `RESEARCH_STORE` (`research_server/wrangler.jsonc`).
   Every deploy and `run.sh` check the pair before doing anything else.

Check it: `curl https://research.sammaditthi.net/health` → `"mode":"live"`.

## Rate limit

The endpoint is public and has no login, so one script could use up the Gemini
quota. A zone rate-limiting rule stops a single IP from hammering it. It does
not stop many IPs at once; Firebase App Check is the real fix
(`docs/todo/research/research-endpoint-security-before-testers.md`).

ops → `sammaditthi.net` → Security → WAF → Rate limiting rules → Create:

- **Match:** URI Path *equals* `/research`. Never leave it matching every path:
  the rule is on the whole zone, so it would block ordinary visitors to the
  static site.
- **Characteristics:** IP.
- **Rate:** 6 requests per 10 seconds. The app on the web sends two requests
  per question (a CORS preflight, then the question), so that is three
  questions; the desktop and mobile apps send no preflight, so six. Cloudflare
  counts roughly: a test burst got its first 429 on the 8th request.
- **Action:** Block. The free plan blocks for 10 seconds; that cannot be changed.
- **Deploy**, not *Save as draft*.

The free plan can't match on hostname, so the rule counts `/research` on every
host in the zone — a future `app.sammaditthi.net/research` page would share it.

## Rollback

Every build calls this Worker, so go back first and fix after. Dashboard:
wisdom-research → Deployments → the last good version → ⋯ → *Rollback*. Each
version's tag is the commit it came from. From the terminal, at the repo root —
in a child bash, so the prod token doesn't stay in your shell, and through
`use_cloudflare`, so it stops unless the token reaches the ops account:

```sh
bash -c '. scripts/lib/common.sh && use_cloudflare prod \
  && cd research_server && "$WRANGLER" rollback'
```

## Good to know

- **The Google side is still the personal project.** The key and the File
  Search store move to the ops `wisdom-research` Google project with the ingest
  plan (`docs/todo/research/research-ingestion-ops-chunking-full-corpus.md`); the
  store and the key then change together, in one deploy.
- **CORS.** A browser app can only call the Worker from an origin listed in
  `RESEARCH_CORS_ORIGINS` (`wrangler.jsonc`). Add the prod app's origin there
  when the app goes live on the web, then deploy.
- **A dev Worker later**, if ever: a second Worker in the dev account with its
  own domain, a `CLOUDFLARE_DEV_*` path in `deploy.sh --dev`, and its own
  `RESEARCH_BASE_URL`.
