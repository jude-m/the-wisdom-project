# Research endpoint security — before the first tester build

**Trigger:** the day a web build goes to testers. A web build bakes the Worker
URL into readable JS, so from that day the endpoint is public. Until then
nothing here is urgent (dev-only exposure).

## Where we are (2026-07-20)

- **Decision (2026-07-20): skip the intermediate `X-App-Token`.** Rather than
  ship a shared-secret token for the tester window and then rip it out, we go
  straight to Firebase App Check when it's built. **Trade-off accepted:** until
  App Check lands there is neither a token nor App Check, so the public Worker
  URL is guarded only by CORS — and CORS is browser-only, so a script that
  finds the URL can still burn our Gemini free-tier quota (feature goes 429 for
  real users; no money at risk). Tolerable for a small LAN tester group, not
  for a public release.
- CORS is **pinned** to the tester origin `http://192.168.1.200:8081`
  (`RESEARCH_CORS_ORIGINS` in `wrangler.jsonc`; no trailing slash — must match
  the browser's `Origin` header exactly). Add the real domain/IP alongside it
  (comma-separated) once the web build is hosted somewhere public.
- The `X-App-Token` gate is **built but dormant** on both sides — server
  (`app.ts:59` skips it while `RESEARCH_APP_TOKEN` is unset) and client
  (`research_provider.dart` → `api_client.dart` send the header only when built
  with `--dart-define=RESEARCH_APP_TOKEN=…`). Nothing to tear out now; the App
  Check work decides whether this dead plumbing is removed or repurposed —
  don't let an extractable token quietly become the floor.
- Server-side input hardening is **done**: basket allowlist (`sutta`|`vinaya`)
  and size caps (question ≤ 4k chars, ≤ 12 history turns of ≤ 8k chars) in
  `contracts.ts`.

## Tester-day checklist (~10 min, do all of it together)

> Updated 2026-07-20: steps 2–3 (the `X-App-Token`) are **superseded** — we're
> skipping the intermediate token and going straight to App Check (see the
> decision above). Step 4 (CORS) is **done** (pinned to the LAN tester origin).
> The token steps are kept below only in case that decision is reversed.

1. Deploy any pending server code: `cd research_server && npm run deploy`.
2. Set the token: `openssl rand -hex 32`, then
   `npx wrangler secret put RESEARCH_APP_TOKEN` and paste it. Takes effect
   immediately — **every app build without the matching define now gets 401**,
   so do step 3 in the same sitting.
3. Build/run the app with the same token:
   `--dart-define=RESEARCH_APP_TOKEN=<token>`. Keep the token in a gitignored
   place (env file a run script sources, or `.vscode/launch.json`) — never
   commit it. Local dev against `run.sh` is unaffected (no token in
   `.dev.vars` → gate off on localhost).
4. Pin CORS: set `RESEARCH_CORS_ORIGINS=<web origin>` in `wrangler.jsonc`
   vars and redeploy. Browser-only protection — the token covers
   curl/scripts.
5. Smoke-test the web build once: the `X-App-Token` header triggers a CORS
   preflight. Hono's `cors()` mirrors the requested headers, so it should
   pass — verify it actually does.

## What the token is (and isn't)

It stops the realistic threat: scanners and drive-by scripts that find the
URL and burn quota. It is a shared secret baked into the client — extractable
from a binary, plainly visible in web JS — so against anyone who deliberately
reads our bundle it's only a speed bump. That gap is what App Check closes.

## Next rung: Firebase App Check

The real "only my app" floor — the device proves to Firebase it runs our
genuine app and gets a short-lived signed token; the server verifies the
signature. Not extractable, no user login. Full ladder + details:
`docs/todo/serverless-deployment-decision.md` §6. Three notes that matter:

- **§6's recipe is Python-era** ("firebase-admin as a FastAPI dependency").
  The server is now TS on Cloudflare Workers, where `firebase-admin` doesn't
  run — the landing becomes verifying the `X-Firebase-AppCheck` JWT against
  Google's public keys (JWKS fetch + cache) in a small Hono middleware.
  Client side is unchanged from §6: `firebase_app_check` in pubspec, attach
  the token in `research_remote_datasource.dart`.
- **macOS is the weak platform — and our dev target.** The Flutter plugin is
  broken on macOS (flutterfire#17057): use the debug provider for dev, and
  never read a passing macOS build as proof App Check works.
- **Open decision (§6):** does App Check *replace* `X-App-Token` or sit
  beside it? The macOS bug tempts keeping the token as fallback — but a
  fallback anyone can extract IS the floor, which cancels the upgrade.
  Decide deliberately; don't let it default.
