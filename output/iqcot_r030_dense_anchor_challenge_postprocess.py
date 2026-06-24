#!/usr/bin/env python3
"""Post-process R030 dense-anchor challenge switching results.

This script combines the three chunked derived-Simulink challenge runs and
recomputes context-level regret over the complete 30-row dense/proxy pair
matrix.  It does not edit or run any .slx model.  The conclusions are kept
local: derived Simulink switching replay is not hardware validation, and the
challenge set does not prove a global T_slew optimum.
"""

from __future__ import annotations

from pathlib import Path

import pandas as pd


ROOT = Path("E:/Desktop/codex")
OUT = ROOT / "output"
FIG = OUT / "figures"

PLAN = OUT / "iqcot_r030_dense_anchor_challenge_plan.csv"
COMBINED = OUT / "iqcot_r030_dense_anchor_challenge_results_combined.csv"
POLICY_SUMMARY = OUT / "iqcot_r030_dense_anchor_challenge_policy_summary.csv"
CONTEXT_SUMMARY = OUT / "iqcot_r030_dense_anchor_challenge_context_summary.csv"
MOTIF_SUMMARY = OUT / "iqcot_r030_dense_anchor_challenge_motif_summary.csv"
REPORT = OUT / "iqcot_r030_dense_anchor_challenge_report.md"
PAPER = OUT / "iqcot_r030_dense_anchor_challenge_paper_section.md"
SVG = FIG / "fig40_r030_dense_anchor_challenge.svg"

CONTEXT = ["target_label", "objective", "tau_ai_us"]
POLICY_DENSE = "discrete_dense_long_table"
POLICY_PROXY = "calibrated_risk_proxy_projection"


def chunk_files() -> list[Path]:
    return sorted(
        OUT.glob("iqcot_r027_proxy_table_in_loop_results_r030_challenge_rows*.csv")
    )


def objective_score_column(objective: str) -> str:
    if objective == "base":
        return "base_score"
    if objective == "score_settle005":
        return "score_settle005"
    if objective == "score_settle010":
        return "score_settle010"
    raise ValueError(f"Unknown objective: {objective}")


def read_results() -> pd.DataFrame:
    frames = []
    for idx, path in enumerate(chunk_files()):
        df = pd.read_csv(path)
        df["chunk_file"] = path.name
        df["chunk_order"] = idx
        frames.append(df)
    if not frames:
        raise FileNotFoundError("No R030 challenge result chunks found.")
    rows = pd.concat(frames, ignore_index=True)
    rows = rows.sort_values(["r027_case_id", "chunk_order"]).drop_duplicates(
        "r027_case_id", keep="last"
    )
    plan = pd.read_csv(PLAN)
    plan_cols = [
        "r027_case_id",
        "r030_case_id",
        "r030_plan_role",
        "r030_reason",
        "selection_basis",
        "boundary",
        "include_in_priority_run",
    ]
    rows = rows.merge(plan[plan_cols], on="r027_case_id", how="left")
    if rows["r030_case_id"].isna().any():
        missing = rows.loc[rows["r030_case_id"].isna(), "r027_case_id"].tolist()
        raise ValueError(f"Rows missing from R030 plan: {missing}")
    return rows


def numericize(rows: pd.DataFrame) -> pd.DataFrame:
    numeric_cols = [
        "target_load_A",
        "load_drop_A",
        "selected_ref_slew_us",
        "realized_ref_slew_us_in_offline_grid",
        "tau_ai_us",
        "delay_events",
        "ref_start_delay_us",
        "objective_alpha_settle",
        "offline_objective_score",
        "offline_regret_vs_oracle",
        "offline_undershoot_mV",
        "offline_settle_time_us",
        "offline_skip_count_est",
        "offline_phase_std_ns",
        "overshoot_mV",
        "undershoot_mV",
        "settle_time_us",
        "max_gate_gap_us",
        "skip_count_est",
        "final_vout_error_mV",
        "final_il_phase_imbalance_A",
        "final_il_m2_projection_A",
        "final_phase_spacing_std_ns",
        "base_score",
        "score_settle005",
        "score_settle010",
        "selected_objective_score",
        "switching_regret_vs_best_in_run",
    ]
    for col in numeric_cols:
        if col in rows.columns:
            rows[col] = pd.to_numeric(rows[col], errors="coerce")
    return rows


def recompute_regret(rows: pd.DataFrame) -> pd.DataFrame:
    rows = rows.copy()
    rows["success_bool"] = rows["success"].astype(str).str.lower().isin(["1", "true"])
    if not rows["success_bool"].all():
        failed = rows.loc[~rows["success_bool"], ["r027_case_id", "error_message"]]
        raise RuntimeError(f"R030 challenge contains failed runs:\n{failed}")

    calc_scores = []
    for _, row in rows.iterrows():
        calc_scores.append(row[objective_score_column(str(row["objective"]))])
    rows["selected_objective_score_recomputed"] = calc_scores
    rows["selected_objective_score_delta"] = (
        rows["selected_objective_score"] - rows["selected_objective_score_recomputed"]
    )
    max_delta = rows["selected_objective_score_delta"].abs().max()
    if max_delta > 1e-8:
        raise ValueError(f"selected_objective_score mismatch, max delta={max_delta}")

    rows["context_best_score"] = rows.groupby(CONTEXT)["selected_objective_score"].transform("min")
    rows["switching_regret_full_context"] = (
        rows["selected_objective_score"] - rows["context_best_score"]
    )
    rows["offline_best_score_in_pair"] = rows.groupby(CONTEXT)["offline_objective_score"].transform("min")
    rows["offline_regret_in_pair"] = rows["offline_objective_score"] - rows["offline_best_score_in_pair"]
    return rows.sort_values(CONTEXT + ["policy"]).reset_index(drop=True)


def policy_summary(rows: pd.DataFrame) -> pd.DataFrame:
    best = rows.loc[rows.groupby(CONTEXT)["selected_objective_score"].idxmin()]
    best_counts = best.groupby("policy").size().rename("best_context_count")
    zero_counts = (
        rows[rows["switching_regret_full_context"].abs() <= 1e-9]
        .groupby("policy")
        .size()
        .rename("zero_regret_context_count")
    )
    summary = (
        rows.groupby(["policy", "policy_role", "policy_kind"], as_index=False)
        .agg(
            n_cases=("r027_case_id", "count"),
            mean_switching_regret=("switching_regret_full_context", "mean"),
            max_switching_regret=("switching_regret_full_context", "max"),
            mean_selected_objective_score=("selected_objective_score", "mean"),
            mean_offline_regret_in_pair=("offline_regret_in_pair", "mean"),
            mean_undershoot_mV=("undershoot_mV", "mean"),
            mean_settle_time_us=("settle_time_us", "mean"),
            mean_skip_count=("skip_count_est", "mean"),
            mean_phase_spacing_std_ns=("final_phase_spacing_std_ns", "mean"),
            mean_abs_final_vout_error_mV=(
                "final_vout_error_mV",
                lambda s: s.abs().mean(),
            ),
        )
        .merge(best_counts, on="policy", how="left")
        .merge(zero_counts, on="policy", how="left")
    )
    summary["best_context_count"] = summary["best_context_count"].fillna(0).astype(int)
    summary["zero_regret_context_count"] = (
        summary["zero_regret_context_count"].fillna(0).astype(int)
    )
    return summary.sort_values(["mean_switching_regret", "policy"]).reset_index(drop=True)


def context_summary(rows: pd.DataFrame) -> pd.DataFrame:
    records = []
    for key, ctx in rows.groupby(CONTEXT, sort=True):
        dense = ctx[ctx["policy"] == POLICY_DENSE].iloc[0]
        proxy = ctx[ctx["policy"] == POLICY_PROXY].iloc[0]
        sw_best = ctx.sort_values(["selected_objective_score", "policy"]).iloc[0]
        offline_best = ctx.sort_values(["offline_objective_score", "policy"]).iloc[0]
        diff = proxy["selected_objective_score"] - dense["selected_objective_score"]
        if diff < -1e-9:
            winner = "proxy"
        elif diff > 1e-9:
            winner = "dense"
        else:
            winner = "tie"
        records.append(
            {
                "target_label": key[0],
                "objective": key[1],
                "tau_ai_us": key[2],
                "dense_slew_us": dense["selected_ref_slew_us"],
                "proxy_slew_us": proxy["selected_ref_slew_us"],
                "dense_score": dense["selected_objective_score"],
                "proxy_score": proxy["selected_objective_score"],
                "proxy_minus_dense_score": diff,
                "winner": winner,
                "switching_best_policy": sw_best["policy"],
                "switching_best_slew_us": sw_best["selected_ref_slew_us"],
                "switching_best_score": sw_best["selected_objective_score"],
                "offline_pair_best_policy": offline_best["policy"],
                "offline_pair_best_slew_us": offline_best["selected_ref_slew_us"],
                "offline_pair_ranking_preserved": sw_best["policy"] == offline_best["policy"],
                "dense_regret": dense["switching_regret_full_context"],
                "proxy_regret": proxy["switching_regret_full_context"],
                "dense_skip": dense["skip_count_est"],
                "proxy_skip": proxy["skip_count_est"],
                "dense_settle_us": dense["settle_time_us"],
                "proxy_settle_us": proxy["settle_time_us"],
                "dense_phase_std_ns": dense["final_phase_spacing_std_ns"],
                "proxy_phase_std_ns": proxy["final_phase_spacing_std_ns"],
                "dense_undershoot_mV": dense["undershoot_mV"],
                "proxy_undershoot_mV": proxy["undershoot_mV"],
            }
        )
    return pd.DataFrame(records)


def motif_summary(context: pd.DataFrame) -> pd.DataFrame:
    records = []
    for key, grp in context.groupby(["target_label", "objective"], sort=True):
        records.append(
            {
                "target_label": key[0],
                "objective": key[1],
                "n_contexts": len(grp),
                "proxy_win_count": int((grp["winner"] == "proxy").sum()),
                "dense_win_count": int((grp["winner"] == "dense").sum()),
                "tie_count": int((grp["winner"] == "tie").sum()),
                "mean_proxy_minus_dense_score": grp["proxy_minus_dense_score"].mean(),
                "max_abs_proxy_minus_dense_score": grp["proxy_minus_dense_score"].abs().max(),
                "mean_dense_regret": grp["dense_regret"].mean(),
                "mean_proxy_regret": grp["proxy_regret"].mean(),
                "ranking_preserved_count": int(grp["offline_pair_ranking_preserved"].sum()),
            }
        )
    return pd.DataFrame(records)


def fmt(value: object, ndigits: int = 3) -> str:
    if pd.isna(value):
        return ""
    if isinstance(value, float):
        return f"{value:.{ndigits}f}"
    return str(value)


def md_table(df: pd.DataFrame, cols: list[str], ndigits: int = 3) -> str:
    lines = [
        "| " + " | ".join(cols) + " |",
        "| " + " | ".join(["---"] * len(cols)) + " |",
    ]
    for _, row in df[cols].iterrows():
        lines.append("| " + " | ".join(fmt(row[c], ndigits) for c in cols) + " |")
    return "\n".join(lines)


def write_svg(policy: pd.DataFrame, motif: pd.DataFrame) -> None:
    FIG.mkdir(parents=True, exist_ok=True)
    width, height = 980, 520
    left, top = 95, 55
    plot_w, plot_h = 370, 310
    max_reg = max(0.1, float(policy["mean_switching_regret"].max()) * 1.2)
    colors = {
        POLICY_DENSE: "#4C78A8",
        POLICY_PROXY: "#E45756",
    }
    labels = {
        POLICY_DENSE: "dense-anchor",
        POLICY_PROXY: "proxy",
    }
    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        '<rect width="100%" height="100%" fill="white"/>',
        '<text x="490" y="28" text-anchor="middle" font-family="Arial" font-size="18">R030 dense-anchor challenge derived-Simulink replay</text>',
        f'<line x1="{left}" y1="{top+plot_h}" x2="{left+plot_w}" y2="{top+plot_h}" stroke="#333"/>',
        f'<line x1="{left}" y1="{top}" x2="{left}" y2="{top+plot_h}" stroke="#333"/>',
        '<text x="280" y="495" text-anchor="middle" font-family="Arial" font-size="13">Policy mean regret over 15 paired contexts</text>',
    ]
    for frac in [0, 0.25, 0.5, 0.75, 1.0]:
        y = top + plot_h - frac * plot_h
        val = frac * max_reg
        parts.append(f'<line x1="{left-4}" y1="{y:.1f}" x2="{left+plot_w}" y2="{y:.1f}" stroke="#eee"/>')
        parts.append(
            f'<text x="{left-10}" y="{y+4:.1f}" text-anchor="end" font-family="Arial" font-size="11">{val:.2f}</text>'
        )
    bar_w = 90
    for i, (_, row) in enumerate(policy.iterrows()):
        x = left + 75 + i * 150
        h = row["mean_switching_regret"] / max_reg * plot_h
        y = top + plot_h - h
        p = row["policy"]
        parts.append(
            f'<rect x="{x}" y="{y:.1f}" width="{bar_w}" height="{h:.1f}" fill="{colors.get(p, "#999")}"/>'
        )
        parts.append(
            f'<text x="{x+bar_w/2}" y="{y-7:.1f}" text-anchor="middle" font-family="Arial" font-size="12">{row["mean_switching_regret"]:.3f}</text>'
        )
        parts.append(
            f'<text x="{x+bar_w/2}" y="{top+plot_h+22}" text-anchor="middle" font-family="Arial" font-size="12">{labels.get(p, p)}</text>'
        )
    parts.append(
        f'<text x="26" y="{top+plot_h/2}" text-anchor="middle" transform="rotate(-90 26,{top+plot_h/2})" font-family="Arial" font-size="13">Mean switching regret</text>'
    )

    # Right panel: proxy minus dense by motif.
    x0, y0 = 570, 70
    row_h = 74
    max_abs = max(0.25, float(motif["mean_proxy_minus_dense_score"].abs().max()) * 1.25)
    axis_x = x0 + 190
    parts.extend(
        [
            '<text x="740" y="55" text-anchor="middle" font-family="Arial" font-size="14">Proxy minus dense score by motif</text>',
            f'<line x1="{axis_x}" y1="{y0-25}" x2="{axis_x}" y2="{y0+row_h*len(motif)}" stroke="#333"/>',
            f'<text x="{axis_x}" y="{y0+row_h*len(motif)+24}" text-anchor="middle" font-family="Arial" font-size="11">0</text>',
            f'<text x="{axis_x-150}" y="{y0+row_h*len(motif)+24}" text-anchor="middle" font-family="Arial" font-size="11">proxy better</text>',
            f'<text x="{axis_x+150}" y="{y0+row_h*len(motif)+24}" text-anchor="middle" font-family="Arial" font-size="11">dense better</text>',
        ]
    )
    for i, (_, row) in enumerate(motif.iterrows()):
        cy = y0 + i * row_h
        label = f'{row["target_label"]} / {row["objective"]}'
        val = float(row["mean_proxy_minus_dense_score"])
        bar_len = abs(val) / max_abs * 150
        if val >= 0:
            bx = axis_x
            color = "#4C78A8"
        else:
            bx = axis_x - bar_len
            color = "#E45756"
        parts.append(
            f'<text x="{x0}" y="{cy+6}" text-anchor="start" font-family="Arial" font-size="12">{label}</text>'
        )
        parts.append(
            f'<rect x="{bx:.1f}" y="{cy-14}" width="{bar_len:.1f}" height="24" fill="{color}"/>'
        )
        parts.append(
            f'<text x="{axis_x + (bar_len + 8 if val >= 0 else -bar_len - 8):.1f}" y="{cy+4}" text-anchor="{ "start" if val >= 0 else "end" }" font-family="Arial" font-size="12">{val:.3f}</text>'
        )
        parts.append(
            f'<text x="{x0}" y="{cy+25}" text-anchor="start" font-family="Arial" font-size="10" fill="#555">proxy wins {int(row["proxy_win_count"])}, dense wins {int(row["dense_win_count"])}</text>'
        )
    parts.append("</svg>")
    SVG.write_text("\n".join(parts), encoding="utf-8")


def write_reports(rows: pd.DataFrame, policy: pd.DataFrame, context: pd.DataFrame, motif: pd.DataFrame) -> None:
    proxy_row = policy[policy["policy"] == POLICY_PROXY].iloc[0]
    dense_row = policy[policy["policy"] == POLICY_DENSE].iloc[0]
    proxy_wins = int((context["winner"] == "proxy").sum())
    dense_wins = int((context["winner"] == "dense").sum())
    ties = int((context["winner"] == "tie").sum())
    preserved = int(context["offline_pair_ranking_preserved"].sum())
    total = len(context)

    key_contexts = context[
        (
            (context["target_label"] == "10A")
            & (context["objective"] == "score_settle010")
        )
        | ((context["target_label"] == "20A") & (context["objective"] == "base"))
        | (
            (context["target_label"] == "20A")
            & (context["objective"] == "score_settle005")
        )
    ].copy()

    report = f"""# R030 Dense-Anchor Challenge Report

## Scope

This report post-processes the 30-row R030 dense/proxy paired challenge run.  The
input rows come from derived Simulink delayed-reference switching simulations:

- `iqcot_r027_proxy_table_in_loop_results_r030_challenge_rows001_010.csv`
- `iqcot_r027_proxy_table_in_loop_results_r030_challenge_rows011_020.csv`
- `iqcot_r027_proxy_table_in_loop_results_r030_challenge_rows021_030.csv`

No original `.slx` file is modified.  The analysis recomputes regret within each
full paired context `(target_label, objective, tau_ai_us)` instead of relying on
chunk-local runner summaries.

## Main Result

The challenge does **not** support a broad claim that dense-anchor projection is
over-conservative.  Over {total} paired contexts, the proxy candidate is better in
{proxy_wins}, dense-anchor is better in {dense_wins}, and ties occur in {ties}.  The
mean full-context switching regret is `{dense_row["mean_switching_regret"]:.3f}`
for dense-anchor and `{proxy_row["mean_switching_regret"]:.3f}` for the proxy.

The offline pair ranking is preserved in `{preserved}/{total}` contexts.  This is
useful as a negative calibration result: the event-domain or offline proxy can
identify candidates, but its ordering is not yet reliable enough to replace the
dense-anchor safety projection in switching replay.

## Policy Summary

{md_table(policy, [
    "policy",
    "n_cases",
    "mean_switching_regret",
    "max_switching_regret",
    "best_context_count",
    "mean_selected_objective_score",
    "mean_undershoot_mV",
    "mean_settle_time_us",
    "mean_skip_count",
    "mean_phase_spacing_std_ns",
])}

## Motif Summary

{md_table(motif, [
    "target_label",
    "objective",
    "n_contexts",
    "proxy_win_count",
    "dense_win_count",
    "mean_proxy_minus_dense_score",
    "max_abs_proxy_minus_dense_score",
    "mean_dense_regret",
    "mean_proxy_regret",
    "ranking_preserved_count",
])}

## Context-Level Evidence

{md_table(key_contexts, [
    "target_label",
    "objective",
    "tau_ai_us",
    "dense_slew_us",
    "proxy_slew_us",
    "winner",
    "proxy_minus_dense_score",
    "dense_regret",
    "proxy_regret",
    "dense_skip",
    "proxy_skip",
    "dense_settle_us",
    "proxy_settle_us",
])}

## Interpretation

1. `10A / score_settle010` remains ambiguous.  The `32us` proxy wins at
   `tau_AI=0/0.5/2us`, while the `30us` dense-anchor wins at `1/5us`; the
   mean proxy-minus-dense score is only `{motif.loc[(motif["target_label"]=="10A") & (motif["objective"]=="score_settle010"), "mean_proxy_minus_dense_score"].iloc[0]:.3f}`.
   This is better written as a local near-tie band than as a proxy victory.
2. `20A / base` also does not justify replacing dense-anchor.  The `86us` proxy
   wins at `0/1us`, but the `80us` dense-anchor wins at `0.5/2/5us`.
3. `20A / score_settle005` is the strongest negative result for the proxy.  The
   `66us` candidate occasionally helps, but at `tau_AI=0.5/2/5us` it introduces
   extra skip and longer settling, leading to a large mean proxy-minus-dense
   score of `{motif.loc[(motif["target_label"]=="20A") & (motif["objective"]=="score_settle005"), "mean_proxy_minus_dense_score"].iloc[0]:.3f}`.

## Claim Boundary

The safe conclusion is that R030 challenge replay tightens the safety projection:
dense-anchor is not proven globally optimal, but the current proxy should not be
allowed to override it outside validated local bands.  This remains derived
Simulink evidence, not hardware validation and not neural-network AI-in-loop
verification.
"""
    REPORT.write_text(report, encoding="utf-8")

    paper = f"""## R030 Dense-Anchor Challenge: Switching-Level Recalibration of the Proxy Band

To test whether the R030 dense-anchor projection was overly conservative, a
30-row paired challenge set was executed on the derived delayed-reference
Simulink model.  The set contains three non-priority motifs where offline proxy
selection differed from the dense-anchor point: `10A/score_settle010` (`30us`
versus `32us`), `20A/base` (`80us` versus `86us`), and
`20A/score_settle005` (`30us` versus `66us`), each evaluated at
`tau_AI=0,0.5,1,2,5us`.

After recomputing regret within each complete paired context, dense-anchor
obtained a mean switching regret of `{dense_row["mean_switching_regret"]:.3f}`,
while the deployable proxy obtained `{proxy_row["mean_switching_regret"]:.3f}`.
The proxy was better in `{proxy_wins}/{total}` contexts and dense-anchor in
`{dense_wins}/{total}` contexts.  The most important failure mode occurred in
`20A/score_settle005`, where the `66us` proxy candidate produced extra skip or
longer settling at several delayed-commit contexts; its mean score relative to
the `30us` dense-anchor was worse by `{motif.loc[(motif["target_label"]=="20A") & (motif["objective"]=="score_settle005"), "mean_proxy_minus_dense_score"].iloc[0]:.3f}`.

This result refines rather than overturns the R030 policy.  It does not prove
that dense-anchor is globally optimal, but it shows that the current offline
proxy is not reliable enough to override dense-anchor outside validated local
bands.  Therefore, in the proposed PIS-IEK supervisor, AI or a learned proxy
should be used as a low-rate parameter-scheduling layer with explicit
mode-aware safety projection; it should not replace the IQCOT inner loop or be
reported as hardware-validated AI-in-loop control.
"""
    PAPER.write_text(paper, encoding="utf-8")


def main() -> None:
    rows = recompute_regret(numericize(read_results()))
    policy = policy_summary(rows)
    context = context_summary(rows)
    motif = motif_summary(context)

    rows.to_csv(COMBINED, index=False)
    policy.to_csv(POLICY_SUMMARY, index=False)
    context.to_csv(CONTEXT_SUMMARY, index=False)
    motif.to_csv(MOTIF_SUMMARY, index=False)
    write_svg(policy, motif)
    write_reports(rows, policy, context, motif)

    print(f"Wrote {COMBINED}")
    print(f"Wrote {POLICY_SUMMARY}")
    print(f"Wrote {CONTEXT_SUMMARY}")
    print(f"Wrote {MOTIF_SUMMARY}")
    print(f"Wrote {REPORT}")
    print(f"Wrote {PAPER}")
    print(f"Wrote {SVG}")


if __name__ == "__main__":
    main()
