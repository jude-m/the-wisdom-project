# Performance Profiling — Summary & Punch List

**Date**: 2026-05-28
**Build**: profile mode (numbers accurate) · Flutter 3.38.5 · macOS · 60Hz display (16.67ms budget)
**Sessions**: 5 DevTools frame exports (~150s total) + 1 memory heap snapshot
**Source files**: `docs/profiling/*.json` + `*.csv` · per-scenario detail in `REPORT-01..05` · memory in `REPORT-06-memory.md`

---

## TL;DR

**The app is in good shape overall.** Steady-state frame rates are fine, but the app has **rare, very tall UI-thread spikes** that the user perceives as momentary freezes when:

1. **Switching between open reader tabs** — worst spike **170ms** (≈ 1/6 second freeze)
2. **Opening a tree view + then a sutta** — worst spike **123ms**
3. **Opening a sutta from a fresh keyword search** — worst spike **59ms**
4. **Opening a cached search record** — worst spike **30ms** (surprisingly high for cache hit)
5. **Scrolling inside a sutta** — clean, **no jank**

Across all 5 scenarios, **the raster (GPU) thread is healthy** (max ~9ms in 4/5 files, one 54ms outlier). The bottleneck is **almost entirely on the UI thread (Dart build phase)**. That's good news — it means the fixes are in Dart code, not in shaders or GPU work.

**No sustained jank runs** were detected in any scenario. Every problem is an **isolated spike** at a specific user action — not continuous lag during scrolling or animation. This is a much easier class of problem to fix than "everything is slow."

---

## At-a-glance comparison

| # | Scenario | Frames | Window | Max build | p99 build | UI jank | Severity |
|---|---|---:|---:|---:|---:|---:|---|
| 1 | Scrolling a sutta (bottom→top) | 476 | 7.0s | **28ms** | 1.4ms | 1 (0.2%) | ✅ excellent |
| 2 | Switching between tabs | 492 | 9.0s | **170ms** | 30.0ms | 9 (1.8%) | 🔴 worst |
| 3 | Open cached search record | 336 | 16.8s | **30ms** | 6.1ms | 2 (0.6%) | 🟡 mild |
| 4 | Tree view + open 2 suttas | 3133 | 61.7s | **123ms** | 11.9ms | 11 (0.4%) | 🟠 isolated spike |
| 5 | Open sutta from fresh search | 992 | 57.2s | **59ms** | 10.0ms | 6 (0.6%) | 🟠 noticeable |

> Note: the "Avg FPS" numbers in individual reports are misleading and ignored above — they reflect how often frames are emitted, which drops naturally during idle moments. **Worst-frame and p99 are the metrics that matter.**

---

## Top finding — Tab switching is the standout problem

In `REPORT-02-tab-switch.md`, the worst frames are not just bad — they are **clustered in adjacent frame numbers**:

| Frame # | Build time | Frame # | Build time |
|---:|---:|---:|---:|
| 859 | **170ms** | 782 | 32ms |
| 860 | 64ms | 783 | 18ms |
| 893 | 44ms | 1065 | 30ms |
| 894 | 24ms | 932 | 30ms |
| 713 | 30ms | 714 | 16ms |

The 859 → 860 sequence in particular is **234ms of UI work split across two consecutive frames**. Same pattern at 893/894, 782/783, 713/714. This is a clear fingerprint: **each tab switch triggers a large, multi-frame burst of build work.**

### Why this is happening (hypothesis — needs verification with traces)

A quick code scan turned up:
- `grep TabBarView|IndexedStack|TabController lib/` → **zero matches**
- This means the open-reader-tabs UI is **custom-managed**, not using Flutter's `TabBarView` or wrapping content in an `IndexedStack`

When a user switches between open suttas, the tab content widget tree is likely being **discarded and rebuilt from scratch** on every switch, rather than being kept alive off-screen. For a sutta reader that may parse formatted text, build many `RichText`/`Text` widgets, set up controllers, etc., this rebuild is the 170ms work.

**Files to look at when you're ready to fix**:
- `lib/presentation/widgets/navigation/tab_bar_widget.dart` — the tab bar itself
- `lib/presentation/widgets/reader/multi_pane_reader_widget.dart` — what each tab renders
- `lib/presentation/models/reader_tab.dart` and `reader_pane.dart` — the tab data model
- Any provider that produces the active tab's reader content (probably in `lib/presentation/providers/`)

The likely fix shape — **not implementing yet** — is one of:
1. Wrap the reader pane in an `IndexedStack` so all open tabs stay mounted (uses more memory; trades work for state)
2. Add `AutomaticKeepAliveClientMixin` to the per-tab reader widget
3. Cache parsed/processed content per-tab so re-mounting is cheap (build is fast even if rebuilt)

Each has tradeoffs. We'd want to look at memory before picking.

> **Memory snapshot update (see `REPORT-06-memory.md`)**: a heap snapshot taken later that day adds a strong corroborating signal — there are **562 `TextEntryWidget` instances but only 194 mounted `_TextEntryWidgetState` instances** (a ~3× ratio). This is the smoking gun: widget configs are being rebuilt en masse on tab switch while only a fraction actually mount. ~187 entries × 3 panes ≈ 561 widget builds per switch ≈ the observed 170ms spike.

---

## Other findings

### Tree view session has one giant spike (frame 2091, 123ms)

In `REPORT-04-tree-view.md`, 61 seconds of data, only 11 UI jank frames — very clean — **except** for one 123ms outlier and a raster spike of 54ms (frame 1522). Without trace data we can't say which user action triggered it, but the timing suggests:
- 123ms spike → likely the initial expansion of the tree node hierarchy, or sutta-open work
- 54ms raster → one-time shader compile (this goes away after first run with `--cache-sksl` baked in)

**This is the only place raster was ever a problem** — and it's plausibly a one-shot warmup cost.

### Fresh search → sutta has multiple medium spikes

`REPORT-05-fresh-search.md` shows **3 frames in a row over 16ms** (frames 5732/5733/5734, build times 29ms/17ms/16ms). My script's "sustained run" check missed this by 0.47ms — I'll widen the threshold slightly so it catches near-misses.

Pattern looks like: tap a search result → push reader screen → render sutta. Three frames means the work spans the route push animation, which is exactly when stutter is most visible.

Compare to the cached-search scenario (REPORT-03): 30ms max vs 59ms here. The **delta of ~30ms is the cost of "fresh" (not cached) search/render path** — somewhere there's parsing or processing being done on the UI thread that the cache short-circuits.

### Scrolling is genuinely good (REPORT-01)

One janky frame in 476. Raster p99 is 2.1ms — plenty of headroom. Whatever the reader widget is doing during scroll, it's fine. **Don't fix what isn't broken.**

### Cached search has small spikes (REPORT-03)

A 30ms UI spike and a 26ms raster spike on opening a cached record. The raster spike (uncommon for this app) is suspicious — maybe a shadow/gradient being rendered for the first time in that session. Low priority.

---

## Recommended next steps (in priority order)

> **I am not changing any code yet. This is the punch list for when you give the go-ahead.**

### 1. Re-record one more session with widget rebuild data enabled — highest leverage

All 5 current exports have `rebuildCountModel: null` because **"Count widget builds" wasn't ticked** in the Performance tab before recording. With that enabled, the next export tells us **exactly which widgets rebuild during a tab switch** — turning "the reader pane is the suspect" into "this specific widget rebuilt 47 times when only 1 was needed."

**Specifically**: re-record only the tab-switch scenario. 30 seconds of switching between 3–5 open tabs is enough. Tick "Count widget builds" + "Trace layouts" before recording.

### 2. Investigate tab-switching architecture (file refs above)

Confirm/refute the "no IndexedStack, full rebuild on switch" hypothesis. Read the existing `tab_bar_widget.dart` + `multi_pane_reader_widget.dart` and trace how an active-tab change propagates. We'd discuss the right caching strategy before making changes.

### 3. Investigate the 30ms cost difference on fresh search → sutta open

Compare the fresh-search code path against the cached path. The cache is saving ~30ms of UI thread work somewhere — find what's in that gap. May or may not be worth optimizing depending on what it is.

### 4. Decode `traceBinary` (only if needed)

Each export has a `traceBinary` field (~3MB Perfetto protobuf). If steps 1–3 don't pinpoint the cause, we can crack it open and read event-level spans with widget names. This is heavier work — only worth it if frame-level + rebuild-count data isn't enough.

### 5. Minor: tighten my "sustained jank" detector

It missed the 5732–5734 run by 0.47ms. Will widen threshold to "frames near the budget" for the next pass.

---

## What I'd suggest you do right now

**Nothing in code.** Read this report and the per-scenario reports it references. Decide whether the tab-switch finding aligns with what you've *felt* during your extended testing. If yes, we move to step 1 (a focused 30-second tab-switch re-recording with rebuild counts on) and from there we'll have enough to make targeted fixes with confidence.

If you'd like me to:
- Walk you through one of the per-scenario reports in more detail → say which
- Look at the suspected source files now to map out what's currently there (still no edits) → say "explore tabs"
- Decode the `traceBinary` from the worst file → say "go deeper on tab switch"
