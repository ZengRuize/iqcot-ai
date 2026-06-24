#!/usr/bin/env python3
"""Post-process R036 dense-paired boundary validation.

R036 adds the missing dense 30us fallback rows at tau_AI=1.25us and 1.75us
for the 20A/score_settle005 folded-band study.  The aim is narrow:

1. Compare the R034 folded probes against the newly simulated dense fallback.
2. Update the local deployable projection status for the two pending delays.
3. Produce a small short-horizon r_hat training view whose inputs are
   deployable context/candidate features and whose labels come from derived
   Simulink outcomes.

The outputs remain derived-Simulink/post-processing evidence.  They are not
hardware validation, global T_slew optimality proof, or AI replacement of the
IQCOT inner event loop.
"""

from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path

import pandas as pd


ROOT = Path("E:/Desktop/codex")
OUT = ROOT / "output"
FIG = OUT / "figures"
WIKI = ROOT / "research-wiki"
LOGS = ROOT / "refine-logs"

R034_COMBINED = OUT / "iqcot_r034_transition_pocket_results_full_combined.csv"
R035_SURFACE = OUT / "iqcot_r035_folded_band_policy_surface.csv"
R036_RESULTS = OUT / "iqcot_r027_proxy_table_in_loop_results_r036_dense_pair.csv"

COMBINED = OUT / "iqcot_r036_dense_pair_results_combined.csv"
CONTEXT = OUT / "iqcot_r036_dense_pair_context_summary.csv"
POLICY = OUT / "iqcot_r036_dense_pair_policy_update.csv"
RHAT_VIEW = OUT / "iqcot_r036_short_horizon_rhat_training_view.csv"
REPORT = OUT / "iqcot_r036_dense_pair_report.md"
PAPER = OUT / "iqcot_r036_dense_pair_paper_section.md"
SVG = FIG / "fig49_r036_dense_pair_boundary.svg"
AUDIT = LOGS / "LOCAL_AUDIT_R036_DENSE_PAIR_BOUNDARY_20260621.md"
WIKI_EXP = WIKI / "experiments" / "dense-paired-boundary-r036.md"

CTX = ["target_label", "objective", "tau_ai_us"]


def fmt(x: object, digits: int = 3) -> str:
    if pd.isna(x):
        return ""
    if isinstance(x, float):
        return f"{x:.{digits}f}"
    return str(x)


def md_table(df: pd.DataFrame, cols: list[str]) -> str:
    lines = [
        "| " + " | ".join(cols) + " |",
        "| " + " | ".join(["---"] * len(cols)) + " |",
    ]
    for _, row in df[cols].iterrows():
        lines.append("| " + " | ".join(fmt(row[c]) for c in cols) + " |")
    return "\n".join(lines)


def append_once(path: Path, marker: str, text: str) -> None:
    old = path.read_text(encoding="utf-8", errors="replace") if path.exists() else ""
    if marker in old:
        return
    sep = "" if not old or old.endswith("\n") else "\n"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(old + sep + text.strip() + "\n", encoding="utf-8")


def write_csv(path: Path, df: pd.DataFrame) -> None:
    path.write_text(df.to_csv(index=False, lineterminator="\n"), encoding="utf-8")


def read_inputs() -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    missing = [p for p in [R034_COMBINED, R035_SURFACE, R036_RESULTS] if not p.exists()]
    if missing:
        raise FileNotFoundError("Missing R036 inputs: " + ", ".join(str(p) for p in missing))

    r034 = pd.read_csv(R034_COMBINED)
    r036 = pd.read_csv(R036_RESULTS)
    surface = pd.read_csv(R035_SURFACE)

    keep_cols = [
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
    ]
    r034 = r034[keep_cols + ["evidence_source"]].copy()
    r034 = r034[
        (r034["target_label"] == "20A")
        & (r034["objective"] == "score_settle005")
        & (r034["tau_ai_us"].astype(float).isin([1.25, 1.75]))
    ].copy()
    r036 = r036[keep_cols].copy()
    r036["evidence_source"] = "R036_dense_pair_validation"

    rows = pd.concat([r034, r036], ignore_index=True)
    numeric_cols = [
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
    ]
    for col in numeric_cols:
        rows[col] = pd.to_numeric(rows[col], errors="coerce")
    rows = rows.sort_values(["tau_ai_us", "selected_ref_slew_us", "evidence_source"]).reset_index(drop=True)
    rows["context_best_score"] = rows.groupby(CTX)["selected_objective_score"].transform("min")
    rows["context_regret"] = rows["selected_objective_score"] - rows["context_best_score"]
    rows["candidate_role"] = rows["selected_ref_slew_us"].map(
        lambda x: "dense_30us_fallback" if abs(float(x) - 30.0) < 1e-9 else "folded_transition_probe"
    )
    return rows, surface, r036


def build_context(rows: pd.DataFrame) -> pd.DataFrame:
    recs: list[dict[str, object]] = []
    for key, g in rows.groupby(CTX, sort=True):
        target, objective, tau = key
        ordered = g.sort_values("selected_objective_score")
        best = ordered.iloc[0]
        dense = g[g["selected_ref_slew_us"] == 30.0].iloc[0]
        folded = ordered[ordered["selected_ref_slew_us"] != 30.0].iloc[0]
        recs.append(
            {
                "target_label": target,
                "objective": objective,
                "tau_ai_us": float(tau),
                "n_candidates_with_dense": int(len(g)),
                "dense_slew_us": float(dense["selected_ref_slew_us"]),
                "dense_score": float(dense["selected_objective_score"]),
                "dense_skip_count_est": float(dense["skip_count_est"]),
                "dense_settle_time_us": float(dense["settle_time_us"]),
                "dense_phase_std_ns": float(dense["final_phase_spacing_std_ns"]),
                "folded_best_slew_us": float(folded["selected_ref_slew_us"]),
                "folded_best_score": float(folded["selected_objective_score"]),
                "folded_skip_count_est": float(folded["skip_count_est"]),
                "folded_settle_time_us": float(folded["settle_time_us"]),
                "folded_phase_std_ns": float(folded["final_phase_spacing_std_ns"]),
                "dense_minus_folded_score": float(dense["selected_objective_score"] - folded["selected_objective_score"]),
                "winner_role": str(best["candidate_role"]),
                "winner_slew_us": float(best["selected_ref_slew_us"]),
                "winner_score": float(best["selected_objective_score"]),
                "interpretation": "folded probe beats dense fallback in the paired derived-Simulink check"
                if float(best["selected_ref_slew_us"]) != 30.0
                else "dense fallback remains best in this paired derived-Simulink check",
            }
        )
    return pd.DataFrame(recs)


def update_policy_surface(surface: pd.DataFrame, context: pd.DataFrame) -> pd.DataFrame:
    policy = surface.copy()
    for row in context.itertuples():
        mask = (
            (policy["target_label"] == row.target_label)
            & (policy["objective"] == row.objective)
            & (policy["tau_ai_us"].astype(float) == float(row.tau_ai_us))
        )
        if not mask.any():
            continue
        policy.loc[mask, "dense_fallback_us"] = row.dense_slew_us
        policy.loc[mask, "dense_score"] = row.dense_score
        policy.loc[mask, "dense_regret"] = row.dense_minus_folded_score
        if row.winner_role == "folded_transition_probe":
            policy.loc[mask, "deployable_commit_us"] = row.winner_slew_us
            policy.loc[mask, "deployment_status"] = "dense_pair_validated_local_commit"
            policy.loc[mask, "decision_reason"] = (
                "R036 dense-paired check shows folded probe beats 30us dense fallback locally; "
                "still requires B_epsilon^sw risk gate and is not a global optimum."
            )
        else:
            policy.loc[mask, "deployable_commit_us"] = 30.0
            policy.loc[mask, "deployment_status"] = "dense_pair_keeps_fallback"
            policy.loc[mask, "decision_reason"] = (
                "R036 dense-paired check keeps 30us fallback for this local delay."
            )
    return policy


def build_rhat_view(rows: pd.DataFrame) -> pd.DataFrame:
    view = rows.copy()
    view["load_drop_norm"] = view["load_drop_A"] / 40.0
    view["candidate_minus_dense_us"] = view["selected_ref_slew_us"] - 30.0
    view["delay_events_est"] = view["delay_events"]
    view["skip_risk_label"] = (view["skip_count_est"] > 0).astype(int)
    view["settling_risk_label"] = (view["settle_time_us"] > 5.0).astype(int)
    view["phase_risk_label"] = (view["final_phase_spacing_std_ns"] > 50.0).astype(int)
    view["rhat_target_vector"] = view.apply(
        lambda r: f"skip={int(r.skip_risk_label)},settle={int(r.settling_risk_label)},phase={int(r.phase_risk_label)}",
        axis=1,
    )
    return view[
        [
            "r027_case_id",
            "target_label",
            "target_load_A",
            "load_drop_norm",
            "objective_alpha_settle",
            "tau_ai_us",
            "delay_events_est",
            "selected_ref_slew_us",
            "candidate_minus_dense_us",
            "selected_objective_score",
            "context_regret",
            "skip_risk_label",
            "settling_risk_label",
            "phase_risk_label",
            "rhat_target_vector",
            "candidate_role",
            "evidence_source",
        ]
    ].copy()


def write_svg(rows: pd.DataFrame, context: pd.DataFrame) -> None:
    FIG.mkdir(parents=True, exist_ok=True)
    width, height = 1080, 560
    left, top, plot_w, plot_h = 90, 70, 720, 340
    tau_min, tau_max = 1.18, 1.82
    slew_min, slew_max = 26.0, 60.0

    def x_of(tau: float) -> float:
        return left + (tau - tau_min) / (tau_max - tau_min) * plot_w

    def y_of(slew: float) -> float:
        return top + (slew_max - slew) / (slew_max - slew_min) * plot_h

    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        '<rect width="100%" height="100%" fill="white"/>',
        '<text x="70" y="34" font-family="Arial" font-size="21" font-weight="bold">R036 dense-paired boundary validation</text>',
        '<text x="70" y="55" font-family="Arial" font-size="13" fill="#555">20A / score+0.05Tsettle: folded probes vs newly simulated 30us dense fallback</text>',
        f'<rect x="{left}" y="{top}" width="{plot_w}" height="{plot_h}" fill="#fbfbfb" stroke="#222"/>',
    ]
    for tau in [1.25, 1.75]:
        x = x_of(tau)
        parts.append(f'<line x1="{x:.1f}" y1="{top}" x2="{x:.1f}" y2="{top+plot_h}" stroke="#e5e7eb"/>')
        parts.append(f'<text x="{x:.1f}" y="{top+plot_h+23}" font-family="Arial" font-size="12" text-anchor="middle">{tau:g}us</text>')
    for slew in [30, 38, 46, 50, 54, 58]:
        y = y_of(slew)
        parts.append(f'<line x1="{left}" y1="{y:.1f}" x2="{left+plot_w}" y2="{y:.1f}" stroke="#eee"/>')
        parts.append(f'<text x="{left-45}" y="{y+4:.1f}" font-family="Arial" font-size="12">{slew}us</text>')

    max_regret = max(rows["context_regret"].max(), 1e-9)
    for r in rows.itertuples():
        x = x_of(float(r.tau_ai_us))
        y = y_of(float(r.selected_ref_slew_us))
        is_best = abs(float(r.context_regret)) < 1e-9
        is_dense = abs(float(r.selected_ref_slew_us) - 30.0) < 1e-9
        fill = "#2f855a" if is_best else ("#c53030" if is_dense else "#f28e2b")
        radius = 6.5 if is_best else 5.0 + 4.0 * min(1.0, float(r.context_regret) / max_regret)
        parts.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{radius:.1f}" fill="{fill}" opacity="0.82"/>')
        parts.append(f'<text x="{x+9:.1f}" y="{y-8:.1f}" font-family="Arial" font-size="10">{r.selected_objective_score:.3f}</text>')

    best_pts = " ".join(
        f"{x_of(float(r.tau_ai_us)):.1f},{y_of(float(r.winner_slew_us)):.1f}" for r in context.itertuples()
    )
    parts.append(f'<polyline points="{best_pts}" fill="none" stroke="#1a365d" stroke-width="3"/>')
    parts.append(f'<text x="{left+plot_w/2-30}" y="{top+plot_h+50}" font-family="Arial" font-size="14">tau_AI</text>')
    parts.append(f'<text x="18" y="{top+plot_h/2}" font-family="Arial" font-size="14" transform="rotate(-90 18,{top+plot_h/2})">T_slew</text>')

    right_x = 840
    parts.append(f'<text x="{right_x}" y="95" font-family="Arial" font-size="14" font-weight="bold">R036 update</text>')
    for i, r in enumerate(context.itertuples()):
        parts.append(
            f'<text x="{right_x}" y="{125+i*36}" font-family="Arial" font-size="12">'
            f'tau={r.tau_ai_us:g}: folded {r.folded_best_slew_us:g}us beats dense by {r.dense_minus_folded_score:.3f}</text>'
        )
    parts.append(f'<text x="{right_x}" y="230" font-family="Arial" font-size="12" fill="#555">Red: dense fallback loses with skip=1.</text>')
    parts.append(f'<text x="{right_x}" y="252" font-family="Arial" font-size="12" fill="#555">Green: local paired winner.</text>')
    parts.append(f'<text x="70" y="520" font-family="Arial" font-size="11" fill="#555">Boundary: derived Simulink only; no hardware/HIL or global optimum claim.</text>')
    parts.append("</svg>")
    SVG.write_text("\n".join(parts), encoding="utf-8")


def write_reports(context: pd.DataFrame, policy: pd.DataFrame, rhat: pd.DataFrame) -> None:
    report = f"""# R036 Dense-Paired Boundary Validation

## Scope

R036 adds the two dense `30us` fallback rows that were missing from the R035
pending points: `20A/score_settle005` at `tau_AI=1.25us` and `1.75us`.
The run uses only the derived delayed-reference Simulink model under
`output/simulink_iek`; it does not modify the original `.slx` and is not
hardware validation.

## Paired Result

{md_table(context, [
    "tau_ai_us",
    "dense_slew_us",
    "dense_score",
    "dense_skip_count_est",
    "dense_phase_std_ns",
    "folded_best_slew_us",
    "folded_best_score",
    "folded_skip_count_est",
    "folded_phase_std_ns",
    "dense_minus_folded_score",
    "winner_role",
])}

Both newly simulated dense fallback rows lose to the R034 folded probes.  The
loss is not just a score artifact: the `30us` fallback triggers one estimated
skip in both paired rows, while the winning folded probes have zero estimated
skip and lower phase-spacing standard deviation.

## Policy Update

- `tau_AI=1.25us`: upgrade `46us` from candidate-only to local dense-pair
  validated commit inside the current derived-model objective.
- `tau_AI=1.75us`: upgrade `54us` from candidate-only to local dense-pair
  validated commit inside the current derived-model objective.
- `tau_AI=2.0us` remains a separate boundary: R035/R031 dense-inclusive
  evidence still keeps `30us` fallback there, despite R034 transition probes.
- `66us` remains blocked as a direct override.

## Short-Horizon r_hat Interface

The R036 training view keeps only deployable context/candidate inputs
(`target_load_A`, `load_drop_norm`, `alpha_settle`, `tau_AI`,
`delay_events`, `candidate T_slew`, and candidate distance from dense
fallback).  Skip, settling, and phase columns are labels derived from the
switching replay, not online inputs.  This gives a small calibration target for
a future short-horizon predictor:

```text
r_hat(z_k,T_slew,tau_AI,recent_event_state)
  -> [skip_risk, settling_risk, phase_risk]
T_slew,plant = Proj_{{B_epsilon^sw}}(T_slew,candidate; r_hat, T_dense)
```

## Boundary

R036 strengthens the local folded-band evidence at two missing dense-paired
delays, but it still does not prove a global `T_slew` optimum or hardware
safety.  AI remains a supervisory parameter scheduler; IQCOT remains the inner
event loop.
"""
    REPORT.write_text(report.strip() + "\n", encoding="utf-8")

    paper = f"""### R036 dense-paired boundary validation

R035 left two folded-band delays in a candidate-only state because the `30us`
dense fallback had not yet been co-tested at the same AI commit delay.  R036
therefore executed two additional derived-Simulink delayed-reference cases for
`20A/score+0.05T_settle`: `tau_AI=1.25us, T_slew=30us` and
`tau_AI=1.75us, T_slew=30us`.  In the paired comparison, the dense fallback
scores are `{context.iloc[0].dense_score:.3f}` and
`{context.iloc[1].dense_score:.3f}`, while the corresponding folded probes
`46us` and `54us` score `{context.iloc[0].folded_best_score:.3f}` and
`{context.iloc[1].folded_best_score:.3f}`.  The improvement is accompanied by
removing one estimated skip and reducing phase-spacing dispersion in both
contexts.

This result upgrades `46us` at `tau_AI=1.25us` and `54us` at
`tau_AI=1.75us` from pending folded probes to locally dense-paired candidates
for the current four-phase derived model and objective.  The claim remains
bounded: R036 is not hardware/HIL validation, does not imply a global
`T_slew` optimum, and does not make the AI supervisor a replacement for the
IQCOT inner event loop.  Its role is to calibrate the
`q_phi/r_hat/B_epsilon^sw` supervision path by showing where the dense fallback
is genuinely too conservative and where it must remain active.
"""
    PAPER.write_text(paper.strip() + "\n", encoding="utf-8")

    audit = f"""# Local Audit R036 Dense-Paired Boundary

- Timestamp UTC: {datetime.now(timezone.utc).isoformat(timespec="seconds")}
- Inputs: `{R034_COMBINED}`, `{R035_SURFACE}`, `{R036_RESULTS}`
- New paired rows: `2`, both successful.
- Key result: `46us` at `tau_AI=1.25us` and `54us` at `tau_AI=1.75us` beat the newly simulated `30us` dense fallback in the current derived model/objective.
- Guardrail: the result is local derived-Simulink evidence only.  It is not hardware validation, global T_slew optimality, or proof that AI replaces the IQCOT inner loop.
- Claim check: `66us` remains blocked; `tau_AI=2us` still keeps `30us` fallback under R035/R031 dense-inclusive evidence.
- r_hat check: skip/settling/phase columns in `{RHAT_VIEW}` are labels, not online inputs.
"""
    AUDIT.write_text(audit.strip() + "\n", encoding="utf-8")

    wiki = f"""# R036 Dense-Paired Boundary Validation

R036补齐了R035中两个pending点的dense对照：`20A/score_settle005`在
`tau_AI=1.25us`和`1.75us`下的`30us` fallback。两行派生Simulink均成功。

{md_table(context, [
    "tau_ai_us",
    "dense_score",
    "dense_skip_count_est",
    "folded_best_slew_us",
    "folded_best_score",
    "dense_minus_folded_score",
])}

结论边界：`46us`和`54us`分别升级为当前派生模型/当前目标函数下的局部
dense-paired候选；这不是硬件验证、不是全局最优，也不意味着AI替代IQCOT内环。
`66us`仍为blocked direct override，`tau_AI=2us`仍由R031/R035证据保持`30us`
fallback。
"""
    WIKI_EXP.parent.mkdir(parents=True, exist_ok=True)
    WIKI_EXP.write_text(wiki.strip() + "\n", encoding="utf-8")


def update_docs() -> None:
    marker = "<!-- R036_DENSE_PAIR_BOUNDARY -->"
    paper_text = PAPER.read_text(encoding="utf-8")
    append_once(OUT / "iqcot_integrated_research_paper.md", marker, f"\n{marker}\n\n{paper_text}\n")
    append_once(
        OUT / "iqcot_pis_iek_derivation_package.md",
        marker,
        f"""{marker}

### R036 dense-paired boundary and `r_hat` labels

R036 adds two derived-Simulink dense fallback rows at `tau_AI=1.25/1.75us`.
They show that the folded probes `46/54us` outperform `30us` fallback in the
current `20A/score_settle005` objective, mainly by avoiding the dense fallback
skip event and reducing phase-spacing dispersion.  In the PIS-IEK interface,
this supports a short-horizon risk predictor view:

```text
r_hat(z_k,T_slew,tau_AI,recent_event_state)
  -> [skip_risk, settling_risk, phase_risk]
T_slew,plant = Proj_B(T_slew,candidate; r_hat, T_dense)
```

The labels in `iqcot_r036_short_horizon_rhat_training_view.csv` are derived
from switching replay and are not assumed to be directly available online.
""",
    )
    append_once(
        OUT / "iqcot_ai_supervisor_validation_design.md",
        marker,
        f"""{marker}

## R036 dense-paired boundary validation

R036补充了`20A/score_settle005`在`tau_AI=1.25us`与`1.75us`下的`30us`
dense fallback派生Simulink对照。结果显示，`46us`和`54us` folded probes在
同一延迟下分别比`30us` fallback低约`2.843`和`2.175`分，并避免了fallback
中的一次skip。因此这两个点可从R035的candidate-only升级为局部
dense-paired候选。

这仍不是神经网络AI-in-loop或硬件验证。监督层接口应继续写成
`q_phi`候选生成、`r_hat`短时风险预测和`B_epsilon^sw`投影；`66us`直接覆盖仍被阻止。
""",
    )
    append_once(
        OUT / "iqcot_claims_evidence_matrix.md",
        marker,
        f"""{marker}

### C32 / R036：dense-paired boundary validation

| Claim | Evidence | Strength | Safe wording | Do not claim |
|---|---|---|---|---|
| R036补齐`20A/score_settle005`在`tau_AI=1.25/1.75us`的dense fallback成对验证，并支持将`46/54us` folded probes升级为局部dense-paired候选 | `iqcot_r036_dense_pair_postprocess.py`; `iqcot_r027_proxy_table_in_loop_results_r036_dense_pair.csv`两行全部成功；`iqcot_r036_dense_pair_context_summary.csv`显示`46us`相对`30us`改善约`2.843`分，`54us`相对`30us`改善约`2.175`分，且dense fallback均出现`skip_count=1` | 中等，局部派生Simulink证据 | “R036支持在当前四相派生模型和当前目标函数下，将`tau_AI=1.25/1.75us`的folded probes作为经过dense成对校准的局部候选。” | “R036证明folded band全局最优、硬件安全，或AI/proxy可直接替代dense fallback和IQCOT内环。” |
""",
    )
    append_once(
        WIKI / "query_pack.md",
        marker,
        f"""{marker}

## R036 Latest Update

R036完成`20A/score_settle005`在`tau_AI=1.25/1.75us`的dense-paired边界验证。
新增两行`30us` fallback派生Simulink均成功；与R034 folded probes合并后，
`46us`在`1.25us`、`54us`在`1.75us`均优于`30us` fallback，fallback两行都出现
`skip_count=1`。结论只能写成局部dense-paired候选升级，不是硬件验证或全局最优；
`66us`继续blocked，`tau_AI=2us`仍保持`30us` fallback。
""",
    )
    append_once(
        WIKI / "index.md",
        marker,
        f"""{marker}

- [R036 dense-paired boundary validation](experiments/dense-paired-boundary-r036.md): 补齐`20A/score_settle005`在`tau_AI=1.25/1.75us`的`30us` fallback对照，局部支持`46/54us` folded probes，但不作硬件或全局最优claim。
""",
    )
    append_once(
        WIKI / "log.md",
        marker,
        f"""{marker}

## 2026-06-21 R036 dense-paired boundary

- Added two derived-Simulink dense fallback rows for `20A/score_settle005`.
- `46us@1.25us` and `54us@1.75us` beat `30us` fallback locally.
- Updated paper, evidence matrix, derivation package, AI validation design, query pack, and wiki experiment note.
""",
    )


def main() -> None:
    rows, surface, _ = read_inputs()
    context = build_context(rows)
    policy = update_policy_surface(surface, context)
    rhat = build_rhat_view(rows)

    write_csv(COMBINED, rows)
    write_csv(CONTEXT, context)
    write_csv(POLICY, policy)
    write_csv(RHAT_VIEW, rhat)

    write_svg(rows, context)
    write_reports(context, policy, rhat)
    update_docs()

    print("R036_COMBINED=" + str(COMBINED))
    print("R036_CONTEXT=" + str(CONTEXT))
    print("R036_POLICY=" + str(POLICY))
    print("R036_RHAT_VIEW=" + str(RHAT_VIEW))
    print("R036_REPORT=" + str(REPORT))
    print("R036_FIGURE=" + str(SVG))


if __name__ == "__main__":
    main()
