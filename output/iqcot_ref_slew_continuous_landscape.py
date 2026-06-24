#!/usr/bin/env python3
"""R023 continuous ref-slew landscape analysis for four-phase IQCOT.

This is a post-processing script only.  It reads completed dense+long Simulink
switching results and estimates local continuous T_slew candidates.  The
quadratic candidates are hypotheses for future simulation, not verified global
optima.
"""

from __future__ import annotations

import csv
import math
from collections import defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "output"
FIG = OUT / "figures"

INPUT = OUT / "iqcot_dynamic_ref_slew_dense_long_combined_scores.csv"
SUMMARY = OUT / "iqcot_ref_slew_continuous_landscape_summary.csv"
GRID = OUT / "iqcot_ref_slew_continuous_landscape_grid.csv"
REPORT = OUT / "iqcot_ref_slew_continuous_landscape_report.md"
PAPER_SECTION = OUT / "iqcot_ref_slew_continuous_landscape_paper_section.md"
FIGURE = FIG / "fig30_ref_slew_continuous_landscape.svg"

OBJECTIVES = [
    ("base", "tradeoff_score"),
    ("score_settle005", "score_settle005"),
    ("score_settle010", "score_settle010"),
]


def fnum(x: object) -> float:
    if x is None:
        return math.nan
    text = str(x).strip().strip('"')
    if not text or text.lower() == "nan":
        return math.nan
    return float(text)


def target_label(target: float) -> str:
    if target < 0.01:
        return "near0A"
    return f"{target:g}A"


def read_rows() -> list[dict[str, float]]:
    with INPUT.open("r", encoding="utf-8-sig", newline="") as fp:
        rows = []
        for row in csv.DictReader(fp):
            rows.append({k: fnum(v) for k, v in row.items()})
    rows.sort(key=lambda r: (r["target_load_A"], r["ref_slew_us"]))
    return rows


def interp(x: float, xs: list[float], ys: list[float]) -> float:
    if x <= xs[0]:
        return ys[0]
    if x >= xs[-1]:
        return ys[-1]
    for i in range(len(xs) - 1):
        if xs[i] <= x <= xs[i + 1]:
            span = xs[i + 1] - xs[i]
            if span == 0:
                return ys[i]
            a = (x - xs[i]) / span
            return ys[i] * (1.0 - a) + ys[i + 1] * a
    return ys[-1]


def quadratic_fit(points: list[tuple[float, float]]) -> tuple[float, float, float]:
    (x1, y1), (x2, y2), (x3, y3) = points
    den = (x1 - x2) * (x1 - x3) * (x2 - x3)
    if abs(den) < 1e-12:
        return math.nan, math.nan, math.nan
    a = (x3 * (y2 - y1) + x2 * (y1 - y3) + x1 * (y3 - y2)) / den
    b = (x3 * x3 * (y1 - y2) + x2 * x2 * (y3 - y1) + x1 * x1 * (y2 - y3)) / den
    c = (
        x2 * x3 * (x2 - x3) * y1
        + x3 * x1 * (x3 - x1) * y2
        + x1 * x2 * (x1 - x2) * y3
    ) / den
    return a, b, c


def select_local_points(samples: list[dict[str, float]], score_col: str) -> list[tuple[float, float]]:
    ranked = sorted(samples, key=lambda r: (r[score_col], r["ref_slew_us"]))
    best_t = ranked[0]["ref_slew_us"]
    ordered = sorted(samples, key=lambda r: r["ref_slew_us"])
    idx = next(i for i, r in enumerate(ordered) if r["ref_slew_us"] == best_t)
    if idx == 0:
        chosen = ordered[:3]
    elif idx == len(ordered) - 1:
        chosen = ordered[-3:]
    else:
        chosen = [ordered[idx - 1], ordered[idx], ordered[idx + 1]]
    return [(r["ref_slew_us"], r[score_col]) for r in chosen]


def contiguous_segments(values: list[float]) -> str:
    if not values:
        return ""
    xs = sorted(set(int(round(v)) for v in values))
    segments: list[tuple[int, int]] = []
    start = prev = xs[0]
    for x in xs[1:]:
        if x == prev + 1:
            prev = x
        else:
            segments.append((start, prev))
            start = prev = x
    segments.append((start, prev))
    return ";".join(f"{a}-{b}" if a != b else f"{a}" for a, b in segments)


def interval_from_grid(grid_rows: list[dict[str, float]], score_col: str, threshold: float) -> tuple[float, float, float, str]:
    selected = [r for r in grid_rows if r[score_col] <= threshold]
    if not selected:
        return math.nan, math.nan, 0.0, ""
    lo = min(r["ref_slew_us"] for r in selected)
    hi = max(r["ref_slew_us"] for r in selected)
    return lo, hi, hi - lo, contiguous_segments([r["ref_slew_us"] for r in selected])


def classify_shape(samples: list[dict[str, float]], score_col: str) -> str:
    ordered = sorted(samples, key=lambda r: r["ref_slew_us"])
    ys = [r[score_col] for r in ordered]
    imin = min(range(len(ys)), key=lambda i: ys[i])
    left_ok = all(ys[i] >= ys[i + 1] - 1e-9 for i in range(0, max(0, imin)))
    right_ok = all(ys[i] <= ys[i + 1] + 1e-9 for i in range(imin, len(ys) - 1))
    if left_ok and right_ok and 0 < imin < len(ys) - 1:
        return "quasi_unimodal"
    if imin == 0 or imin == len(ys) - 1:
        return "boundary_minimum"
    return "nonmonotone_or_noisy"


def analyze() -> tuple[list[dict[str, object]], list[dict[str, object]]]:
    rows = read_rows()
    by_target: dict[float, list[dict[str, float]]] = defaultdict(list)
    for row in rows:
        by_target[row["target_load_A"]].append(row)

    summary_rows: list[dict[str, object]] = []
    grid_rows_out: list[dict[str, object]] = []

    for target, samples in sorted(by_target.items(), reverse=True):
        samples = sorted(samples, key=lambda r: r["ref_slew_us"])
        xs = [r["ref_slew_us"] for r in samples]
        min_t, max_t = int(min(xs)), int(max(xs))
        grid: list[dict[str, float]] = []
        for t in range(min_t, max_t + 1):
            g: dict[str, float] = {
                "target_load_A": target,
                "ref_slew_us": float(t),
                "undershoot_mV": interp(t, xs, [r["undershoot_mV"] for r in samples]),
                "settle_time_us": interp(t, xs, [r["settle_time_us"] for r in samples]),
                "phase_spacing_std_ns": interp(t, xs, [r["final_phase_spacing_std_ns"] for r in samples]),
                "skip_count_est": interp(t, xs, [r["skip_count_est"] for r in samples]),
            }
            for obj, score_col in OBJECTIVES:
                g[score_col] = interp(t, xs, [r[score_col] for r in samples])
            grid.append(g)

        for obj, score_col in OBJECTIVES:
            sampled_best = min(samples, key=lambda r: (r[score_col], r["ref_slew_us"]))
            sampled_best_t = sampled_best["ref_slew_us"]
            sampled_best_score = sampled_best[score_col]
            shape = classify_shape(samples, score_col)

            pts = select_local_points(samples, score_col)
            a, b, c = quadratic_fit(pts)
            lo_pts, hi_pts = min(p[0] for p in pts), max(p[0] for p in pts)
            quad_t = sampled_best_t
            quad_score = sampled_best_score
            quad_valid = False
            if math.isfinite(a) and a > 0:
                cand = -b / (2 * a)
                if lo_pts <= cand <= hi_pts:
                    val = a * cand * cand + b * cand + c
                    if val <= sampled_best_score + 0.25:
                        quad_t, quad_score, quad_valid = cand, val, True

            gain = max(0.0, sampled_best_score - quad_score)
            tol025 = interval_from_grid(grid, score_col, sampled_best_score + 0.25)
            tol050 = interval_from_grid(grid, score_col, sampled_best_score + 0.50)

            # Conservative "safe design band": score near optimum, no additional
            # interpolated skip count beyond the sampled best, and phase std below
            # 120 ns. This is a design heuristic, not a hardware safety proof.
            safe = [
                r
                for r in grid
                if r[score_col] <= sampled_best_score + 0.50
                and r["skip_count_est"] <= sampled_best["skip_count_est"] + 0.1
                and r["phase_spacing_std_ns"] <= 120.0
            ]
            if safe:
                safe_lo = min(r["ref_slew_us"] for r in safe)
                safe_hi = max(r["ref_slew_us"] for r in safe)
                safe_segments = contiguous_segments([r["ref_slew_us"] for r in safe])
            else:
                safe_lo = safe_hi = math.nan
                safe_segments = ""

            if gain < 0.05:
                decision = "discrete_grid_sufficient"
            elif gain < 0.20:
                decision = "fine_sweep_candidate"
            else:
                decision = "requires_new_switching_validation"

            summary_rows.append(
                {
                    "target_load_A": target,
                    "target_label": target_label(target),
                    "objective": obj,
                    "sampled_best_us": sampled_best_t,
                    "sampled_best_score": sampled_best_score,
                    "local_quad_candidate_us": quad_t,
                    "local_quad_est_score": quad_score,
                    "estimated_continuous_gain": gain,
                    "quad_valid": int(quad_valid),
                    "local_fit_points_us": "/".join(f"{p[0]:g}" for p in pts),
                    "shape_class": shape,
                    "near_opt_0p25_lo_us": tol025[0],
                    "near_opt_0p25_hi_us": tol025[1],
                    "near_opt_0p25_width_us": tol025[2],
                    "near_opt_0p25_segments_us": tol025[3],
                    "near_opt_0p50_lo_us": tol050[0],
                    "near_opt_0p50_hi_us": tol050[1],
                    "near_opt_0p50_width_us": tol050[2],
                    "near_opt_0p50_segments_us": tol050[3],
                    "safe_band_lo_us": safe_lo,
                    "safe_band_hi_us": safe_hi,
                    "safe_band_segments_us": safe_segments,
                    "sampled_best_undershoot_mV": sampled_best["undershoot_mV"],
                    "sampled_best_settle_time_us": sampled_best["settle_time_us"],
                    "sampled_best_phase_std_ns": sampled_best["final_phase_spacing_std_ns"],
                    "sampled_best_skip_count": sampled_best["skip_count_est"],
                    "decision": decision,
                    "boundary": "quadratic candidate is a hypothesis from existing samples, not a verified global optimum",
                }
            )

        for g in grid:
            for obj, score_col in OBJECTIVES:
                grid_rows_out.append(
                    {
                        "target_load_A": target,
                        "target_label": target_label(target),
                        "objective": obj,
                        "ref_slew_us": g["ref_slew_us"],
                        "interp_score": g[score_col],
                        "interp_undershoot_mV": g["undershoot_mV"],
                        "interp_settle_time_us": g["settle_time_us"],
                        "interp_phase_spacing_std_ns": g["phase_spacing_std_ns"],
                        "interp_skip_count_est": g["skip_count_est"],
                    }
                )

    return summary_rows, grid_rows_out


def write_csv(path: Path, rows: list[dict[str, object]]) -> None:
    if not rows:
        raise ValueError(f"no rows for {path}")
    path.parent.mkdir(parents=True, exist_ok=True)
    fields = list(rows[0].keys())
    with path.open("w", encoding="utf-8", newline="") as fp:
        writer = csv.DictWriter(fp, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)


def fmt(x: object, digits: int = 3) -> str:
    try:
        if isinstance(x, str):
            return x
        return f"{float(x):.{digits}f}"
    except Exception:
        return str(x)


def markdown_table(rows: list[dict[str, object]], fields: list[str]) -> str:
    lines = ["| " + " | ".join(fields) + " |", "| " + " | ".join(["---"] * len(fields)) + " |"]
    for row in rows:
        lines.append("| " + " | ".join(fmt(row.get(f, "")) for f in fields) + " |")
    return "\n".join(lines)


def make_svg(summary_rows: list[dict[str, object]]) -> None:
    FIG.mkdir(parents=True, exist_ok=True)
    width, height = 960, 540
    margin_l, margin_t = 64, 50
    panel_w, panel_h = 260, 118
    gap_x, gap_y = 34, 34
    colors = {"base": "#2563eb", "score_settle005": "#059669", "score_settle010": "#dc2626"}
    targets = ["20A", "10A", "near0A"]
    objectives = ["base", "score_settle005", "score_settle010"]
    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        '<rect width="100%" height="100%" fill="white"/>',
        '<text x="24" y="28" font-size="18" font-family="Arial" font-weight="bold">R023 continuous T_slew local landscape</text>',
        '<text x="24" y="47" font-size="12" font-family="Arial" fill="#555">Dots: sampled best. Cross: local quadratic candidate. Candidate is not a verified global optimum.</text>',
    ]
    lookup = {(str(r["target_label"]), str(r["objective"])): r for r in summary_rows}
    max_gain = max(float(r["estimated_continuous_gain"]) for r in summary_rows) or 1.0
    for row_i, target in enumerate(targets):
        for col_i, obj in enumerate(objectives):
            r = lookup[(target, obj)]
            x0 = margin_l + col_i * (panel_w + gap_x)
            y0 = margin_t + row_i * (panel_h + gap_y)
            parts.append(f'<rect x="{x0}" y="{y0}" width="{panel_w}" height="{panel_h}" fill="#fafafa" stroke="#ddd"/>')
            parts.append(f'<text x="{x0+8}" y="{y0+18}" font-size="12" font-family="Arial" font-weight="bold">{target} / {obj}</text>')
            # x scale over 20-120 us, y as gain bar.
            sx = lambda t: x0 + 24 + (float(t) - 20.0) / 100.0 * (panel_w - 48)
            ymid = y0 + 72
            parts.append(f'<line x1="{x0+24}" y1="{ymid}" x2="{x0+panel_w-24}" y2="{ymid}" stroke="#bbb"/>')
            parts.append(f'<text x="{x0+20}" y="{ymid+18}" font-size="10" font-family="Arial" fill="#666">20</text>')
            parts.append(f'<text x="{x0+panel_w-43}" y="{ymid+18}" font-size="10" font-family="Arial" fill="#666">120 us</text>')
            st = float(r["sampled_best_us"])
            qt = float(r["local_quad_candidate_us"])
            gain = float(r["estimated_continuous_gain"])
            parts.append(f'<circle cx="{sx(st):.1f}" cy="{ymid}" r="5" fill="{colors[obj]}"/>')
            parts.append(f'<line x1="{sx(qt)-5:.1f}" y1="{ymid-11}" x2="{sx(qt)+5:.1f}" y2="{ymid-1}" stroke="#111" stroke-width="1.5"/>')
            parts.append(f'<line x1="{sx(qt)-5:.1f}" y1="{ymid-1}" x2="{sx(qt)+5:.1f}" y2="{ymid-11}" stroke="#111" stroke-width="1.5"/>')
            bar_w = 0 if max_gain == 0 else (panel_w - 48) * gain / max_gain
            parts.append(f'<rect x="{x0+24}" y="{y0+92}" width="{bar_w:.1f}" height="10" fill="{colors[obj]}" opacity="0.65"/>')
            parts.append(f'<text x="{x0+24}" y="{y0+112}" font-size="10" font-family="Arial" fill="#333">sample {st:.0f}us, cand {qt:.1f}us, gain {gain:.3f}</text>')
    parts.append("</svg>")
    FIGURE.write_text("\n".join(parts), encoding="utf-8")


def write_reports(summary_rows: list[dict[str, object]]) -> None:
    ordered = sorted(summary_rows, key=lambda r: (float(r["target_load_A"]), str(r["objective"])), reverse=True)
    max_gain = max(float(r["estimated_continuous_gain"]) for r in summary_rows)
    meaningful = [r for r in summary_rows if float(r["estimated_continuous_gain"]) >= 0.20]
    fine = [r for r in summary_rows if 0.05 <= float(r["estimated_continuous_gain"]) < 0.20]
    discrete = [r for r in summary_rows if float(r["estimated_continuous_gain"]) < 0.05]

    report = f"""# R023 连续 `T_slew` 分数景观与安全区间后处理

## 目的

R022 说明离散候选策略的可解释监督层能够近似 delayed-reference 策略排序，但仍停留在固定 `30/40/50/60/80 us` 等标签。R023 使用已有 dense+long 开关级 sweep，评估连续 `T_slew` 动作是否值得进入下一轮 Simulink 验证。

本实验只做后处理，不运行新的 `.slx`。局部二次候选点是“下一轮仿真候选”，不是全局最优，也不是硬件结果。

## 方法

- 输入：`E:/Desktop/codex/output/iqcot_dynamic_ref_slew_dense_long_combined_scores.csv`，覆盖 `T_slew=20/30/40/50/60/80/100/120 us`、`3` 个切载目标。
- 对每个目标和目标函数，选择采样最优点附近三点做局部二次拟合。
- 在 `20-120 us` 内做 `1 us` piecewise-linear 重采样，计算 `best+0.25` 与 `best+0.50` 的 near-optimal 区间。
- 额外给出一个保守设计带：`score <= best+0.50`、插值 skip 不高于采样最优、phase std 不超过 `120 ns`。这只是设计启发，不是安全证明。

## 汇总结果

{markdown_table(ordered, ["target_label", "objective", "sampled_best_us", "sampled_best_score", "local_quad_candidate_us", "local_quad_est_score", "estimated_continuous_gain", "near_opt_0p50_segments_us", "safe_band_segments_us", "decision"])}

## 关键观察

1. 最大局部二次估计收益为 `{fmt(max_gain)}` 分；这表明连续动作可能带来细小收益，但没有证据支持“连续回归会大幅超过当前采样表”。
2. `{len(discrete)}` 个目标/工况的估计收益低于 `0.05`，可视为当前离散网格已足够；`{len(fine)}` 个目标/工况适合做小范围更细 sweep；`{len(meaningful)}` 个目标/工况需要新开关级仿真确认。
3. near-optimal 区间通常比单点最优更有工程意义。AI 监督层可以优先学习“安全区间内选择”，而不是执着输出一个尖锐最优 `T_slew`。
4. 若后续训练连续动作 AI，reward 应惩罚超出 near-optimal/safe band 的动作，并保留 `tau_AI` 延迟缓冲；AI 仍不能替代 IQCOT 内环。

## 输出文件

- `E:/Desktop/codex/output/iqcot_ref_slew_continuous_landscape_summary.csv`
- `E:/Desktop/codex/output/iqcot_ref_slew_continuous_landscape_grid.csv`
- `E:/Desktop/codex/output/figures/fig30_ref_slew_continuous_landscape.svg`

## 结论边界

- 不声称任何局部二次候选是全局最优。
- 不声称插值曲线等于新的开关级仿真。
- 不把 safe band 当成硬件安全证明。
- 该结果只用于指导下一轮更细 `T_slew` sweep 或连续动作 AI 前置训练。
"""

    paper = f"""### 10.4 连续 `T_slew` 动作的分数景观前置分析

R022 的可解释监督层仍在离散候选策略集合中选择动作。为判断连续 `T_slew` 回归是否值得进入下一轮仿真，本文进一步对 dense+long 参考斜率 sweep 做局部连续景观分析。输入数据覆盖 `20/30/40/50/60/80/100/120 us`、三个切载目标和三个目标函数；对每个目标函数，在采样最优点附近三点拟合局部二次曲线，并在 `20-120 us` 内用 `1 us` 网格计算 near-optimal 区间。

结果显示，局部二次插值的最大估计收益为 `{fmt(max_gain)}` 分，多数目标函数的潜在连续收益低于 `0.05` 或只适合小范围细扫。这意味着连续动作的价值不应被写成“必然大幅优于离散表”，而应写成两个更稳的结论：第一，当前离散网格已经给出较强基线；第二，连续 `T_slew` 更适合作为在 near-optimal 区间内进行平滑调度和安全投影的变量，而不是寻找一个尖锐全局最优点。

因此，下一步若接入连续动作 AI，应先围绕局部二次候选和 near-optimal 区间追加少量开关级验证点，再训练 `s_phi(z,T_slew)->score` 或 `pi_phi(z)->T_slew`。这些候选点仍只是由已有样本推断出的仿真建议，不是新的开关级或硬件证据。
"""

    REPORT.write_text(report, encoding="utf-8")
    PAPER_SECTION.write_text(paper, encoding="utf-8")


def main() -> None:
    summary_rows, grid_rows = analyze()
    write_csv(SUMMARY, summary_rows)
    write_csv(GRID, grid_rows)
    make_svg(summary_rows)
    write_reports(summary_rows)
    print(f"summary_rows={len(summary_rows)}")
    print(f"grid_rows={len(grid_rows)}")
    print(f"wrote={SUMMARY}")
    print(f"wrote={REPORT}")


if __name__ == "__main__":
    main()
