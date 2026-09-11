# C1–C10 — the bar the static surface clears

> **Moved here 2026-09-11** from `static-html-site-plan.md` §2, archived to
> `docs/done/web/`. These are the maintainer's non-negotiables for the apex
> static site. It is built and clears all ten; they are kept because they are the
> standing test for any future change, not a plan.
>
> Companion decisions: [`static-web-hosting.md`](./static-web-hosting.md)
> (where the files live, how crawlers find them). Open work:
> `docs/todo/web-strategy/static-site-backlog.md`.

| # | Constraint | Why it matters |
|---|---|---|
| **C1** | **Source JSON is the single source of truth.** The generator never edits it; a re-sync regenerates only the affected HTML, deterministically and idempotently. | Corrections arrive regularly; re-sync must be trivial and safe for a solo maintainer. |
| **C2** | **SuttaCentral-grade SEO.** Searching a sutta by name — even a small one — surfaces our page. | This is the whole point of the static surface. |
| **C3** | **Every sutta, even tiny, has a correct, stable shareable link.** | Sharing one sutta must just work, and must not break when routing changes. |
| **C4** | **Per-sutta single view.** A small sutta opens on its own, not only inside a group. | SuttaCentral has this; we want it. |
| **C5** | **All 4 reading layouts** — Pali-only, Sinhala-only, side-by-side, stacked. | Parity with the app's core reading modes. |
| **C6** | **Logical grouping.** Don't shatter the canon into thousands of near-empty pages. | UX, and it avoids a thin/duplicate-content penalty. |
| **C7** | **Continuous reading where natural**, with the URL reflecting position. | The tipitaka.lk reading feel, on static pages. |
| **C8** | **No JS framework.** Zero-JS baseline — every page fully usable with JS off; the search dialog is the one progressive enhancement. | Slowest connections, all bots and LLMs, low maintenance. |
| **C9** | **Single maintainer.** Prefer simplicity and bounded, mechanical effort. | Sustainability. |
| **C10** | **Keep Flutter web as the interactive app.** The static site links into it; it never replaces it. | Don't rebuild the app; route around Flutter's SEO gap. |

## The central tension is C2 vs C6

Per-sutta SEO wants a page per sutta; grouping wants to collapse the tiny ones.
It is resolved **without duplicating text**: distinct suttas get their own file,
micro-suttas share one chapter file and are shown singly via a URL filter.

**A sutta's text never lives in two files.** That is the hard half of the rule.
Which leaf gets its own page is decided by `foldedLeafKeys` in `wisdom_shared` —
frozen, never measured at build time — and the rule behind it is owned by
`docs/todo/web-strategy/reading-units-and-grouping.md`.

## Where each one is enforced now

The constraints predate the code; these are what keeps them true.

| | enforced by |
|---|---|
| C1 | `.manifest.json` source→outputs, plus the build-twice determinism check |
| C2 | the `<title>` grammar, `sitemap.xml`, per-page `<meta name="description">`, absolute self-canonical |
| C3 / C4 | `TipitakaLink` codec, `SitePlan.servingLink`, the `:has(:target)` single view |
| C5 | `reading_layouts.dart` + `test/wiring_contract_test.dart` |
| C6 | `foldedLeafKeys` (frozen snapshot) |
| C8 | `site.js` is the only script — no inline script, no inline handlers, no `eval` |

> These numbers are the **site plan's** C1–C10. They have nothing to do with the
> `C1`–`C9` items in `static-site-backlog.md`, which are chores.
