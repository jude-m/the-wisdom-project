# Static site — deploy setup

`deploy.sh --dev` and `--prod` upload the built site to Cloudflare Pages. This
is what has to exist first. Everything here is done once, by hand.

| Target | Account | Pages project | Serves at |
|---|---|---|---|
| dev | wisdomproject.dev | `sammaditthi-test` | `https://sammaditthi-test.pages.dev` — noindex |
| prod | ops | `sammaditthi` | `https://sammaditthi.net` — indexable |

The names are in `scripts/config/targets.env`.

## One-time setup, per account

1. **Token.** An account-owned API token with *Cloudflare Pages: Edit* and
   *Account Settings: Read*. The recipe is in
   `scripts/config/secrets.env.example`. Put it and the account ID in
   `scripts/config/secrets.env` as `CLOUDFLARE_DEV_*` or `CLOUDFLARE_PROD_*`.
2. **Pages project.** Workers & Pages → Create → Pages → *Use direct upload*.
   Name it as in the table and create it without uploading anything — the
   deploy does that. Its **production branch must be `main`**: dev deploys to
   it for the clean URL, prod for the indexable one; a deploy to any other
   branch becomes a preview at `<branch>.<project>.pages.dev`. The deploy
   checks this and stops if the project is missing or its branch is not
   `main`. Never let `wrangler pages deploy` create a project; its prompt
   picks whatever git branch you are on.
3. **Prod only — the domain.** On the `sammaditthi` project: Custom domains →
   Set up a custom domain → `sammaditthi.net`. Wait for *Active*.
   `deploy.sh --prod` checks this and refuses until it is, because every page
   names the domain in its canonical URL.

Dev needs nothing for noindex: the generated `_headers` sends
`X-Robots-Tag: noindex` on every `*.pages.dev` host, which covers dev and prod's
own `sammaditthi.pages.dev`, and never the custom domain. After every upload the
deploy checks the site answers 200, noindex on dev and indexable on prod.

## Rollback

Pages project → Deployments → the last good deployment → ⋯ → *Rollback to this
deployment*. Then fix, and deploy again.

## Good to know

- **The first upload to a new project sends the whole build**; later ones send
  only changed files. On a slow uplink it fails with `Error: {})` and
  `UND_ERR_HEADERS_TIMEOUT` — wrangler gives up on a batch that has no reply
  after about five minutes. Do the first one from a fast connection.
- When a deploy dies with `Error: {})` and nothing else, the real cause is in
  `~/Library/Preferences/.wrangler/logs/`.
- Never run two deploys at once. There is no lock, and the second one wipes
  `static_site_generator/build/` while the first is uploading.
