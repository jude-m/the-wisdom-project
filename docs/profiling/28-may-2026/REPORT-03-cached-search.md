# Profile report: Open cached search record from FTS tab

- **Build mode**: profile ✓
- **Platform**: macos | Flutter 3.38.5 | display 60Hz (budget 16.67ms)
- **Widget rebuild data**: absent ✗ (enable “Count widget builds”)

## Session summary

- Frames captured: **336** (rolling buffer at export time)
- Session window: **16.8s**
- Avg FPS: **19.9**

## Jank counts

| Category | Count | % of frames |
|---|---:|---:|
| UI-thread over budget (build > 16.67ms) | 2 | 0.6% |
| Raster-thread over budget (raster > 16.67ms) | 1 | 0.3% |
| Both threads over budget (worst case) | 0 | 0.0% |
| **Any jank** | **3** | **0.9%** |

## Timing distribution (μs unless noted)

| Phase | p50 | p90 | p99 | max |
|---|---:|---:|---:|---:|
| Build (UI) | 1.73ms | 3.17ms | 6.10ms | 30.38ms |
| Raster | 0.93ms | 1.45ms | 4.03ms | 26.71ms |

## Worst 10 frames

| Frame # | Build | Raster | Total | Type |
|---:|---:|---:|---:|---|
| 5253 | 30.38ms | 1.51ms | 31.89ms | UI |
| 5046 | 27.31ms | 2.01ms | 29.32ms | UI |
| 5182 | 2.46ms | 26.71ms | 29.17ms | RASTER |
| 5092 | 11.52ms | 1.73ms | 13.25ms | OK |
| 5157 | 4.90ms | 4.20ms | 9.10ms | OK |
| 5015 | 6.75ms | 0.90ms | 7.65ms | OK |
| 5052 | 3.67ms | 3.71ms | 7.38ms | OK |
| 5158 | 4.36ms | 2.53ms | 6.89ms | OK |
| 5090 | 4.62ms | 1.80ms | 6.41ms | OK |
| 4991 | 0.65ms | 5.75ms | 6.40ms | OK |

**Type legend**: `UI` = build phase over budget, `RASTER` = raster phase over budget, `BOTH` = both, `OK` = under budget on both (still in worst-10 by total).

## Sustained jank runs (≥3 consecutive janky frames)

_No sustained runs detected → jank in this scenario is **isolated spikes**, not continuous lag._
