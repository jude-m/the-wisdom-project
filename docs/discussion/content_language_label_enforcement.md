# Discussion: One construct to mark "Content-Language" labels

**Status:** Open for discussion — *not implemented*.
**Goal:** A single, enforceable construct so it's obvious (to humans *and* the compiler) which strings are **App-Language driven** vs **Content-Language driven** vs **verbatim content**.
**Related:** `docs/todo/app_language_and_content_language_plan.md`, `docs/discussion/search_result_titles_content_language.md`.

---

## 1. The problem

Right now the rule "this label follows Content Language, that one follows App Language" is **convention**, not enforcement. Nothing stops someone from rendering a tree-node name with a raw `Text(node.paliName)` and silently breaking the Content-Language behaviour. You asked: *can we have one construct — an interface or whatever — so we know which labels go through the pipeline?*

---

## 2. The three buckets (the thing we're classifying)

| Bucket | Driven by | Rendered via | Examples |
|--------|-----------|--------------|----------|
| **UI chrome** | **App Language** (en / si) | `AppLocalizations.of(context).xxx` | "Settings", "Refine", "Top Results" |
| **Data label** | **Content Language** (pali / si) | `formatContentLabel(node.getDisplayName(lang), lang)` | tree nodes, breadcrumbs, tab labels, search title + path |
| **Verbatim content** | *neither* (source text) | shown as stored; Pali gets conjuncts | reading panes, matched-text snippets |

Litmus test: *"Which switch changes this string — App Language or Content Language?"* Neither ⇒ verbatim content.

---

## 3. What we already have (the good news)

We're ~80% there — the pipeline is already centralised:

- **`formatContentLabel(raw, ContentLanguage)`** (`lib/presentation/utils/content_text_formatter.dart`) — the *single* place script transforms happen (Pali → conjunct ligatures today; Roman transliteration plugs in here in Phase 2).
- **`TipitakaTreeNode.getDisplayName(ContentLanguage)`** — the single place a node picks its name (with fallback when one language is missing).
- **`breadcrumbPathProvider`** and **`searchResultLabels`** — both already funnel through `getDisplayName` + `formatContentLabel`.

So "data labels go through one pipeline" is already *true in practice*. What's missing is something that **enforces** it / **names** it.

---

## 4. Options

### Option 1 — A domain interface `ContentLabeled` *(recommended, part 1)*
Mark every entity that owns multi-language names:
```dart
/// Marks an entity that carries names in multiple content languages.
/// If a class implements this, its names MUST be rendered through the
/// Content Language pipeline — never shown raw.
abstract interface class ContentLabeled {
  String label(ContentLanguage language);
}
```
- `TipitakaTreeNode` already satisfies it (rename/alias `getDisplayName` → `label`, or just `implements ContentLabeled`).
- `ReaderTab` could implement it too (it has `paliName` / `sinhalaName`).
- **Win:** the *type* now tells you "this has a content label." Enforcement at the **data layer**.

### Option 2 — A single render widget `ContentLabel` *(recommended, part 2)*
One widget is the *only* sanctioned way to show a data label:
```dart
/// The ONE way to render a Content-Language data label.
/// `ContentLabel(nodeKey)` in the tree  => follows Content Language.
/// `Text(l10n.xxx)`         in the tree  => follows App Language.
class ContentLabel extends ConsumerWidget {
  const ContentLabel(this.nodeKey, {this.style, this.maxLines, this.overflow, super.key});
  final String nodeKey;
  // ...resolves effectiveContentLanguage + nodeByKeyProvider + formatContentLabel
}
```
- `breadcrumbPathProvider` and `searchResultLabels` become callers/implementations of this one seam.
- **Win:** the distinction is **visible at every call site**. Enforcement at the **UI layer** by habit + reviewability.

### Option 3 — A value type `ContentText` *(strongest, but heavy — not recommended)*
```dart
extension type const ContentText(String _raw) {}   // must be unwrapped via the pipeline
```
- The compiler refuses to render a `ContentText` as a plain `String`.
- **Win:** the hardest guarantee. **Cost:** viral — it spreads through dozens of signatures (entities, providers, widgets) for modest practical gain over 1+2.

### Option 4 — Convention + naming only *(status quo+)*
Document the rule, keep `formatContentLabel` as the only transform, rely on review.
- **Win:** zero cost. **Cost:** no enforcement; easy to regress.

---

## 5. Recommendation

**Adopt Option 1 + Option 2.** Together they answer the question at both layers without the virality of Option 3:

- `ContentLabeled` (data layer) = "this entity *has* a content-language name."
- `ContentLabel` widget / resolver (UI layer) = "this is *how* you render one, the only way."
- Everything else stays on `AppLocalizations` (UI) or is verbatim content.

Because the pipeline already exists, this is mostly **consolidation + naming**, not new machinery.

---

## 6. If we proceed — rough steps (not done yet)

1. Add `ContentLabeled` interface in `domain/`; have `TipitakaTreeNode` implement it.
2. Add a `ContentLabel` widget (+ a `contentLabelFor(ref, nodeKey)` resolver) in `presentation/`.
3. Migrate `breadcrumbPathProvider`, `searchResultLabels`, tree navigator, and tab labels to the resolver/widget.
4. (Optional) a tiny lint/CI grep that flags `\.paliName|\.sinhalaName` used outside the resolver, to catch regressions.
5. Note for Phase 2: Roman/Pali Script transliteration still plugs into `formatContentLabel` — this construct doesn't change that seam.

---

## 7. Open questions

- [ ] Adopt **1+2**, or start with just **2** (the widget) and add the interface later?
- [ ] Rename `getDisplayName` → `label`, or keep both?
- [ ] Is a regression-catching lint/grep worth the noise?
