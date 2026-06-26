# AI Q&A Integration & SuttaCentral Reference Resolver — Design & Plan

> **Status:** Design / plan — not yet started.
> **Captured:** 2026-06-27.
> **Companion to** [`wisdom-project-rag-qa-design.md`](./wisdom-project-rag-qa-design.md)
> (the upstream NotebookLM-style RAG design). That doc decides *what* the AI
> Q&A feature is and how the **backend/ingest** work; **this** doc decides how
> it lands **inside the Flutter app** under our clean architecture, plus a
> cross-edition reference resolver that the same work unlocks.
> **Related:** [`deep-linking-and-shareable-urls.md`](./deep-linking-and-shareable-urls.md)
> (the `go_router` URL scheme RAG deep-links resolve into) and
> [`mahamevnawa-link-mapping.md`](./mahamevnawa-link-mapping.md) (the proven
> cross-edition concordance pattern the resolver mirrors).

---

## 0. TL;DR

Three deliverables that share **one new core component**:

1. **AI Q&A feature** — a button → dialog → chat box that calls a stateless
   `/ask` backend and shows a grounded answer + citation snippets. Clean
   architecture, remote-only, **stub-first** so the UI works before any backend
   exists. *"Make it work first."*
2. **SuttaCentral ↔ BJT reference resolver** — the **shared core**. A pure-Dart
   resolver (in `wisdom_shared`) + a build-time concordance asset that maps a
   SuttaCentral uid (`sn15.3`) to our BJT tree node (`sn-2-4-3`). Sibling of the
   existing `tools/mahamevnawa_map/`.
3. **Two consumers of the resolver:**
   - **Search by canonical reference** *(new, independently valuable)* — type
     `SN 15.3` in the search box → jump straight to the sutta. Doesn't work today.
   - **RAG citation deep-links** *(next phase)* — tap a citation → open the text
     in-app, via the `go_router` scheme already planned in the deep-linking doc.

The Q&A prototype needs **none** of the resolver, so it ships first. The
resolver then unlocks reference-search and deep-links, in that order.

```
                         ┌─────────────────────────────┐
                         │  SuttaCentral ↔ BJT resolver │  ← shared core (Part B)
                         │  parseRef() + resolve()      │
                         │  + sc-to-bjt.json (asset)    │
                         └───────────┬─────────┬────────┘
                                     │         │
                  ┌──────────────────┘         └──────────────────┐
                  ▼                                               ▼
      ┌───────────────────────┐                     ┌──────────────────────────┐
      │ Search by reference   │ (Part C, new)       │ RAG citation deep-links  │ (Part D, next phase)
      │ "SN 15.3" → open sutta│                     │ tap citation → /sutta/…  │
      └───────────────────────┘                     └──────────────────────────┘

      ┌──────────────────────────────────────────────────────────────────────┐
      │ AI Q&A feature (Part A) — ships FIRST, stub-first, no resolver needed  │
      └──────────────────────────────────────────────────────────────────────┘
```

---

## 1. The one insight that shapes the architecture

Every existing feature (FTS, dictionary, documents) has **two real datasource
implementations**: a *local* one (bundled SQLite/JSON on native) and a *remote*
one (HTTP to our Dart `server/`, injected only on web via `getWebOverrides()` in
`lib/presentation/providers/platform_providers.dart`). Same data, different
transport.

**RAG breaks that symmetry.** No client can ever call Gemini directly (the API
key must stay server-side) and the File Search index lives in Google's cloud.
So:

- The Q&A feature is **remote-only on _every_ platform** — native, desktop, web
  all hit a backend. There is no `AskLocalDataSource`. This *simplifies* the
  clean-architecture mapping (no platform override), but introduces one wiring
  difference: **native currently never talks to a server**, so the Q&A
  datasource needs a **configurable absolute base URL** (e.g.
  `https://ask.thewisdomproject.app`), not the same-origin `''` trick the
  content server uses on web.
- Because of this, the feature **cannot work offline** — unlike everything else
  in the app. It must degrade gracefully (a clear "needs connection" state) and
  be hideable behind a capability flag when no backend is configured.

---

## 2. Backend decision (settled): separate **Python** service

The companion design doc left the backend framework open (§5.7, §14). One fact
settles it for us:

- **Gemini File Search — the managed RAG store + `grounding_metadata` this whole
  design rests on — is _not_ exposed in any Dart SDK.** It is first-class in
  **Python and JavaScript** only. Dart is explicitly blocked; tracked at
  [googleapis/google-cloud-dart #94](https://github.com/googleapis/google-cloud-dart/issues/94).
  It *is* reachable from Dart via raw REST, but then we hand-roll upload, tool
  config, and grounding parsing — losing the "fully managed" benefit that
  justified the stack. ([File Search docs](https://ai.google.dev/gemini-api/docs/file-search),
  GA since Nov 2025.)

**Verdict:** the `/ask` service is a **separate Python `google-genai`
deployable** (FastAPI on Cloud Run, or one Cloud Function — implementer's call).
Our Dart `server/` stays as-is (web content proxy). The Flutter app binds only
to the `/ask` JSON contract (§7 of the design doc) and **does not care** what
language the backend is in — that is the reversibility anchor; protect it.

---

## Part A — Clean-architecture integration of the Q&A feature

Slots into existing conventions almost mechanically. Mirrors the `search` /
`dictionary` feature layout.

### A.1 File tree

```
lib/domain/
  entities/ask/
    ask_answer.dart        # Freezed: answer, lang, List<Citation>
    citation.dart          # Freezed: uid, ref, kind, snippet, deeplink
    chat_message.dart      # Freezed: role (user|assistant), content
    ask_filters.dart       # Freezed: basket? (optional scope)
  repositories/
    ask_repository.dart    # abstract → Future<Either<Failure, AskAnswer>> ask(...)

lib/data/
  datasources/
    ask_datasource.dart            # abstract interface (mockable / swappable)
    ask_remote_datasource.dart     # the ONLY real impl: http POST /ask
    ask_stub_datasource.dart       # fake impl: returns a canned AskAnswer (Phase 1)
  models/
    ask_response_model.dart        # fromJson/toJson for the §7 wire contract
  repositories/
    ask_repository_impl.dart       # wraps datasource in try/catch → Either

lib/presentation/
  providers/ask_provider.dart      # baseUrl → datasource → repository → AskChatNotifier
  widgets/ask/                      # button + dialog + chat box (kept minimal)
```

### A.2 The `/ask` contract → entities (1:1)

The §7 contract maps directly onto Freezed entities. Keep their shapes aligned
with the contract — that is what keeps the backend swappable.

```dart
// lib/domain/entities/ask/citation.dart
@freezed
class Citation with _$Citation {
  const factory Citation({
    required String uid,        // "sn15.3" | "pli-tv-bu-vb-np18"
    required String ref,        // "SN 15.3" (display form)
    required String kind,       // "canon" now; "note" reserved (design §5.2)
    String? snippet,            // English source span (the verification preview)
    String? deeplink,           // resolved later by Part D; null in the prototype
  }) = _Citation;

  factory Citation.fromJson(Map<String, dynamic> j) => _$CitationFromJson(j);
}

// lib/domain/entities/ask/ask_answer.dart
@freezed
class AskAnswer with _$AskAnswer {
  const factory AskAnswer({
    required String answer,
    required String lang,             // "si" | "en"
    @Default([]) List<Citation> citations,
  }) = _AskAnswer;

  factory AskAnswer.fromJson(Map<String, dynamic> j) => _$AskAnswerFromJson(j);
}
```

> **Cheap insurance (from design §7):** keep the `kind` field even though it is
> always `"canon"` in the prototype, and keep `deeplink` nullable. Then adding
> Sujato notes (`kind=note`) or turning on deep-links is *no contract change and
> no app release*.

### A.3 Datasource — mirrors `FTSRemoteDataSourceImpl`

Same `http.Client` + base-URL + `_checkResponse` shape as
`lib/data/datasources/fts_remote_datasource.dart`; only difference is a `POST`
with a JSON body instead of a `GET` with query params.

```dart
abstract class AskDataSource {
  Future<AskAnswer> ask(
    String question, {
    List<ChatMessage> history = const [],
    AskFilters? filters,
  });
}

class AskRemoteDataSourceImpl implements AskDataSource {
  final http.Client _client;
  final String _baseUrl;
  AskRemoteDataSourceImpl({required String baseUrl, http.Client? client})
      : _baseUrl = baseUrl, _client = client ?? http.Client();

  @override
  Future<AskAnswer> ask(String question,
      {List<ChatMessage> history = const [], AskFilters? filters}) async {
    final res = await _client.post(
      Uri.parse('$_baseUrl/ask'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'question': question,
        'history': history.map((m) => m.toJson()).toList(), // empty in prototype
        if (filters != null) 'filters': filters.toJson(),
      }),
    );
    if (res.statusCode != 200) {
      throw Exception('ask failed (${res.statusCode}): ${res.body}');
    }
    return AskAnswer.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }
}
```

### A.4 Repository — `Either<Failure, AskAnswer>`

Reuses the existing `Failure` variants (`lib/domain/entities/failure.dart`).
Network/timeout → `dataLoadFailure`; anything else → `unexpectedFailure`.

```dart
class AskRepositoryImpl implements AskRepository {
  final AskDataSource _ds;
  AskRepositoryImpl(this._ds);

  @override
  Future<Either<Failure, AskAnswer>> ask(String question,
      {List<ChatMessage> history = const [], AskFilters? filters}) async {
    try {
      return Right(await _ds.ask(question, history: history, filters: filters));
    } on SocketException catch (e) {
      return Left(Failure.dataLoadFailure(
          message: 'No connection to the answer service', error: e));
    } catch (e) {
      return Left(Failure.unexpectedFailure(message: 'Ask failed', error: e));
    }
  }
}
```

### A.5 Providers — same `datasource → repository → notifier` chain as `search_provider.dart`

```dart
/// Config: where the /ask backend lives. Override per environment.
final askBaseUrlProvider = Provider<String>((_) => kAskBackendBaseUrl);

/// Phase 1 wires the stub; Phase 4 swaps this ONE line to the remote impl.
final askDataSourceProvider = Provider<AskDataSource>((ref) {
  // return AskStubDataSourceImpl();
  return AskRemoteDataSourceImpl(baseUrl: ref.watch(askBaseUrlProvider));
});

final askRepositoryProvider = Provider<AskRepository>((ref) {
  return AskRepositoryImpl(ref.watch(askDataSourceProvider));
});

/// Chat state: messages + isLoading + error. isLoading disables the send
/// button (a real cost guardrail — see §Cross-cutting).
final askChatProvider =
    StateNotifierProvider<AskChatNotifier, AskChatState>((ref) {
  return AskChatNotifier(ref.watch(askRepositoryProvider));
});
```

### A.6 UI (kept deliberately minimal, per request)

A single entry-point button (e.g. in the app bar / a FAB) opens a dialog hosting
a `ListView` of `ChatMessage`s + a `TextField` + send button. The notifier's
`isLoading` shows a "thinking…" row and disables send. All user-facing strings
(`title`, hint, "thinking…", error text) go through the existing ARB
localization (`lib/core/localization/l10n/app_en.arb`, `app_si.arb`) — no
hard-coded strings. **No streaming, no threads, no citation links in v1** — the
contract already supports adding all three later with no entity change.

---

## Part B — The shared core: SuttaCentral ↔ BJT reference resolver

### B.1 The problem (and the evidence)

A SuttaCentral uid is **flat**: `sn15.3` = saṁyutta 15 (Anamatagga), sutta 3,
where saṁyuttas are numbered 1–56 continuously. Our BJT tree is **nested**:
`assets/data/file-map.json` keys SN as `sn-1 … sn-5` — the **five vaggas**
(Sagāthā, Nidāna, Khandha, Saḷāyatana, Mahā) — with saṁyuttas nested underneath
(`sn-2-4-…`). Anamatagga is the 4th saṁyutta of the Nidānavagga, so:

```
sn15.3   →   sn-2-4-3        (NOT sn-15-3)
```

This is the same flat-vs-nested gap the `mahamevnawa-link-mapping.md` tool
already solves between BJT and Mahamevnawa. So this is **not a regex** — it needs
a **concordance**, built once, shipped as data.

### B.2 Where it lives (mirrors the proven pattern)

| Piece | Location | Mirrors |
|---|---|---|
| Build-time map generator (Python) | `tools/suttacentral_map/build_map.py` | `tools/mahamevnawa_map/build_map.py` |
| Committed concordance asset | `tools/suttacentral_map/sc-to-bjt.json` → shipped as `assets/data/` | `bjt-to-mahamevnawa.json` |
| Pure-Dart runtime resolver | `packages/wisdom_shared/lib/src/refs/` | existing `wisdom_shared` parsers |

Putting the resolver in **`wisdom_shared`** (not in a RAG-private helper) is
deliberate: it is consumed by **both** the Flutter client (search + deep-links)
and could later serve the Python backend's linkifier or the planned static HTML
site — it is shared canon-addressing logic, exactly what `wisdom_shared` is for.

### B.3 The runtime API (two clean steps)

```dart
// packages/wisdom_shared/lib/src/refs/suttacentral_ref_resolver.dart

/// Step 1 — parse a human/uid string into a canonical SuttaCentral uid.
/// "SN 15.3" | "sn 15.3" | "SN15.3" | "sn15.3"  →  "sn15.3"
/// Returns null if it doesn't look like a canonical reference at all.
String? parseRef(String input);

/// Step 2 — resolve a uid to our BJT tree node key via the concordance.
/// "sn15.3"  →  "sn-2-4-3"   (null if not in the map)
String? resolveToNodeKey(String uid);
```

- **`parseRef`** is pure and free (a small regex over the known nikāya/book
  abbreviations — the same set the design doc's linkifier uses:
  `SN MN DN AN KN Snp Dhp Ud Iti Thag Thig …`, plus Vinaya `pli-tv-*`).
- **`resolveToNodeKey`** is an O(1) lookup into the loaded concordance map.
- The map is **bidirectional/injective** (like the Mahamevnawa map), so the
  reverse (`bjtNodeKey → scUid`) is available for "this page is **SN 15.3**"
  labels and for the backend to know what to cite.

### B.4 Building the concordance (`tools/suttacentral_map/`)

Reuse the Mahamevnawa playbook: **propose by canonical position, confirm by an
independent signal.** SuttaCentral's uids *are* the canonical reference system,
and both editions enumerate the same canon in the same order, so:

1. Walk our `assets/data/tree.json` and SuttaCentral's structure together
   (nikāya → saṁyutta/vagga → sutta), aligning by position within each
   already-matched parent.
2. Confirm against a cross-reference signal (SC publishes BJT alignment; the
   local `tipitaka.lk` project and `bilara-data` segment ids are also available)
   and **drop** any pair the signal contradicts — exactly how the Mahamevnawa
   build rejects *peyyāla* drift.
3. Emit `sc-to-bjt.json` + an `unmatched.txt` grouped by reason, for review.

> Detailed build rules are deferred to when the tool is written; the point here
> is that the **architecture is settled** (build-time Python → committed JSON →
> pure-Dart lookup) and **proven** by the sibling tool.

### B.5 Slots this fills that already exist

- **`Entry.segmentId`** (`lib/domain/entities/content/entry.dart:24`) is already
  documented as cross-edition and shaped to hold SuttaCentral ids like
  `dn1:1.1`. The resolver feeds this slot — we are filling a reserved field, not
  inventing one.
- **`ReaderTab.textId`** (edition-agnostic, e.g. `dn1`, `mn100`, `sn1-1`; see
  the deep-linking doc) is the routing identity the resolver's node key maps to
  for Part D.

---

## Part C — Consumer 1: search by canonical reference (new feature)

**The gap:** typing `SN 15.3` in the search box returns nothing useful today —
it goes through FTS as literal text. (Confirmed: no canonical-ref parsing exists
in `lib/` search code.) Users expect a **direct jump**.

**Why it's easy now:** `SearchResult`
(`lib/domain/entities/search/search_result.dart`) already carries a `nodeKey`
navigation target, and navigation already knows how to open a `nodeKey`. So a
reference hit is just *another `SearchResult`* the existing UI can render and
route.

**Integration (thin, additive):**

1. Add `SearchResultType.reference` to the enum
   (`lib/domain/entities/search/search_result_type.dart`) — the enum already
   anticipates growth (`definition` is marked "future feature").
2. In the search flow (`SearchStateNotifier` / `searchTopResults`), **before**
   firing FTS: `final uid = parseRef(query); if (uid != null) { final node =
   resolveToNodeKey(uid); … }`. On a hit, prepend a single high-priority
   `SearchResult(resultType: reference, nodeKey: node, title: "SN 15.3", …)`.
3. Normal FTS still runs underneath, so a literal-text match isn't lost.

This is **independent of RAG** and shippable on its own the moment Part B lands.
It also generalizes for free: the same `parseRef` accepts the display forms the
RAG answers contain, so reference-search and citation-linking stay consistent.

---

## Part D — Consumer 2: RAG citation deep-links (next phase)

Deferred per the "make it work first" decision; specified here so Part A's
entities are shaped correctly now.

- `deeplinkFor(uid)` = `resolveToNodeKey(uid)` → the app's `textId` → a
  `go_router` route **`/sutta/<textId>`**, exactly the scheme the
  [`deep-linking-and-shareable-urls.md`](./deep-linking-and-shareable-urls.md)
  plan introduces. RAG must **not** invent its own URI scheme — it resolves into
  that one, so a tapped citation behaves identically to a shared link.
- **Granularity:** v1 is **sutta-level** (open the file/page for SN 15.3).
  Segment-level (`sn15.3:1.4` → the exact BJT paragraph) is genuinely hard —
  BJT paragraphs ≠ SC segments and our BJT entries aren't SC-segment-tagged yet
  — and stays the design doc's deferred **v2**.
- **Edition caveat to surface in UI later:** the citation snippet is Sujato's
  **English**; the page we open is **BJT Sinhala/Pali**. The reference is the
  same; the wording differs. Acceptable (design §11.3 positions Sinhala answers
  as a study aid), worth a small "source: SuttaCentral English" note.

---

## SQLite strategy — keep it off the ask path entirely

The headline: **in v1 the RAG feature should touch local SQLite essentially
never**, and the resolver should add **zero** runtime DB load.

- **The answer** is 100% from the backend. The ask path does **no** local DB
  read. Protect that — it is the leanest possible footprint.
- **Chat history** is small and ephemeral. Follow the existing pattern —
  `RecentSearchesRepositoryImpl` stores history in **`shared_preferences`** as
  JSON, not SQLite. For the prototype, in-memory (the notifier) is enough.
  **Never** write chat into `bjt-fts.db` / `dict.db`: those are **read-only
  bundled assets** that get rebuilt and replaced on content updates — any user
  data inside them is silently destroyed, and there's no reason to open them
  read-write.
- **The resolver concordance** is a **committed JSON asset** loaded once into an
  in-memory map — the same idiom as `file-map.json` and `bjt-to-mahamevnawa.json`
  — **not** a SQLite table, and **not** a new column inside the FTS/dict DBs
  (which would couple the content pipeline to a cross-edition concern). Map at
  the saṁyutta/vagga level and resolve the sutta leaf positionally underneath, so
  the asset stays a few KB.
- **The FTS4 hybrid** (design §5.6 — merge File Search with our FTS index for
  exact proper nouns) is **deferred to v1.1**, and when it lands it must
  **reuse the existing `FTSDataSource` / `CachingTextSearchRepository`** rather
  than open a second connection to the same file. We already have documented
  *shared-DB contention* flakiness in the integration suite; one connection pool
  and one cache, not two.

Net: chat → `shared_preferences`; resolver → in-memory JSON map; hybrid (later)
→ reuse the existing FTS path. The asset DBs stay read-only and untouched.

---

## Cross-cutting considerations

1. **Graceful offline / capability gate.** Unlike every other feature, Q&A
   can't work offline. Map network failure to a clear `Failure`; the dialog says
   "needs a connection" rather than spinning. A flag hides the entry-point button
   when no backend is configured.
2. **`/ask` is a money endpoint.** The backend protects the key, but a public
   unauthenticated `/ask` lets anyone spend our Gemini quota. Add basic
   rate-limiting / an app token before it's public (local dev is fine without).
3. **Client-side cost guardrail.** Disable the send button while a request is
   in-flight (`isLoading`) so impatient tapping doesn't burn the ~1,500/day free
   tier.
4. **Streaming is a free upgrade later.** Single request/response is fine for
   v1; switching to SSE token streaming needs **no entity change** — the notifier
   just appends deltas.
5. **i18n.** All dialog strings through ARB, per `CLAUDE.md`.
6. **Tests.** Per `CLAUDE.md`, none are written unless requested. Natural seams
   when wanted: the datasource (HTTP→model), the repository (exception→`Either`),
   and — highest value — `parseRef` / `resolveToNodeKey` (pure functions, easy
   to table-test, and the resolver is correctness-critical for both consumers).
7. **Bonus synergy.** Because `/ask` is just an HTTP contract and the resolver
   lives in `wisdom_shared`, both can later serve the planned static HTML site
   with no Flutter involved.

---

## Build order (each step ships value independently)

1. **Q&A stub vertical** — entities → `AskDataSource` interface →
   `AskStubDataSourceImpl` (canned answer) → repository → provider → button +
   dialog. **Working chat UI today, zero backend.** *(Part A)*
2. **Python `/ask` backend + ingest** — per the companion design doc (both
   trees → File Search store; `/ask` = detect → rewrite → generation →
   citations). *(separate deployable)*
3. **Swap stub → remote** — one line in `askDataSourceProvider`. The swap *is*
   the proof the architecture is right. *(Part A complete)*
4. **Resolver core** — `tools/suttacentral_map/` build → `sc-to-bjt.json` →
   `parseRef` / `resolveToNodeKey` in `wisdom_shared`. *(Part B)*
5. **Search by reference** — `SearchResultType.reference` + the pre-FTS check.
   *(Part C — ships independently of RAG)*
6. **RAG deep-links** — `deeplinkFor` → `go_router /sutta/<textId>` (depends on
   the deep-linking doc's `go_router` migration). *(Part D)*
7. **v1.1** — FTS4 hybrid (reusing the existing FTS path), metadata `filters`,
   multi-turn follow-ups; **v2** — segment-level deep-links.

---

## Open decisions

- **Q&A entry point location** — app bar action vs FAB vs nav drawer item.
- **Backend host** — Cloud Run (FastAPI) vs single Cloud Function. (Doesn't touch
  the app.)
- **Backend base URL config** — compile-time `--dart-define` vs a config file vs
  a remote-config lookup. Native needs an absolute URL.
- **`SearchResultType.reference` vs reuse `title`** — new value is clearer;
  confirm it doesn't disturb the tab/badge UI.
- **Resolver output identity** — node key (`sn-2-4-3`) for search vs `textId`
  (`sn1-1`) for routing; confirm the existing nodeKey↔textId mapping covers both
  consumers or add a thin adapter.
- **Concordance coverage policy** — what to do for uids with no clean BJT target
  (the Mahamevnawa build shows ~bundled/peyyāla regions will exist): drop, or
  resolve to the nearest containing node?

---

## Appendix — key files this plan touches or mirrors

| Concern | Existing file (pattern to follow) |
|---|---|
| Remote datasource shape | `lib/data/datasources/fts_remote_datasource.dart` |
| Platform overrides | `lib/presentation/providers/platform_providers.dart` |
| Provider chain | `lib/presentation/providers/search_provider.dart` |
| `Either`/`Failure` | `lib/domain/entities/failure.dart` |
| Client-side history (shared_prefs, not SQLite) | `lib/data/repositories/recent_searches_repository_impl.dart` |
| Cross-edition concordance (proven) | `tools/mahamevnawa_map/build_map.py`, `docs/todo/mahamevnawa-link-mapping.md` |
| Cross-edition alignment slot | `lib/domain/entities/content/entry.dart` (`segmentId`) |
| Search result → navigation | `lib/domain/entities/search/search_result.dart` (`nodeKey`) |
| Routing target for deep-links | `docs/todo/deep-linking-and-shareable-urls.md` (`/sutta/<textId>`) |
| Shared client/server logic home | `packages/wisdom_shared/` |
