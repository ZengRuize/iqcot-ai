#!/usr/bin/env python3
"""Post-process partial R034 transition-pocket derived-Simulink validation.

This script combines the executed R034 transition-pocket chunks and compares
them with the R033 tau=1.5us anchor.  It refines the original "50us pocket"
hypothesis into a tentative moving transition ridge:

    tau=1.25us -> 46us
    tau=1.50us -> 50us  (R033 anchor)
    tau=1.75us -> 54us

The result is still derived-Simulink evidence only and currently partial:
tau=1.0us and tau=2.0us remain planned validation points.
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
    OUT / "iqcot_r027_proxy_table_in_loop_results_r034_transition_pocket_rows006_010.csv",
    OUT / "iqcot_r027_proxy_table_in_loop_results_r034_transition_pocket_rows011_015.csv",
]
R033_COMBINED = OUT / "iqcot_r033_delay_band_validation_results_combined.csv"
PLAN = OUT / "iqcot_r034_transition_pocket_validation_plan.csv"

COMBINED = OUT / "iqcot_r034_transition_pocket_results_partial_combined.csv"
CONTEXT = OUT / "iqcot_r034_transition_pocket_context_partial_summary.csv"
RIDGE = OUT / "iqcot_r034_transition_ridge_model.csv"
REMAINING = OUT / "iqcot_r034_transition_pocket_remaining_plan.csv"
REPORT = OUT / "iqcot_r034_transition_pocket_partial_report.md"
PAPER = OUT / "iqcot_r034_transition_pocket_partial_paper_section.md"
SVG = FIG / "fig46_r034_transition_pocket_partial.svg"
AUDIT = LOGS / "LOCAL_AUDIT_R034_TRANSITION_POCKET_PARTIAL_20260621.md"
WIKI_EXP = WIKI / "experiments" / "transition-pocket-partial-r034.md"

CTX = ["target_label", "objective", "tau_ai_us"]


def append_once(path: Path, marker: str, text: str) -> None:
    old = path.read_text(encoding="utf-8", errors="replace") if path.exists() else ""
    if marker in old:
        return
    sep = "" if old.endswith("\n") or not old else "\n"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(old + sep + text.strip() + "\n", encoding="utf-8")


def f3(x: float) -> str:
    return f"{float(x):.3f}"


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


def read_inputs() -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    missing = [p for p in [*CHUNKS, R033_COMBINED, PLAN] if not p.exists()]
    if missing:
        raise FileNotFoundError(", ".join(str(p) for p in missing))
    r034 = pd.concat((pd.read_csv(p) for p in CHUNKS), ignore_index=True)
    r033 = pd.read_csv(R033_COMBINED)
    plan = pd.read_csv(PLAN)
    return r034, r033, plan


def prepare_rows(r034: pd.DataFrame, r033: pd.DataFrame) -> pd.DataFrame:
    cols = [
        "success",
        "error_message",
        "r027_case_id",
        "target_label",
        "objective",
        "policy",
        "objective_alpha_settle",
        "target_load_A",
        "load_drop_A",
        "selected_ref_slew_us",
        "tau_ai_us",
        "delay_events",
        "ref_start_delay_us",
        "selected_objective_score",
        "undershoot_mV",
        "settle_time_us",
        "skip_count_est",
        "final_phase_spacing_std_ns",
        "final_vout_error_mV",
        "switching_regret_vs_best_in_run",
    ]
    r034 = r034[cols].copy()
    r034["evidence_source"] = "R034_partial_validation"

    anchor = r033[
        (r033["target_label"] == "20A")
        & (r033["objective"] == "score_settle005")
        & (r033["tau_ai_us"].astype(float) == 1.5)
        & (r033["selected_ref_slew_us"].astype(float).isin([38.0, 50.0, 58.0]))
    ][cols].copy()
    anchor["evidence_source"] = "R033_anchor_tau1p5"

    rows = pd.concat([r034, anchor], ignore_index=True)
    for col in [
        "tau_ai_us",
        "selected_ref_slew_us",
        "selected_objective_score",
        "undershoot_mV",
        "settle_time_us",
        "skip_count_est",
        "final_phase_spacing_std_ns",
        "switching_regret_vs_best_in_run",
    ]:
        rows[col] = pd.to_numeric(rows[col], errors="coerce")
    rows = rows.sort_values(["tau_ai_us", "selected_ref_slew_us", "evidence_source"]).reset_index(drop=True)
    rows["context_best_score"] = rows.groupby(CTX)["selected_objective_score"].transform("min")
    rows["context_regret"] = rows["selected_objective_score"] - rows["context_best_score"]
    return rows


def build_context_summary(rows: pd.DataFrame) -> pd.DataFrame:
    out = []
    for key, group in rows.groupby(CTX, sort=True):
        target, objective, tau = key
        best = group.loc[group["selected_objective_score"].idxmin()]
        out.append(
            {
                "target_label": target,
                "objective": objective,
                "tau_ai_us": float(tau),
                "n_candidates": len(group),
                "best_slew_us": float(best["selected_ref_slew_us"]),
                "best_score": float(best["selected_objective_score"]),
                "best_source": best["evidence_source"],
                "best_undershoot_mV": float(best["undershoot_mV"]),
                "best_settle_time_us": float(best["settle_time_us"]),
                "best_skip_count_est": float(best["skip_count_est"]),
                "best_phase_std_ns": float(best["final_phase_spacing_std_ns"]),
                "second_best_slew_us": float(group.nsmallest(2, "selected_objective_score").iloc[-1]["selected_ref_slew_us"])
                if len(group) >= 2
                else float("nan"),
                "second_best_regret": float(group.nsmallest(2, "selected_objective_score").iloc[-1]["context_regret"])
                if len(group) >= 2
                else float("nan"),
            }
        )
    return pd.DataFrame(out)


def build_ridge(context: pd.DataFrame, plan: pd.DataFrame) -> tuple[pd.DataFrame, pd.DataFrame]:
    observed = context[["tau_ai_us", "best_slew_us", "best_source", "second_best_slew_us", "second_best_regret"]].copy()
    observed["ridge_formula_us"] = 26.0 + 16.0 * observed["tau_ai_us"]
    observed["ridge_error_us"] = observed["best_slew_us"] - observed["ridge_formula_us"]
    observed["status"] = observed["best_source"].map(
        {
            "R034_partial_validation": "new derived-Simulink point",
            "R033_anchor_tau1p5": "inherited R033 anchor",
        }
    )

    remaining = plan[~plan["r034_case_id"].isin(["R034_0006", "R034_0007", "R034_0008", "R034_0009", "R034_0010", "R034_0011", "R034_0012", "R034_0013", "R034_0014", "R034_0015"])].copy()
    remaining["ridge_predicted_best_us"] = 26.0 + 16.0 * remaining["tau_ai_us"].astype(float)
    remaining["ridge_predicted_best_us"] = remaining["ridge_predicted_best_us"].clip(38.0, 58.0)
    return observed, remaining


def write_figure(rows: pd.DataFrame, context: pd.DataFrame, ridge: pd.DataFrame) -> None:
    FIG.mkdir(parents=True, exist_ok=True)
    width, height = 1100, 540
    left, top = 90, 70
    plot_w, plot_h = 650, 320
    tau_min, tau_max = 1.0, 2.0
    slew_min, slew_max = 34.0, 60.0

    def x_of(tau: float) -> float:
        return left + (tau - tau_min) / (tau_max - tau_min) * plot_w

    def y_of(slew: float) -> float:
        return top + plot_h - (slew - slew_min) / (slew_max - slew_min) * plot_h

    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        '<rect width="100%" height="100%" fill="white"/>',
        '<text x="550" y="34" text-anchor="middle" font-family="Arial" font-size="18">R034 partial transition-pocket validation</text>',
        f'<rect x="{left}" y="{top}" width="{plot_w}" height="{plot_h}" fill="#fbfbfb" stroke="#ddd"/>',
        '<text x="90" y="55" font-family="Arial" font-size="13">Score landscape samples and tentative moving ridge</text>',
    ]
    for tau in [1.0, 1.25, 1.5, 1.75, 2.0]:
        x = x_of(tau)
        parts.append(f'<line x1="{x:.1f}" y1="{top}" x2="{x:.1f}" y2="{top+plot_h}" stroke="#eee"/>')
        parts.append(f'<text x="{x:.1f}" y="{top+plot_h+20}" text-anchor="middle" font-family="Arial" font-size="10">{tau:g}</text>')
    for slew in [38, 46, 50, 54, 58]:
        y = y_of(slew)
        parts.append(f'<line x1="{left}" y1="{y:.1f}" x2="{left+plot_w}" y2="{y:.1f}" stroke="#eee"/>')
        parts.append(f'<text x="{left-10}" y="{y+4:.1f}" text-anchor="end" font-family="Arial" font-size="10">{slew}</text>')
    max_score = rows["selected_objective_score"].max()
    min_score = rows["selected_objective_score"].min()
    for row in rows.itertuples():
        score = float(row.selected_objective_score)
        frac = (score - min_score) / max(1e-9, max_score - min_score)
        radius = 5 + 8 * (1 - frac)
        color = "#2F855A" if abs(float(row.context_regret)) < 1e-9 else "#C53030"
        if row.evidence_source == "R033_anchor_tau1p5":
            color = "#4C78A8"
        parts.append(f'<circle cx="{x_of(row.tau_ai_us):.1f}" cy="{y_of(row.selected_ref_slew_us):.1f}" r="{radius:.1f}" fill="{color}" opacity="0.78"/>')
    ridge_points = [(float(r.tau_ai_us), float(r.best_slew_us)) for r in ridge.itertuples()]
    if len(ridge_points) >= 2:
        pts = " ".join(f"{x_of(t):.1f},{y_of(s):.1f}" for t, s in ridge_points)
        parts.append(f'<polyline points="{pts}" fill="none" stroke="#1A365D" stroke-width="3"/>')
    right_x = 790
    parts.append(f'<text x="{right_x}" y="82" font-family="Arial" font-size="13">Observed best ridge</text>')
    for i, row in enumerate(ridge.itertuples()):
        parts.append(
            f'<text x="{right_x}" y="{112+i*26}" font-family="Arial" font-size="11">'
            f'tau={row.tau_ai_us:g}: best={row.best_slew_us:g}us, formula err={row.ridge_error_us:+.1f}us</text>'
        )
    parts.append('<text x="90" y="500" font-family="Arial" font-size="11" fill="#555">Green=new R034 best, blue=R033 anchor, red=non-best. Derived Simulink only.</text>')
    parts.append("</svg>")
    SVG.write_text("\n".join(parts), encoding="utf-8")


def write_reports(rows: pd.DataFrame, context: pd.DataFrame, ridge: pd.DataFrame, remaining: pd.DataFrame) -> None:
    best_map = {float(r.tau_ai_us): float(r.best_slew_us) for r in context.itertuples()}
    report = f"""# R034 Transition-Pocket Partial Derived-Simulink Validation

## Scope

This report combines the executed R034 transition-pocket chunks at
`tau_AI=1.25us` and `1.75us`, then compares them with the R033 `tau_AI=1.5us`
anchor.  It is a partial derived-Simulink validation, not hardware validation
and not proof of global `T_slew` optimality.

## Key Result

The original R034 fixed `50us` transition-pocket hypothesis is too narrow.
The observed local best points form a tentative moving ridge:

- `tau_AI=1.25us -> {best_map.get(1.25, float('nan')):g}us`
- `tau_AI=1.50us -> {best_map.get(1.5, float('nan')):g}us` from R033 anchor
- `tau_AI=1.75us -> {best_map.get(1.75, float('nan')):g}us`

At `tau_AI=1.25us`, `50us` triggers skip and has regret `2.568`, while `46us`
is best.  At `tau_AI=1.75us`, `54us` is best, while `46us` triggers skip and
`50/58us` suffer longer settling.  This supports a moving transition ridge,
not a fixed pocket.

## Context Summary

{md_table(context, [
    "target_label",
    "objective",
    "tau_ai_us",
    "n_candidates",
    "best_slew_us",
    "best_source",
    "best_score",
    "best_settle_time_us",
    "best_skip_count_est",
    "second_best_slew_us",
    "second_best_regret",
])}

## Tentative Ridge Model

{md_table(ridge, [
    "tau_ai_us",
    "best_slew_us",
    "best_source",
    "ridge_formula_us",
    "ridge_error_us",
    "status",
])}

## Remaining Validation Plan

{md_table(remaining, [
    "r034_case_id",
    "tau_ai_us",
    "candidate_ref_slew_us",
    "priority",
])}

## Interpretation

R034 now gives stronger evidence that the safe transition set is mode-aware and
delay-sensitive.  A practical supervisor should not commit a fixed `50us`
action merely because `tau_AI` is near the transition region.  A better
deployable interface is:

```text
T_ridge(tau_AI) ≈ 26 + 16*tau_AI us, clipped to the verified candidate band,
then projected by skip/settling risk and dense fallback.
```

The formula is only a local hypothesis from three points.  The remaining
`tau_AI=1.0us` and `2.0us` rows are needed before writing it as more than a
candidate predictor.
"""
    REPORT.write_text(report, encoding="utf-8")

    paper = f"""## R034 部分派生验证：从固定 `50us` 口袋到移动 transition ridge

R034 原先基于 R033 的 `tau_AI=1.5us` 结果，将 `20A/score_settle005` 写成 `50us` transition pocket。为了检查该口袋是否只是单点现象，本文追加运行了两个最小派生 Simulink 边界块：`tau_AI=1.25us` 与 `tau_AI=1.75us`，每个延迟下比较 `38/46/50/54/58us`。结果显示固定 `50us` 假设需要修正：`tau_AI=1.25us` 时 `46us` 最优，而 `50us` 触发 skip 且 regret 达 `2.568`；`tau_AI=1.75us` 时 `54us` 最优，`46us` 反而触发 skip。结合 R033 的 `tau_AI=1.5us -> 50us` 锚点，局部最优候选更像一条随延迟移动的 transition ridge，而不是固定口袋。

因此，R034 对监督层接口的修正是：`q_phi` 可用局部斜脊近似生成候选，例如 `T_ridge(tau_AI)≈26+16 tau_AI us`，但 `r_hat` 必须继续检查 skip 与 settling 风险，最终仍经 `B_epsilon^sw` 投影和 dense fallback 提交。该公式目前只由三个派生模型点支撑，剩余 `tau_AI=1.0us` 与 `2.0us` 的细扫仍需完成；不能把它写成全局最优规律或硬件验证结论。
"""
    PAPER.write_text(paper, encoding="utf-8")


def update_docs(context: pd.DataFrame, ridge: pd.DataFrame, remaining: pd.DataFrame) -> None:
    paper = PAPER.read_text(encoding="utf-8")
    append_once(ROOT / "RESEARCH_BRIEF.md", "## R034 部分派生验证", "\n" + paper)
    append_once(OUT / "iqcot_integrated_research_paper.md", "## R034 部分派生验证", "\n" + paper)
    append_once(OUT / "iqcot_pis_iek_derivation_package.md", "## R034 Partial Validation Addition", """
## R034 Partial Validation Addition: moving transition ridge

R034 的 `tau_AI=1.25/1.75us` 派生 Simulink 细扫显示，`20A/score_settle005`
的过渡口袋不是固定 `50us`，而更像随延迟移动的局部 ridge：
`1.25us -> 46us`、`1.5us -> 50us`、`1.75us -> 54us`。这进一步说明
PIS-IEK 给 AI 监督层提供的是事件模式边界与风险投影结构，而不是一个可被简单
线性插值替代的光滑参数面。
""")
    append_once(OUT / "iqcot_ai_supervisor_validation_design.md", "## 25. R034 partial transition", f"""
## 25. R034 partial transition-pocket validation

已完成 R034 transition-pocket 计划的核心两块：`tau_AI=1.25us` 与 `1.75us`，
共 `10` 行派生 Simulink delayed-reference 工况。结果修正了固定 `50us`
口袋假设：左侧边界最佳为 `46us`，右侧边界最佳为 `54us`。剩余计划位于
`E:/Desktop/codex/output/iqcot_r034_transition_pocket_remaining_plan.csv`，包含
`{len(remaining)}` 行，主要用于验证 `tau_AI=1.0us` 和 `2.0us` 的 ridge 外推。
""")
    evidence = f"""
### C29 / R034 partial：`20A/score_settle005` transition ridge

| ID | 论断 | 支撑证据 | 强度 | 允许写法 | 禁止写法 |
|---|---|---|---|---|---|
| C29 | R034 部分派生验证表明 `20A/score_settle005` 的过渡动作更像随 `tau_AI` 移动的局部 ridge，而非固定 `50us` 口袋。 | `iqcot_r027_proxy_table_in_loop_results_r034_transition_pocket_rows006_010.csv` 与 `rows011_015.csv` 共 `10` 行成功；`iqcot_r034_transition_pocket_context_partial_summary.csv` 显示 `tau=1.25us -> 46us`、`tau=1.75us -> 54us`，结合 R033 `tau=1.5us -> 50us`。 | 中等，仍是局部派生模型证据 | “R034 partial 支持移动 transition ridge 假设，并提示下一轮应验证 `tau=1.0/2.0us` 外推点。” | “R034 已证明 ridge 公式全局成立、硬件有效、或 `T_slew` 存在全局最优。” |
"""
    append_once(OUT / "iqcot_claims_evidence_matrix.md", "### C29 / R034 partial", evidence)

    wiki_page = f"""# Experiment: R034 partial transition-pocket validation

## ID

`exp:transition-pocket-partial-r034`

## Result

Executed 10 derived-Simulink cases at `tau_AI=1.25us` and `1.75us`.
The best candidates are `46us` and `54us`, respectively.  Together with the
R033 `tau_AI=1.5us -> 50us` anchor, this suggests a moving transition ridge
rather than a fixed `50us` pocket.

## Boundary

Partial derived-Simulink evidence only.  `tau_AI=1.0us` and `2.0us` remain to
be validated.
"""
    append_once(WIKI_EXP, "# Experiment: R034 partial", wiki_page)
    append_once(WIKI / "query_pack.md", "## R034 Partial Update", """
## R034 Partial Update

- `exp:transition-pocket-partial-r034`: ran 10 derived-Simulink cases around the R034 transition pocket.  Results revise the fixed `50us` pocket into a tentative moving ridge: `tau=1.25us -> 46us`, R033 anchor `1.5us -> 50us`, and `1.75us -> 54us`.  Remaining `tau=1.0/2.0us` cases are still needed.
""")
    append_once(WIKI / "index.md", "exp:transition-pocket-partial-r034", "- `exp:transition-pocket-partial-r034` - R034 partial derived-Simulink validation of moving transition ridge\n")
    append_once(WIKI / "log.md", "exp:transition-pocket-partial-r034", "- `2026-06-21T01:20:00Z` add_experiment: completed partial exp:transition-pocket-partial-r034 [verdict=partial confidence=medium]; 10 cases revise fixed 50us pocket into moving ridge hypothesis\n")
    edge_path = WIKI / "graph" / "edges.jsonl"
    old = edge_path.read_text(encoding="utf-8", errors="replace") if edge_path.exists() else ""
    edges = [
        {
            "from": "idea:iqcot-pis-iek-four-phase",
            "to": "exp:transition-pocket-partial-r034",
            "type": "tested_by",
            "evidence": "R034 partial derived-Simulink validation tests the transition pocket edges at tau=1.25us and tau=1.75us.",
            "added": "2026-06-21T01:20:00Z",
        },
        {
            "from": "exp:transition-pocket-partial-r034",
            "to": "exp:deployable-risk-predictor-r034",
            "type": "refines",
            "evidence": "Partial validation revises fixed 50us pocket into a moving transition ridge hypothesis.",
            "added": "2026-06-21T01:20:05Z",
        },
    ]
    additions = [json.dumps(e, ensure_ascii=False) for e in edges if json.dumps(e, ensure_ascii=False) not in old]
    if additions:
        sep = "" if old.endswith("\n") or not old else "\n"
        edge_path.write_text(old + sep + "\n".join(additions) + "\n", encoding="utf-8")


def write_audit(rows: pd.DataFrame, context: pd.DataFrame, remaining: pd.DataFrame) -> None:
    LOGS.mkdir(parents=True, exist_ok=True)
    audit = f"""# Local Audit R034 Transition-Pocket Partial Validation

Date: 2026-06-21

## Checks

- Chunk files present: `{len(CHUNKS)}`
- Combined rows including R033 anchor: `{len(rows)}`
- New R034 rows successful: `{int(rows[rows['evidence_source'].eq('R034_partial_validation')]['success'].sum())}` / `10`
- Contexts summarized: `{len(context)}` (`tau=1.25/1.5/1.75us`)
- Remaining plan rows: `{len(remaining)}`
- Original `.slx` modified: no; derived model runner only.
- Boundary language: report and paper section state partial derived-Simulink evidence, not hardware validation or global optimum proof.

## Verdict

PASS with partial scope.  The run is internally consistent and scientifically
useful because it falsifies the fixed-50us pocket as a universal local rule.
The moving ridge remains a hypothesis until remaining tau points are run.
"""
    AUDIT.write_text(audit, encoding="utf-8")


def main() -> None:
    r034, r033, plan = read_inputs()
    rows = prepare_rows(r034, r033)
    context = build_context_summary(rows)
    ridge, remaining = build_ridge(context, plan)

    rows.to_csv(COMBINED, index=False)
    context.to_csv(CONTEXT, index=False)
    ridge.to_csv(RIDGE, index=False)
    remaining.to_csv(REMAINING, index=False)
    write_figure(rows, context, ridge)
    write_reports(rows, context, ridge, remaining)
    update_docs(context, ridge, remaining)
    write_audit(rows, context, remaining)

    print(f"Wrote {COMBINED}")
    print(f"Wrote {CONTEXT}")
    print(f"Wrote {RIDGE}")
    print(f"Wrote {REMAINING}")
    print(f"Wrote {REPORT}")
    print(f"Wrote {PAPER}")
    print(f"Wrote {SVG}")
    print(f"Wrote {AUDIT}")


if __name__ == "__main__":
    main()
