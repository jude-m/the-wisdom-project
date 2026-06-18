# Pali Letter Settings — Three Conjunct Switches

**Status:** Implemented 2026-06-18 (steps A–H). `flutter analyze` clean; affected
unit/widget tests pass; transformer output verified against the §4 grid. Remaining:
the in-app manual checks in [§12](#12-verification-checklist) (live toggle, persistence).
**Date:** 2026-06-17
**Local reference:** `tipitaka.lk` (Vue) → `src/text-convert.mjs`, `src/store/tree.js`, `src/views/FTS.vue`
**Official sources:** see [§11](#11-sources).

---

## 1. Goal

Today our Pali-in-Sinhala-script rendering applies **every** conjunct transformation in one
always-on monolithic pass (`applyConjunctConsonants`). We are splitting it into **three
user-controlled switches**, applied everywhere source text is shown — the **reading pane** *and*
every **content-language label** (tree, breadcrumbs, tabs, search, dialogs).

This supersedes the earlier 2-switch plan. The move to **three** switches (and the exact character
lists) was settled through research against official Unicode/SLS sources and the two reference apps;
the reasoning lived in `pali-switches-proposal-DRAFT.md`, now folded into this document.

The three switches (Sinhala labels follow tipitaka.lk's wording where one exists):

| # | Switch | Sinhala label | Default | What it does |
|---|---|---|:---:|---|
| 1 | **Touching** | පාළි බැඳි අකුරු භාවිතා කරන්න | **ON** | Touching mechanism for *every* remaining cluster + long→short vowel |
| 2 | **Special / rare old-Pali** | විශේෂ පාළි අකුරු භාවිතා කරන්න | **OFF** | The 7 ornate Pali-only ligatures (UN-font glyphs) |
| 3 | **Standard ligatures** | සුලබ බැඳි අකුරු *(provisional — see §9.G)* | **ON** | rakaransaya + yansaya + repaya + the 8 common ligated pairs |

All three are **Pali-only** — Sinhala content is never transformed (matches tipitaka.lk's display
behaviour, see [§6](#6-scope-pali-only)).

---

## 2. The one idea: two *different* mechanisms, not one effect at two strengths

A consonant cluster (two consonants, no vowel between) can render **unjoined** (first consonant keeps
its visible *hal* `්`) or **joined**. There are **two structurally different ways** to join, decided
by where the Zero-Width Joiner (ZWJ, U+200D) sits relative to the hal/virama (`්`, U+0DCA). This is
the key to keeping the three switches clean — they are not the same effect dialled up; they are
different typographic systems.

- **Ligated conjunct** = hal **then** ZWJ → `් ‍`. Produces a *fused glyph*; a FIXED inventory the
  font must contain. → Switches **2 and 3**.
- **Touching conjunct** = ZWJ **then** hal → `‍ ්`. Hides the hal and pushes letters together; a
  GENERAL, "productive" rule that works on *any* cluster — no list. → Switch **1**.

> *The Unicode Standard 16.0, Ch. 13 (Sinhala)* describes both styles and calls the touching style
> "productive [and it] should not be implemented on a case-by-case basis" — i.e. a general rule, which
> is exactly why Switch 1 has no list.

---

## 3. The tiers and their exact character lists

### Switch 3 — Standard ligatures (default ON, ligated `් ‍`)

The three **reduced consonant forms** (one orthographic class in SLS 1134 / helpcentre.lk) plus the
everyday "common" pairs:

- **Yansaya** — `් ය` → `් ‍ ය`
- **Rakaransaya** — `් ර` → `් ‍ ර`
- **Repaya** — `ර ්` (ර is the *first* consonant of the cluster) → `ර ් ‍`
- **Common conjuncts (8)** — `X ් Y` → `X ් ‍ Y` for:
  `ක්ව, ක්ෂ, ත්ථ, ත්ව, න්ව, න්ථ, න්ද, න්ධ`

### Switch 2 — Special / rare old-Pali conjuncts (default OFF, ligated `් ‍`)

A fixed list of **7** ornate ligatures found in old Pali books; need UN-type fonts to render.
`X ් Y` → `X ් ‍ Y` for:
`ඤ්ච, ඤ්ජ, ඤ්ඡ, ට්ඨ, ණ්ඩ, ද්ධ, ද්ව`

This is **exactly** tipitaka.lk's `paliConjuncts`.

### Switch 1 — Touching (default ON, touching `‍ ්`)

No list. The productive rule `X ් Y` → `X ‍ ් Y` for every cluster not already ligated by 2/3, plus
the long→short vowel step (`ේ`→`ෙ`, `ෝ`→`ො`).

### Two characters deliberately EXCLUDED (must be recorded in code comments)

1. **ම්බ** — *not* in Switch 2. Mechanically a valid joiner-form, but tipitaka.lk excludes it,
   pitaka.lk itself labels it "rare (දුලබ)", and "mb" already has a dedicated prenasalized letter
   ඹ. When Switch 1 is on it still binds via touching — just not as a "special" member.
2. **ඞ්ග → ඟ** — *out of scope entirely*. This is a single-codepoint **prenasalized** substitution
   (`ඞ ් ග` → `ඟ` U+0D9F), not a joiner. Unicode 16 contrasts `අඬ` vs `අණ්ඩ` as *different words*,
   so it can change meaning. It belongs to the sanyaka/prenasalized series (ඟ ඳ ඬ ඹ), a separate
   feature we are not touching.

> **Implementation requirement:** the transformer file MUST carry a comment next to the special list
> recording *both* exclusions and why, so a future maintainer doesn't "helpfully" re-add them.

---

## 4. Ordering invariant (correctness)

The ligated tiers (Switch 3, then Switch 2) run **before** the touching tier (Switch 1). Each ligated
unit inserts a ZWJ *after* the hal; that ZWJ then **shields** the pair from the touching regex (which
only matches `cons + hal + cons` with *nothing* between hal and the next consonant). Consequences,
all intended:

- A pair ligated by Switch 3/2 is never re-touched by Switch 1.
- With **Switch 3 OFF but Switch 1 ON**, rakar/yansa/common are *not* shielded → they fall through to
  touching (so you get touching forms, not the proper reduced-form glyphs). This is the accepted
  "strip the standard ligatures" behaviour.
- With **both OFF**, the cluster stays at bare baseline (visible hal).

This mirrors tipitaka.lk's ordering (it always runs rakar/yansa + common before touching).

### Behaviour grid — example `ධර්ම බුද්ධ ධම්ම චන්ද`

(`ර්ම` repaya · `ද්ධ` special · `ම්ම` general-only · `න්ද` common)

| S3 std | S2 special | S1 touching | ර්ම | බුද්ධ | ම්ම | චන්ද |
|:---:|:---:|:---:|---|---|---|---|
| ON | OFF | ON | repaya | touching | touching | common-ligated |
| ON | ON | ON | repaya | **special ligature** | touching | common-ligated |
| ON | OFF | OFF | repaya | baseline | baseline | common-ligated |
| OFF | OFF | ON | touching | touching | touching | touching |
| OFF | OFF | OFF | baseline | baseline | baseline | baseline |

Row 1 is the **default** launch state (S3 ON, S2 OFF, S1 ON).

---

## 5. Design principle: one job per function (extensibility)

Per the directive that Switch 3 is "a bunch of many operations… design it as individual units of work
so we can remove any of it or control differently in the future" — the transformer is a set of
**small, pure, single-purpose** functions (`String → String`), and a thin orchestrator that composes
them per the options. This is *finer* than tipitaka.lk (which bundles rakar+yansa in one regex and
hides vowel-shortening inside `addBandiLetters`); the finer split is deliberate, so any unit can later
be pulled out or moved behind its own gate without surgery.

```dart
// --- units (each pure, one job) ---
String _stripZeroWidth(String t);    // reset ZWJ/ZWNJ → idempotent re-application

// Switch 3 (ligated  ් ‍)
String addYansaya(String t);         // ් ය  → ් ‍ ය
String addRakaransaya(String t);     // ් ර  → ් ‍ ර
String addRepaya(String t);          // ර ්  → ර ් ‍   (ර first in cluster)
String addCommonConjuncts(String t); // iterate _commonPairs (8): X්Y → X්‍Y

// Switch 2 (ligated  ් ‍)
String addSpecialConjuncts(String t);// iterate _specialPairs (7): X්Y → X්‍Y

// Switch 1 (touching  ‍ ්)
String addTouchingConjuncts(String t);// X්Y → X‍්Y, full consonant range, run twice
String shortenVowels(String t);       // ේ→ෙ, ෝ→ො

// --- orchestrator (composition only) ---
String beautifyPaliText(String text, PaliLetterOptions o) {
  var t = _stripZeroWidth(text);
  if (o.standardLigatures) {           // Switch 3
    t = addYansaya(t);
    t = addRakaransaya(t);
    t = addRepaya(t);
    t = addCommonConjuncts(t);
  }
  if (o.specialConjuncts) {            // Switch 2
    t = addSpecialConjuncts(t);
  }
  if (o.generalBandi) {                // Switch 1
    t = addTouchingConjuncts(t);
    t = shortenVowels(t);
  }
  return t;
}
```

Run order between `addRepaya` and yansaya/rakaransaya matters only at the `ර්ය`/`ර්ර` edge: running
the after-hal reduced forms first means repaya's `ර ් (cons)` regex can't re-match an already-joined
pair — no conflict.

---

## 6. Scope: Pali-only

Verified across every tipitaka.lk call site (grep):

- **Display** (`tree.js:16-17`, `TextEntry.vue:132/145`, `TextTab.vue:153/160`) all short-circuit
  Sinhala (`if (lang == 'sinh') return text`) → Sinhala gets nothing.
- **Search** (`FTS.vue:138/216` → `beautifyFTSText`) applies `addRakarYansa` to Sinhala *only* as an
  index-matching workaround ("fts lacks 200d"), not visual styling.

Why: Pali source is stored **bare** (no joiners) so we must add them; native Sinhala source is
**already encoded** correctly, and forcing the transform risks mis-binding real words (their code
comment: *"issue pointed out by Vincent — උස්යහනින්"*, where `ස්ය` would wrongly ligate).

→ **All three switches are Pali-only for display.** Our existing seam already does this:
`formatContentLabel` only transforms `ContentLanguage.pali`. **Separate future item (out of scope):**
if our Sinhala *search* shows the same index mismatch, add a search-layer rakar/yansa normalisation
then — independent of these switches.

### Spot-check of OUR data (2026-06-17) — confirms Pali-only

Counting ZWJ (U+200D) vs hal (U+0DCA) directly in our assets:

- **Page content** (`assets/text/*.json`, 40 files): Pali = 377,043 hals but **4 ZWJ total** (3 of
  38,106 entries) → effectively **bare**. Sinhala = 440,623 hals with **123,923 ZWJ** across 24,201
  entries → **already encoded** (ZWJ-per-hal ≈ 0.28).
- **Tree labels** (`assets/data/tree.json`): Pali = **1 ZWJ** / 16,355 names; Sinhala = **9,824 ZWJ**.

So Pali is stored bare (the transform's job is to *add* joiners) and Sinhala arrives with its
rakar/yansa/repaya joiners already authored in (e.g. `වර්‍ගය`). Re-running our strip-then-re-add
transform on Sinhala would damage that hand-authored encoding — so Pali-only isn't just "matching
tipitaka.lk", it's **required to preserve the Sinhala source**. Decision is now firmly grounded.

---

## 7. Current state (the "mixed bag") and the reference

`lib/core/utils/pali_conjunct_transformer.dart` → `applyConjunctConsonants(text)`:
- One always-on pass, no toggles, no `lang` awareness.
- Has rakar/yansa + the 7 special pairs + a general (touching) step + vowel shortening.
- **Missing the *common* tier** → the common pairs get swept into the touching step and joined with
  `ZWJ + hal` (before), where they should be `hal + ZWJ` (after). That is the literal "mix": special
  and touching fused, no standard-ligature baseline, and **no repaya at all**.

**The one piece already right:** `lib/presentation/utils/content_text_formatter.dart` →
`formatContentLabel(raw, language)` is the central seam applying conjuncts to **Pali only**. Most
surfaces already route through it.

### Reference model — tipitaka.lk `src/text-convert.mjs`

```js
export function beautifyText(text, lang, {bandiLetters, specialLetters}) {
  if (lang == 'sinh') return text          // Sinhala: never transform
  text = addRakarYansa(text)               // ALWAYS — no toggle (yansa + rakaransaya; NO repaya)
  text = addCommonConjuncts(text)          // ALWAYS — no toggle (6 pairs, hal+ZWJ)
  if (lang == 'pali') {
    if (specialLetters) text = addPaliConjuncts(text)  // 7 pairs, hal+ZWJ
    if (bandiLetters)   text = addBandiLetters(text)   // touching ZWJ+hal + vowel shorten
  }
  return text
}
```

---

## 8. Decisions, resonated against tipitaka.lk

| Decision | vs tipitaka.lk | Why |
|---|---|---|
| **Switch 1 = touching, default ON** | **MATCH** (`bandiLetters: true`) | Same mechanism, same default. |
| **Switch 2 = 7 special pairs, default OFF** | **MATCH exactly** (`paliConjuncts`, `specialLetters: false`) | Exact parity; UN-font ligatures of old Pali texts. |
| **Switch 3 = standard ligatures as a real toggle** | **DIVERGE** — they hard-code this always-on with no control | More user control; default ON keeps default *behaviour* identical to theirs. |
| **Repaya included** | **DIVERGE** — their `addRakarYansa` regex (`්[යර]`) does *not* do repaya | Repaya is the 3rd reduced form (SLS 1134); genuine correctness gain. |
| **Common list = 8** (`+ ක්ෂ, න්ව`) | **DIVERGE** — they ship 6 | pitaka.lk's fuller list; `ක්ෂ` especially is standard modern Sinhala. |
| **ම්බ dropped from special** | **MATCH** — they exclude it | Rare; tangled with prenasalized ඹ. |
| **ඞ්ග→ඟ excluded** | **MATCH** — not in their lists | Prenasalized single-codepoint; meaning-changing; separate feature. |
| **Pali-only display** | **MATCH** their display | Sinhala source already encoded; forcing risks mis-binds. |
| **Fine-grained units** | **DIVERGE** — they group rakar+yansa, bury vowel in the touching step | Extensibility directive: remove/re-gate any unit later. |

---

## 9. Implementation steps

### A. Value object — `lib/core/utils/pali_letter_options.dart` *(new)*
Immutable holder for the three flags so we thread one object, not three bools, through every seam.
```dart
class PaliLetterOptions {
  const PaliLetterOptions({
    required this.standardLigatures, // Switch 3
    required this.specialConjuncts,  // Switch 2
    required this.generalBandi,      // Switch 1
  });
  final bool standardLigatures;
  final bool specialConjuncts;
  final bool generalBandi;

  /// App default = default behaviour parity with tipitaka.lk (grid row 1).
  static const defaults = PaliLetterOptions(
      standardLigatures: true, specialConjuncts: false, generalBandi: true);
  /// Everything off — bare baseline.
  static const baseline = PaliLetterOptions(
      standardLigatures: false, specialConjuncts: false, generalBandi: false);

  // value `==`/`hashCode` so Provider de-dupes rebuilds on unchanged value.
  // (A Dart record `({bool ...})` would give equality for free; class chosen
  //  for the named `defaults`/`baseline` members + discoverability.)
}
```

### B. Refactor the transformer — `pali_conjunct_transformer.dart`
- Add `const _commonConjunctPairs` (8) and keep `_specialConjunctPairs` (7, unchanged).
- Split the monolith into the single-purpose units from [§5](#5-design-principle-one-job-per-function-extensibility):
  `_stripZeroWidth`, `addYansaya`, `addRakaransaya`, `addRepaya`, `addCommonConjuncts`,
  `addSpecialConjuncts`, `addTouchingConjuncts`, `shortenVowels`.
- Add the **new repaya unit**: regex `ර ්` followed by a consonant → insert ZWJ after the hal.
- Touching regex → **full consonant range** `([ක-ෆ])්([ක-ෆ])` (run twice for consecutive hals),
  relying on the ligated tiers to shield ර/ය when Switch 3 is on (drops our current ය/ර exclusion;
  this is the tipitaka.lk approach).
- Orchestrator `beautifyPaliText(text, PaliLetterOptions)` composes the units (keep the leading
  `_stripZeroWidth` reset so re-application is idempotent regardless of source JSON contents).
- **Comment** beside the special list recording the two exclusions (ම්බ, ඞ්ග→ඟ) — see [§3](#3-the-tiers-and-their-exact-character-lists).
- Update dependents:
  - `PaliConjunctExtension.withPaliConjuncts` (getter) → `withPaliLetters(PaliLetterOptions)` (method).
  - `applyConjunctsWithRangeMapping(rawText, ranges, options)` — add the options param, forward it.
  - `buildConjunctPositionMap` / `removeConjunctFormatting` — **unchanged** (they only diff/strip
    zero-width chars, agnostic to which units ran).
  - Optional: keep an `applyConjunctConsonants` alias or rename call sites — all 8 seams change
    anyway (they must pass options), so renaming to `beautifyPaliText` is low marginal cost and
    resonates with tipitaka.lk's `beautifyText`.

### C. Storage — add a `bool` helper + 3 keys
- `key_value_store.dart`: add `bool? getBool(String)` + `Future<void> setBool(String, bool)` (the
  interface already invites typed helpers).
- Implement in `shared_preferences_key_value_store.dart` (native `getBool`/`setBool`) **and**
  `test/helpers/fake_key_value_store.dart`.
- `storage_keys.dart` (suffix `_v1` per convention):
  `paliStandardLigatures = 'pali_standard_ligatures_v1'`,
  `paliSpecialConjuncts  = 'pali_special_conjuncts_v1'`,
  `paliGeneralBandi      = 'pali_general_bandi_v1'`.

### D. Providers — `lib/presentation/providers/pali_letter_options_provider.dart` *(new)*
- A reusable `BoolSettingNotifier extends StateNotifier<bool>` (store + key + fallback; best-effort
  persist, swallow+log — same shape as `ContentLanguageNotifier`); add a `toggle()` helper.
- Three providers: `standardLigaturesProvider` (fallback `true`), `specialConjunctsProvider`
  (fallback `false`), `generalBandiProvider` (fallback `true`).
- `paliLetterOptionsProvider = Provider<PaliLetterOptions>((ref) => PaliLetterOptions(
    standardLigatures: ref.watch(standardLigaturesProvider),
    specialConjuncts:  ref.watch(specialConjunctsProvider),
    generalBandi:      ref.watch(generalBandiProvider)))`.

### E. Formatter seam — `content_text_formatter.dart`
`String formatContentLabel(String raw, ContentLanguage language, PaliLetterOptions options)` →
Pali branch calls `beautifyPaliText(raw, options)`; Sinhala branch returns `raw` unchanged.

### F. Thread `paliLetterOptionsProvider` through all 8 surfaces
Each surface `ref.watch`es the provider and passes the options down. Because every surface watches it,
flipping a switch rebuilds them all live — our equivalent of tipitaka.lk's `recomputeTree`.

| # | File | How it gets options |
|---|---|---|
| 1 | `providers/breadcrumb_provider.dart:35` | `ref.watch` |
| 2 | `utils/search_result_labels.dart:65,78` | already takes `ref` → `ref.watch` internally (no caller change) |
| 3 | `widgets/navigation/tree_navigator_widget.dart:154` | `ref.watch` |
| 4 | `widgets/navigation/tab_bar_widget.dart:458` | `ref.watch` |
| 5 | `widgets/search/refine_search_dialog.dart:423` | `ref.watch` |
| 6 | `widgets/reader/text_entry_widget.dart:117` | already `ConsumerStatefulWidget` → `ref.watch` |
| 7 | `widgets/search/highlighted_fts_search_text.dart:78` | `ref.watch` → pass to `applyConjunctsWithRangeMapping` |
| 8 | `widgets/search/dictionary_search_result_tile.dart:53` | `ref.watch` (dictionary is always Pali, still gated) |

### G. Settings UI — `widgets/app/settings_menu_button.dart`
Add a `_PaliLettersSection` `ConsumerWidget` (under a new `_MenuSectionLabel`) holding **three**
switches that `ref.watch` the providers and call `.toggle()` (same live-update pattern as the existing
selectors). New ARB keys in `app_en.arb` + `app_si.arb`, then regenerate l10n:
- section header (e.g. `paliLetters`)
- `paliStandardLigatures` → EN **"Standard ligatures"** / SI **"සුලබ බැඳි අකුරු"** *(provisional;
  pairs with විශේෂ as common-vs-special. Alt EN "Standard conjuncts", alt SI "සම්මත බැඳි අකුරු" if
  we prefer "standard" over "common". Changeable later.)*
- `specialPaliLetters` → EN "Special Pali letters" / SI "විශේෂ පාළි අකුරු භාවිතා කරන්න"
- `paliTouching` → EN "Touching letters" / SI "පාළි බැඳි අකුරු"

### H. Tests (fix existing minimally — locked)
Update call sites for the new signatures and adjust expected strings where the **default** behaviour
changed (common pairs now ligated after-hal; repaya now applied). No new toggle coverage in this pass
(deferred to `qa-test-writer` per CLAUDE.md). Likely files:
- `test/presentation/utils/content_text_formatter_test.dart`
- `test/presentation/utils/search_result_labels_test.dart`
- `test/presentation/widgets/tab_bar_widget_test.dart`
- `test/core/utils/pali_conjunct_transformer_test.dart` (if present)

Per repo convention these test edits run automatically (`-d macos`) since the work touches tests.

---

## 10. Out of scope

- **Prenasalized / sanyaka** (ඟ ඳ ඬ ඹ), incl. ඞ්ග→ඟ — separate feature, *meaning-changing* (see the
  research note below).
- **Sinhala search normalisation** — the FTS-only Sinhala rakar/yansa case ([§6](#6-scope-pali-only)).
- **Pali Script (Roman) axis** — deferred; when Roman lands, the Pali branch of `formatContentLabel`
  picks script first and skips conjuncts for Roman.
- **Dictionary lookup** — `removeConjunctFormatting` strips ZWJ before lookup regardless of toggles.
- **Search index** — DB stores plain text; beautification is display-time only, toggles never touch
  FTS matching.

### Research note — prenasalized (sanyaka) letters, and why Pali never uses them

Sinhala has four core (*śuddha*) **prenasalized** consonants — **ඟ ඳ ඬ ඹ** (plus an archaic ඦ). Each is
a *single precomposed codepoint*, **not** a virama+ZWJ join, and each encodes one phoneme (a short
nasal onset fused into the following stop). Sinhala is one of only three languages in the world that
**phonemically contrast** a prenasalized consonant with its matching nasal+stop *cluster*:

- **කඳ** `[kaⁿdə]` = *trunk* — prenasalized, single letter ඳ
- **කන්ද** `[kandə]` = *hill* — cluster, න්ද

→ **different words.** This is the crux: a prenasalized letter is not a "prettier" rendering of the
cluster — it is a different sound, usually a different word.

**How Pali uses them: it doesn't.** Pali nasal+stop sequences (`ṅga, ñca, ṇḍa, nda, mba` — e.g.
*aṅga*, *paṇḍita*, *Ānanda*, *ambara*) are always written as **full clusters** — nasal + hal + stop
(අඞ්ග, පණ්ඩිත, ආනන්ද, අම්බර). The prenasalized letters belong to *native Sinhala* vocabulary; the
Sinhala-script Pali tradition — and our BJT source — renders these as plain clusters.

- **Handled now:** nothing in our pipeline (or tipitaka.lk's) ever *produces* a prenasalized letter.
  The spot-check ([§6](#6-scope-pali-only)) found Pali stored as bare clusters; the only path that
  could create one is the legacy substitution **ඞ්ග → ඟ**, which we explicitly exclude ([§3](#3-the-tiers-and-their-exact-character-lists)).
- **How it should stay:** leave them untouched. Folding a cluster into a prenasalized glyph would be
  **lossy and meaning-changing** (කන්ද → කඳ), and as single codepoints they sit entirely *outside* the
  virama/ZWJ mechanism the three switches operate on. They are correctly out of scope — not a fourth
  switch, and not a hidden step inside Switch 1.

---

## 11. Sources

- The Unicode Standard 16.0, Ch. 13 (Sinhala) — https://www.unicode.org/versions/Unicode16.0.0/core-spec/chapter-13/
- SLS 1134 : 2011 (Sri Lanka Standard Sinhala character code) — https://www.language.lk/wp-content/uploads/2018/03/SLS-1134-2011.pdf
- r12a — Sinhala orthography notes — https://r12a.github.io/scripts/sinh/si.html
- Microsoft — *Creating and Supporting OpenType Fonts for Sinhala Script* (authoritative glossary: **"Touching letters"** = ZWJ+halant, "used in classical and Buddhist texts"; **"Ligature"** = halant+ZWJ; repaya / yansaya / rakaaraansaya) — https://learn.microsoft.com/en-us/typography/script-development/sinhala
- Wikipedia — *Prenasalized consonant* (Sinhala: කඳ "trunk" vs කන්ද "hill" minimal pair; only 3
  languages contrast N͜C vs NC) — https://en.wikipedia.org/wiki/Prenasalized_consonant
- helpcentre.lk — conjuncts, rakaransaya & yansaya — https://helpcentre.lk/knowledgebase/issues-pertaining-to-rendering-and-resolving-labels-with-conjunct-consonants-rakaransaya-and-yansaya-forms-in-sinhala-script/
- pitaka.lk — Pali bandi generator (common vs rare) — https://pitaka.lk/tools/unicode/pali_bandi.htm
- uthmax (2009) — රකාරාංශ / යංශ / රේඵ usage notes — https://uthmax.blogspot.com/2009/06/blog-post.html
- tipitaka.lk (local) — `src/text-convert.mjs`, `src/store/tree.js`, `src/views/FTS.vue`

### Cross-check: uthmax blog vs our model

Aligns, no contradictions:
- **repaya (රේඵය) is "optional in modern writing"** — supports putting it behind a *toggle* (Switch 3)
  rather than hard-coding it. Also: the blog treats repaya as *more* optional than yansaya/rakaransaya,
  which is exactly why our design keeps them as **separate units** (`addRepaya` vs `addYansaya`/
  `addRakaransaya`) — a future "repaya off, yansaya on" split is then trivial.
- **ද්ව / ද්ධ ("දකාරාංශය")** are treated as special joined forms that are "hard to write in Unicode" —
  consistent with them living in Switch 2 (special, UN-font ligatures).
- The blog gives no pair lists, no prenasalized discussion, and uses older/variant term names —
  reinforcing our choice to name internals by *mechanism*, not by the unstandardised Sinhala labels.

## 12. Verification checklist

- [ ] Toggle each of the 3 switches → reading pane **and** tree/tab/breadcrumb/search labels update
      live without reopening the menu.
- [ ] Default launch = grid row 1 (S3 ON, S2 OFF, S1 ON).
- [ ] `චන්ද` (common) stays ligated whenever S3 is ON; `බුද්ධ` (special) only ligatures when S2 ON;
      `ධර්ම` shows repaya when S3 ON.
- [ ] All three OFF = bare baseline everywhere.
- [ ] Sinhala content language: switches have no visible effect.
- [ ] Settings persist across restart.
- [ ] Code comment present recording the ම්බ and ඞ්ග→ඟ exclusions.
- [ ] `flutter analyze` clean; updated tests pass (`-d macos`).
