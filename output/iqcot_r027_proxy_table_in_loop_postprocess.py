"""Post-process R027 priority table-in-loop switching chunks.

The script combines chunked derived-Simulink results from
iqcot_r027_proxy_table_in_loop_validation.m and recomputes regret over the
complete R027 priority matrix. It intentionally keeps R027 claims narrow:
priority switching replay is not hardware validation and does not prove a
global T_slew optimum.
"""

from __future__ import annotations

from pathlib import Path

import pandas as pd


ROOT = Path("E:/Desktop/codex")
OUT = ROOT / "output"
FIG = OUT / "figures"

PRIORITY_PLAN = OUT / "iqcot_r027_proxy_table_in_loop_priority_plan.csv"
COMBINED_RESULTS = OUT / "iqcot_r027_proxy_table_in_loop_results_priority_combined.csv"
POLICY_SUMMARY = OUT / "iqcot_r027_proxy_table_in_loop_policy_eval_priority_combined.csv"
CONTEXT_SUMMARY = OUT / "iqcot_r027_proxy_table_in_loop_context_summary_priority_combined.csv"
PROXY_DENSE = OUT / "iqcot_r027_proxy_vs_dense_priority_combined.csv"
REPORT = OUT / "iqcot_r027_proxy_table_in_loop_combined_report.md"
PAPER = OUT / "iqcot_r027_proxy_table_in_loop_combined_paper_section.md"
SVG = FIG / "fig35_r027_priority_combined_regret.svg"


POLICY_ORDER = [
    "discrete_dense_long_table",
    "calibrated_risk_proxy_projection",
    "near_opt_band_clipping",
    "posterior_mode_aware_projection",
    "fixed_40us_precommitted",
    "fixed_80us_precommitted",
]


def chunk_files() -> list[Path]:
    files = [
        OUT / "iqcot_r027_proxy_table_in_loop_results_priority.csv",
        *sorted(OUT.glob("iqcot_r027_proxy_table_in_loop_results_priority_rows*.csv")),
    ]
    return [f for f in files if f.exists() and "combined" not in f.name]


def read_results() -> pd.DataFrame:
    frames = []
    for idx, path in enumerate(chunk_files()):
        df = pd.read_csv(path)
        df["chunk_file"] = path.name
        df["chunk_order"] = idx
        frames.append(df)
    if not frames:
        raise FileNotFoundError("No R027 priority switching result chunks found.")
    all_rows = pd.concat(frames, ignore_index=True)
    all_rows = all_rows.sort_values(["r027_case_id", "chunk_order"]).drop_duplicates(
        "r027_case_id", keep="last"
    )
    return all_rows


def numericize(df: pd.DataFrame) -> pd.DataFrame:
    for col in df.columns:
        if col in {
            "success",
            "online_available_inputs_only",
        }:
            continue
        if col.endswith("_us") or col.endswith("_A") or col.endswith("_mV") or col.endswith("_ns"):
            df[col] = pd.to_numeric(df[col], errors="coerce")
        elif col in {
            "tau_ai_us",
            "delay_events",
            "selected_ref_slew_us",
            "realized_ref_slew_us_in_offline_grid",
            "objective_alpha_settle",
            "offline_objective_score",
            "offline_regret_vs_oracle",
            "selected_objective_score",
            "base_score",
            "score_settle005",
            "score_settle010",
            "settle_time_us",
            "skip_count_est",
            "final_phase_spacing_std_ns",
            "undershoot_mV",
        }:
            df[col] = pd.to_numeric(df[col], errors="coerce")
    return df


def recompute_regret(rows: pd.DataFrame) -> pd.DataFrame:
    keys = ["target_label", "objective", "tau_ai_us"]
    rows["switching_regret_priority"] = rows.groupby(keys)["selected_objective_score"].transform(
        lambda s: s - s.min()
    )
    rows["offline_regret_within_priority"] = rows.groupby(keys)["offline_objective_score"].transform(
        lambda s: s - s.min()
    )
    return rows


def summarize_policy(rows: pd.DataFrame) -> pd.DataFrame:
    valid = rows[rows["success"].astype(str).isin(["1", "True", "true"]) | (rows["success"] == 1)].copy()
    best = valid.loc[
        valid.groupby(["target_label", "objective", "tau_ai_us"])["selected_objective_score"].idxmin()
    ]
    best_counts = best.groupby("policy").size().rename("best_context_count")
    zero_counts = (
        valid[valid["switching_regret_priority"].abs() <= 1e-9]
        .groupby("policy")
        .size()
        .rename("zero_regret_context_count")
    )
    summary = (
        valid.groupby("policy", as_index=False)
        .agg(
            n_cases=("r027_case_id", "count"),
            mean_switching_regret=("switching_regret_priority", "mean"),
            max_switching_regret=("switching_regret_priority", "max"),
            mean_selected_objective=("selected_objective_score", "mean"),
            mean_offline_regret=("offline_regret_within_priority", "mean"),
            mean_undershoot_mV=("undershoot_mV", "mean"),
            mean_settle_time_us=("settle_time_us", "mean"),
            mean_skip=("skip_count_est", "mean"),
            mean_phase_std_ns=("final_phase_spacing_std_ns", "mean"),
            online_available_inputs_only=("online_available_inputs_only", "first"),
        )
        .merge(best_counts, how="left", on="policy")
        .merge(zero_counts, how="left", on="policy")
    )
    summary["best_context_count"] = summary["best_context_count"].fillna(0).astype(int)
    summary["zero_regret_context_count"] = summary["zero_regret_context_count"].fillna(0).astype(int)
    summary["policy"] = pd.Categorical(summary["policy"], POLICY_ORDER, ordered=True)
    summary = summary.sort_values(["mean_switching_regret", "policy"]).reset_index(drop=True)
    summary["policy"] = summary["policy"].astype(str)
    return summary


def summarize_context(rows: pd.DataFrame) -> pd.DataFrame:
    out = []
    keys = ["target_label", "objective", "tau_ai_us"]
    for key, ctx in rows.groupby(keys, sort=False):
        sw = ctx.sort_values(["selected_objective_score", "policy"]).iloc[0]
        off = ctx.sort_values(["offline_objective_score", "policy"]).iloc[0]
        proxy = ctx[ctx["policy"] == "calibrated_risk_proxy_projection"].iloc[0]
        dense = ctx[ctx["policy"] == "discrete_dense_long_table"].iloc[0]
        near = ctx[ctx["policy"] == "near_opt_band_clipping"].iloc[0]
        posterior = ctx[ctx["policy"] == "posterior_mode_aware_projection"].iloc[0]
        out.append(
            {
                "target_label": key[0],
                "objective": key[1],
                "tau_ai_us": key[2],
                "switching_best_policy": sw["policy"],
                "switching_best_slew_us": sw["selected_ref_slew_us"],
                "switching_best_score": sw["selected_objective_score"],
                "offline_best_policy_within_priority": off["policy"],
                "offline_best_slew_us": off["selected_ref_slew_us"],
                "offline_best_score_within_priority": off["offline_objective_score"],
                "ranking_preserved": sw["policy"] == off["policy"],
                "proxy_score": proxy["selected_objective_score"],
                "dense_score": dense["selected_objective_score"],
                "near_opt_score": near["selected_objective_score"],
                "posterior_score": posterior["selected_objective_score"],
                "proxy_regret": proxy["switching_regret_priority"],
                "dense_regret": dense["switching_regret_priority"],
                "near_opt_regret": near["switching_regret_priority"],
                "posterior_regret": posterior["switching_regret_priority"],
                "proxy_minus_dense_score": proxy["selected_objective_score"]
                - dense["selected_objective_score"],
            }
        )
    return pd.DataFrame(out)


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


def write_svg(policy: pd.DataFrame) -> None:
    FIG.mkdir(parents=True, exist_ok=True)
    width, height = 980, 420
    margin_l, margin_b, margin_t = 120, 90, 40
    plot_w, plot_h = width - margin_l - 40, height - margin_t - margin_b
    max_v = max(0.05, policy["mean_switching_regret"].max() * 1.15)
    bar_w = plot_w / max(len(policy), 1) * 0.55
    step = plot_w / max(len(policy), 1)
    colors = {
        "discrete_dense_long_table": "#4C78A8",
        "posterior_mode_aware_projection": "#72B7B2",
        "near_opt_band_clipping": "#F58518",
        "calibrated_risk_proxy_projection": "#E45756",
        "fixed_40us_precommitted": "#54A24B",
        "fixed_80us_precommitted": "#B279A2",
    }
    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        '<rect width="100%" height="100%" fill="white"/>',
        '<text x="490" y="24" text-anchor="middle" font-family="Arial" font-size="17">R027 priority combined switching regret</text>',
        f'<line x1="{margin_l}" y1="{height-margin_b}" x2="{width-40}" y2="{height-margin_b}" stroke="#333"/>',
        f'<line x1="{margin_l}" y1="{margin_t}" x2="{margin_l}" y2="{height-margin_b}" stroke="#333"/>',
    ]
    for tick in [0, 0.25, 0.5, 0.75, 1.0]:
        y = height - margin_b - tick * plot_h
        v = tick * max_v
        parts.append(f'<line x1="{margin_l-5}" y1="{y:.1f}" x2="{width-40}" y2="{y:.1f}" stroke="#eee"/>')
        parts.append(
            f'<text x="{margin_l-10}" y="{y+4:.1f}" text-anchor="end" font-family="Arial" font-size="11">{v:.2f}</text>'
        )
    for i, row in policy.reset_index(drop=True).iterrows():
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
        f'<text x="26" y="{margin_t+plot_h/2}" text-anchor="middle" transform="rotate(-90 26,{margin_t+plot_h/2})" font-family="Arial" font-size="13">Mean switching regret</text>'
    )
    parts.append("</svg>")
    SVG.write_text("\n".join(parts), encoding="utf-8")


def write_reports(rows: pd.DataFrame, policy: pd.DataFrame, context: pd.DataFrame) -> None:
    plan = pd.read_csv(PRIORITY_PLAN)
    missing = sorted(set(plan["r027_case_id"]) - set(rows["r027_case_id"]))
    proxy_dense = context[["target_label", "objective", "tau_ai_us", "proxy_minus_dense_score", "proxy_regret", "dense_regret"]].copy()
    proxy_better = int((proxy_dense["proxy_minus_dense_score"] < -1e-9).sum())
    proxy_equal = int((proxy_dense["proxy_minus_dense_score"].abs() <= 1e-9).sum())
    proxy_worse = int((proxy_dense["proxy_minus_dense_score"] > 1e-9).sum())
    preserved = int(context["ranking_preserved"].sum())

    report = [
        "# R027 priority table-in-loop combined switching report",
        "",
        "## Scope",
        "",
        "This report combines all completed chunks of the R027 priority matrix. It uses only the derived Simulink model and delayed `Iph_ref_ts` profiles. It is not hardware/HIL validation and does not prove a global `T_slew` optimum.",
        "",
        "## Coverage",
        "",
        f"- Priority plan rows: `{len(plan)}`.",
        f"- Combined switching rows: `{len(rows)}`.",
        f"- Unique cases: `{rows['r027_case_id'].nunique()}`.",
        f"- Successful cases: `{int(pd.to_numeric(rows['success']).sum())}`.",
        f"- Missing priority cases: `{len(missing)}`.",
        "",
        "## Policy Summary",
        "",
        md_table(
            policy,
            [
                "policy",
                "n_cases",
                "mean_switching_regret",
                "max_switching_regret",
                "mean_selected_objective",
                "best_context_count",
                "zero_regret_context_count",
                "mean_settle_time_us",
            ],
        ),
        "",
        "## Context Summary",
        "",
        md_table(
            context,
            [
                "target_label",
                "objective",
                "tau_ai_us",
                "switching_best_policy",
                "switching_best_slew_us",
                "offline_best_policy_within_priority",
                "ranking_preserved",
                "proxy_regret",
                "dense_regret",
            ],
        ),
        "",
        "## Proxy vs Dense-Long",
        "",
        f"- Proxy better than dense-long in `{proxy_better}` / `{len(proxy_dense)}` priority contexts.",
        f"- Proxy tied dense-long in `{proxy_equal}` / `{len(proxy_dense)}` contexts.",
        f"- Proxy worse than dense-long in `{proxy_worse}` / `{len(proxy_dense)}` contexts.",
        f"- Offline best policy within the priority subset was preserved in `{preserved}` / `{len(context)}` contexts.",
        "",
        "Key interpretation: the R026 offline average advantage of calibrated risk proxy does not survive this stress-selected R027 priority switching replay. Dense-long table and posterior rows have the lowest mean switching regret, while calibrated proxy is useful as an interface but requires re-calibration of the safety projection before stronger AI claims.",
        "",
        "## Boundary",
        "",
        "- AI remains a supervisory parameter scheduler and does not replace IQCOT inner loop.",
        "- Posterior mode-aware projection is an upper-bound comparator, not deployable AI.",
        "- Near-opt band is an offline comparator, not a hardware safety set.",
        "- This priority replay is derived Simulink evidence, not hardware validation.",
    ]
    REPORT.write_text("\n".join(report) + "\n", encoding="utf-8")

    paper = [
        "### R027 优先矩阵开关级重放结果",
        "",
        f"R027 已完成优先矩阵全部 `{len(rows)}` 个派生 Simulink 工况。该优先矩阵不是完整 `315` 行均匀验证，而是故意挑选排序分歧和 proxy regret 较高的压力上下文，因此更适合检验 R026 proxy 的边界。",
        "",
        f"合并后，dense-long table 与 posterior mode-aware projection 的 mean switching regret 均为 `{policy.loc[policy['policy']=='discrete_dense_long_table','mean_switching_regret'].iloc[0]:.3f}`，calibrated risk proxy 为 `{policy.loc[policy['policy']=='calibrated_risk_proxy_projection','mean_switching_regret'].iloc[0]:.3f}`，near-opt band 为 `{policy.loc[policy['policy']=='near_opt_band_clipping','mean_switching_regret'].iloc[0]:.3f}`。proxy 在 `{proxy_better}` 个上下文优于 dense-long，在 `{proxy_equal}` 个上下文并列，在 `{proxy_worse}` 个上下文更差。",
        "",
        "这个结果修正了 R026 的离线乐观结论：`r_hat` proxy 可以作为可执行监督层接口进入派生模型，但当前校准方式在压力上下文中没有稳定超过 dense-long table。论文中应将 R027 写成“完成 proxy 接口开关级压力检验，并暴露需要重标定的安全投影边界”，而不是“proxy 已证明优于查表”。",
    ]
    PAPER.write_text("\n".join(paper) + "\n", encoding="utf-8")
    proxy_dense.to_csv(PROXY_DENSE, index=False)


def main() -> None:
    rows = numericize(read_results())
    rows = recompute_regret(rows)
    plan = pd.read_csv(PRIORITY_PLAN)
    order = plan[["r027_case_id"]].copy()
    order["priority_row"] = range(1, len(order) + 1)
    rows = rows.merge(order, on="r027_case_id", how="left").sort_values("priority_row")
    policy = summarize_policy(rows)
    context = summarize_context(rows)

    rows.to_csv(COMBINED_RESULTS, index=False)
    policy.to_csv(POLICY_SUMMARY, index=False)
    context.to_csv(CONTEXT_SUMMARY, index=False)
    write_svg(policy)
    write_reports(rows, policy, context)

    print(f"R027_COMBINED_RESULTS={COMBINED_RESULTS}")
    print(f"R027_POLICY_SUMMARY={POLICY_SUMMARY}")
    print(f"R027_CONTEXT_SUMMARY={CONTEXT_SUMMARY}")
    print(f"R027_REPORT={REPORT}")
    print(f"R027_FIGURE={SVG}")


if __name__ == "__main__":
    main()
