# Profile report: Scrolling a sutta from bottom to top

- **Build mode**: profile ✓
- **Platform**: macos | Flutter 3.38.5 | display 60Hz (budget 16.67ms)
- **Widget rebuild data**: absent ✗ (enable “Count widget builds”)

## Session summary

- Frames captured: **476** (rolling buffer at export time)
- Session window: **7.0s**
- Avg FPS: **67.5**

## Jank counts

| Category | Count | % of frames |
|---|---:|---:|
| UI-thread over budget (build > 16.67ms) | 1 | 0.2% |
| Raster-thread over budget (raster > 16.67ms) | 0 | 0.0% |
| Both threads over budget (worst case) | 0 | 0.0% |
| **Any jank** | **1** | **0.2%** |

## Timing distribution (μs unless noted)

| Phase | p50 | p90 | p99 | max |
|---|---:|---:|---:|---:|
| Build (UI) | 0.49ms | 0.66ms | 1.41ms | 28.16ms |
| Raster | 0.82ms | 1.14ms | 2.13ms | 9.15ms |

## Worst 10 frames

| Frame # | Build | Raster | Total | Type |
|---:|---:|---:|---:|---|
| 540 | 28.16ms | 1.02ms | 29.18ms | UI |
| 196 | 0.17ms | 9.15ms | 9.32ms | OK |
| 631 | 5.78ms | 1.72ms | 7.50ms | OK |
| 541 | 4.07ms | 1.71ms | 5.78ms | OK |
| 459 | 4.01ms | 0.56ms | 4.57ms | OK |
| 199 | 0.42ms | 2.83ms | 3.25ms | OK |
| 545 | 0.33ms | 2.84ms | 3.17ms | OK |
| 198 | 0.90ms | 2.26ms | 3.16ms | OK |
| 632 | 0.54ms | 2.57ms | 3.12ms | OK |
| 223 | 1.04ms | 1.62ms | 2.66ms | OK |

**Type legend**: `UI` = build phase over budget, `RASTER` = raster phase over budget, `BOTH` = both, `OK` = under budget on both (still in worst-10 by total).

## Sustained jank runs (≥3 consecutive janky frames)

_No sustained runs detected → jank in this scenario is **isolated spikes**, not continuous lag._
