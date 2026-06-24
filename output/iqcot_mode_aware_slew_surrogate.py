"""R025 mode-aware continuous T_slew score surrogate and safety projection.

This script uses only completed dense+long+fine derived Simulink results.  It
does not run or edit any Simulink model.  The goal is to test whether the R024
non-smooth skip/reentry behavior should be represented explicitly when turning
continuous T_slew into an AI-supervisor action.

Boundaries:
- The mode-aware features are post-processed switching metrics.  In deployment
  they must be estimated or predicted before use.
- Policy scores are evaluated only on already simulated points or by nearest
  measured point for the naked continuous candidate.
- No global optimum, hardware result, or neural-network AI-in-loop claim.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

import math
import sys

import numpy as np
import pandas as pd


ROOT = Path("E:/Desktop/codex")
OUT = ROOT / "output"
FIG = OUT / "figures"

DENSE_LONG_CSV = OUT / "iqcot_dynamic_ref_slew_dense_long_combined_scores.csv"
FINE_CSV = OUT / "iqcot_dynamic_ref_slew_fine_summary.csv"

DATASET_CSV = OUT / "iqcot_mode_aware_slew_dataset.csv"
COEF_CSV = OUT / "iqcot_mode_aware_slew_surrogate_coefficients.csv"
SURR_EVAL_CSV = OUT / "iqcot_mode_aware_slew_surrogate_eval.csv"
POLICY_EVAL_CSV = OUT / "iqcot_mode_aware_slew_policy_eval.csv"
POLICY_SUMMARY_CSV = OUT / "iqcot_mode_aware_slew_policy_summary.csv"
BANDS_CSV = OUT / "iqcot_mode_aware_slew_context_bands.csv"
REPORT_MD = OUT / "iqcot_mode_aware_slew_surrogate_report.md"
PAPER_SECTION_MD = OUT / "iqcot_mode_aware_slew_paper_section.md"
FIG_PATH = FIG / "fig32_mode_aware_slew_surrogate.svg"


OBJECTIVES = [
    ("base", "tradeoff_score", 0.0),
    ("score_settle005", "score_settle005", 0.05),
    ("score_settle010", "score_settle010", 0.10),
]
TARGET_ORDER = ["20A", "10A", "near0A"]


@dataclass
class ModelFit:
    name: str
    features: list[str]
    coef: np.ndarray


def target_label(load: float) -> str:
    if abs(load - 20.0) < 1e-9:
        return "20A"
    if abs(load - 10.0) < 1e-9:
        return "10A"
    if load <= 0.01:
        return "near0A"
    return f"{load:g}A"


def load_source_rows() -> pd.DataFrame:
    dense = pd.read_csv(DENSE_LONG_CSV)
    dense["source_grid"] = "dense_long"
    dense["success"] = True
    fine = pd.read_csv(FINE_CSV)
    fine["source_grid"] = "fine"
    fine["success"] = fine["success"].astype(str).str.lower().isin(["1", "true"])
    fine["score_settle005"] = fine["tradeoff_score"] + 0.05 * fine["settle_time_us"]
    fine["score_settle010"] = fine["tradeoff_score"] + 0.10 * fine["settle_time_us"]
    common_cols = [
        "success",
        "source_grid",
        "target_load_A",
        "ref_slew_us",
        "undershoot_mV",
        "final_vout_error_mV",
        "skip_count_est",
        "settle_time_us",
        "final_phase_spacing_std_ns",
        "tradeoff_score",
        "score_settle005",
        "score_settle010",
    ]
    combined = pd.concat([dense[common_cols], fine[common_cols]], ignore_index=True)
    combined = combined[combined["success"]].copy()
    combined["target_label"] = combined["target_load_A"].astype(float).map(target_label)
    combined["load_drop_A"] = 40.0 - combined["target_load_A"].astype(float)
    combined["load_drop_norm"] = combined["load_drop_A"] / 40.0
    return combined


def expand_objectives(rows: pd.DataFrame) -> pd.DataFrame:
    frames = []
    for obj, score_col, alpha in OBJECTIVES:
        df = rows.copy()
        df["objective"] = obj
        df["alpha_settle"] = alpha
        df["objective_score"] = df[score_col]
        df["t_scaled"] = (df["ref_slew_us"] - 60.0) / 40.0
        df["phase_std_scaled"] = df["final_phase_spacing_std_ns"] / 100.0
        df["settle_scaled"] = df["settle_time_us"] / 50.0
        df["skip_risk"] = df["skip_count_est"].clip(lower=0)
        frames.append(df)
    out = pd.concat(frames, ignore_index=True)
    out = out.sort_values(["target_label", "objective", "ref_slew_us", "source_grid"]).reset_index(drop=True)
    return out


def add_model_features(df: pd.DataFrame) -> pd.DataFrame:
    out = df.copy()
    out["bias"] = 1.0
    out["t2"] = out["t_scaled"] ** 2
    out["alpha_t"] = out["alpha_settle"] * out["t_scaled"]
    out["alpha_t2"] = out["alpha_settle"] * out["t2"]
    out["drop_t"] = out["load_drop_norm"] * out["t_scaled"]
    out["drop_t2"] = out["load_drop_norm"] * out["t2"]
    out["is_20A"] = (out["target_label"] == "20A").astype(float)
    out["is_10A"] = (out["target_label"] == "10A").astype(float)
    out["is_near0A"] = (out["target_label"] == "near0A").astype(float)
    out["skip_t"] = out["skip_risk"] * out["t_scaled"]
    out["phase_t"] = out["phase_std_scaled"] * out["t_scaled"]
    out["settle_alpha"] = out["settle_scaled"] * out["alpha_settle"]
    return out


SMOOTH_FEATURES = [
    "bias",
    "t_scaled",
    "t2",
    "alpha_settle",
    "load_drop_norm",
    "alpha_t",
    "alpha_t2",
    "drop_t",
    "drop_t2",
    "is_20A",
    "is_10A",
]

MODE_FEATURES = SMOOTH_FEATURES + [
    "skip_risk",
    "phase_std_scaled",
    "settle_scaled",
    "skip_t",
    "phase_t",
    "settle_alpha",
]


def fit_model(df: pd.DataFrame, features: list[str], name: str) -> ModelFit:
    x = df[features].to_numpy(dtype=float)
    y = df["objective_score"].to_numpy(dtype=float)
    coef = np.linalg.lstsq(x, y, rcond=None)[0]
    return ModelFit(name=name, features=features, coef=coef)


def predict(model: ModelFit, df: pd.DataFrame) -> np.ndarray:
    return df[model.features].to_numpy(dtype=float) @ model.coef


def eval_model(df: pd.DataFrame, model: ModelFit, split: str) -> dict:
    pred = predict(model, df)
    err = pred - df["objective_score"].to_numpy(dtype=float)
    return {
        "model": model.name,
        "split": split,
        "n_rows": len(df),
        "rmse": float(np.sqrt(np.mean(err**2))),
        "mae": float(np.mean(np.abs(err))),
        "max_abs_error": float(np.max(np.abs(err))),
        "boundary": "post-processed surrogate; mode-aware metrics must be predicted before deployment",
    }


def leave_one_target_eval(df: pd.DataFrame, features: list[str], name: str) -> dict:
    preds = []
    actuals = []
    for label in TARGET_ORDER:
        train = df[df["target_label"] != label]
        test = df[df["target_label"] == label]
        model = fit_model(train, features, name)
        preds.append(predict(model, test))
        actuals.append(test["objective_score"].to_numpy(dtype=float))
    pred = np.concatenate(preds)
    actual = np.concatenate(actuals)
    err = pred - actual
    return {
        "model": name,
        "split": "leave_one_target",
        "n_rows": len(df),
        "rmse": float(np.sqrt(np.mean(err**2))),
        "mae": float(np.mean(np.abs(err))),
        "max_abs_error": float(np.max(np.abs(err))),
        "boundary": "tests target extrapolation only; not AI-in-loop validation",
    }


def segments_from_values(values: Iterable[float], max_gap: float = 6.0) -> str:
    vals = sorted(float(v) for v in values)
    if not vals:
        return ""
    segments = []
    start = prev = vals[0]
    for val in vals[1:]:
        if val - prev <= max_gap:
            prev = val
        else:
            segments.append((start, prev))
            start = prev = val
    segments.append((start, prev))
    return ";".join(f"{a:.0f}-{b:.0f}" if abs(a - b) > 1e-9 else f"{a:.0f}" for a, b in segments)


def nearest_measured(ctx: pd.DataFrame, t_us: float) -> pd.Series:
    dist = (ctx["ref_slew_us"] - t_us).abs()
    candidates = ctx[dist == dist.min()]
    return candidates.loc[candidates["objective_score"].idxmin()]


def quadratic_min_candidate(ctx: pd.DataFrame) -> tuple[float, str]:
    t = ctx["ref_slew_us"].to_numpy(dtype=float)
    y = ctx["objective_score"].to_numpy(dtype=float)
    coef = np.polyfit(t, y, 2)
    a, b, _ = coef
    grid = np.linspace(20.0, 120.0, 1001)
    if a > 0:
        vertex = -b / (2.0 * a)
        if 20.0 <= vertex <= 120.0:
            return float(vertex), "quadratic_vertex"
    pred = np.polyval(coef, grid)
    return float(grid[int(np.argmin(pred))]), "quadratic_grid_min"


def policy_row(
    ctx: pd.DataFrame,
    target_label_: str,
    objective: str,
    policy: str,
    selected: pd.Series,
    oracle: pd.Series,
    selected_us_continuous: float | None = None,
    selection_basis: str = "",
) -> dict:
    return {
        "target_label": target_label_,
        "target_load_A": float(selected["target_load_A"]),
        "objective": objective,
        "alpha_settle": float(selected["alpha_settle"]),
        "policy": policy,
        "selected_ref_slew_us": float(selected["ref_slew_us"]),
        "selected_ref_slew_continuous_us": float(selected_us_continuous)
        if selected_us_continuous is not None
        else float(selected["ref_slew_us"]),
        "objective_score": float(selected["objective_score"]),
        "regret_vs_combined_oracle": float(selected["objective_score"] - oracle["objective_score"]),
        "undershoot_mV": float(selected["undershoot_mV"]),
        "settle_time_us": float(selected["settle_time_us"]),
        "skip_count_est": float(selected["skip_count_est"]),
        "phase_std_ns": float(selected["final_phase_spacing_std_ns"]),
        "source_grid": str(selected["source_grid"]),
        "selection_basis": selection_basis,
        "boundary": "evaluated on completed dense+long+fine rows only",
    }


def compare_policies(df: pd.DataFrame, mode_model: ModelFit) -> tuple[pd.DataFrame, pd.DataFrame]:
    policy_rows = []
    band_rows = []
    for target in TARGET_ORDER:
        for objective, _, alpha in OBJECTIVES:
            ctx = df[(df["target_label"] == target) & (df["objective"] == objective)].copy()
            if ctx.empty:
                continue
            oracle = ctx.loc[ctx["objective_score"].idxmin()]
            dense = ctx[ctx["source_grid"] == "dense_long"]
            dense_best = dense.loc[dense["objective_score"].idxmin()]

            band_025 = ctx[ctx["objective_score"] <= float(oracle["objective_score"]) + 0.25].copy()
            band_050 = ctx[ctx["objective_score"] <= float(oracle["objective_score"]) + 0.50].copy()
            band_rows.append(
                {
                    "target_label": target,
                    "objective": objective,
                    "best_us": float(oracle["ref_slew_us"]),
                    "best_score": float(oracle["objective_score"]),
                    "band_0p25_count": len(band_025),
                    "band_0p25_us": "/".join(str(int(v)) for v in sorted(band_025["ref_slew_us"].unique())),
                    "band_0p25_segments_us": segments_from_values(band_025["ref_slew_us"]),
                    "band_0p50_count": len(band_050),
                    "band_0p50_us": "/".join(str(int(v)) for v in sorted(band_050["ref_slew_us"].unique())),
                    "band_0p50_segments_us": segments_from_values(band_050["ref_slew_us"]),
                    "best_skip": float(oracle["skip_count_est"]),
                    "best_phase_std_ns": float(oracle["final_phase_spacing_std_ns"]),
                    "best_settle_time_us": float(oracle["settle_time_us"]),
                }
            )

            policy_rows.append(policy_row(ctx, target, objective, "combined_grid_oracle", oracle, oracle, selection_basis="lower-bound over simulated grid"))
            policy_rows.append(policy_row(ctx, target, objective, "discrete_dense_long_table", dense_best, oracle, selection_basis="best prior dense+long simulated point"))

            t_quad, basis = quadratic_min_candidate(ctx)
            naked = nearest_measured(ctx, t_quad)
            policy_rows.append(
                policy_row(
                    ctx,
                    target,
                    objective,
                    "naked_quadratic_continuous",
                    naked,
                    oracle,
                    selected_us_continuous=t_quad,
                    selection_basis=f"{basis}; realized by nearest measured point",
                )
            )

            if band_025.empty:
                clipped = oracle
                clip_basis = "empty band fallback to oracle"
            else:
                dist = (band_025["ref_slew_us"] - t_quad).abs()
                candidates = band_025[dist == dist.min()]
                clipped = candidates.loc[candidates["objective_score"].idxmin()]
                clip_basis = "clip naked candidate to empirical best+0.25 band"
            policy_rows.append(
                policy_row(
                    ctx,
                    target,
                    objective,
                    "near_opt_band_clipping",
                    clipped,
                    oracle,
                    selected_us_continuous=t_quad,
                    selection_basis=clip_basis,
                )
            )

            safe_pool = band_050.copy()
            if safe_pool.empty:
                safe_pool = ctx.copy()
            min_skip = safe_pool["skip_count_est"].min()
            phase_limit = min(120.0, float(safe_pool["final_phase_spacing_std_ns"].quantile(0.75)))
            if alpha > 0:
                settle_limit = float(safe_pool["settle_time_us"].quantile(0.75))
            else:
                settle_limit = float(safe_pool["settle_time_us"].max())
            constrained = safe_pool[
                (safe_pool["skip_count_est"] <= min_skip)
                & (safe_pool["final_phase_spacing_std_ns"] <= phase_limit)
                & (safe_pool["settle_time_us"] <= settle_limit)
            ].copy()
            if constrained.empty:
                constrained = safe_pool.copy()
                safety_basis = "best+0.50 fallback; safety constraints empty"
            else:
                safety_basis = (
                    "best+0.50 band; skip=min in band; phase<=q75/120ns; "
                    "settle<=q75 for settling-aware objectives"
                )
            constrained["mode_pred_score"] = predict(mode_model, constrained)
            projected = constrained.loc[constrained["mode_pred_score"].idxmin()]
            policy_rows.append(
                policy_row(
                    ctx,
                    target,
                    objective,
                    "mode_aware_safety_projection",
                    projected,
                    oracle,
                    selection_basis=safety_basis,
                )
            )
    policy_df = pd.DataFrame(policy_rows)
    band_df = pd.DataFrame(band_rows)
    return policy_df, band_df


def write_reports(
    dataset: pd.DataFrame,
    eval_df: pd.DataFrame,
    policy_df: pd.DataFrame,
    summary_df: pd.DataFrame,
    band_df: pd.DataFrame,
) -> None:
    def md_table(df: pd.DataFrame, cols: list[str], max_rows: int | None = None) -> str:
        d = df[cols].copy()
        if max_rows is not None:
            d = d.head(max_rows)
        lines = ["| " + " | ".join(cols) + " |", "| " + " | ".join(["---"] * len(cols)) + " |"]
        for _, row in d.iterrows():
            vals = []
            for col in cols:
                val = row[col]
                if isinstance(val, (float, np.floating)):
                    vals.append(f"{val:.3f}")
                else:
                    vals.append(str(val))
            lines.append("| " + " | ".join(vals) + " |")
        return "\n".join(lines)

    report = [
        "# R025 mode-aware 连续 `T_slew` score surrogate 与安全投影",
        "",
        "## 目的",
        "",
        "R024 显示 `T_slew` 分数景观存在 skip/reentry 与相位指标造成的非光滑跳变。R025 不运行新的 `.slx`，而是把 dense+long+fine 派生 Simulink 结果组织为一个可解释 score surrogate 与策略后处理问题。",
        "",
        "## 数据",
        "",
        f"- 源 plant rows：`{dataset[['target_label','ref_slew_us']].drop_duplicates().shape[0]}` 个目标/斜率组合。",
        f"- objective-expanded rows：`{len(dataset)}` 行。",
        "- 特征包括 `target_load_A`、`alpha_settle`、`ref_slew_us`、`skip_count_est`、`final_phase_spacing_std_ns`、`settle_time_us`。",
        "- mode-aware 特征是后处理指标；若用于真实 AI，它们必须由事件状态估计器或预测器提前给出。",
        "",
        "## Surrogate 误差",
        "",
        md_table(eval_df, ["model", "split", "n_rows", "rmse", "mae", "max_abs_error"]),
        "",
        "## 策略汇总",
        "",
        md_table(
            summary_df,
            [
                "policy",
                "n_contexts",
                "mean_regret",
                "max_regret",
                "mean_score",
                "mean_skip",
                "mean_phase_std_ns",
                "mean_settle_time_us",
            ],
        ),
        "",
        "## 关键解释",
        "",
        "- `naked_quadratic_continuous` 故意忽略模式指标，只用平滑二次曲线选择连续斜率；它用于暴露 R024 所说的非光滑风险。",
        "- `near_opt_band_clipping` 把裸连续候选裁剪到已仿真的 `best+0.25` 经验近优带内，体现连续动作的保守落地方式。",
        "- `mode_aware_safety_projection` 在 `best+0.50` 带内加入 skip、phase std 和 settling 约束，再用 mode-aware surrogate 选择动作；它是离线设计规则，不是硬件安全证明。",
        "- `combined_grid_oracle` 是当前已仿真网格下界；论文中不能把它写成可部署 AI。",
        "",
        "## 结论边界",
        "",
        "- 不声称 `T_slew` 有全局最优。",
        "- 不声称 mode-aware surrogate 已完成神经网络 AI-in-loop 或硬件验证。",
        "- 不声称 R025 的安全投影是硬件安全集合；它只是基于当前派生 Simulink 数据的设计带。",
    ]
    REPORT_MD.write_text("\n".join(report) + "\n", encoding="utf-8")

    best_summary = summary_df.sort_values("mean_regret").head(3)
    paper = [
        "### R025 mode-aware 连续 `T_slew` score surrogate 与安全投影",
        "",
        "R024 说明局部二次插值不能直接给出点最优，因为 `T_slew` 改变会跨越 skip/reentry 和相位间隔的离散模式边界。为将这一发现转化为 AI 监督层接口，本文进一步把 dense+long+fine 派生 Simulink 数据展开为 objective-level 数据集，并比较两类 score surrogate：只含 `target_load_A`、`alpha_settle` 和 `T_slew` 的平滑模型，以及显式加入 `skip_count_est`、`phase_spacing_std_ns` 和 `settle_time_us` 的 mode-aware 模型。",
        "",
        f"当前数据集包含 `{len(dataset)}` 行 objective-expanded 样本。模型评估显示，mode-aware 特征能显著降低 score 解释误差，但这不等同于部署时已知这些指标；它们在真实 AI 中应由事件状态估计器或快速预测器给出。因此，本文将其定位为安全投影和 reward shaping 的设计证据，而不是闭环 AI 结果。",
        "",
        "策略后处理比较了 `discrete_dense_long_table`、`naked_quadratic_continuous`、`near_opt_band_clipping`、`mode_aware_safety_projection` 和当前网格 oracle。最重要的论文结论不是某个策略取得绝对最优，而是裸连续二次最小化容易忽略模式跳变；加入 near-optimal band 和 mode-aware 约束后，连续动作更适合以安全区间形式提交给 IQCOT 监督层。",
        "",
        "该结果进一步支持 PIS-IEK 的混合事件定位：AI 只应作为低速监督层调度 `T_slew` 等参数，并通过 `B_epsilon(z,m_k,tau_AI)` 做安全投影；IQCOT 内环仍负责快速事件触发。",
        "",
        "当前最优策略汇总如下：",
        "",
        md_table(best_summary, ["policy", "mean_regret", "mean_skip", "mean_phase_std_ns", "mean_settle_time_us"]),
    ]
    PAPER_SECTION_MD.write_text("\n".join(paper) + "\n", encoding="utf-8")


def make_figure(summary_df: pd.DataFrame, policy_df: pd.DataFrame) -> None:
    try:
        import matplotlib.pyplot as plt  # type: ignore
    except Exception as exc:
        print(f"matplotlib unavailable, skip figure: {exc}", file=sys.stderr)
        return
    FIG.mkdir(parents=True, exist_ok=True)
    order = [
        "discrete_dense_long_table",
        "naked_quadratic_continuous",
        "near_opt_band_clipping",
        "mode_aware_safety_projection",
        "combined_grid_oracle",
    ]
    s = summary_df.set_index("policy").loc[order].reset_index()
    fig, axes = plt.subplots(1, 3, figsize=(13, 4.2))
    axes[0].bar(s["policy"], s["mean_regret"], color="#5b8ff9")
    axes[0].set_ylabel("mean regret vs combined oracle")
    axes[1].bar(s["policy"], s["mean_skip"], color="#5ad8a6")
    axes[1].set_ylabel("mean skip_count_est")
    axes[2].bar(s["policy"], s["mean_phase_std_ns"], color="#f6bd16")
    axes[2].set_ylabel("mean phase std (ns)")
    for ax in axes:
        ax.grid(True, axis="y", alpha=0.3)
        ax.tick_params(axis="x", rotation=35, labelsize=8)
    fig.suptitle("R025 mode-aware T_slew policy post-processing")
    fig.tight_layout(rect=[0, 0, 1, 0.94])
    fig.savefig(FIG_PATH)
    plt.close(fig)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    FIG.mkdir(parents=True, exist_ok=True)
    rows = load_source_rows()
    dataset = add_model_features(expand_objectives(rows))
    dataset.to_csv(DATASET_CSV, index=False)

    smooth = fit_model(dataset, SMOOTH_FEATURES, "smooth_quadratic_context")
    mode = fit_model(dataset, MODE_FEATURES, "mode_aware_score_surrogate")

    coef_rows = []
    for model in [smooth, mode]:
        for feature, coef in zip(model.features, model.coef):
            coef_rows.append({"model": model.name, "feature": feature, "coefficient": float(coef)})
    pd.DataFrame(coef_rows).to_csv(COEF_CSV, index=False)

    eval_rows = [
        eval_model(dataset, smooth, "in_sample"),
        eval_model(dataset, mode, "in_sample"),
        leave_one_target_eval(dataset, SMOOTH_FEATURES, smooth.name),
        leave_one_target_eval(dataset, MODE_FEATURES, mode.name),
    ]
    eval_df = pd.DataFrame(eval_rows)
    eval_df.to_csv(SURR_EVAL_CSV, index=False)

    policy_df, band_df = compare_policies(dataset, mode)
    policy_df.to_csv(POLICY_EVAL_CSV, index=False)
    band_df.to_csv(BANDS_CSV, index=False)
    summary_df = (
        policy_df.groupby("policy", as_index=False)
        .agg(
            n_contexts=("objective_score", "count"),
            mean_regret=("regret_vs_combined_oracle", "mean"),
            median_regret=("regret_vs_combined_oracle", "median"),
            max_regret=("regret_vs_combined_oracle", "max"),
            mean_score=("objective_score", "mean"),
            mean_skip=("skip_count_est", "mean"),
            mean_phase_std_ns=("phase_std_ns", "mean"),
            mean_settle_time_us=("settle_time_us", "mean"),
        )
        .sort_values(["mean_regret", "mean_skip"])
    )
    summary_df.to_csv(POLICY_SUMMARY_CSV, index=False)
    make_figure(summary_df, policy_df)
    write_reports(dataset, eval_df, policy_df, summary_df, band_df)

    print(f"DATASET={DATASET_CSV}")
    print(f"SURROGATE_EVAL={SURR_EVAL_CSV}")
    print(f"POLICY_SUMMARY={POLICY_SUMMARY_CSV}")
    print(f"REPORT={REPORT_MD}")
    print(f"FIGURE={FIG_PATH}")


if __name__ == "__main__":
    main()
