# Profile report: Open tree view + open 2 suttas (long session)

- **Build mode**: profile ✓
- **Platform**: macos | Flutter 3.38.5 | display 60Hz (budget 16.67ms)
- **Widget rebuild data**: absent ✗ (enable “Count widget builds”)

## Session summary

- Frames captured: **3133** (rolling buffer at export time)
- Session window: **61.7s**
- Avg FPS: **50.8**

## Jank counts

| Category | Count | % of frames |
|---|---:|---:|
| UI-thread over budget (build > 16.67ms) | 11 | 0.4% |
| Raster-thread over budget (raster > 16.67ms) | 2 | 0.1% |
| Both threads over budget (worst case) | 0 | 0.0% |
| **Any jank** | **13** | **0.4%** |

## Timing distribution (μs unless noted)

| Phase | p50 | p90 | p99 | max |
|---|---:|---:|---:|---:|
| Build (UI) | 1.07ms | 6.47ms | 11.88ms | 123.33ms |
| Raster | 0.65ms | 1.01ms | 2.27ms | 54.42ms |

## Worst 10 frames

| Frame # | Build | Raster | Total | Type |
|---:|---:|---:|---:|---|
| 2091 | 123.33ms | 2.56ms | 125.88ms | UI |
| 1522 | 8.33ms | 54.42ms | 62.74ms | RASTER |
| 4234 | 36.96ms | 3.85ms | 40.81ms | UI |
| 2481 | 32.67ms | 1.96ms | 34.62ms | UI |
| 1250 | 21.55ms | 4.85ms | 26.40ms | UI |
| 2749 | 24.42ms | 1.45ms | 25.87ms | UI |
| 2357 | 20.26ms | 1.97ms | 22.23ms | UI |
| 4235 | 19.34ms | 2.68ms | 22.02ms | UI |
| 3922 | 20.17ms | 1.33ms | 21.50ms | UI |
| 1982 | 19.90ms | 1.07ms | 20.97ms | UI |

**Type legend**: `UI` = build phase over budget, `RASTER` = raster phase over budget, `BOTH` = both, `OK` = under budget on both (still in worst-10 by total).

## Sustained jank runs (≥3 consecutive janky frames)

_No sustained runs detected → jank in this scenario is **isolated spikes**, not continuous lag._
