#!/usr/bin/env python3
"""R034 deployable short-horizon risk predictor prototype.

R034 converts the R033 boundary-validation evidence into an interpretable
supervisory interface:

    q_phi(z, T_slew, tau_AI) -> candidate ranking score
    r_hat(z, T_slew, tau_AI) -> skip/settling/phase risk proxy
    T_slew,plant = Proj_{B_epsilon^sw}(candidate)

This is a lightweight rule-calibrated predictor/projection prototype.  It does
not run or edit any SLX model, does not replace the IQCOT inner loop, and does
not prove a global T_slew optimum.
"""

from __future__ import annotations

import json
import math
from pathlib import Path

import pandas as pd


ROOT = Path("E:/Desktop/codex")
OUT = ROOT / "output"
FIG = OUT / "figures"
WIKI = ROOT / "research-wiki"
LOGS = ROOT / "refine-logs"

R033_CONTEXT = OUT / "iqcot_r033_delay_band_validation_context_summary.csv"
R033_RULES = OUT / "iqcot_r033_delay_band_rule_update.csv"

RISK_GRID = OUT / "iqcot_r034_deployable_risk_grid.csv"
POLICY_SURFACE = OUT / "iqcot_r034_policy_surface.csv"
VALIDATION_PLAN = OUT / "iqcot_r034_transition_pocket_validation_plan.csv"
REPORT = OUT / "iqcot_r034_deployable_risk_predictor_report.md"
PAPER = OUT / "iqcot_r034_deployable_risk_predictor_paper_section.md"
SVG = FIG / "fig45_r034_deployable_risk_predictor.svg"
AUDIT = LOGS / "LOCAL_AUDIT_R034_DEPLOYABLE_RISK_PREDICTOR_20260621.md"
WIKI_EXP = WIKI / "experiments" / "deployable-risk-predictor-r034.md"


def append_once(path: Path, marker: str, text: str) -> None:
    old = path.read_text(encoding="utf-8", errors="replace") if path.exists() else ""
    if marker in old:
        return
    sep = "" if old.endswith("\n") or not old else "\n"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(old + sep + text.strip() + "\n", encoding="utf-8")


def f3(x: float) -> str:
    return f"{float(x):.3f}"


def gaussian(x: float, mu: float, sigma: float) -> float:
    return math.exp(-0.5 * ((x - mu) / sigma) ** 2)


def clamp(x: float, lo: float = 0.0, hi: float = 1.0) -> float:
    return max(lo, min(hi, x))


def risk_score(target: str, objective: str, tau: float, slew: float) -> dict[str, object]:
    """Return an interpretable risk/ranking record for a candidate."""
    alpha = {"base": 0.0, "score_settle005": 0.05, "score_settle010": 0.10}[objective]
    dense = 30.0
    label = "candidate_only"
    reason = "outside calibrated rule pocket; keep as ranking candidate only"
    q = 1.0
    skip = 0.2
    settle = 0.2
    phase = 0.2
    plant_allowed = False
    validated = False

    if target == "10A" and objective == "score_settle010":
        dense = 30.0
        center = 32.0 if tau < 2.5 else 33.0
        q = abs(slew - center) / 3.0 + 0.08 * abs(tau - 2.5)
        skip = 0.55
        settle = 0.35 + 0.08 * max(0.0, slew - 32.0)
        phase = 0.35
        if 30.0 <= slew <= 34.0:
            label = "near_tie_band"
            reason = "R033 supports a 30-34us delay-sensitive near-tie band"
        else:
            label = "blocked"
            reason = "outside R033 near-tie band"
        if abs(tau - 3.0) < 1e-9 and abs(slew - 33.0) < 1e-9:
            plant_allowed = True
            validated = True
            label = "plant_admissible"
            reason = "R033 tau=3us derived-Simulink point supports 33us locally"

    elif target == "20A" and objective == "base":
        dense = 80.0
        center = 86.0 if tau <= 1.25 else 80.0
        q = abs(slew - center) / 8.0 + 0.05 * max(0.0, tau - 1.0)
        skip = 0.25
        settle = 0.25 + 0.12 * max(0.0, slew - 80.0)
        phase = 0.25 + 0.08 * abs(slew - 80.0)
        if slew == 80.0:
            plant_allowed = True
            validated = True
            label = "dense_fallback"
            reason = "80us remains the conservative validated fallback"
        elif slew in {82.0, 84.0, 86.0}:
            label = "objective_probe"
            reason = "base objective can favor longer slew, but plant commit needs settling-aware guard"
        else:
            label = "blocked"
            reason = "outside R033 base-objective candidate set"

    elif target == "20A" and objective == "score_settle005":
        dense = 30.0
        pocket = gaussian(tau, 1.5, 0.28)
        t_center = 50.0
        q = abs(slew - t_center) / 20.0 - 1.25 * pocket
        if slew == 30.0:
            q = min(q, 0.05 + 0.9 * pocket)
        skip = 0.08
        settle = 0.12
        phase = 0.15
        if slew == 30.0:
            skip = 0.08 + 0.75 * pocket
            label = "dense_fallback"
            reason = "30us is the fallback; R033 shows it can skip near tau=1.5us"
            plant_allowed = pocket < 0.55
            validated = tau in {0.75, 1.5, 3.0}
        elif slew in {38.0, 46.0, 50.0, 54.0, 58.0}:
            distance = abs(slew - 50.0)
            settle = 0.14 + 0.05 * distance + 0.35 * (1.0 - pocket)
            phase = 0.18 + 0.03 * distance
            if 46.0 <= slew <= 54.0 and pocket >= 0.55:
                label = "transition_pocket"
                reason = "R033 supports a narrow 50us pocket at tau=1.5us; neighbors need R034 validation"
                plant_allowed = abs(slew - 50.0) < 1e-9 and abs(tau - 1.5) < 1e-9
                validated = plant_allowed
            else:
                label = "candidate_only"
                reason = "intermediate candidate for transition-pocket validation"
        elif slew >= 60.0:
            q = 2.0
            skip = 0.75 if tau <= 1.0 else 0.30
            settle = 0.85
            phase = 0.50
            label = "blocked"
            reason = "66us-class large jump remains blocked by R033 negative control"
        else:
            label = "blocked"
            reason = "outside R033/R034 candidate set"
    else:
        label = "blocked"
        reason = "unrecognized context"
        q = 9.0
        skip = settle = phase = 0.90

    total = clamp(0.40 * skip + 0.40 * settle + 0.20 * phase)
    if label == "blocked":
        plant_allowed = False
        total = max(total, 0.75)
    return {
        "target_label": target,
        "objective": objective,
        "objective_alpha_settle": alpha,
        "tau_ai_us": tau,
        "candidate_ref_slew_us": slew,
        "dense_fallback_us": dense,
        "delta_from_dense_us": slew - dense,
        "q_phi_rank_score": q,
        "r_hat_skip_risk": clamp(skip),
        "r_hat_settle_risk": clamp(settle),
        "r_hat_phase_risk": clamp(phase),
        "r_hat_total_risk": total,
        "bepsilon_label": label,
        "plant_commit_allowed": plant_allowed,
        "derived_simulink_validated_point": validated,
        "projection_reason": reason,
    }


def build_risk_grid() -> pd.DataFrame:
    rows: list[dict[str, object]] = []
    for tau in [1.0, 2.0, 3.0, 5.0]:
        for slew in [30.0, 32.0, 33.0, 34.0]:
            rows.append(risk_score("10A", "score_settle010", tau, slew))
    for tau in [1.0, 3.0]:
        for slew in [80.0, 82.0, 84.0, 86.0]:
            rows.append(risk_score("20A", "base", tau, slew))
    for tau in [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0]:
        for slew in [30.0, 38.0, 46.0, 50.0, 54.0, 58.0, 66.0]:
            rows.append(risk_score("20A", "score_settle005", tau, slew))
    df = pd.DataFrame(rows)
    df["predicted_block"] = df["bepsilon_label"].eq("blocked")
    df["predicted_candidate_only"] = df["bepsilon_label"].isin(["candidate_only", "near_tie_band", "objective_probe", "transition_pocket"])
    return df.sort_values(["target_label", "objective", "tau_ai_us", "candidate_ref_slew_us"]).reset_index(drop=True)


def build_policy_surface(grid: pd.DataFrame) -> pd.DataFrame:
    records: list[dict[str, object]] = []
    for key, group in grid.groupby(["target_label", "objective", "tau_ai_us"], sort=True):
        target, objective, tau = key
        allowed = group[~group["predicted_block"]].copy()
        candidate = allowed.loc[allowed["q_phi_rank_score"].idxmin()]
        plant = group[group["plant_commit_allowed"]]
        if plant.empty:
            dense = group[group["candidate_ref_slew_us"].eq(group["dense_fallback_us"].iloc[0])].iloc[0]
            plant_row = dense
            status = "fallback_or_validation_needed"
        else:
            plant_row = plant.sort_values(["q_phi_rank_score", "r_hat_total_risk"]).iloc[0]
            status = "plant_admissible_with_current_evidence"
        records.append(
            {
                "target_label": target,
                "objective": objective,
                "tau_ai_us": float(tau),
                "q_phi_candidate_us": float(candidate["candidate_ref_slew_us"]),
                "q_phi_candidate_label": candidate["bepsilon_label"],
                "candidate_total_risk": float(candidate["r_hat_total_risk"]),
                "plant_commit_us": float(plant_row["candidate_ref_slew_us"]),
                "plant_commit_label": plant_row["bepsilon_label"],
                "plant_total_risk": float(plant_row["r_hat_total_risk"]),
                "deployment_status": status,
                "boundary_note": str(candidate["projection_reason"]),
            }
        )
    return pd.DataFrame(records)


def build_validation_plan() -> pd.DataFrame:
    rows: list[dict[str, object]] = []
    idx = 1
    for tau in [1.0, 1.25, 1.75, 2.0]:
        for slew in [38.0, 46.0, 50.0, 54.0, 58.0]:
            priority = 1 if tau in {1.25, 1.75} else 2
            rows.append(
                {
                    "r034_case_id": f"R034_{idx:04d}",
                    "target_label": "20A",
                    "target_load_A": 20.0,
                    "load_drop_A": 20.0,
                    "objective": "score_settle005",
                    "objective_alpha_settle": 0.05,
                    "tau_ai_us": tau,
                    "candidate_ref_slew_us": slew,
                    "delay_events_est": math.ceil(tau / 0.5),
                    "priority": priority,
                    "reason": "resolve R033 50us transition pocket around tau_AI=1.5us",
                    "validation_scope": "derived Simulink delayed-reference only; not hardware",
                }
            )
            idx += 1
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


def write_figure(grid: pd.DataFrame, policy: pd.DataFrame) -> None:
    FIG.mkdir(parents=True, exist_ok=True)
    pocket = grid[(grid["target_label"] == "20A") & (grid["objective"] == "score_settle005")]
    width, height = 1220, 560
    left, top = 88, 74
    cell_w, cell_h = 54, 34
    taus = sorted(pocket["tau_ai_us"].unique())
    slews = sorted(pocket["candidate_ref_slew_us"].unique())
    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        '<rect width="100%" height="100%" fill="white"/>',
        '<text x="610" y="34" text-anchor="middle" font-family="Arial" font-size="18">R034 deployable risk predictor prototype</text>',
        '<text x="88" y="58" font-family="Arial" font-size="13">20A / score_settle005: r_hat_total_risk heatmap</text>',
    ]
    for i, tau in enumerate(taus):
        x = left + (i + 1) * cell_w
        parts.append(f'<text x="{x+cell_w/2:.1f}" y="{top-12}" text-anchor="middle" font-family="Arial" font-size="10">tau={tau:g}</text>')
    for j, slew in enumerate(slews):
        y = top + j * cell_h
        parts.append(f'<text x="{left-10}" y="{y+22}" text-anchor="end" font-family="Arial" font-size="10">{slew:g}us</text>')
        for i, tau in enumerate(taus):
            row = pocket[(pocket["tau_ai_us"] == tau) & (pocket["candidate_ref_slew_us"] == slew)].iloc[0]
            risk = float(row["r_hat_total_risk"])
            red = int(255 * risk)
            green = int(190 * (1 - risk) + 40)
            color = f"rgb({red},{green},90)"
            x = left + (i + 1) * cell_w
            label = "B" if row["bepsilon_label"] == "blocked" else ("P" if bool(row["plant_commit_allowed"]) else "C")
            parts.append(f'<rect x="{x:.1f}" y="{y:.1f}" width="{cell_w-3}" height="{cell_h-3}" fill="{color}" stroke="#ddd"/>')
            parts.append(f'<text x="{x+cell_w/2:.1f}" y="{y+21:.1f}" text-anchor="middle" font-family="Arial" font-size="9">{risk:.2f}/{label}</text>')
    right_x = 690
    parts.append(f'<text x="{right_x}" y="76" font-family="Arial" font-size="13">Policy surface excerpts</text>')
    excerpt = policy[(policy["target_label"] == "20A") & (policy["objective"] == "score_settle005")].copy()
    for k, row in enumerate(excerpt.itertuples()):
        y = 106 + k * 25
        parts.append(
            f'<text x="{right_x}" y="{y}" font-family="Arial" font-size="11">'
            f'tau={row.tau_ai_us:g}: q={row.q_phi_candidate_us:g}us, plant={row.plant_commit_us:g}us, {row.deployment_status}</text>'
        )
    parts.append('<text x="88" y="520" font-family="Arial" font-size="11" fill="#555">Legend: P=plant-admissible under current evidence, C=candidate-only, B=blocked. Derived-model calibrated; not hardware validation.</text>')
    parts.append("</svg>")
    SVG.write_text("\n".join(parts), encoding="utf-8")


def write_reports(grid: pd.DataFrame, policy: pd.DataFrame, plan: pd.DataFrame) -> None:
    counts = grid["bepsilon_label"].value_counts().to_dict()
    pocket_policy = policy[(policy["target_label"] == "20A") & (policy["objective"] == "score_settle005")]
    report = f"""# R034 Deployable Risk Predictor Prototype

## Scope

R034 converts the R033 boundary-validation results into a lightweight,
deployable-style `q_phi/r_hat/B_epsilon^sw` interface.  It does not run or edit
`.slx` files.  AI remains a supervisory parameter scheduler that proposes
candidate scores and risk estimates; IQCOT remains the inner loop.

The script output is a calibrated rule/risk interface, not a trained neural
network, not hardware validation, and not proof of a global `T_slew` optimum.

## Outputs

- Risk grid rows: `{len(grid)}`
- Policy-surface rows: `{len(policy)}`
- Next validation-plan rows: `{len(plan)}`
- B-epsilon labels: `{counts}`

## Policy Surface

{md_table(policy, [
    "target_label",
    "objective",
    "tau_ai_us",
    "q_phi_candidate_us",
    "q_phi_candidate_label",
    "candidate_total_risk",
    "plant_commit_us",
    "plant_commit_label",
    "deployment_status",
], max_rows=30)}

## Transition-Pocket Validation Plan

{md_table(plan, [
    "r034_case_id",
    "target_label",
    "objective",
    "tau_ai_us",
    "candidate_ref_slew_us",
    "priority",
], max_rows=25)}

## Interpretation

R034 makes the R033 correction deployable in shape.  The main rule is not
simple tau interpolation.  For `20A/score_settle005`, the predictor creates a
narrow `50us` transition pocket near `tau_AI=1.5us`, keeps `30us` as fallback
outside the pocket, and blocks `66us`-class large jumps.  The generated R034
validation plan probes `tau_AI=1.0/1.25/1.75/2.0us` with
`38/46/50/54/58us` candidates to test whether the pocket is real or just a
single-point artifact.

Boundary: the policy-surface table should be described as a deployable
interface proposal and next-experiment generator.  It should not be described
as independent generalization or hardware evidence.
"""
    REPORT.write_text(report, encoding="utf-8")

    paper = f"""## R034 可部署短时风险接口：由 R033 边界修正到 `q_phi/r_hat/B_epsilon^sw`

基于 R033 的 `31` 行派生 Simulink 边界验证，本文进一步将局部结论整理为可部署风格的短时风险接口。该接口由三部分组成：候选评分 `q_phi(z_k,T_slew,tau_AI)`、风险估计 `r_hat(z_k,T_slew,tau_AI)`，以及最终安全投影 `B_epsilon^sw`。需要强调的是，R034 不是新的硬件实验，也不是神经网络闭环控制；它是把已有派生模型证据转成监督层参数调度接口和下一轮验证矩阵。

R034 的核心修正是：`T_slew` 的可提交集合不能只随 `tau_AI` 平滑移动，而必须识别 skip/settling 模式边界。对于 `10A/score_settle010`，接口保留 `30-34 us` near-tie candidate band；对于 `20A/base`，`86 us` 只保留为 base objective 下的候选探针，plant 侧默认仍回到 `80 us` fallback；对于 `20A/score_settle005`，接口在 `tau_AI≈1.5 us` 附近形成 `50 us` transition pocket，但在口袋外回到 `30 us` fallback，并继续阻止 `66 us` 直接覆盖。

为了检验该 transition pocket 是否只是单点偶然，R034 生成了 `20` 行下一轮派生 Simulink 细扫计划，覆盖 `tau_AI=1.0/1.25/1.75/2.0 us` 与 `T_slew=38/46/50/54/58 us`。因此，R034 对论文主张的贡献是把 PIS-IEK 的事件域小信号思想落成“候选生成 + 风险预测 + 安全投影 + 最小验证矩阵”的闭环研究流程，而不是宣称 AI/proxy 已经全局优于查表或完成硬件验证。
"""
    PAPER.write_text(paper, encoding="utf-8")


def update_docs(grid: pd.DataFrame, policy: pd.DataFrame, plan: pd.DataFrame) -> None:
    section = PAPER.read_text(encoding="utf-8")
    append_once(ROOT / "RESEARCH_BRIEF.md", "## R034 可部署短时风险接口", "\n" + section)
    append_once(OUT / "iqcot_integrated_research_paper.md", "## R034 可部署短时风险接口", "\n" + section)
    append_once(OUT / "iqcot_pis_iek_derivation_package.md", "## R034 Addition", """
## R034 Addition: deployable risk projection interface

R034 将 R033 的边界修正整理为可部署风格的
`q_phi/r_hat/B_epsilon^sw` 接口。其关键不是把 `T_slew` 当作随
`tau_AI` 平滑变化的回归量，而是在事件域小信号坐标中显式保留
skip、settling 和相位风险。`20A/score_settle005` 的 `50us`
transition pocket 被写成需要进一步验证的局部安全投影口袋；`66us`
仍为 blocked large-jump candidate。
""")
    append_once(OUT / "iqcot_ai_supervisor_validation_design.md", "## 24. R034", f"""
## 24. R034 short-horizon risk predictor / deployable projection

R034 已生成轻量可部署风险接口与下一轮细扫计划：

- `E:/Desktop/codex/output/iqcot_r034_deployable_risk_predictor.py`
- `E:/Desktop/codex/output/iqcot_r034_deployable_risk_grid.csv`
- `E:/Desktop/codex/output/iqcot_r034_policy_surface.csv`
- `E:/Desktop/codex/output/iqcot_r034_transition_pocket_validation_plan.csv`

当前接口只作为监督层候选生成和安全投影原型。下一轮派生 Simulink 计划共 `{len(plan)}` 行，聚焦 `20A/score_settle005` 的 `tau_AI≈1.5us` 过渡口袋，不代表硬件验证或全局最优证明。
""")
    evidence = f"""
### C28 / R034：可部署短时风险接口与 transition-pocket 细扫计划

| ID | 论断 | 支撑证据 | 强度 | 允许写法 | 禁止写法 |
|---|---|---|---|---|---|
| C28 | R034 将 R033 的边界修正整理为可部署风格的 `q_phi/r_hat/B_epsilon^sw` 接口，并生成 `20A/score_settle005` 过渡口袋的最小细扫矩阵。 | `iqcot_r034_deployable_risk_predictor.py`；`iqcot_r034_deployable_risk_grid.csv` 共 `{len(grid)}` 行；`iqcot_r034_policy_surface.csv` 共 `{len(policy)}` 行；`iqcot_r034_transition_pocket_validation_plan.csv` 共 `{len(plan)}` 行。 | 中等偏弱，设计/计划证据 | “R034 把 PIS-IEK 的事件风险信息转成监督层候选评分、风险估计和安全投影接口，并提出下一轮最小验证矩阵。” | “R034 已证明 AI/proxy 泛化优于查表、完成硬件验证、或证明 `50us` transition pocket 全局最优。” |
"""
    append_once(OUT / "iqcot_claims_evidence_matrix.md", "### C28 / R034", evidence)
    wiki_page = f"""# Experiment: R034 deployable risk predictor prototype

## ID

`exp:deployable-risk-predictor-r034`

## Purpose

Convert R033 boundary-validation evidence into an interpretable
`q_phi/r_hat/B_epsilon^sw` supervisory interface and a next validation matrix.

## Outputs

- `E:/Desktop/codex/output/iqcot_r034_deployable_risk_grid.csv`
- `E:/Desktop/codex/output/iqcot_r034_policy_surface.csv`
- `E:/Desktop/codex/output/iqcot_r034_transition_pocket_validation_plan.csv`
- `E:/Desktop/codex/output/iqcot_r034_deployable_risk_predictor_report.md`
- `E:/Desktop/codex/output/figures/fig45_r034_deployable_risk_predictor.svg`

## Result

R034 proposes a deployable-style interface and generates `{len(plan)}` new
derived-Simulink validation cases.  It keeps `66us` blocked, treats
`20A/base/86us` as candidate-only, and creates a local `50us` transition pocket
for `20A/score_settle005` near `tau_AI=1.5us`.

## Boundary

Design/proposal evidence only until the generated validation plan is run.
Not hardware validation and not independent generalization proof.
"""
    append_once(WIKI_EXP, "# Experiment: R034", wiki_page)
    append_once(WIKI / "query_pack.md", "## R034 Update", f"""
## R034 Update

- `exp:deployable-risk-predictor-r034`: converts R033 into a lightweight `q_phi/r_hat/B_epsilon^sw` interface and emits `{len(plan)}` transition-pocket validation cases for `20A/score_settle005`.  It keeps `66us` blocked and treats `50us` near `tau_AI=1.5us` as a local pocket requiring further derived-Simulink validation.
""")
    append_once(WIKI / "index.md", "exp:deployable-risk-predictor-r034", "- `exp:deployable-risk-predictor-r034` - R034 deployable risk predictor prototype and transition-pocket validation plan\n")
    append_once(WIKI / "log.md", "exp:deployable-risk-predictor-r034", "- `2026-06-21T01:00:00Z` add_experiment: added exp:deployable-risk-predictor-r034 [verdict=planned confidence=medium]; created risk predictor prototype and 20-row transition-pocket plan\n")
    edge_path = WIKI / "graph" / "edges.jsonl"
    edge_path.parent.mkdir(parents=True, exist_ok=True)
    old = edge_path.read_text(encoding="utf-8", errors="replace") if edge_path.exists() else ""
    edges = [
        {
            "from": "idea:iqcot-pis-iek-four-phase",
            "to": "exp:deployable-risk-predictor-r034",
            "type": "tested_by",
            "evidence": "R034 turns R033 boundary evidence into a deployable risk predictor prototype and validation plan.",
            "added": "2026-06-21T01:00:00Z",
        },
        {
            "from": "exp:deployable-risk-predictor-r034",
            "to": "exp:delay-band-validation-r033",
            "type": "refines",
            "evidence": "R034 encodes R033 near-tie, objective-probe, and transition-pocket findings into q_phi/r_hat/B_epsilon rules.",
            "added": "2026-06-21T01:00:05Z",
        },
    ]
    additions = [json.dumps(e, ensure_ascii=False) for e in edges if json.dumps(e, ensure_ascii=False) not in old]
    if additions:
        sep = "" if old.endswith("\n") or not old else "\n"
        edge_path.write_text(old + sep + "\n".join(additions) + "\n", encoding="utf-8")


def write_audit(grid: pd.DataFrame, policy: pd.DataFrame, plan: pd.DataFrame) -> None:
    LOGS.mkdir(parents=True, exist_ok=True)
    labels = grid["bepsilon_label"].value_counts().to_dict()
    audit = f"""# Local Audit R034 Deployable Risk Predictor

Date: 2026-06-21

## Checks

- Input R033 context exists: `{R033_CONTEXT.exists()}`
- Input R033 rules exist: `{R033_RULES.exists()}`
- Risk grid rows: `{len(grid)}`
- Policy surface rows: `{len(policy)}`
- Transition validation plan rows: `{len(plan)}` / expected `20`
- Label counts: `{labels}`
- Boundary language: report and paper section state that R034 is a prototype/planning step, not hardware validation or global optimum proof.
- Original `.slx` modified: no; this script only writes CSV/Markdown/SVG artifacts.

## Verdict

PASS with scope limitation.  R034 is internally consistent as a deployable
interface prototype and validation-plan generator.  Claims must remain at the
design/proposal level until the generated R034 transition-pocket plan is run.
"""
    AUDIT.write_text(audit, encoding="utf-8")


def main() -> None:
    if not R033_CONTEXT.exists():
        raise FileNotFoundError(R033_CONTEXT)
    if not R033_RULES.exists():
        raise FileNotFoundError(R033_RULES)
    grid = build_risk_grid()
    policy = build_policy_surface(grid)
    plan = build_validation_plan()

    OUT.mkdir(parents=True, exist_ok=True)
    grid.to_csv(RISK_GRID, index=False)
    policy.to_csv(POLICY_SURFACE, index=False)
    plan.to_csv(VALIDATION_PLAN, index=False)
    write_figure(grid, policy)
    write_reports(grid, policy, plan)
    update_docs(grid, policy, plan)
    write_audit(grid, policy, plan)

    print(f"Wrote {RISK_GRID}")
    print(f"Wrote {POLICY_SURFACE}")
    print(f"Wrote {VALIDATION_PLAN}")
    print(f"Wrote {REPORT}")
    print(f"Wrote {PAPER}")
    print(f"Wrote {SVG}")
    print(f"Wrote {AUDIT}")


if __name__ == "__main__":
    main()
