# Deep Link — Test Coverage Plan

> Status: **Parked 2026-07-29** on branch `feat/static-site`. Written after the
> code review of `packages/wisdom_shared/test/links/tipitaka_link_test.dart`
> (the first test the link codec ever had). Layer **A is done**; the A2 sweep
> and layers B–D are not started.
> Companion: [`./deep-linking-and-shareable-urls.md`](./deep-linking-and-shareable-urls.md)
> owns the URL *grammar* and the decisions; this doc only says **what proves it
> works**.
>
> The review's own findings (F1–F7), simplifications and the untested-edge list
> were applied directly to the test file (56 → 67 tests) and are **not**
> repeated here. Layer A below assumes them. Two findings are deferred and do
> live here: **F5** (corpus sweep, § A2 — it belongs outside `test/`) and
> **F6** (nothing runs these tests automatically, last section).

---

## TL;DR

Four layers carry a deep link. One has tests.

| Layer | Code | Tests today |
|---|---|---|
| **A** URL codec | `packages/wisdom_shared/lib/src/links/tipitaka_link.dart` | 68 (2026-07-29) — every shape in A covered; corpus sweep **A2 outstanding** |
| **B** Reference resolver | `packages/wisdom_shared/lib/src/refs/suttacentral_ref_resolver.dart` | **zero** |
| **C** Static-site URL emission | `static_site_generator/lib/domain/site_page.dart`, `lib/render/page_template.dart` | **zero** (no `test/` dir) |
| **D** App-side wiring | `lib/presentation/providers/deep_link_provider.dart`, `widgets/app/deep_link_listener.dart` | **zero** |

Recommended order: **A2 + B** (pure Dart, no new infra, sub-second) → **C** →
**D**. C catches a class of bug nothing else can; D is worth little until
Universal Links are live on a real domain.

## The surface

```
"SN 15.3"  ──parseRef──►  "sn15.3"  ──concordance──►  "sn-2-3-1-3"      ← B
                                                            │
static-site href   /tipitaka/<key>   ───────────────────────┤           ← C
OS link            sammaditthi://tipitaka/<key>?e=12.4  ────┤
web start URL      Uri.base  ───────────────────────────────┤
                                                            ▼
                                                   TipitakaLink.parse   ← A
                                                            │
                                            openTipitakaLinkProvider    ← D
                                                            ▼
                                                       tab opens
```

---

## A — extend `packages/wisdom_shared/test/links/tipitaka_link_test.dart`

> **DONE 2026-07-29** (67 → 68 tests). All nine shapes below are covered; the
> table stays as the record of *why* each is pinned. **A2 is not done.**

No new files or dependencies. Each shape below was probed against the current
implementation on 2026-07-29; the stated behaviour is what it does *today*.

| Shape | Today | Why it needs pinning |
|---|---|---|
| `…/tipitaka/sn-2-3#sn-2-3-1-3` | fragment **dropped** → opens the vagga | The locked grouped-vagga form (see companion doc, "Grouped-sutta fragments"). Pin the baseline + `TODO`, so the day `parse` starts preferring a nodeKey-shaped fragment it shows as a deliberate flip, not a silent one. |
| `…?layout=stacked` | ignored, link survives | Part of the documented grammar (layout decision, 2026-07-20) but **not implemented anywhere in `lib/`**. Also test `?e=12.4&layout=stacked` for param independence. |
| `https://sammaditthi.app/tipitaka/<key>` | parses | The static-site production host. |
| `https://app.sammaditthi.app/tipitaka/<key>` | parses | The Flutter-web host — same path, no `/app/` prefix (topology decision, 2026-07-23). |
| `SAMMADITTHI://TIPITAKA/SN-2-3` | **parses** | Uppercase works on the custom scheme (`Uri` lowercases the host) but *not* on https — see F2. Whichever way that resolves, both forms need a test. |
| `sammaditthi://foo/tipitaka/<key>` | parses | Wrong custom-scheme host is tolerated as a path prefix. Intended? |
| `?e=1&e=2` | last wins → page 2 | |
| `?E=12.4` | ignored (param is case-sensitive) | |
| `…/tipitaka//sn-2-3` | parses (empty segments skipped) | |

### A2 — corpus sweep: every real nodeKey parses (review finding F5)

Not in `test/`. `_nodeKeyPattern` is the one gate every deep link passes, and
the test file only pins **3** of the 53 dotted keys — a regression test for the
bug we know about, silent about key #54 or any other shape in the tree. Sweep
all 16,355 keys in `assets/data/tree.json`:

```dart
for (final key in tree.keys) {
  if (TipitakaLink.tryParse('https://x/tipitaka/$key') == null) {
    failures.add(key); // this node can never be deep-linked
  }
}
```

Turns "we fixed the dots" into "**no key in the corpus is unlinkable**".

Belongs in `static_site_generator/tool/verify_corpus_invariants.dart`, not the
package: `wisdom_shared` is Flutter-free by design, can't reach `assets/`, and a
16k-node load does not belong in a sub-second suite — same split already used
for markers and tree. ~10 lines, `TipitakaLink.tryParse` only, no shim.

**Snapshot, not a guarantee.** Re-run after every `tree.json` sync from
tipitaka.lk (see the canon-sync workflow): a newly-introduced dotted or
odd-shaped key breaks links again, and only this check would notice.

## B — new `packages/wisdom_shared/test/refs/suttacentral_ref_resolver_test.dart`

`SuttaCentralRefResolver` is the other half of the citation path and has never
been tested. It feeds **two** shipped features: tappable research citations
(`citation_source_sheet.dart:99-102`) and the "type SN 15.3 → jump" search.

Pure Dart with an injected concordance `Map`, so it is table-testable exactly
like the codec:

- `parseRef` accepts `"SN 15.3"`, `"sn 15.3"`, `"SN15.3"`, `"sn15.3"` → `sn15.3`
- **anchoring**: `"metta123"` and `"see SN 15.3 here"` must *not* parse
  (the regex is anchored precisely so ordinary search words don't fire)
- unknown book (`"xy1.2"`) → null; multi-dot (`"an3.65"`, `"sn15.3.1"`)
- `displayRef` round trip: `sn15.3` ⇄ `SN 15.3`, `dhp1` → `Dhp 1`, unknown book
  falls back to UPPERCASE, non-matching input returned unchanged
- `resolveToNodeKey` miss (well-formed ref, absent from the concordance) → null
- `isReady` false on an empty map

**Fixture, not the asset.** `assets/data/sc-to-bjt.json` is still the SN 15 seed
(20 entries, 1.1 KB) and `wisdom_shared` must keep building standalone — use a
handful of copied rows. When the full concordance is generated by
`tools/suttacentral_map/`, a "every uid resolves to a key that exists in
tree.json" sweep belongs in
`static_site_generator/tool/verify_corpus_invariants.dart`, not here — same
split the package already uses for markers and tree.

Effort: ~20 tests, one new file.

## C — new `static_site_generator/test/` — codec ⇄ generator agreement

**The gap that matters.** The generator builds the same URL grammar
independently and nothing checks the two agree:

- `lib/domain/site_page.dart:38` — `String get url => '/tipitaka/$nodeKey';`
- `lib/render/page_template.dart:121` — breadcrumb ancestors
- `lib/render/page_template.dart:138` — canon ↔ aṭṭhakathā twin cross-link
- `lib/render/page_template.dart:162` — child lists on container TOCs
- `lib/render/page_template.dart:186` — `id="<nodeKey>"` anchors (the `:target`
  single-view targets, i.e. the future `#fragment` link targets)

Once Universal Links are live, **every static-site href is also an app deep
link** — the OS intercepts the tap. A divergence means the link works in a
browser and dies in the app, which is exactly the failure users report as "the
app opened on the wrong page".

Test: emit pages from a synthetic tree (including the dotted commentary keys —
`atta-ap-dhs-2-1-1.1` and friends, 53 of them in the real tree), then assert
every emitted `href` and `id` round-trips through `TipitakaLink.parse` back to
the same nodeKey.

`test: ^1.24.0` is already a dev-dependency there; only the `test/` directory is
missing. **Timing:** `lib/domain`, `lib/render` and `lib/grouping` are still
untracked and in flux — either write the narrow `SitePage.url` assertion now, or
wait for the generator to land and do the full href sweep then.

## D — new app-side tests (flutter_test)

The "out of scope" gap from the review: **nothing in `test/` or
`integration_test/` references `TipitakaLink` or the deep-link path at all.**

`test/presentation/providers/deep_link_provider_test.dart` —
`openTipitakaLinkProvider` (`deep_link_provider.dart:38-63`):

- `entryStart` derivation (`:46-47`): page **with** entry → that entry; page
  **without** entry → `0` (start of page, never the node's own entry); **no**
  page → `null` (node's own coordinates)
- tree load fails → returns `false`, opens nothing
- unknown nodeKey (`openTabFromNodeKeyProvider` → `-1`) → `false`
- success → switches `selectedAppSectionProvider` to `AppSection.reader` and
  syncs the navigator, *from any section* (Home/Research/Notes)
- `tipitakaLinkUrlBuilderProvider` uses `LINK_BASE_URL` (default
  `http://localhost:8080`)

`test/helpers/mocks.dart` and `pump_app.dart` already exist.

**Skip `DeepLinkListener` itself** unless something breaks: mocking the
`app_links` stream and `Uri.base` is heavy, and its logic is three lines
(parse → mounted check → fire-and-forget) already covered either side.

---

## Note: one command runs the package tests — shipped 2026-08-06

Root `flutter test` still does not recurse into `packages/`, and
`.github/workflows/` is still empty, so this was once "only if someone types
`dart test` inside the package". It is now `tools/check-dart-packages.sh`:
`dart analyze` + `dart test` in `packages/wisdom_shared`,
`static_site_generator` and `server`, ~35s for all three. Three callers run it —
`tools/validate-release.sh` (Step 6), `scripts/web/deploy.sh` (Phase 2) and
`scripts/bjt-sync-regen/sync-regen.sh` (Step 5, straight after a corpus
re-sync).

It covers the three Dart packages only. Root `flutter test` was left out on
purpose: different runner, 45 files, and the integration half needs a device —
folding it in produces a command nobody runs.
