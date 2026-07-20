# Serverless Deployment Decision — Where the Backends Live

> **Status:** decision *space mapped*, not yet locked. Recommended default
> identified; all branches are reversible via existing seams. **Captured:**
> 2026-06-28 (from a design conversation).
> **Companions:**
> [`wisdom-project-rag-qa-design.md`](./wisdom-project-rag-qa-design.md) (the
> `/ask` backend this started with),
> [`ai-qa-and-suttacentral-reference-resolver-plan.md`](./ai-qa-and-suttacentral-reference-resolver-plan.md)
> (Flutter integration), and
> [`reduce_mobile_bundle_size.md`](./retiring-dart-server/reduce_mobile_bundle_size.md) (the
> content-DB / single-source plan that this decision leans on).

> **UPDATE 2026-07-16 — the content-server hinge is dissolved; the B1/B2/B3 tree
> below is largely moot.** Follow-up study: **retire the content server.** All
> read-only canon data (content + FTS + dict) moves **client-side into SQLite via
> [Drift](https://pub.dev/packages/drift)** — native FFI on mobile/desktop, wasm +
> OPFS in the browser (Flutter web becomes fully static). The DBs ship as static
> files on the CDN, so "where does its SQLite live" no longer has a server answer.
> The **research (RAG) server stays** — the one backend, still scale-to-zero.
> Notes → **Firestore** (direct client). **Net: zero always-on infrastructure.**
> Content refreshes as monthly batched rebuilds. Details:
> [`reduce_mobile_bundle_size.md`](./retiring-dart-server/reduce_mobile_bundle_size.md).

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
   A clean Cloud Run fit, $0 idle. *Settled: yes.* The existing Dockerfile deploys
   to **Cloud Run as-is — no FastAPI rewrite**; wrapping it into *Cloud Functions
   for Firebase* buys nothing (2nd-gen Functions run **on** Cloud Run underneath,
   so cold-start is identical), and cold start (~1–3 s, softened by the lazy
   `google-genai` import) is minor next to the multi-second Gemini call.
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

### B3 · free-box variant — Oracle Always Free A1 (exploration notes, NOT decided)

> Captured 2026-07-08 from a design chat. A *concrete instantiation of B3* on a $0
> box — **not** a decision. B1 (Cloud Run) is still the recommended default (§7).
> Shape considered: **Ampere A1 (ARM64), 2 OCPU / 12 GB, Always Free.**

- **Resource fit — a non-event.** DBs ~262 MB on disk (95 MB FTS + 167 MB dict);
  SQLite reads pages via the OS cache, it does **not** load the DB into RAM →
  resident set stays low-hundreds-of-MB (~4% of 12 GB), 2 ARM cores idle on a
  read-only FTS/dict load. Could host content + research + Caddy and still leave
  ~11 GB free. **The constraint here is ops, never capacity.**
- **ARM64:** Dart, Python, `sqlite3` all fine on `linux-arm64`; images must be
  arm64 — the dev Mac is Apple Silicon (arm64) so local builds match natively.
  Host needs `libsqlite3` present (the Dart `sqlite3` pkg binds to it).
- **Fold-in (★):** one box → Caddy: `/research/*` → uvicorn (`research_server/`),
  rest → Dart. Research server rides free.

**Custom domain — yes, straightforward:**
- Reserve the instance's public IP (*Reserved*, not ephemeral, so DNS never breaks).
- `A` record → IP; **Caddy auto-provisions Let's Encrypt TLS** (no manual certbot).
- Two one-time footguns: open 80/443 in the **VCN security list** *and* the host's
  default **iptables** (Oracle Ubuntu images drop traffic locally even after the
  security list is opened — the classic "can't reach my server").
- ⚠️ Verify at build time: IPv4 may become billable (industry trend); Oracle
  Always Free still bundles it as of writing.

**Longevity — indefinite, but 3 real loss-modes (none a clock):**
- *Idle reclamation* — Oracle reclaims Always Free compute it reads as idle
  (7-day **95th-pct** CPU/net/mem all <20%). A health-check ping does **NOT** beat
  this — nor do a couple of daily users or a 30-min daily UI test; the percentile
  is built to ignore short bursts (would need >72 min/day sustained ≥20% CPU). The
  cheap real lever is **holding >2.4 GB resident memory** (anon heap / tmpfs / big
  SQLite `cache_size` — OS page cache does *not* count), else accept + auto-restart
  in an uncrowded region (a daily UI test is a good *canary* for that, not life-support).
- *A1 capacity slot* — stopping/terminating may forfeit the 2-OCPU/12-GB shape
  (free A1 is scarce → "Out of host capacity"). Don't tear down casually.
- *Account standing* — payment flags / dormant unverified accounts get reclaimed.
- **De-risk:** upgrade to **Pay-As-You-Go** — Always Free stays free but PAYG is
  **exempt from idle reclamation** and more stable; cost is a card on file + a
  budget alert. Recommended if the app relies on it.

**Update 2026-07-09 (verified online):**
- Free A1 was **quietly halved 4/24 → 2/12** (~15 Jun 2026; allotment now 1,500
  OCPU-hrs + 9,000 GB-hrs/mo). **PAYG reportedly still gets 4/24 free** (Oracle
  hasn't confirmed publicly).
- Rate $0.01/OCPU-hr + $0.0015/GB-hr → a 4/24 box 24×7 = **$0 inside the PAYG
  allotment**, ~**$55/mo** if fully metered; 2/12 24×7 just fits the free allotment ($0).
- **Fit:** the 3 services (Dart + Python + small TTS ≈ 1.3 GB) sit easily in 2/12
  — but no PAYG means no idle-immunity (see reclamation above). **Supabase +
  PowerSync self-host is ~14 containers, not 5 → don't; use their cloud free tiers.**

**TTS / audio / images — stay on R2, do NOT migrate onto the box.** Reinforces the
R2 call in
[`tipitaka-tts-implementation-plan.md`](./tipitaka-tts-implementation-plan.md); the
box existing makes this *stronger*, not weaker:
- Box = dynamic query APIs (small requests, in-process SQLite, ~zero bandwidth).
  Static media = a bandwidth+storage problem → R2's **zero egress** + edge cache
  beats routing large audio through one VM in one region. (A1's 10 TB/mo egress
  wouldn't fall over — R2 is simply the right tool.)
- **Keep the box disposable.** B3-on-free-A1's whole appeal is a cheap replaceable
  node; the moment it holds the only copy of the audio corpus, losing the instance
  (capacity loss above) becomes painful. R2 keeps state off the ephemeral thing.
- **Open call — the one live Pali-word TTS endpoint:** now that a box exists it
  *could* fold in behind Caddy (same ★). Depends what it is: thin proxy to an
  external TTS API → fold onto box; local synthesis model → single-word on 2 ARM
  cores is *probably* fine but benchmark first, else leave on Cloud Run.

Net layout under this variant:

| Thing | Where |
|---|---|
| Content API (Dart) | box |
| Research Q&A (Python) | box (behind Caddy) |
| Pre-rendered Sinhala audio + cached Pali words + images | **R2** |
| Live Pali-word TTS | box *or* Cloud Run (see open call) |

### B1 vs B3 · "Firebase vs the box" — the fork is *only* compute host

> Captured 2026-07-08, same chat. Framing note, not a decision.

**Firebase is a suite, not one rival host — most of it is orthogonal and used on
*either* branch:**

| Firebase piece | Role | Tied to where servers run? |
|---|---|---|
| **App Check** | abuse floor ("only my app") | ❌ verified via `firebase-admin` on *any* backend, box included (macOS plugin is flaky — §6) |
| **Auth** (silent anonymous) | UID for per-user quotas | ❌ token verification is compute-agnostic |
| **Firestore** | cloud notes | ❌ client → Firestore direct, no server at all |
| **Hosting** | Flutter web static + CDN | ❌ can serve web + reverse-proxy `/research` to either host |

So the App Check + Auth ladder (§6), Firestore notes, and R2 media are **shared
infra** in both worlds. The only thing that actually forks is **where the two
server processes run — free Oracle box (B3) vs Cloud Run (B1)**:

| Axis | Oracle A1 box (B3) | Cloud Run + Firebase (B1) |
|---|---|---|
| Monthly cost | genuinely **$0**, flat | $0 if scale-to-zero; ~few $/mo warm (`min-instances=1`); needs **Blaze** (card), metered |
| Ops | ❌ **you own the box** (patch/uptime/TLS/firewall) | ✅ fully managed — the "hands-free" goal |
| Cold start | ✅ none, always warm | ~1–3 s on scale-to-zero (buy off = money) |
| Content reads | ✅ in-process SQLite, µs | same, but pays cold-start on wake |
| Spikes | ❌ fixed 2 OCPU, single point of failure | ✅ auto-scales (capped by `max-instances`) |
| Surprise bill | ✅ **impossible** (fixed box → slow, not costly) | metered; `max-instances` is the cap |
| Longevity risk | idle-reclaim / capacity / account standing | as stable as GCP |

**Two things that dominate the read:**
- **Gemini generation tokens are the real cost, and they're identical on both
  hosts** — so the compute-host choice barely moves the dollar total. This is an
  **ops-burden + cold-start** decision, not a money one.
- The **"money endpoint" fear tilts slightly *toward* the box** — a fixed-cost box
  literally can't run up an infra bill (a flood makes it slow, not expensive). The
  App Check/Auth/quota ladder guards the Gemini spend either way.

**Not either/or → the likely real shape is a hybrid:** Firebase for
App Check / Auth / Firestore / Hosting (managed, free-tier, low-maintenance) +
compute wherever preferred. The box earns its place only if *ownership* appeals;
if it reads as a chore, Cloud Run is strictly less work for ≈ the same money — which
is why **B1 stays the §7 default**.

---

## 5. Constants (true on every branch — don't re-litigate)

- **Offline mobile is always bundled.** No cloud-SQLite/CDN idea touches it;
  offline is the hard anchor (`reduce_mobile_bundle_size.md` rejects server-fetch
  for mobile).
- **`ask` never reads SQLite.** Its serverless-ness is independent of the tree.
- **The research server is mandatory — there is no client-direct path.** Gemini
  File Search (the retrieval engine this feature rests on) is
  Gemini-Developer-API-only and needs a raw API key; Firebase's native client SDK
  (Firebase AI Logic / `firebase_ai`) does **not** expose File Search — only
  Google Search / Maps grounding. So you cannot move the RAG call into the app to
  delete the server, *even after adopting Firebase*. Adding **Firestore for notes
  is orthogonal** (client → Firestore direct, no server) and doesn't change this.
- **Escape hatches:** the **`/ask` contract** + the **local/remote datasource
  seam** (`getWebOverrides()`) make every branch swappable later — no lock-in.
  Start at the default, move branches cheaply if needed.
- **File Search ≠ content store.** It answers questions over its own corpus; it
  does not deliver BJT documents and is not part of this tree.
- **RAG retrieval store = Gemini File Search — decided 2026-07-03.** Compared vs
  **pgvector**, **Pinecone**, and **embedded indexes**. Wins on the project's "no
  recurring cost / no ops / no sponsors" constraints: indexing the whole
  ~3M-token corpus is **~$1 one-time**, then **$0 recurring** (storage +
  query-embedding free; you pay only Gemini *generation* tokens, which are
  unavoidable on every option). **Rejected:** *Pinecone* (free tier funnels to a
  **$50/mo** floor and pauses idle indexes) and *pgvector / managed Postgres*
  (rented free tier **plus** you own the retrieval pipeline and DB ops).
  **Named fallback if Google ever drops free storage:** an embedded
  `sqlite-vec` / LanceDB index bundled in the container or on R2 — same
  $0-recurring / zero-ops profile, rebuildable from `bilara-data` (git = source
  of truth) for ~$1. No true lock-in either way.

---

## 6. Cross-cutting controls (orthogonal — same on every branch)

These were part of the original ask and don't change which branch you pick:

- **Cost ceiling:** set `--max-instances` low (e.g. 3) — a hard bill cap.
- **Abuse / "money endpoint":** `X-App-Token` + `max-instances` (**live today** —
  a shared secret, extractable from the binary by anyone who cares) → **Firebase
  App Check** (only-my-app; the true floor — no user identity, protects the bill
  even for token-less requests; **not built**) → **Firebase Auth ID token**
  (verify with `firebase-admin`)
  keyed to a **silent anonymous UID by default**, unlocking best-effort
  **per-user daily quotas** in Firestore → **per-IP throttle** (Upstash Redis +
  `slowapi`, keyed on `X-Forwarded-For`) → **Cloud Armor** only if real abuse
  justifies the Load-Balancer cost (~$18+/mo, the one thing that breaks $0).
  - *How the App Check rung lands* (the "verified on any backend" claim above,
    made concrete): server — `app_check.verify_token()` from `firebase-admin` as
    a FastAPI dependency reading the `X-Firebase-AppCheck` header, 401 on
    failure; add `firebase-admin` to `research_server/requirements.txt`. IAM —
    the service account needs the **Firebase App Check Token Verifier** role
    (already granted if the Admin SDK is initialised with the Firebase console's
    service-account credentials). Client — `firebase_app_check` in
    `pubspec.yaml`, attach the token in `research_remote_datasource.dart`, which
    already sets `X-App-Token`.
  - *macOS is the weak platform — and it's our default run target.* Checked
    2026-07-16: macOS **is** supported on paper (App Attest macOS 14+,
    DeviceCheck ~12.5+), but the Flutter plugin is not — flutterfire#17057 (open
    since Feb 2025, `blocked: firebase-sdk`) throws AppAttest errors even when
    `AppleProvider.deviceCheck` is explicitly configured, with no clean fallback;
    #10934 / #13202 are the same bug. Use the **debug provider** for macOS dev,
    and never read a passing macOS build as evidence App Check works. The rung
    this doc calls "the true floor" is least trustworthy exactly where we test.
  - *OPEN — does App Check replace `X-App-Token`, or sit beside it?* The ladder
    implies replace. The macOS bug argues for keeping the shared secret as a
    fallback — but a fallback anyone can extract **is** the floor, which cancels
    the upgrade. Decide deliberately; don't let it default.
  - *Quotas cover every sign-in method, but never require a login.* App Check
    needs no identity; anonymous auth mints a real UID + verifiable ID token
    **silently** (no login screen). So a user who keeps notes local (e.g. an
    Excel sheet) is still rate-limited without ever signing in — **rate limiting
    must never depend on the user having chosen cloud notes.** Google/Apple
    sign-in is **opt-in, only for cloud note sync**; `linkWithCredential` later
    upgrades the same anonymous UID in place (history preserved).
  - *Anonymous is the weak rung:* its UID is cheap to re-mint (sign in again /
    reinstall resets the counter), so give anonymous a **lower cap** and lean on
    **App Check** as the real floor; stable Google/Apple UIDs are where per-user
    limits actually bite.
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
- Cloud Run free-tier quotas and `min-instances=1` monthly cost. Note the free
  tier is **2M invocations per _month_** (not per day); the real cost ceiling is
  **Gemini generation tokens**, not free invocations.
- Artifact Registry: both images fit the **0.5 GB free tier _compressed_**
  (measured ~315 MB total; 751 MB raw assets → ~140 MB gzipped — AR bills
  compressed layers, not the uncompressed size `docker images` shows). Add a
  keep-last-N cleanup policy so old versions don't accumulate.
- Turso / D1 free-tier limits (both restructured recently).
- Firebase App Check web (reCAPTCHA Enterprise) free allotment.
- Firebase Auth free (Spark) plan ceiling: **3,000 daily active users** (anonymous
  counts as Tier-1). Not a token cap — anonymous accounts cap at 100M, creation is
  throttled 100/hr/IP (free anti-abuse on re-minting). Past 3,000 DAU → Blaze
  (50k MAU free). Firestore for notes has its own Spark daily caps (~50k reads /
  20k writes per day, 1 GiB).
