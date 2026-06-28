# Serverless Deployment Decision — Where the Backends Live

> **Status:** decision *space mapped*, not yet locked. Recommended default
> identified; all branches are reversible via existing seams. **Captured:**
> 2026-06-28 (from a design conversation).
> **Companions:**
> [`wisdom-project-rag-qa-design.md`](./wisdom-project-rag-qa-design.md) (the
> `/ask` backend this started with),
> [`ai-qa-and-suttacentral-reference-resolver-plan.md`](./ai-qa-and-suttacentral-reference-resolver-plan.md)
> (Flutter integration), and
> [`reduce_mobile_bundle_size.md`](./reduce_mobile_bundle_size.md) (the
> content-DB / single-source plan that this decision leans on).

---

## 0. The one hinge

**The whole deployment topology turns on one question: where does the content
server's SQLite live, and how is it reached?** ("the SQLite's address"). Every
other choice — including whether the `ask` server stays serverless — follows
from that.

The **`ask` server never touches SQLite** (the RAG plan keeps "SQLite off the
ask path"), so its serverless-ness is *independent* — it is influenced only
*indirectly*, by whether the SQLite answer forces a box into existence.

---

## 1. The trail (how this question arose)

1. **"Make the `ask` server serverless so the server isn't my problem."** → It is
   already ~90% there: stateless, 12-factor env config, Cloud-Run-ready Dockerfile.
   A clean Cloud Run fit, $0 idle. *Settled: yes.*
2. **Cost mechanics** — `max-instances` is a cost ceiling (not a user cap);
   `concurrency` is per-instance (3 × 40 = 120 simultaneous); Firebase App Check is
   free (web reCAPTCHA has a free-then-paid tier); **Gemini File Search has no
   recurring fee** — one-time indexing (~$1–2) + per-query generation tokens;
   storage and query-embedding are free.
3. **Serverless vs a box** — for low-traffic + hands-free, serverless wins. Cold
   start is the only real downside, and it's a *latency* cost, not a fee (you pay
   the ~1–3s of boot compute, a fraction of a cent). Buyable off with
   `min-instances=1`.
4. **"But I'll need a box for the Dart content server anyway."** → The content
   server is *also* stateless, **but it hauls ~600 MB** (95 MB FTS + 167 MB dict +
   340 MB JSON text). **That weight is the pivot** — the first time a box looks
   justified.
5. **Bundle-size doc + "do we need SQLite?"** → Gemini File Search is **not** a
   content store (semantic retrieval for *answering*, paid per query, holds a
   *different* corpus — SuttaCentral English, not BJT). SQLite stays, but its job
   **narrows to the offline search/dictionary index** (offline *forces* a local
   index). Adopting the content-DB (`reduce_mobile_bundle_size.md`) drops the
   340 MB JSON → server payload ~halves to ~310 MB.
6. **"Cloud/online SQLite?"** → Yes (Turso / Cloudflare D1) — decouples data from
   compute so the function goes featherweight. Trade: every query becomes a
   network hop. This is where the hinge became explicit.

---

## 2. Two insights (validated & refined)

**"It all comes down to the SQLite's address."** ✅ Correct — *for the content
side*. The content server's deployment model is fully determined by where its
SQLite lives.

**"If we're compelled to go box, there's no point in serverless `ask` either."**
⚠️ Right in spirit, too absolute in letter:

- `ask` **never reads SQLite**, so the address doesn't *force* anything on it.
- A box doesn't make serverless-`ask` *pointless* — `ask` keeps $0-idle and
  **isolation** (a content outage/deploy can't take down Q&A). What flips is the
  **simplicity** argument: if a box already exists, folding the tiny `ask` server
  into it is one ops model instead of two, for ~zero extra resources.

**The true causal chain:**

> SQLite's address → content server's deployment (box vs serverless) → **if box**,
> `ask` gets *pulled toward* the box (a simplicity-vs-isolation call) → **else**
> `ask` stays its own serverless service.

---

## 3. The decision tree

```
START: "I don't want to run servers"
│
├─ ASK SERVER (Python /ask) ──────────────────────────────────
│    Stateless, tiny, never touches SQLite.
│    → Cloud Run, scale-to-zero, $0 idle.   ✅ settled
│    (Revisit only via ★ below, if a box appears.)
│
└─ CONTENT SERVER (Dart) ── the decision that drives everything
     │
     ▼  Q:  WHERE DOES THE SQLITE LIVE?  ("the address")
     │
     ├─ B1 ▸ Bundled in the container  → Cloud Run
     │       + adopt content-DB (~600MB → ~310MB)
     │       + min-instances=1 (warm, no cold start)
     │       Cost: ~few $/mo · no new vendor · local-fast reads
     │       → HANDS-FREE ✅   ◀── recommended default
     │
     ├─ B2 ▸ Cloud SQLite (Turso / D1)  → tiny function
     │       Function carries no data → true featherweight serverless
     │       Cost: per-query network hop · +1 vendor/free-tier
     │       → HANDS-FREE ✅   (cooler, more moving parts)
     │
     └─ B3 ▸ Box with local SQLite
             Fast local reads · no cold start
             Cost: YOU OWN A BOX (patch/uptime)
             → NOT hands-free ❌
             │
             └─ ★ Box exists anyway — fold ASK in too?
                   ├─ Yes → one ops model (simplest, ask rides free)
                   └─ No  → keep ask serverless (isolation/scale)
```

---

## 4. The branches in detail

### B1 — Bundle SQLite in the container (Cloud Run)
- **Pros:** one artifact, no new vendor, reads stay **local-fast** (in-process
  SQLite), no per-query latency.
- **Cons:** fat image → slower cold start; needs ~1 GB memory (SQLite mmaps the
  DBs). *Layer caching* means routine code deploys are light — only **content
  updates** re-ship the DB layer.
- **Mitigations:** adopt the content-DB (kills the 340 MB JSON, ~600 → ~310 MB) +
  `min-instances=1` (warm, no cold start) for a few $/mo.

### B2 — Cloud SQLite (Turso / Cloudflare D1)
- **What it is:** managed, always-on SQLite reached over HTTP. Both **run the
  query server-side and return rows**, so it's **one round-trip per query** (not
  one per index page) and **FTS5 still works**.
- **Free tiers (verify — they drift):** Turso ≈ 5 GB / 500M row-reads;
  D1 ≈ 5 GB / 25B reads. Your ~262 MB fits either with room to spare.
- **Pros:** the function carries no data → featherweight, truly scale-to-zero,
  fastest cold start. Can serve as one managed canonical store for web + the
  static-HTML generator (mobile gets a build-time snapshot).
- **Cons:** **inverts SQLite's superpower** — in-process µs reads become network
  hops (~tens of ms per query). Fine for search; a small regression for reads.
  Adds a vendor + a free-tier limit to track.

### B3 — Box with local SQLite
- **Pros:** local-disk SQLite is fast; no cold start; flat predictable cost; at
  *heavy steady* traffic, cheaper per request than per-invocation serverless.
- **Cons:** **you own the box** — patching, uptime, monitoring (the exact thing
  "hands-free" was trying to avoid); single point of failure; manual scaling.
- **★ If you land here:** fold `ask` in too (Caddy reverse-proxy: `/ask` → Python,
  rest → Dart). `ask` is tiny and rides for free — *unless* you specifically want
  its isolation/independent scale, then keep it serverless.

---

## 5. Constants (true on every branch — don't re-litigate)

- **Offline mobile is always bundled.** No cloud-SQLite/CDN idea touches it;
  offline is the hard anchor (`reduce_mobile_bundle_size.md` rejects server-fetch
  for mobile).
- **`ask` never reads SQLite.** Its serverless-ness is independent of the tree.
- **Escape hatches:** the **`/ask` contract** + the **local/remote datasource
  seam** (`getWebOverrides()`) make every branch swappable later — no lock-in.
  Start at the default, move branches cheaply if needed.
- **File Search ≠ content store.** It answers questions over its own corpus; it
  does not deliver BJT documents and is not part of this tree.

---

## 6. Cross-cutting controls (orthogonal — same on every branch)

These were part of the original ask and don't change which branch you pick:

- **Cost ceiling:** set `--max-instances` low (e.g. 3) — a hard bill cap.
- **Abuse / "money endpoint":** `max-instances` (now) → **Firebase App Check**
  (only-my-app, stronger than the existing static `X-App-Token`) → **per-IP
  throttle** (Upstash Redis + `slowapi`, keyed on `X-Forwarded-For`) →
  **Cloud Armor** only if real abuse justifies the Load-Balancer cost (~$18+/mo,
  the one thing that breaks $0).
- **Model switching:** a **fallback ladder** — try the configured model, on `429`
  fail over to the next; models are config/data (already are via `ASK_MODEL`).
  Rotating *models within one account* to use each free tier is fine; rotating
  *accounts/projects/keys* to multiply one quota is a ToS violation — don't.
- **Response transforms:** the backend is a single chokepoint — **answer caching**
  (biggest lever for a shared fixed corpus), server-side deeplink resolution,
  snippet trimming, later SSE streaming. All code-only, no infra change.

---

## 7. Recommended default

**`ask` → Cloud Run. Content → Cloud Run with the content-DB slimming +
`min-instances=1`. No box. ~a few $/month, hands-free.**

- Keep **B2 (Turso/D1)** in the back pocket as the clean upgrade if you later want
  the content function truly weightless — it's a swap behind the existing remote
  datasource seam.
- Go **B3 (box)** only if a box gives you something specific (heavy steady web
  traffic where flat cost wins, or you want local-disk SQLite speed), then fold
  `ask` in via ★.

---

## 8. Verify at build time (rates/limits drift)

- Gemini File Search indexing price, free-tier request limits, per-tier storage /
  file-count caps (design Appendix A still lists basket `metadata_filter` syntax
  and full-corpus caps as open).
- Cloud Run free-tier quotas and `min-instances=1` monthly cost.
- Turso / D1 free-tier limits (both restructured recently).
- Firebase App Check web (reCAPTCHA Enterprise) free allotment.
