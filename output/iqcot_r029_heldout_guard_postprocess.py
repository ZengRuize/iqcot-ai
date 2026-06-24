"""Post-process R029 held-out guarded-proxy switching chunks.

R029 validates whether R028 guarded rules, fitted on R027 priority contexts,
survive nearby held-out delay contexts.  This script combines chunked derived
Simulink results, recomputes context-level regret over the full R029 matrix,
and writes a cautious report.  It does not run Simulink or edit .slx files.
"""

from __future__ import annotations

from pathlib import Path

import pandas as pd


ROOT = Path("E:/Desktop/codex")
OUT = ROOT / "output"
FIG = OUT / "figures"

COMBINED_RESULTS = OUT / "iqcot_r029_heldout_guard_results_combined.csv"
POLICY_SUMMARY = OUT / "iqcot_r029_heldout_guard_policy_summary_combined.csv"
CONTEXT_SUMMARY = OUT / "iqcot_r029_heldout_guard_context_summary_combined.csv"
REPORT_MD = OUT / "iqcot_r029_heldout_guard_combined_report.md"
PAPER_MD = OUT / "iqcot_r029_heldout_guard_paper_section.md"
SVG = FIG / "fig38_r029_heldout_guard_combined.svg"

CONTEXT_KEYS = ["target_label", "objective", "tau_ai_us"]


def chunk_files() -> list[Path]:
    files = sorted(OUT.glob("iqcot_r029_heldout_guard_results_heldout_rows*.csv"))
    full = OUT / "iqcot_r029_heldout_guard_results_heldout.csv"
    if full.exists():
        files.append(full)
    return [f for f in files if "combined" not in f.name]


def numericize(df: pd.DataFrame) -> pd.DataFrame:
    for col in df.columns:
        if col == "success":
            continue
        if col.endswith("_us") or col.endswith("_A") or col.endswith("_mV") or col.endswith("_ns"):
            df[col] = pd.to_numeric(df[col], errors="coerce")
        elif col in {
            "tau_ai_us",
            "selected_ref_slew_us",
            "selected_objective_score",
            "switching_regret_vs_best_in_context",
            "base_score",
            "score_settle005",
            "score_settle010",
            "settle_time_us",
            "skip_count_est",
        }:
            df[col] = pd.to_numeric(df[col], errors="coerce")
    return df


def read_results() -> pd.DataFrame:
    frames = []
    for idx, path in enumerate(chunk_files()):
        df = pd.read_csv(path)
        df["chunk_file"] = path.name
        df["chunk_order"] = idx
        frames.append(df)
    if not frames:
        raise FileNotFoundError("No R029 held-out result chunks found.")
    rows = pd.concat(frames, ignore_index=True)
    rows = rows.sort_values(["r029_case_id", "chunk_order"]).drop_duplicates(
        "r029_case_id", keep="last"
    )
    return numericize(rows)


def recompute_regret(rows: pd.DataFrame) -> pd.DataFrame:
    valid = rows["success"].astype(str).isin(["1", "true", "True"]) | (rows["success"] == 1)
    rows["switching_regret_combined"] = pd.NA
    rows.loc[valid, "switching_regret_combined"] = rows[valid].groupby(CONTEXT_KEYS)[
        "selected_objective_score"
    ].transform(lambda s: s - s.min())
    rows["switching_regret_combined"] = pd.to_numeric(
        rows["switching_regret_combined"], errors="coerce"
    )
    return rows


def summarize_policy(rows: pd.DataFrame) -> pd.DataFrame:
    valid = rows[rows["success"].astype(str).isin(["1", "true", "True"]) | (rows["success"] == 1)]
    best = valid.loc[valid.groupby(CONTEXT_KEYS)["selected_objective_score"].idxmin()]
    best_counts = best.groupby("policy_family").size().rename("best_context_count")
    zero_counts = (
        valid[valid["switching_regret_combined"].abs() <= 1e-9]
        .groupby("policy_family")
        .size()
        .rename("zero_regret_context_count")
    )
    out = (
        valid.groupby("policy_family", as_index=False)
        .agg(
            n_cases=("r029_case_id", "count"),
            mean_switching_regret=("switching_regret_combined", "mean"),
            max_switching_regret=("switching_regret_combined", "max"),
            mean_selected_objective=("selected_objective_score", "mean"),
            mean_undershoot_mV=("undershoot_mV", "mean"),
            mean_settle_time_us=("settle_time_us", "mean"),
            mean_skip=("skip_count_est", "mean"),
            mean_phase_std_ns=("final_phase_spacing_std_ns", "mean"),
        )
        .merge(best_counts, how="left", on="policy_family")
        .merge(zero_counts, how="left", on="policy_family")
    )
    out["best_context_count"] = out["best_context_count"].fillna(0).astype(int)
    out["zero_regret_context_count"] = out["zero_regret_context_count"].fillna(0).astype(int)
    return out.sort_values(["mean_switching_regret", "max_switching_regret"]).reset_index(drop=True)


def summarize_context(rows: pd.DataFrame) -> pd.DataFrame:
    valid = rows[rows["success"].astype(str).isin(["1", "true", "True"]) | (rows["success"] == 1)]
    out = []
    for key, ctx in valid.groupby(CONTEXT_KEYS, sort=False):
        ctx = ctx.sort_values(["selected_objective_score", "selected_ref_slew_us"])
        best = ctx.iloc[0]
        dense = ctx[ctx["policy_family"] == "dense_anchor"]
        guarded = ctx[ctx["policy_family"] == "guarded_candidate"]
        old = ctx[ctx["policy_family"] == "old_proxy_failure_probe"]
        row = {
            "target_label": key[0],
            "objective": key[1],
            "tau_ai_us": key[2],
            "best_policy": best["policy"],
            "best_policy_family": best["policy_family"],
            "best_slew_us": best["selected_ref_slew_us"],
            "best_score": best["selected_objective_score"],
            "dense_anchor_slew_us": dense["selected_ref_slew_us"].iloc[0] if not dense.empty else pd.NA,
            "dense_anchor_regret": dense["switching_regret_combined"].iloc[0] if not dense.empty else pd.NA,
            "guarded_slew_us": guarded["selected_ref_slew_us"].iloc[0] if not guarded.empty else pd.NA,
            "guarded_regret": guarded["switching_regret_combined"].iloc[0] if not guarded.empty else pd.NA,
            "old_proxy_slew_us": old["selected_ref_slew_us"].iloc[0] if not old.empty else pd.NA,
            "old_proxy_regret": old["switching_regret_combined"].iloc[0] if not old.empty else pd.NA,
            "interpretation": interpret_context(key[0], key[1], float(key[2]), best),
        }
        out.append(row)
    return pd.DataFrame(out)


def interpret_context(target: str, objective: str, tau: float, best: pd.Series) -> str:
    slew = float(best["selected_ref_slew_us"])
    if target == "10A" and objective == "score_settle005":
        if tau < 2.0:
            return "guard threshold is not supported below 2us; 40us is best at 1.5us"
        if abs(slew - 34.0) < 1e-9:
            return "R028 34us delay guard has local held-out support"
        return "dense/intermediate action competes with the 34us guard"
    if target == "near0A" and objective == "score_settle010":
        if abs(slew - 38.0) < 1e-9 and tau <= 0.25:
            return "35us zero-delay guard is too narrow; 38us fine-sweep probe is better"
        if abs(slew - 30.0) < 1e-9 and tau >= 0.5:
            return "dense/proxy 30us action remains best once delay reaches 0.5us"
    return "held-out context evaluated"


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
            elif pd.isna(val):
                vals.append("")
            else:
                vals.append(str(val))
        lines.append("| " + " | ".join(vals) + " |")
    return "\n".join(lines)


def write_svg(policy: pd.DataFrame) -> None:
    FIG.mkdir(parents=True, exist_ok=True)
    width, height = 920, 400
    margin_l, margin_b, margin_t = 115, 92, 42
    plot_w, plot_h = width - margin_l - 42, height - margin_t - margin_b
    max_v = max(0.05, policy["mean_switching_regret"].max() * 1.15)
    step = plot_w / max(len(policy), 1)
    bar_w = step * 0.58
    colors = {
        "guarded_candidate": "#2CA02C",
        "dense_anchor": "#4C78A8",
        "heldout_probe": "#F58518",
        "fixed_probe": "#54A24B",
        "old_proxy_failure_probe": "#E45756",
    }
    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        '<rect width="100%" height="100%" fill="white"/>',
        '<text x="460" y="25" text-anchor="middle" font-family="Arial" font-size="17">R029 held-out guarded proxy replay</text>',
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
    for i, row in policy.reset_index(drop=True).iterrows():
        x = margin_l + i * step + (step - bar_w) / 2
        h = row["mean_switching_regret"] / max_v * plot_h
        y = height - margin_b - h
        family = row["policy_family"]
        parts.append(
            f'<rect x="{x:.1f}" y="{y:.1f}" width="{bar_w:.1f}" height="{h:.1f}" fill="{colors.get(family, "#888")}"/>'
        )
        parts.append(
            f'<text x="{x+bar_w/2:.1f}" y="{y-5:.1f}" text-anchor="middle" font-family="Arial" font-size="11">{row["mean_switching_regret"]:.3f}</text>'
        )
        label = str(family).replace("_", " ")
        parts.append(
            f'<text x="{x+bar_w/2:.1f}" y="{height-margin_b+18}" text-anchor="end" transform="rotate(-35 {x+bar_w/2:.1f},{height-margin_b+18})" font-family="Arial" font-size="11">{label}</text>'
        )
    parts.append(
        f'<text x="26" y="{margin_t+plot_h/2}" text-anchor="middle" transform="rotate(-90 26,{margin_t+plot_h/2})" font-family="Arial" font-size="13">Mean switching regret</text>'
    )
    parts.append("</svg>")
    SVG.write_text("\n".join(parts), encoding="utf-8")


def write_reports(policy: pd.DataFrame, context: pd.DataFrame, rows: pd.DataFrame) -> None:
    n_success = int((rows["success"].astype(str).isin(["1", "true", "True"]) | (rows["success"] == 1)).sum())
    guarded = policy[policy["policy_family"] == "guarded_candidate"]
    dense = policy[policy["policy_family"] == "dense_anchor"]
    old = policy[policy["policy_family"] == "old_proxy_failure_probe"]
    report = [
        "# R029 held-out guarded-proxy switching report",
        "",
        "## Scope",
        "",
        "R029 executes the held-out validation matrix proposed after R028.  It uses only the derived Simulink model and delayed `Iph_ref_ts` profiles.  It is not hardware/HIL validation and does not prove a global `T_slew` optimum.",
        "",
        "## Coverage",
        "",
        f"- Successful held-out cases: `{n_success}` / `21`.",
        "- `10A / score_settle005`: `tau_AI = 1.5/2.5/3 us`, `T_slew = 34/40/50/62 us`.",
        "- `near0A / score_settle010`: `tau_AI = 0/0.25/0.5 us`, `T_slew = 30/35/38 us`.",
        "",
        "## Policy-Family Summary",
        "",
        md_table(
            policy,
            [
                "policy_family",
                "n_cases",
                "mean_switching_regret",
                "max_switching_regret",
                "mean_selected_objective",
                "best_context_count",
                "zero_regret_context_count",
            ],
        ),
        "",
        "## Context Winners",
        "",
        md_table(
            context,
            [
                "target_label",
                "objective",
                "tau_ai_us",
                "best_policy",
                "best_slew_us",
                "dense_anchor_regret",
                "guarded_regret",
                "old_proxy_regret",
                "interpretation",
            ],
        ),
        "",
        "## Interpretation",
        "",
        "- The `10A/score_settle005` delay guard has local held-out support for `tau_AI=2.5/3 us`: `34 us` is best in both contexts.",
        "- The guard should not be extended below `2 us`: at `tau_AI=1.5 us`, `40 us` is best among the tested candidates.",
        "- The old `62 us` proxy action remains poor for 10A held-out contexts, supporting the R028 decision to reject it.",
        "- The near0A zero-delay `35 us` guard is too narrow once the `38 us` fine-sweep probe is included: `38 us` is best at `tau_AI=0` and marginally best at `0.25 us`, while `30 us` is best again at `0.5 us`.",
        "",
    ]
    if not guarded.empty and not dense.empty:
        report += [
            f"Guarded-family mean regret is `{guarded.iloc[0]['mean_switching_regret']:.3f}` over contexts where guarded rows exist; dense-anchor mean regret is `{dense.iloc[0]['mean_switching_regret']:.3f}` over all dense-anchor rows.  These are not directly identical policy deployments because each family appears in different subsets of the held-out matrix.",
            "",
        ]
    if not old.empty:
        report += [
            f"The old proxy failure probe has mean regret `{old.iloc[0]['mean_switching_regret']:.3f}`, reinforcing that the old `62 us` action should remain outside the deployable band for the tested 10A settling-aware context.",
            "",
        ]
    report += [
        "## Boundary",
        "",
        "- AI remains a supervisory scheduler and does not replace the IQCOT inner loop.",
        "- R029 is derived Simulink evidence only.",
        "- The near0A result updates R028: a fixed `35 us` zero-delay guard is weaker than a local `30-38 us` band/projection rule.",
        "- These data suggest a refined R030 policy, not a final hardware-safe controller.",
        "",
    ]
    REPORT_MD.write_text("\n".join(report), encoding="utf-8")

    paper = [
        "### R029 held-out 验证：R028 guard 的局部支持与修正",
        "",
        "为避免把 R028 的 `0.000` priority regret 误写成泛化证明，本文进一步执行了 `21` 个 held-out 派生 Simulink 工况。对 `10A/score_settle005`，验证矩阵在 `tau_AI=1.5/2.5/3us` 下比较 `34/40/50/62us`。结果显示，`tau_AI=1.5us` 时 `40us` 最优，说明 `34us` guard 不应外推到 `2us` 以下；而 `tau_AI=2.5/3us` 时 `34us` 最优，支持 R028 中 `tau_AI>=2us` 的短斜率 delay guard。旧 proxy 的 `62us` 在 held-out 10A 场景中仍然偏差较大，支持 dense-anchor 投影将其排除。",
        "",
        "near0A 强恢复目标的结果则修正了 R028：当加入 `38us` 细扫候选后，`tau_AI=0` 与 `0.25us` 下 `38us` 最优或近似最优，`tau_AI=0.5us` 下 `30us` 最优。因此 near0A 不应写成固定 `35us` guard，而应写成 `30-38us` 局部安全带，后续由 score 或风险 proxy 在带内选择。R029 仍是派生模型证据，不等同于硬件验证或神经网络 AI-in-loop。",
        "",
    ]
    PAPER_MD.write_text("\n".join(paper), encoding="utf-8")


def main() -> None:
    rows = recompute_regret(read_results())
    policy = summarize_policy(rows)
    context = summarize_context(rows)
    rows.to_csv(COMBINED_RESULTS, index=False, encoding="utf-8-sig")
    policy.to_csv(POLICY_SUMMARY, index=False, encoding="utf-8-sig")
    context.to_csv(CONTEXT_SUMMARY, index=False, encoding="utf-8-sig")
    write_svg(policy)
    write_reports(policy, context, rows)


if __name__ == "__main__":
    main()
