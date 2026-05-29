#!/usr/bin/env python3
"""
Analyze a Flutter DevTools performance JSON export.

Usage:
    python3 analyze.py "<path-to-export.json>" [--out <report.md>]

Reads `performance.flutterFrames` and produces a markdown report:
  - Session metadata
  - Jank counts (UI thread / raster thread / either)
  - Worst-N frame table
  - Percentile distribution
  - Sustained jank runs (consecutive janky frames)
  - Pattern classification (isolated spikes vs sustained jank vs warmup)
"""
from __future__ import annotations
import argparse
import json
import statistics
import sys
from pathlib import Path

# 60Hz budget in microseconds. DevTools exports use μs for build/raster.
BUDGET_60HZ_US = 16_667


def load_frames(path: Path) -> tuple[list[dict], dict]:
    with path.open() as f:
        data = json.load(f)
    perf = data.get("performance", {})
    frames = perf.get("flutterFrames", []) or []
    meta = {
        "refresh_hz": perf.get("displayRefreshRate", 60),
        "is_profile": data.get("connectedApp", {}).get("isProfileBuild"),
        "os": data.get("connectedApp", {}).get("operatingSystem"),
        "flutter": data.get("connectedApp", {}).get("flutterVersion"),
        "rebuild_data": perf.get("rebuildCountModel") is not None,
    }
    return frames, meta


def pct(values: list[float], p: float) -> float:
    if not values:
        return 0.0
    s = sorted(values)
    k = (len(s) - 1) * p
    f = int(k)
    c = min(f + 1, len(s) - 1)
    if f == c:
        return s[f]
    return s[f] + (s[c] - s[f]) * (k - f)


def fmt_ms(us: float) -> str:
    return f"{us/1000:.2f}ms"


def classify_frame(build_us: int, raster_us: int, budget_us: int) -> str:
    ui_over = build_us > budget_us
    raster_over = raster_us > budget_us
    if ui_over and raster_over:
        return "BOTH"
    if ui_over:
        return "UI"
    if raster_over:
        return "RASTER"
    return "OK"


def find_jank_runs(frames: list[dict], budget_us: int, min_len: int = 3) -> list[dict]:
    """Find consecutive runs of N+ janky frames (sustained jank)."""
    runs = []
    current_start = None
    current_count = 0
    current_max_build = 0
    current_max_raster = 0
    for i, fr in enumerate(frames):
        janky = fr["build"] > budget_us or fr["raster"] > budget_us
        if janky:
            if current_start is None:
                current_start = i
                current_count = 1
                current_max_build = fr["build"]
                current_max_raster = fr["raster"]
            else:
                current_count += 1
                current_max_build = max(current_max_build, fr["build"])
                current_max_raster = max(current_max_raster, fr["raster"])
        else:
            if current_start is not None and current_count >= min_len:
                runs.append({
                    "start_idx": current_start,
                    "length": current_count,
                    "start_frame": frames[current_start]["number"],
                    "end_frame": frames[current_start + current_count - 1]["number"],
                    "max_build_us": current_max_build,
                    "max_raster_us": current_max_raster,
                })
            current_start = None
            current_count = 0
    if current_start is not None and current_count >= min_len:
        runs.append({
            "start_idx": current_start,
            "length": current_count,
            "start_frame": frames[current_start]["number"],
            "end_frame": frames[current_start + current_count - 1]["number"],
            "max_build_us": current_max_build,
            "max_raster_us": current_max_raster,
        })
    return runs


def detect_warmup(frames: list[dict], budget_us: int) -> int:
    """First N frames are commonly janky due to shader compilation, first paint.
    Return the index after which sustained jank settles down."""
    if len(frames) < 20:
        return 0
    # If the first 10 frames have many janky, but frames 20-40 are mostly clean,
    # call it warmup.
    early_jank = sum(1 for fr in frames[:10] if fr["build"] > budget_us or fr["raster"] > budget_us)
    mid_jank = sum(1 for fr in frames[20:40] if fr["build"] > budget_us or fr["raster"] > budget_us) if len(frames) >= 40 else 0
    if early_jank >= 3 and mid_jank <= 2:
        return 10
    return 0


def analyze(frames: list[dict], meta: dict, budget_us: int = BUDGET_60HZ_US) -> dict:
    total = len(frames)
    if total == 0:
        return {"empty": True}

    builds = [fr["build"] for fr in frames]
    rasters = [fr["raster"] for fr in frames]
    elapseds = [fr["elapsed"] for fr in frames]

    ui_jank = [fr for fr in frames if fr["build"] > budget_us]
    raster_jank = [fr for fr in frames if fr["raster"] > budget_us]
    any_jank = [fr for fr in frames if fr["build"] > budget_us or fr["raster"] > budget_us]
    both_jank = [fr for fr in frames if fr["build"] > budget_us and fr["raster"] > budget_us]

    # Worst-10 by total time (build + raster)
    worst = sorted(frames, key=lambda fr: fr["build"] + fr["raster"], reverse=True)[:10]

    # Session duration (from first frame start to last frame end, ms)
    session_us = (frames[-1]["startTime"] + frames[-1]["elapsed"]) - frames[0]["startTime"]
    session_ms = session_us / 1000

    # Effective FPS = frames drawn / wall-clock seconds.
    # NOTE: `elapsed` is per-frame work duration, not the gap between frames,
    # so we can't use mean(elapsed) — we'd get an unrealistic number.
    avg_fps = (total / (session_us / 1_000_000)) if session_us > 0 else 0

    # Sustained jank runs
    runs = find_jank_runs(frames, budget_us, min_len=3)

    # Warmup detection
    warmup_end = detect_warmup(frames, budget_us)
    post_warmup = frames[warmup_end:] if warmup_end else frames
    post_warmup_jank = [fr for fr in post_warmup if fr["build"] > budget_us or fr["raster"] > budget_us]

    return {
        "empty": False,
        "total_frames": total,
        "session_ms": session_ms,
        "avg_fps": avg_fps,
        "budget_us": budget_us,
        "ui_jank_count": len(ui_jank),
        "raster_jank_count": len(raster_jank),
        "both_jank_count": len(both_jank),
        "any_jank_count": len(any_jank),
        "jank_pct": 100 * len(any_jank) / total,
        "post_warmup_jank_count": len(post_warmup_jank),
        "post_warmup_jank_pct": 100 * len(post_warmup_jank) / len(post_warmup) if post_warmup else 0,
        "warmup_end": warmup_end,
        "build_p50": pct(builds, 0.50),
        "build_p90": pct(builds, 0.90),
        "build_p99": pct(builds, 0.99),
        "build_max": max(builds),
        "raster_p50": pct(rasters, 0.50),
        "raster_p90": pct(rasters, 0.90),
        "raster_p99": pct(rasters, 0.99),
        "raster_max": max(rasters),
        "worst_frames": worst,
        "jank_runs": runs,
        "meta": meta,
    }


def render_report(scenario: str, a: dict) -> str:
    if a.get("empty"):
        return f"# {scenario}\n\nNo frames captured.\n"

    m = a["meta"]
    lines = []
    lines.append(f"# Profile report: {scenario}")
    lines.append("")
    lines.append(f"- **Build mode**: {'profile ✓' if m['is_profile'] else 'NOT profile ✗ (numbers unreliable)'}")
    lines.append(f"- **Platform**: {m['os']} | Flutter {m['flutter']} | display {m['refresh_hz']}Hz (budget {a['budget_us']/1000:.2f}ms)")
    lines.append(f"- **Widget rebuild data**: {'present ✓' if m['rebuild_data'] else 'absent ✗ (enable “Count widget builds”)'}")
    lines.append("")
    lines.append("## Session summary")
    lines.append("")
    lines.append(f"- Frames captured: **{a['total_frames']}** (rolling buffer at export time)")
    lines.append(f"- Session window: **{a['session_ms']/1000:.1f}s**")
    lines.append(f"- Avg FPS: **{a['avg_fps']:.1f}**")
    lines.append("")
    lines.append("## Jank counts")
    lines.append("")
    lines.append(f"| Category | Count | % of frames |")
    lines.append(f"|---|---:|---:|")
    lines.append(f"| UI-thread over budget (build > {a['budget_us']/1000:.2f}ms) | {a['ui_jank_count']} | {100*a['ui_jank_count']/a['total_frames']:.1f}% |")
    lines.append(f"| Raster-thread over budget (raster > {a['budget_us']/1000:.2f}ms) | {a['raster_jank_count']} | {100*a['raster_jank_count']/a['total_frames']:.1f}% |")
    lines.append(f"| Both threads over budget (worst case) | {a['both_jank_count']} | {100*a['both_jank_count']/a['total_frames']:.1f}% |")
    lines.append(f"| **Any jank** | **{a['any_jank_count']}** | **{a['jank_pct']:.1f}%** |")
    lines.append("")
    if a["warmup_end"]:
        lines.append(f"_Excluding the first {a['warmup_end']} frames as warmup (shader compile / first paint):_")
        lines.append(f"- Post-warmup jank: **{a['post_warmup_jank_count']}** frames (**{a['post_warmup_jank_pct']:.1f}%**)")
        lines.append("")
    lines.append("## Timing distribution (μs unless noted)")
    lines.append("")
    lines.append(f"| Phase | p50 | p90 | p99 | max |")
    lines.append(f"|---|---:|---:|---:|---:|")
    lines.append(f"| Build (UI) | {fmt_ms(a['build_p50'])} | {fmt_ms(a['build_p90'])} | {fmt_ms(a['build_p99'])} | {fmt_ms(a['build_max'])} |")
    lines.append(f"| Raster | {fmt_ms(a['raster_p50'])} | {fmt_ms(a['raster_p90'])} | {fmt_ms(a['raster_p99'])} | {fmt_ms(a['raster_max'])} |")
    lines.append("")
    lines.append("## Worst 10 frames")
    lines.append("")
    lines.append("| Frame # | Build | Raster | Total | Type |")
    lines.append("|---:|---:|---:|---:|---|")
    for fr in a["worst_frames"]:
        cls = classify_frame(fr["build"], fr["raster"], a["budget_us"])
        total = fr["build"] + fr["raster"]
        lines.append(f"| {fr['number']} | {fmt_ms(fr['build'])} | {fmt_ms(fr['raster'])} | {fmt_ms(total)} | {cls} |")
    lines.append("")
    lines.append("**Type legend**: `UI` = build phase over budget, `RASTER` = raster phase over budget, `BOTH` = both, `OK` = under budget on both (still in worst-10 by total).")
    lines.append("")
    lines.append("## Sustained jank runs (≥3 consecutive janky frames)")
    lines.append("")
    if a["jank_runs"]:
        lines.append("| Frames | Length | Max build | Max raster |")
        lines.append("|---|---:|---:|---:|")
        for run in a["jank_runs"]:
            lines.append(
                f"| {run['start_frame']}–{run['end_frame']} | {run['length']} | "
                f"{fmt_ms(run['max_build_us'])} | {fmt_ms(run['max_raster_us'])} |"
            )
        lines.append("")
        lines.append("_Sustained runs indicate the user **sees** continuous lag (scrolling stutter, animation hitch). Isolated spikes between runs are individual stutters._")
    else:
        lines.append("_No sustained runs detected → jank in this scenario is **isolated spikes**, not continuous lag._")
    lines.append("")
    return "\n".join(lines)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("input", help="Path to DevTools performance export JSON")
    ap.add_argument("--scenario", help="Scenario label for the report (default: filename stem)")
    ap.add_argument("--out", help="Output markdown path (default: stdout)")
    args = ap.parse_args()

    path = Path(args.input)
    scenario = args.scenario or path.stem
    frames, meta = load_frames(path)
    analysis = analyze(frames, meta)
    report = render_report(scenario, analysis)
    if args.out:
        Path(args.out).write_text(report)
        print(f"Wrote {args.out}")
    else:
        print(report)


if __name__ == "__main__":
    main()
