# Research endpoint security — before the first tester build

**Trigger:** the day a web build goes to testers. A web build bakes the Worker
URL into readable JS, so from that day the endpoint is public. Until then
nothing here is urgent (dev-only exposure).

## Where we are (2026-07-19)

- The live Worker (`wisdom-research.bk-anigha.workers.dev`) has **no gate**:
  `RESEARCH_APP_TOKEN` is unset (the gate code in `app.ts` exists but stays
  off without it) and CORS is `*`. Anyone with the URL can spend our Gemini
  free-tier quota — the risk is the feature going 429 for real users, not
  money.
- Server-side input hardening is **done**: basket allowlist (`sutta`|`vinaya`)
  and size caps (question ≤ 4k chars, ≤ 12 history turns of ≤ 8k chars) in
  `contracts.ts`.
- The client is **already wired**: it sends `X-App-Token` whenever the app is
  built with `--dart-define=RESEARCH_APP_TOKEN=…` (`api_client.dart`).

## Tester-day checklist (~10 min, do all of it together)

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
