# Testing the app ↔ site seam

> **This document owns how the seam is *verified*.** The rule it verifies lives in
> `reading-units-and-grouping.md`; every corpus count lives in
> `static_site_generator/CORPUS_FIGURES.md` and is cited here by name.
>
> **Scope: the app.** Static-site testing is handled separately — only the two
> points that are genuinely about the *seam* are recorded at the end.
>
> **Status:** Stage A is implemented and green. Nothing in the Gaps section
> below is written yet — per project convention, tests are not generated unless
> asked, so this is the list to hand a test writer.

---

## Baseline, measured 2026-08-23

Everything was run after Stage A landed, on `feat/static-site`:

| suite | command | result |
|---|---|---|
| app unit + widget | `flutter test` | **564 pass** |
| shared package | `dart test` in `packages/wisdom_shared` | **226 pass** |
| generator | `dart test` in `static_site_generator` | **17 pass** |
| corpus integrity | `dart run tool/plan_corpus.dart --check` | integrity ok, no violations, both derivations close |
| build determinism | `--root an-1` diffed against a pre-Stage-A build | **byte-for-byte identical** |

Integration tests (`integration_test/`, macOS) were **not** run — see "How to run"
below and the flakiness note.

---

## What Stage A changed

Three seams, in the order a reader meets them.

1. **`SitePlan` moved into `wisdom_shared`** (`src/pages/site_plan.dart`), so the
   app can ask which page serves a node. Gained `pageOf` (which page) and
   `servingLink` (which URL), both reading the one map that already answered
   `urlFor` for the site. The two frozen sets now default to the snapshot, so a
   caller cannot plan a site that differs from the one that ships.
2. **The app decodes the tree through `TipitakaTree.fromJson`**
   (`tree_local_datasource.dart`), deleting its own copy of the row parsing and
   the sibling comparator — and inheriting `correctedTreeCoordinates`, which the
   site has had since 2026-08-19 and the app never did.
3. **Links carry the page that serves them.** `TipitakaLink` gained `pageKey`,
   parses a nodeKey-shaped `#fragment` as the target, and tolerates a `.html`
   suffix. Copy-link builds through `SitePlan.servingLink`; the deep-link opener
   asks `plan.pageOf` whether the path's page really serves the fragment, and
   falls back to the page key when it does not. Both directions read the one
   map, and neither throws — the plan being unavailable degrades to the answer
   the app gave before it existed.

---

## What already covers it

Audited file by file. Two of these are stronger than expected and one is weaker.

| what | where | verdict |
|---|---|---|
| Sibling order is identical to the pre-extraction app code, over every parent in the corpus | `static_site_generator/tool/verify_corpus_invariants.dart`, run by `test/corpus_tools_test.dart` | **Strong — this is the guard that de-risks change 2.** Both oracles are frozen copies from commit `4bb320c`; if one has to change to pass, the extraction changed behaviour and that is the finding. Independently reproduced 2026-08-23: 0 parents differ. |
| The frozen snapshot still describes this tree, and the rule still runs | `static_site_generator/test/corpus_tools_test.dart` | **Strong.** Catches a snapshot that no longer matches the corpus — which is exactly what "the app follows the site" depends on. Runs `SitePlan.build`'s guards only in the direction that passes (Gap 3). |
| Sibling ordering, malformed input, ancestors, leaves, determinism | `packages/wisdom_shared/test/tree/tipitaka_tree_test.dart` | Good for the decoder's *shape*, but see Gap 2: it never passes `corrections`. |
| URL grammar, both schemes, round trips, rejection cases, and now the fragment form | `packages/wisdom_shared/test/links/tipitaka_link_test.dart` | **Updated in Stage A.** The old group was named "fragments are ignored — for now" and pinned the deferred behaviour deliberately; that flip is now made, with the `.html` and page-anchor cases added. |
| One address per node, asked of `urlFor` and `servingLink` alike, over every key a plan can answer for | `packages/wisdom_shared/test/pages/site_plan_test.dart` | **New.** The seam's own rule, held by prose until now — it had already come apart once, `urlFor` learning the `<key>#<key>` form while `servingLink` ten lines below kept returning the bare URL. Runs on a synthetic eleven-node tree carrying all four page shapes, with the shapes themselves pinned so the loops cannot go vacuous. |
| The search index's positional row against the offsets and the `hrefFor` that `assets/site.js` reads it by | `static_site_generator/test/wiring_contract_test.dart` | **New.** The third surface, and the one no other signal reaches: the links are assembled in a browser, so a wrong `chapterIdx` passes `dart analyze`, the build-twice hash and a link checker alike. Offsets and the `hrefFor` body are both read out of the script rather than copied. |
| Tree load, caching, node lookup, failure mapping | `test/data/repositories/navigation_tree_repository_impl_test.dart` | Covers `loadNavigationTree`, not `loadSitePlan` (Gap 4). |
| Tab open from search result, switching, closing, scroll bookkeeping | `test/presentation/providers/tab_provider_test.dart` | Untouched by Stage A and still passing. |
| Reader, breadcrumb, prev-sutta, scroll restoration against the **real** tree and real content | `integration_test/*` | Valuable, and the only place the real asset is exercised end to end — but none of them names a corrected leaf (Gap 1). |

**The honest summary:** the *site* half of the seam is well guarded, mostly by
the generator's corpus tools. The *app* half — the part Stage A added — was
guarded by nothing until `site_plan_test.dart`, which now holds `servingLink`
to the same answer `urlFor` writes. That is both sides of one shared function,
not both surfaces: what no test yet does is open a real sutta in the app and
compare it against the HTML the site serves at that URL — Gap 8, and still the
one worth most.

---

## Gaps, in the order worth closing them

### Gap 1 — nothing asserts a corrected coordinate, on either surface

`grep` over `test/` and `integration_test/` finds no reference to any key in
`correctedTreeCoordinates` (`vp-pct-1-3-*`, `ap-vbh-*`, `kn-pv-*`, `kn-vv-*`).
The app now inherits the correction and could silently lose it — a stale mock, a
future caller decoding with `corrections: const {}`, a re-sync — and every test
would stay green while the sekhiya pages went back to opening one rule early.

**Pin:** one app-level test that decodes the real asset and asserts a named
corrected leaf's `entryPageIndex`/`entryIndexInPage` equal the corrected value,
not the raw one. Choose a leaf whose correction crosses a printed page (there
are `FIGURES.correctedCoordinates` leaves in total, and the ones that change page
are the ones a wrong decode is most visible on). One assertion, and it fails the
moment the app stops reading the shared decoder.

**Also pin in the shared package:** `TipitakaTree.fromJson` applies
`corrections` by default and `corrections: const {}` does not — the switch the
alignment tool depends on. Currently untested (see Gap 2).

### Gap 2 — the shared decoder's correction path has no unit test

`tipitaka_tree_test.dart` covers ordering, malformed rows and navigation, and
never passes the `corrections` parameter. Two small tests over a hand-made tree:
a corrected key takes the map's coordinate, an uncorrected sibling keeps its own.

### Gap 3 — `SitePlan.build`'s seven guards are never seen to throw

`SitePlan.build` refuses seven shapes. Three are about the snapshot — a folded
first child with unfolded siblings (a page half text and half navigation), a
container that folds wholesale but holds containers (their subtrees swallowed
unrendered), a folded leaf no run picked up (a leaf on no page at all, with
`urlFor` still handing out a URL for it). Four are about the roots — none,
unknown, listed twice, or nested; the last two walk a subtree twice, which
writes every page twice and threads prev/next through the second copy.

**None of the seven has a test on the throwing path.** `corpus_tools_test.dart`
runs `SitePlan.build` against the real corpus, which by definition satisfies all
of them, so they are exercised only in the direction that cannot fail. Invert a
condition or drop one in a refactor and every suite stays green while the
hand-edit they exist to catch sails through — and these are the guards standing
between a hand-edited snapshot and a site that is quietly wrong, so a silent one
is worse than none.

**Pin:** seven cases in
`packages/wisdom_shared/test/pages/site_plan_test.dart`, which already carries a
synthetic tree with every page shape on it. Each is one `SitePlan.build` with an
altered folded set or root list and a `throwsStateError`. Assert the message
names the offending key: that key is the whole value of the guard on the day it
fires. Write the three snapshot guards first — the root guards already fail
loudly at the command line the moment anyone types the wrong `--root`, while a
bad snapshot fails on a page nobody is looking at.

Needs no corpus, so it belongs in the shared package's suite rather than the
generator's.

### Gap 4 — `loadSitePlan` / `sitePlanProvider` are untested

The new repository method and provider are the app's whole answer to "which page
serves this node". Worth pinning:

- a folded leaf resolves to a page whose `nodeKey` is **not** its parent (pick
  one of the mid-vagga chapters — the case `node.parentNodeKey` gets wrong);
- a leaf that owns its page resolves to itself;
- the plan is built once and cached (the repository caches it beside the tree);
- a failed tree load surfaces as `Left(Failure)`, not an exception.

### Gap 5 — copy-link can regress to a 404 without failing a test

`tipitakaLinkUrlBuilderProvider` is now async and rewrites folded keys. If it
ever loses the `servingLink` call, the app silently goes back to copying URLs
the site has no file for — invisible in-app, broken for whoever receives it.

**Pin:** for a folded key the URL is `<base>/tipitaka/<pageKey>#<leafKey>`; for
an unfolded key it is `<base>/tipitaka/<key>` with no fragment; the base comes
from `LINK_BASE_URL`.

Verified by hand 2026-08-23 over a sample of folded leaves spread across the
corpus: every URL named a file that exists in the built site, every file carried
the matching `id="<leafKey>"` anchor, every URL round-tripped back through
`TipitakaLink.parse`, and no own-page key was rewritten. That check is a script,
not a test — Gap 5 is about keeping it true.

### Gap 6 — the deep-link fallback branch

`openTipitakaLinkProvider` now prefers the fragment and falls back to the page
key when `SitePlan` says that page does not serve it. Four cases, one test each:
a folded leaf's fragment opens the leaf; a decorative anchor (`#top`) opens the
page; a fragment naming a node served by a *different* page opens the path's
page, matching what the site renders; a link naming nothing at all returns false
rather than opening an empty tab.

Worth one more: with the plan unavailable, the tree fallback still opens
something rather than throwing. That branch is the reason a snapshot problem
cannot turn a tapped citation into a crash.

### Gap 7 — mocks drift silently when a datasource grows a method

`TreeLocalDataSource` gained `loadSharedTree`, so `test/helpers/mocks.mocks.dart`
had to be regenerated (`dart run build_runner build --delete-conflicting-outputs`
— done). Worth a line in the test README rather than a test: a stubbed mock that
misses a new method fails at the call, not at compile time, so it surfaces as an
unrelated test failing far from the change.

### Gap 8 — no test compares the two surfaces on the same sutta

This is the one that would have caught the original defect, and the only gap
whose value is *cross-surface*: take a handful of keys — a corrected sekhiya
rule, a folded leaf, a mid-vagga chapter anchor, a promoted-book leaf — and
assert the app opens the same text the generated HTML carries at the same URL.

It needs a built site on disk, so it belongs beside the integration tests rather
than in `flutter test`, and it is the natural home for the "cross-check ~20
suttas" step Part 4 of the grouping plan already asks for by hand.

---

## How to run

```bash
flutter test                                    # app unit + widget
cd packages/wisdom_shared && dart test           # codec, decoder, markers
cd static_site_generator && dart test            # corpus tools (~47s, reads the whole corpus)
cd static_site_generator && dart run tool/plan_corpus.dart --check   # ~1s integrity
flutter test integration_test/<one_file>.dart -d macos               # one at a time
```

**Run integration files individually, not `all_tests.dart`.** The suite flakes
under shared-DB contention — `pumpAndSettle` hangs on a spinner — and the same
files pass alone. A failure there is not evidence of a regression until the file
has been re-run on its own.

---

## Static site — the two points that belong here

Everything else about site testing is out of scope by instruction. These two are
about the seam itself, so they are recorded rather than filed elsewhere:

1. **The byte-identity check is the cheapest regression test the seam has.**
   Building one subtree (`--root an-1`, ~300 ms) and diffing it against a build
   from before a change proves a refactor moved no output. It is what proved the
   `SitePlan` move and the `_owningPage` collapse were behaviour-neutral. Worth
   keeping as the standard first step for any change to shared page logic, now
   that the app depends on the same code.

2. **`--check` should stay in the app's release checklist, not just the
   generator's.** It reads the tree only (~1 s) and refuses a snapshot that
   cannot describe a real site. Now that the app builds its `SitePlan` from that
   same snapshot, a bad regeneration would break *both* surfaces — so the check
   that catches it is no longer a site-only concern.

---

## Stage B will need more than this

Not yet, but so the list exists when the reader rework starts: bounded-unit
rendering (a sutta page ends at its boundary), a chapter opening scrolled to a
folded leaf, prev/next matching `SitePlan`'s chain exactly across a vagga
boundary, `?e=` becoming scroll-position-only, and the `openTabs` → `_v2`
migration reading no saved tab under the old meaning. Each of those changes what
a reader sees, so each needs a test in a way Stage A — which changed almost
nothing visible — did not.
