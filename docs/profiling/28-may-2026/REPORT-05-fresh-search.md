# Profile report: Open a sutta from a fresh keyword search

- **Build mode**: profile ✓
- **Platform**: macos | Flutter 3.38.5 | display 60Hz (budget 16.67ms)
- **Widget rebuild data**: absent ✗ (enable “Count widget builds”)

## Session summary

- Frames captured: **992** (rolling buffer at export time)
- Session window: **57.2s**
- Avg FPS: **17.3**

## Jank counts

| Category | Count | % of frames |
|---|---:|---:|
| UI-thread over budget (build > 16.67ms) | 6 | 0.6% |
| Raster-thread over budget (raster > 16.67ms) | 0 | 0.0% |
| Both threads over budget (worst case) | 0 | 0.0% |
| **Any jank** | **6** | **0.6%** |

## Timing distribution (μs unless noted)

| Phase | p50 | p90 | p99 | max |
|---|---:|---:|---:|---:|
| Build (UI) | 1.59ms | 2.09ms | 10.01ms | 58.99ms |
| Raster | 0.82ms | 1.31ms | 3.19ms | 4.75ms |

## Worst 10 frames

| Frame # | Build | Raster | Total | Type |
|---:|---:|---:|---:|---|
| 5788 | 58.99ms | 2.13ms | 61.12ms | UI |
| 6248 | 41.90ms | 1.75ms | 43.65ms | UI |
| 5732 | 29.15ms | 1.93ms | 31.07ms | UI |
| 5392 | 22.28ms | 1.89ms | 24.16ms | UI |
| 5853 | 20.76ms | 1.35ms | 22.11ms | UI |
| 5733 | 16.93ms | 2.19ms | 19.11ms | UI |
| 5734 | 16.20ms | 1.25ms | 17.45ms | OK |
| 5973 | 14.32ms | 2.30ms | 16.63ms | OK |
| 6249 | 14.10ms | 1.29ms | 15.39ms | OK |
| 5616 | 9.91ms | 3.08ms | 12.99ms | OK |

**Type legend**: `UI` = build phase over budget, `RASTER` = raster phase over budget, `BOTH` = both, `OK` = under budget on both (still in worst-10 by total).

## Sustained jank runs (≥3 consecutive janky frames)

_No sustained runs detected → jank in this scenario is **isolated spikes**, not continuous lag._
