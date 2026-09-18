# Refactor — Document Caching: Two Unbounded Caches

> **Status:** Investigation / **not scheduled**, 2026-09-18. Spun out of the
> step-8 review (`reduce-mobile-size-and-move-to-drift.md`), where the document
> cache key changed shape. **Not a step-8 blocker** — both caches pre-date it
> and it did not raise their ceiling. **No app code changed.**
> **Related:** `docs/todo/retiring-dart-server/reduce-mobile-size-and-move-to-drift.md`

---

## 0. TL;DR

Loaded document text is held in memory twice, by two caches with the same keys,
neither of which ever releases anything. They hold the *same* objects, so it is
not double the memory — but one of them is answered first every time, which
makes the other one hard to justify.

The question is not "bound the cache". It is **does the repository cache earn
its place at all**, now that Riverpod is holding the same thing under the same
key.

---

## 1. What exists today

### Cache A — the repository's own Map

`lib/data/repositories/bjt_document_repository_impl.dart:12`

```dart
final Map<String, BJTDocument> _cache = {};
```

Keyed by `'$fileId:$firstPage:${lastPage ?? 'eof'}'` (`:22`). Written on every
successful load. Nothing removes entries, there is no maximum, and it lives as
long as the app object does.

### Cache B — the Riverpod provider

`lib/presentation/providers/document_provider.dart:71-87`

```dart
final bjtDocumentProvider = FutureProvider.autoDispose
    .family<BJTDocument, DocumentRequest>((ref, request) async {
  ...
  ref.keepAlive(); // successful loads are never disposed
```

`autoDispose` would normally release a document once nothing is watching it.
`keepAlive()` opts out of exactly that, for successful loads. The family key is
the same `(fileId, firstPage, lastPage)` triple the repository builds its string
from — so the two caches have the same key space.

### How they interact

Every read goes provider → use case → repository. The provider answers first, so
on a repeat request the repository is never reached and Cache A is never
consulted. Cache A only earns anything when something calls the repository from
outside the provider.

---

## 2. What step 8 changed (and what it didn't)

| | Before | After |
|---|---|---|
| Key | the file | the file **and the page span** |
| One entry holds | a whole book file | one reading unit |
| Peeking at one sutta costs | the entire file | that sutta's pages |
| Possible entries | one per file | one per reading unit |

More entries, each smaller. The totals come out about even: read a book unit by
unit and the pieces add up to roughly the book you used to cache in one go.

Step 8 **improved** the common case — a citation preview no longer drags in a
whole file — and left the worst case where it was: read everything and
everything is resident. That was true before step 8 too.

---

## 3. The question to investigate

**Does `BJTDocumentRepositoryImpl._cache` do anything the provider isn't already
doing?**

Things to establish before touching it:

1. **Is the repository ever called outside the provider?** Today the only path
   in `lib/` is `bjtDocumentProvider` → `LoadBJTDocumentUseCase` → repository.
   If that stays true, Cache A is dead weight.
2. **Do `hasDocument` / `preloadDocuments` matter?** They are the only callers
   that write whole-file keys (`fileId:0:eof`), and neither is called anywhere
   in `lib/`. If they go, Cache A's key space becomes exactly the provider's,
   and the redundancy is total. (See the step-8 review — `hasDocument` also
   full-inflates a file to answer a bool.)
3. **Does anything depend on the cache surviving a provider rebuild?** That is
   the one job Cache A could still have: if a provider is ever disposed and
   re-created, Cache A would spare the re-read. `keepAlive()` currently makes
   that not happen, but it is the thing to check before deleting.

## 4. Options, in order of preference

- **Delete Cache A**, if §3.1 and §3.3 come back clean. One cache, one owner,
  no key-format string to keep in sync with the family key. Simplest.
- **Keep it and bound it** with the existing `LRUCache`
  (`lib/data/cache/lru_cache.dart`, already used by search) — a few lines, no
  new class. Only worth it if §3.3 finds a real job for it.
- **Bound the provider side instead** by dropping `keepAlive()` and letting
  `autoDispose` do its job, with Cache A as the backing store. This inverts
  which cache is load-bearing; mentioned for completeness, not recommended —
  it would make navigating back re-read the database.

## 5. Not in scope

- Memory profiling as a prerequisite. Neither cache has caused a reported
  problem; this is a "two things doing one job" cleanup, not a leak hunt.
- The snippet/search caches. `CachingTextSearchRepository` is already bounded
  via `LRUCache` and is not part of this.
- Anything in step 8. It is faithful as built; this note only records what the
  review noticed on the way past.
