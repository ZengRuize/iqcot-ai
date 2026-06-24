#!/usr/bin/env python3
"""Post-process R031 minimal held-out derived-Simulink validation.

This script combines:
- R031 minimal validation chunk results,
- matching R030 dense-anchor baseline rows, and
- matching R030 original proxy rows.

It recomputes context-level regret within (target_label, objective, tau_ai_us)
for candidate-vs-baseline analysis.  The evidence is derived-Simulink replay,
not hardware validation and not proof of global T_slew optimality.
"""

from __future__ import annotations

from pathlib import Path

import pandas as pd


ROOT = Path("E:/Desktop/codex")
OUT = ROOT / "output"
FIG = OUT / "figures"

R031_CHUNKS = [
    OUT / "iqcot_r027_proxy_table_in_loop_results_r031_minimal_rows001_008.csv",
    OUT / "iqcot_r027_proxy_table_in_loop_results_r031_minimal_rows009_016.csv",
    OUT / "iqcot_r027_proxy_table_in_loop_results_r031_minimal_rows017_022.csv",
]
R030_COMBINED = OUT / "iqcot_r030_dense_anchor_challenge_results_combined.csv"

COMBINED = OUT / "iqcot_r031_minimal_validation_results_combined.csv"
CONTEXT = OUT / "iqcot_r031_minimal_validation_context_summary.csv"
FAMILY = OUT / "iqcot_r031_minimal_validation_family_summary.csv"
REPORT = OUT / "iqcot_r031_minimal_validation_report.md"
PAPER = OUT / "iqcot_r031_minimal_validation_paper_section.md"
SVG = FIG / "fig42_r031_minimal_validation.svg"

CTX = ["target_label", "objective", "tau_ai_us"]
DENSE = "discrete_dense_long_table"
PROXY = "calibrated_risk_proxy_projection"


def f3(x: float) -> str:
    return f"{float(x):.3f}"


def read_inputs() -> tuple[pd.DataFrame, pd.DataFrame]:
    missing = [p for p in [*R031_CHUNKS, R030_COMBINED] if not p.exists()]
    if missing:
        raise FileNotFoundError(", ".join(str(p) for p in missing))
    r031 = pd.concat((pd.read_csv(p) for p in R031_CHUNKS), ignore_index=True)
    r030 = pd.read_csv(R030_COMBINED)
    return r031, r030


def normalize_rows(df: pd.DataFrame, family: str) -> pd.DataFrame:
    out = df.copy()
    out["candidate_family"] = family
    out["tau_ai_us"] = out["tau_ai_us"].astype(float)
    out["selected_ref_slew_us"] = out["selected_ref_slew_us"].astype(float)
    out["selected_objective_score"] = out["selected_objective_score"].astype(float)
    for col in [
        "base_score",
        "score_settle005",
        "score_settle010",
        "undershoot_mV",
        "settle_time_us",
        "skip_count_est",
        "final_phase_spacing_std_ns",
        "final_vout_error_mV",
    ]:
        out[col] = pd.to_numeric(out[col], errors="coerce")
    return out


def build_combined(r031: pd.DataFrame, r030: pd.DataFrame) -> pd.DataFrame:
    contexts = r031[CTX].drop_duplicates()
    r030_match = r030.merge(contexts, on=CTX, how="inner")
    r030_match = r030_match[r030_match["policy"].isin([DENSE, PROXY])].copy()
    r030_match["candidate_family"] = r030_match["policy"].map(
        {DENSE: "r030_dense_baseline", PROXY: "r030_original_proxy"}
    )
    r031 = normalize_rows(r031, "r031_intermediate_candidate")
    r030_match = normalize_rows(r030_match, "r030")
    # Restore family labels overwritten by normalize_rows.
    r030_match["candidate_family"] = r030_match["policy"].map(
        {DENSE: "r030_dense_baseline", PROXY: "r030_original_proxy"}
    )
    common_cols = [
        "success",
        "error_message",
        "r027_case_id",
        "target_label",
        "objective",
        "policy",
        "candidate_family",
        "objective_alpha_settle",
        "target_load_A",
        "load_drop_A",
        "selected_ref_slew_us",
        "tau_ai_us",
        "delay_events",
        "ref_start_delay_us",
        "selected_objective_score",
        "base_score",
        "score_settle005",
        "score_settle010",
        "undershoot_mV",
        "settle_time_us",
        "skip_count_est",
        "final_phase_spacing_std_ns",
        "final_vout_error_mV",
        "final_il_phase_imbalance_A",
    ]
    combined = pd.concat(
        [r030_match[common_cols], r031[common_cols]],
        ignore_index=True,
    )
    combined = combined.sort_values(CTX + ["candidate_family", "selected_ref_slew_us"]).reset_index(drop=True)
    combined["context_best_score"] = combined.groupby(CTX)["selected_objective_score"].transform("min")
    combined["context_regret"] = combined["selected_objective_score"] - combined["context_best_score"]
    return combined


def build_context_summary(combined: pd.DataFrame) -> pd.DataFrame:
    rows: list[dict[str, object]] = []
    for key, group in combined.groupby(CTX, sort=True):
        target, objective, tau = key
        best = group.loc[group["selected_objective_score"].idxmin()]
        dense = group[group["candidate_family"] == "r030_dense_baseline"].iloc[0]
        proxy = group[group["candidate_family"] == "r030_original_proxy"].iloc[0]
        r031_group = group[group["candidate_family"] == "r031_intermediate_candidate"]
        r031_best = r031_group.loc[r031_group["selected_objective_score"].idxmin()]
        rows.append(
            {
                "target_label": target,
                "objective": objective,
                "tau_ai_us": float(tau),
                "best_family": best["candidate_family"],
                "best_slew_us": float(best["selected_ref_slew_us"]),
                "best_score": float(best["selected_objective_score"]),
                "dense_slew_us": float(dense["selected_ref_slew_us"]),
                "dense_score": float(dense["selected_objective_score"]),
                "dense_regret": float(dense["context_regret"]),
                "proxy_slew_us": float(proxy["selected_ref_slew_us"]),
                "proxy_score": float(proxy["selected_objective_score"]),
                "proxy_regret": float(proxy["context_regret"]),
                "r031_best_slew_us": float(r031_best["selected_ref_slew_us"]),
                "r031_best_score": float(r031_best["selected_objective_score"]),
                "r031_best_regret": float(r031_best["context_regret"]),
                "r031_minus_dense_score": float(r031_best["selected_objective_score"] - dense["selected_objective_score"]),
                "r031_minus_proxy_score": float(r031_best["selected_objective_score"] - proxy["selected_objective_score"]),
                "r031_beats_dense": bool(r031_best["selected_objective_score"] < dense["selected_objective_score"]),
                "r031_beats_proxy": bool(r031_best["selected_objective_score"] < proxy["selected_objective_score"]),
                "best_undershoot_mV": float(best["undershoot_mV"]),
                "best_settle_time_us": float(best["settle_time_us"]),
                "best_skip_count_est": float(best["skip_count_est"]),
                "best_phase_std_ns": float(best["final_phase_spacing_std_ns"]),
                "best_final_error_mV": float(best["final_vout_error_mV"]),
            }
        )
    return pd.DataFrame(rows).sort_values(CTX).reset_index(drop=True)


def build_family_summary(combined: pd.DataFrame) -> pd.DataFrame:
    valid = combined.copy()
    summary = (
        valid.groupby("candidate_family", as_index=False)
        .agg(
            n_rows=("selected_objective_score", "count"),
            mean_context_regret=("context_regret", "mean"),
            max_context_regret=("context_regret", "max"),
            mean_objective_score=("selected_objective_score", "mean"),
            mean_undershoot_mV=("undershoot_mV", "mean"),
            mean_settle_time_us=("settle_time_us", "mean"),
            mean_skip_count=("skip_count_est", "mean"),
            best_context_count=("context_regret", lambda s: int((s.abs() <= 1e-9).sum())),
        )
        .sort_values(["mean_context_regret", "max_context_regret", "candidate_family"])
        .reset_index(drop=True)
    )
    return summary


def md_table(df: pd.DataFrame, cols: list[str], max_rows: int | None = None) -> str:
    if max_rows is not None:
        df = df.head(max_rows)
    lines = [
        "| " + " | ".join(cols) + " |",
        "| " + " | ".join(["---"] * len(cols)) + " |",
    ]
    for _, row in df[cols].iterrows():
        vals = []
        for col in cols:
            val = row[col]
            if isinstance(val, float):
                vals.append(f"{val:.3f}")
            else:
                vals.append(str(val))
        lines.append("| " + " | ".join(vals) + " |")
    return "\n".join(lines)


def write_figure(context: pd.DataFrame, family: pd.DataFrame) -> None:
    FIG.mkdir(parents=True, exist_ok=True)
    width, height = 1180, 540
    left, top = 80, 70
    plot_w, plot_h = 610, 300
    values = context["r031_minus_dense_score"].astype(float).to_list()
    vmax = max(0.2, max(abs(v) for v in values) * 1.25)
    zero_y = top + plot_h / 2
    scale = (plot_h / 2) / vmax
    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        '<rect width="100%" height="100%" fill="white"/>',
        '<text x="590" y="32" text-anchor="middle" font-family="Arial" font-size="18">R031 minimal held-out derived-Simulink validation</text>',
        f'<rect x="{left}" y="{top}" width="{plot_w}" height="{plot_h}" fill="#fbfbfb" stroke="#ddd"/>',
        f'<line x1="{left}" y1="{zero_y:.1f}" x2="{left+plot_w}" y2="{zero_y:.1f}" stroke="#333" stroke-width="1"/>',
        f'<text x="{left}" y="{top-18}" font-family="Arial" font-size="13">R031 best candidate minus dense score (negative is better)</text>',
    ]
    for frac in [-1, -0.5, 0, 0.5, 1]:
        y = zero_y - frac * vmax * scale
        parts.append(f'<line x1="{left-4}" y1="{y:.1f}" x2="{left+plot_w}" y2="{y:.1f}" stroke="#eee"/>')
        parts.append(f'<text x="{left-10}" y="{y+4:.1f}" text-anchor="end" font-family="Arial" font-size="10">{frac*vmax:.2f}</text>')
    bar_step = plot_w / len(context)
    bar_w = min(42, bar_step * 0.65)
    for i, row in enumerate(context.itertuples()):
        val = float(row.r031_minus_dense_score)
        x = left + i * bar_step + (bar_step - bar_w) / 2
        y = zero_y - max(val, 0) * scale
        h = abs(val) * scale
        color = "#54A24B" if val < 0 else "#E45756"
        if val < 0:
            y = zero_y
        parts.append(f'<rect x="{x:.1f}" y="{y:.1f}" width="{bar_w:.1f}" height="{h:.1f}" fill="{color}"/>')
        parts.append(f'<text x="{x+bar_w/2:.1f}" y="{y-5 if val>=0 else y+h+13:.1f}" text-anchor="middle" font-family="Arial" font-size="9">{val:.2f}</text>')
        label = f"{row.target_label}/{row.objective.replace('score_', '')}/τ={row.tau_ai_us:g}"
        tx = x + bar_w / 2
        ty = top + plot_h + 20
        parts.append(f'<text x="{tx:.1f}" y="{ty:.1f}" text-anchor="end" transform="rotate(-45 {tx:.1f},{ty:.1f})" font-family="Arial" font-size="9">{label}</text>')

    right_x, right_y = 760, 88
    parts.append(f'<text x="{right_x}" y="{right_y-28}" font-family="Arial" font-size="13">Family mean context regret</text>')
    max_reg = max(0.1, float(family["mean_context_regret"].max()) * 1.2)
    bar_area_w = 330
    bar_area_h = 230
    parts.append(f'<rect x="{right_x}" y="{right_y}" width="{bar_area_w}" height="{bar_area_h}" fill="#fbfbfb" stroke="#ddd"/>')
    f_step = bar_area_w / len(family)
    for i, row in enumerate(family.itertuples()):
        val = float(row.mean_context_regret)
        h = val / max_reg * (bar_area_h - 30)
        x = right_x + i * f_step + 24
        y = right_y + bar_area_h - h - 24
        bw = min(62, f_step * 0.55)
        parts.append(f'<rect x="{x:.1f}" y="{y:.1f}" width="{bw:.1f}" height="{h:.1f}" fill="#4C78A8"/>')
        parts.append(f'<text x="{x+bw/2:.1f}" y="{y-6:.1f}" text-anchor="middle" font-family="Arial" font-size="10">{val:.3f}</text>')
        label = row.candidate_family.replace("r030_", "").replace("r031_", "").replace("_", " ")
        tx = x + bw / 2
        ty = right_y + bar_area_h + 20
        parts.append(f'<text x="{tx:.1f}" y="{ty:.1f}" text-anchor="end" transform="rotate(-35 {tx:.1f},{ty:.1f})" font-family="Arial" font-size="9">{label}</text>')
    parts.append("</svg>")
    SVG.write_text("\n".join(parts), encoding="utf-8")


def write_reports(context: pd.DataFrame, family: pd.DataFrame) -> None:
    n_contexts = len(context)
    r031_beats_dense = int(context["r031_beats_dense"].sum())
    r031_beats_proxy = int(context["r031_beats_proxy"].sum())
    best_counts = context["best_family"].value_counts().to_dict()
    r031_mean_delta = float(context["r031_minus_dense_score"].mean())

    report = f"""# R031 Minimal Held-Out Derived-Simulink Validation

## Scope

This report post-processes the completed R031 minimal validation chunks.  It
combines the `22` new R031 intermediate-slope cases with matching R030 dense
baseline and original proxy rows.  All runs use the derived
`four_phase_iek_dynamic_load_refslew.slx` model and delayed `Iph_ref_ts`
profiles.  This is derived-Simulink evidence, not hardware validation.

## Family Summary

{md_table(family, [
    "candidate_family",
    "n_rows",
    "mean_context_regret",
    "max_context_regret",
    "mean_objective_score",
    "mean_undershoot_mV",
    "mean_settle_time_us",
    "mean_skip_count",
    "best_context_count",
])}

## Context Summary

R031 best intermediate candidates beat the dense baseline in `{r031_beats_dense}/{n_contexts}`
contexts and beat the original R030 proxy in `{r031_beats_proxy}/{n_contexts}` contexts.
The mean R031-best minus dense score is `{r031_mean_delta:.3f}`; negative means R031 improves
over dense, positive means it is worse.  Best-family counts are `{best_counts}`.

{md_table(context, [
    "target_label",
    "objective",
    "tau_ai_us",
    "best_family",
    "best_slew_us",
    "dense_score",
    "proxy_score",
    "r031_best_slew_us",
    "r031_best_score",
    "r031_minus_dense_score",
    "best_skip_count_est",
    "best_settle_time_us",
])}

## Interpretation

- `10A/score_settle010`: `31/33us` remain delay-sensitive.  At `tau_AI=1us`
  the dense `30us` baseline remains better, while at `tau_AI=5us` the `33us`
  intermediate candidate improves over dense.  This supports a conservative,
  delay-aware near-tie band rather than a fixed proxy override.
- `20A/base`: intermediate `82/84us` reveals delay-sensitive behavior but does
  not materially beat the dense `80us` baseline in these contexts.  Among the
  intermediate candidates, `82us` is best at `0.5us`, while `84us` is best at
  `2/5us`; this supports a delay-aware band and blocks direct `86us` proxy
  override.
- `20A/score_settle005`: the safer intermediate band is strongly delay
  dependent.  `50us` is best at `0.5/2us`, `38us` is best at `1us`, and
  `58us` is best at `5us`.  This partially rehabilitates intermediate slopes,
  but does not re-admit the original `66us` proxy without short-horizon risk
  prediction.

## Claim Boundary

R031 minimal validation improves the empirical design of `B_epsilon^sw`, but it
does not prove global `T_slew` optimality, does not prove AI/proxy can replace
the IQCOT inner loop, and does not constitute hardware validation.  The safest
claim is that `B_epsilon^sw` should be delay-aware and should admit
intermediate candidate bands only after derived switching replay or a validated
short-horizon event-risk predictor.
"""
    REPORT.write_text(report, encoding="utf-8")

    paper = f"""## R031 最小 held-out 派生验证：`B_epsilon^sw` 的延迟敏感修正

在 R031 tightened projection 完成后，本文进一步执行了 `22` 行最小 held-out
派生 Simulink 验证，并将结果与 R030 中对应的 dense baseline 和原 proxy
行合并。所有工况仍使用派生 `four_phase_iek_dynamic_load_refslew.slx` 与
delayed `Iph_ref_ts`，不修改原始 `.slx`。

结果显示，R031 中间候选不是简单单调改善。`10A/score_settle010` 中，
`tau_AI=1us` 时 dense `30us` 仍优于 `31/33us`，而 `tau_AI=5us` 时
`33us` 反而优于 dense，说明 near-tie 子带应写成延迟敏感局部带。
`20A/base` 中，`82/84us` 没有实质超过 dense `80us`，但中间候选内部
呈现 `0.5us` 偏 `82us`、`2/5us` 偏 `84us` 的延迟分歧，因此仍不应
直接放行 `86us` proxy。`20A/score_settle005` 则出现更明显的模式边界：
`50us` 在 `0.5/2us` 下较好，`38us` 在 `1us` 下较好，`58us` 在 `5us`
下较好。这说明 R030 中 `66us` proxy 不能直接重新放行，但 `38-58us`
中间带值得作为短时 risk predictor 的候选动作集。

因此，R031 held-out 验证把 `B_epsilon^sw` 从静态规则推进为延迟敏感局部带：
AI 或 proxy 可以生成候选 score/risk，但最终动作仍需经过开关级负样本和
held-out 样本校准的投影。该结论仍是派生 Simulink 证据，不是硬件验证，
也不支持 `T_slew` 全局最优或 AI 替代 IQCOT 内环的说法。
"""
    PAPER.write_text(paper, encoding="utf-8")


def main() -> None:
    r031, r030 = read_inputs()
    combined = build_combined(r031, r030)
    context = build_context_summary(combined)
    family = build_family_summary(combined)

    combined.to_csv(COMBINED, index=False)
    context.to_csv(CONTEXT, index=False)
    family.to_csv(FAMILY, index=False)
    write_figure(context, family)
    write_reports(context, family)

    print(f"Wrote {COMBINED}")
    print(f"Wrote {CONTEXT}")
    print(f"Wrote {FAMILY}")
    print(f"Wrote {REPORT}")
    print(f"Wrote {PAPER}")
    print(f"Wrote {SVG}")


if __name__ == "__main__":
    main()
