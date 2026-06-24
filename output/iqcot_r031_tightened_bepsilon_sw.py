#!/usr/bin/env python3
"""R031 tightened B_epsilon^sw and short-horizon risk interface prototype.

This is an offline post-processing step.  It uses the completed R030 dense-anchor
challenge results to design a conservative switching-calibrated projection rule
and a minimal follow-up validation matrix.  It does not edit or run any .slx
model.  The R031 rules are calibration candidates, not hardware validation and
not a proof of global T_slew optimality.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import pandas as pd


ROOT = Path("E:/Desktop/codex")
OUT = ROOT / "output"
FIG = OUT / "figures"

CHALLENGE_RESULTS = OUT / "iqcot_r030_dense_anchor_challenge_results_combined.csv"
CONTEXT_SUMMARY = OUT / "iqcot_r030_dense_anchor_challenge_context_summary.csv"
MOTIF_SUMMARY = OUT / "iqcot_r030_dense_anchor_challenge_motif_summary.csv"

PAIR_FEATURES = OUT / "iqcot_r031_pair_risk_features.csv"
POLICY_EVAL = OUT / "iqcot_r031_tightened_bepsilon_policy_eval.csv"
POLICY_SUMMARY = OUT / "iqcot_r031_tightened_bepsilon_policy_summary.csv"
RULES = OUT / "iqcot_r031_tightened_bepsilon_rules.csv"
VALIDATION_PLAN = OUT / "iqcot_r031_minimal_validation_plan.csv"
REPORT = OUT / "iqcot_r031_tightened_bepsilon_report.md"
PAPER = OUT / "iqcot_r031_tightened_bepsilon_paper_section.md"
SVG = FIG / "fig41_r031_tightened_bepsilon.svg"

DENSE = "discrete_dense_long_table"
PROXY = "calibrated_risk_proxy_projection"
CONTEXT = ["target_label", "objective", "tau_ai_us"]


@dataclass(frozen=True)
class Decision:
    policy: str
    selected_policy: str
    selected_slew_us: float
    rationale: str
    deployability: str


def f3(value: float) -> str:
    return f"{float(value):.3f}"


def read_inputs() -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    for path in [CHALLENGE_RESULTS, CONTEXT_SUMMARY, MOTIF_SUMMARY]:
        if not path.exists():
            raise FileNotFoundError(path)
    rows = pd.read_csv(CHALLENGE_RESULTS)
    context = pd.read_csv(CONTEXT_SUMMARY)
    motif = pd.read_csv(MOTIF_SUMMARY)
    return rows, context, motif


def build_pair_features(rows: pd.DataFrame, context: pd.DataFrame, motif: pd.DataFrame) -> pd.DataFrame:
    motif_key = motif.set_index(["target_label", "objective"])
    records: list[dict[str, object]] = []
    for _, ctx in context.iterrows():
        mask = (
            (rows["target_label"] == ctx["target_label"])
            & (rows["objective"] == ctx["objective"])
            & (rows["tau_ai_us"].astype(float).round(9) == round(float(ctx["tau_ai_us"]), 9))
        )
        dense = rows[mask & (rows["policy"] == DENSE)].iloc[0]
        proxy = rows[mask & (rows["policy"] == PROXY)].iloc[0]
        m = motif_key.loc[(ctx["target_label"], ctx["objective"])]
        slew_delta = float(ctx["proxy_slew_us"] - ctx["dense_slew_us"])
        proxy_minus_dense = float(ctx["proxy_minus_dense_score"])
        proxy_extra_skip = float(ctx["proxy_skip"] - ctx["dense_skip"])
        proxy_extra_settle = float(ctx["proxy_settle_us"] - ctx["dense_settle_us"])
        proxy_extra_phase = float(ctx["proxy_phase_std_ns"] - ctx["dense_phase_std_ns"])
        offline_advantage = float(dense["offline_objective_score"] - proxy["offline_objective_score"])
        records.append(
            {
                "target_label": ctx["target_label"],
                "target_load_A": float(dense["target_load_A"]),
                "objective": ctx["objective"],
                "objective_alpha_settle": float(dense["objective_alpha_settle"]),
                "tau_ai_us": float(ctx["tau_ai_us"]),
                "delay_events": int(dense["delay_events"]),
                "dense_slew_us": float(ctx["dense_slew_us"]),
                "proxy_slew_us": float(ctx["proxy_slew_us"]),
                "slew_delta_us": slew_delta,
                "abs_slew_delta_us": abs(slew_delta),
                "offline_proxy_advantage_score": offline_advantage,
                "switching_proxy_minus_dense_score": proxy_minus_dense,
                "proxy_wins_switching": bool(ctx["winner"] == "proxy"),
                "offline_pair_ranking_preserved": bool(ctx["offline_pair_ranking_preserved"]),
                "proxy_regret": float(ctx["proxy_regret"]),
                "dense_regret": float(ctx["dense_regret"]),
                "proxy_extra_skip": proxy_extra_skip,
                "proxy_extra_settle_us": proxy_extra_settle,
                "proxy_extra_phase_std_ns": proxy_extra_phase,
                "proxy_undershoot_delta_mV": float(
                    ctx["proxy_undershoot_mV"] - ctx["dense_undershoot_mV"]
                ),
                "motif_proxy_win_rate": float(m["proxy_win_count"]) / float(m["n_contexts"]),
                "motif_mean_proxy_minus_dense_score": float(m["mean_proxy_minus_dense_score"]),
                "motif_max_abs_proxy_minus_dense_score": float(
                    m["max_abs_proxy_minus_dense_score"]
                ),
                "large_slew_jump_flag": abs(slew_delta) >= 20.0,
                "delay_sensitive_motif_flag": bool(
                    float(m["proxy_win_count"]) > 0 and float(m["dense_win_count"]) > 0
                ),
                "near_tie_motif_flag": bool(
                    abs(float(m["mean_proxy_minus_dense_score"])) <= 0.05
                    and float(m["max_abs_proxy_minus_dense_score"]) <= 0.75
                ),
                "unsafe_proxy_override_label": bool(
                    proxy_minus_dense > 0.5 or proxy_extra_skip > 0.0 or proxy_extra_settle > 6.0
                ),
            }
        )
    return pd.DataFrame(records)


def choose(policy: str, row: pd.Series) -> Decision:
    target = str(row["target_label"])
    objective = str(row["objective"])
    tau = float(row["tau_ai_us"])
    dense_slew = float(row["dense_slew_us"])
    proxy_slew = float(row["proxy_slew_us"])

    if policy == "direct_proxy_override":
        return Decision(policy, PROXY, proxy_slew, "offline proxy selected directly", "deployable_negative_control")
    if policy == "dense_anchor_baseline":
        return Decision(policy, DENSE, dense_slew, "always use dense-anchor baseline", "deployable_baseline")
    if policy == "r031_small_delta_only":
        if abs(proxy_slew - dense_slew) <= 2.0:
            return Decision(policy, PROXY, proxy_slew, "proxy allowed only for <=2us local band", "candidate_rule")
        return Decision(policy, DENSE, dense_slew, "proxy blocked outside <=2us local band", "candidate_rule")
    if policy == "r031_tightened_sw_projection":
        if target == "10A" and objective == "score_settle010" and tau in {0.0, 0.5, 2.0}:
            return Decision(
                policy,
                PROXY,
                proxy_slew,
                "R030 near-tie subband: proxy allowed only at locally observed winning delays",
                "switching_calibrated_candidate",
            )
        return Decision(
            policy,
            DENSE,
            dense_slew,
            "default dense-anchor; block delay-sensitive or large-jump proxy override",
            "switching_calibrated_candidate",
        )
    if policy == "r031_pair_oracle_upper_bound":
        if bool(row["proxy_wins_switching"]):
            return Decision(policy, PROXY, proxy_slew, "pair-wise switching lower bound", "non_deployable_upper_bound")
        return Decision(policy, DENSE, dense_slew, "pair-wise switching lower bound", "non_deployable_upper_bound")
    raise ValueError(policy)


def evaluate_policies(features: pd.DataFrame) -> tuple[pd.DataFrame, pd.DataFrame]:
    policies = [
        "direct_proxy_override",
        "dense_anchor_baseline",
        "r031_small_delta_only",
        "r031_tightened_sw_projection",
        "r031_pair_oracle_upper_bound",
    ]
    records: list[dict[str, object]] = []
    for _, row in features.iterrows():
        for policy in policies:
            d = choose(policy, row)
            if d.selected_policy == PROXY:
                score = float(row["proxy_regret"] + min(row["dense_score"] if "dense_score" in row else 0, 0))
                objective_score = float(row["proxy_regret"]) + float(row.get("context_best_score", 0.0))
                regret = float(row["proxy_regret"])
                unsafe_selected = bool(row["unsafe_proxy_override_label"])
            else:
                objective_score = float(row.get("context_best_score", 0.0)) + float(row["dense_regret"])
                regret = float(row["dense_regret"])
                unsafe_selected = False
            records.append(
                {
                    "target_label": row["target_label"],
                    "objective": row["objective"],
                    "tau_ai_us": row["tau_ai_us"],
                    "policy": policy,
                    "selected_policy": d.selected_policy,
                    "selected_slew_us": d.selected_slew_us,
                    "regret": regret,
                    "objective_score_relative": objective_score,
                    "unsafe_proxy_override_selected": unsafe_selected,
                    "rationale": d.rationale,
                    "deployability": d.deployability,
                }
            )
    eval_df = pd.DataFrame(records)
    best_counts = eval_df[eval_df["regret"].abs() <= 1e-9].groupby("policy").size()
    summary = (
        eval_df.groupby(["policy", "deployability"], as_index=False)
        .agg(
            n_contexts=("regret", "count"),
            mean_regret=("regret", "mean"),
            max_regret=("regret", "max"),
            proxy_selected_count=("selected_policy", lambda s: int((s == PROXY).sum())),
            unsafe_proxy_selected_count=("unsafe_proxy_override_selected", "sum"),
        )
        .sort_values(["mean_regret", "max_regret", "policy"])
    )
    summary["zero_regret_context_count"] = summary["policy"].map(best_counts).fillna(0).astype(int)
    return eval_df, summary


def build_rules(motif: pd.DataFrame) -> pd.DataFrame:
    records = [
        {
            "target_label": "10A",
            "objective": "score_settle010",
            "dense_slew_us": 30.0,
            "proxy_slew_us": 32.0,
            "B_epsilon_sw_rule": "local band [30,32] us; default dense; proxy only in locally verified subband",
            "risk_category": "near_tie_delay_sensitive",
            "allowed_proxy_condition": "calibration candidate only: tau_AI in {0,0.5,2} us; needs held-out check",
            "blocked_proxy_condition": "tau_AI in {1,5} us or predictor uncertainty",
            "next_action": "validate 31/33us around tau_AI=1/5us to learn whether midpoint reduces non-monotonicity",
        },
        {
            "target_label": "20A",
            "objective": "base",
            "dense_slew_us": 80.0,
            "proxy_slew_us": 86.0,
            "B_epsilon_sw_rule": "block direct 86us override until intermediate 82/84us delay sweep is checked",
            "risk_category": "small_gain_delay_sensitive",
            "allowed_proxy_condition": "none for deployable rule; 86us only as validation candidate",
            "blocked_proxy_condition": "tau_AI in {0.5,2,5} us showed dense better; ranking not stable",
            "next_action": "validate 82/84us at tau_AI=0.5/2/5us",
        },
        {
            "target_label": "20A",
            "objective": "score_settle005",
            "dense_slew_us": 30.0,
            "proxy_slew_us": 66.0,
            "B_epsilon_sw_rule": "tighten to exclude 66us direct override; require short-horizon skip/settle risk prediction",
            "risk_category": "large_jump_settling_sensitive_negative_sample",
            "allowed_proxy_condition": "none for deployable rule; only re-admit if predictor flags low skip and low settling risk",
            "blocked_proxy_condition": "tau_AI in {0.5,2,5} us produced large proxy regret and extra skip/settling cost",
            "next_action": "validate 38/50/58us at tau_AI=0.5/1/2/5us to find a safer intermediate band",
        },
    ]
    rules = pd.DataFrame(records)
    rules = rules.merge(
        motif[
            [
                "target_label",
                "objective",
                "proxy_win_count",
                "dense_win_count",
                "mean_proxy_minus_dense_score",
                "max_abs_proxy_minus_dense_score",
            ]
        ],
        on=["target_label", "objective"],
        how="left",
    )
    return rules


def build_validation_plan() -> pd.DataFrame:
    records: list[dict[str, object]] = []

    def add(target: str, load: float, objective: str, alpha: float, tau: float, slew: float, base: float, reason: str, priority: int) -> None:
        records.append(
            {
                "r031_case_id": f"R031_{len(records)+1:04d}",
                "target_label": target,
                "target_load_A": load,
                "load_drop_A": 40.0 - load,
                "objective": objective,
                "objective_alpha_settle": alpha,
                "tau_ai_us": tau,
                "candidate_ref_slew_us": slew,
                "reference_baseline_slew_us": base,
                "priority": priority,
                "reason": reason,
                "expected_information": "derived Simulink delayed-reference validation only; not hardware",
            }
        )

    for tau in [1.0, 5.0]:
        for slew in [31.0, 33.0]:
            add(
                "10A",
                10.0,
                "score_settle010",
                0.10,
                tau,
                slew,
                30.0,
                "Resolve 30-32us near-tie non-monotonic delay behavior.",
                2,
            )
    for tau in [0.5, 2.0, 5.0]:
        for slew in [82.0, 84.0]:
            add(
                "20A",
                20.0,
                "base",
                0.0,
                tau,
                slew,
                80.0,
                "Check whether 82/84us intermediate points avoid 86us delay-sensitive ranking flips.",
                2,
            )
    for tau in [0.5, 1.0, 2.0, 5.0]:
        for slew in [38.0, 50.0, 58.0]:
            add(
                "20A",
                20.0,
                "score_settle005",
                0.05,
                tau,
                slew,
                30.0,
                "Map safer intermediate band between dense 30us and high-risk proxy 66us.",
                1,
            )
    return pd.DataFrame(records)


def write_svg(summary: pd.DataFrame, rules: pd.DataFrame) -> None:
    FIG.mkdir(parents=True, exist_ok=True)
    width, height = 1050, 520
    left, top = 95, 55
    plot_w, plot_h = 520, 310
    max_reg = max(0.1, float(summary["mean_regret"].max()) * 1.18)
    colors = {
        "direct_proxy_override": "#E45756",
        "dense_anchor_baseline": "#4C78A8",
        "r031_small_delta_only": "#F58518",
        "r031_tightened_sw_projection": "#54A24B",
        "r031_pair_oracle_upper_bound": "#72B7B2",
    }
    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        '<rect width="100%" height="100%" fill="white"/>',
        '<text x="525" y="28" text-anchor="middle" font-family="Arial" font-size="18">R031 tightened B_epsilon^sw calibration prototype</text>',
        f'<line x1="{left}" y1="{top+plot_h}" x2="{left+plot_w}" y2="{top+plot_h}" stroke="#333"/>',
        f'<line x1="{left}" y1="{top}" x2="{left}" y2="{top+plot_h}" stroke="#333"/>',
    ]
    for frac in [0, 0.25, 0.5, 0.75, 1.0]:
        y = top + plot_h - frac * plot_h
        val = frac * max_reg
        parts.append(f'<line x1="{left-4}" y1="{y:.1f}" x2="{left+plot_w}" y2="{y:.1f}" stroke="#eee"/>')
        parts.append(f'<text x="{left-10}" y="{y+4:.1f}" text-anchor="end" font-family="Arial" font-size="11">{val:.2f}</text>')
    bar_w = 64
    step = plot_w / len(summary)
    for i, (_, row) in enumerate(summary.reset_index(drop=True).iterrows()):
        p = row["policy"]
        x = left + i * step + (step - bar_w) / 2
        h = float(row["mean_regret"]) / max_reg * plot_h
        y = top + plot_h - h
        parts.append(f'<rect x="{x:.1f}" y="{y:.1f}" width="{bar_w:.1f}" height="{h:.1f}" fill="{colors.get(p, "#888")}"/>')
        parts.append(f'<text x="{x+bar_w/2:.1f}" y="{y-6:.1f}" text-anchor="middle" font-family="Arial" font-size="11">{row["mean_regret"]:.3f}</text>')
        label = p.replace("r031_", "").replace("_", " ")
        parts.append(f'<text x="{x+bar_w/2:.1f}" y="{top+plot_h+20}" text-anchor="end" transform="rotate(-35 {x+bar_w/2:.1f},{top+plot_h+20})" font-family="Arial" font-size="10">{label}</text>')
    parts.append(f'<text x="25" y="{top+plot_h/2}" text-anchor="middle" transform="rotate(-90 25,{top+plot_h/2})" font-family="Arial" font-size="13">Mean regret on R030 challenge contexts</text>')

    x0, y0 = 665, 82
    parts.append('<text x="825" y="55" text-anchor="middle" font-family="Arial" font-size="14">R031 rule categories</text>')
    for i, (_, row) in enumerate(rules.iterrows()):
        y = y0 + i * 95
        label = f'{row["target_label"]} / {row["objective"]}'
        color = ["#72B7B2", "#F58518", "#E45756"][i]
        parts.append(f'<rect x="{x0}" y="{y-24}" width="20" height="20" fill="{color}"/>')
        parts.append(f'<text x="{x0+30}" y="{y-9}" font-family="Arial" font-size="12" font-weight="bold">{label}</text>')
        parts.append(f'<text x="{x0+30}" y="{y+12}" font-family="Arial" font-size="11">{row["risk_category"]}</text>')
        parts.append(f'<text x="{x0+30}" y="{y+32}" font-family="Arial" font-size="10" fill="#555">proxy wins {int(row["proxy_win_count"])}, dense wins {int(row["dense_win_count"])}, mean Δ={float(row["mean_proxy_minus_dense_score"]):.3f}</text>')
    parts.append("</svg>")
    SVG.write_text("\n".join(parts), encoding="utf-8")


def md_table(df: pd.DataFrame, cols: list[str]) -> str:
    lines = [
        "| " + " | ".join(cols) + " |",
        "| " + " | ".join(["---"] * len(cols)) + " |",
    ]
    for _, row in df[cols].iterrows():
        vals = []
        for c in cols:
            v = row[c]
            if isinstance(v, float):
                vals.append(f"{v:.3f}")
            else:
                vals.append(str(v))
        lines.append("| " + " | ".join(vals) + " |")
    return "\n".join(lines)


def write_reports(summary: pd.DataFrame, rules: pd.DataFrame, plan: pd.DataFrame) -> None:
    dense = summary[summary["policy"] == "dense_anchor_baseline"].iloc[0]
    proxy = summary[summary["policy"] == "direct_proxy_override"].iloc[0]
    tightened = summary[summary["policy"] == "r031_tightened_sw_projection"].iloc[0]
    small_delta = summary[summary["policy"] == "r031_small_delta_only"].iloc[0]
    oracle = summary[summary["policy"] == "r031_pair_oracle_upper_bound"].iloc[0]

    report = f"""# R031 Tightened `B_epsilon^sw` / Risk Predictor Prototype

## Scope

This is an offline post-processing prototype based on the completed R030
dense-anchor challenge.  It does not run or edit any `.slx` model.  Its purpose
is to turn R030 negative samples into a more conservative switching-calibrated
projection rule and a minimal next validation matrix.

## Policy Replay on R030 Challenge Contexts

{md_table(summary, [
    "policy",
    "deployability",
    "n_contexts",
    "mean_regret",
    "max_regret",
    "proxy_selected_count",
    "unsafe_proxy_selected_count",
    "zero_regret_context_count",
])}

Direct proxy override remains unsafe on this challenge set: mean regret
`{proxy["mean_regret"]:.3f}` versus dense-anchor `{dense["mean_regret"]:.3f}`.
A naive small-delta rule (`<=2us`) gives mean regret `{small_delta["mean_regret"]:.3f}`,
which is not better than dense-anchor because near-tie delay behavior is
non-monotonic.  The R031 switching-calibrated candidate blocks the high-risk
`20A/score_settle005 -> 66us` override and only permits the `10A/score_settle010`
proxy in locally observed winning subbands.  It reaches mean regret
`{tightened["mean_regret"]:.3f}`, but it is a calibration candidate and must be
held-out tested.  The pair oracle `{oracle["mean_regret"]:.3f}` is a non-deployable
lower bound.

## Tightened Projection Rules

{md_table(rules, [
    "target_label",
    "objective",
    "risk_category",
    "B_epsilon_sw_rule",
    "allowed_proxy_condition",
    "blocked_proxy_condition",
])}

## Minimal Follow-Up Validation Matrix

The next derived-Simulink check should be small and targeted.  It should test
intermediate slopes rather than re-run the already completed dense/proxy pairs.
The generated plan has `{len(plan)}` rows and is saved as
`iqcot_r031_minimal_validation_plan.csv`.

{md_table(plan.head(12), [
    "r031_case_id",
    "target_label",
    "objective",
    "tau_ai_us",
    "candidate_ref_slew_us",
    "reference_baseline_slew_us",
    "priority",
])}

## Claim Boundary

R031 does not prove dense-anchor is globally optimal and does not prove the
proxy is useless.  It narrows the deployable interface: proxy or AI should
generate score/risk candidates, while `B_epsilon^sw` blocks unverified override
actions unless short-horizon event risk prediction can justify them.  All
evidence remains derived-Simulink or offline post-processing, not hardware
validation.
"""
    REPORT.write_text(report, encoding="utf-8")

    paper = f"""## R031：由负样本收紧的 `B_epsilon^sw` 安全投影

R030 dense-anchor challenge 表明，离线 proxy 可以提出候选，但不能直接覆盖
dense-anchor。为了把这一负面证据转成可部署设计，本文进一步构造 R031
switching-calibrated projection 原型。该原型不新增 `.slx` 仿真，而是把
R030 的 `15` 个成对上下文整理为 pair-level risk features，并比较 direct
proxy、dense-anchor、small-delta rule、R031 tightened projection 和 pair
oracle 上界。

结果显示，direct proxy override 的 mean regret 为 `{proxy["mean_regret"]:.3f}`，
高于 dense-anchor 的 `{dense["mean_regret"]:.3f}`；单纯允许小斜率差 proxy
也只有 `{small_delta["mean_regret"]:.3f}`，说明近似并列带仍存在延迟非单调。
R031 tightened projection 将 `20A/score_settle005` 的 `66us` 标为 large-jump
settling-sensitive 负样本，同时只在 `10A/score_settle010` 的已观测 near-tie
子带中保留 proxy 候选，得到 `{tightened["mean_regret"]:.3f}` 的校准集
mean regret。这个数值不能作为独立泛化证明；它的意义是说明 `B_epsilon^sw`
可以由开关级负样本收紧，并为下一轮少量 held-out 派生仿真提供候选矩阵。

因此，PIS-IEK 支持的 AI 角色应进一步限定为“候选 score/risk 生成器 +
mode-aware safety projection”。AI 不替代 IQCOT 内环，不直接输出 gate
command，也不应把 R031 的离线投影候选写成硬件验证结果。
"""
    PAPER.write_text(paper, encoding="utf-8")


def main() -> None:
    rows, context, motif = read_inputs()
    features = build_pair_features(rows, context, motif)
    eval_df, summary = evaluate_policies(features)
    rules = build_rules(motif)
    plan = build_validation_plan()

    features.to_csv(PAIR_FEATURES, index=False)
    eval_df.to_csv(POLICY_EVAL, index=False)
    summary.to_csv(POLICY_SUMMARY, index=False)
    rules.to_csv(RULES, index=False)
    plan.to_csv(VALIDATION_PLAN, index=False)
    write_svg(summary, rules)
    write_reports(summary, rules, plan)

    print(f"Wrote {PAIR_FEATURES}")
    print(f"Wrote {POLICY_EVAL}")
    print(f"Wrote {POLICY_SUMMARY}")
    print(f"Wrote {RULES}")
    print(f"Wrote {VALIDATION_PLAN}")
    print(f"Wrote {REPORT}")
    print(f"Wrote {PAPER}")
    print(f"Wrote {SVG}")


if __name__ == "__main__":
    main()
