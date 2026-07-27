# web_client — Jaspr web prototype

De-risking prototype for replacing the Flutter-web surface with a
server-rendered + hydrated [Jaspr](https://jaspr.site) app. Proves
**multi-tab reading** and **SSR/hydration** against the existing shelf API.

Spec: `docs/todo/jaspr-web-client-migration.md` ·
Findings: `docs/todo/jaspr-prototype-findings.md`

## Prerequisites

- **Dart ≥ 3.11** — Flutter ≥ 3.44 bundles Dart 3.12, which is enough
  (jaspr_cli 0.23 needs ≥ 3.11; no separate SDK required).
- `jaspr_cli` activated: `dart pub global activate jaspr_cli`
- The content API running locally (terminal 1):

  ```bash
  cd server && dart run bin/server.dart        # :8080, assets from ../assets
  ```

## Run (development)

```bash
jaspr serve -p 8081
# → http://localhost:8081/sutta/dn-1
```

The API base URL defaults to `http://localhost:8080`; override with
`--dart-define=WISDOM_API=...`.

## Build (release)

```bash
jaspr build       # → build/jaspr/app (server binary) + build/jaspr/web/ (assets)
PORT=8082 ./build/jaspr/app
```

## Verify (e2e harness)

With both servers running:

```bash
cd tool/e2e && npm install && node test.js     # 14 PASS/FAIL checks
node shot.js                                   # screenshots → /tmp/proto_*.png
```

## Layout

- `lib/pages/` — server-only routed pages (`/`, `/sutta/:fileId`); SSR data
  preload happens here.
- `lib/src/components/` — `reader_shell.dart` is the hydrated `@client`
  island (tabs, nav, search, reader).
- `lib/src/state/` — `tab_provider` port (jaspr_riverpod) + actions.
- `lib/src/domain/`, `lib/src/utils/` — **prototype-only copies** of the
  app's pure-Dart logic (entities, parser, transliterator). The real build
  extracts these into a shared package instead.
- `web/styles.css` — all styling (theme values → CSS custom properties).

## Version pins

Jaspr family + riverpod are pinned exactly in `pubspec.yaml` (pre-1.0
framework; riverpod 3.3.x breaks jaspr_riverpod 0.4.5 — see findings doc).
