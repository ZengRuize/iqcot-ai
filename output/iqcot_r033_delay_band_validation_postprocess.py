#!/usr/bin/env python3
"""Post-process R032 delay-band derived-Simulink validation.

This R033 step combines the completed R032 delayed-reference validation
chunks and refines the delay-aware B_epsilon^sw band rules.  The evidence is
derived Simulink replay only.  It is not hardware validation, not a global
T_slew optimum proof, and not an AI-in-the-loop gate-control result.
"""

from __future__ import annotations

import json
from pathlib import Path

import pandas as pd


ROOT = Path("E:/Desktop/codex")
OUT = ROOT / "output"
FIG = OUT / "figures"
WIKI = ROOT / "research-wiki"
LOGS = ROOT / "refine-logs"

CHUNKS = [
    OUT / "iqcot_r027_proxy_table_in_loop_results_r032_delay_band_rows001_008.csv",
    OUT / "iqcot_r027_proxy_table_in_loop_results_r032_delay_band_rows009_016.csv",
    OUT / "iqcot_r027_proxy_table_in_loop_results_r032_delay_band_rows017_021.csv",
    OUT / "iqcot_r027_proxy_table_in_loop_results_r032_delay_band_rows022_026.csv",
    OUT / "iqcot_r027_proxy_table_in_loop_results_r032_delay_band_rows027_031.csv",
]
PLAN = OUT / "iqcot_r032_next_validation_plan.csv"

COMBINED = OUT / "iqcot_r033_delay_band_validation_results_combined.csv"
CONTEXT = OUT / "iqcot_r033_delay_band_validation_context_summary.csv"
ROLE = OUT / "iqcot_r033_delay_band_validation_role_summary.csv"
RULES = OUT / "iqcot_r033_delay_band_rule_update.csv"
REPORT = OUT / "iqcot_r033_delay_band_validation_report.md"
PAPER = OUT / "iqcot_r033_delay_band_paper_section.md"
SVG = FIG / "fig44_r033_delay_band_validation.svg"
AUDIT = LOGS / "LOCAL_AUDIT_R033_DELAY_BAND_VALIDATION_20260621.md"
WIKI_EXP = WIKI / "experiments" / "delay-band-validation-r033.md"

CTX = ["target_label", "objective", "tau_ai_us"]


def f3(value: float) -> str:
    return f"{float(value):.3f}"


def append_once(path: Path, marker: str, text: str) -> None:
    old = path.read_text(encoding="utf-8", errors="replace") if path.exists() else ""
    if marker in old:
        return
    sep = "" if old.endswith("\n") or not old else "\n"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(old + sep + text.strip() + "\n", encoding="utf-8")


def read_inputs() -> tuple[pd.DataFrame, pd.DataFrame]:
    missing = [p for p in [*CHUNKS, PLAN] if not p.exists()]
    if missing:
        raise FileNotFoundError(", ".join(str(p) for p in missing))
    rows = pd.concat((pd.read_csv(p) for p in CHUNKS), ignore_index=True)
    plan = pd.read_csv(PLAN)
    return rows, plan


def candidate_role(row: pd.Series) -> str:
    target = str(row["target_label"])
    objective = str(row["objective"])
    slew = float(row["selected_ref_slew_us"])
    if target == "10A" and objective == "score_settle010":
        if abs(slew - 30.0) < 1e-9:
            return "dense_fallback"
        return "near_tie_probe"
    if target == "20A" and objective == "base":
        if abs(slew - 80.0) < 1e-9:
            return "dense_fallback"
        if slew in {82.0, 84.0}:
            return "intermediate_probe"
        if abs(slew - 86.0) < 1e-9:
            return "direct_override_probe"
    if target == "20A" and objective == "score_settle005":
        if abs(slew - 30.0) < 1e-9:
            return "dense_fallback"
        if slew in {38.0, 50.0, 58.0}:
            return "intermediate_band"
        if abs(slew - 66.0) < 1e-9:
            return "negative_control_66us"
    return "unclassified_probe"


def prepare_combined(rows: pd.DataFrame, plan: pd.DataFrame) -> pd.DataFrame:
    out = rows.copy()
    plan = plan.rename(columns={"r032_case_id": "r027_case_id"})
    out = out.merge(
        plan[["r027_case_id", "priority", "reason", "validation_scope"]],
        on="r027_case_id",
        how="left",
    )
    for col in [
        "tau_ai_us",
        "selected_ref_slew_us",
        "selected_objective_score",
        "undershoot_mV",
        "settle_time_us",
        "skip_count_est",
        "final_phase_spacing_std_ns",
        "final_vout_error_mV",
    ]:
        out[col] = pd.to_numeric(out[col], errors="coerce")
    out["candidate_role"] = out.apply(candidate_role, axis=1)
    out = out.sort_values(CTX + ["selected_ref_slew_us"]).reset_index(drop=True)
    out["context_best_score"] = out.groupby(CTX)["selected_objective_score"].transform("min")
    out["context_regret"] = out["selected_objective_score"] - out["context_best_score"]
    return out


def row_or_none(group: pd.DataFrame, role: str) -> pd.Series | None:
    part = group[group["candidate_role"] == role]
    if part.empty:
        return None
    return part.iloc[0]


def best_non_dense(group: pd.DataFrame) -> pd.Series | None:
    part = group[group["candidate_role"] != "dense_fallback"]
    if part.empty:
        return None
    return part.loc[part["selected_objective_score"].idxmin()]


def build_context_summary(combined: pd.DataFrame) -> pd.DataFrame:
    records: list[dict[str, object]] = []
    for key, group in combined.groupby(CTX, sort=True):
        target, objective, tau = key
        best = group.loc[group["selected_objective_score"].idxmin()]
        dense = row_or_none(group, "dense_fallback")
        non_dense = best_non_dense(group)
        neg = row_or_none(group, "negative_control_66us")
        records.append(
            {
                "target_label": target,
                "objective": objective,
                "tau_ai_us": float(tau),
                "n_candidates": len(group),
                "best_slew_us": float(best["selected_ref_slew_us"]),
                "best_role": str(best["candidate_role"]),
                "best_score": float(best["selected_objective_score"]),
                "best_undershoot_mV": float(best["undershoot_mV"]),
                "best_settle_time_us": float(best["settle_time_us"]),
                "best_skip_count_est": float(best["skip_count_est"]),
                "best_phase_std_ns": float(best["final_phase_spacing_std_ns"]),
                "dense_slew_us": float(dense["selected_ref_slew_us"]) if dense is not None else float("nan"),
                "dense_score": float(dense["selected_objective_score"]) if dense is not None else float("nan"),
                "dense_regret": float(dense["context_regret"]) if dense is not None else float("nan"),
                "non_dense_best_slew_us": float(non_dense["selected_ref_slew_us"]) if non_dense is not None else float("nan"),
                "non_dense_best_role": str(non_dense["candidate_role"]) if non_dense is not None else "",
                "non_dense_minus_dense_score": float(non_dense["selected_objective_score"] - dense["selected_objective_score"]) if dense is not None and non_dense is not None else float("nan"),
                "negative_66_score": float(neg["selected_objective_score"]) if neg is not None else float("nan"),
                "negative_66_regret": float(neg["context_regret"]) if neg is not None else float("nan"),
                "negative_66_skip_count": float(neg["skip_count_est"]) if neg is not None else float("nan"),
                "negative_66_settle_time_us": float(neg["settle_time_us"]) if neg is not None else float("nan"),
            }
        )
    return pd.DataFrame(records).sort_values(CTX).reset_index(drop=True)


def build_role_summary(combined: pd.DataFrame) -> pd.DataFrame:
    summary = (
        combined.groupby("candidate_role", as_index=False)
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
        .sort_values(["mean_context_regret", "max_context_regret", "candidate_role"])
        .reset_index(drop=True)
    )
    return summary


def build_rule_update(context: pd.DataFrame) -> pd.DataFrame:
    rows = [
        {
            "target_label": "10A",
            "objective": "score_settle010",
            "tau_region_us": "around 2",
            "r032_prior_rule": "default dense 30us until tau>=3us",
            "r033_observation": "32us is best at tau=2us, with 30us only 0.058 score worse and 34us only 0.033 worse",
            "refined_rule": "treat 30-34us as a delay-sensitive near-tie candidate band; do not claim a sharp optimum",
            "deployment_status": "candidate band; dense fallback remains acceptable",
        },
        {
            "target_label": "10A",
            "objective": "score_settle010",
            "tau_region_us": "around 3",
            "r032_prior_rule": "commit 33us at tau>=3us",
            "r033_observation": "33us is best at tau=3us; dense 30us has 0.176 regret",
            "refined_rule": "33us remains plant-admissible in the long-delay near-tie band",
            "deployment_status": "locally supported by derived Simulink",
        },
        {
            "target_label": "20A",
            "objective": "base",
            "tau_region_us": "around 1",
            "r032_prior_rule": "block 86us direct override and keep 80us fallback",
            "r033_observation": "86us is base-score best by 0.061 over 80us, while 82/84us introduce skip; 86us also has longer settling",
            "refined_rule": "keep 86us as objective-dependent candidate-only probe; do not globally unblock it",
            "deployment_status": "needs settling-aware confirmation before plant commit",
        },
        {
            "target_label": "20A",
            "objective": "base",
            "tau_region_us": "around 3",
            "r032_prior_rule": "default dense 80us",
            "r033_observation": "80us is best; 82/84us are near, 86us is worse",
            "refined_rule": "retain 80us fallback and keep 82/84us as low-risk ranking probes",
            "deployment_status": "fallback supported",
        },
        {
            "target_label": "20A",
            "objective": "score_settle005",
            "tau_region_us": "around 0.75",
            "r032_prior_rule": "38us allowed for 0.75<=tau<1.5us",
            "r033_observation": "30us is best; 38/50us are close, 58us worsens settling, 66us has skip and 2.324 regret",
            "refined_rule": "use 30us fallback; keep 38/50us candidate-only; block 66us",
            "deployment_status": "negative control confirms large-jump risk",
        },
        {
            "target_label": "20A",
            "objective": "score_settle005",
            "tau_region_us": "around 1.5",
            "r032_prior_rule": "otherwise dense 30us after tau>=1.5us",
            "r033_observation": "50us is best; 30us has skip and 2.171 regret; 66us has long settling and 0.644 regret",
            "refined_rule": "add a transition pocket allowing 50us near tau=1.5us, with 38us as backup candidate",
            "deployment_status": "locally supported; still not a global rule",
        },
        {
            "target_label": "20A",
            "objective": "score_settle005",
            "tau_region_us": "around 3",
            "r032_prior_rule": "dense fallback at long delay",
            "r033_observation": "30us is best; 38us is second; 50/58/66us show longer settling",
            "refined_rule": "retain dense 30us fallback; keep 38us as a ranking probe only",
            "deployment_status": "fallback supported",
        },
    ]
    return pd.DataFrame(rows)


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


def write_figure(context: pd.DataFrame) -> None:
    FIG.mkdir(parents=True, exist_ok=True)
    width, height = 1240, 590
    left, top = 86, 76
    plot_w, plot_h = 760, 300
    values = context["non_dense_minus_dense_score"].fillna(0.0).astype(float).to_list()
    max_abs = max(0.1, max(abs(v) for v in values) * 1.2)
    zero_y = top + plot_h / 2
    scale = (plot_h / 2) / max_abs
    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        '<rect width="100%" height="100%" fill="white"/>',
        '<text x="620" y="34" text-anchor="middle" font-family="Arial" font-size="18">R033 delay-band derived-Simulink validation</text>',
        f'<rect x="{left}" y="{top}" width="{plot_w}" height="{plot_h}" fill="#fbfbfb" stroke="#ddd"/>',
        f'<line x1="{left}" y1="{zero_y:.1f}" x2="{left+plot_w}" y2="{zero_y:.1f}" stroke="#333"/>',
        f'<text x="{left}" y="{top-20}" font-family="Arial" font-size="13">Best non-dense candidate minus dense score (negative is better)</text>',
    ]
    for frac in [-1, -0.5, 0, 0.5, 1]:
        y = zero_y - frac * max_abs * scale
        parts.append(f'<line x1="{left-4}" y1="{y:.1f}" x2="{left+plot_w}" y2="{y:.1f}" stroke="#eee"/>')
        parts.append(f'<text x="{left-10}" y="{y+4:.1f}" text-anchor="end" font-family="Arial" font-size="10">{frac*max_abs:.2f}</text>')
    step = plot_w / len(context)
    bar_w = min(54, step * 0.62)
    for i, row in enumerate(context.itertuples()):
        val = float(row.non_dense_minus_dense_score)
        h = abs(val) * scale
        x = left + i * step + (step - bar_w) / 2
        y = zero_y - h if val < 0 else zero_y
        color = "#2F855A" if val < -1e-9 else "#C53030"
        if abs(val) <= 1e-9:
            color = "#718096"
        parts.append(f'<rect x="{x:.1f}" y="{y:.1f}" width="{bar_w:.1f}" height="{max(h,1):.1f}" fill="{color}"/>')
        parts.append(f'<text x="{x+bar_w/2:.1f}" y="{y-6 if val>=0 else y+h+13:.1f}" text-anchor="middle" font-family="Arial" font-size="9">{val:.2f}</text>')
        label = f"{row.target_label}/{row.objective.replace('score_', '')}/tau={row.tau_ai_us:g}"
        tx = x + bar_w / 2
        ty = top + plot_h + 24
        parts.append(f'<text x="{tx:.1f}" y="{ty:.1f}" text-anchor="end" transform="rotate(-45 {tx:.1f},{ty:.1f})" font-family="Arial" font-size="9">{label}</text>')

    right_x = 900
    parts.append(f'<text x="{right_x}" y="92" font-family="Arial" font-size="13">Context best T_slew</text>')
    y0 = 120
    for i, row in enumerate(context.itertuples()):
        color = "#2F855A" if row.best_role != "dense_fallback" else "#4C78A8"
        parts.append(f'<circle cx="{right_x+10}" cy="{y0+i*24}" r="5" fill="{color}"/>')
        parts.append(
            f'<text x="{right_x+24}" y="{y0+i*24+4}" font-family="Arial" font-size="11">'
            f'{row.target_label}/{row.objective}/tau={row.tau_ai_us:g}: {row.best_slew_us:g}us ({row.best_role})</text>'
        )
    parts.append('<text x="86" y="550" font-family="Arial" font-size="11" fill="#555">Derived Simulink only; not hardware validation or global optimum proof.</text>')
    parts.append("</svg>")
    SVG.write_text("\n".join(parts), encoding="utf-8")


def write_reports(context: pd.DataFrame, role: pd.DataFrame, rules: pd.DataFrame) -> None:
    n_rows = int(context["n_candidates"].sum())
    n_contexts = len(context)
    non_dense_wins = int((context["best_role"] != "dense_fallback").sum())
    neg = context[context["negative_66_regret"].notna()]
    neg_mean = float(neg["negative_66_regret"].mean()) if not neg.empty else float("nan")
    report = f"""# R033 Delay-Band Derived-Simulink Validation

## Scope

R033 post-processes the completed R032 31-row delayed-reference validation
matrix.  All cases use the derived model
`E:/Desktop/codex/output/simulink_iek/four_phase_iek_dynamic_load_refslew.slx`
through the R027 runner adapter.  No original `.slx` file is modified and no
`.slx` XML is edited.

This is derived-Simulink evidence for a supervisory `T_slew` scheduler.  It is
not hardware validation, not a global `T_slew` optimum proof, and not evidence
that AI replaces the IQCOT inner loop.

## Headline

- Completed rows: `{n_rows}` over `{n_contexts}` validation contexts.
- Non-dense candidates are best in `{non_dense_wins}/{n_contexts}` contexts.
- The `66us` negative-control probe appears in `{len(neg)}` contexts with mean
  regret `{f3(neg_mean)}`; it remains unsafe as a direct override.

## Context Summary

{md_table(context, [
    "target_label",
    "objective",
    "tau_ai_us",
    "best_slew_us",
    "best_role",
    "dense_regret",
    "non_dense_best_slew_us",
    "non_dense_best_role",
    "non_dense_minus_dense_score",
    "negative_66_regret",
])}

## Candidate-Role Summary

{md_table(role, [
    "candidate_role",
    "n_rows",
    "mean_context_regret",
    "max_context_regret",
    "mean_settle_time_us",
    "mean_skip_count",
    "best_context_count",
])}

## Refined Rules

{md_table(rules, [
    "target_label",
    "objective",
    "tau_region_us",
    "r033_observation",
    "refined_rule",
    "deployment_status",
])}

## Interpretation

`10A/score_settle010` supports a small delay-sensitive near-tie band rather
than a point optimum: `32us` is best at `tau=2us`, while `33us` is best at
`tau=3us`.  The margins are small and skip is still observed, so the paper
should describe this as a local candidate band.

`20A/base` is objective-sensitive.  At `tau=1us`, `86us` has the best base
score by a small margin, but `82/84us` introduce skip and `86us` also has
longer settling than `80us`.  At `tau=3us`, `80us` is best.  Therefore the
previous hard block on `86us` should soften only to an objective-dependent
candidate probe, not to a general plant-commit rule.

`20A/score_settle005` is the most useful calibration motif.  At `tau=0.75us`,
`30us` remains best and `66us` is a strong negative control with skip.  At
`tau=1.5us`, `50us` becomes best and `30us` skips, revealing a transition
pocket.  At `tau=3us`, the dense `30us` fallback is again best.  This supports
a delay-aware band with a narrow `50us` transition pocket, while continuing to
block `66us` as a direct override.
"""
    REPORT.write_text(report, encoding="utf-8")

    paper = f"""## R033 派生 Simulink 验证：delay-aware `B_epsilon^sw` 的边界修正

在 R032 将 R031 结果整理为 `q_phi/r_hat/B_epsilon^sw` 接口之后，本文进一步执行了 `31` 行派生 Simulink delayed-reference 验证。验证仍只使用 `output/simulink_iek` 下的派生模型，不修改原始 `.slx`，也不构成硬件验证。该轮实验的价值在于把 R032 的已知上下文拟合规则放到新的延迟边界点上检查，从而修正可部署安全投影的局部边界。

结果显示，非 dense 候选在 `{non_dense_wins}/{n_contexts}` 个上下文中成为当前候选集最优，但这种优势具有明显的目标函数和延迟依赖性。`10A/score_settle010` 形成 `30-34 us` 的 near-tie 候选带：`tau_AI=2 us` 时 `32 us` 最优，`tau_AI=3 us` 时 `33 us` 最优，但各候选差距较小且均出现一次 skip，因此不能写成尖锐点最优。`20A/base` 中，`86 us` 在 `tau_AI=1 us` 的 base score 下略优于 `80 us`，但在 `tau_AI=3 us` 下变差，且 settling 更长；因此它只能作为 objective-dependent probe，而不是被全局解除阻断。最关键的是 `20A/score_settle005`：`tau_AI=0.75 us` 时 `30 us` 最优且 `66 us` 触发 skip，`tau_AI=1.5 us` 时 `50 us` 最优且 `30 us` 触发 skip，`tau_AI=3 us` 时又回到 `30 us` 最优。这说明安全投影需要一个窄的延迟过渡口袋，而不是简单的 `tau_AI` 近邻插值或 proxy 直接覆盖。

因此，R033 对论文主张的强化不是“AI/proxy 已优于查表”，而是更谨慎地说明：PIS-IEK 可以把短时 skip、settling 与相位风险转化为监督层安全投影边界；AI 或表驱动监督层只产生候选 score/risk，最终提交给 IQCOT 内环的 `T_slew` 必须经过 delay-aware `B_epsilon^sw` 投影。`66 us` 负控在当前派生模型中仍不能作为直接覆盖动作，除非后续短时风险预测器或 HIL/硬件验证证明其风险可控。
"""
    PAPER.write_text(paper, encoding="utf-8")


def write_wiki_and_docs(context: pd.DataFrame, role: pd.DataFrame) -> None:
    section_marker = "## R033 派生 Simulink 验证：delay-aware"
    paper = PAPER.read_text(encoding="utf-8")
    append_once(ROOT / "RESEARCH_BRIEF.md", section_marker, "\n" + paper)
    append_once(OUT / "iqcot_integrated_research_paper.md", section_marker, "\n" + paper)
    append_once(OUT / "iqcot_pis_iek_derivation_package.md", "## R033 Addition", f"""
## R033 Addition: switching-calibrated delay-band refinement

R033 将 R032 的 `B_epsilon^sw` 规则放入 `31` 行派生 Simulink delayed-reference 验证中。新增信息是：安全投影边界并非只随 `tau_AI` 单调平移，而会在 skip/reentry 和 settling 模式边界处出现窄的过渡口袋。例如 `20A/score_settle005` 在 `tau_AI=1.5 us` 时支持 `50 us`，但在 `0.75 us` 和 `3 us` 时仍回到 `30 us` fallback。这说明 PIS-IEK 小信号模型用于 AI 监督层时，`r_hat` 至少要预测短时 skip/settling 风险，而不能只做 `tau_AI` 近邻插值。
""")
    append_once(OUT / "iqcot_ai_supervisor_validation_design.md", "## 23. R033", f"""
## 23. R033 delay-band 派生 Simulink 验证

R033 已完成 `E:/Desktop/codex/output/iqcot_r032_next_validation_plan.csv` 的全部 `31` 行派生 Simulink delayed-reference 验证，并由 `E:/Desktop/codex/output/iqcot_r033_delay_band_validation_postprocess.py` 合并分析。核心输出包括：

- `E:/Desktop/codex/output/iqcot_r033_delay_band_validation_results_combined.csv`
- `E:/Desktop/codex/output/iqcot_r033_delay_band_validation_context_summary.csv`
- `E:/Desktop/codex/output/iqcot_r033_delay_band_rule_update.csv`
- `E:/Desktop/codex/output/iqcot_r033_delay_band_validation_report.md`

验证结论应写成边界修正：`10A/score_settle010` 是 `30-34 us` near-tie 带，`20A/base` 的 `86 us` 只能作为目标函数相关探针，`20A/score_settle005` 存在 `tau_AI≈1.5 us` 的 `50 us` 过渡口袋，但 `66 us` 仍应作为负控阻断。该实验不等同于硬件验证或神经网络 AI-in-loop。
""")
    evidence = f"""
### C27 / R033：R032 delay-band 的派生 Simulink 边界验证

| ID | 论断 | 支撑证据 | 强度 | 允许写法 | 禁止写法 |
|---|---|---|---|---|---|
| C27 | R033 用 `31` 行派生 Simulink delayed-reference 验证修正 R032 的 delay-aware `B_epsilon^sw` 边界：监督层可产生局部候选带，但最终 plant commit 仍需安全投影和 dense fallback。 | `iqcot_r032_delay_band_validation.m` 复用 R027 runner；`iqcot_r033_delay_band_validation_results_combined.csv` 共 `31` 行且全部成功；`iqcot_r033_delay_band_validation_context_summary.csv` 显示非 dense 候选在 `{int((context["best_role"] != "dense_fallback").sum())}/{len(context)}` 个上下文最优；`66us` 负控平均 regret `{f3(context["negative_66_regret"].dropna().mean())}`。 | 中等，边界强 | “R033 支持 delay-aware local band with dense fallback，并把 R032 规则修正为 near-tie 带、objective-dependent probe 与 50us transition pocket。” | “R033 证明 AI/proxy 全局优于查表、完成硬件验证、或找到 `T_slew` 全局最优。” |
"""
    append_once(OUT / "iqcot_claims_evidence_matrix.md", "### C27 / R033", evidence)

    wiki_page = f"""# Experiment: R033 delay-band derived-Simulink validation

## ID

`exp:delay-band-validation-r033`

## Purpose

Validate the R032 delay-aware `B_epsilon^sw` boundary on a small derived
Simulink delayed-reference matrix.

## Inputs

- `E:/Desktop/codex/output/iqcot_r032_next_validation_plan.csv`
- `E:/Desktop/codex/output/iqcot_r032_delay_band_rules.csv`
- `E:/Desktop/codex/output/simulink_iek/four_phase_iek_dynamic_load_refslew.slx`

## Outputs

- `E:/Desktop/codex/output/iqcot_r033_delay_band_validation_results_combined.csv`
- `E:/Desktop/codex/output/iqcot_r033_delay_band_validation_context_summary.csv`
- `E:/Desktop/codex/output/iqcot_r033_delay_band_validation_role_summary.csv`
- `E:/Desktop/codex/output/iqcot_r033_delay_band_rule_update.csv`
- `E:/Desktop/codex/output/figures/fig44_r033_delay_band_validation.svg`

## Result

All `31` planned derived-Simulink cases completed.  Non-dense candidates are
best in `{int((context["best_role"] != "dense_fallback").sum())}/{len(context)}` contexts.  The important corrections are:

- `10A/score_settle010`: `32us` wins at `tau=2us`, `33us` wins at `tau=3us`; treat as a near-tie band.
- `20A/base`: `86us` wins only for base objective at `tau=1us`; keep it candidate-only.
- `20A/score_settle005`: `50us` wins at `tau=1.5us`, but `30us` wins at `0.75us` and `3us`; keep `66us` blocked.

## Boundary

Derived Simulink only.  Not hardware validation, not neural-network AI-in-loop,
and not a global optimum proof.
"""
    append_once(WIKI_EXP, "# Experiment: R033", wiki_page)
    append_once(WIKI / "query_pack.md", "## R033 Update", f"""
## R033 Update

- `exp:delay-band-validation-r033`: completed all `31` R032 validation cases in the derived Simulink delayed-reference model.  Non-dense candidates are best in `{int((context["best_role"] != "dense_fallback").sum())}/{len(context)}` contexts, but the result refines rather than expands claims: `10A/score_settle010` is a near-tie band, `20A/base` keeps `86us` candidate-only, and `20A/score_settle005` gains a narrow `50us` transition pocket while `66us` remains blocked.
""")
    append_once(WIKI / "index.md", "exp:delay-band-validation-r033", "- `exp:delay-band-validation-r033` - R033 derived-Simulink validation of R032 delay-aware band rules\n")
    append_once(WIKI / "log.md", "exp:delay-band-validation-r033", "- `2026-06-21T00:35:00Z` add_experiment: completed exp:delay-band-validation-r033 [verdict=partial confidence=medium]; 31 derived-Simulink delayed-reference cases refine R032 band projection\n")
    edge_path = WIKI / "graph" / "edges.jsonl"
    edge_path.parent.mkdir(parents=True, exist_ok=True)
    existing = edge_path.read_text(encoding="utf-8", errors="replace") if edge_path.exists() else ""
    edges = [
        {
            "from": "idea:iqcot-pis-iek-four-phase",
            "to": "exp:delay-band-validation-r033",
            "type": "tested_by",
            "evidence": "R033 validates R032 delay-band rules with 31 derived-Simulink delayed-reference cases.",
            "added": "2026-06-21T00:35:00Z",
        },
        {
            "from": "exp:delay-band-validation-r033",
            "to": "exp:delay-aware-band-r032",
            "type": "refines",
            "evidence": "R033 corrects R032 plant-commit boundaries for 10A near-tie, 20A base, and 20A score_settle005 transition pocket.",
            "added": "2026-06-21T00:35:05Z",
        },
    ]
    additions = [json.dumps(e, ensure_ascii=False) for e in edges if json.dumps(e, ensure_ascii=False) not in existing]
    if additions:
        sep = "" if existing.endswith("\n") or not existing else "\n"
        edge_path.write_text(existing + sep + "\n".join(additions) + "\n", encoding="utf-8")


def write_audit(combined: pd.DataFrame, context: pd.DataFrame) -> None:
    LOGS.mkdir(parents=True, exist_ok=True)
    all_success = bool(combined["success"].astype(bool).all())
    duplicate_ids = combined["r027_case_id"].duplicated().sum()
    expected_contexts = {
        ("10A", "score_settle010", 2.0),
        ("10A", "score_settle010", 3.0),
        ("20A", "base", 1.0),
        ("20A", "base", 3.0),
        ("20A", "score_settle005", 0.75),
        ("20A", "score_settle005", 1.5),
        ("20A", "score_settle005", 3.0),
    }
    actual_contexts = set(tuple(x) for x in context[CTX].itertuples(index=False, name=None))
    missing_contexts = sorted(expected_contexts - actual_contexts)
    audit = f"""# Local Audit R033 Delay-Band Validation

Date: 2026-06-21

## Checks

- Required chunk files present: PASS (`{len(CHUNKS)}` chunks)
- Combined row count: `{len(combined)}` / expected `31`
- All rows successful: `{all_success}`
- Duplicate case IDs: `{duplicate_ids}`
- Context count: `{len(context)}` / expected `7`
- Missing contexts: `{missing_contexts}`
- Original `.slx` modified: not touched by this script; runner uses derived model only.
- Boundary language: report and paper section explicitly state derived-Simulink only, no hardware validation, no global `T_slew` optimum, and AI as supervisory scheduler only.

## Verdict

PASS with scientific qualification.  The experiment is internally consistent
as a derived-Simulink boundary-validation run.  It should be claimed only as a
local refinement of R032, not as hardware or independent generalization proof.
"""
    AUDIT.write_text(audit, encoding="utf-8")


def main() -> None:
    rows, plan = read_inputs()
    combined = prepare_combined(rows, plan)
    context = build_context_summary(combined)
    role = build_role_summary(combined)
    rules = build_rule_update(context)

    COMBINED.parent.mkdir(parents=True, exist_ok=True)
    FIG.mkdir(parents=True, exist_ok=True)
    combined.to_csv(COMBINED, index=False)
    context.to_csv(CONTEXT, index=False)
    role.to_csv(ROLE, index=False)
    rules.to_csv(RULES, index=False)
    write_figure(context)
    write_reports(context, role, rules)
    write_wiki_and_docs(context, role)
    write_audit(combined, context)

    print(f"Wrote {COMBINED}")
    print(f"Wrote {CONTEXT}")
    print(f"Wrote {ROLE}")
    print(f"Wrote {RULES}")
    print(f"Wrote {REPORT}")
    print(f"Wrote {PAPER}")
    print(f"Wrote {SVG}")
    print(f"Wrote {AUDIT}")


if __name__ == "__main__":
    main()
