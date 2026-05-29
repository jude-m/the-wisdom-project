# Profile report: Switching between tabs (many open)

- **Build mode**: profile ✓
- **Platform**: macos | Flutter 3.38.5 | display 60Hz (budget 16.67ms)
- **Widget rebuild data**: absent ✗ (enable “Count widget builds”)

## Session summary

- Frames captured: **492** (rolling buffer at export time)
- Session window: **9.0s**
- Avg FPS: **54.6**

## Jank counts

| Category | Count | % of frames |
|---|---:|---:|
| UI-thread over budget (build > 16.67ms) | 9 | 1.8% |
| Raster-thread over budget (raster > 16.67ms) | 0 | 0.0% |
| Both threads over budget (worst case) | 0 | 0.0% |
| **Any jank** | **9** | **1.8%** |

## Timing distribution (μs unless noted)

| Phase | p50 | p90 | p99 | max |
|---|---:|---:|---:|---:|
| Build (UI) | 0.45ms | 1.31ms | 29.96ms | 170.15ms |
| Raster | 0.68ms | 1.25ms | 4.54ms | 8.48ms |

## Worst 10 frames

| Frame # | Build | Raster | Total | Type |
|---:|---:|---:|---:|---|
| 859 | 170.15ms | 2.98ms | 173.12ms | UI |
| 860 | 64.61ms | 1.41ms | 66.01ms | UI |
| 893 | 44.08ms | 2.19ms | 46.27ms | UI |
| 782 | 32.08ms | 2.04ms | 34.12ms | UI |
| 932 | 30.33ms | 2.52ms | 32.84ms | UI |
| 713 | 29.58ms | 2.71ms | 32.29ms | UI |
| 1065 | 29.92ms | 1.79ms | 31.71ms | UI |
| 894 | 24.01ms | 0.98ms | 24.99ms | UI |
| 783 | 18.46ms | 0.93ms | 19.39ms | UI |
| 714 | 16.18ms | 1.39ms | 17.57ms | OK |

**Type legend**: `UI` = build phase over budget, `RASTER` = raster phase over budget, `BOTH` = both, `OK` = under budget on both (still in worst-10 by total).

## Sustained jank runs (≥3 consecutive janky frames)

_No sustained runs detected → jank in this scenario is **isolated spikes**, not continuous lag._
