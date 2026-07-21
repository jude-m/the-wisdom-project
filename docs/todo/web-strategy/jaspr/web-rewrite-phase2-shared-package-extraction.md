# Web Rewrite — Phase 2: Shared Package Extraction

> Status: **Plan** — no code changed.
> Captured: 2026-06-10.
> Companion to: [`web-rewrite-clean-architecture-audit.md`](./web-rewrite-clean-architecture-audit.md) (§4 Phase 2A),
> [`jaspr-web-client-migration.md`](./jaspr-web-client-migration.md) ("Backbone"),
> [`jaspr-prototype-findings.md`](./jaspr-prototype-findings.md).
>
> Precondition: the Jaspr prototype is proven (done 2026-06-10) and the
> framework call is **Jaspr**. This work is *only* worth doing on the Jaspr
> path — for Next.js it would be wasted (audit §3.4).

---

## 0. Goal

Move the pure-Dart logic that both the Flutter app and the Jaspr web client
need into shared path-packages, so `web_client_prototype/` imports the **same files**
the app uses instead of the prototype's copies. The prototype made the
boundary concrete: everything it had to copy
(`web_client_prototype/lib/src/domain/*`, `web_client_prototype/lib/src/utils/*`) is exactly the
extraction inventory.

**Why a package and not "fix the imports"**: the app's pubspec depends on the
Flutter SDK, so *no* non-Flutter project can depend on it — even on files
that never touch Flutter. A pure-Dart package is the only mechanism that
lets app + server + web client share source. `packages/wisdom_shared/`
already proves the pattern (path-dep from both app and server, zero Flutter).

---

## 1. Decisions

### 1.1 Two packages, per the audit — not one, not three

| Package | Contents | Deps |
|---|---|---|
| `packages/wisdom_text/` (new) | the 5 pure text algorithms from `core/utils`: `text_utils`, `singlish_transliterator`, `search_query_utils`, `pali_conjunct_transformer`, `search_match_finder` | `characters` only |
| `packages/wisdom_domain/` (new) | all of `lib/domain/` (entities, `failure.dart`, repository interfaces, the 2 usecases) **plus** the two pure data-layer pieces the web also needs (§1.3) | `dartz`, `freezed_annotation`, `wisdom_shared`; dev: `build_runner`, `freezed`, `json_serializable` |

Considered and rejected:
- **Fold everything into `wisdom_shared`** (simplest-change instinct):
  rejected because it drags Freezed codegen and `dartz` into a currently
  codegen-free, dependency-free package the *server* depends on. Keeping
  `wisdom_shared` lean keeps server builds trivial.
- **Three packages** (`wisdom_domain` / `wisdom_text` / `wisdom_api`):
  over-split; the API models ride along fine in `wisdom_domain` (§1.3).

Dependency direction stays clean:
`wisdom_domain → wisdom_shared`, `wisdom_domain → wisdom_text` (only if an
entity needs a text util — currently none does, keep it that way), app →
both, web_client_prototype → both, server → `wisdom_shared` only (unchanged).

### 1.2 Keep Freezed in the shared package

`freezed_annotation` is pure Dart; a non-Flutter package can run
`build_runner` and ship its own `*.freezed.dart`/`*.g.dart`. Keeping Freezed
means **zero rewrite** of entities and zero behavioural risk. The prototype's
plain-class ports in `web_client_prototype/lib/src/domain/` get deleted, not promoted —
they existed only to skip codegen during prototyping.

(Generated files move with their sources; the package gets its own
`build.yaml`-free default build_runner setup, same as the app.)

### 1.3 The two strays: `BJTDocumentParser` and `FTSMatch`

Both live in `lib/data/datasources/` today, are pure Dart, and the web client
needs both (the prototype copied them):

- **`BJTDocumentParser`** → `wisdom_domain/lib/src/content/bjt_document_parser.dart`.
  It's a JSON→entity mapper used identically by the local (native) and remote
  (web) datasources — a domain-adjacent factory, not platform code.
- **`FTSMatch` / `FTSSuggestion`** (models only, *not* the `FTSDataSource`
  interface — that stays in the app) → `wisdom_domain/lib/src/search/fts_models.dart`.
  They are the client-side decoders of the server's API contract.

### 1.4 No re-export shims

The moved files' old import paths break ~46 app files + ~45 test files
(measured 2026-06-10). Update the imports directly — mechanical
find-and-replace — rather than leaving `export 'package:wisdom_domain/...'`
shims in `lib/domain/`/`core/utils/` that would linger forever.

---

## 2. Inventory (what moves, what stays)

### Moves to `wisdom_text`
- `lib/core/utils/text_utils.dart` (+ its tests)
- `lib/core/utils/singlish_transliterator.dart`
- `lib/core/utils/search_query_utils.dart`
- `lib/core/utils/pali_conjunct_transformer.dart`
- `lib/core/utils/search_match_finder.dart`

(Internal dep: `search_match_finder`/`search_query_utils` → `text_utils` —
moves intact. `string_extensions.dart` is NOT used by these five and stays.)

### Stays in `lib/core/utils` (Flutter/platform-coupled or app-only)
`platform_utils*`, `responsive_utils`, `string_extensions`,
`url_launcher_utils`.

### Moves to `wisdom_domain`
- `lib/domain/**` wholesale (entities incl. generated files, failure,
  repository interfaces, 2 usecases).
- `lib/data/datasources/bjt_document_parser.dart` (§1.3).
- `FTSMatch`/`FTSSuggestion` split out of `lib/data/datasources/fts_datasource.dart` (§1.3).

### Consumers to re-point
- **App**: ~46 `lib/` files import `domain/`; 10 files import the five text
  utils (1 data, 9 presentation). All mechanical import swaps.
- **Tests**: ~45 files under `test/` + `integration_test/`. `test/domain/**`
  and the text-util unit tests *move into the packages' own `test/` dirs* so
  the logic is tested where it lives.
- **web_client_prototype**: delete `lib/src/domain/` + `lib/src/utils/` copies, add the
  two path deps, fix imports (handful of files). `reader_tab.dart` keeps its
  port-status (it's presentation state, not domain).
- **Server**: untouched.

---

## 3. Execution order (each step leaves the repo green)

1. **`wisdom_text`** — smallest, zero codegen, proves the loop:
   scaffold package → `git mv` the 5 files + their unit tests → fix 10 app
   imports + test imports → `flutter analyze` + run the moved tests.
2. **`wisdom_domain`** — scaffold (with freezed/build_runner dev-deps) →
   `git mv lib/domain` → move the two strays (§1.3) → run
   `dart run build_runner build` *inside the package* → fix ~46 app imports →
   move `test/domain` into the package → analyze + test.
3. **web_client_prototype swap** — add path deps, delete the copies, fix imports,
   re-run the e2e harness (`web_client_prototype/tool/e2e/test.js`, 14 checks).
4. **Guardrail** — extend the audit's grep check:
   `grep -rl "package:flutter" packages/` must stay empty; consider a tiny CI
   step or a comment in each package README.

Sizing: step 1 ≈ an hour; step 2 is the bulk (mostly import churn);
step 3 ≈ an hour. The whole phase is mechanical — no behaviour changes
anywhere, which is the point: `git mv` + import rewrites only.

Per project convention: test *content* doesn't change (files move), so no
test generation is involved; if any test needs more than an import fix,
flag it for the test agent rather than rewriting inline.

---

## 4. Risks / notes

- **SDK floor**: Flutter was upgraded to 3.44.1 (Dart 3.12.1) on 2026-06-10,
  so app and web_client_prototype share one toolchain. New packages can use
  `sdk: '>=3.10.0 <4.0.0'` (or 3.12 if newer language features are wanted).
- **Freezed versions**: the package and the app should pin compatible
  `freezed`/`freezed_annotation` majors (same caret line as the app uses
  today) so generated code stays interchangeable.
- **Import-churn PR noise**: steps 1 and 2 produce a large but trivially
  reviewable diff — keep them as separate commits ("move files" vs "fix
  imports" if practical, otherwise one commit per step).
- **`Entry`'s `Expando` cache** and all other logic move verbatim — any
  behaviour diff found later is a porting bug, not a design change.
