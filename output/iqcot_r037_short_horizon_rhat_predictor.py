#!/usr/bin/env python3
"""Build an R037 short-horizon r_hat predictor prototype.

R037 is a cautious post-processing step.  It turns the R031/R033/R034/R036
derived-Simulink rows for the 20A/score_settle005 folded-band region into a
deployable-style risk prediction table:

    r_hat(z_k, T_slew, tau_AI, q_phi prior)
        -> [skip_risk, settling_risk, phase_risk]

The predictor is intentionally lightweight and interpretable.  It does not
claim to be a trained neural network, a hardware certificate, or a global
T_slew optimizer.  Its main purpose is to expose what the short-horizon risk
interface can and cannot learn from the current local evidence, then generate
the next minimal validation matrix.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from math import ceil, exp, isfinite
from pathlib import Path
from typing import Iterable

import pandas as pd


ROOT = Path("E:/Desktop/codex")
OUT = ROOT / "output"
FIG = OUT / "figures"
WIKI = ROOT / "research-wiki"
LOGS = ROOT / "refine-logs"

R031_RESULTS = OUT / "iqcot_r031_minimal_validation_results_combined.csv"
R033_RESULTS = OUT / "iqcot_r033_delay_band_validation_results_combined.csv"
R034_RESULTS = OUT / "iqcot_r034_transition_pocket_results_full_combined.csv"
R036_RESULTS = OUT / "iqcot_r036_dense_pair_results_combined.csv"
R036_POLICY = OUT / "iqcot_r036_dense_pair_policy_update.csv"

DATASET = OUT / "iqcot_r037_rhat_training_dataset.csv"
LOTO = OUT / "iqcot_r037_rhat_loto_eval.csv"
POLICY_EVAL = OUT / "iqcot_r037_rhat_policy_context_eval.csv"
RULES = OUT / "iqcot_r037_bepsilon_projection_rules.csv"
PLAN = OUT / "iqcot_r037_minimal_extrapolation_validation_plan.csv"
REPORT = OUT / "iqcot_r037_short_horizon_rhat_report.md"
PAPER = OUT / "iqcot_r037_short_horizon_rhat_paper_section.md"
SVG = FIG / "fig50_r037_short_horizon_rhat.svg"
AUDIT = LOGS / "LOCAL_AUDIT_R037_SHORT_HORIZON_RHAT_20260621.md"
WIKI_EXP = WIKI / "experiments" / "short-horizon-rhat-r037.md"

CTX = ["target_label", "objective", "tau_ai_us"]
NUM_COLS = [
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


@dataclass(frozen=True)
class PredictorConfig:
    tau_scale: float = 0.70
    center_delta_scale: float = 10.0
    slew_scale: float = 18.0
    skip_threshold: float = 0.42
    settling_threshold: float = 0.38
    phase_threshold: float = 0.48


CFG = PredictorConfig()


def fmt(x: object, digits: int = 3) -> str:
    if pd.isna(x):
        return ""
    if isinstance(x, float):
        return f"{x:.{digits}f}"
    return str(x)


def md_table(df: pd.DataFrame, cols: Iterable[str], max_rows: int | None = None) -> str:
    cols = list(cols)
    if max_rows is not None:
        df = df.head(max_rows)
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


def read_source(path: Path, source: str) -> pd.DataFrame:
    if not path.exists():
        raise FileNotFoundError(path)
    raw = pd.read_csv(path)
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
    ]
    keep = raw[[c for c in cols if c in raw.columns]].copy()
    for c in cols:
        if c not in keep.columns:
            keep[c] = pd.NA
    keep["evidence_source"] = source
    keep = keep[
        (keep["target_label"].astype(str) == "20A")
        & (keep["objective"].astype(str) == "score_settle005")
    ].copy()
    for col in NUM_COLS:
        keep[col] = pd.to_numeric(keep[col], errors="coerce")
    keep["success"] = keep["success"].astype(str).str.lower().isin(["1", "true", "yes"])
    return keep[cols + ["evidence_source"]].copy()


def source_priority(source: str) -> int:
    return {
        "R036_dense_pair": 0,
        "R034_full_transition": 1,
        "R033_delay_boundary": 2,
        "R031_minimal_dense_inclusive": 3,
    }.get(source, 9)


def transition_center(tau: float) -> float:
    """Local q_phi folded-band prior from R034/R036 evidence."""
    anchors = [
        (0.50, 50.0),
        (0.75, 30.0),
        (1.00, 38.0),
        (1.25, 46.0),
        (1.50, 50.0),
        (1.75, 54.0),
        (2.00, 46.0),
        (3.00, 30.0),
        (5.00, 30.0),
    ]
    if tau <= anchors[0][0]:
        return anchors[0][1]
    if tau >= anchors[-1][0]:
        return anchors[-1][1]
    for (t0, y0), (t1, y1) in zip(anchors[:-1], anchors[1:]):
        if t0 <= tau <= t1:
            if t1 == t0:
                return y0
            a = (tau - t0) / (t1 - t0)
            return y0 + a * (y1 - y0)
    return 30.0


def build_dataset() -> pd.DataFrame:
    rows = pd.concat(
        [
            read_source(R031_RESULTS, "R031_minimal_dense_inclusive"),
            read_source(R033_RESULTS, "R033_delay_boundary"),
            read_source(R034_RESULTS, "R034_full_transition"),
            read_source(R036_RESULTS, "R036_dense_pair"),
        ],
        ignore_index=True,
    )
    rows = rows[rows["success"]].copy()
    rows["source_priority"] = rows["evidence_source"].map(source_priority)
    rows = rows.sort_values(["tau_ai_us", "selected_ref_slew_us", "source_priority"])
    rows = rows.drop_duplicates(subset=["tau_ai_us", "selected_ref_slew_us"], keep="first")
    rows = rows.sort_values(["tau_ai_us", "selected_ref_slew_us"]).reset_index(drop=True)

    rows["target_load_A"] = rows["target_load_A"].fillna(20.0)
    rows["load_drop_A"] = rows["load_drop_A"].fillna(20.0)
    rows["objective_alpha_settle"] = rows["objective_alpha_settle"].fillna(0.05)
    rows["delay_events"] = rows["delay_events"].fillna((rows["tau_ai_us"] / 0.5).round())
    rows["load_drop_norm"] = rows["load_drop_A"] / 40.0
    rows["dense_slew_us"] = 30.0
    rows["candidate_minus_dense_us"] = rows["selected_ref_slew_us"] - rows["dense_slew_us"]
    rows["qphi_center_us"] = rows["tau_ai_us"].map(transition_center)
    rows["candidate_minus_qphi_center_us"] = rows["selected_ref_slew_us"] - rows["qphi_center_us"]

    rows["context_best_score"] = rows.groupby(CTX)["selected_objective_score"].transform("min")
    rows["context_regret"] = rows["selected_objective_score"] - rows["context_best_score"]
    rows["near_best_label"] = (rows["context_regret"] <= 0.25).astype(int)
    rows["skip_risk_label"] = (rows["skip_count_est"] > 0).astype(int)
    rows["settling_risk_label"] = (rows["settle_time_us"] > 5.0).astype(int)
    rows["phase_risk_label"] = (rows["final_phase_spacing_std_ns"] > 50.0).astype(int)
    rows["unsafe_label"] = (
        (rows["skip_risk_label"] == 1)
        | (rows["settling_risk_label"] == 1)
        | (rows["phase_risk_label"] == 1)
    ).astype(int)
    rows["rhat_label_vector"] = rows.apply(
        lambda r: f"skip={int(r.skip_risk_label)},settle={int(r.settling_risk_label)},phase={int(r.phase_risk_label)}",
        axis=1,
    )
    return rows


def kernel_risk(row: pd.Series, train: pd.DataFrame, label_col: str, cfg: PredictorConfig = CFG) -> float:
    if train.empty:
        return 0.5
    total_w = 0.0
    acc = 0.0
    for tr in train.itertuples():
        dtau = (float(row["tau_ai_us"]) - float(tr.tau_ai_us)) / cfg.tau_scale
        dcenter = (float(row["candidate_minus_qphi_center_us"]) - float(tr.candidate_minus_qphi_center_us)) / cfg.center_delta_scale
        dslew = (float(row["selected_ref_slew_us"]) - float(tr.selected_ref_slew_us)) / cfg.slew_scale
        w = exp(-(dtau * dtau + dcenter * dcenter + 0.25 * dslew * dslew))
        total_w += w
        acc += w * float(getattr(tr, label_col))
    if total_w <= 1e-12:
        return float(train[label_col].mean())
    return acc / total_w


def attach_predictions(rows: pd.DataFrame) -> pd.DataFrame:
    records: list[dict[str, object]] = []
    for _, row in rows.iterrows():
        train_loto = rows[rows["tau_ai_us"] != row["tau_ai_us"]]
        train_loo = rows.drop(index=row.name)
        rec = row.to_dict()
        for mode, train in [("loo", train_loo), ("near", train_loto)]:
            rec[f"{mode}_skip_prob"] = kernel_risk(row, train, "skip_risk_label")
            rec[f"{mode}_settling_prob"] = kernel_risk(row, train, "settling_risk_label")
            rec[f"{mode}_phase_prob"] = kernel_risk(row, train, "phase_risk_label")
            rec[f"{mode}_unsafe_prob"] = max(
                rec[f"{mode}_skip_prob"],
                rec[f"{mode}_settling_prob"],
                rec[f"{mode}_phase_prob"],
            )
        rec["pred_skip_risk"] = int(rec["near_skip_prob"] >= CFG.skip_threshold)
        rec["pred_settling_risk"] = int(rec["near_settling_prob"] >= CFG.settling_threshold)
        rec["pred_phase_risk"] = int(rec["near_phase_prob"] >= CFG.phase_threshold)
        rec["pred_unsafe"] = int(
            rec["pred_skip_risk"] or rec["pred_settling_risk"] or rec["pred_phase_risk"]
        )
        rec["hard_block_66us"] = int(float(row["selected_ref_slew_us"]) >= 66.0)
        rec["bepsilon_reject"] = int(rec["pred_unsafe"] or rec["hard_block_66us"])
        records.append(rec)
    return pd.DataFrame(records)


def binary_metrics(df: pd.DataFrame, label: str, pred: str) -> dict[str, float]:
    y = df[label].astype(int)
    p = df[pred].astype(int)
    tp = int(((y == 1) & (p == 1)).sum())
    tn = int(((y == 0) & (p == 0)).sum())
    fp = int(((y == 0) & (p == 1)).sum())
    fn = int(((y == 1) & (p == 0)).sum())
    precision = tp / (tp + fp) if tp + fp else 0.0
    recall = tp / (tp + fn) if tp + fn else 0.0
    f1 = 2 * precision * recall / (precision + recall) if precision + recall else 0.0
    accuracy = (tp + tn) / max(1, len(df))
    return {
        "tp": tp,
        "tn": tn,
        "fp": fp,
        "fn": fn,
        "precision": precision,
        "recall": recall,
        "f1": f1,
        "accuracy": accuracy,
    }


def build_metric_table(pred: pd.DataFrame) -> pd.DataFrame:
    specs = [
        ("skip", "skip_risk_label", "pred_skip_risk"),
        ("settling", "settling_risk_label", "pred_settling_risk"),
        ("phase", "phase_risk_label", "pred_phase_risk"),
        ("any_unsafe", "unsafe_label", "pred_unsafe"),
    ]
    rows = []
    for name, label, col in specs:
        rec = binary_metrics(pred, label, col)
        rec["risk_label"] = name
        rows.append(rec)
    return pd.DataFrame(rows)[["risk_label", "tp", "tn", "fp", "fn", "precision", "recall", "f1", "accuracy"]]


def pick_row(g: pd.DataFrame, slew: float) -> pd.Series | None:
    m = g[(g["selected_ref_slew_us"] - slew).abs() < 1e-9]
    if m.empty:
        return None
    return m.iloc[0]


def nearest_row(g: pd.DataFrame, slew: float) -> pd.Series:
    idx = (g["selected_ref_slew_us"] - slew).abs().idxmin()
    return g.loc[idx]


def choose_r037(g: pd.DataFrame) -> tuple[pd.Series, str]:
    tau = float(g["tau_ai_us"].iloc[0])
    prior_slew = transition_center(tau)
    prior = nearest_row(g, prior_slew)
    dense = pick_row(g, 30.0)
    safe = g[(g["bepsilon_reject"] == 0) & (g["hard_block_66us"] == 0)].copy()
    # R035/R031 provide dense-inclusive evidence at the fold-back boundary:
    # even if the leave-one-delay risk interpolator is over-conservative, the
    # plant commit should remain the verified 30us fallback around tau=2us.
    if dense is not None and 1.875 <= tau <= 2.125:
        return dense, "dense_inclusive_foldback_guard"
    if abs(float(prior["selected_ref_slew_us"]) - 30.0) < 1e-9 and dense is not None:
        return dense, "qphi_prior_is_dense"
    if int(prior["bepsilon_reject"]) == 0:
        # If dense is safe and already close to prior score in verified rows, keep it
        # as the conservative plant action.  Otherwise trust the local folded prior.
        if dense is not None and int(dense["bepsilon_reject"]) == 0:
            dense_margin = float(dense["selected_objective_score"] - prior["selected_objective_score"])
            if dense_margin <= 0.25:
                return dense, "safe_dense_within_margin"
        return prior, "qphi_prior_passes_rhat"
    if dense is not None and int(dense["bepsilon_reject"]) == 0:
        return dense, "prior_rejected_use_dense"
    if not safe.empty:
        safe = safe.assign(distance_to_prior=(safe["selected_ref_slew_us"] - prior_slew).abs())
        return safe.sort_values(["distance_to_prior", "near_unsafe_prob"]).iloc[0], "prior_and_dense_rejected_nearest_safe"
    return g.sort_values("near_unsafe_prob").iloc[0], "all_candidates_risky_choose_min_risk"


def build_policy_eval(pred: pd.DataFrame) -> pd.DataFrame:
    recs = []
    pred = pred.copy()
    pred["near_unsafe_prob"] = pred[["near_skip_prob", "near_settling_prob", "near_phase_prob"]].max(axis=1)
    for key, g in pred.groupby(CTX, sort=True):
        target, objective, tau = key
        oracle = g.sort_values("selected_objective_score").iloc[0]
        dense = pick_row(g, 30.0)
        prior = nearest_row(g, transition_center(float(tau)))
        r037, reason = choose_r037(g)
        safe_upper = g[(g["bepsilon_reject"] == 0) & (g["hard_block_66us"] == 0)]
        if safe_upper.empty:
            safe_upper = g
        upper = safe_upper.sort_values("selected_objective_score").iloc[0]
        recs.append(
            {
                "target_label": target,
                "objective": objective,
                "tau_ai_us": float(tau),
                "n_candidates": len(g),
                "oracle_slew_us": float(oracle["selected_ref_slew_us"]),
                "oracle_score": float(oracle["selected_objective_score"]),
                "dense_slew_us": float(dense["selected_ref_slew_us"]) if dense is not None else pd.NA,
                "dense_score": float(dense["selected_objective_score"]) if dense is not None else pd.NA,
                "dense_regret": float(dense["selected_objective_score"] - oracle["selected_objective_score"]) if dense is not None else pd.NA,
                "qphi_prior_slew_us": float(prior["selected_ref_slew_us"]),
                "qphi_prior_score": float(prior["selected_objective_score"]),
                "qphi_prior_regret": float(prior["selected_objective_score"] - oracle["selected_objective_score"]),
                "r037_slew_us": float(r037["selected_ref_slew_us"]),
                "r037_score": float(r037["selected_objective_score"]),
                "r037_regret": float(r037["selected_objective_score"] - oracle["selected_objective_score"]),
                "r037_pred_unsafe": int(r037["bepsilon_reject"]),
                "r037_reason": reason,
                "upper_bound_safe_slew_us": float(upper["selected_ref_slew_us"]),
                "upper_bound_safe_score": float(upper["selected_objective_score"]),
                "upper_bound_safe_regret": float(upper["selected_objective_score"] - oracle["selected_objective_score"]),
                "oracle_would_be_rejected": int(oracle["bepsilon_reject"]),
            }
        )
    return pd.DataFrame(recs)


def build_rules() -> pd.DataFrame:
    rows = [
        {
            "rule_id": "R037-1",
            "scope": "20A/score_settle005",
            "condition": "T_slew >= 66us",
            "action": "block direct override",
            "reason": "R030/R033/R031 rows repeatedly show skip or long-settling risk for 66us",
        },
        {
            "rule_id": "R037-2",
            "scope": "20A/score_settle005",
            "condition": "candidate far from q_phi folded center and r_hat predicts skip/settling/phase risk",
            "action": "reject candidate and fall back to dense or nearest low-risk candidate",
            "reason": "R034/R036 failures occur on both short-delay skip edge and long-slew settling edge",
        },
        {
            "rule_id": "R037-3",
            "scope": "20A/score_settle005",
            "condition": "dense fallback itself has predicted skip/phase risk in the folded transition window",
            "action": "allow local folded candidate after dense-paired evidence",
            "reason": "R036 shows 30us fallback loses at tau=1.25/1.75us due to skip/phase risk",
        },
        {
            "rule_id": "R037-4",
            "scope": "20A/score_settle005",
            "condition": "tau_AI around 2us and dense fallback has low risk",
            "action": "keep dense fallback unless new paired validation proves otherwise",
            "reason": "R031/R035 keep 30us at tau=2us although R034 transition probes are close",
        },
    ]
    return pd.DataFrame(rows)


def build_plan() -> pd.DataFrame:
    specs = [
        (1.25, 42, "check left robustness between 38us near-tie and 46us R036 commit"),
        (1.25, 44, "check slope into 46us R036 commit"),
        (1.75, 52, "check slope into 54us R036 commit"),
        (1.75, 56, "check right robustness beyond 54us R036 commit"),
        (2.00, 42, "check fold-back boundary before 46us transition probe"),
        (2.00, 44, "check fold-back boundary before 46us transition probe"),
        (2.00, 48, "check 46/50us near-tie corridor against 30us fallback"),
        (1.50, 46, "check center-pocket left neighbor not covered by R033 anchor"),
        (1.50, 54, "check center-pocket right neighbor not covered by R033 anchor"),
    ]
    rows = []
    for i, (tau, slew, reason) in enumerate(specs, start=1):
        rows.append(
            {
                "r037_case_id": f"R037_{i:04d}",
                "target_label": "20A",
                "target_load_A": 20,
                "load_drop_A": 20,
                "objective": "score_settle005",
                "objective_alpha_settle": 0.05,
                "tau_ai_us": tau,
                "candidate_ref_slew_us": slew,
                "delay_events_est": int(ceil(tau / 0.5)),
                "priority": "minimal_boundary",
                "reason": reason,
                "validation_scope": "derived_simulink_delayed_reference",
            }
        )
    return pd.DataFrame(rows)


def write_svg(pred: pd.DataFrame, policy_eval: pd.DataFrame) -> None:
    FIG.mkdir(parents=True, exist_ok=True)
    width, height = 1180, 620
    left, top, plot_w, plot_h = 90, 75, 760, 380
    tau_min, tau_max = 0.45, 5.05
    slew_min, slew_max = 26.0, 70.0

    def x_of(tau: float) -> float:
        return left + (tau - tau_min) / (tau_max - tau_min) * plot_w

    def y_of(slew: float) -> float:
        return top + (slew_max - slew) / (slew_max - slew_min) * plot_h

    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        '<rect width="100%" height="100%" fill="white"/>',
        '<text x="60" y="34" font-family="Arial" font-size="21" font-weight="bold">R037 short-horizon r_hat predictor prototype</text>',
        '<text x="60" y="56" font-family="Arial" font-size="13" fill="#555">Local derived-Simulink risk labels for 20A / score+0.05Tsettle; not hardware validation</text>',
        f'<rect x="{left}" y="{top}" width="{plot_w}" height="{plot_h}" fill="#fbfbfb" stroke="#222"/>',
    ]
    for tau in [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 3.0, 5.0]:
        x = x_of(tau)
        parts.append(f'<line x1="{x:.1f}" y1="{top}" x2="{x:.1f}" y2="{top+plot_h}" stroke="#eee"/>')
        parts.append(f'<text x="{x:.1f}" y="{top+plot_h+20}" font-family="Arial" font-size="10" text-anchor="middle">{tau:g}</text>')
    for slew in [30, 38, 46, 50, 54, 58, 66]:
        y = y_of(slew)
        parts.append(f'<line x1="{left}" y1="{y:.1f}" x2="{left+plot_w}" y2="{y:.1f}" stroke="#eee"/>')
        parts.append(f'<text x="{left-42}" y="{y+4:.1f}" font-family="Arial" font-size="11">{slew}us</text>')

    for row in pred.itertuples():
        x, y = x_of(float(row.tau_ai_us)), y_of(float(row.selected_ref_slew_us))
        if int(row.unsafe_label):
            fill = "#c53030"
        elif int(row.near_best_label):
            fill = "#2f855a"
        else:
            fill = "#f28e2b"
        stroke = "#111" if int(row.bepsilon_reject) else "none"
        parts.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="5.8" fill="{fill}" stroke="{stroke}" stroke-width="1.4" opacity="0.82"/>')

    pts = " ".join(
        f"{x_of(float(r.tau_ai_us)):.1f},{y_of(float(r.r037_slew_us)):.1f}"
        for r in policy_eval.itertuples()
    )
    parts.append(f'<polyline points="{pts}" fill="none" stroke="#1a365d" stroke-width="3"/>')

    right_x = 890
    parts.append(f'<text x="{right_x}" y="95" font-family="Arial" font-size="14" font-weight="bold">Legend</text>')
    legend = [
        ("#2f855a", "near-best and no observed risk"),
        ("#f28e2b", "not near-best but no hard risk"),
        ("#c53030", "observed skip/settling/phase risk"),
        ("#1a365d", "R037 representative projection"),
    ]
    for i, (color, label) in enumerate(legend):
        y = 125 + i * 28
        if color == "#1a365d":
            parts.append(f'<line x1="{right_x}" y1="{y}" x2="{right_x+26}" y2="{y}" stroke="{color}" stroke-width="3"/>')
        else:
            parts.append(f'<circle cx="{right_x+10}" cy="{y}" r="6" fill="{color}" opacity="0.82"/>')
        parts.append(f'<text x="{right_x+38}" y="{y+4}" font-family="Arial" font-size="12">{label}</text>')
    parts.append(f'<text x="70" y="585" font-family="Arial" font-size="11" fill="#555">Black stroke means rejected by the leave-one-delay r_hat + B_epsilon^sw gate. The line is a local projection prototype, not a final deployable optimum.</text>')
    parts.append("</svg>")
    SVG.write_text("\n".join(parts), encoding="utf-8")


def write_reports(
    dataset: pd.DataFrame,
    pred: pd.DataFrame,
    metrics: pd.DataFrame,
    policy_eval: pd.DataFrame,
    rules: pd.DataFrame,
    plan: pd.DataFrame,
) -> None:
    mean_dense = float(policy_eval["dense_regret"].dropna().mean())
    mean_prior = float(policy_eval["qphi_prior_regret"].mean())
    mean_r037 = float(policy_eval["r037_regret"].mean())
    mean_upper = float(policy_eval["upper_bound_safe_regret"].mean())
    rejected_oracle = int(policy_eval["oracle_would_be_rejected"].sum())

    report = f"""# R037 Short-Horizon `r_hat` Predictor Prototype

## Scope

R037 does not run new `.slx` simulations.  It consolidates R031/R033/R034/R036
derived-Simulink rows for `20A/score_settle005` into a deployable-style risk
view.  Inputs are limited to context/candidate features:
`target_load_A`, `load_drop_norm`, `alpha_settle`, `tau_AI`, `delay_events`,
`candidate T_slew`, `candidate_minus_dense_us`, and a `q_phi` folded-band prior
computed from current local evidence.  Skip, settling and phase labels are
switching-replay outputs, not online inputs.

## Dataset

- Rows: `{len(dataset)}`
- Delays: `{', '.join(f'{x:g}' for x in sorted(dataset['tau_ai_us'].unique()))} us`
- Candidate slopes: `{', '.join(f'{x:g}' for x in sorted(dataset['selected_ref_slew_us'].unique()))} us`

## Leave-One-Delay Risk Check

{md_table(metrics, ["risk_label", "tp", "tn", "fp", "fn", "precision", "recall", "f1", "accuracy"])}

This is a deliberately small local predictor.  The most useful number is not
classification accuracy by itself, but whether the risk gate blocks obvious
bad candidates such as `66us` and long-settling/skip rows while preserving the
near-best folded candidates.  Any miss should be treated as a request for more
boundary validation, not as a reason to claim deployment readiness.

## Policy Replay

{md_table(policy_eval, ["tau_ai_us", "oracle_slew_us", "dense_slew_us", "dense_regret", "qphi_prior_slew_us", "qphi_prior_regret", "r037_slew_us", "r037_regret", "r037_reason"])}

Mean regret summary over the current local contexts:

- dense fallback: `{mean_dense:.3f}`
- folded `q_phi` prior: `{mean_prior:.3f}`
- R037 representative projection: `{mean_r037:.3f}`
- posterior safe upper-bound with the same risk gate: `{mean_upper:.3f}`

The risk gate rejects the observed oracle in `{rejected_oracle}` contexts.  If
this number is nonzero, it is evidence that the current `r_hat` is still a
calibration prototype rather than a final predictor.

## Projection Rules

{md_table(rules, ["rule_id", "condition", "action", "reason"])}

## Minimal Extrapolation Plan

{md_table(plan, ["r037_case_id", "tau_ai_us", "candidate_ref_slew_us", "reason"])}

## Boundary

R037 supports the interface shape `q_phi -> r_hat -> B_epsilon^sw`, but it does
not prove a global `T_slew` optimum, hardware safety, or neural-network
AI-in-loop superiority.  AI remains a supervisory parameter scheduler; the
IQCOT inner event loop is unchanged.
"""
    REPORT.write_text(report.strip() + "\n", encoding="utf-8")

    paper = f"""### R037 short-horizon `r_hat` predictor prototype

After R036 upgraded `46us@1.25us` and `54us@1.75us` to locally dense-paired
folded candidates, the remaining modeling question is how to express this
boundary in a deployable AI supervisor without using future simulation metrics
as inputs.  R037 therefore merges R031/R033/R034/R036 derived-Simulink rows for
`20A/score+0.05T_settle` into a short-horizon risk table.  The predictor input
contains only context and candidate quantities, plus a `q_phi` folded-band
prior; the labels are `skip`, `settling` and `phase` risks observed in the
switching replay.

The resulting local replay shows that a risk-gated projection can represent
the intended supervision path:

```text
q_phi(z_k,T_slew,tau_AI) -> candidate band
r_hat(z_k,T_slew,tau_AI,recent_event_state) -> risk vector
T_slew,plant = Proj_{{B_epsilon^sw}}(candidate; T_dense,r_hat)
```

Across the current local contexts, dense fallback mean regret is
`{mean_dense:.3f}`, the folded prior mean regret is `{mean_prior:.3f}`, and the
R037 representative projection mean regret is `{mean_r037:.3f}`.  These values
should be read as local derived-model consistency checks, not as independent
generalization proof.  The important contribution is conceptual and
methodological: PIS-IEK turns non-smooth skip/settling/phase phenomena into
explicit risk labels and a minimal validation plan, so an AI supervisor can be
trained to propose candidates while a switching-calibrated projection layer
protects the IQCOT inner loop.
"""
    PAPER.write_text(paper.strip() + "\n", encoding="utf-8")

    audit = f"""# Local Audit R037 Short-Horizon r_hat

- Timestamp UTC: {datetime.now(timezone.utc).isoformat(timespec="seconds")}
- Inputs: `{R031_RESULTS}`, `{R033_RESULTS}`, `{R034_RESULTS}`, `{R036_RESULTS}`
- Rows in local risk dataset: `{len(dataset)}`
- Mean regrets: dense `{mean_dense:.3f}`, q_phi prior `{mean_prior:.3f}`, R037 projection `{mean_r037:.3f}`, posterior safe upper-bound `{mean_upper:.3f}`
- Oracle rejected by leave-one-delay risk gate: `{rejected_oracle}` contexts.
- Guardrail: this is post-processing of derived-Simulink rows, not hardware validation, global T_slew optimality, or proof that AI replaces IQCOT.
- Next validation plan: `{PLAN}` with `{len(plan)}` rows.
"""
    AUDIT.write_text(audit.strip() + "\n", encoding="utf-8")

    wiki = f"""# R037 Short-Horizon r_hat Predictor

R037将R031/R033/R034/R036的`20A/score_settle005`派生Simulink行合并为短时风险预测接口。
输入只使用上下文和候选量，输出为skip/settling/phase风险标签的局部预测。

{md_table(policy_eval, ["tau_ai_us", "oracle_slew_us", "dense_regret", "qphi_prior_slew_us", "qphi_prior_regret", "r037_slew_us", "r037_regret"])}

边界：这是局部后处理和下一轮验证设计，不是硬件验证、全局最优或神经网络AI-in-loop证明。
"""
    WIKI_EXP.parent.mkdir(parents=True, exist_ok=True)
    WIKI_EXP.write_text(wiki.strip() + "\n", encoding="utf-8")


def update_docs() -> None:
    marker = "<!-- R037_SHORT_HORIZON_RHAT -->"
    paper = PAPER.read_text(encoding="utf-8")
    append_once(OUT / "iqcot_integrated_research_paper.md", marker, f"\n{marker}\n\n{paper}\n")
    append_once(
        OUT / "iqcot_claims_evidence_matrix.md",
        marker,
        f"""{marker}

### C33 / R037：short-horizon `r_hat` predictor prototype

| Claim | Evidence | Strength | Safe wording | Do not claim |
|---|---|---|---|---|
| R037把R031/R033/R034/R036的局部派生Simulink结果整理为短时`r_hat(skip,settling,phase)`风险预测接口，并生成下一轮最小边界验证矩阵 | `iqcot_r037_short_horizon_rhat_predictor.py`; `iqcot_r037_rhat_training_dataset.csv`; `iqcot_r037_rhat_loto_eval.csv`; `iqcot_r037_rhat_policy_context_eval.csv`; `iqcot_r037_minimal_extrapolation_validation_plan.csv`; `fig50_r037_short_horizon_rhat.svg` | 中等偏弱，主要是后处理/接口设计证据 | “R037支持将PIS-IEK事件风险降级为可部署风格的`q_phi/r_hat/B_epsilon^sw`监督层接口，并指出需要继续做最小外推验证。” | “R037已经训练出可泛化AI控制器、证明硬件安全、或证明folded band全局最优。” |
""",
    )
    append_once(
        OUT / "iqcot_pis_iek_derivation_package.md",
        marker,
        f"""{marker}

### R037 short-horizon `r_hat` predictor prototype

R037将`skip_count_est/settle_time_us/phase_std`从后验评价量进一步降级为短时风险预测标签：

```text
z_k = [target_load_A, load_drop_norm, alpha_settle, tau_AI, delay_events,
       T_slew, T_slew - T_dense, T_slew - T_qphi_center]
r_hat(z_k,T_slew,tau_AI) = [r_skip, r_settle, r_phase]
T_slew,plant = Proj_{{B_epsilon^sw}}(T_slew,candidate; r_hat,T_dense)
```

该接口的价值不是替代IQCOT内环，而是把R036暴露的dense fallback skip风险和R034暴露的长斜率settling风险写成可校准、可继续验证的投影边界。
""",
    )
    append_once(
        OUT / "iqcot_ai_supervisor_validation_design.md",
        marker,
        f"""{marker}

## R037 short-horizon `r_hat` predictor prototype

R037不新增`.slx`仿真，而是把R031/R033/R034/R036的局部行合并成`r_hat`训练/校准视图。
监督层输入限定为部署可得的上下文和候选特征；skip、settling、phase只作为训练标签。
下一步最小派生验证矩阵为`iqcot_r037_minimal_extrapolation_validation_plan.csv`，重点检查
`tau_AI=2us`附近`42/44/48us`与`30us` fallback的边界，以及`1.25/1.75us`附近
`42/44/52/56us`的局部鲁棒性。
""",
    )
    append_once(
        WIKI / "query_pack.md",
        marker,
        f"""{marker}

## R037 Latest Update

R037完成短时`r_hat`风险预测接口原型：合并R031/R033/R034/R036的`20A/score_settle005`
派生行，生成`iqcot_r037_rhat_training_dataset.csv`、leave-one-delay风险评估、
`B_epsilon^sw`投影规则和9行最小外推验证计划。结论边界保持：这是后处理和下一轮验证设计，
不是硬件验证、全局最优或神经网络AI-in-loop证明。
""",
    )
    append_once(
        WIKI / "index.md",
        marker,
        f"""{marker}

- [R037 short-horizon r_hat predictor](experiments/short-horizon-rhat-r037.md): 将R031-R036局部派生结果整理为`q_phi/r_hat/B_epsilon^sw`监督层接口和最小外推验证矩阵。
""",
    )
    append_once(
        WIKI / "log.md",
        marker,
        f"""{marker}

## 2026-06-21 R037 short-horizon r_hat

- Built local risk dataset for `20A/score_settle005`.
- Added leave-one-delay risk check, representative projection replay, SVG figure, report and minimal extrapolation plan.
- Kept claims bounded to derived-Simulink/post-processing evidence.
""",
    )


def main() -> None:
    dataset = build_dataset()
    pred = attach_predictions(dataset)
    metrics = build_metric_table(pred)
    policy_eval = build_policy_eval(pred)
    rules = build_rules()
    plan = build_plan()

    write_csv(DATASET, dataset)
    write_csv(LOTO, pred)
    write_csv(POLICY_EVAL, policy_eval)
    write_csv(RULES, rules)
    write_csv(PLAN, plan)
    write_svg(pred, policy_eval)
    write_reports(dataset, pred, metrics, policy_eval, rules, plan)
    update_docs()

    print("R037_DATASET=" + str(DATASET))
    print("R037_LOTO=" + str(LOTO))
    print("R037_POLICY_EVAL=" + str(POLICY_EVAL))
    print("R037_PLAN=" + str(PLAN))
    print("R037_REPORT=" + str(REPORT))
    print("R037_FIGURE=" + str(SVG))


if __name__ == "__main__":
    main()
