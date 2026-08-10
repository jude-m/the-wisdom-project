# SEO wins

What actually moves search performance on the static site, ranked by payoff.

Scope: the apex static site only. `app.<domain>` stays `X-Robots-Tag: noindex`
(crawlable, not indexed) — see `static-web-hosting.md`.

This is the **what and why**. The phasing lives in `static-html-site-build-plan.md`
§P5; several items below are already named there. Where they overlap, the build
plan owns the schedule and this doc owns the reasoning. Don't restate a decision
in both.

## What already works — don't regress it

Worth stating, because most static sites pay for these and this one gets them free:

- **Zero JS, one stylesheet, self-hosted subset fonts** with `font-display: swap`
  (`stylesheet.dart:124`). Core Web Vitals should be near-perfect out of the box.
- **The `<title>` grammar** — `<leaf> — <vagga> — <collection>`
  (`page_template.dart:470`). This is doing nearly all the keyword work on the
  site. It exists because 1,165 leaves are titled with only a number and 2,216
  share a name; without the trailing parts, thousands of pages would carry an
  identical `<title>`, which is the duplicate-content signal C2 was written to
  avoid.
- **Self-canonical on commentary.** The 6,731 `atta-*` pages point at themselves,
  never at their canon twin — they're different texts, not duplicates.
- **One text, one URL.** The grouped-vagga rule means no passage is ever
  reachable at two addresses, so there is no internal duplicate-content problem
  to clean up later.

## 1. `404.html` — missing

Nothing in the generator writes one and there is none in `build/static_site/`.

Cloudflare Pages needs a `404.html` at the output root to serve a real 404.
Without one it falls back to `index.html`, so — as observed on 2026-08-03 —
**every missing path returns HTTP 200**, serving the landing page complete with
`<link rel="canonical" href="/">`. Google classifies that as a **soft 404**, and
the canonical tag actively tells it these are all the same page.

At 16,356 pages the surface for typo'd and stale inbound links is large, and soft
404s spend crawl budget and get logged as quality problems against the whole
site. This is the worst item on the list and the cheapest to fix.

The page should carry the toolbar and a link back to `/`, so a wrong URL still
lands somewhere useful.

**Verify after deploying:** `curl -I https://<host>/tipitaka/does-not-exist`
must return `404`, not `200`.

## 2. `<meta name="description">` — missing

`document_shell.dart:38-44` emits five things: charset, viewport, title,
canonical, generator. No description.

Google writes the SERP snippet from the description when there is one and from
scraped page text when there isn't. Scraped text on a canon page is the opening
line of Pali — accurate, but it tells a searcher nothing about what they found.
This is the **click-through** lever, and it's the largest one available.

Descriptions have to be generated, not written — there are 16,356 of them. The
material is already on hand: node name, its place in the tree, the collection,
and how many suttas the page holds. Something like *"<leaf>, from <vagga> of
<collection>. Pali with Sinhala translation."* Keep it under ~155 characters and
never emit an empty one — no description beats a blank description.

`/` gets a hand-written description, not a generated one. It's the highest-value
page on the site.

## 3. `sitemap.xml` + `robots.txt` — missing

Neither is generated. With 16,356 pages, discovery currently depends entirely on
Google crawling the TOC chain down from `/`.

- **`sitemap.xml`** — all pages, one file (the 50,000-URL / 50 MB limit is not
  close). `<lastmod>` from the manifest hashes, as P5 already specifies, so a
  rebuild that doesn't change a page doesn't claim it changed. Lying in
  `<lastmod>` gets the whole signal ignored.
- **`robots.txt`** — allow all, plus a `Sitemap:` line. That line is the main
  reason the file needs to exist; the apex has nothing to hide.

Note the app origin is handled differently and deliberately: `X-Robots-Tag:
noindex` on `app.<domain>`, **not** `Disallow`. Disallow would block the crawl
and the `noindex` would never be read.

## 4. Absolute canonical — currently root-relative

`document_shell.dart:11-15` parks this on purpose: an absolute canonical needs a
settled apex domain, and a wrong one points every page at a host that doesn't
serve it. That was the right call at the time.

The domain is settled now, so this is unblocked. Relative canonicals are legal
and resolve against the document URL, but they can't do the one job canonicals
are for — telling Google which of several hosts serving identical bytes is the
real one. Preview deployments are covered today by Cloudflare's automatic
`noindex`, so this is insurance rather than a live bug. Do it when the domain is
wired.

## 5. Open Graph tags — missing

Parked at P5 alongside JSON-LD. Not a ranking factor at all — this is the
**sharing** story, and for this audience sharing happens in WhatsApp and
Facebook, not in search results. A pasted link with no OG tags renders as a bare
URL; with them it renders as a card carrying the sutta name.

`og:title` (un-welded per D2, same as `<title>`), `og:description` (reuse item 2),
`og:url`, `og:type`, `og:site_name`, `og:locale`. An `og:image` needs a real
image — a generated one per page is out of scope, so a single site-wide image is
the sane version.

## 6. JSON-LD structured data — missing

Also parked at P5. The one with visible payoff is **`BreadcrumbList`**: it
replaces the URL line in a search result with the readable trail, which is worth
more to a browsing reader than the path ever was. The tree already has
everything needed — the breadcrumb is built in `site_chrome.dart:131`.

Beyond that, `Book` / `Chapter` for the canon structure is defensible but has no
rich-result treatment, so it's speculative. Do `BreadcrumbList` first and stop
there unless there's a reason not to.

## 7. Pali text isn't marked as Pali

Every page is `<html lang="si">` (`document_shell.dart:37`), and the Pali cells
carry no `lang` of their own — they inherit Sinhala.

The Pali *is* in Sinhala script, so the rendering is right, but the language
declaration isn't: `lang` is a language attribute, not a script one. The correct
value on `.pali` cells is `lang="pi-Sinh"` — Pali, Sinhala script.

Modest SEO effect (it sharpens language targeting on pages that are half
non-Sinhala). Real accessibility effect: a screen reader currently pronounces
Pali using Sinhala rules.

## 8. Duplicate headings when both languages render

Flagged in the build plan (§ around line 727) and carried to P5: rendering both
languages emits two `<hN>` per heading row, so the document outline says
everything twice. Rendering only one would leave the single-language layouts with
no outline at all, which is why it wasn't fixed inline.

Low priority — Google is tolerant of messy outlines — but it belongs on this list
because the fix probably falls out of the structured-data work rather than
standing on its own.

## 9. Preload the primary font

`font-display: swap` is set, so there's no invisible-text stall. But the font
request can't start until the stylesheet has been fetched and parsed, which puts
it two round-trips deep on the critical path.

One `<link rel="preload" as="font" type="font/woff2" crossorigin>` for the single
most-used weight would pull that forward. Only the primary weight — preloading
fonts a page never uses is a net loss. Worth measuring before and after rather
than assuming.

## Not worth doing

- **Shortening `/tipitaka/` in the URL.** Words in the URL are a very small
  ranking factor by Google's own repeated guidance. The `<title>` and `<h1>` do
  that work. The segment is worth keeping for reasons that have nothing to do
  with SEO — it scopes AASA/assetlinks to `/tipitaka/*` instead of `/*`, and the
  codec is shared with the app.
- **Keyword-stuffing titles.** The current grammar is already at the right
  density; adding "Tipitaka" or "Buddhism" to 16,356 titles would read as spam
  and dilute the part that identifies the page.
- **Backlink or directory schemes.** The site earns links by being the readable
  copy of the canon, or it doesn't earn them.

## Order to do them in

1. `404.html` — a correctness bug, not an optimisation.
2. `robots.txt` + `sitemap.xml` — discovery for 16K pages.
3. `<meta name="description">` — the click-through lever.
4. Absolute canonical — cheap now that the domain is settled.
5. OG tags — distribution, and this audience shares in messaging apps.
6. `BreadcrumbList` JSON-LD.
7. `lang="pi-Sinh"` — mostly an accessibility fix.
8. Font preload, heading duplication — measure first, both are small.
