# Pali Letter Settings — Test Plan

Status: Proposed 2026-06-18 · scope = unit-first, minimal combinations.
Covers the implementation in `docs/pali-letter-settings-bandi-special-toggles.md`.

## Principle

Pin the **behaviour** at the cheapest layer that can prove it. The transformer is
pure `String → String`, so combinations live in a pure unit test — *not* the UI,
*not* the (flaky) integration suite. We test **4 representative toggle states**, not
all 8: each chosen state proves a distinct mechanism; the rest are redundant.

Expected outputs are built from **explicit unicode escapes** (`‍` ZWJ,
`්`/`්` hal), never from `beautifyPaliText(...)` itself — otherwise the
assertion is circular.

Building blocks:
- **Ligated** `X්Y` → `X් <ZWJ> Y` = `"X්‍Y"` (hal then ZWJ)
- **Touching** `X්Y` → `X <ZWJ> ්Y` = `"X‍්Y"` (ZWJ then hal)

---

## File 1 — `test/core/utils/pali_conjunct_transformer_test.dart` (priority)

Pure Dart, no Flutter. Grid example sentence: `ධර්ම බුද්ධ ධම්ම චන්ද`
(`ර්ම` repaya · `ද්ධ` special · `ම්ම` general-only · `න්ද` common).

### 1. Behaviour grid — 4 states (one rich sentence each)

| State | options | expected output |
|---|---|---|
| **Default** (S3 on, S2 off, S1 on) | `PaliLetterOptions.defaults` | `ධර්‍ම බුද‍්ධ ධම‍්ම චන්‍ද` |
| **All on** | `(true, true, true)` | `ධර්‍ම බුද්‍ධ ධම‍්ම චන්‍ද` |
| **Touching only** (S3 off, S2 off, S1 on) | `(false, false, true)` | `ධර‍්ම බුද‍්ධ ධම‍්ම චන‍්ද` |
| **All off** | `PaliLetterOptions.baseline` | `ධර්ම බුද්ධ ධම්ම චන්ද` (unchanged) |

What each row locks:
- **Default** → repaya ligates; common pair (`න්ද`) ligates and is *shielded* from
  touching (proves ordering); special (`ද්ධ`) stays un-ligated because S2 is off; the
  general-only (`ම්ම`) and the off-special cluster get touched. One row, four mechanisms.
- **All on** → the *only* delta vs default is `බුද්ධ` → `බුද්‍ධ`: proves the special
  tier turns on and the after-hal ZWJ shields it from the touching pass.
- **Touching only** → everything touched, nothing ligated: proves S1 standalone and that
  S3-off truly drops the ligated forms.
- **All off** → gates really gate (bare baseline, only zero-width stripped).

### 2. Vowel shortening (S1 side-effect) — 1 test
With S1 on: `තේ` → `තෙ` and `සෝ` → `සො`. With S1 off: unchanged.

### 3. Idempotency — 1 test
`beautify(beautify(sentence, defaults), defaults) == beautify(sentence, defaults)`.

### 4. Deliberate exclusions — 1 test
Options `(S3 off, S2 **on**, S1 off)` so only the special tier runs:
- `ම්බ` stays `ම්බ` (NOT `ම්‍බ`).
- `ඞ්ග` stays `ඞ්ග` (NOT substituted to `ඟ`).
Guards against a future "helpful" re-add.

### 5. Position map round-trip — 1 test (highest-risk math)
`applyConjunctsWithRangeMapping('චන්ද', [(start: 1, end: 4)], defaults)`
→ `('චන්‍ද', [(start: 1, end: 5)])`. Assert the display text **and** that the
remapped range slices `'න්‍ද'`.

### 6. `removeConjunctFormatting` — 1 test
`'චන්‍ද'` → `'චන්ද'` (ZWJ stripped); a shortened vowel `'තෙ'` is left as-is
(it does NOT restore the long vowel).

**File 1 ≈ 9 tests.** Closes ~80% of the gap.

---

## File 2 — `test/presentation/providers/pali_letter_options_provider_test.dart`

Mirror `content_language_provider_test.dart` (same `ProviderContainer` +
`InMemoryKeyValueStore` + throwing-store pattern).

1. **Defaults**: empty store → `paliLetterOptionsProvider == PaliLetterOptions.defaults`
   (S3 on / S2 off / S1 on).
2. **Relaunch round-trip**: `specialConjunctsProvider.notifier.set(true)`, assert it
   wrote `StorageKeys.paliSpecialConjuncts`, dispose, new container over the same store
   → restored `true` (and reflected in the combined provider).
3. **Best-effort write**: a store whose `setBool` throws → `set(...)` completes without
   throwing and state still flips.
4. **Value equality** (fold in): equal flags → `==` and same `hashCode`;
   `defaults != baseline`. (This is what de-dupes no-op rebuilds across all surfaces.)

**File 2 ≈ 4 tests.**

---

## File 3 — `text_entry_widget` cache-invalidation widget test

NOT a full `integration_test/` file (that suite is flaky under shared-DB contention),
and NOT a generic `Consumer` (that would just test Riverpod + the seam already covered
by File 1). This targets the **one** path no unit test can reach: `text_entry_widget`'s
**hand-rolled display-text cache**, which serves a cached string unless its manual
`_options`/`_lastOptions` key changes (`text_entry_widget.dart:117-128`) and is only
busted when `build`'s `ref.watch` detects `options != _options` (`:241-243`). A bug here
shows **stale Pali text** in the reader after a toggle.

- Pump a `TextEntryWidget(text: 'බුද්ධ', enableTap: true, ...)` inside the standard
  widget-test harness (`ProviderScope` + `InMemoryKeyValueStore` override + `MaterialApp`
  / `AppLocalizations`) — mirror `tab_bar_widget_test.dart`.
- Assert it first renders the **default** form `බුද‍්ධ` (S2 off → touching).
- `container.read(specialConjunctsProvider.notifier).set(true)`, then `await tester.pump()`.
- Assert the rendered text is now the **special-ligated** `බුද්‍ධ` — proving the cache
  busted and recomputed (not served stale).

`enableTap: true` matters — the cache only engages on that branch (`:128`).

---

## Out of scope (deliberately)

- All 8 toggle permutations — the 4 above cover every distinct mechanism.
- `getBool`/`setBool` store wrapper — no storage unit tests exist in the repo today;
  staying consistent.
- Settings menu layout/visuals — that's the `ui-auditor`'s job, not unit tests.

## Execution

Tests authored by the **`qa-test-writer`** agent (per CLAUDE.md). Run on `-d macos`;
test-related work runs automatically per repo convention.
