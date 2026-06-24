"""R029 held-out validation plan for the R028 guarded proxy candidate.

This script only generates CSV plans and expected/offline labels. It does not
run Simulink and does not modify any .slx model.  The held-out matrix probes
whether the R028 guarded rules, fitted on R027 priority contexts, survive
nearby delay contexts that were not used for calibration.
"""

from __future__ import annotations

from pathlib import Path

import pandas as pd


ROOT = Path("E:/Desktop/codex")
OUT = ROOT / "output"

PLAN_CSV = OUT / "iqcot_r029_guarded_heldout_plan.csv"
MATLAB_PLAN_CSV = OUT / "iqcot_r029_guarded_heldout_matlab_plan.csv"
EXPECTED_CSV = OUT / "iqcot_r029_guarded_heldout_expected_summary.csv"
REPORT_MD = OUT / "iqcot_r029_guarded_heldout_plan_report.md"
PAPER_MD = OUT / "iqcot_r029_guarded_heldout_paper_section.md"


def objective_alpha(objective: str) -> float:
    if objective == "score_settle005":
        return 0.05
    if objective == "score_settle010":
        return 0.10
    return 0.0


def policy_role(target_label: str, objective: str, tau_us: float, slew_us: float) -> tuple[str, str, str]:
    """Return policy, family, and interpretation."""
    if target_label == "10A" and objective == "score_settle005":
        if slew_us == 34:
            if tau_us >= 2.0:
                return "r028_guarded_candidate", "guarded_candidate", "R028 delay guard action for tau>=2us"
            return "short_slew_probe_34us", "heldout_probe", "short-slew probe below the R028 delay threshold"
        if slew_us == 50:
            return "r028_dense_anchor", "dense_anchor", "conservative dense-anchor action"
        if slew_us == 62:
            return "old_proxy_62us", "old_proxy_failure_probe", "old R026 proxy action that failed in R027"
        if slew_us == 40:
            return "fixed_40us_probe", "fixed_probe", "intermediate fixed-slew comparator"
    if target_label == "near0A" and objective == "score_settle010":
        if slew_us == 30:
            return "r028_dense_anchor", "dense_anchor", "dense/proxy action; R028 guard keeps this once delay exists"
        if slew_us == 35:
            if tau_us == 0:
                return "r028_guarded_candidate", "guarded_candidate", "R028 zero-delay recovery guard action"
            return "near_opt_35us_probe", "heldout_probe", "near-opt comparator near the zero-delay guard"
        if slew_us == 38:
            return "fine_sweep_38us_probe", "heldout_probe", "R024 fine-sweep local comparator"
    return f"slew_{slew_us:g}us_probe", "heldout_probe", "generic held-out slew probe"


def build_plan() -> pd.DataFrame:
    rows: list[dict[str, object]] = []
    case_idx = 0

    # Held-out delay contexts near the R027 10A/score_settle005 stress boundary.
    for tau_us in [1.5, 2.5, 3.0]:
        for slew_us in [34.0, 40.0, 50.0, 62.0]:
            case_idx += 1
            policy, family, basis = policy_role("10A", "score_settle005", tau_us, slew_us)
            rows.append(
                {
                    "r029_case_id": f"R029_{case_idx:04d}",
                    "target_label": "10A",
                    "target_load_A": 10.0,
                    "load_drop_A": 30.0,
                    "objective": "score_settle005",
                    "objective_alpha_settle": objective_alpha("score_settle005"),
                    "tau_ai_us": tau_us,
                    "delay_events_at_0p5us": int(round(tau_us / 0.5)),
                    "selected_ref_slew_us": slew_us,
                    "ref_start_delay_us_for_simulink": tau_us,
                    "policy": policy,
                    "policy_family": family,
                    "selection_basis": basis,
                    "heldout_reason": "interpolates/extrapolates R027 delay guard boundary; not used to fit R028",
                    "online_available_inputs_only": True,
                    "boundary": "R029 plan only until derived Simulink runner is executed",
                }
            )

    # Held-out delay contexts near the near-zero-load zero-delay recovery guard.
    for tau_us in [0.0, 0.25, 0.5]:
        for slew_us in [30.0, 35.0, 38.0]:
            case_idx += 1
            policy, family, basis = policy_role("near0A", "score_settle010", tau_us, slew_us)
            rows.append(
                {
                    "r029_case_id": f"R029_{case_idx:04d}",
                    "target_label": "near0A",
                    "target_load_A": 0.001,
                    "load_drop_A": 39.999,
                    "objective": "score_settle010",
                    "objective_alpha_settle": objective_alpha("score_settle010"),
                    "tau_ai_us": tau_us,
                    "delay_events_at_0p5us": int(round(tau_us / 0.5)),
                    "selected_ref_slew_us": slew_us,
                    "ref_start_delay_us_for_simulink": tau_us,
                    "policy": policy,
                    "policy_family": family,
                    "selection_basis": basis,
                    "heldout_reason": "tests whether the near0A zero-delay 35us guard persists under small delay",
                    "online_available_inputs_only": True,
                    "boundary": "R029 plan only until derived Simulink runner is executed",
                }
            )

    return pd.DataFrame(rows)


def write_outputs(plan: pd.DataFrame) -> None:
    plan.to_csv(PLAN_CSV, index=False, encoding="utf-8-sig")
    plan.to_csv(MATLAB_PLAN_CSV, index=False, encoding="utf-8-sig")

    expected = (
        plan.groupby(["target_label", "objective", "tau_ai_us"], as_index=False)
        .agg(
            n_slew_candidates=("selected_ref_slew_us", "count"),
            candidate_slews_us=("selected_ref_slew_us", lambda s: "/".join(f"{x:g}" for x in s)),
            policy_families=("policy_family", lambda s: "/".join(pd.unique(s))),
        )
    )
    expected.to_csv(EXPECTED_CSV, index=False, encoding="utf-8-sig")

    report = [
        "# R029 held-out guarded-proxy validation plan",
        "",
        "## Purpose",
        "",
        "R029 tests whether the R028 guarded proxy candidate is merely fitted to the R027 priority contexts.  The plan uses only the derived model when executed and does not edit any `.slx` XML.",
        "",
        "## Matrix",
        "",
        "- `10A / score_settle005`: `tau_AI = 1.5/2.5/3 us`, `T_slew = 34/40/50/62 us`.",
        "- `near0A / score_settle010`: `tau_AI = 0/0.25/0.5 us`, `T_slew = 30/35/38 us`.",
        "",
        f"- Total held-out cases: `{len(plan)}`.",
        "",
        "## Interpretation Rules",
        "",
        "- If `34 us` remains best for `10A/score_settle005` at `tau_AI=2.5/3 us` and is not best at `1.5 us`, the R028 delay guard has local support.",
        "- If `50 us` remains competitive at `tau_AI=2.5/3 us`, the dense-anchor rule is safer than an aggressive delay guard.",
        "- If `62 us` remains poor, R028 correctly rejected the old proxy action.",
        "- For near0A, if `35 us` is best only at `tau_AI=0` but `30 us` wins once delay is introduced, the zero-delay guard is locally supported.",
        "",
        "## Boundary",
        "",
        "This is a validation plan.  It does not prove hardware performance, global optimality of `T_slew`, or neural-network AI-in-loop superiority.",
        "",
    ]
    REPORT_MD.write_text("\n".join(report), encoding="utf-8")

    paper = [
        "### R029 held-out 验证设计：检验 R028 guarded proxy 是否过拟合",
        "",
        "R028 的 `r028_switching_guarded_proxy` 在 R027 priority 压力集上取得零 regret，但该策略由同一压力集校准得到，因此不能作为泛化证据。R029 设计了一个小规模 held-out 派生 Simulink 矩阵：对 `10A/score_settle005` 扫描 `tau_AI=1.5/2.5/3us` 和 `T_slew=34/40/50/62us`，对 near0A 强恢复目标扫描 `tau_AI=0/0.25/0.5us` 和 `T_slew=30/35/38us`。该矩阵用于检查 delay guard 的局部边界，而不是寻找全局最优斜率。",
        "",
    ]
    PAPER_MD.write_text("\n".join(paper), encoding="utf-8")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    plan = build_plan()
    write_outputs(plan)


if __name__ == "__main__":
    main()
