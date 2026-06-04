# Refactor candidate: invert ownership of `mainSearchFocusNodeProvider`

**Status:** Noted, not actioned — parked for later (2026-06-04).
**Severity:** Latent footgun. No known crash today, but it's the same pattern that
crashed the in-page search bar. Worth unifying for consistency + safety.

## Background — what we already did for the in-page search bar

The in-page (find-in-page) search bar used to **own** its `FocusNode` and push/clear
it into a `StateProvider<FocusNode?>` through its widget lifecycle:

- `initState` → publish: `controller.state = _focusNode`
- `dispose`  → clear:   `controller.state = null`

That mutate-a-provider-during-`dispose()` re-entered Riverpod's scheduler **while the
widget was being torn down**, and because the bar both `ref.watch`ed the provider that
controls its own visibility *and* was unmounted by it, Riverpod tried to rebuild a
`defunct` element → `'_lifecycleState != _ElementLifecycle.defunct': is not true`.

We fixed it by **inverting ownership**: a plain `Provider<FocusNode>` now creates and
disposes the node (via `ref.onDispose`), and the widget is a pure *consumer* that
borrows it and never writes provider state. See the implemented version:

- `lib/presentation/providers/in_page_search_focus_provider.dart` (the template)
- `lib/presentation/widgets/reader/in_page_search_bar.dart`
- `lib/presentation/keyboard/shortcut_actions.dart` (`OpenInPageSearchAction`)

`mainSearchFocusNodeProvider` is the **mirror twin** of that provider and still uses the
old publish/clear-in-lifecycle pattern. This doc is about bringing it in line.

## Where

- `lib/presentation/providers/main_search_focus_provider.dart`
  - `final mainSearchFocusNodeProvider = StateProvider<FocusNode?>((ref) => null);`
- `lib/presentation/widgets/search/search_bar.dart` (`_SearchBarState`)
  - field: `final FocusNode _focusNode = FocusNode();`
  - field: `late final StateController<FocusNode?> _searchFocusController;`
  - `initState`: captures `ref.read(mainSearchFocusNodeProvider.notifier)`, then in a
    post-frame callback `_searchFocusController.state = _focusNode;`
  - `dispose`: `if (identical(_searchFocusController.state, _focusNode)) { _searchFocusController.state = null; }` then `_focusNode.dispose();`
- Read sites (consumers of the published node):
  - `lib/presentation/keyboard/shortcut_actions.dart` → `OpenMainSearchAction`:
    `ref.read(mainSearchFocusNodeProvider)?.requestFocus();`
  - `lib/presentation/widgets/app/overlay_stack_sync.dart` → FTS-panel `dismiss`:
    `ref.read(mainSearchFocusNodeProvider)?.unfocus();`

## The observation

Same shape as the old in-page bug: a transient widget publishes a disposable,
mutable `FocusNode` into global state and clears it in `dispose()`. Carries the same
two smells — a provider that can hold a *disposed* node, and a provider write during
teardown — plus the `identical(...)` guard that exists only to defend the race.

## Why it doesn't crash today (and why it's still worth changing)

The crash needed two things together: (a) a provider write during `dispose()`, **and**
(b) the widget being unmounted by a provider it watches. `SearchBar` has (a) but not
(b): it lives in the app bar and is effectively **always mounted**, so its `dispose()`
almost never runs, and nothing unmounts it as a side effect of a provider it watches.
So the footgun is loaded but not pointed at anything — today.

It still matters because:
- It's the lone remaining instance of a pattern we've decided is wrong.
- If `SearchBar` ever becomes conditionally mounted (e.g. hidden on certain
  routes / collapsed into an icon on mobile), it inherits the exact in-page crash.
- One consistent idiom across both focus providers is easier to reason about.

## Proposed change (mirror the in-page fix)

1. **Provider owns the node** — change `main_search_focus_provider.dart` to:
   ```dart
   final mainSearchFocusNodeProvider = Provider<FocusNode>((ref) {
     final node = FocusNode(debugLabel: 'main-search');
     ref.onDispose(node.dispose);
     return node;
   });
   ```
2. **`SearchBar` borrows, never writes** — capture once in `initState`
   (`_focusNode = ref.read(mainSearchFocusNodeProvider);`), drop the
   `_searchFocusController` field, the post-frame publish, and the clear-in-`dispose`.
   `dispose()` keeps only `removeListener` + `_controller.dispose()` and **no longer
   disposes the node** (the provider does).
3. **Simplify the read sites** — node is now non-null:
   - `OpenMainSearchAction`: `ref.read(mainSearchFocusNodeProvider).requestFocus();`
   - `overlay_stack_sync` dismiss: `ref.read(mainSearchFocusNodeProvider).unfocus();`

Net: deletes the `StateProvider<FocusNode?>`, the captured controller, the publish,
the clear, and the `identical(...)` guard. Fewer lines, no lifecycle→provider writes.

## Risks / differences vs the in-page bar (read before doing)

- **More read sites.** Unlike the in-page node (one reader), this one is read in two
  places (`OpenMainSearchAction`, `overlay_stack_sync`). Both currently use `?.` and
  must be updated to the non-null form. Grep for `mainSearchFocusNodeProvider` and
  confirm there are no others.
- **Session-lived, shared node.** The node will live for the whole app session and be
  reused across any remount of `SearchBar` (e.g. hot reload, theme/locale rebuilds).
  `FocusNode`s are built to detach/reattach, so this is fine — but verify the
  `_onFocusChange` listener is still added in `initState` / removed in `dispose`
  symmetrically so listeners don't accumulate across remounts.
- **`ref` in `dispose`.** Keep the "capture in `initState`" habit — store the node in a
  field and use the field in `dispose`, don't touch `ref` there.
- **Don't over-scope.** This is the only twin left; do not generalize into a shared
  base/mixin for "widgets that own a focus node" — two call sites don't justify it
  (per the project's "prefer simplest change" guidance).

## What to test (manual + suggested automated)

Manual — focus behaviours that depend on this node:

1. **Ctrl/Cmd+Shift+F from anywhere** (reader, empty space, *inside* the in-page search
   field, inside a reader selection) jumps focus to the main FTS search bar.
2. **Select-all-on-focus**: focusing the bar when it already has a query highlights the
   whole query (the post-frame selection logic in `_onFocusChange` still fires).
3. **FTS results-panel dismiss** (Esc / tap-out): `overlay_stack_sync`'s `dismiss`
   calls `unfocus()` on the node and the panel closes; typing again re-opens it
   (i.e. `isPanelDismissed` resets — the focus release still works).
4. **Recent-searches overlay**: focus empty bar → recent overlay shows; Esc closes it
   and releases focus.
5. **Tab traversal** stays healthy after focusing/blurring the search bar (this was the
   collateral symptom of the in-page crash — make sure the main bar didn't regress it).
6. **Hot reload** while the bar is focused — no "used a disposed FocusNode" / no
   "ref after dispose" errors; focus state survives sensibly.
7. **No crash on teardown**: navigate so `SearchBar` is rebuilt/disposed (locale switch,
   theme switch, or any route change that remounts the app bar) — no
   `'_lifecycleState != defunct'` assertion.

Suggested automated (per project rules, write only when picked up):

- Widget test: pump a scope, read `mainSearchFocusNodeProvider`, assert it returns a
  non-null `FocusNode` and the **same instance** across reads.
- Widget test: mount `SearchBar`, dispatch `OpenMainSearchIntent` (or call the action),
  assert `node.hasFocus` becomes true.
- Widget test: mount → unmount `SearchBar`, assert no exception and that the provider's
  node is **not** disposed (still usable) — proves ownership moved to the provider.
- Provider test: dispose the `ProviderContainer`, assert the node is disposed exactly
  once (`ref.onDispose` ran).

## Recommendation

Adopt the in-page pattern for symmetry and to retire the last
`StateProvider<FocusNode?>` publish/clear idiom. Low-risk, net-negative LOC, but it
touches the **always-on** main search bar and two read sites — so do it as its own
small change with the focus checklist above run manually, not folded into unrelated
work.
