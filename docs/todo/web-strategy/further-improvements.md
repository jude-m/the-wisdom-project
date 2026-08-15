# Further improvements — static site

Small, self-contained items raised in review and deliberately **not** done at
the time, with the reasoning that made them wait. Each is independently
shippable; none blocks anything.

Opened 2026-08-15, out of the review of the P4 search dialog and the `_headers`
caching work. What that review found and we *did* fix — the hand-bumped cache
token, the `/fonts/*` literal, the wrong 404 message — is recorded in
`static-web-hosting.md` and `render/site_assets.dart`, not here.

Scope note: SEO items live in `seo-wins.md`, phasing lives in
`static-html-site-build-plan.md`. This file is only for the leftovers.

---

## 1. Tests for `buildCacheHeaders()` and the asset wiring

**Why it waited:** tests in this repo are written on request, not by reflex.

Nothing currently tests `render/cache_headers.dart` at all, and the wiring test
hard-codes its asset URLs (`?v=test`), so the hashing in `sitegen.dart` is
uncovered — an unhashed build would ship green. Three belong in
`test/wiring_contract_test.dart`, which already exists to catch exactly this
class of bug (two files that must agree with nothing connecting them):

| test | catches |
|---|---|
| no two `_headers` rules match the same path | the comma-join hazard the whole file is shaped around — Pages merges matching rules and joins duplicate header names, so an overlap silently emits two policies in one `Cache-Control` |
| every non-wildcard rule names a file the build writes | a renamed asset leaving a rule pointing at nothing |
| a page's `<link rel="stylesheet">` equals `SiteAssets.forContent(...)`'s | the hashing wiring itself, which no test sees today |

Collapsing to `/assets/*` made the third of those matter more than it did.
Five exact paths failed **safe**: an asset with no rule of its own simply kept
the revalidating default. A wildcard fails **unsafe** — anything that lands in
that directory linked without a `?v=` is served `immutable` for a year, and a
year of `immutable` cannot be recalled, since purging Cloudflare's cache does
not reach a browser's disk. "Every asset URL comes from `SiteAssets`" is now an
invariant that nothing enforces.

The properties `SiteAssets` is supposed to hold are cheap to assert and were
verified by hand once (2026-08-15, all passing): same inputs → same URLs;
editing the CSS moves only the stylesheet URL; editing *either* `site.js` or the
index moves **both** of their URLs; editing the emblem moves only the emblem;
and the NUL join makes `("ab","c")` and `("a","bc")` hash differently.

## 2. A Content-Security-Policy header

**Why it waited:** it changes the response headers on every URL, which is its
own change to deploy and verify — not something to fold into a caching diff.

`_headers` is now the file where one goes, and the site already qualifies for a
strict policy **with no refactor**. Verified on the full build: zero `<form>`,
zero inline event handlers, zero inline `<script>`, zero `style=` attributes,
and `site.js` builds result rows with `createElement`/`textContent` and calls no
`eval`.

```
/*
  Content-Security-Policy: default-src 'self'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'
```

`/*` overlaps the two `Cache-Control` rules, which is safe: the merge hazard is
per header *name*, and this is a different one.

Live headers already carry `x-content-type-options: nosniff` and
`referrer-policy: strict-origin-when-cross-origin` from Pages' own defaults; CSP
is the one that is missing.

## 3. `.manifest.json` is publicly fetchable

**Why it waited:** it is harmless, and the fix belongs with the `404.html` work.

Measured on the dev deployment (2026-08-15): `GET /.manifest.json` → `200`,
595 KB. It is the source-file → output-path map with content hashes — nothing
secret, nothing linked from any page, and it has to stay in `build/` because
`_clearOutputDir` uses it as the marker that says "this directory is mine".

If it ever matters, the fix is a rule in `_headers`, not a deletion:

```
/.manifest.json
  X-Robots-Tag: noindex
```

Worth doing in the same pass as `seo-wins.md` item 1 (`404.html`), since that is
when unknown and non-page URLs get their answer sorted out generally.

## 4. The preview server does not apply `_headers`

**Why it waited:** the preview deliberately serves `no-store` so you always see
the build that is on disk right now, and a `_headers` parser would be a second
implementation of Cloudflare's semantics to keep in sync — including the
merge-and-comma-join rule that is the easiest part to get wrong.

`tool/serve.dart` mirrors the two Pages behaviours the *output* depends on (the
extensionless rewrite and the `.html` → 308) plus a 404 on `/_headers` itself.
It does not mirror caching, so a mistake in the rule set is invisible locally.

The honest test is a real Pages preview deploy (`scripts/static_site/deploy.sh`)
and a `curl -I`. Revisit only if the rule set ever grows past the two lines it
is today.

## 5. `utf8.decode` on the way to hashing `site.js`

**Why it waited:** it cannot fire on a committed file, and it is a one-line
change to a path that is otherwise correct.

`SiteGenerator.generate` reads `site.js` as bytes, decodes it to a `String`
only to hand it to `SiteAssets.forContent`, which encodes it straight back to
hash it. The round trip does not change the digest — the comment there says so
and it is right — but it is the only step in the asset path that can *throw*:
`utf8.decode` rejects a malformed sequence with a `FormatException`, failing a
whole build over a file it never needed to interpret.

Hashing the bytes directly drops the round trip and the failure mode with it,
at the cost of `forContent` taking `List<int> script` and joining on a `0`
byte rather than the NUL string literal it uses today:

```dart
contentHashOfBytes([...script, 0, ...utf8.encode(searchIndex)])
```

That literal is one `0x00` in UTF-8, so this is the same digest over the same
bytes: no URL moves, and no page re-uploads because of the change.
