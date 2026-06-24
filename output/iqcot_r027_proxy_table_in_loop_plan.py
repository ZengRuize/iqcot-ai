"""R027 table-in-loop validation plan for deployable IQCOT risk proxy.

This script does not run Simulink. It converts the R026 offline proxy policy
comparison into a derived-model validation matrix. The generated MATLAB wrapper
uses only the derived model under output/simulink_iek when run later.

Boundaries:
- posterior_mode_aware_projection is an upper-bound comparator, not deployable.
- calibrated_risk_proxy_projection is a table/proxy supervisor, not a neural
  network AI-in-loop result.
- The generated plan is a validation design; switching-level evidence exists
  only after running the MATLAB plan on the derived model.
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd


ROOT = Path("E:/Desktop/codex")
OUT = ROOT / "output"

DATASET_CSV = OUT / "iqcot_mode_aware_slew_dataset.csv"
R026_POLICY_EVAL_CSV = OUT / "iqcot_deployable_proxy_policy_eval.csv"

FULL_PLAN_CSV = OUT / "iqcot_r027_proxy_table_in_loop_plan.csv"
PRIORITY_PLAN_CSV = OUT / "iqcot_r027_proxy_table_in_loop_priority_plan.csv"
EXPECTED_SUMMARY_CSV = OUT / "iqcot_r027_proxy_table_in_loop_expected_summary.csv"
EXPECTED_DETAIL_CSV = OUT / "iqcot_r027_proxy_table_in_loop_expected_detail.csv"
REPORT_MD = OUT / "iqcot_r027_proxy_table_in_loop_plan_report.md"
PAPER_SECTION_MD = OUT / "iqcot_r027_proxy_table_in_loop_paper_section.md"


POLICIES = [
    {
        "policy": "fixed_40us_precommitted",
        "source_policy": "fixed",
        "policy_kind": "fixed",
        "policy_role": "baseline",
        "selected_ref_slew_us": 40.0,
        "delay_mode": "precommitted",
        "online_available_inputs_only": True,
    },
    {
        "policy": "fixed_80us_precommitted",
        "source_policy": "fixed",
        "policy_kind": "fixed",
        "policy_role": "baseline",
        "selected_ref_slew_us": 80.0,
        "delay_mode": "precommitted",
        "online_available_inputs_only": True,
    },
    {
        "policy": "discrete_dense_long_table",
        "source_policy": "discrete_dense_long_table",
        "policy_kind": "lookup_table",
        "policy_role": "deployable_baseline",
        "delay_mode": "commit_after_tau_ai",
        "online_available_inputs_only": True,
    },
    {
        "policy": "calibrated_risk_proxy_projection",
        "source_policy": "calibrated_risk_proxy_projection",
        "policy_kind": "proxy_projection",
        "policy_role": "deployable_candidate",
        "delay_mode": "commit_after_tau_ai",
        "online_available_inputs_only": True,
    },
    {
        "policy": "near_opt_band_clipping",
        "source_policy": "near_opt_band_clipping",
        "policy_kind": "band_projection",
        "policy_role": "offline_comparator",
        "delay_mode": "commit_after_tau_ai",
        "online_available_inputs_only": False,
    },
    {
        "policy": "posterior_mode_aware_projection",
        "source_policy": "posterior_mode_aware_projection",
        "policy_kind": "posterior_projection",
        "policy_role": "posterior_upper_bound",
        "delay_mode": "commit_after_tau_ai",
        "online_available_inputs_only": False,
    },
    {
        "policy": "naked_smooth_continuous",
        "source_policy": "naked_smooth_continuous",
        "policy_kind": "smooth_continuous",
        "policy_role": "negative_control",
        "delay_mode": "commit_after_tau_ai",
        "online_available_inputs_only": True,
    },
]

OBJECTIVE_ALPHA = {
    "base": 0.0,
    "score_settle005": 0.05,
    "score_settle010": 0.10,
}

OBJECTIVE_SCORE_COL = {
    "base": "objective_score",
    "score_settle005": "objective_score",
    "score_settle010": "objective_score",
}


def nearest_measured(ctx: pd.DataFrame, slew_us: float) -> pd.Series:
    dist = (ctx["ref_slew_us"] - slew_us).abs()
    candidates = ctx[dist == dist.min()]
    return candidates.loc[candidates["objective_score"].idxmin()]


def selected_row_for_policy(
    ctx: pd.DataFrame,
    r026: pd.DataFrame,
    target_label: str,
    objective: str,
    tau_us: float,
    policy: dict[str, object],
) -> tuple[float, pd.Series, str]:
    if policy["source_policy"] == "fixed":
        requested = float(policy["selected_ref_slew_us"])
        selected = nearest_measured(ctx, requested)
        return requested, selected, "fixed precommitted baseline; realized by nearest measured grid point"

    rows = r026[
        (r026["target_label"] == target_label)
        & (r026["objective"] == objective)
        & (r026["tau_AI_us"].astype(float) == float(tau_us))
        & (r026["policy"] == str(policy["source_policy"]))
    ]
    if rows.empty:
        raise KeyError(f"Missing R026 row {target_label}/{objective}/{tau_us}/{policy['source_policy']}")
    r = rows.iloc[0]
    requested = float(r["selected_ref_slew_us"])
    selected = nearest_measured(ctx, requested)
    return requested, selected, str(r.get("selection_basis", "R026 policy replay"))


def build_plan() -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    dataset = pd.read_csv(DATASET_CSV)
    r026 = pd.read_csv(R026_POLICY_EVAL_CSV)
    for df in [dataset, r026]:
        for col in df.columns:
            if col.endswith("_us") or col.endswith("_A") or col in [
                "alpha_settle",
                "objective_score",
                "ref_slew_us",
                "skip_count_est",
                "settle_time_us",
                "final_phase_spacing_std_ns",
                "phase_std_ns",
                "undershoot_mV",
                "regret_vs_combined_oracle",
                "tau_AI_us",
                "delay_events",
            ]:
                try:
                    df[col] = pd.to_numeric(df[col])
                except Exception:
                    pass

    rows: list[dict[str, object]] = []
    detail_rows: list[dict[str, object]] = []
    context_groups = dataset.groupby(["target_label", "target_load_A", "objective"], sort=False)
    case_idx = 0
    for (target_label, target_load, objective), ctx in context_groups:
        alpha = OBJECTIVE_ALPHA[str(objective)]
        oracle = ctx.loc[ctx["objective_score"].idxmin()]
        for tau_us in sorted(r026["tau_AI_us"].astype(float).unique()):
            for policy in POLICIES:
                requested_slew, selected, basis = selected_row_for_policy(
                    ctx, r026, str(target_label), str(objective), float(tau_us), policy
                )
                case_idx += 1
                delay_mode = str(policy["delay_mode"])
                ref_start_delay = 0.0 if delay_mode == "precommitted" else float(tau_us)
                delay_events = int(np.ceil(float(tau_us) / 0.5 - 1e-12))
                score = float(selected["objective_score"])
                regret = score - float(oracle["objective_score"])
                row = {
                    "r027_case_id": f"R027_{case_idx:04d}",
                    "target_label": str(target_label),
                    "target_load_A": float(target_load),
                    "load_drop_A": 40.0 - float(target_load),
                    "objective": str(objective),
                    "objective_alpha_settle": alpha,
                    "tau_ai_us": float(tau_us),
                    "delay_events": delay_events,
                    "event_period_us_assumed": 0.5,
                    "policy": str(policy["policy"]),
                    "source_policy": str(policy["source_policy"]),
                    "policy_kind": str(policy["policy_kind"]),
                    "policy_role": str(policy["policy_role"]),
                    "selected_ref_slew_us": requested_slew,
                    "realized_ref_slew_us_in_offline_grid": float(selected["ref_slew_us"]),
                    "ref_start_delay_us_for_simulink": ref_start_delay,
                    "delay_mode": delay_mode,
                    "offline_objective_score": score,
                    "offline_regret_vs_oracle": regret,
                    "offline_undershoot_mV": float(selected["undershoot_mV"]),
                    "offline_settle_time_us": float(selected["settle_time_us"]),
                    "offline_skip_count_est": float(selected["skip_count_est"]),
                    "offline_phase_std_ns": float(selected["final_phase_spacing_std_ns"]),
                    "online_available_inputs_only": bool(policy["online_available_inputs_only"]),
                    "selection_basis": basis,
                    "boundary": "R027 plan only; switching evidence requires derived Simulink run",
                }
                rows.append(row)
                detail_rows.append(row.copy())

    plan = pd.DataFrame(rows)
    expected = (
        plan.groupby("policy", as_index=False)
        .agg(
            n_cases=("offline_objective_score", "count"),
            mean_regret=("offline_regret_vs_oracle", "mean"),
            max_regret=("offline_regret_vs_oracle", "max"),
            mean_score=("offline_objective_score", "mean"),
            mean_skip=("offline_skip_count_est", "mean"),
            mean_phase_std_ns=("offline_phase_std_ns", "mean"),
            mean_settle_time_us=("offline_settle_time_us", "mean"),
            online_available_inputs_only=("online_available_inputs_only", "min"),
        )
        .sort_values(["mean_regret", "max_regret"])
    )

    # Priority contexts: include cases where calibrated proxy differs from dense
    # table or posterior upper-bound, plus high-regret calibrated contexts. This
    # keeps the first switching check compact while retaining failure-sensitive
    # cases.
    piv = plan.pivot_table(
        index=["target_label", "objective", "tau_ai_us"],
        columns="policy",
        values=["selected_ref_slew_us", "offline_regret_vs_oracle"],
        aggfunc="first",
    )
    priority_contexts = []
    for idx, row in piv.iterrows():
        cal_slew = row[("selected_ref_slew_us", "calibrated_risk_proxy_projection")]
        dense_slew = row[("selected_ref_slew_us", "discrete_dense_long_table")]
        post_slew = row[("selected_ref_slew_us", "posterior_mode_aware_projection")]
        cal_regret = row[("offline_regret_vs_oracle", "calibrated_risk_proxy_projection")]
        if cal_slew != dense_slew or cal_slew != post_slew or cal_regret >= 0.15:
            priority_contexts.append((idx, float(cal_regret), float(abs(cal_slew - dense_slew) + abs(cal_slew - post_slew))))
    priority_contexts = sorted(priority_contexts, key=lambda x: (x[1], x[2]), reverse=True)[:8]
    priority_index = {x[0] for x in priority_contexts}
    priority = plan[
        plan.set_index(["target_label", "objective", "tau_ai_us"]).index.isin(priority_index)
        & plan["policy"].isin(
            [
                "fixed_40us_precommitted",
                "fixed_80us_precommitted",
                "discrete_dense_long_table",
                "calibrated_risk_proxy_projection",
                "posterior_mode_aware_projection",
                "near_opt_band_clipping",
            ]
        )
    ].copy()
    priority["priority_reason"] = priority.apply(priority_reason, axis=1)
    priority["include_in_priority_run"] = True
    plan["include_in_priority_run"] = plan["r027_case_id"].isin(priority["r027_case_id"])

    return plan, priority, expected


def priority_reason(row: pd.Series) -> str:
    if row["policy"] == "posterior_mode_aware_projection":
        return "posterior upper-bound comparator only; not deployable"
    if row["policy"] == "calibrated_risk_proxy_projection":
        return "deployable R026 candidate whose ordering needs switching replay"
    if row["policy"] == "discrete_dense_long_table":
        return "strong deployable lookup baseline"
    if row["policy"].startswith("fixed"):
        return "fixed slew baseline for absolute waveform comparison"
    return "band comparator for safety projection sensitivity"


def md_table(df: pd.DataFrame, cols: list[str], max_rows: int | None = None) -> str:
    d = df[cols].copy()
    if max_rows is not None:
        d = d.head(max_rows)
    lines = ["| " + " | ".join(cols) + " |", "| " + " | ".join(["---"] * len(cols)) + " |"]
    for _, row in d.iterrows():
        vals: list[str] = []
        for col in cols:
            val = row[col]
            if isinstance(val, (float, np.floating)):
                vals.append(f"{val:.3f}")
            else:
                vals.append(str(val))
        lines.append("| " + " | ".join(vals) + " |")
    return "\n".join(lines)


def write_reports(plan: pd.DataFrame, priority: pd.DataFrame, expected: pd.DataFrame) -> None:
    report = [
        "# R027 R026-proxy table-in-loop 验证计划",
        "",
        "## 目的",
        "",
        "R026 已经把后验 `skip/phase/settle` 指标降级为可部署 `r_hat(z,T_slew)` 风险 proxy。R027 的目标不是再次证明离线排序，而是为派生 Simulink table-in-loop 验证生成可执行矩阵：检查校准 risk proxy 在参数提交延迟下是否仍优于强查表基线，并用后验 mode-aware projection 仅作为上界对照。",
        "",
        "## 产物",
        "",
        f"- 完整计划：`{FULL_PLAN_CSV.as_posix()}`，`{len(plan)}` 行。",
        f"- 优先仿真计划：`{PRIORITY_PLAN_CSV.as_posix()}`，`{len(priority)}` 行。",
        f"- 离线预期汇总：`{EXPECTED_SUMMARY_CSV.as_posix()}`。",
        "",
        "## 离线预期排序",
        "",
        md_table(
            expected,
            [
                "policy",
                "n_cases",
                "mean_regret",
                "max_regret",
                "mean_skip",
                "mean_phase_std_ns",
                "mean_settle_time_us",
                "online_available_inputs_only",
            ],
        ),
        "",
        "## 优先仿真矩阵预览",
        "",
        md_table(
            priority,
            [
                "r027_case_id",
                "target_label",
                "objective",
                "tau_ai_us",
                "policy",
                "selected_ref_slew_us",
                "ref_start_delay_us_for_simulink",
                "offline_regret_vs_oracle",
            ],
            max_rows=30,
        ),
        "",
        "## 执行边界",
        "",
        "- 只使用派生模型 `E:/Desktop/codex/output/simulink_iek/four_phase_iek_dynamic_load_refslew.slx`。",
        "- 不修改原始 `.slx`，不直接编辑 `.slx` XML。",
        "- `posterior_mode_aware_projection` 只作为离线上界对照，不可写成可部署 AI。",
        "- R027 计划本身不是开关级结果；只有运行 MATLAB wrapper 后才可报告 switching-level 指标。",
    ]
    REPORT_MD.write_text("\n".join(report) + "\n", encoding="utf-8")

    cal = expected[expected["policy"] == "calibrated_risk_proxy_projection"].iloc[0]
    dense = expected[expected["policy"] == "discrete_dense_long_table"].iloc[0]
    posterior = expected[expected["policy"] == "posterior_mode_aware_projection"].iloc[0]
    paper = [
        "### R027 R026-proxy table-in-loop 验证设计",
        "",
        "R026 仍是离线后处理，因此下一步需要将 `r_hat(z,T_slew)` 形式的校准 risk proxy 接入派生 Simulink 参考通道。R027 生成完整验证矩阵和优先仿真子集：完整计划覆盖目标负载、目标函数权重、`tau_AI=0/0.5/1/2/5 us` 和固定/查表/proxy/后验上界等策略；优先计划只保留排序分歧和 proxy regret 较高的上下文。",
        "",
        f"离线预期中，校准 risk proxy 的 mean regret 为 `{cal['mean_regret']:.3f}`，低于 dense-long table `{dense['mean_regret']:.3f}`，但弱于后验上界 `{posterior['mean_regret']:.3f}`。R027 的开关级验证问题不是证明全局最优，而是检查这个排序在延迟提交的 `Iph_ref_ts` 波形中是否保持。",
        "",
        "若派生模型验证保持该排序，论文可进一步声称 `r_hat` 表驱动监督层具有开关级接入可行性；若排序不保持，应收缩结论为离线 proxy 设计，并回到 `B_epsilon` 安全边界重标定。",
    ]
    PAPER_SECTION_MD.write_text("\n".join(paper) + "\n", encoding="utf-8")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    plan, priority, expected = build_plan()
    plan.to_csv(FULL_PLAN_CSV, index=False)
    priority.to_csv(PRIORITY_PLAN_CSV, index=False)
    expected.to_csv(EXPECTED_SUMMARY_CSV, index=False)
    plan.to_csv(EXPECTED_DETAIL_CSV, index=False)
    write_reports(plan, priority, expected)
    print(f"R027_FULL_PLAN={FULL_PLAN_CSV}")
    print(f"R027_PRIORITY_PLAN={PRIORITY_PLAN_CSV}")
    print(f"R027_EXPECTED_SUMMARY={EXPECTED_SUMMARY_CSV}")
    print(f"R027_REPORT={REPORT_MD}")


if __name__ == "__main__":
    main()
