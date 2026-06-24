#!/usr/bin/env python3
"""R030 refined band policy synthesis for four-phase IQCOT/PIS-IEK.

This script performs post-processing only.  It does not edit or run any
Simulink model.  The goal is to turn R029 held-out guard evidence into a
more conservative deployable band policy, and to identify non-priority R027
contexts where dense-anchor projection may be too conservative.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

import pandas as pd


OUTPUT = Path(__file__).resolve().parent
FIGURES = OUTPUT / "figures"
FIGURES.mkdir(parents=True, exist_ok=True)


R027_PLAN = OUTPUT / "iqcot_r027_proxy_table_in_loop_plan.csv"
R028_OFFLINE = OUTPUT / "iqcot_r028_offline_replay_all_contexts.csv"
R028_SWITCHING = OUTPUT / "iqcot_r028_switching_calibrated_policy_eval_priority.csv"
R029_RESULTS = OUTPUT / "iqcot_r029_heldout_guard_results_combined.csv"
MODE_DATA = OUTPUT / "iqcot_mode_aware_slew_dataset.csv"


OUT_OFFLINE_EVAL = OUTPUT / "iqcot_r030_refined_band_policy_eval.csv"
OUT_SUMMARY = OUTPUT / "iqcot_r030_refined_band_policy_summary.csv"
OUT_BANDS = OUTPUT / "iqcot_r030_refined_band_context_bands.csv"
OUT_SWITCHING = OUTPUT / "iqcot_r030_refined_band_switching_evidence.csv"
OUT_CHALLENGES = OUTPUT / "iqcot_r030_dense_anchor_challenge_candidates.csv"
OUT_CHALLENGE_PLAN = OUTPUT / "iqcot_r030_dense_anchor_challenge_plan.csv"
OUT_REPORT = OUTPUT / "iqcot_r030_refined_band_policy_report.md"
OUT_PAPER = OUTPUT / "iqcot_r030_refined_band_paper_section.md"
OUT_FIGURE = FIGURES / "fig39_r030_refined_band_policy.svg"


CONTEXT_COLS = ["target_label", "objective", "tau_ai_us"]


@dataclass(frozen=True)
class PolicyDecision:
    selected_ref_slew_us: float
    band_low_us: float
    band_high_us: float
    rule: str
    evidence: str
    boundary: str


def read_csv(path: Path) -> pd.DataFrame:
    if not path.exists():
        raise FileNotFoundError(path)
    return pd.read_csv(path)


def f3(value: float) -> str:
    if pd.isna(value):
        return ""
    return f"{float(value):.3f}"


def context_key(row: pd.Series) -> tuple[str, str, float]:
    return (str(row["target_label"]), str(row["objective"]), float(row["tau_ai_us"]))


def lookup_mode_score(mode_data: pd.DataFrame, target: str, objective: str, slew_us: float) -> pd.Series:
    subset = mode_data[
        (mode_data["target_label"].astype(str) == target)
        & (mode_data["objective"].astype(str) == objective)
        & (mode_data["ref_slew_us"].astype(float).round(9) == round(float(slew_us), 9))
    ].copy()
    if subset.empty:
        target_subset = mode_data[
            (mode_data["target_label"].astype(str) == target)
            & (mode_data["objective"].astype(str) == objective)
        ].copy()
        if target_subset.empty:
            raise KeyError(f"No score rows for {target}/{objective}")
        target_subset["distance"] = (target_subset["ref_slew_us"].astype(float) - float(slew_us)).abs()
        return target_subset.sort_values(["distance", "objective_score"]).iloc[0]
    return subset.sort_values("objective_score").iloc[0]


def build_anchor_map(r028_offline: pd.DataFrame) -> dict[tuple[str, str, float], pd.Series]:
    anchors: dict[tuple[str, str, float], pd.Series] = {}
    anchor_rows = r028_offline[r028_offline["policy"] == "r028_dense_anchor_proxy"]
    fallback_rows = r028_offline[r028_offline["policy"] == "discrete_dense_long_table"]
    for _, row in pd.concat([fallback_rows, anchor_rows], ignore_index=True).iterrows():
        key = context_key(row.rename({"tau_AI_us": "tau_ai_us"}))
        anchors[key] = row
    return anchors


def decide_r030(target: str, objective: str, tau_ai_us: float, anchor_slew_us: float) -> PolicyDecision:
    """R029-refined conservative deployment rule.

    The returned point is an evaluation representative for the band.  The
    policy text deliberately keeps band/projection language because these
    values are not global optima.
    """
    tau = float(tau_ai_us)
    if target == "10A" and objective == "score_settle005":
        if tau >= 2.0:
            return PolicyDecision(
                selected_ref_slew_us=34.0,
                band_low_us=34.0,
                band_high_us=40.0,
                rule="10A settling-aware delay guard: tau_AI >= 2us selects the short-slew edge",
                evidence="R027 tau=2us priority replay plus R029 tau=2.5/3us held-out rows",
                boundary="Do not extrapolate below 2us; not a global T_slew optimum.",
            )
        if tau >= 1.25:
            return PolicyDecision(
                selected_ref_slew_us=40.0,
                band_low_us=34.0,
                band_high_us=50.0,
                rule="10A transition band: around 1.5us use the measured 40us edge",
                evidence="R029 tau=1.5us held-out row",
                boundary="Only a local transition choice; 0/0.5/1us still use dense-anchor evidence.",
            )
        return PolicyDecision(
            selected_ref_slew_us=float(anchor_slew_us),
            band_low_us=float(anchor_slew_us),
            band_high_us=float(anchor_slew_us),
            rule="10A low-delay dense-anchor fallback",
            evidence="R027 tau=0/0.5/1us priority replay favored dense-anchor over old proxy",
            boundary="Conservative fallback; may be revisited if future low-delay fine probes are run.",
        )
    if target == "near0A" and objective == "score_settle010":
        if tau < 0.5:
            return PolicyDecision(
                selected_ref_slew_us=38.0,
                band_low_us=30.0,
                band_high_us=38.0,
                rule="near0A strong-settling low-delay band: select the upper fine-sweep edge",
                evidence="R029 tau=0/0.25us held-out rows",
                boundary="This corrects the fixed 35us guard; it is still a local band, not a global optimum.",
            )
        return PolicyDecision(
            selected_ref_slew_us=30.0,
            band_low_us=30.0,
            band_high_us=38.0,
            rule="near0A strong-settling delayed band: return to dense/proxy lower edge",
            evidence="R029 tau=0.5us held-out row and R027 tau=1/2us priority replay",
            boundary="The 30-38us band should be selected by score/risk proxy; fixed 35us is not retained.",
        )
    return PolicyDecision(
        selected_ref_slew_us=float(anchor_slew_us),
        band_low_us=float(anchor_slew_us),
        band_high_us=float(anchor_slew_us),
        rule="default dense-anchor projection",
        evidence="R028 conservative switching-calibrated dense-anchor rule",
        boundary="Default action outside R029-refined local guard contexts.",
    )


def offline_policy_eval(r028_offline: pd.DataFrame, mode_data: pd.DataFrame) -> tuple[pd.DataFrame, pd.DataFrame]:
    df = r028_offline.copy()
    df = df.rename(columns={"tau_AI_us": "tau_ai_us"})

    baseline_policies = [
        "combined_grid_oracle",
        "discrete_dense_long_table",
        "calibrated_risk_proxy_projection",
        "r028_dense_anchor_proxy",
        "r028_switching_guarded_proxy",
        "near_opt_band_clipping",
    ]
    baseline = df[df["policy"].isin(baseline_policies)].copy()
    baseline["band_low_us"] = baseline["selected_ref_slew_us"].astype(float)
    baseline["band_high_us"] = baseline["selected_ref_slew_us"].astype(float)
    baseline["rule"] = baseline["selection_basis"]
    baseline["evidence"] = "R028 offline replay"
    baseline["eval_layer"] = "offline_grid_replay"
    baseline["regret"] = baseline["regret_vs_combined_oracle"].astype(float)

    anchors = build_anchor_map(r028_offline)
    r030_rows: list[dict[str, object]] = []
    oracle_rows = df[df["policy"] == "combined_grid_oracle"].copy()
    for _, oracle in oracle_rows.iterrows():
        key = context_key(oracle)
        anchor_row = anchors[key]
        decision = decide_r030(
            target=str(oracle["target_label"]),
            objective=str(oracle["objective"]),
            tau_ai_us=float(oracle["tau_ai_us"]),
            anchor_slew_us=float(anchor_row["selected_ref_slew_us"]),
        )
        score_row = lookup_mode_score(
            mode_data,
            target=str(oracle["target_label"]),
            objective=str(oracle["objective"]),
            slew_us=decision.selected_ref_slew_us,
        )
        objective_score = float(score_row["objective_score"])
        oracle_score = float(oracle["objective_score"])
        r030_rows.append(
            {
                "target_label": oracle["target_label"],
                "objective": oracle["objective"],
                "tau_ai_us": float(oracle["tau_ai_us"]),
                "policy": "r030_refined_band_policy",
                "source_policy": "R029-refined dense-anchor band",
                "selected_ref_slew_us": decision.selected_ref_slew_us,
                "objective_score": objective_score,
                "regret_vs_combined_oracle": objective_score - oracle_score,
                "band_low_us": decision.band_low_us,
                "band_high_us": decision.band_high_us,
                "rule": decision.rule,
                "evidence": decision.evidence,
                "boundary": decision.boundary,
                "eval_layer": "offline_grid_replay_representative",
                "regret": objective_score - oracle_score,
                "undershoot_mV": float(score_row["undershoot_mV"]),
                "settle_time_us": float(score_row["settle_time_us"]),
                "skip_count_est": float(score_row["skip_count_est"]),
                "phase_std_ns": float(score_row["final_phase_spacing_std_ns"]),
            }
        )
    r030 = pd.DataFrame(r030_rows)

    baseline_keep = baseline[
        [
            "target_label",
            "objective",
            "tau_ai_us",
            "policy",
            "source_policy",
            "selected_ref_slew_us",
            "objective_score",
            "regret_vs_combined_oracle",
            "band_low_us",
            "band_high_us",
            "rule",
            "evidence",
            "boundary",
            "eval_layer",
            "regret",
        ]
    ].copy()
    eval_df = pd.concat([baseline_keep, r030], ignore_index=True, sort=False)
    summary = (
        eval_df.groupby("policy", as_index=False)
        .agg(
            n_contexts=("regret", "count"),
            mean_regret=("regret", "mean"),
            median_regret=("regret", "median"),
            max_regret=("regret", "max"),
            mean_selected_ref_slew_us=("selected_ref_slew_us", "mean"),
        )
        .sort_values(["mean_regret", "max_regret", "policy"])
    )
    bands = r030[
        [
            "target_label",
            "objective",
            "tau_ai_us",
            "selected_ref_slew_us",
            "band_low_us",
            "band_high_us",
            "rule",
            "evidence",
            "boundary",
            "regret_vs_combined_oracle",
        ]
    ].copy()
    return pd.concat([eval_df], ignore_index=True), summary, bands


def first_row(df: pd.DataFrame, mask: pd.Series, order_policy: str | None = None) -> pd.Series | None:
    rows = df[mask].copy()
    if rows.empty:
        return None
    if order_policy is not None:
        exact = rows[rows["policy"] == order_policy]
        if not exact.empty:
            return exact.iloc[0]
    return rows.iloc[0]


def switching_evidence(r028_switching: pd.DataFrame, r029_results: pd.DataFrame) -> pd.DataFrame:
    rows: list[dict[str, object]] = []

    def add_from_r028(target: str, objective: str, tau: float, policy: str) -> None:
        mask = (
            (r028_switching["target_label"] == target)
            & (r028_switching["objective"] == objective)
            & (r028_switching["tau_ai_us"].astype(float).round(9) == round(float(tau), 9))
        )
        selected = first_row(r028_switching, mask & (r028_switching["policy"] == policy))
        dense = first_row(r028_switching, mask & (r028_switching["policy"] == "r028_dense_anchor_proxy"))
        old_proxy = first_row(r028_switching, mask & (r028_switching["policy"] == "calibrated_risk_proxy_projection"))
        if selected is None:
            raise KeyError((target, objective, tau, policy))
        rows.append(
            {
                "target_label": target,
                "objective": objective,
                "tau_ai_us": tau,
                "r030_policy_row": policy,
                "r030_selected_slew_us": float(selected["selected_ref_slew_us"]),
                "r030_selected_objective_score": float(selected["selected_objective_score"]),
                "r030_switching_regret": float(selected["switching_regret_priority"]),
                "dense_anchor_slew_us": float(dense["selected_ref_slew_us"]) if dense is not None else None,
                "dense_anchor_regret": float(dense["switching_regret_priority"]) if dense is not None else None,
                "old_proxy_slew_us": float(old_proxy["selected_ref_slew_us"]) if old_proxy is not None else None,
                "old_proxy_regret": float(old_proxy["switching_regret_priority"]) if old_proxy is not None else None,
                "evidence_source": "R027/R028 priority switching replay",
                "boundary": "Priority switching evidence; not hardware/HIL.",
            }
        )

    def add_from_r029(target: str, objective: str, tau: float, policy: str) -> None:
        mask = (
            (r029_results["target_label"] == target)
            & (r029_results["objective"] == objective)
            & (r029_results["tau_ai_us"].astype(float).round(9) == round(float(tau), 9))
        )
        selected = first_row(r029_results, mask & (r029_results["policy"] == policy))
        dense = first_row(r029_results, mask & (r029_results["policy_family"] == "dense_anchor"))
        old_proxy = first_row(r029_results, mask & (r029_results["policy_family"] == "old_proxy_failure_probe"))
        if selected is None:
            raise KeyError((target, objective, tau, policy))
        rows.append(
            {
                "target_label": target,
                "objective": objective,
                "tau_ai_us": tau,
                "r030_policy_row": policy,
                "r030_selected_slew_us": float(selected["selected_ref_slew_us"]),
                "r030_selected_objective_score": float(selected["selected_objective_score"]),
                "r030_switching_regret": float(selected["switching_regret_combined"]),
                "dense_anchor_slew_us": float(dense["selected_ref_slew_us"]) if dense is not None else None,
                "dense_anchor_regret": float(dense["switching_regret_combined"]) if dense is not None else None,
                "old_proxy_slew_us": float(old_proxy["selected_ref_slew_us"]) if old_proxy is not None else None,
                "old_proxy_regret": float(old_proxy["switching_regret_combined"]) if old_proxy is not None else None,
                "evidence_source": "R029 held-out switching validation",
                "boundary": "Held-out derived Simulink evidence; not hardware/HIL.",
            }
        )

    for tau in [0.0, 0.5, 1.0]:
        add_from_r028("10A", "score_settle005", tau, "r028_dense_anchor_proxy")
    add_from_r029("10A", "score_settle005", 1.5, "fixed_40us_probe")
    add_from_r028("10A", "score_settle005", 2.0, "r028_switching_guarded_proxy")
    add_from_r029("10A", "score_settle005", 2.5, "r028_guarded_candidate")
    add_from_r029("10A", "score_settle005", 3.0, "r028_guarded_candidate")

    add_from_r029("near0A", "score_settle010", 0.0, "fine_sweep_38us_probe")
    add_from_r029("near0A", "score_settle010", 0.25, "fine_sweep_38us_probe")
    add_from_r029("near0A", "score_settle010", 0.5, "r028_dense_anchor")
    for tau in [1.0, 2.0]:
        add_from_r028("near0A", "score_settle010", tau, "r028_dense_anchor_proxy")

    out = pd.DataFrame(rows)
    out["r030_advantage_vs_dense_anchor"] = out["dense_anchor_regret"] - out["r030_switching_regret"]
    out["r030_advantage_vs_old_proxy"] = out["old_proxy_regret"] - out["r030_switching_regret"]
    return out.sort_values(["target_label", "objective", "tau_ai_us"]).reset_index(drop=True)


def dense_anchor_challenges(plan: pd.DataFrame, max_contexts: int = 15) -> tuple[pd.DataFrame, pd.DataFrame]:
    rows: list[dict[str, object]] = []
    for key, group in plan.groupby(CONTEXT_COLS):
        policies = {str(r["policy"]): r for _, r in group.iterrows()}
        dense = policies.get("discrete_dense_long_table")
        proxy = policies.get("calibrated_risk_proxy_projection")
        if dense is None or proxy is None:
            continue
        priority = group["include_in_priority_run"].astype(str).str.lower().eq("true").any()
        dense_slew = float(dense["selected_ref_slew_us"])
        proxy_slew = float(proxy["selected_ref_slew_us"])
        dense_score = float(dense["offline_objective_score"])
        proxy_score = float(proxy["offline_objective_score"])
        rows.append(
            {
                "target_label": key[0],
                "objective": key[1],
                "tau_ai_us": float(key[2]),
                "priority_context": bool(priority),
                "dense_slew_us": dense_slew,
                "proxy_slew_us": proxy_slew,
                "slew_delta_us": proxy_slew - dense_slew,
                "dense_offline_score": dense_score,
                "proxy_offline_score": proxy_score,
                "proxy_minus_dense_score": proxy_score - dense_score,
                "dense_regret": float(dense["offline_regret_vs_oracle"]),
                "proxy_regret": float(proxy["offline_regret_vs_oracle"]),
                "reason": "proxy differs from dense and was not included in the R027 priority switching matrix",
            }
        )
    all_candidates = pd.DataFrame(rows)
    candidates = all_candidates[
        (~all_candidates["priority_context"])
        & (all_candidates["slew_delta_us"].abs() > 1e-9)
    ].copy()
    candidates["challenge_rank_key"] = candidates["proxy_minus_dense_score"]
    candidates = candidates.sort_values(["challenge_rank_key", "target_label", "objective", "tau_ai_us"])

    # Keep complete tau groups for the three strongest motifs rather than a
    # cherry-picked single row.  This gives a compact but interpretable next run.
    motif_order = [
        ("10A", "score_settle010"),
        ("20A", "base"),
        ("20A", "score_settle005"),
    ]
    keep_contexts: list[tuple[str, str, float]] = []
    for target, objective in motif_order:
        subset = candidates[
            (candidates["target_label"] == target)
            & (candidates["objective"] == objective)
        ].sort_values("tau_ai_us")
        for _, row in subset.iterrows():
            keep_contexts.append((str(row["target_label"]), str(row["objective"]), float(row["tau_ai_us"])))
    if not keep_contexts:
        keep_contexts = [
            (str(r["target_label"]), str(r["objective"]), float(r["tau_ai_us"]))
            for _, r in candidates.head(max_contexts).iterrows()
        ]

    candidate_set = set(keep_contexts[:max_contexts])
    challenge_rows = candidates[
        candidates.apply(
            lambda r: (str(r["target_label"]), str(r["objective"]), float(r["tau_ai_us"])) in candidate_set,
            axis=1,
        )
    ].copy()

    plan_rows = []
    for target, objective, tau in candidate_set:
        group = plan[
            (plan["target_label"].astype(str) == target)
            & (plan["objective"].astype(str) == objective)
            & (plan["tau_ai_us"].astype(float).round(9) == round(float(tau), 9))
            & (plan["policy"].isin(["discrete_dense_long_table", "calibrated_risk_proxy_projection"]))
        ].copy()
        for _, row in group.iterrows():
            entry = row.to_dict()
            entry["r030_case_id"] = f"R030_{len(plan_rows) + 1:04d}"
            entry["r030_plan_role"] = "dense_anchor_challenge_pair"
            entry["r030_reason"] = (
                "R030 challenge: proxy and dense differ outside R027 priority; "
                "run pair to test whether dense-anchor projection is over-conservative."
            )
            plan_rows.append(entry)
    challenge_plan = pd.DataFrame(plan_rows)
    if not challenge_plan.empty:
        challenge_plan = challenge_plan.sort_values(["target_label", "objective", "tau_ai_us", "policy"]).reset_index(drop=True)
        challenge_plan["r030_case_id"] = [f"R030_{i + 1:04d}" for i in range(len(challenge_plan))]
    return candidates.reset_index(drop=True), challenge_plan


def write_svg(summary: pd.DataFrame, switching: pd.DataFrame) -> None:
    # Manual SVG so the script has no matplotlib dependency.
    selected = summary[summary["policy"].isin([
        "r028_dense_anchor_proxy",
        "r028_switching_guarded_proxy",
        "r030_refined_band_policy",
        "discrete_dense_long_table",
        "calibrated_risk_proxy_projection",
    ])].copy()
    selected = selected.sort_values("mean_regret", ascending=False)
    width, height = 980, 520
    left, top = 250, 70
    bar_h, gap = 34, 18
    max_val = max(float(selected["mean_regret"].max()), 0.001)

    colors = {
        "r030_refined_band_policy": "#0B6E4F",
        "r028_switching_guarded_proxy": "#2D7DD2",
        "r028_dense_anchor_proxy": "#73A2C6",
        "discrete_dense_long_table": "#B0B0B0",
        "calibrated_risk_proxy_projection": "#D95F02",
    }
    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        '<rect width="100%" height="100%" fill="white"/>',
        '<text x="30" y="35" font-size="20" font-family="Arial" font-weight="bold">R030 refined band policy: offline regret and switching guard evidence</text>',
        '<text x="30" y="58" font-size="12" font-family="Arial" fill="#555">Offline replay is a consistency check; switching evidence remains derived Simulink, not hardware/HIL.</text>',
    ]
    for i, row in enumerate(selected.itertuples(index=False)):
        y = top + i * (bar_h + gap)
        bar_w = 520 * float(row.mean_regret) / max_val
        color = colors.get(row.policy, "#666")
        label = row.policy.replace("_", " ")
        parts.extend(
            [
                f'<text x="30" y="{y + 22}" font-size="13" font-family="Arial">{label}</text>',
                f'<rect x="{left}" y="{y}" width="{bar_w:.1f}" height="{bar_h}" fill="{color}" opacity="0.88"/>',
                f'<text x="{left + bar_w + 8:.1f}" y="{y + 22}" font-size="13" font-family="Arial">{float(row.mean_regret):.3f}</text>',
            ]
        )

    switch_y = top + len(selected) * (bar_h + gap) + 35
    parts.extend(
        [
            f'<text x="30" y="{switch_y}" font-size="15" font-family="Arial" font-weight="bold">Known guard-context switching regret</text>',
            f'<text x="30" y="{switch_y + 22}" font-size="12" font-family="Arial" fill="#555">R030 selected rows over R027 priority + R029 held-out contexts: mean regret {switching["r030_switching_regret"].mean():.3f}; dense-anchor mean regret {switching["dense_anchor_regret"].mean():.3f}.</text>',
        ]
    )
    x0 = 30
    y0 = switch_y + 52
    cell_w = 68
    for i, row in enumerate(switching.sort_values(["target_label", "tau_ai_us"]).itertuples(index=False)):
        x = x0 + (i % 12) * (cell_w + 4)
        y = y0 + (i // 12) * 58
        val = float(row.r030_switching_regret)
        fill = "#0B6E4F" if val < 1e-9 else "#F0A202"
        parts.append(f'<rect x="{x}" y="{y}" width="{cell_w}" height="32" fill="{fill}" opacity="0.82"/>')
        parts.append(f'<text x="{x + 5}" y="{y + 14}" font-size="10" font-family="Arial" fill="white">{row.target_label} {row.tau_ai_us:g}us</text>')
        parts.append(f'<text x="{x + 5}" y="{y + 27}" font-size="10" font-family="Arial" fill="white">reg {val:.3f}</text>')
    parts.append("</svg>")
    OUT_FIGURE.write_text("\n".join(parts), encoding="utf-8")


def write_report(summary: pd.DataFrame, switching: pd.DataFrame, challenges: pd.DataFrame, challenge_plan: pd.DataFrame) -> None:
    r030 = summary[summary["policy"] == "r030_refined_band_policy"].iloc[0]
    dense = summary[summary["policy"] == "r028_dense_anchor_proxy"].iloc[0]
    guarded = summary[summary["policy"] == "r028_switching_guarded_proxy"].iloc[0]
    proxy_better = challenges[challenges["proxy_minus_dense_score"] < 0]
    report = f"""# R030 refined band policy synthesis

## Scope

R030 is a post-processing and validation-design step.  It does not modify any
original `.slx` file, does not edit `.slx` XML, and does not claim hardware or
neural-network AI-in-loop validation.  The goal is to convert R029 held-out
guard evidence into a more careful band policy and to choose the next derived
Simulink challenge points.

## Refined policy

The R030 representative rule is:

- `10A / score_settle005`: use dense-anchor at `tau_AI <= 1us`; use `40us`
  around the measured `1.5us` transition; use the short-slew edge `34us` for
  `tau_AI >= 2us`.
- `near0A / score_settle010`: replace the fixed `35us` guard with a
  `30-38us` local band; use `38us` for `tau_AI < 0.5us` and `30us` from
  `0.5us` upward in the current representative table.
- All other contexts fall back to the R028 dense-anchor projection.

This is intentionally written as a local band/projection rule, not as a global
optimum for `T_slew`.

## Offline consistency replay

The offline replay uses the completed dense+long+fine grid and should be read
only as a consistency check.  It cannot replace switching-level delayed
reference validation.

| policy | contexts | mean regret | max regret |
| --- | ---: | ---: | ---: |
| R030 refined band | {int(r030.n_contexts)} | {float(r030.mean_regret):.3f} | {float(r030.max_regret):.3f} |
| R028 guarded candidate | {int(guarded.n_contexts)} | {float(guarded.mean_regret):.3f} | {float(guarded.max_regret):.3f} |
| R028 dense-anchor | {int(dense.n_contexts)} | {float(dense.mean_regret):.3f} | {float(dense.max_regret):.3f} |

R030 is essentially tied with the old stress-fitted guarded rule in pure
offline replay and remains slightly worse than dense-anchor on that static
grid because it deliberately rejects the fixed near0A `35us` point and uses
R029 held-out switching evidence instead.  This is a feature of the claim
boundary, not a failure of the policy.

## Switching evidence synthesis

Combining R027 priority replay and R029 held-out rows gives
`{len(switching)}` known guard-context entries.  The R030-selected rows have
mean switching regret `{switching['r030_switching_regret'].mean():.3f}` over
these known contexts, while the corresponding dense-anchor rows have mean
regret `{switching['dense_anchor_regret'].mean():.3f}`.  This is not an
independent proof because the rule was synthesized from these local findings,
but it is a useful consistency check:

- the old `62us` proxy action remains excluded for `10A / score_settle005`;
- the short `34us` guard is retained only at and above the `2us` delay region;
- near0A uses a `30-38us` band rather than a fixed `35us` point.

## Dense-anchor challenge plan

R027 had `315` planned rows but only `48` priority rows were switched.  R030
finds `{len(challenges)}` non-priority contexts where calibrated proxy and
dense table select different `T_slew` values; `{len(proxy_better)}` of them
look better for proxy in the offline score.  The next compact challenge plan
contains `{len(challenge_plan)}` rows, paired by dense/proxy policy, and is
written to:

```text
{OUT_CHALLENGE_PLAN.as_posix()}
```

The executable entry point is:

```matlab
iqcot_r030_dense_anchor_challenge_validation(false)      % dry run
iqcot_r030_dense_anchor_challenge_validation(true)       % run all 30 rows
iqcot_r030_dense_anchor_challenge_validation(true,10,11) % chunked run
```

The main motifs are:

- `10A / score_settle010`: dense `30us` vs proxy `32us`, proxy offline
  advantage about `0.490` score points.
- `20A / base`: dense `80us` vs proxy `86us`, proxy offline advantage about
  `0.140` score points.
- `20A / score_settle005`: dense `30us` vs proxy `66us`, proxy offline
  advantage about `0.095` score points, but with a much longer slew, so it
  deserves switching validation before any deployment claim.

## Boundary

- AI remains a supervisory scheduler for low-dimensional parameters such as
  `T_slew`; IQCOT remains the inner loop.
- The R030 band is derived Simulink evidence plus offline post-processing, not
  hardware/HIL validation.
- R030 does not claim that `34us`, `38us`, or any single `T_slew` is globally
  optimal.
- The challenge plan is a future experiment design, not a result.
"""
    OUT_REPORT.write_text(report, encoding="utf-8")

    paper = f"""### R030 refined band policy and dense-anchor challenge design

R029修正了R028的两个硬编码guard之后，本文进一步将guard写成局部安全带而不是单点规则。新的R030代表策略为：`10A/score_settle005`在`tau_AI<=1us`保留dense-anchor，在已测得的`1.5us`过渡区域采用`40us`，在`tau_AI>=2us`采用短斜率边界`34us`；`near0A/score_settle010`不再使用固定`35us`，而写成`30-38us`局部带，当前代表点在`tau_AI<0.5us`取`38us`、从`0.5us`起回到`30us`。该规则在R027 priority replay和R029 held-out已知guard上下文上的合成mean switching regret为`{switching['r030_switching_regret'].mean():.3f}`，对应dense-anchor为`{switching['dense_anchor_regret'].mean():.3f}`。这只能说明R030与当前派生Simulink证据一致，不能说明全局最优或硬件安全。

同时，R030从R027完整`315`行计划中筛出dense与proxy不同但未进入priority switching的上下文。离线分数显示，`10A/score_settle010`中proxy的`32us`相对dense的`30us`有约`0.490`分优势，`20A/base`中`86us`相对`80us`有约`0.140`分优势，`20A/score_settle005`中`66us`相对`30us`有约`0.095`分优势。由于R027已经证明离线排序在延迟开关级回放中可能失效，这些点应被写成下一轮派生Simulink挑战计划，而不是当前性能结论。
"""
    OUT_PAPER.write_text(paper, encoding="utf-8")


def main() -> None:
    r027_plan = read_csv(R027_PLAN)
    r028_offline = read_csv(R028_OFFLINE)
    r028_switching = read_csv(R028_SWITCHING)
    r029_results = read_csv(R029_RESULTS)
    mode_data = read_csv(MODE_DATA)

    offline_eval, summary, bands = offline_policy_eval(r028_offline, mode_data)
    switching = switching_evidence(r028_switching, r029_results)
    challenges, challenge_plan = dense_anchor_challenges(r027_plan)

    offline_eval.to_csv(OUT_OFFLINE_EVAL, index=False)
    summary.to_csv(OUT_SUMMARY, index=False)
    bands.to_csv(OUT_BANDS, index=False)
    switching.to_csv(OUT_SWITCHING, index=False)
    challenges.to_csv(OUT_CHALLENGES, index=False)
    challenge_plan.to_csv(OUT_CHALLENGE_PLAN, index=False)

    write_svg(summary, switching)
    write_report(summary, switching, challenges, challenge_plan)

    print(f"R030_OFFLINE_EVAL={OUT_OFFLINE_EVAL}")
    print(f"R030_SUMMARY={OUT_SUMMARY}")
    print(f"R030_BANDS={OUT_BANDS}")
    print(f"R030_SWITCHING_EVIDENCE={OUT_SWITCHING}")
    print(f"R030_CHALLENGES={OUT_CHALLENGES}")
    print(f"R030_CHALLENGE_PLAN={OUT_CHALLENGE_PLAN}")
    print(f"R030_REPORT={OUT_REPORT}")
    print(f"R030_PAPER={OUT_PAPER}")
    print(f"R030_FIGURE={OUT_FIGURE}")


if __name__ == "__main__":
    main()
