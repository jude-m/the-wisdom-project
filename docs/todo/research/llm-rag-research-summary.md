# LLM Selection for Multilingual RAG — Research Summary

_Prepared as a basis for further research. Date: 30 June 2026._
_Benchmark source: Artificial Analysis (Intelligence Index v4.1). Pricing & free-tier details from provider docs (Google AI for Developers, DeepSeek API docs, OpenRouter)._

---

## 1. The Goal

Find a model to power a **Retrieval-Augmented Generation (RAG)** system that answers questions strictly from provided **English** source documents. Priorities, in order:

- **Cost is the main driver.**
- **Hosted / managed cloud API only** (no self-hosting), with clear API docs and a **generous free tier**.
- **"Mid" intelligence is sufficient** — deep reasoning NOT needed (non-reasoning / low-effort mode preferred).
- Behave like an **excellent search/extraction tool**: faithful to sources, no added outside knowledge.
- **Small context window is acceptable.**
- **Multilingual:** must handle queries/answers in low-resource languages such as **Sinhala**, while sources stay in English.

---

## 2. Context — What GPT-5.4 Is and How It Compares (frontier tier)

The original chat investigated (Gotama) runs on `openai/gpt-5.4` via OpenRouter (OpenAI provider). GPT-5.4 is a frontier general-purpose reasoning model: ~1M context, $2.50 in / $15.00 out per 1M tokens, Intelligence Index 51. It sits in the **Pro/frontier band**, NOT the cheap Flash band.

### Frontier / Pro-band reference
| Model | Intelligence | Input $/1M | Output $/1M | Speed |
|---|---|---|---|---|
| GPT-5.4 (xhigh) | 51 | $2.50 | $15.00 | 158 t/s |
| Gemini 3.5 Flash (high) | 50 | $1.50 | $9.00 | 175 t/s |
| Gemini 3.1 Pro | 46 | $2.00 | $12.00 | 137 t/s |
| Qwen3.7 Max | 46 | $2.50 | $7.50 | 197 t/s |

### Open-weight / value tier
| Model | Intelligence | Input $/1M | Output $/1M |
|---|---|---|---|
| DeepSeek V4 Pro (reasoning) | 44 | $0.435 | $0.87 |
| MiniMax-M3 | 44 | $0.30 | $1.20 |
| gpt-oss-120b (high) | 24 | $0.15 | $0.60 |

**Takeaway:** Open-weight models (DeepSeek, MiniMax) reach ~85% of frontier intelligence at a fraction of the cost. gpt-oss-120b is an economy/speed model (~306 t/s), not frontier.

---

## 3. The Relevant Shortlist — Cheap, NON-REASONING Models for RAG

| Model | Intelligence | Input $/1M | Output $/1M | Speed | Notes |
|---|---|---|---|---|---|
| Gemini 3.5 Flash (minimal) | 35 | $1.50 | $9.00 | 159 t/s | Smartest non-reasoning; priciest input |
| Qwen3.5 397B (non-reasoning) | 32 | ~$0.20–0.40* | ~$0.40–0.80* | 52 t/s | Open-weight; price varies by host; slow |
| DeepSeek V4 Flash (non-reasoning) | 29 | $0.14 | $0.28 | 114 t/s | Cheapest; best cost-per-intelligence |
| Gemini 3 Flash (non-reasoning) | 27 | $0.50 | $3.00 | 180 t/s | Google "search & grounding" model |
| Gemini 3.1 Flash-Lite | 25 | $0.25 | $1.50 | 327 t/s | Cheapest hosted Gemini; very fast |
| GPT-5.4 mini (non-reasoning) | 17 | $0.75 | $4.50 | 168 t/s | Poor value with reasoning off — avoid |

\* Open-weight pricing depends on the host; verify before relying on it.

> **RAG cost note:** You pay mostly for **input** (large retrieved context) + cache hits, with short outputs. Input price and prompt-caching discounts matter more than output price.

---

## 4. Recommendation

**Primary pick: Google Gemini Flash-Lite** (start with 2.5 / 3.1 Flash-Lite), with **Gemini 3 Flash** as the step-up.

Why it fits the brief best:

- **Free tier:** Gemini Flash / Flash-Lite are "free of charge" up to rate limits via Google AI Studio (no card to start; daily reset). Best genuine free tier among candidates.
- **Hosting & docs:** Fully hosted; ai.google.dev docs are clear with copy-paste quickstarts and an AI Studio playground.
- **Multilingual / Sinhala (decisive factor):** Google has the broadest low-resource-language coverage; Sinhala is supported. Cheap open-weight rivals (DeepSeek Flash, smaller Qwen/MiniMax) are strong in EN/ZH but weaker on Sinhala.
- **RAG faithfulness:** Gemini 3 Flash is described by Google as built for "superior search and grounding" — exactly the extract-and-answer behavior wanted.
- **No reasoning needed:** Flash models support a "thinking budget" you can set to **0** for fast, cheap, non-reasoning answers.
- **Smartness:** Flash-Lite ~25, Gemini 3 Flash ~27 — solidly mid-tier, sufficient for retrieve-and-answer.

**Fallback (English-only, ultra-cheap, high volume): DeepSeek V4 Flash** in non-thinking mode ($0.14 / $0.28). OpenAI/Anthropic-compatible API (`base_url: https://api.deepseek.com`; `model: deepseek-v4-flash`; thinking disabled). Pay-as-you-go (no real free tier) but cheapest per token. Weaker on Sinhala.

**Suggested architecture:** two-tier routing — cheap default model for the easy ~80% of queries, step up to Gemini 3 Flash for harder / multilingual queries.

---

## 5. Caveats / Open Questions

- **Sinhala quality is not benchmarked publicly.** Confidence is HIGH on support, MEDIUM on exact quality. Validate before committing.
- Artificial Analysis does **not** test RAG-faithfulness or Sinhala; per-eval scores (AA-LCR long-context, AA-Omniscience non-hallucination, IFBench instruction-following) render in interactive charts and were not extracted numerically. The Intelligence Index is a general composite.
- Model lineups move fast (GPT-5.5 and newer Gemini variants already exist). Re-check current models / prices / free-tier limits before building.
- Open-weight prices vary by host — confirm with the provider you actually use.

---

## 6. Suggested Next Research Steps

1. Build a 20–30 question **Sinhala eval set** against representative English source docs; test Flash-Lite vs Gemini 3 Flash vs DeepSeek V4 Flash for answer correctness, faithfulness (no hallucinated facts), and Sinhala fluency.
2. Pull exact **Gemini free-tier limits** (RPM / TPM / RPD) for Flash-Lite to size throughput.
3. Pull **RAG-specific sub-benchmarks** (long-context accuracy, non-hallucination rate, instruction-following) for the shortlist.
4. Test a strict **system prompt** ("answer only from the provided sources; if not present, say you don't know") to enforce search-tool behavior.
5. Confirm **prompt-caching** pricing/behavior for the chosen model, since RAG context often repeats.
