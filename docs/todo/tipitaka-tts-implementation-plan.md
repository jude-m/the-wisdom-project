# Tipitaka Reader — Text-to-Speech: Implementation Plan

**Status:** Build spec for the dev team / coding agent. Stage 1 is detailed and actionable from the get-go. Stages 2–3 are intentionally high-level.

---

## 0. Stage interpretation (confirm before building)

The stages are read as:

- **Stage 1 — Always-on live API, no caching.** Every request is synthesized fresh. Split into two sub-stages by language, because Pali and Sinhala are at very different readiness levels:
  - **Stage 1.1 — Pali only.** The full pipeline end-to-end for all three use cases, Pali only. **Zero open dependencies** — the Pali romanizer is proven and complete (see §2.3). This can ship now.
  - **Stage 1.2 — Add Sinhala.** Same pipeline, plus the Sinhala romanizer (`@pnfo/singlish-search`, MIT — found and proven, see §2.3) and `lang: si`. No longer blocked; remaining work is wiring + a quality-gate listen.
- **Stage 2 — Caching + pre-warm a few main suttas.** Add a cache; pre-generate (“warm”) a chosen set of popular suttas so they play instantly without re-synthesis. The long tail stays lazy.
- **Stage 3 — On-device.** Run the model locally on the phone (no server, offline).

**Why the 1.1/1.2 split is structural, not cosmetic:** Pali is fully solved today (lossless converter, full character coverage, proven on real text). Sinhala has exactly one unresolved piece — its romanizer. Coupling them would let a Sinhala blocker hold Pali hostage for no reason. The architecture, contract, gateway, and model setup are **identical** across 1.1 and 1.2; only the romanizer (and optionally the voice) differ.

If this mapping is wrong, stop and clarify — it changes Stage 2.

---

## 1. Architecture (the spine, true across all stages)

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

---

## 5. STAGE 3 — On-device (high level)

- Export the VITS checkpoint to **ONNX**; run via **sherpa-onnx** (maintained Flutter package, iOS + Android, consumes Piper/Coqui VITS).
- **Reuse the same `normalize → romanize → chunk` library**, ported to Dart — this is exactly why Stage 1 keeps it pure and server-free.
- Add a new **`TtsEngine`** implementation (on-device) behind the same client interface; the client doesn’t change.
- Sequence: dictionary single-word first (instant, offline), then whole-sutta offline for power users.
- Manage the model download (~tens of MB) in-app; validate latency on older devices.

---

## 6. Decisions for the team to confirm

1. **Stage mapping** (§0) — confirm Stage 1 = live-only/no-cache, Stage 2 = cache + warm popular suttas, Stage 3 = on-device.
2. **Source script** of Pali in your BJT JSON — assumed **Sinhala script**; confirm (routes the romanizer).
3. **Paragraph numbers** — assumed **not voiced**; confirm.
4. **Sinhala romanizer (Stage 1.2)** — resolved: `@pnfo/singlish-search` `sinhalaToRomanConvert` (MIT, rule-based, Dart-portable). Remaining: a quality-gate listen on Sinhala output. Pali (Stage 1.1) uses `@pnfo/pali-converter`.
5. **Capitalization — resolved:** model charset is all-lowercase; lowercase both romanizers' output. Confirm the female voice (multi-v2.0) language coverage (Pali too, or Sinhala only) if you want a female Pali option.
6. **Transport** — Stage 1 starts with JSON + base64; move to binary + segments sidecar if/when payload size matters.

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
