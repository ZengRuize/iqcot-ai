"""R028 switching-calibrated proxy projection for four-phase IQCOT.

This script does not run Simulink and does not edit any .slx file.  It replays
the completed R027 derived-Simulink priority matrix to calibrate the deployable
`B_epsilon(z, r_hat, tau_AI)` projection that was too optimistic in R026.

Boundaries:
- R028 is a post-processing and validation-design step over completed derived
  Simulink rows, not hardware/HIL validation.
- The posterior and near-optimal rows are comparators; only dense/proxy based
  rows are deployable interfaces.
- The stress-calibrated guarded rule is fitted from the R027 priority contexts
  and must be treated as a candidate for further held-out Simulink validation.
"""

from __future__ import annotations

from pathlib import Path

import pandas as pd


ROOT = Path("E:/Desktop/codex")
OUT = ROOT / "output"
FIG = OUT / "figures"

R027_RESULTS = OUT / "iqcot_r027_proxy_table_in_loop_results_priority_combined.csv"
R027_CONTEXT = OUT / "iqcot_r027_proxy_table_in_loop_context_summary_priority_combined.csv"
R026_POLICY = OUT / "iqcot_deployable_proxy_policy_eval.csv"

POLICY_EVAL = OUT / "iqcot_r028_switching_calibrated_policy_eval_priority.csv"
POLICY_SUMMARY = OUT / "iqcot_r028_switching_calibrated_policy_summary_priority.csv"
FAILURE_ANALYSIS = OUT / "iqcot_r028_context_failure_analysis.csv"
R026_REPLAY = OUT / "iqcot_r028_offline_replay_all_contexts.csv"
REPORT = OUT / "iqcot_r028_switching_calibrated_proxy_report.md"
PAPER = OUT / "iqcot_r028_switching_calibrated_proxy_paper_section.md"
SVG = FIG / "fig36_r028_switching_calibrated_proxy.svg"


CONTEXT_KEYS = ["target_label", "objective", "tau_ai_us"]
R026_CONTEXT_KEYS = ["target_label", "objective", "tau_AI_us"]


def numericize(df: pd.DataFrame) -> pd.DataFrame:
    for col in df.columns:
        if col.endswith("_us") or col.endswith("_A") or col.endswith("_mV") or col.endswith("_ns"):
            df[col] = pd.to_numeric(df[col], errors="coerce")
        elif col in {
            "tau_ai_us",
            "tau_AI_us",
            "delay_events",
            "selected_ref_slew_us",
            "realized_ref_slew_us_in_offline_grid",
            "objective_alpha_settle",
            "objective_score",
            "offline_objective_score",
            "selected_objective_score",
            "switching_regret_priority",
            "offline_regret_vs_oracle",
            "regret_vs_combined_oracle",
            "settle_time_us",
            "skip_count_est",
            "final_phase_spacing_std_ns",
            "phase_std_ns",
            "undershoot_mV",
            "target_load_A",
            "load_drop_A",
            "load_drop_norm",
        }:
            df[col] = pd.to_numeric(df[col], errors="coerce")
    return df


def first_policy(ctx: pd.DataFrame, policy: str) -> pd.Series:
    row = ctx[ctx["policy"] == policy]
    if row.empty:
        raise KeyError(f"Missing policy {policy} in {ctx[CONTEXT_KEYS].iloc[0].to_dict()}")
    return row.iloc[0]


def alpha_from_objective(objective: str) -> float:
    if objective == "score_settle005":
        return 0.05
    if objective == "score_settle010":
        return 0.10
    return 0.0


def choose_dense_anchor(ctx: pd.DataFrame) -> tuple[pd.Series, str, float]:
    """Deployable conservative projection: keep proxy only inside dense band."""
    dense = first_policy(ctx, "discrete_dense_long_table")
    proxy = first_policy(ctx, "calibrated_risk_proxy_projection")
    target = str(dense["target_label"])
    objective = str(dense["objective"])
    tau = float(dense["tau_ai_us"])
    proxy_slew = float(proxy["selected_ref_slew_us"])
    dense_slew = float(dense["selected_ref_slew_us"])

    # R027 failure mode: for 10A/settling-aware 0.05 the old proxy selected a
    # slower 62 us command, increasing settling penalty after switching replay.
    # The conservative deployable rule anchors such high-drop cases to the
    # dense-long table unless proxy stays close to the table action.
    if target == "10A" and objective == "score_settle005":
        band = 0.0
    elif target == "near0A" and objective == "score_settle010":
        band = 5.0
    else:
        band = 10.0 if tau <= 1.0 else 5.0

    if abs(proxy_slew - dense_slew) <= band:
        return proxy, f"proxy kept inside dense anchor band +/-{band:.1f} us", band
    return dense, f"proxy projected to dense-long anchor; |{proxy_slew:.1f}-{dense_slew:.1f}|>{band:.1f} us", band


def choose_guarded(ctx: pd.DataFrame) -> tuple[pd.Series, str, float]:
    """Stress-calibrated candidate rule fitted from R027 priority failures."""
    dense_anchor, anchor_reason, band = choose_dense_anchor(ctx)
    target = str(dense_anchor["target_label"])
    objective = str(dense_anchor["objective"])
    tau = float(dense_anchor["tau_ai_us"])

    # Candidate rule R028-G1: for the 10A settling-aware context, R027 shows that
    # a 2 us supervisory delay makes the shorter near-opt row better than the
    # dense 50 us row. This is deliberately marked as stress-fitted.
    if target == "10A" and objective == "score_settle005" and tau >= 2.0:
        near = first_policy(ctx, "near_opt_band_clipping")
        return near, "stress-fitted delay tightening: use short-slew comparator for tau>=2 us", band

    # Candidate rule R028-G2: for near-zero target load at zero AI delay, the
    # 35 us near-opt row slightly improves the strong settling objective.  Once
    # delay is present, the 30 us dense/proxy row is already best in R027.
    if target == "near0A" and objective == "score_settle010" and tau == 0.0:
        near = first_policy(ctx, "near_opt_band_clipping")
        return near, "stress-fitted zero-delay recovery tightening: 35 us near-opt comparator", band

    return dense_anchor, anchor_reason, band


def policy_rows(results: pd.DataFrame) -> pd.DataFrame:
    rows: list[dict[str, object]] = []
    for key, ctx in results.groupby(CONTEXT_KEYS, sort=False):
        ctx = ctx.copy()
        best_score = float(ctx["selected_objective_score"].min())
        dense = first_policy(ctx, "discrete_dense_long_table")
        proxy = first_policy(ctx, "calibrated_risk_proxy_projection")
        near = first_policy(ctx, "near_opt_band_clipping")
        posterior = first_policy(ctx, "posterior_mode_aware_projection")
        fixed40 = first_policy(ctx, "fixed_40us_precommitted")
        fixed80 = first_policy(ctx, "fixed_80us_precommitted")
        dense_anchor, dense_anchor_reason, dense_anchor_band = choose_dense_anchor(ctx)
        guarded, guarded_reason, guarded_band = choose_guarded(ctx)
        choices = [
            ("discrete_dense_long_table", dense, "deployable baseline table"),
            ("calibrated_risk_proxy_projection", proxy, "R026 proxy before R028 recalibration"),
            ("r028_dense_anchor_proxy", dense_anchor, dense_anchor_reason),
            ("r028_switching_guarded_proxy", guarded, guarded_reason),
            ("near_opt_band_clipping", near, "offline comparator"),
            ("posterior_mode_aware_projection", posterior, "posterior upper-bound comparator"),
            ("fixed_40us_precommitted", fixed40, "fixed baseline"),
            ("fixed_80us_precommitted", fixed80, "fixed baseline"),
        ]
        for policy, selected, reason in choices:
            rows.append(
                {
                    "target_label": key[0],
                    "objective": key[1],
                    "tau_ai_us": key[2],
                    "policy": policy,
                    "source_row_policy": selected["policy"],
                    "selected_ref_slew_us": float(selected["selected_ref_slew_us"]),
                    "selected_objective_score": float(selected["selected_objective_score"]),
                    "switching_regret_priority": float(selected["selected_objective_score"]) - best_score,
                    "settle_time_us": float(selected["settle_time_us"]),
                    "undershoot_mV": float(selected["undershoot_mV"]),
                    "skip_count_est": float(selected["skip_count_est"]),
                    "phase_std_ns": float(selected["final_phase_spacing_std_ns"]),
                    "dense_slew_us": float(dense["selected_ref_slew_us"]),
                    "proxy_slew_us": float(proxy["selected_ref_slew_us"]),
                    "near_opt_slew_us": float(near["selected_ref_slew_us"]),
                    "posterior_slew_us": float(posterior["selected_ref_slew_us"]),
                    "anchor_band_us": dense_anchor_band if policy == "r028_dense_anchor_proxy" else guarded_band,
                    "selection_basis": reason,
                    "online_available_inputs_only": policy
                    in {
                        "discrete_dense_long_table",
                        "calibrated_risk_proxy_projection",
                        "r028_dense_anchor_proxy",
                        "fixed_40us_precommitted",
                        "fixed_80us_precommitted",
                    },
                    "boundary": (
                        "R028 priority switching replay over completed derived Simulink rows; "
                        "guarded rule is stress-fitted and needs held-out validation"
                    ),
                }
            )
    return pd.DataFrame(rows)


def summarize_policy(eval_df: pd.DataFrame) -> pd.DataFrame:
    best = eval_df.loc[
        eval_df.groupby(CONTEXT_KEYS)["selected_objective_score"].idxmin()
    ]
    best_counts = best.groupby("policy").size().rename("best_context_count")
    zero_counts = (
        eval_df[eval_df["switching_regret_priority"].abs() <= 1e-9]
        .groupby("policy")
        .size()
        .rename("zero_regret_context_count")
    )
    out = (
        eval_df.groupby("policy", as_index=False)
        .agg(
            n_cases=("selected_objective_score", "count"),
            mean_switching_regret=("switching_regret_priority", "mean"),
            max_switching_regret=("switching_regret_priority", "max"),
            mean_selected_objective=("selected_objective_score", "mean"),
            mean_settle_time_us=("settle_time_us", "mean"),
            mean_undershoot_mV=("undershoot_mV", "mean"),
            mean_phase_std_ns=("phase_std_ns", "mean"),
            online_available_inputs_only=("online_available_inputs_only", "min"),
        )
        .merge(best_counts, how="left", on="policy")
        .merge(zero_counts, how="left", on="policy")
    )
    out["best_context_count"] = out["best_context_count"].fillna(0).astype(int)
    out["zero_regret_context_count"] = out["zero_regret_context_count"].fillna(0).astype(int)
    return out.sort_values(["mean_switching_regret", "max_switching_regret"]).reset_index(drop=True)


def failure_rows(results: pd.DataFrame, context_summary: pd.DataFrame) -> pd.DataFrame:
    rows: list[dict[str, object]] = []
    for key, ctx in results.groupby(CONTEXT_KEYS, sort=False):
        dense = first_policy(ctx, "discrete_dense_long_table")
        proxy = first_policy(ctx, "calibrated_risk_proxy_projection")
        near = first_policy(ctx, "near_opt_band_clipping")
        posterior = first_policy(ctx, "posterior_mode_aware_projection")
        dense_anchor, anchor_reason, anchor_band = choose_dense_anchor(ctx)
        guarded, guarded_reason, _ = choose_guarded(ctx)
        proxy_minus_dense = float(proxy["selected_objective_score"]) - float(dense["selected_objective_score"])
        rows.append(
            {
                "target_label": key[0],
                "objective": key[1],
                "tau_ai_us": key[2],
                "dense_slew_us": float(dense["selected_ref_slew_us"]),
                "proxy_slew_us": float(proxy["selected_ref_slew_us"]),
                "near_opt_slew_us": float(near["selected_ref_slew_us"]),
                "posterior_slew_us": float(posterior["selected_ref_slew_us"]),
                "proxy_minus_dense_score": proxy_minus_dense,
                "proxy_regret": float(proxy["switching_regret_priority"]),
                "dense_regret": float(dense["switching_regret_priority"]),
                "near_opt_regret": float(near["switching_regret_priority"]),
                "posterior_regret": float(posterior["switching_regret_priority"]),
                "proxy_settle_time_us": float(proxy["settle_time_us"]),
                "dense_settle_time_us": float(dense["settle_time_us"]),
                "near_opt_settle_time_us": float(near["settle_time_us"]),
                "proxy_undershoot_mV": float(proxy["undershoot_mV"]),
                "dense_undershoot_mV": float(dense["undershoot_mV"]),
                "anchor_band_us": anchor_band,
                "dense_anchor_slew_us": float(dense_anchor["selected_ref_slew_us"]),
                "dense_anchor_regret": float(dense_anchor["switching_regret_priority"]),
                "dense_anchor_reason": anchor_reason,
                "guarded_slew_us": float(guarded["selected_ref_slew_us"]),
                "guarded_regret": float(guarded["switching_regret_priority"]),
                "guarded_reason": guarded_reason,
                "diagnosis": diagnose_context(key[0], key[1], float(key[2]), proxy_minus_dense),
            }
        )
    out = pd.DataFrame(rows)
    if not context_summary.empty:
        keep = [
            "target_label",
            "objective",
            "tau_ai_us",
            "switching_best_policy",
            "switching_best_slew_us",
            "ranking_preserved",
        ]
        out = out.merge(context_summary[keep], on=CONTEXT_KEYS, how="left")
    return out


def diagnose_context(target_label: str, objective: str, tau: float, proxy_minus_dense: float) -> str:
    if target_label == "10A" and objective == "score_settle005":
        if tau >= 2.0:
            return "old proxy is too slow and delay-sensitive; short-slew guarded candidate wins in R027"
        return "old proxy is too slow for high-drop settling-aware context; dense anchor removes 62 us failure"
    if target_label == "near0A" and objective == "score_settle010":
        if tau == 0.0:
            return "30 us deployable rows are close, but 35 us comparator slightly improves zero-delay recovery"
        return "30 us dense/proxy rows are already best or tied once supervisory delay is present"
    if proxy_minus_dense > 0:
        return "proxy worse than dense in priority replay"
    if proxy_minus_dense < 0:
        return "proxy better than dense in priority replay"
    return "proxy tied dense in priority replay"


def r026_replay() -> pd.DataFrame:
    if not R026_POLICY.exists():
        return pd.DataFrame()
    df = numericize(pd.read_csv(R026_POLICY))
    rows: list[dict[str, object]] = []
    for key, ctx in df.groupby(R026_CONTEXT_KEYS, sort=False):
        dense = ctx[ctx["policy"] == "discrete_dense_long_table"].iloc[0]
        proxy = ctx[ctx["policy"] == "calibrated_risk_proxy_projection"].iloc[0]
        near = ctx[ctx["policy"] == "near_opt_band_clipping"].iloc[0]
        oracle = ctx[ctx["policy"] == "combined_grid_oracle"].iloc[0]
        target, objective, tau = key
        proxy_slew = float(proxy["selected_ref_slew_us"])
        dense_slew = float(dense["selected_ref_slew_us"])
        if target == "10A" and objective == "score_settle005":
            anchor = dense
        elif abs(proxy_slew - dense_slew) <= 10.0:
            anchor = proxy
        else:
            anchor = dense
        guarded = anchor
        if target == "10A" and objective == "score_settle005" and float(tau) >= 2.0:
            guarded = near
        if target == "near0A" and objective == "score_settle010" and float(tau) == 0.0:
            guarded = near
        for name, row, note in [
            ("combined_grid_oracle", oracle, "offline lower-bound comparator"),
            ("discrete_dense_long_table", dense, "deployable table baseline"),
            ("calibrated_risk_proxy_projection", proxy, "old R026 calibrated proxy"),
            ("r028_dense_anchor_proxy", anchor, "R028 dense-anchor proxy replay on R026 grid"),
            ("r028_switching_guarded_proxy", guarded, "R028 stress-fitted candidate replay on R026 grid"),
            ("near_opt_band_clipping", near, "offline comparator"),
        ]:
            rows.append(
                {
                    "target_label": target,
                    "objective": objective,
                    "tau_AI_us": tau,
                    "policy": name,
                    "source_policy": row["policy"],
                    "selected_ref_slew_us": float(row["selected_ref_slew_us"]),
                    "objective_score": float(row["objective_score"]),
                    "regret_vs_combined_oracle": float(row["objective_score"])
                    - float(oracle["objective_score"]),
                    "selection_basis": note,
                    "boundary": "offline R026 grid replay only; not switching re-simulation",
                }
            )
    return pd.DataFrame(rows)


def md_table(df: pd.DataFrame, cols: list[str]) -> str:
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


def write_svg(summary: pd.DataFrame) -> None:
    FIG.mkdir(parents=True, exist_ok=True)
    show = summary[
        summary["policy"].isin(
            [
                "discrete_dense_long_table",
                "calibrated_risk_proxy_projection",
                "r028_dense_anchor_proxy",
                "r028_switching_guarded_proxy",
                "near_opt_band_clipping",
                "fixed_40us_precommitted",
                "fixed_80us_precommitted",
            ]
        )
    ].copy()
    order = [
        "r028_switching_guarded_proxy",
        "discrete_dense_long_table",
        "r028_dense_anchor_proxy",
        "near_opt_band_clipping",
        "calibrated_risk_proxy_projection",
        "fixed_40us_precommitted",
        "fixed_80us_precommitted",
    ]
    show["order"] = show["policy"].map({p: i for i, p in enumerate(order)})
    show = show.sort_values("order")

    width, height = 1040, 430
    margin_l, margin_b, margin_t = 120, 100, 42
    plot_w, plot_h = width - margin_l - 42, height - margin_t - margin_b
    max_v = max(0.05, show["mean_switching_regret"].max() * 1.15)
    step = plot_w / max(len(show), 1)
    bar_w = step * 0.55
    colors = {
        "r028_switching_guarded_proxy": "#2CA02C",
        "r028_dense_anchor_proxy": "#17BECF",
        "discrete_dense_long_table": "#4C78A8",
        "calibrated_risk_proxy_projection": "#E45756",
        "near_opt_band_clipping": "#F58518",
        "fixed_40us_precommitted": "#54A24B",
        "fixed_80us_precommitted": "#B279A2",
    }
    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        '<rect width="100%" height="100%" fill="white"/>',
        '<text x="520" y="25" text-anchor="middle" font-family="Arial" font-size="17">R028 switching-calibrated proxy replay</text>',
        f'<line x1="{margin_l}" y1="{height-margin_b}" x2="{width-42}" y2="{height-margin_b}" stroke="#333"/>',
        f'<line x1="{margin_l}" y1="{margin_t}" x2="{margin_l}" y2="{height-margin_b}" stroke="#333"/>',
    ]
    for tick in [0, 0.25, 0.5, 0.75, 1.0]:
        y = height - margin_b - tick * plot_h
        v = tick * max_v
        parts.append(f'<line x1="{margin_l-5}" y1="{y:.1f}" x2="{width-42}" y2="{y:.1f}" stroke="#eee"/>')
        parts.append(
            f'<text x="{margin_l-10}" y="{y+4:.1f}" text-anchor="end" font-family="Arial" font-size="11">{v:.2f}</text>'
        )
    for i, row in show.reset_index(drop=True).iterrows():
        x = margin_l + i * step + (step - bar_w) / 2
        h = row["mean_switching_regret"] / max_v * plot_h
        y = height - margin_b - h
        p = row["policy"]
        parts.append(
            f'<rect x="{x:.1f}" y="{y:.1f}" width="{bar_w:.1f}" height="{h:.1f}" fill="{colors.get(p, "#888")}"/>'
        )
        parts.append(
            f'<text x="{x+bar_w/2:.1f}" y="{y-5:.1f}" text-anchor="middle" font-family="Arial" font-size="11">{row["mean_switching_regret"]:.3f}</text>'
        )
        label = p.replace("_", " ")
        parts.append(
            f'<text x="{x+bar_w/2:.1f}" y="{height-margin_b+18}" text-anchor="end" transform="rotate(-35 {x+bar_w/2:.1f},{height-margin_b+18})" font-family="Arial" font-size="11">{label}</text>'
        )
    parts.append(
        f'<text x="28" y="{margin_t+plot_h/2}" text-anchor="middle" transform="rotate(-90 28,{margin_t+plot_h/2})" font-family="Arial" font-size="13">Mean switching regret</text>'
    )
    parts.append("</svg>")
    SVG.write_text("\n".join(parts), encoding="utf-8")


def write_reports(
    eval_df: pd.DataFrame,
    summary: pd.DataFrame,
    failure: pd.DataFrame,
    offline: pd.DataFrame,
) -> None:
    dense_anchor = summary[summary["policy"] == "r028_dense_anchor_proxy"].iloc[0]
    guarded = summary[summary["policy"] == "r028_switching_guarded_proxy"].iloc[0]
    old_proxy = summary[summary["policy"] == "calibrated_risk_proxy_projection"].iloc[0]
    dense = summary[summary["policy"] == "discrete_dense_long_table"].iloc[0]
    near = summary[summary["policy"] == "near_opt_band_clipping"].iloc[0]

    offline_summary = pd.DataFrame()
    if not offline.empty:
        offline_summary = (
            offline.groupby("policy", as_index=False)
            .agg(
                n_cases=("objective_score", "count"),
                mean_offline_regret=("regret_vs_combined_oracle", "mean"),
                max_offline_regret=("regret_vs_combined_oracle", "max"),
            )
            .sort_values("mean_offline_regret")
        )

    report = [
        "# R028 switching-calibrated proxy projection",
        "",
        "## Scope",
        "",
        "R028 reuses the completed R027 priority derived-Simulink matrix to recalibrate the deployable risk-proxy projection.  No original `.slx` file is modified, no `.slx` XML is edited, and no hardware/HIL claim is made.",
        "",
        "## What Failed In R027",
        "",
        "- In `10A / score_settle005`, the old calibrated proxy repeatedly selected `62 us`; the switching replay favored the dense-long `50 us` row for `tau_AI=0/0.5/1 us`, and a short `34 us` comparator at `tau_AI=2 us`.",
        "- In `near0A / score_settle010`, the old proxy and dense table selected `30 us`, which tied for best once delay was present; at zero delay the `35 us` comparator was slightly better.",
        "- Therefore the R026 proxy is useful as an interface, but its safety band was not calibrated to switching-level delay stress.",
        "",
        "## R028 Policies",
        "",
        "- `r028_dense_anchor_proxy`: deployable conservative rule.  It keeps the proxy only when it stays inside a context-dependent dense-table band, otherwise it projects back to the dense-long table action.",
        "- `r028_switching_guarded_proxy`: stress-calibrated candidate.  It starts from the dense-anchor rule and adds two R027-fitted guards: use the short `34 us` comparator for `10A/score_settle005/tau>=2 us`, and use `35 us` for `near0A/score_settle010/tau=0 us`.  This row is a candidate for held-out validation, not a final deployable proof.",
        "",
        "## Priority Switching Replay Summary",
        "",
        md_table(
            summary,
            [
                "policy",
                "n_cases",
                "mean_switching_regret",
                "max_switching_regret",
                "mean_settle_time_us",
                "best_context_count",
                "zero_regret_context_count",
            ],
        ),
        "",
        "Key numeric outcome:",
        "",
        f"- Old calibrated proxy mean switching regret: `{old_proxy['mean_switching_regret']:.3f}`.",
        f"- Dense-long table mean switching regret: `{dense['mean_switching_regret']:.3f}`.",
        f"- R028 dense-anchor proxy mean switching regret: `{dense_anchor['mean_switching_regret']:.3f}`.",
        f"- R028 guarded candidate mean switching regret: `{guarded['mean_switching_regret']:.3f}`.",
        f"- Near-opt comparator mean switching regret: `{near['mean_switching_regret']:.3f}`.",
        "",
        "The conservative dense-anchor rule removes the `62 us` proxy failure and ties the dense-long table on this priority replay.  The guarded candidate attains zero regret on the same priority contexts because it is calibrated from those contexts; it must therefore be treated as a hypothesis for R029 held-out simulation, not as independent proof.",
        "",
        "## Failure And Guard Table",
        "",
        md_table(
            failure[
                [
                    "target_label",
                    "objective",
                    "tau_ai_us",
                    "dense_slew_us",
                    "proxy_slew_us",
                    "dense_anchor_slew_us",
                    "guarded_slew_us",
                    "proxy_regret",
                    "dense_anchor_regret",
                    "guarded_regret",
                ]
            ],
            [
                "target_label",
                "objective",
                "tau_ai_us",
                "dense_slew_us",
                "proxy_slew_us",
                "dense_anchor_slew_us",
                "guarded_slew_us",
                "proxy_regret",
                "dense_anchor_regret",
                "guarded_regret",
            ],
        ),
        "",
        "## Offline R026 Replay Check",
        "",
    ]
    if not offline_summary.empty:
        report += [
            md_table(
                offline_summary,
                ["policy", "n_cases", "mean_offline_regret", "max_offline_regret"],
            ),
            "",
            "The offline replay is included only as a consistency check over the R026 grid.  It is not a substitute for switching-level re-simulation because R027 already showed that offline ranking can fail under delayed-reference replay.",
            "",
        ]
    report += [
        "## Boundary",
        "",
        "- AI remains a supervisory scheduler of `T_slew` or related parameters and does not replace the IQCOT inner loop.",
        "- R028 does not prove a global optimum for `T_slew`.",
        "- R028 does not prove hardware performance, neural-network AI-in-loop superiority, or exact first-peak prediction by PIS-IEK.",
        "- The guarded candidate is intentionally conservative in claims: it converts R027 failure evidence into a next validation design.",
        "",
    ]
    REPORT.write_text("\n".join(report), encoding="utf-8")

    paper = [
        "### R028 开关级校准的 proxy 安全投影",
        "",
        "R027 表明，R026 离线 `r_hat(z,T_slew)` proxy 的平均优势不能直接迁移到派生 Simulink 的延迟参考通道中。尤其在 `10A/score_settle005` 压力上下文中，旧 proxy 选择 `62 us`，使切载后的恢复时间惩罚增大；dense-long 表的 `50 us` 在 `tau_AI=0/0.5/1 us` 更稳，而 `tau_AI=2 us` 下较短斜率比较器更优。基于这一负面边界，本文将 `B_epsilon(z,r_hat,tau_AI)` 改写为开关级校准的安全投影：当 proxy 偏离 dense-long 基准超过上下文带宽时，回退到 dense-long 表；同时保留一个仅用于下一轮验证的延迟防护候选。",
        "",
        f"在 R027 优先压力矩阵的回放中，旧 proxy 的 mean switching regret 为 `{old_proxy['mean_switching_regret']:.3f}`，dense-long 表为 `{dense['mean_switching_regret']:.3f}`。R028 的保守 dense-anchor proxy 将 regret 降至 `{dense_anchor['mean_switching_regret']:.3f}`，与 dense-long 表并列；stress-calibrated guarded candidate 在同一压力集合上为 `{guarded['mean_switching_regret']:.3f}`，但由于该规则由 R027 压力点校准得到，只能作为 R029 held-out 派生仿真的候选策略，不能写成独立泛化结论。",
        "",
        "这一结果的价值不在于宣称 proxy 已优于查表，而在于把 PIS-IEK 小信号/事件域模型中的 `tau_AI`、目标函数权重和 skip/settling 风险转化为可部署的监督层安全接口：AI 或表驱动监督器可以先给出候选 `T_slew`，再经过 `B_epsilon` 投影，避免在开关级压力场景中选择明显过慢的参考斜率。",
        "",
    ]
    PAPER.write_text("\n".join(paper), encoding="utf-8")


def main() -> None:
    results = numericize(pd.read_csv(R027_RESULTS))
    context = numericize(pd.read_csv(R027_CONTEXT)) if R027_CONTEXT.exists() else pd.DataFrame()
    eval_df = policy_rows(results)
    summary = summarize_policy(eval_df)
    failure = failure_rows(results, context)
    offline = r026_replay()

    eval_df.to_csv(POLICY_EVAL, index=False, encoding="utf-8-sig")
    summary.to_csv(POLICY_SUMMARY, index=False, encoding="utf-8-sig")
    failure.to_csv(FAILURE_ANALYSIS, index=False, encoding="utf-8-sig")
    if not offline.empty:
        offline.to_csv(R026_REPLAY, index=False, encoding="utf-8-sig")
    write_svg(summary)
    write_reports(eval_df, summary, failure, offline)


if __name__ == "__main__":
    main()
