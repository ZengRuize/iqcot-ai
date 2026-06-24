#!/usr/bin/env python3
"""R032 delay-aware B_epsilon^sw band projection prototype.

This script post-processes the completed R031 minimal held-out
derived-Simulink results.  It turns the R031 local-band evidence into a
deployable-style short-horizon risk interface:

    q_phi(z_k, T_slew, tau_AI) -> score candidate
    r_hat(z_k, T_slew, tau_AI, recent_state) -> skip/settle/phase risk
    T_slew,plant = Proj_{B_epsilon^sw}(T_slew,candidate)

No .slx file is edited or executed here.  The generated R032 replay is a
known-context consistency check, not hardware validation and not proof of
global T_slew optimality.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import pandas as pd


ROOT = Path("E:/Desktop/codex")
OUT = ROOT / "output"
FIG = OUT / "figures"

R031_COMBINED = OUT / "iqcot_r031_minimal_validation_results_combined.csv"
R031_CONTEXT = OUT / "iqcot_r031_minimal_validation_context_summary.csv"
R031_FAMILY = OUT / "iqcot_r031_minimal_validation_family_summary.csv"

FEATURES = OUT / "iqcot_r032_candidate_risk_features.csv"
RULES = OUT / "iqcot_r032_delay_band_rules.csv"
POLICY_REPLAY = OUT / "iqcot_r032_policy_replay.csv"
POLICY_SUMMARY = OUT / "iqcot_r032_policy_summary.csv"
NEXT_PLAN = OUT / "iqcot_r032_next_validation_plan.csv"
REPORT = OUT / "iqcot_r032_delay_aware_band_report.md"
PAPER = OUT / "iqcot_r032_delay_aware_band_paper_section.md"
SVG = FIG / "fig43_r032_delay_aware_band.svg"

CTX = ["target_label", "objective", "tau_ai_us"]
DENSE_FAMILY = "r030_dense_baseline"
PROXY_FAMILY = "r030_original_proxy"
INTERMEDIATE_FAMILY = "r031_intermediate_candidate"


@dataclass(frozen=True)
class Selection:
    policy: str
    selected_family: str
    selected_slew_us: float
    rationale: str
    deployability: str


def f3(value: float) -> str:
    return f"{float(value):.3f}"


def read_inputs() -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    for path in [R031_COMBINED, R031_CONTEXT, R031_FAMILY]:
        if not path.exists():
            raise FileNotFoundError(path)
    combined = pd.read_csv(R031_COMBINED)
    context = pd.read_csv(R031_CONTEXT)
    family = pd.read_csv(R031_FAMILY)
    combined["tau_ai_us"] = combined["tau_ai_us"].astype(float)
    combined["selected_ref_slew_us"] = combined["selected_ref_slew_us"].astype(float)
    combined["selected_objective_score"] = combined["selected_objective_score"].astype(float)
    return combined, context, family


def classify_band(row: pd.Series) -> tuple[str, str, float, float, float, float]:
    """Return band action, reason, and risk components in [0, 1]."""
    target = str(row["target_label"])
    objective = str(row["objective"])
    family = str(row["candidate_family"])
    tau = float(row["tau_ai_us"])
    slew = float(row["selected_ref_slew_us"])
    dense_slew = float(row["dense_selected_ref_slew_us"])
    abs_delta = abs(float(row["delta_from_dense_us"]))

    # Dense fallback is always admissible in the current verified envelope.
    if family == DENSE_FAMILY:
        return "plant_admissible", "dense fallback anchor", 0.05, 0.05, 0.05, 0.05

    # In R031 the strong negative sample is the 66us direct proxy for
    # 20A/score_settle005, not every intermediate point beyond 20us.
    large_jump = abs_delta >= 30.0
    skip_risk = 0.10
    settle_risk = 0.10
    phase_risk = 0.10
    total = 0.10
    decision = "candidate_only"
    reason = "unclassified candidate; keep inside candidate set but do not commit"

    if target == "10A" and objective == "score_settle010":
        phase_risk = 0.35
        settle_risk = 0.25
        if family == PROXY_FAMILY and abs(slew - 32.0) < 1e-9:
            decision = "candidate_only"
            reason = "32us proxy is near-tie but not final plant command in R032"
            total = 0.45
        elif abs(slew - 33.0) < 1e-9 and tau >= 3.0:
            decision = "plant_admissible"
            reason = "33us is allowed only in long-delay near-tie subband"
            total = 0.20
        elif abs(slew - 33.0) < 1e-9:
            decision = "blocked"
            reason = "33us worsened tau=1us; require long-delay evidence"
            total = 0.70
        elif abs(slew - dense_slew) <= 2.0:
            decision = "candidate_only"
            reason = "small near-tie perturbation, keep for ranking but default to dense"
            total = 0.45
        else:
            decision = "blocked"
            reason = "outside verified near-tie band"
            total = 0.80

    elif target == "20A" and objective == "base":
        settle_risk = 0.30
        phase_risk = 0.30
        if slew in {82.0, 84.0}:
            decision = "candidate_only"
            reason = "82/84us expose delay sensitivity but do not replace 80us fallback"
            total = 0.45
        elif slew >= 86.0 or family == PROXY_FAMILY:
            decision = "blocked"
            reason = "86us direct override remains blocked after R031"
            total = 0.75
        else:
            decision = "candidate_only"
            reason = "base objective candidate remains below plant-commit threshold"
            total = 0.55

    elif target == "20A" and objective == "score_settle005":
        if large_jump:
            skip_risk = 0.65
            settle_risk = 0.75
            phase_risk = 0.45
            total = 0.85
            decision = "blocked"
            reason = "large jump settling-sensitive negative sample; 66us direct override blocked"
        elif abs(slew - 50.0) < 1e-9 and tau < 0.75:
            skip_risk = 0.15
            settle_risk = 0.20
            phase_risk = 0.25
            total = 0.20
            decision = "plant_admissible"
            reason = "50us improves tau=0.5us held-out context"
        elif abs(slew - 38.0) < 1e-9 and 0.75 <= tau < 1.5:
            skip_risk = 0.15
            settle_risk = 0.20
            phase_risk = 0.25
            total = 0.20
            decision = "plant_admissible"
            reason = "38us improves tau=1us held-out context"
        elif slew in {38.0, 50.0, 58.0}:
            skip_risk = 0.25
            settle_risk = 0.35
            phase_risk = 0.30
            total = 0.55
            decision = "candidate_only"
            reason = "intermediate band is informative but dense remains plant fallback here"
        else:
            total = 0.70
            decision = "blocked"
            reason = "outside verified 38-58us intermediate band"
    else:
        if large_jump:
            skip_risk = 0.55
            settle_risk = 0.55
            total = 0.75
            decision = "blocked"
            reason = "unseen large jump"

    observed_score_margin = float(row["score_margin_vs_dense"])
    if observed_score_margin > 0.5:
        total = max(total, 0.70)
    if float(row["skip_extra_vs_dense"]) > 0:
        skip_risk = max(skip_risk, 0.65)
        total = max(total, 0.75)
    if float(row["settle_extra_vs_dense_us"]) > 5.0:
        settle_risk = max(settle_risk, 0.70)
        total = max(total, 0.75)

    return decision, reason, min(skip_risk, 1.0), min(settle_risk, 1.0), min(phase_risk, 1.0), min(total, 1.0)


def build_features(combined: pd.DataFrame) -> pd.DataFrame:
    combined = combined.drop(
        columns=[c for c in ["context_best_score", "context_regret"] if c in combined.columns]
    ).copy()
    dense = (
        combined[combined["candidate_family"] == DENSE_FAMILY]
        .set_index(CTX)
        .add_prefix("dense_")
    )
    best = (
        combined.loc[combined.groupby(CTX)["selected_objective_score"].idxmin(), CTX + ["selected_ref_slew_us", "selected_objective_score", "candidate_family"]]
        .set_index(CTX)
        .rename(
            columns={
                "selected_ref_slew_us": "context_best_slew_us",
                "selected_objective_score": "context_best_score",
                "candidate_family": "context_best_family",
            }
        )
    )
    rows = combined.join(dense, on=CTX).join(best, on=CTX).copy()
    rows["delta_from_dense_us"] = rows["selected_ref_slew_us"] - rows["dense_selected_ref_slew_us"]
    rows["abs_delta_from_dense_us"] = rows["delta_from_dense_us"].abs()
    rows["score_margin_vs_dense"] = rows["selected_objective_score"] - rows["dense_selected_objective_score"]
    rows["regret"] = rows["selected_objective_score"] - rows["context_best_score"]
    rows["skip_extra_vs_dense"] = rows["skip_count_est"] - rows["dense_skip_count_est"]
    rows["settle_extra_vs_dense_us"] = rows["settle_time_us"] - rows["dense_settle_time_us"]
    rows["phase_extra_vs_dense_ns"] = rows["final_phase_spacing_std_ns"] - rows["dense_final_phase_spacing_std_ns"]
    rows["undershoot_delta_vs_dense_mV"] = rows["undershoot_mV"] - rows["dense_undershoot_mV"]
    rows["score_safe_eps025"] = rows["score_margin_vs_dense"] <= 0.25
    rows["observed_bad_candidate"] = (
        (rows["score_margin_vs_dense"] > 0.50)
        | (rows["skip_extra_vs_dense"] > 0)
        | (rows["settle_extra_vs_dense_us"] > 5.0)
        | (rows["phase_extra_vs_dense_ns"] > 15.0)
    )

    classified = rows.apply(classify_band, axis=1, result_type="expand")
    classified.columns = [
        "r032_band_decision",
        "r032_band_reason",
        "r_hat_skip_risk",
        "r_hat_settle_risk",
        "r_hat_phase_risk",
        "r_hat_total_risk",
    ]
    out = pd.concat([rows, classified], axis=1)
    out["predicted_block"] = out["r032_band_decision"] == "blocked"
    out["predicted_plant_admissible"] = out["r032_band_decision"] == "plant_admissible"
    return out.sort_values(CTX + ["candidate_family", "selected_ref_slew_us"]).reset_index(drop=True)


def select_row(group: pd.DataFrame, family: str | None = None, slew: float | None = None) -> pd.Series:
    g = group.copy()
    if family is not None:
        g = g[g["candidate_family"] == family]
    if slew is not None:
        g = g[(g["selected_ref_slew_us"].astype(float) - float(slew)).abs() < 1e-9]
    if g.empty:
        # Fallback to the dense row if the requested candidate is not present in
        # this context.  This keeps policy replay robust when a future plan has a
        # sparse candidate set.
        g = group[group["candidate_family"] == DENSE_FAMILY]
    return g.iloc[0]


def choose_policy(policy: str, group: pd.DataFrame, training: pd.DataFrame | None = None) -> Selection:
    target = str(group["target_label"].iloc[0])
    objective = str(group["objective"].iloc[0])
    tau = float(group["tau_ai_us"].iloc[0])

    if policy == "dense_fallback":
        row = select_row(group, DENSE_FAMILY)
        return Selection(policy, DENSE_FAMILY, float(row["selected_ref_slew_us"]), "always use dense fallback", "deployable_baseline")

    if policy == "direct_proxy_override":
        row = select_row(group, PROXY_FAMILY)
        return Selection(policy, PROXY_FAMILY, float(row["selected_ref_slew_us"]), "old proxy direct override", "negative_control")

    if policy == "r031_best_intermediate_only":
        cand = group[group["candidate_family"] == INTERMEDIATE_FAMILY]
        if cand.empty:
            row = select_row(group, DENSE_FAMILY)
        else:
            row = cand.loc[cand["selected_objective_score"].idxmin()]
        return Selection(policy, str(row["candidate_family"]), float(row["selected_ref_slew_us"]), "best intermediate candidate without dense fallback", "nondeployable_upper_candidate")

    if policy == "r032_delay_aware_band_projection":
        # R032 plant policy fitted from R031: retain dense fallback except in
        # locally verified, delay-specific subbands.
        if target == "10A" and objective == "score_settle010" and tau >= 3.0:
            row = select_row(group, slew=33.0)
            return Selection(policy, str(row["candidate_family"]), float(row["selected_ref_slew_us"]), "long-delay near-tie band chooses 33us", "calibrated_candidate")
        if target == "20A" and objective == "score_settle005" and tau < 0.75:
            row = select_row(group, slew=50.0)
            return Selection(policy, str(row["candidate_family"]), float(row["selected_ref_slew_us"]), "short-delay settling-aware band chooses 50us", "calibrated_candidate")
        if target == "20A" and objective == "score_settle005" and 0.75 <= tau < 1.5:
            row = select_row(group, slew=38.0)
            return Selection(policy, str(row["candidate_family"]), float(row["selected_ref_slew_us"]), "mid-delay settling-aware band chooses 38us", "calibrated_candidate")
        row = select_row(group, DENSE_FAMILY)
        return Selection(policy, DENSE_FAMILY, float(row["selected_ref_slew_us"]), "dense fallback outside locally verified improvement band", "calibrated_candidate")

    if policy == "nearest_tau_loto_predictor":
        if training is None or training.empty:
            row = select_row(group, DENSE_FAMILY)
            return Selection(policy, DENSE_FAMILY, float(row["selected_ref_slew_us"]), "no training rows; dense fallback", "leave_one_tau_stress")
        train_same = training[
            (training["target_label"] == target)
            & (training["objective"] == objective)
            & (training["candidate_family"] != PROXY_FAMILY)
        ].copy()
        if train_same.empty:
            row = select_row(group, DENSE_FAMILY)
            return Selection(policy, DENSE_FAMILY, float(row["selected_ref_slew_us"]), "no same-motif rows; dense fallback", "leave_one_tau_stress")
        train_best_by_tau = train_same.loc[train_same.groupby("tau_ai_us")["selected_objective_score"].idxmin()].copy()
        train_best_by_tau["tau_distance"] = (train_best_by_tau["tau_ai_us"].astype(float) - tau).abs()
        picked = train_best_by_tau.sort_values(["tau_distance", "selected_objective_score"]).iloc[0]
        requested_slew = float(picked["selected_ref_slew_us"])
        if ((group["selected_ref_slew_us"].astype(float) - requested_slew).abs() < 1e-9).any():
            row = select_row(group, slew=requested_slew)
        else:
            group = group.copy()
            group["slew_distance"] = (group["selected_ref_slew_us"].astype(float) - requested_slew).abs()
            row = group.sort_values(["slew_distance", "selected_objective_score"]).iloc[0]
        return Selection(policy, str(row["candidate_family"]), float(row["selected_ref_slew_us"]), f"nearest training tau requested {requested_slew:g}us", "leave_one_tau_stress")

    raise ValueError(policy)


def evaluate_policies(features: pd.DataFrame) -> tuple[pd.DataFrame, pd.DataFrame]:
    policies = [
        "dense_fallback",
        "direct_proxy_override",
        "r031_best_intermediate_only",
        "nearest_tau_loto_predictor",
        "r032_delay_aware_band_projection",
    ]
    records: list[dict[str, object]] = []
    for key, group in features.groupby(CTX, sort=True):
        training = features[
            ~(
                (features["target_label"] == key[0])
                & (features["objective"] == key[1])
                & (features["tau_ai_us"].astype(float).round(9) == round(float(key[2]), 9))
            )
        ]
        for policy in policies:
            sel = choose_policy(policy, group, training)
            row = select_row(group, sel.selected_family, sel.selected_slew_us)
            records.append(
                {
                    "target_label": key[0],
                    "objective": key[1],
                    "tau_ai_us": float(key[2]),
                    "policy": policy,
                    "selected_family": sel.selected_family,
                    "selected_slew_us": sel.selected_slew_us,
                    "selected_objective_score": float(row["selected_objective_score"]),
                    "context_best_score": float(row["context_best_score"]),
                    "dense_score": float(row["dense_selected_objective_score"]),
                    "regret": float(row["selected_objective_score"] - row["context_best_score"]),
                    "margin_vs_dense": float(row["selected_objective_score"] - row["dense_selected_objective_score"]),
                    "r_hat_total_risk": float(row["r_hat_total_risk"]),
                    "band_decision": row["r032_band_decision"],
                    "rationale": sel.rationale,
                    "deployability": sel.deployability,
                }
            )
    replay = pd.DataFrame(records)
    best_counts = replay[replay["regret"].abs() <= 1e-9].groupby("policy").size()
    summary = (
        replay.groupby(["policy", "deployability"], as_index=False)
        .agg(
            n_contexts=("regret", "count"),
            mean_regret=("regret", "mean"),
            max_regret=("regret", "max"),
            mean_margin_vs_dense=("margin_vs_dense", "mean"),
            non_dense_selected_count=("selected_family", lambda s: int((s != DENSE_FAMILY).sum())),
            mean_r_hat_total_risk=("r_hat_total_risk", "mean"),
        )
        .sort_values(["mean_regret", "max_regret", "policy"])
    )
    summary["zero_regret_context_count"] = summary["policy"].map(best_counts).fillna(0).astype(int)
    return replay, summary


def build_rules(features: pd.DataFrame) -> pd.DataFrame:
    rows = [
        {
            "target_label": "10A",
            "objective": "score_settle010",
            "dense_fallback_us": 30.0,
            "candidate_band_us": "[30, 33]",
            "plant_commit_rule": "tau_AI >= 3us -> 33us; otherwise dense 30us",
            "blocked_rule": "do not directly commit 32/33us at tau_AI around 1us without fresh evidence",
            "risk_proxy_features": "tau_AI, candidate T_slew, previous phase-spacing state, recent skip flag",
            "r032_status": "delay-sensitive near-tie band; calibrated from R031 only",
        },
        {
            "target_label": "20A",
            "objective": "base",
            "dense_fallback_us": 80.0,
            "candidate_band_us": "[80, 84] candidate-only",
            "plant_commit_rule": "default dense 80us; 82/84us are ranking probes",
            "blocked_rule": "block 86us direct override",
            "risk_proxy_features": "tau_AI, phase-spacing std, settling estimate, candidate-dense delta",
            "r032_status": "dense fallback retained; intermediate candidates need more switching evidence",
        },
        {
            "target_label": "20A",
            "objective": "score_settle005",
            "dense_fallback_us": 30.0,
            "candidate_band_us": "[38, 58] with dense fallback",
            "plant_commit_rule": "tau<0.75us -> 50us; 0.75<=tau<1.5us -> 38us; otherwise dense 30us",
            "blocked_rule": "block 66us unless a future short-horizon predictor certifies low skip/settling risk",
            "risk_proxy_features": "tau_AI, candidate T_slew, skip-risk, settling-risk, phase-risk",
            "r032_status": "large-jump negative sample converted into bounded intermediate band",
        },
    ]
    return pd.DataFrame(rows)


def build_next_plan() -> pd.DataFrame:
    records: list[dict[str, object]] = []

    def add(target: str, load: float, objective: str, alpha: float, tau: float, slew: float, priority: int, reason: str) -> None:
        records.append(
            {
                "r032_case_id": f"R032_{len(records)+1:04d}",
                "target_label": target,
                "target_load_A": load,
                "load_drop_A": 40.0 - load,
                "objective": objective,
                "objective_alpha_settle": alpha,
                "tau_ai_us": tau,
                "candidate_ref_slew_us": slew,
                "delay_events_est": int((tau / 0.5) + (0 if abs(tau / 0.5 - round(tau / 0.5)) < 1e-9 else 1)),
                "priority": priority,
                "reason": reason,
                "validation_scope": "derived Simulink delayed-reference only; not hardware",
            }
        )

    for tau in [2.0, 3.0]:
        for slew in [30.0, 32.0, 33.0, 34.0]:
            add("10A", 10.0, "score_settle010", 0.10, tau, slew, 2, "resolve 30/33us transition boundary")

    for tau in [1.0, 3.0]:
        for slew in [80.0, 82.0, 84.0, 86.0]:
            add("20A", 20.0, "base", 0.0, tau, slew, 3, "test whether base-objective 82/84us ever justifies replacing 80us fallback")

    for tau in [0.75, 1.5, 3.0]:
        for slew in [30.0, 38.0, 50.0, 58.0, 66.0]:
            add("20A", 20.0, "score_settle005", 0.05, tau, slew, 1, "map 38/50/58us band and keep 66us as negative-control probe")

    return pd.DataFrame(records)


def md_table(df: pd.DataFrame, cols: list[str], max_rows: int | None = None) -> str:
    if max_rows is not None:
        df = df.head(max_rows)
    lines = [
        "| " + " | ".join(cols) + " |",
        "| " + " | ".join(["---"] * len(cols)) + " |",
    ]
    for _, row in df[cols].iterrows():
        vals: list[str] = []
        for col in cols:
            val = row[col]
            if isinstance(val, float):
                vals.append(f"{val:.3f}")
            else:
                vals.append(str(val))
        lines.append("| " + " | ".join(vals) + " |")
    return "\n".join(lines)


def write_svg(summary: pd.DataFrame, features: pd.DataFrame) -> None:
    FIG.mkdir(parents=True, exist_ok=True)
    width, height = 1180, 560
    left, top = 90, 70
    plot_w, plot_h = 580, 300
    max_reg = max(0.1, float(summary["mean_regret"].max()) * 1.2)
    colors = {
        "r032_delay_aware_band_projection": "#54A24B",
        "dense_fallback": "#4C78A8",
        "direct_proxy_override": "#E45756",
        "r031_best_intermediate_only": "#F58518",
        "nearest_tau_loto_predictor": "#B279A2",
    }
    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        '<rect width="100%" height="100%" fill="white"/>',
        '<text x="590" y="32" text-anchor="middle" font-family="Arial" font-size="18">R032 delay-aware band projection: known-context replay</text>',
        f'<line x1="{left}" y1="{top+plot_h}" x2="{left+plot_w}" y2="{top+plot_h}" stroke="#333"/>',
        f'<line x1="{left}" y1="{top}" x2="{left}" y2="{top+plot_h}" stroke="#333"/>',
    ]
    for frac in [0, 0.25, 0.5, 0.75, 1.0]:
        y = top + plot_h - frac * plot_h
        val = frac * max_reg
        parts.append(f'<line x1="{left-4}" y1="{y:.1f}" x2="{left+plot_w}" y2="{y:.1f}" stroke="#eee"/>')
        parts.append(f'<text x="{left-10}" y="{y+4:.1f}" text-anchor="end" font-family="Arial" font-size="11">{val:.2f}</text>')
    bar_w = 66
    step = plot_w / len(summary)
    for i, row in enumerate(summary.itertuples()):
        policy = row.policy
        x = left + i * step + (step - bar_w) / 2
        h = float(row.mean_regret) / max_reg * plot_h
        y = top + plot_h - h
        parts.append(f'<rect x="{x:.1f}" y="{y:.1f}" width="{bar_w:.1f}" height="{h:.1f}" fill="{colors.get(policy, "#888")}"/>')
        parts.append(f'<text x="{x+bar_w/2:.1f}" y="{y-6:.1f}" text-anchor="middle" font-family="Arial" font-size="11">{row.mean_regret:.3f}</text>')
        label = policy.replace("_", " ")
        tx = x + bar_w / 2
        ty = top + plot_h + 20
        parts.append(f'<text x="{tx:.1f}" y="{ty:.1f}" text-anchor="end" transform="rotate(-35 {tx:.1f},{ty:.1f})" font-family="Arial" font-size="9">{label}</text>')
    parts.append(f'<text x="28" y="{top+plot_h/2}" text-anchor="middle" transform="rotate(-90 28,{top+plot_h/2})" font-family="Arial" font-size="13">Mean regret</text>')

    # Right panel: risk counts by band decision.
    right_x, right_y = 740, 86
    counts = features.groupby("r032_band_decision").size().reset_index(name="count")
    parts.append(f'<text x="{right_x}" y="{right_y-30}" font-family="Arial" font-size="13">Candidate band decisions</text>')
    for i, row in enumerate(counts.itertuples()):
        y = right_y + i * 62
        color = {"plant_admissible": "#54A24B", "candidate_only": "#F58518", "blocked": "#E45756"}.get(row.r032_band_decision, "#888")
        parts.append(f'<rect x="{right_x}" y="{y}" width="{int(row.count)*14}" height="28" fill="{color}"/>')
        parts.append(f'<text x="{right_x + int(row.count)*14 + 10}" y="{y+19}" font-family="Arial" font-size="12">{row.r032_band_decision}: {int(row.count)}</text>')
    parts.append('<text x="740" y="340" font-family="Arial" font-size="12" fill="#555">R032 replay is fitted from R031 evidence.</text>')
    parts.append('<text x="740" y="362" font-family="Arial" font-size="12" fill="#555">It is not hardware validation or global optimality proof.</text>')
    parts.append("</svg>")
    SVG.write_text("\n".join(parts), encoding="utf-8")


def write_reports(
    features: pd.DataFrame,
    rules: pd.DataFrame,
    replay: pd.DataFrame,
    summary: pd.DataFrame,
    plan: pd.DataFrame,
) -> None:
    dense = summary[summary["policy"] == "dense_fallback"].iloc[0]
    proxy = summary[summary["policy"] == "direct_proxy_override"].iloc[0]
    loto = summary[summary["policy"] == "nearest_tau_loto_predictor"].iloc[0]
    r032 = summary[summary["policy"] == "r032_delay_aware_band_projection"].iloc[0]
    inter = summary[summary["policy"] == "r031_best_intermediate_only"].iloc[0]
    blocked = int((features["r032_band_decision"] == "blocked").sum())
    admissible = int((features["r032_band_decision"] == "plant_admissible").sum())
    candidate_only = int((features["r032_band_decision"] == "candidate_only").sum())

    report = f"""# R032 Delay-Aware `B_epsilon^sw` Band Projection

## Scope

R032 converts the completed R031 minimal held-out derived-Simulink result into
a deployable-style short-horizon risk interface.  It does not run or edit any
`.slx` model.  The result is a known-context consistency design plus a next
validation matrix, not hardware validation and not a proof that `T_slew` has a
global optimum.

The proposed online shape is:

```text
q_phi(z_k, T_slew, tau_AI) -> score/ranking candidate
r_hat(z_k, T_slew, tau_AI, recent_phase_state)
  -> [skip risk, settling risk, phase-spacing risk]

T_slew,plant =
  Proj_{{B_epsilon^sw(z_k,tau_AI,r_hat,T_dense)}}(T_slew,candidate)
```

AI remains a supervisory parameter scheduler.  It does not replace the IQCOT
inner loop and does not output gate commands.

## Candidate Risk Table

R032 expands the R031 combined table into `{len(features)}` candidate rows.
Band decisions are: plant-admissible `{admissible}`, candidate-only
`{candidate_only}`, blocked `{blocked}`.  The blocked set includes the
`20A/score_settle005 -> 66us` direct override and the `20A/base -> 86us`
override.

## Policy Replay

{md_table(summary, [
    "policy",
    "deployability",
    "n_contexts",
    "mean_regret",
    "max_regret",
    "mean_margin_vs_dense",
    "non_dense_selected_count",
    "mean_r_hat_total_risk",
    "zero_regret_context_count",
])}

The fitted R032 projection has known-context mean regret
`{r032["mean_regret"]:.3f}` on the R031 replay table, while dense fallback is
`{dense["mean_regret"]:.3f}` and direct proxy override is
`{proxy["mean_regret"]:.3f}`.  This is only a calibration consistency result.
The leave-one-tau nearest-neighbor stress policy has mean regret
`{loto["mean_regret"]:.3f}`, showing that simple tau interpolation can fail
near the non-smooth skip/reentry boundaries.  R031 best-intermediate-only has
mean regret `{inter["mean_regret"]:.3f}`, so intermediate slopes need dense
fallback and risk projection.

## Delay-Aware Band Rules

{md_table(rules, [
    "target_label",
    "objective",
    "dense_fallback_us",
    "candidate_band_us",
    "plant_commit_rule",
    "blocked_rule",
    "r032_status",
])}

## Next Derived-Simulink Validation Plan

The generated next matrix contains `{len(plan)}` rows.  It targets transition
boundaries rather than repeating completed R031 points.  It should be run only
on derived models under `E:/Desktop/codex/output/simulink_iek`.

{md_table(plan, [
    "r032_case_id",
    "target_label",
    "objective",
    "tau_ai_us",
    "candidate_ref_slew_us",
    "priority",
    "reason",
], max_rows=16)}

## Interpretation

R032 refines the claim boundary rather than expanding it.  The strongest
allowable statement is that R031/R032 support a delay-aware local band with
dense fallback and a short-horizon risk-prediction interface.  They do not
show that the proxy or AI is globally better than dense-anchor tables, and
they do not replace hardware or HIL validation.
"""
    REPORT.write_text(report, encoding="utf-8")

    paper = f"""## R032：短时风险预测接口与延迟感知 `B_\\epsilon^{{sw}}` 投影

基于 R031 的 `22` 行最小 held-out 派生 Simulink 结果，本文进一步将
`B_\\epsilon^{{sw}}` 从人工规则表整理为短时风险预测接口。该接口不让 AI 直接提交
最终 `T_slew`，而是先给出候选分数或候选分布，再由
`r_hat(z_k,T_slew,tau_AI,recent_phase_state)` 估计 skip、settling 和
phase-spacing 风险，最后经过安全投影得到 plant 侧参数：

```text
T_slew,plant = Proj_B(T_slew,candidate; z_k, tau_AI, r_hat, T_dense)
```

在 R031 已知上下文上，R032 拟合投影的 mean regret 为
`{r032["mean_regret"]:.3f}`，dense fallback 为 `{dense["mean_regret"]:.3f}`，
direct proxy override 为 `{proxy["mean_regret"]:.3f}`。这个结果只能说明
R032 规则与 R031 局部证据一致，不能写成独立泛化证明。更有信息量的是
leave-one-tau nearest-neighbor stress policy 的 mean regret 为
`{loto["mean_regret"]:.3f}`，说明仅按 `tau_AI` 近邻插值会在
`20A/score_settle005` 一类非光滑边界上失败；因此短时 predictor 需要显式处理
skip/reentry 和 settling 风险，而不是把 `T_slew` 当作平滑连续变量直接回归。

R032 的当前可部署边界为：`10A/score_settle010` 保留 `30/33us` 延迟敏感近似并列带；
`20A/base` 保持 `80us` dense fallback，`82/84us` 仅作为候选探针，继续阻止
`86us` direct override；`20A/score_settle005` 将 `38/50/58us` 作为中间候选带，
但继续阻止 `66us` 直接覆盖，除非未来短时风险预测器能在新的派生 Simulink 或
硬件/HIL 验证中证明低 skip/settling 风险。AI 在这里仍只是监督层参数调度器，
不替代 IQCOT 内环，也不构成硬件验证。"""
    PAPER.write_text(paper, encoding="utf-8")


def main() -> None:
    combined, context, family = read_inputs()
    features = build_features(combined)
    replay, summary = evaluate_policies(features)
    rules = build_rules(features)
    plan = build_next_plan()

    features.to_csv(FEATURES, index=False)
    rules.to_csv(RULES, index=False)
    replay.to_csv(POLICY_REPLAY, index=False)
    summary.to_csv(POLICY_SUMMARY, index=False)
    plan.to_csv(NEXT_PLAN, index=False)
    write_svg(summary, features)
    write_reports(features, rules, replay, summary, plan)

    print(f"Wrote {FEATURES}")
    print(f"Wrote {RULES}")
    print(f"Wrote {POLICY_REPLAY}")
    print(f"Wrote {POLICY_SUMMARY}")
    print(f"Wrote {NEXT_PLAN}")
    print(f"Wrote {REPORT}")
    print(f"Wrote {PAPER}")
    print(f"Wrote {SVG}")


if __name__ == "__main__":
    main()
