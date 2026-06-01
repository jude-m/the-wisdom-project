# Sinhala Translation Table

> ✅ **Applied 2026-06-01.** Decisions: confident fixes + new tokens applied;
> **Pali-style scope names kept** (no scope-chip change); **tipitaka.lk refine
> phrasing adopted** (refineSearch→සෙවුම සීමා කිරීම, refine→සීමා කිරීම,
> dictRefineTitle→ශබ්දකෝෂ තෝරන්න, wordProximity→වචන අතර දුර); **commentary
> unified to අට්ඨකථා**. New tokens: themeLight=ආලෝකවත්, backspace=මකන්න,
> searchLanguageLabel=සෙවුම් භාෂා සීමා කරන්න, clearAll=සියල්ල ඉවත් කරන්න.
> Not applied (not approved): rootText, fontSize, සම්පූර්ණ spelling polish.



Source mined: `tipitaka.lk/src` — `Settings.vue`, `App.vue`, `TSearch.vue`,
`FTS.vue`, `Dictionary.vue`, `FilterTree.vue`, `DictionaryFilter.vue`,
`constants.js`, and the canonical `public/static/data/tree.json` (Piṭaka names).

Legend: ✅ = confident recommendation · ⚖️ = judgment call (your decision) ·
🆕 = new token from Part 1 (no tipitaka.lk source — my suggestion).

---

## Group A — Internal inconsistencies in our own app (fix regardless of tipitaka.lk)

| Key(s) | Current | Issue | Recommended |
|---|---|---|---|
| `paliLanguageLabel`, `layoutPaliOnly` | පා**ල**ි | Uses dental ල. Buddhist-Sinhala standard (and tipitaka.lk Settings) is retroflex **ළ** | ✅ පා**ළ**ි / පාළි පමණයි |
| `searchHint` | …ඇතු**ල**ත් කරන්න | Spelled with dental ල, but `statusInvalidQuery` uses correct **ළ** (ඇතුළත්) | ✅ …ඇතු**ළ**ත් කරන්න |
| `searchAsPhrase` | සම්පු**ර**ණ | සම්පූර්ණ is the correct spelling (long ූ). NB: tipitaka.lk also has the typo | ⚖️ සම්පූර්ණ වාක්‍යක් ලෙස (optional polish) |
| `commentary` vs `scopeCommentaries` | අටුවාව / අට්ඨකථා | Two different words for "commentary" in the same app | ⚖️ Unify, or keep (reader=colloquial අටුවාව, scope=formal අට්ඨකථා may be intentional) |

---

## Group B — tipitaka.lk override candidates

| Key | Current | tipitaka.lk | Recommended | Note |
|---|---|---|---|---|
| `settings` | සැකසීම් | සැකසුම් | ✅ සැකසුම් | Both valid; tipitaka.lk + modern Sinhala UI use සැකසුම් |
| `updateBannerTitle` | නව **සංස්කරණ**යක් තිබේ | නව **අනුවාද**යක් තිබේ | ✅ නව අනුවාදයක් තිබේ | tipitaka.lk consistently uses අනුවාදය = "version" |
| `refineSearch` | සූක්ෂම සෙවීම | සෙවුම සීමා කිරීම | ⚖️ සෙවුම සීමා කිරීම | "narrow the search" reads clearer than "subtle search" |
| `refine` | සූක්ෂම | සීමා කිරීම | ⚖️ (follow refineSearch) | the chip/button label |
| `dictRefineTitle` | ශබ්දකෝෂ සූක්ෂම කිරීම | ශබ්දකෝෂ තෝරන්න / ශබ්දකෝෂ සීමා කිරීම | ⚖️ ශබ්දකෝෂ තෝරන්න | "select dictionaries" (tipitaka.lk dialog title) |
| `wordProximity` | වචන ආසන්නතාව | වචන අතර උපරිම දුර | ⚖️ වචන අතර දුර | "distance between words" matches the slider's actual function |
| `fontSize` | අක්ෂර ප්‍රමාණය | අකුරු විශාලත්වය | ⚖️ keep ours | ours is more formal/correct; tipitaka.lk's is colloquial. Low value |
| `rootText` | මූල පාඨය | පෙළ (Welcome.vue: "පෙළ, අටුවා") | ⚖️ මූල පෙළ | tipitaka.lk calls the canonical text පෙළ |

### Piṭaka / scope names — from tree.json `[pali, sinhala]`

tree.json gives both forms. Our chips currently use the **Pali stem**; tipitaka.lk's
**Sinhala** column uses the Sinhalised form. This is a ⚖️ set decision (keep Pali-style
names, which parallel the English "Sutta/Vinaya/Abhidhamma", **or** switch to Sinhala).

| Key | Current | tree.json Pali | tree.json Sinhala |
|---|---|---|---|
| `scopeSutta` | සුත්ත | සුත්තපිටක | සූත්‍ර (පිටකය) |
| `scopeVinaya` | විනය | විනයපිටක | විනය (පිටකය) — same |
| `scopeAbhidhamma` | අභිධම්ම | අභිධම්මපිටක | අභිධර්ම (පිටකය) |
| `scopeCommentaries` | අට්ඨකථා | (atta-) | අටුවා |
| `scopeTreatises` | ග්‍රන්ථ | — | ⚠️ no clear tipitaka.lk equivalent — needs the app's own definition of "Treatises" |

---

## Group C — New tokens from Part 1 (🆕 my suggestions; no tipitaka.lk source)

| Key | EN | Suggested SI | Rationale (web-verifiable on request) |
|---|---|---|---|
| `themeLight` | Light | ආලෝකවත් | tipitaka.lk's light screen = "ආලෝකමත් තිරය"; ආලෝකවත් is the standard adjective |
| `backspace` | Backspace | මකන්න | Clearest Sinhala for an erase/backspace key (literal "පසුබෑම" is unnatural in UI) |

---

## Group D — Reviewed, already good (keep as-is)

Already verbatim from tipitaka.lk or no better term exists:
- `isExactMatchToggle` = එම වචනයම සොයන්න ✓ (verbatim)
- `searchAsPhrase` = සම්පුර්ණ වාක්‍යක් ලෙස ✓ (verbatim — except optional spelling polish above)
- `searchAsSeparateWords` = වෙන්වූ වචන සමූහයක් ලෙස ✓ (verbatim)
- `close` = වසන්න ✓ · `commentary` = අටුවාව ✓ · `scopeVinaya` = විනය ✓
- `dictionaryLookup` = ශබ්දකෝෂය ✓ · `apply` = යොදන්න · `done` = හරි · `reset` = යළි සකසන්න
- All `layout*`, `fontSize*`, `dictFilter*`, `status*`, `error*`, in-page-search, banner keys — reviewed, no stronger tipitaka.lk term.
