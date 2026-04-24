# Things to Consider Before Going Live

A running list of caching, asset, and deployment items to revisit before the
app is exposed to the public internet. Everything here is fine for LAN-only
deploys today, but will need attention when real users arrive over WAN.

---

## 1. HTTP caching strategy for the web bundle

### What we do today

`server_app.dart` sends `Cache-Control: no-cache` on files that change every
deploy:

- `index.html` and `/` (the default document)
- every `.js` file (`main.dart.js`, `flutter.js`, `flutter_bootstrap.js`)
- `manifest.json`, `version.json`

Everything else (fonts, `canvaskit.wasm`, images, `assets/*`) inherits
`shelf_static`'s default: `ETag` + `Last-Modified`, no explicit
`Cache-Control`. Chrome then uses heuristic freshness to decide how long to
trust them without revalidation.

`no-cache` means: "browser may cache, but MUST revalidate with server before
using". Combined with the ETag, unchanged files return a tiny `304 Not
Modified` (fast), changed files return `200` with fresh bytes (correct).

### Why this is enough for LAN

Revalidation round-trips on a LAN are ~5–30 ms. Six revalidations per cold
load is invisible. The correctness win — every deploy shows up on the next
reload for every user — dwarfs the cost.

### Why it needs rethinking for public internet

Round-trip time on mobile / transcontinental networks is 150–250 ms. Six
revalidations, some serialized on `main.dart.js`, can add **200–800 ms** to
cold startup. Still vastly better than broken deploys, but not optimal.

### The long-term fix: content-hashed filenames + `immutable`

Industry standard for SPAs:

| File                     | Caching                                             |
|--------------------------|-----------------------------------------------------|
| `index.html`             | `Cache-Control: no-cache` (always revalidate)       |
| `main.<hash>.js`         | `Cache-Control: public, max-age=31536000, immutable`|
| `flutter.<hash>.js`      | `Cache-Control: public, max-age=31536000, immutable`|
| fonts, wasm, images (hashed) | `Cache-Control: public, max-age=31536000, immutable`|

Flow:

1. Browser checks `index.html` (cheap ~300 byte 304).
2. New `index.html` references `main.NEW_HASH.js` — a URL the browser has
   never seen.
3. Browser fetches it fresh. Everything else it already has cached for a
   year.
4. Zero-cost cache hits from then on.

### What that costs to implement

Flutter web does NOT hash `main.dart.js` or `flutter.js` by default. Options:

- **Post-build step in `deploy-web.sh`**: after `flutter build web`, rename
  `main.dart.js` → `main.<sha256-prefix>.js`, same for `flutter.js`, then
  rewrite references inside `flutter_bootstrap.js` and `index.html`. ~20
  lines of bash. Deterministic, no runtime changes.
- **Reverse proxy (nginx, Cloudflare)**: handle cache headers at the proxy;
  some CDNs auto-rewrite for you. More infra, less code.
- **Accept the `no-cache` overhead**: pragmatic if latency isn't critical.
  The app isn't real-time; 300 ms slower startup on public launch is
  survivable.

### CDN compatibility

`no-cache` is honored correctly by Cloudflare, Fastly, CloudFront. The edge
can still cache at its tier and revalidate with origin; browsers revalidate
with the edge. So round-trip cost collapses to the edge (usually 10–30 ms
globally) instead of origin. Putting a CDN in front is the quickest win
without restructuring the build.

### TL;DR decision points for launch day

- **Minimum viable**: keep current `no-cache` setup, add a CDN in front.
  Works, slight cold-start hit.
- **Better**: add a post-build hash-and-rewrite step; keep `no-cache` on
  `index.html` only; mark hashed assets `immutable`.
- **Keep forever**: `Cache-Control: no-cache` on `index.html`. It's the
  universal SPA pattern.

---

## 2. Pushing through binary-asset changes

Cache rules for non-JS assets (fonts, images, wasm) are still default today,
so swapping a binary file in-place is invisible to Chrome's cache.

### Changes that ship automatically

Anything that compiles into `main.dart.js` is covered by `no-cache`:

- Widget code, layouts, navigation
- `TextStyle` — font size, weight, letter spacing, colour
- Theme definitions, colour palette
- Localization (ARB files compile into the bundle)
- `index.html` changes
- `manifest.json` / favicon references

### Changes that DON'T ship without effort

Anything where only the *file contents* change but the URL stays the same:

- Font file binaries (`NotoSansSinhala-Regular.ttf` replaced with a new
  version)
- Image file binaries
- `canvaskit.wasm` (Flutter usually upgrades this by version; stable within
  an engine revision)
- Raw JSON / DB files under `assets/` that the client reads directly

### How to push a font/image binary change

**Option A — rename the file (recommended)**

```
assets/fonts/noto-sans-sinhala/NotoSansSinhala-Regular.ttf
  → NotoSansSinhala-Regular-v2.ttf
```

Update references in `pubspec.yaml` and `web/index.html` preload tag. New
URL = automatic cache-bust for every user. Zero infra work.

**Option B — temporarily widen `mustRevalidate`**

In `server_app.dart`, add `.ttf` / `.otf` / `.png` to the `mustRevalidate`
list. Deploy. Wait ~24–48 hours so every returning user revalidates once.
Remove the extensions and redeploy.

Trade-off: a few extra revalidations per cold load during the window. Use
when renaming is impractical (e.g. many files at once).

**Option C — long-term: hash asset filenames in the build**

Same pattern as `main.dart.js`. The deploy script renames each asset to
include a content hash, rewrites `AssetManifest.json` / `FontManifest.json`
to match. Most work; best user experience.

**Option D (don't use) — `?v=2` query strings**

Works for `<link>` and `<img>` tags in `index.html`, but Flutter's engine
loads fonts/assets from `pubspec.yaml`-derived URLs without the query
string. Incomplete fix; skip.

---

## 3. Service worker strategy

`deploy-web.sh` currently strips `flutter_service_worker.js` from the build
(line 128). Reasoning: without it, redeploys are served fresh immediately
via the `no-cache` mechanism above.

### When to reintroduce a service worker

- **Offline support**: if the app ever needs to work without a live server
  connection (e.g. airplane mode reading), a SW is the only way to cache
  the Flutter bundle + assets for offline use.
- **Installable PWA**: iOS/Android install prompts and true PWA experience
  require a registered SW (even a minimal one).

### What to watch out for if you do

- **Cache eviction on deploy**: the SW's own cache won't evict itself just
  because the server changed. You need a versioning scheme inside the SW so
  it notices a new `index.html` and flushes its caches. Flutter's default
  SW template does this via `serviceWorkerVersion` — handle updates with
  an explicit `registration.update()` + `skipWaiting()` flow, or users
  stay on old versions for days.
- **Stale SW lockout**: once a SW is registered in a user's browser, it
  lives there until explicitly unregistered or superseded. If a SW bug
  ships, every user is stuck until they hard-reload or you ship a fix SW.
  Have a "kill switch" SW ready.
- **Interaction with `no-cache`**: SW intercepts fetches before HTTP cache.
  Your `Cache-Control` headers no longer matter for SW-managed resources.
  Pick one strategy per asset class; don't mix.

Safer posture: **don't reintroduce a SW until you have a clear offline /
PWA requirement**. The `no-cache` + hashing combo handles pure online
deployment with far less complexity.

---

## 4. Security & transport items to revisit before public launch

Not caching-related but same "LAN is forgiving, public isn't" theme.

- **HTTPS termination**: the Windows server runs plain HTTP on port 8081.
  Browsers increasingly refuse features (clipboard, fullscreen, some APIs)
  on `http://`. Put a proper TLS-terminating proxy (nginx, Caddy,
  Cloudflare) in front before exposing publicly.
- **CORS**: `_corsMiddleware` sends `Access-Control-Allow-Origin: *`. Fine
  for local dev; on public internet, restrict to the real origin(s).
- **Rate limiting**: no middleware today. Public search endpoints are
  cheap but FTS queries can be expensive. Add a simple per-IP bucket at
  the proxy layer.
- **Request size / timeout limits**: shelf uses defaults. For a public
  server, cap body size and set request/response timeouts.
- **Logging PII**: `_requestLogger` logs paths. Verify no user-identifying
  query params get written to disk.

---

## 5. Deploy pipeline items

- **Deploy verification runs only on `/healthz` SHA match**. Once public,
  consider also hitting a sample page (`/`) and checking the response
  contains a known build marker — catches cases where the server is up but
  serving the wrong static root.
- **Rollback**: no automatic rollback today. Keep the previous `build/web/`
  tree around after a deploy (e.g. `build/web.prev/`) so a single
  `mv` reverts the live site if a bad deploy slips through.
- **Asset sizes**: watch `main.dart.js` size over time. Flutter web bundles
  can silently grow with deps; a budget check (e.g. fail deploy if
  `main.dart.js > 5 MB`) stops regressions before users notice.

---

## 6. Quick reference — what triggers a browser cache miss today

After the `no-cache` change in `server_app.dart`:

| Change type                                    | Next reload ships it? |
|------------------------------------------------|------------------------|
| Any Dart code change                           | Yes (main.dart.js)     |
| Theme / typography / widget styling            | Yes                    |
| Translations (ARB files)                       | Yes                    |
| `index.html` edits                             | Yes                    |
| `manifest.json` / `version.json`               | Yes                    |
| New font file added (new filename)             | Yes                    |
| Font file replaced (same filename)             | **No** — rename it     |
| Image file replaced (same filename)            | **No** — rename it     |
| `pubspec.yaml` asset path change               | Yes (compiled in)      |
| Server-side API behaviour change               | N/A — no caching       |

If something doesn't land and isn't in the "No" rows above, the first
debugging step is still **DevTools → Network → Disable cache → reload**.
That tells you instantly whether it's a caching issue or a deploy issue.
