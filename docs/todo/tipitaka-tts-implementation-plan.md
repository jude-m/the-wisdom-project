# Tipitaka Reader — Text-to-Speech: Implementation Plan

**Status:** Build spec for the dev team / coding agent. **Reframed 2026-07-05 (see §0):** Pali listening is the *existing human recordings*, **not** TTS; TTS now scopes to **Pali single words (live+cached)** + **the whole Sinhala corpus (pre-rendered)**; sentence-level alignment and on-device are both dropped. The TTS pipeline detail (§2) stands unchanged — it's exactly what Phase 2 and the Sinhala mirror build on.

---

## 0. Scope & phasing (decided 2026-07-05 — read first; supersedes the old stage model)

**Two audio sources, not one.** The original plan assumed TTS synthesizes *everything*. It doesn't. Pali listening **already exists** as human chanting recordings from the tipitaka.lk project (`.m4a` files + **entry-level** timestamp `.txt` labels + `file-map.json`; documented in `tipitaka.lk/how-audio-works.txt`). TTS's job narrows to the gaps:

| Audio need | Source | Granularity |
| --- | --- | --- |
| Pali sutta / paragraph listening | **existing human recordings** (already built) | entry (paragraph); finer = **player seek** |
| Pali single word (tap a word) | **TTS — live + cached** (one model) | the word |
| Sinhala sutta / paragraph | **TTS — pre-rendered** on the Mac, served static | entry (mirror of the Pali entries) |
| Sinhala single word | **not needed** (the audience knows Sinhala); worst case reuse the Pali word endpoint | — |

**Why the split (settled in the design conversation):**
- You **cannot slice a word out of the chanted recordings** — forced alignment on chanting is infeasible (no Pali acoustic model; chanting ≠ speech). So single words **must** be synthesized.
- Pre-generating a whole robot-voice Pali canon just to harvest word slices is wasteful *and* sounds worse than an isolated synth → **synthesize a word only when tapped, cache it on R2** (organically bounded; never a million files — that was the hard "no per-word files" rule, DPD has >1M headwords).
- Sinhala has **no recordings at all** → pre-render the whole covered corpus once on the Mac ($0 compute), serve static.
- **No sentence-level alignment.** Entry (paragraph) is the floor; users scrub the player for anything finer. Sentence-chunking survives only as the model's *input-length ceiling* (§1), not as a highlight tier.

**Runtime = static files on R2 + exactly ONE live model** — the Pali single-word endpoint (Cloud Run scale-to-zero), which fires only on a cache miss ≈ $0.

**Build phases:**
- **Phase 1 — Pali sutta/entry playback from the existing recordings.** *No synthesis.* Integrate tipitaka.lk's audio + entry labels + `file-map` into the app: entry-level highlight, tap-entry-to-play, player seek. This is "what we already have," ported in.
- **Phase 2 — Single-word TTS.** Stand up the TTS pipeline (§2) for the **single-word** case only: tap a Pali word → synthesize (live) → cache on R2 → play. One model, Pali voice.
- **Sinhala mirror (parallel with / after Phase 2).** The *same* TTS pipeline, run as a **Mac batch**: pre-render every entry's Sinhala audio → R2, mirroring the Pali entry structure. Reuses everything from Phase 2; differs only in the romanizer (`si`) and in running offline in bulk rather than live.
- **Dropped: on-device** (old Stage 3, see §5) — the audience has low-end phones, and the new architecture already reaches ≈ $0 without it.

**Neither language's romanizer is a blocker** (both found & proven — §2.3): Pali `@pnfo/pali-converter`; Sinhala `@pnfo/singlish-search` (MIT, Dart-portable).

---

## 1. Architecture (the spine, true across all stages)

> **Scope (per §0):** this spine serves the **TTS-produced** audio only — **Pali single words** (live) and the **full Sinhala corpus** (pre-rendered batch). **Pali paragraph/sutta listening does not pass through here** — it plays the existing human recordings (entry-level labels + `file-map`). So in the "three use cases" below, the **single-word** row is the live Pali path; the **paragraph / whole-sutta** rows apply to **Sinhala** (run as a Mac batch, not live streaming). Highlighting is **entry-level**; the sentence chunking described below is only the model's input-length ceiling, *not* a highlight tier.

One method, one response shape. The **atomic unit is a *segment*** (any text the caller wants spoken as one playable thing). A **sentence is the chunking *ceiling*, not the unit** — long segments are split down to sentence-sized chunks because the model degrades past ~15 s of input; short ones (a single word) pass through as one chunk.

Three use cases collapse to invocations of the same method:

- **Single word** (dictionary tap) → 1-segment call, `style: pronunciation`.
- **Paragraph** → 1 segment, chunked into sentences.
- **Whole sutta** → an ordered list of segment calls, played in sequence (client streams: play paragraph *k* while *k+1* synthesizes).

Two processes, each in its native ecosystem:

```
                 ┌─────────────────────────────────────────┐
  Flutter client │  POST /v1/tts {text, lang, voice, style} │
  (highlighting, └───────────────────┬─────────────────────┘
   playback)                         │
                                     ▼
                  ┌──────────────────────────────────────┐
                  │  API GATEWAY  (Node / TypeScript)      │
                  │  • normalize  • romanize  • chunk      │   ← text pipeline lives here
                  │  • call model server per chunk         │     (JS, because the romanizers are JS)
                  │  • assemble audio + timing  • encode    │
                  │  • (Stage 2) cache                     │
                  └──────────────────┬─────────────────────┘
                                     │  HTTP, romanized text
                                     ▼
                  ┌──────────────────────────────────────┐
                  │  MODEL SERVER  (Python, coqui VITS)    │   ← pure text→wav inference
                  │  romanized text  →  WAV                │
                  └──────────────────────────────────────┘
```

**Why split this way:** the romanizers (`@pnfo/pali-converter`, `sinhalaToRomanConvert`) are JS/npm; the VITS model runs in Python. Each side stays native. The gateway owns the contract and the text pipeline; the model server is a dumb, swappable `text → wav` function. That swap point is the **`TtsEngine` seam** — later it can be a recorded-audio source, or (Stage 3) an on-device engine, with **zero client change**.

**Alignment is free and uniform.** Stage 1 uses **chunk-as-clip**: each sentence chunk is its own clip, so clip *i* ↔ sentence *i* — no timestamp math, no label files. The response carries a `segments[]` array with `startMs/endMs`. Highlight granularity is just the *density* of that array (sentence now; word later), not a different API. Turning highlighting off is pure client work (ignore the array).

**Two rules to pay the “design for on-device later” cost now, and nothing more:**
1. Keep `normalize → romanize → chunk` a **pure, portable library** with no server dependency (so it can be ported to Dart in Stage 3).
2. Keep the model behind the **`TtsEngine` interface** (server impl today).

---

## 2. STAGE 1 — DETAILED

**Sub-stage scope.** Everything in §2.1, §2.2, §2.4, §2.5, §2.6 is shared. The *only* differences:

| | Stage 1.1 (Pali) | Stage 1.2 (Sinhala) |
| --- | --- | --- |
| `lang` accepted | `pali` | adds `si` |
| Romanizer | `@pnfo/pali-converter` — **ready** | `@pnfo/singlish-search` `sinhalaToRomanConvert` — **ready (MIT)** |
| Voice | single-speaker male (Ven. Mettananda) | same, or add female (multi-v2.0) |
| Blocking dependency | none | none (romanizer found) |

Build 1.1 to completion (shippable Pali audio), then drop in the Sinhala romanizer to light up 1.2 with no other changes.

### 2.1 Prerequisites (macOS, Apple Silicon)

```bash
brew install pyenv ffmpeg node        # ffmpeg = transcode/trim/slow; node = gateway + romanizer
pyenv install 3.11.9                   # coqui-tts needs Python >=3.9, <3.13 (NOT 3.13)
```

### 2.2 Part A — Stand up the model locally

Target layout (matches pnfo’s own run instructions — models live in a `models/` dir *beside* the repo):

```
~/tts-workspace/
  coqui-ai-TTS/                         (pnfo fork, venv inside)
  models/sinhala/
    single-v2.1/  { config.json, checkpoint_80000.pth }          ← Stage 1 voice (male, Ven. Mettananda)
    multi-v2.0/   { config.json, checkpoint_70000.pth, speakers.pth }   ← female/multi, later
```

```bash
mkdir -p ~/tts-workspace && cd ~/tts-workspace
pyenv local 3.11.9

# 1. pnfo's Coqui fork
git clone https://github.com/pnfo/coqui-ai-TTS.git
cd coqui-ai-TTS
python -m venv venv && source venv/bin/activate
pip install --upgrade pip
pip install -e ".[server]"             # editable install + the Flask server extra

# 2. Models — download the assets from the pnfo dataset release and place per the layout above
#    Releases: https://github.com/pnfo/sinhala-tts-dataset/releases   (tag: v2.0-model)
mkdir -p ../models/sinhala/single-v2.1 ../models/sinhala/multi-v2.0
#    -> drop config.json + checkpoint_80000.pth into single-v2.1/
#    -> drop config.json + checkpoint_70000.pth + speakers.pth into multi-v2.0/

# 3. CLI smoke test (single speaker). Input must be ROMANIZED (see Part B).
tts --text "Atha kho bhagavā" \
    --model_path ../models/sinhala/single-v2.1/checkpoint_80000.pth \
    --config_path ../models/sinhala/single-v2.1/config.json \
    --out_path /tmp/test.wav
open /tmp/test.wav

# 4. Web server — eyeball quality in a browser before writing any code
python TTS/server/server.py \
    --config_path ../models/sinhala/single-v2.1/config.json \
    --model_path ../models/sinhala/single-v2.1/checkpoint_80000.pth
# -> open http://localhost:5002 and paste romanized text (e.g. "Satipaṭṭhāna")
```

**Notes**
- Runs on **CPU** by default on Apple Silicon — fine for VITS (sub-second to a few seconds per sentence). MPS is optional and unnecessary.
- Open `config.json` and confirm `"use_phonemes": false`. The model tokenizes the **romanized characters directly**, so **espeak-ng / phonemizer are NOT required**. (If it were `true` you’d need a phonemizer — it isn’t, for this model.)
- The stock server’s web UI expects **already-romanized** input. Romanization is the gateway’s job (Part B/C).

### 2.3 Part B — Romanization (the Pali/Sinhala divide)

The model eats romanized (IAST-style) text, **not** native script. Crucially there are **two different romanizers**, and they are not interchangeable — this was verified empirically, not assumed.

| `lang`  | Source script (in BJT JSON) | Converter | Status |
| ------- | --------------------------- | --------- | ------ |
| `pali`  | Pali in **Sinhala script**  | `@pnfo/pali-converter` (npm) | **Ready, proven** |
| `si`    | Sinhala-language prose       | `sinhalaToRomanConvert` from `@pnfo/singlish-search` (npm, **MIT**) | **Found, proven** |

Both romanizer outputs must be **lowercased** before synthesis — the model's character set is entirely lowercase (see below).

**Pali path — done.** `@pnfo/pali-converter` v1.1.2, signature `convert(text, toScript, fromScript)`:

```js
import { convert, Script } from '@pnfo/pali-converter';
convert('සතිපට්ඨාන',  Script.LATN, Script.SINH);  // -> "Satipaṭṭhāna"
convert('අථ ඛො භගවා', Script.LATN, Script.SINH);  // -> "Atha kho bhagavā"
```

Both outputs were generated and verified; `Atha kho bhagavā` matches pnfo's own published model example. Pali is a lossless 1:1 script mapping (Pali orthography is perfectly phonemic), the model's character set fully covers it, and it round-trips. **Zero open work** beyond wiring.

**Why you cannot reuse the Pali converter for Sinhala — proven, not theoretical.** Running a real Sinhala sentence through it:

```
input :  ... වැඩ වසනසේක.
output:  ... mula vැḍa vasanaseka.          ←  "වැ" came out as  vැ
```

The `ැ` vowel (the **æ** sound, as in *cat*) leaked through **untransliterated**, because Pali has no such sound and the converter has no mapping for it. Sinhala-only graphemes (`ැ`/`ඇ` = æ, `ෑ`/`ඈ` = ǣ, and prenasalized consonants `ඬ ඳ ඟ ඹ`) all fall through this way. Two consequences:

1. The model's documented Roman character set **includes `æ` and `ǣ`** — so it was trained on a Sinhala romanizer that *produces* those characters. Feeding it the Pali converter's output (raw `ැ`/`ඇ` mixed into Roman) gives the model tokens it never saw in training.
2. The Pali converter also renders every inherent vowel as a flat `a` (it's an orthographic mapper, not a pronunciation predictor) — fine for Pali, but Sinhala's spoken schwa behaviour is absorbed by the model from its training romanization, which again means **you must match pnfo's exact scheme.**

**Bottom line:** Sinhala must be romanized with the *same* scheme pnfo used to prepare the Sinhala training data. That scheme is `sinhalaToRomanConvert`.

**Found and verified — `@pnfo/singlish-search`.** The function lives in `roman_convert.js` of the npm package `@pnfo/singlish-search` (**MIT-licensed**), exporting `sinhalaToRomanConvert` and `romanToSinhalaConvert`:

```js
import { sinhalaToRomanConvert } from '@pnfo/singlish-search';   // roman_convert.js
sinhalaToRomanConvert('බුද්ධ ජයන්ති ත්‍රිපිටකය');  // -> "buddha jayanti tripiṭakaya"
```

Run on a real sutta sentence, contrasted with the Pali converter on the same input:

```
Pali converter (wrong):   ... mula vැḍa vasanaseka. ... ඇmatūseka
singlish-search (right):  ... mula væḍa vasanasēka. ... æmatūsēka
```

`වැ → væ`, `ඇ → æ`, long vowels correct (`vahansē`, `mesē`), no leaked script. This is the tool.

Three properties that matter:
- **MIT license** — commercially clean, no permission needed for this piece (unlike `@pnfo/pali-converter`).
- **Pure rule-based** — lookup tables + a permutation generator, no dictionary/model. Ports to Dart almost mechanically → answers the Stage 3 portability question.
- **Output matches the model's charset** — emits the documented all-lowercase set including `æ`/`ǣ`.

**Casing — resolved.** The model's Roman character set is entirely lowercase (`…abcdefghijklmnoprstuvyæñāēīōśşūǣḍḥḷṁṅṇṉṛṝṭ`) and pnfo's own Pali example is lowercase (`atha kho bhagavā`). So **lowercase everything before synthesis.** `sinhalaToRomanConvert` already outputs lowercase; the Pali converter capitalizes the first letter, so the gateway must `.toLowerCase()` its output too.

**Optional consolidation (evaluate, don't assume):** `singlish-search` also covers the Pali consonant set, so the team *could* test whether it can romanize Pali acceptably too — which would retire the non-commercial `@pnfo/pali-converter` dependency entirely. Validate it against Pali conjuncts (e.g. `ක්‍ඛ`) and the demo samples first; until then, keep `pali-converter` for Pali as pnfo intends.

> **Guardrail — do not confuse the two halves of `@pnfo/singlish-search`.** The package contains *two different* tools: `singlish.js` (`getPossibleMatches`) does **Singlish ASCII → Sinhala** for *search* (user types `nirvana`); `roman_convert.js` (`sinhalaToRomanConvert`) does **Sinhala → Roman IAST** for *TTS*. Only the latter is the TTS romanizer. A project may already have a Dart Singlish→Sinhala transliterator for search — that is the **wrong direction and a different alphabet** (ASCII `t/T/th/Th/~n/Sh` vs IAST `ṭ/ṭh/ṃ/ś`) and must **not** be reused for TTS. For Stage 3, port `roman_convert.js` specifically.

**Caveat (Pali):** `@pnfo/pali-converter` capitalizes the first letter; lowercase for the single-word case if needed, and confirm capitalization against training (above). Its source header carries a **non-commercial** clause — ensure your written permission explicitly covers it (see §3).

### 2.4 Part C — API gateway (Node / TypeScript)

**Contract — one endpoint, all three use cases:**

```http
POST /v1/tts
{
  "text":     "සතිපට්ඨාන",        // native script
  "lang":     "pali" | "si",
  "voice":    "male",             // Stage 1: single-speaker male (Ven. Mettananda)
  "style":    "reading" | "pronunciation",
  "withTiming": true
}

200 ->
{
  "audio":    { "format": "mp3", "base64": "…", "durationMs": 1840 },
  "segments": [
    { "index": 0, "text": "සතිපට්ඨාන", "roman": "satipaṭṭhāna", "startMs": 0, "endMs": 1840 }
  ],
  "modelVersion": "single-v2.1"
}
```

**Per-request pipeline:**

1. **Normalize** (pure, portable library — keep server-free for Stage 3):
   - strip footnote markers / reference numbers;
   - drop structural / `noAudio`-type entries (reuse the existing `noAudio` logic);
   - **do not voice paragraph numbers** like `234.` — strip them (confirm this product choice);
   - normalize whitespace/punctuation;
   - apply the **pronunciation lexicon** overrides (see §3).
2. **Romanize** by `lang`, then **lowercase** the result (model charset is all-lowercase):
   - `pali` → `convert(text, Script.LATN, Script.SINH)` then `.toLowerCase()`
   - `si`   → `sinhalaToRomanConvert(text)` (already lowercase)
3. **Chunk** (sentence = ceiling): split on terminal punctuation (`.`, `;`, `—`, and the script’s sentence breaks), then enforce a max length (~ the char count that maps to <15 s audio). A single word stays one chunk (no-op).
4. **Synthesize** each chunk via the model server (HTTP), collect one WAV per chunk.
5. **Style handling** (gateway-side via ffmpeg — model-agnostic, robust):
   - `reading`: as-is;
   - `pronunciation`: slow + tidy — `atempo=0.85`, trim leading/trailing silence, optional ~60 ms pad.
6. **Assemble:** concatenate chunk WAVs into one stream; compute cumulative offsets → `segments[]` (`startMs/endMs` per chunk). This **chunk-as-clip** mapping is the Stage-1 highlighting source — no VITS duration extraction.
7. **Encode** to mp3 (or opus) via ffmpeg; return JSON (base64 + segments). JSON+base64 is fine for Stage 1; switch to binary+sidecar later if payload size matters.

**How each use case rides through the one method:**
- **Word:** `text=word, style=pronunciation` → 1 chunk, slowed/padded.
- **Paragraph:** `text=paragraph, style=reading` → N sentence chunks → one audio + N segments; client highlights the current sentence.
- **Whole sutta:** client calls per paragraph in order and streams. (Optional `/v1/tts/batch` convenience wrapper later — not required for Stage 1.)

**Highlight granularity = segment density, same contract.** Sentence-level now. Word-level later by producing word segments from VITS token durations (a model-server enhancement) — no contract change.

### 2.5 Part D — Model server (recommended shape)

Two options:

- **Fastest smoke test:** the stock coqui server (Part A step 4); gateway calls `GET /api/tts?text=<romanized>` and gets WAV.
- **Recommended for Stage 1:** a thin FastAPI wrapper that loads the checkpoint once and exposes `POST /tts {text} -> WAV`. Cleaner seam, process control, and speed/pad stay gateway-side so the model server is a pure function.

```python
# model_server.py  — run inside the coqui-ai-TTS venv
#   pip install fastapi uvicorn soundfile
import io, numpy as np, soundfile as sf
from fastapi import FastAPI, Body
from fastapi.responses import Response
from TTS.utils.synthesizer import Synthesizer

synth = Synthesizer(
    tts_checkpoint="../models/sinhala/single-v2.1/checkpoint_80000.pth",
    tts_config_path="../models/sinhala/single-v2.1/config.json",
    use_cuda=False,
)
app = FastAPI()

@app.post("/tts")
def tts(text: str = Body(..., embed=True)):     # romanized text in
    wav = synth.tts(text)
    sr = synth.output_sample_rate
    buf = io.BytesIO(); sf.write(buf, np.array(wav), sr, format="WAV")
    return Response(buf.getvalue(), media_type="audio/wav")

# run:  uvicorn model_server:app --port 5050
```

### 2.6 Part E — Testing & acceptance

- **Unit:** romanizer golden tests (30 known Pali phrases, SINH→LATN, reviewed by a Pali-literate person); chunker tests (long paragraph → sentence chunks; single word → 1 chunk; cumulative offsets correct).
- **Integration:** `POST /v1/tts` for all three use cases × both languages — assert audio non-empty, segment count, monotonic `startMs/endMs`, total ≈ sum of chunks.
- **Quality gate (the real gate — manual):** generate ~50 items — a Pali paragraph, the same in Sinhala, and 50 dictionary headwords including tricky ones (long vowels ā/ī/ū, gemination ṭṭh/ṇṇ, niggahīta ṃ, retroflexes). A Pali-literate reviewer (monk/scholar) signs off. Log systematic mispronunciations → pronunciation lexicon.
- **Stage 1.1 done when:** all three use cases return correct audio + timing for **Pali**; reviewer signs off on Pali pronunciation; word mode is intelligibly slow and clean. (No dependency on the Sinhala romanizer.)
- **Stage 1.2 done when:** the same holds for **Sinhala**, using pnfo's `sinhalaToRomanConvert`; reviewer confirms `æ`/`ǣ` words and schwa-bearing words read correctly.

---

## 3. Cross-cutting concerns

- **Licensing (you have permission — get it in writing, covering the two pnfo pieces that need it):** (a) the VITS **model weights**, and (b) **`@pnfo/pali-converter`** (source header is non-commercial-without-permission). **`@pnfo/singlish-search` is MIT** and needs no permission. One email confirming (a) and (b) closes this. (If you later consolidate Pali onto `singlish-search` per §2.3, (b) drops away too.)
- **Pronunciation lexicon:** a small override map `{ romanized term → corrected spelling }` applied in the normalize step, for proper names / rare terms the model mis-says. Cheap, high-leverage.
- **Voice:** Stage 1 = single-speaker male (Ven. Mettananda; no `speakers.pth`). Female (multi-v2.0) is a later toggle.
- **Hardening (Stage 1.5):** the stock Flask server is single-threaded/dev-only. The FastAPI `Synthesizer` wrapper + a worker/queue handles concurrent sutta playback.
- **Expectation:** TTS produces clear **reading** pronunciation, not devotional **chanting**. Correct for a study app; flag it as a conscious product choice.

---

## 4. STAGE 2 — Caching + warm a few suttas (high level)

- Output is deterministic for `(text, lang, voice, style, modelVersion)` → cache on that key: audio in object storage / CDN, segment metadata in a small KV.
- Gateway checks cache first; miss → synthesize → store → return. On-the-fly vs pre-generated becomes “warm or cold,” not an architecture fork.
- **“Few main suttas on demand” = a warm-up job** that runs the pipeline over a chosen popular set and populates the cache, so first play is instant and pre-reviewed. This is the demoted “batch” idea: same architecture, batch = eager cache-warming; long tail stays lazy.
- Add **auth + rate-limiting** on the synth path (cost + abuse surface).
- Bump `modelVersion` in the cache key when pnfo ships a better checkpoint — popular content re-warms lazily, the rest costs nothing until requested.
- **Under the §0 reframe, this section splits cleanly in two:** the **cache** is exactly the **Pali single-word cache** (lazy, cache-on-tap); the **"warm" batch is the full Sinhala pre-render** run on the Mac — not "a few popular suttas" but the whole covered Sinhala corpus, since Sinhala has no recordings. Pali paragraph/sutta audio is **not** cached here at all — it's the static human recordings.

---

## 5. On-device — DROPPED (far-future, not planned) (decided 2026-07-05)

**Shelved.** The target audience (monks, often on low-end phones) makes on-device synthesis the wrong bet, and the new architecture removes its main rationale: the highest-volume case (Pali single words) is served live+cached from **one** scale-to-zero endpoint, and everything else is pre-rendered static from R2 — so marginal cost is already ≈ $0 without pushing the model onto the phone.

Kept here only as a note of what it *would* entail if ever revived: export the VITS checkpoint to **ONNX** → run via **sherpa-onnx** (Flutter, iOS + Android, consumes Piper/Coqui VITS) → reuse the pure `normalize → romanize → chunk` library (ported to Dart) behind a new on-device **`TtsEngine`** impl, with **no client change**. The two portability rules in §1 keep this option cheap to reopen; nothing else in the plan depends on it.

---

## 6. Decisions for the team to confirm

1. **Phasing** (§0) — confirm the reframed model: **Phase 1** = Pali sutta/entry from the *existing recordings* (no TTS); **Phase 2** = single-word TTS (Pali live+cached); **Sinhala** = pre-rendered mirror (Mac batch → R2); **sentence-level and on-device both dropped**. (Supersedes the old Stage 1/2/3 "live-TTS-everything" reading.)
2. **Source script** of Pali in your BJT JSON — assumed **Sinhala script**; confirm (routes the romanizer).
3. **Paragraph numbers** — assumed **not voiced**; confirm.
4. **Sinhala romanizer (Stage 1.2)** — resolved: `@pnfo/singlish-search` `sinhalaToRomanConvert` (MIT, rule-based, Dart-portable). Remaining: a quality-gate listen on Sinhala output. Pali (Stage 1.1) uses `@pnfo/pali-converter`.
5. **Capitalization — resolved:** model charset is all-lowercase; lowercase both romanizers' output. Confirm the female voice (multi-v2.0) language coverage (Pali too, or Sinhala only) if you want a female Pali option.
6. **Transport** — Stage 1 starts with JSON + base64; move to binary + segments sidecar if/when payload size matters.
7. **Deployment host (§7)** — confirm the model-server placement: **A) GCP Cloud Run scale-to-zero** (leaning) vs **B) co-locate on the web-server box**; and that the **audio cache uses Cloudflare R2** (zero-egress), not GCS.

---

## 7. Deployment & cost (hosting strategy)

**Context:** no sponsors yet — optimize for **nimble / near-zero idle cost**, not peak throughput. The decisive fact is that pnfo's VITS is a **small CPU model** (tens of MB; sub-second to a few seconds per sentence on CPU), **not a GPU LLM** — so it lives in a cheap deployment bracket with options a GPU model can't use. *(All free-tier/pricing figures below are approximate and were current as of mid-2026 — confirm on each provider's page before committing.)*

### 7.1 What goes where

| Component | Host | Why |
| --- | --- | --- |
| Web / content server | **Always-on box** (the project needs one regardless) | Always warm, flat cost, no cold start |
| Gateway (Node) | Box, or co-located / serverless | Lightweight: normalize / romanize / chunk / encode |
| **Model server** (Python + torch + coqui) | **GCP Cloud Run, scale-to-zero** | Heavy at *load*, light at *run*; bursty / occasional → free while idle |
| **Audio cache** (Stage 2 output) | **Cloudflare R2** | Free storage + **zero egress** |

Two equally valid placements for the model server — pick on cold-start tolerance:
- **A — Cloud Run scale-to-zero** *(leaning)*: $0 while sleeping, free tier likely covers all synths; the cost is cold-start latency on the first uncached request.
- **B — co-locate on the box**: marginal cost ~$0 (box already paid for), always warm / no cold start; the cost is synth CPU spikes sharing the box — cap them with the Stage 1.5 worker/queue. Caching makes spikes rare.

The clean **gateway ↔ model** seam (§1) means the model can move between A and B later with **no client change**.

### 7.2 Model server — GCP Cloud Run (not AI Studio)

- **Not Google AI Studio, and not Google's own TTS.** AI Studio only serves Google's *own* models (Gemini) — you cannot host pnfo's VITS there. Google's own TTS is also unusable for this app: **no Pali**, and wrong pronunciation of Buddhist terms / long vowels / niggahīta. pnfo's domain-trained model is the whole point. Deploy pnfo's container yourself; optionally in a **separate GCP project** for clean billing / key / quota isolation (the `ask_server` Dockerfile already targets Cloud Run — same pattern).
- **Scale-to-zero = idle is free.** No requests → zero containers → **$0**. A mostly-sleeping service is the *intended* case, not a problem.
- **Free tier (approx):** ~2M requests, ~180k vCPU-seconds, ~360k GiB-seconds / month. At ~2 vCPU-sec + ~4 GiB-sec per synth, that's roughly **tens of thousands of free synths/month** — a study app with caching likely lives entirely inside it.
- **The one catch — cold start (latency, not money):** the first request after idle must load torch + the checkpoint → **several seconds to ~30s**. Mitigate by (a) leaning on the Stage 2 cache / pre-warm so cold starts only hit rare first-time content, (b) keeping the image lean + startup-CPU-boost, or (c) `min-instances=1` — but that pays ~24/7 and defeats scale-to-zero (at which point option B / the box wins).
- **Break-even vs an always-on box:** ~100k synth requests/month. Below → serverless wins; above → box. Caching shrinks real synth volume so far that both converge toward ~free.

### 7.3 Audio cache — Cloudflare R2 (not GCS)

CDN cost is **two meters**: *storage* (what you keep — cheap, ignore it) and *egress* (what you serve — scales with listeners; the meter that produces surprise bills). Optimize for egress.

- **Cloudflare R2:** 10 GB free storage + **zero egress, ever** + 10M reads / 1M writes free per month. Zero-egress is the whole reason — serving a popular sutta a million times stays $0.
- **Do NOT store audio on Google Cloud Storage** despite the model running on GCP — GCS charges egress (~$0.08–0.12/GB), exactly the meter to avoid. Keep them split: Cloud Run **writes** new clips to R2; **all playback is served from R2**. GCP only ever sees the rare cold synth.
- **Serve from an R2 public bucket on a custom domain** (the sanctioned media path), not by proxying heavy media through Cloudflare's free CDN plan (acceptable-use limits on media).
- **Sizing:** speech at **Opus ~32 kbps** (or mp3 64 kbps), mono ≈ **15–30 MB/hour** → 10 GB ≈ **350–650 hours**. The **whole Sinhala corpus is pre-rendered** (§0), and the recorded corpus is **~12 hours of voice** → the Sinhala mirror is **~180–360 MB** (≈ **2–4% of R2's 10 GB free tier**). Even if the Pali recordings also move onto R2 (~similar duration), both together stay **under ~0.7 GB** — no overage scenario at all, comfortably inside the free tier, egress $0. **Pali single-word clips stay lazy** (cache-on-tap), a tiny bounded set. Storage is a genuine non-issue.

### 7.4 Endgame — pre-rendered static + one live endpoint

The zero-idle-cost end state **is already the design**, not a future stage: **everything pre-rendered lives on R2** (the Pali human recordings + the full Sinhala mirror), served static with zero egress, and the **only live component is the Pali single-word endpoint** on Cloud Run scale-to-zero — it fires just on a cache miss and then never again for that word. No on-device step is needed to reach ≈ $0 marginal cost. (On-device is dropped — §5.)

### 7.5 Recommended nimble setup (no sponsors)

1. **Pali listening → existing human recordings on R2** (no synthesis); serve static — entry-level labels drive highlight + player seek.
2. **Sinhala → pre-render the whole covered corpus once on the Mac → R2** (static mirror of the Pali entries).
3. **Pali single word → Cloud Run `--min-instances=0`** (free while sleeping); cache each tapped word to R2; accept cold-start only on the first-ever tap of a given word.
4. **Audio → Cloudflare R2** public bucket on a custom domain (free/near-free storage, zero egress); **encode Opus ~32 kbps**.
5. **Web / content server → the box** you already run; optionally co-locate the gateway there.
6. Keep the **gateway ↔ model** seam clean so the one live model can move (box ⇄ Cloud Run) with no client change.

---

## 8. Model evaluation — keep pnfo VITS, don't chase a newer model (decided 2026-07-04)

**The governing fact:** pnfo's VITS is not valuable for its *architecture* (VITS is a 2021 design, middling by today's standards) — it's valuable because it was **trained on Pali/Sinhala**, so it pronounces the domain (long vowels, gemination ṭṭh, niggahīta ṃ) correctly. **Every newer/"better"/smaller model on the market is trained on English + a few major languages; none know Pali or Sinhala.** So "switch to a better model" really means "re-do the hard Pali/Sinhala training + build a G2P," which is exactly the moat pnfo already handed us.

| Question | Finding |
| --- | --- |
| **How hard to train a new one?** | Bottleneck is **data, not compute**. Good TTS wants **10–30+ hrs** of single-speaker, studio-clean audio with accurate transcripts. Compute is cheap (rent a GPU, hours–days). Two paths: **(A) fine-tune the existing pnfo VITS on more data** — moderate, ~1–2 wks, needs the dataset; **(B) new architecture from scratch** — hard, weeks–months, *and* forces building a Pali/Sinhala **G2P** (pnfo VITS avoids this via direct romanized-char tokenization, `use_phonemes:false`). |
| **Is it "next level"?** | A real naturalness ceiling exists above VITS (StyleTTS2 / flow-matching / codec-LM sound more human) — but the gain is **cosmetic for a reading/study app** (scoped as "clear reading, not chanting"). **Risk is asymmetric:** re-training risks *worse* domain pronunciation — the whole moat — for a small prosody win. Not worth it unless the quality-gate reviewer (§2.6) rejects VITS. |
| **Audio file size?** | **Independent of model** — size = duration × bitrate. At **Opus 32 kbps** mono: **~6 KB/word, ~120 KB/paragraph, ~2.4 MB per 10-min sutta, ~14 MB/hr.** A non-issue; must not influence model choice. A better/larger model produces the *same-size* file. |
| **Smaller-but-more-powerful models?** | **Kokoro-82M** (82M params, ~300 MB / ~80 MB int8, Apache-2.0, StyleTTS2-based, #1 TTS Arena Jan 2026, runs on CPU) is the poster child — but supports only ~9 major languages, **no Pali/Sinhala**, needs a G2P it doesn't have, no language-add recipe. Using it = the same hard training project. **Also moot: pnfo VITS is *already* tiny (tens of MB, CPU-fast, ONNX-exportable for on-device Stage 3)** — smaller buys nothing; the only real headroom is naturalness. |

**Decision:** Ship Stage 1 on the existing pnfo VITS. Treat "better model" as a **Phase-2 R&D track gated on two triggers**: (a) the Pali-literate reviewer finds VITS insufficient, **and** (b) a good Pali/Sinhala dataset is secured. Even then, **first move is fine-tuning the existing VITS on more data**, not a new architecture. The highest-leverage quality investment is **more/better training data for the current voice**, not a new model.

---

### Appendix — Validated romanizer output

**Pali** — `@pnfo/pali-converter` v1.1.2, `import { convert, Script } from '@pnfo/pali-converter'`, signature `convert(text, toScript, fromScript)` (lowercase the result):

| Input (Sinhala script) | `convert(text, Script.LATN, Script.SINH)` |
| ---------------------- | ----------------------------------------- |
| `සතිපට්ඨාන`            | `Satipaṭṭhāna` → `satipaṭṭhāna`           |
| `අථ ඛො භගවා`           | `Atha kho bhagavā` → `atha kho bhagavā`   |

**Sinhala** — `@pnfo/singlish-search` (MIT), `import { sinhalaToRomanConvert } from '@pnfo/singlish-search'` (already lowercase):

| Input (Sinhala script) | `sinhalaToRomanConvert(text)` |
| ---------------------- | ----------------------------- |
| `බුද්ධ ජයන්ති ත්‍රිපිටකය` | `buddha jayanti tripiṭakaya` |
| `... වැඩ වසනසේක ... ඇමතූසේක` | `... væḍa vasanasēka ... æmatūsēka` (æ correct; cf. Pali converter leaks `vැḍa`/`ඇmatū`) |
