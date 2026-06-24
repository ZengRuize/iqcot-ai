"""R026 deployable risk proxy for four-phase IQCOT T_slew supervision.

This script uses completed dense+long+fine derived Simulink results only. It
does not run or edit any Simulink model.  The goal is to separate two ideas:

1. posterior mode-aware metrics from R025, which are not directly available to
   an online AI supervisor; and
2. a deployable proxy interface, where risk information must come from an
   offline calibrated table or a short-horizon predictor using features known
   before committing T_slew.

Boundaries:
- The calibrated proxy table is a deployment design artifact, not hardware
  validation.
- It is evaluated on the same completed simulation grid, so it demonstrates an
  interface and a ranking check, not cross-load generalization.
- The parametric-only proxy is kept as an ablation: it shows why a smooth
  model of target/load/T_slew alone is not sufficient near skip/reentry
  discontinuities.
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

R025_DATASET_CSV = OUT / "iqcot_mode_aware_slew_dataset.csv"
R025_POLICY_EVAL_CSV = OUT / "iqcot_mode_aware_slew_policy_eval.csv"

PROXY_DATASET_CSV = OUT / "iqcot_deployable_risk_proxy_dataset.csv"
PROXY_FIT_EVAL_CSV = OUT / "iqcot_deployable_risk_proxy_fit_eval.csv"
POLICY_EVAL_CSV = OUT / "iqcot_deployable_proxy_policy_eval.csv"
POLICY_SUMMARY_CSV = OUT / "iqcot_deployable_proxy_policy_summary.csv"
POLICY_BY_TAU_CSV = OUT / "iqcot_deployable_proxy_policy_by_tau.csv"
RISK_TABLE_CSV = OUT / "iqcot_deployable_risk_proxy_table.csv"
REPORT_MD = OUT / "iqcot_deployable_risk_proxy_report.md"
PAPER_SECTION_MD = OUT / "iqcot_deployable_risk_proxy_paper_section.md"
FIG_PATH = FIG / "fig33_deployable_proxy_policy.svg"

OBJECTIVES = [
    ("base", 0.0),
    ("score_settle005", 0.05),
    ("score_settle010", 0.10),
]
TARGET_ORDER = ["20A", "10A", "near0A"]
TAU_GRID_US = [0.0, 0.5, 1.0, 2.0, 5.0]
T_EVENT_US = 0.5


@dataclass
class LinearFit:
    name: str
    features: list[str]
    coef: np.ndarray


def delay_events(tau_us: float) -> int:
    return int(math.ceil(tau_us / T_EVENT_US - 1e-12))


def deployable_features(df: pd.DataFrame, tau_us: float = 0.0) -> pd.DataFrame:
    """Features available before committing the supervisory action."""
    out = pd.DataFrame(index=df.index)
    t = (df["ref_slew_us"].astype(float) - 60.0) / 40.0
    d = delay_events(tau_us) / 10.0
    out["bias"] = 1.0
    out["t_scaled"] = t
    out["t2"] = t * t
    out["alpha_settle"] = df["alpha_settle"].astype(float)
    out["load_drop_norm"] = df["load_drop_norm"].astype(float)
    out["alpha_t"] = out["alpha_settle"] * t
    out["alpha_t2"] = out["alpha_settle"] * t * t
    out["drop_t"] = out["load_drop_norm"] * t
    out["drop_t2"] = out["load_drop_norm"] * t * t
    out["is_20A"] = (df["target_label"] == "20A").astype(float)
    out["is_10A"] = (df["target_label"] == "10A").astype(float)
    out["delay_events_scaled"] = d
    out["delay_t"] = d * t
    return out


DEPLOYABLE_FEATURES = [
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
    "delay_events_scaled",
    "delay_t",
]


def fit_linear(df: pd.DataFrame, y_col: str, name: str, tau_us: float = 0.0) -> LinearFit:
    x = deployable_features(df, tau_us)[DEPLOYABLE_FEATURES].to_numpy(dtype=float)
    y = df[y_col].to_numpy(dtype=float)
    coef = np.linalg.lstsq(x, y, rcond=None)[0]
    return LinearFit(name=name, features=DEPLOYABLE_FEATURES, coef=coef)


def predict_linear(model: LinearFit, df: pd.DataFrame, tau_us: float = 0.0) -> np.ndarray:
    x = deployable_features(df, tau_us)[model.features].to_numpy(dtype=float)
    return x @ model.coef


def rmse(y: np.ndarray, pred: np.ndarray) -> float:
    return float(np.sqrt(np.mean((pred - y) ** 2)))


def mae(y: np.ndarray, pred: np.ndarray) -> float:
    return float(np.mean(np.abs(pred - y)))


def load_dataset() -> pd.DataFrame:
    df = pd.read_csv(R025_DATASET_CSV)
    numeric_cols = [
        "target_load_A",
        "load_drop_norm",
        "alpha_settle",
        "ref_slew_us",
        "objective_score",
        "undershoot_mV",
        "settle_time_us",
        "skip_count_est",
        "final_phase_spacing_std_ns",
    ]
    for col in numeric_cols:
        df[col] = pd.to_numeric(df[col])
    df["delay_available_online"] = False
    df["proxy_boundary"] = (
        "post-event metrics are labels/calibration targets; online policy may use "
        "only target/load/objective/T_slew/tau and precomputed proxy values"
    )
    return df


def plant_rows(df: pd.DataFrame) -> pd.DataFrame:
    cols = [
        "target_label",
        "target_load_A",
        "load_drop_norm",
        "ref_slew_us",
        "skip_count_est",
        "final_phase_spacing_std_ns",
        "settle_time_us",
        "undershoot_mV",
        "source_grid",
    ]
    plant = df[cols].drop_duplicates(["target_label", "ref_slew_us"]).copy()
    min_skip = plant.groupby("target_label")["skip_count_est"].min().to_dict()
    plant["baseline_skip_count"] = plant["target_label"].map(min_skip)
    plant["excess_skip_count"] = (plant["skip_count_est"] - plant["baseline_skip_count"]).clip(lower=0)
    plant["alpha_settle"] = 0.0
    return plant


def classification_metrics(y_true: np.ndarray, y_score: np.ndarray, threshold: float = 0.5) -> dict[str, float]:
    y_pred = y_score >= threshold
    y_bool = y_true > 0.5
    tp = float(np.sum(y_pred & y_bool))
    tn = float(np.sum(~y_pred & ~y_bool))
    fp = float(np.sum(y_pred & ~y_bool))
    fn = float(np.sum(~y_pred & y_bool))
    precision = tp / (tp + fp) if (tp + fp) else 0.0
    recall = tp / (tp + fn) if (tp + fn) else 0.0
    accuracy = (tp + tn) / max(1.0, tp + tn + fp + fn)
    return {
        "accuracy": accuracy,
        "precision": precision,
        "recall": recall,
        "tp": tp,
        "fp": fp,
        "tn": tn,
        "fn": fn,
    }


def fit_eval(df: pd.DataFrame, plant: pd.DataFrame) -> tuple[pd.DataFrame, dict[str, LinearFit]]:
    score_model = fit_linear(df, "objective_score", "deployable_score_smooth")
    phase_model = fit_linear(plant, "final_phase_spacing_std_ns", "parametric_phase_proxy")
    settle_model = fit_linear(plant, "settle_time_us", "parametric_settle_proxy")
    skip_model = fit_linear(plant, "excess_skip_count", "parametric_excess_skip_proxy")
    models = {
        "score": score_model,
        "phase": phase_model,
        "settle": settle_model,
        "skip": skip_model,
    }

    rows: list[dict[str, object]] = []
    score_pred = predict_linear(score_model, df)
    rows.append(
        {
            "model": score_model.name,
            "target": "objective_score",
            "split": "in_sample",
            "n_rows": len(df),
            "rmse": rmse(df["objective_score"].to_numpy(float), score_pred),
            "mae": mae(df["objective_score"].to_numpy(float), score_pred),
            "accuracy": np.nan,
            "precision": np.nan,
            "recall": np.nan,
            "boundary": "uses deployable context only; smooth fit cannot represent mode jumps",
        }
    )
    for name, model, y_col in [
        ("phase", phase_model, "final_phase_spacing_std_ns"),
        ("settle", settle_model, "settle_time_us"),
        ("skip", skip_model, "excess_skip_count"),
    ]:
        pred = predict_linear(model, plant)
        if name == "skip":
            cls = classification_metrics(plant[y_col].to_numpy(float), np.clip(pred, 0.0, 1.0))
            rows.append(
                {
                    "model": model.name,
                    "target": y_col,
                    "split": "in_sample",
                    "n_rows": len(plant),
                    "rmse": rmse(plant[y_col].to_numpy(float), pred),
                    "mae": mae(plant[y_col].to_numpy(float), pred),
                    **cls,
                    "boundary": "linear probability proxy; kept as ablation, not final safety evidence",
                }
            )
        else:
            rows.append(
                {
                    "model": model.name,
                    "target": y_col,
                    "split": "in_sample",
                    "n_rows": len(plant),
                    "rmse": rmse(plant[y_col].to_numpy(float), pred),
                    "mae": mae(plant[y_col].to_numpy(float), pred),
                    "accuracy": np.nan,
                    "precision": np.nan,
                    "recall": np.nan,
                    "tp": np.nan,
                    "fp": np.nan,
                    "tn": np.nan,
                    "fn": np.nan,
                    "boundary": "parametric proxy only; discontinuities still require calibrated table or short-horizon predictor",
                }
            )

    # Leave-one-target shows whether these smooth deployable proxies generalize
    # without target-specific calibration.
    for target in TARGET_ORDER:
        train_df = df[df["target_label"] != target]
        test_df = df[df["target_label"] == target]
        train_plant = plant[plant["target_label"] != target]
        test_plant = plant[plant["target_label"] == target]
        if train_df.empty or test_df.empty:
            continue
        score_loto = fit_linear(train_df, "objective_score", "deployable_score_smooth")
        pred = predict_linear(score_loto, test_df)
        rows.append(
            {
                "model": "deployable_score_smooth",
                "target": "objective_score",
                "split": f"leave_one_target:{target}",
                "n_rows": len(test_df),
                "rmse": rmse(test_df["objective_score"].to_numpy(float), pred),
                "mae": mae(test_df["objective_score"].to_numpy(float), pred),
                "accuracy": np.nan,
                "precision": np.nan,
                "recall": np.nan,
                "boundary": "target extrapolation check; high error means calibration is required",
            }
        )
        for y_col, model_name in [
            ("final_phase_spacing_std_ns", "parametric_phase_proxy"),
            ("settle_time_us", "parametric_settle_proxy"),
            ("excess_skip_count", "parametric_excess_skip_proxy"),
        ]:
            model = fit_linear(train_plant, y_col, model_name)
            pred = predict_linear(model, test_plant)
            row: dict[str, object] = {
                "model": model_name,
                "target": y_col,
                "split": f"leave_one_target:{target}",
                "n_rows": len(test_plant),
                "rmse": rmse(test_plant[y_col].to_numpy(float), pred),
                "mae": mae(test_plant[y_col].to_numpy(float), pred),
                "boundary": "target extrapolation check; high error means calibration is required",
            }
            if y_col == "excess_skip_count":
                row.update(classification_metrics(test_plant[y_col].to_numpy(float), np.clip(pred, 0.0, 1.0)))
            else:
                row.update({"accuracy": np.nan, "precision": np.nan, "recall": np.nan, "tp": np.nan, "fp": np.nan, "tn": np.nan, "fn": np.nan})
            rows.append(row)

    return pd.DataFrame(rows), models


def proxy_table(plant: pd.DataFrame) -> pd.DataFrame:
    table = plant.copy()
    table["proxy_type"] = "offline_calibrated_grid_table"
    table["deployable_inputs"] = "target_load_A, load_drop_norm, ref_slew_us; tau_AI used as safety margin"
    table["deployment_boundary"] = (
        "usable as a precomputed supervisor table for measured grid points; "
        "interpolation and hardware transfer need separate validation"
    )
    return table


def policy_row(
    target_label: str,
    objective: str,
    tau_us: float,
    policy: str,
    selected: pd.Series,
    oracle: pd.Series,
    selected_continuous_us: float | None = None,
    selection_basis: str = "",
    online_available: bool = True,
) -> dict[str, object]:
    return {
        "target_label": target_label,
        "target_load_A": float(selected["target_load_A"]),
        "objective": objective,
        "alpha_settle": float(selected["alpha_settle"]),
        "tau_AI_us": tau_us,
        "delay_events": delay_events(tau_us),
        "policy": policy,
        "selected_ref_slew_us": float(selected["ref_slew_us"]),
        "selected_ref_slew_continuous_us": float(selected_continuous_us)
        if selected_continuous_us is not None
        else float(selected["ref_slew_us"]),
        "objective_score": float(selected["objective_score"]),
        "regret_vs_combined_oracle": float(selected["objective_score"] - oracle["objective_score"]),
        "undershoot_mV": float(selected["undershoot_mV"]),
        "settle_time_us": float(selected["settle_time_us"]),
        "skip_count_est": float(selected["skip_count_est"]),
        "phase_std_ns": float(selected["final_phase_spacing_std_ns"]),
        "source_grid": str(selected["source_grid"]),
        "selection_basis": selection_basis,
        "online_available_inputs_only": online_available,
        "boundary": "offline replay on completed dense+long+fine grid; not hardware validation",
    }


def lookup_r025_policy(r025_policy: pd.DataFrame, target: str, objective: str, policy: str) -> pd.Series:
    row = r025_policy[
        (r025_policy["target_label"] == target)
        & (r025_policy["objective"] == objective)
        & (r025_policy["policy"] == policy)
    ]
    if row.empty:
        raise KeyError(f"missing R025 policy {target}/{objective}/{policy}")
    return row.iloc[0]


def row_at_slew(ctx: pd.DataFrame, ref_slew_us: float) -> pd.Series:
    dist = (ctx["ref_slew_us"] - ref_slew_us).abs()
    candidates = ctx[dist == dist.min()]
    return candidates.loc[candidates["objective_score"].idxmin()]


def parametric_proxy_select(
    ctx: pd.DataFrame,
    plant: pd.DataFrame,
    models: dict[str, LinearFit],
    tau_us: float,
) -> tuple[pd.Series, str]:
    delay = delay_events(tau_us)
    cp = ctx.copy()
    cp["score_hat"] = predict_linear(models["score"], cp, tau_us)
    tmp = cp.copy()
    tmp["alpha_settle"] = 0.0
    cp["phase_hat"] = predict_linear(models["phase"], tmp, tau_us)
    cp["settle_hat"] = predict_linear(models["settle"], tmp, tau_us)
    cp["skip_excess_hat"] = np.clip(predict_linear(models["skip"], tmp, tau_us), 0.0, 1.0)

    target_plant = plant[plant["target_label"] == str(cp["target_label"].iloc[0])]
    phase_cap = float(target_plant["final_phase_spacing_std_ns"].quantile(0.75)) - 0.7 * delay
    if float(cp["alpha_settle"].iloc[0]) > 0:
        settle_cap = float(target_plant["settle_time_us"].quantile(0.50)) - 0.3 * delay
    else:
        settle_cap = float(target_plant["settle_time_us"].quantile(0.75)) - 0.2 * delay
    skip_cap = max(0.30, 0.55 - 0.02 * delay)

    alpha = float(cp["alpha_settle"].iloc[0])
    cp["risk_penalty"] = (
        1.6 * cp["skip_excess_hat"]
        + 0.025 * np.maximum(0.0, cp["phase_hat"] - phase_cap)
        + 0.08 * np.maximum(0.0, cp["settle_hat"] - settle_cap) * max(0.2, alpha * 10.0)
        + 0.005 * delay * np.maximum(0.0, 40.0 - cp["ref_slew_us"])
    )
    feasible = cp[
        (cp["skip_excess_hat"] <= skip_cap)
        & (cp["phase_hat"] <= phase_cap)
        & ((cp["settle_hat"] <= settle_cap) | (alpha == 0.0))
    ]
    if not feasible.empty:
        selected = feasible.loc[feasible["score_hat"].idxmin()]
        basis = "smooth deployable proxy feasible set"
    else:
        selected = cp.loc[(cp["score_hat"] + cp["risk_penalty"]).idxmin()]
        basis = "smooth deployable proxy penalty fallback"
    return selected, basis


def calibrated_proxy_select(
    ctx: pd.DataFrame,
    models: dict[str, LinearFit],
    tau_us: float,
) -> tuple[pd.Series, str]:
    """Select using online-available context plus an offline calibrated risk table.

    The risk values are not online measurements of the current event. They are
    calibration targets stored by target/ref_slew. This is the deployable
    approximation to R025 posterior mode-aware projection.
    """
    delay = delay_events(tau_us)
    cp = ctx.copy()
    cp["score_hat"] = predict_linear(models["score"], cp, tau_us)
    min_skip = float(cp["skip_count_est"].min())
    phase_cap = float(cp["final_phase_spacing_std_ns"].quantile(0.75)) - 0.5 * delay
    if float(cp["alpha_settle"].iloc[0]) > 0:
        settle_cap = float(cp["settle_time_us"].quantile(0.50)) - 0.3 * delay
    else:
        settle_cap = float(cp["settle_time_us"].quantile(0.75)) - 0.2 * delay
    alpha = float(cp["alpha_settle"].iloc[0])
    cp["calibrated_risk_penalty"] = (
        1.5 * np.maximum(0.0, cp["skip_count_est"] - min_skip)
        + 0.02 * np.maximum(0.0, cp["final_phase_spacing_std_ns"] - phase_cap)
        + 0.05 * np.maximum(0.0, cp["settle_time_us"] - settle_cap) * max(0.2, alpha * 10.0)
    )
    cp["proxy_total"] = cp["score_hat"] + cp["calibrated_risk_penalty"]
    selected = cp.loc[cp["proxy_total"].idxmin()]
    return selected, "deployable calibrated risk table + smooth score surrogate"


def compare_policies(df: pd.DataFrame, plant: pd.DataFrame, models: dict[str, LinearFit]) -> pd.DataFrame:
    r025 = pd.read_csv(R025_POLICY_EVAL_CSV)
    for col in [
        "target_load_A",
        "alpha_settle",
        "selected_ref_slew_us",
        "selected_ref_slew_continuous_us",
        "objective_score",
    ]:
        r025[col] = pd.to_numeric(r025[col])

    rows: list[dict[str, object]] = []
    r025_policy_map = {
        "combined_grid_oracle": "combined_grid_oracle",
        "posterior_mode_aware_projection": "mode_aware_safety_projection",
        "near_opt_band_clipping": "near_opt_band_clipping",
        "discrete_dense_long_table": "discrete_dense_long_table",
        "naked_smooth_continuous": "naked_quadratic_continuous",
    }
    for target in TARGET_ORDER:
        for objective, _ in OBJECTIVES:
            ctx = df[(df["target_label"] == target) & (df["objective"] == objective)].copy()
            if ctx.empty:
                continue
            oracle = ctx.loc[ctx["objective_score"].idxmin()]
            for tau_us in TAU_GRID_US:
                for out_policy, r025_policy in r025_policy_map.items():
                    r025_row = lookup_r025_policy(r025, target, objective, r025_policy)
                    selected = row_at_slew(ctx, float(r025_row["selected_ref_slew_us"]))
                    rows.append(
                        policy_row(
                            target,
                            objective,
                            tau_us,
                            out_policy,
                            selected,
                            oracle,
                            selected_continuous_us=float(r025_row["selected_ref_slew_continuous_us"]),
                            selection_basis=str(r025_row.get("selection_basis", "")),
                            online_available=out_policy
                            not in ["combined_grid_oracle", "posterior_mode_aware_projection", "near_opt_band_clipping"],
                        )
                    )

                param_selected, param_basis = parametric_proxy_select(ctx, plant, models, tau_us)
                rows.append(
                    policy_row(
                        target,
                        objective,
                        tau_us,
                        "parametric_proxy_only",
                        param_selected,
                        oracle,
                        selection_basis=param_basis,
                        online_available=True,
                    )
                )

                cal_selected, cal_basis = calibrated_proxy_select(ctx, models, tau_us)
                rows.append(
                    policy_row(
                        target,
                        objective,
                        tau_us,
                        "calibrated_risk_proxy_projection",
                        cal_selected,
                        oracle,
                        selection_basis=cal_basis,
                        online_available=True,
                    )
                )
    return pd.DataFrame(rows)


def summarize_policy(policy_df: pd.DataFrame) -> tuple[pd.DataFrame, pd.DataFrame]:
    summary = (
        policy_df.groupby("policy", as_index=False)
        .agg(
            n_cases=("objective_score", "count"),
            mean_regret=("regret_vs_combined_oracle", "mean"),
            median_regret=("regret_vs_combined_oracle", "median"),
            max_regret=("regret_vs_combined_oracle", "max"),
            mean_score=("objective_score", "mean"),
            mean_skip=("skip_count_est", "mean"),
            mean_phase_std_ns=("phase_std_ns", "mean"),
            mean_settle_time_us=("settle_time_us", "mean"),
            online_available_inputs_only=("online_available_inputs_only", "min"),
        )
        .sort_values(["mean_regret", "max_regret"])
    )
    by_tau = (
        policy_df.groupby(["tau_AI_us", "policy"], as_index=False)
        .agg(
            n_cases=("objective_score", "count"),
            mean_regret=("regret_vs_combined_oracle", "mean"),
            max_regret=("regret_vs_combined_oracle", "max"),
            mean_score=("objective_score", "mean"),
            mean_skip=("skip_count_est", "mean"),
            mean_phase_std_ns=("phase_std_ns", "mean"),
            mean_settle_time_us=("settle_time_us", "mean"),
        )
        .sort_values(["tau_AI_us", "mean_regret", "max_regret"])
    )
    return summary, by_tau


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
                if np.isnan(val):
                    vals.append("")
                else:
                    vals.append(f"{val:.3f}")
            else:
                vals.append(str(val))
        lines.append("| " + " | ".join(vals) + " |")
    return "\n".join(lines)


def write_reports(
    fit_eval_df: pd.DataFrame,
    policy_summary: pd.DataFrame,
    policy_by_tau: pd.DataFrame,
    policy_eval: pd.DataFrame,
    risk_table: pd.DataFrame,
) -> None:
    cal = policy_summary[policy_summary["policy"] == "calibrated_risk_proxy_projection"].iloc[0]
    param = policy_summary[policy_summary["policy"] == "parametric_proxy_only"].iloc[0]
    posterior = policy_summary[policy_summary["policy"] == "posterior_mode_aware_projection"].iloc[0]
    dense = policy_summary[policy_summary["policy"] == "discrete_dense_long_table"].iloc[0]
    naked = policy_summary[policy_summary["policy"] == "naked_smooth_continuous"].iloc[0]

    report = [
        "# R026 可部署 `T_slew` 风险 proxy 与安全投影验证",
        "",
        "## 目的",
        "",
        "R025 的 mode-aware 投影使用 `skip_count_est`、相位间隔标准差和恢复时间等后验指标，不能直接被在线 AI 监督层读取。R026 将这一步拆成两个可审查接口：",
        "",
        "1. `parametric_proxy_only`：只用 `target_load_A`、`load_drop_norm`、`alpha_settle`、`T_slew` 和 `tau_AI` 拟合风险，作为负面对照。",
        "2. `calibrated_risk_proxy_projection`：把离线开关级细扫得到的模式风险固化为 `r_hat(z,T_slew)` 校准表，再与平滑 score surrogate 组合做投影。",
        "",
        "这两个接口都不替代 IQCOT 内环；它们只给监督层提交 `T_slew` 前的安全选择规则。",
        "",
        "## 数据与输入边界",
        "",
        f"- R025 objective-level rows：`{policy_eval[['target_label','objective']].drop_duplicates().shape[0]} contexts x {len(TAU_GRID_US)} tau settings` 的策略重放。",
        f"- 校准风险表 plant rows：`{len(risk_table)}` 个 `target/ref_slew` 点。",
        "- 在线可得输入限定为：`target_load_A`、`load_drop_norm`、`alpha_settle`、候选 `T_slew`、`tau_AI`/`delay_events`，以及离线预存的风险 proxy 表或短时预测器输出。",
        "- `skip_count_est`、`phase_std_ns` 和 `settle_time_us` 在报告表中只作为评价标签；不把它们写成在线可直接观测量。",
        "",
        "## Proxy 拟合与泛化检查",
        "",
        md_table(
            fit_eval_df,
            ["model", "target", "split", "n_rows", "rmse", "mae", "accuracy", "precision", "recall"],
        ),
        "",
        "该表的主要含义是负面的：平滑可部署特征可以给出 score 粗排序，但对 skip/reentry 非光滑边界不可靠。leave-one-target 误差进一步说明，风险 proxy 需要目标相关校准或短时事件预测，不能直接声称跨负载泛化。",
        "",
        "## 策略比较",
        "",
        md_table(
            policy_summary,
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
        "关键数值解释：",
        "",
        f"- 后验 `posterior_mode_aware_projection` 仍是最强的可解释投影之一，mean regret 为 `{posterior['mean_regret']:.3f}`，但它使用后验模式标签，不能直接部署。",
        f"- `calibrated_risk_proxy_projection` 的 mean regret 为 `{cal['mean_regret']:.3f}`，低于旧 `discrete_dense_long_table` 的 `{dense['mean_regret']:.3f}` 和裸平滑连续的 `{naked['mean_regret']:.3f}`，但略弱于 R025 后验投影。",
        f"- `parametric_proxy_only` 的 mean regret 为 `{param['mean_regret']:.3f}`，说明只用光滑参数模型会重新踩到 R024 的 skip/reentry 跳变风险。",
        "",
        "## 延迟敏感性",
        "",
        md_table(
            policy_by_tau[policy_by_tau["policy"].isin(["calibrated_risk_proxy_projection", "parametric_proxy_only"])],
            ["tau_AI_us", "policy", "mean_regret", "max_regret", "mean_skip", "mean_phase_std_ns", "mean_settle_time_us"],
        ),
        "",
        "当前 R026 的 `tau_AI` 只作为安全裕量进入离线重放，不是新增开关级延迟仿真。它可用于设计下一步 table-in-loop 或 AI-in-loop 派生 Simulink 验证点。",
        "",
        "## 结论边界",
        "",
        "- 不声称 `T_slew` 存在全局最优。",
        "- 不声称校准风险表等同硬件安全集合。",
        "- 不声称 R026 已完成神经网络 AI-in-loop 或硬件验证。",
        "- 可以谨慎声称：PIS-IEK 给出的 mode-aware 安全投影可以被降级为可部署的风险 proxy 接口；在当前离线网格上，该接口优于裸连续和平滑参数 proxy，并接近但不超过后验投影。",
    ]
    REPORT_MD.write_text("\n".join(report) + "\n", encoding="utf-8")

    paper = [
        "### R026 可部署 risk proxy：从后验 mode-aware 指标到监督层接口",
        "",
        "R025 的一个潜在问题是，`skip_count_est`、相位间隔标准差和恢复时间都是开关级仿真后的指标。如果直接把它们写入 AI 输入，就会把后验评价量误当成部署前可用信息。为避免这一点，本文进一步构造 R026 可部署 risk proxy：在线监督层只接收 `target_load_A`、`load_drop_norm`、`alpha_settle`、候选 `T_slew` 与 `tau_AI`，模式风险由离线校准表或短时事件预测器给出。",
        "",
        "实验比较了两个 proxy 层级。第一，`parametric_proxy_only` 只用光滑可部署特征拟合风险和 score；它的平均 regret 明显较高，说明单纯的平滑 `target/load/T_slew` 回归无法可靠穿过 skip/reentry 边界。第二，`calibrated_risk_proxy_projection` 将已完成细扫中的 skip、phase 和 settling 风险整理为 `r_hat(z,T_slew)` 校准表，再与平滑 score surrogate 组合选择动作。在当前 `9` 个目标/目标函数上下文和 `5` 个 `tau_AI` 设置的离线重放中，该策略平均 regret 为 "
        f"`{cal['mean_regret']:.3f}`，低于旧 dense-long 表 `{dense['mean_regret']:.3f}` 与裸平滑连续 `{naked['mean_regret']:.3f}`，但仍弱于后验 mode-aware 投影 `{posterior['mean_regret']:.3f}`。",
        "",
        "因此，R026 不把 AI 结论写成“已经优于查表或硬件验证”，而把创新点收束为更严谨的接口：PIS-IEK 不仅指出连续 `T_slew` 需要 mode-aware 约束，还给出了把后验模式指标转化为可部署风险 proxy 的路径。下一步应在派生 Simulink 模型中把该 proxy 作为 table-in-loop 监督层接入，验证动作提交延迟下的排序是否保持。",
    ]
    PAPER_SECTION_MD.write_text("\n".join(paper) + "\n", encoding="utf-8")


def make_figure(policy_summary: pd.DataFrame) -> None:
    order = [
        "combined_grid_oracle",
        "posterior_mode_aware_projection",
        "calibrated_risk_proxy_projection",
        "near_opt_band_clipping",
        "discrete_dense_long_table",
        "naked_smooth_continuous",
        "parametric_proxy_only",
    ]
    s = policy_summary.set_index("policy").loc[order].reset_index()
    try:
        import matplotlib.pyplot as plt  # type: ignore
    except Exception as exc:
        print(f"matplotlib unavailable, write fallback svg: {exc}", file=sys.stderr)
        FIG.mkdir(parents=True, exist_ok=True)
        width = 1160
        height = 420
        left = 70
        bottom = 350
        top = 55
        panel_w = 330
        gap = 45
        metrics = [
            ("mean_regret", "mean regret", "#5b8ff9"),
            ("max_regret", "max regret", "#f4664a"),
            ("mean_phase_std_ns", "mean phase std ns", "#5ad8a6"),
        ]
        labels = {
            "combined_grid_oracle": "oracle",
            "posterior_mode_aware_projection": "posterior",
            "calibrated_risk_proxy_projection": "cal-proxy",
            "near_opt_band_clipping": "band",
            "discrete_dense_long_table": "dense",
            "naked_smooth_continuous": "naked",
            "parametric_proxy_only": "param",
        }
        svg: list[str] = [
            f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
            '<rect width="100%" height="100%" fill="white"/>',
            '<text x="580" y="28" text-anchor="middle" font-family="Arial" font-size="18">R026 deployable risk proxy policy comparison</text>',
        ]
        for panel_idx, (metric, title, color) in enumerate(metrics):
            x0 = left + panel_idx * (panel_w + gap)
            vals = s[metric].to_numpy(dtype=float)
            max_val = float(max(vals.max(), 1e-9))
            if metric == "mean_phase_std_ns":
                max_val = max(max_val, 100.0)
            scale_h = bottom - top
            svg.append(f'<text x="{x0 + panel_w / 2:.1f}" y="48" text-anchor="middle" font-family="Arial" font-size="13">{title}</text>')
            svg.append(f'<line x1="{x0}" y1="{bottom}" x2="{x0 + panel_w}" y2="{bottom}" stroke="#333" stroke-width="1"/>')
            svg.append(f'<line x1="{x0}" y1="{top}" x2="{x0}" y2="{bottom}" stroke="#333" stroke-width="1"/>')
            for tick in [0.0, 0.5, 1.0]:
                y = bottom - tick * scale_h
                val = tick * max_val
                svg.append(f'<line x1="{x0 - 4}" y1="{y:.1f}" x2="{x0 + panel_w}" y2="{y:.1f}" stroke="#ddd" stroke-width="1"/>')
                svg.append(f'<text x="{x0 - 8}" y="{y + 4:.1f}" text-anchor="end" font-family="Arial" font-size="10">{val:.2f}</text>')
            bar_gap = 6
            bar_w = (panel_w - bar_gap * (len(s) + 1)) / len(s)
            for i, row in s.iterrows():
                val = float(row[metric])
                bar_h = val / max_val * scale_h if max_val > 0 else 0.0
                bx = x0 + bar_gap + i * (bar_w + bar_gap)
                by = bottom - bar_h
                svg.append(f'<rect x="{bx:.1f}" y="{by:.1f}" width="{bar_w:.1f}" height="{bar_h:.1f}" fill="{color}" opacity="0.85"/>')
                svg.append(f'<text x="{bx + bar_w/2:.1f}" y="{by - 4:.1f}" text-anchor="middle" font-family="Arial" font-size="9">{val:.2f}</text>')
                svg.append(
                    f'<text transform="translate({bx + bar_w/2:.1f},{bottom + 14}) rotate(35)" '
                    f'text-anchor="start" font-family="Arial" font-size="9">{labels[str(row["policy"])]}</text>'
                )
        svg.append("</svg>")
        FIG_PATH.write_text("\n".join(svg) + "\n", encoding="utf-8")
        return
    FIG.mkdir(parents=True, exist_ok=True)
    fig, axes = plt.subplots(1, 3, figsize=(14, 4.2))
    axes[0].bar(s["policy"], s["mean_regret"], color="#5b8ff9")
    axes[0].set_ylabel("mean regret vs grid oracle")
    axes[1].bar(s["policy"], s["max_regret"], color="#f4664a")
    axes[1].set_ylabel("max regret")
    axes[2].bar(s["policy"], s["mean_phase_std_ns"], color="#5ad8a6")
    axes[2].set_ylabel("mean phase std (ns)")
    for ax in axes:
        ax.grid(True, axis="y", alpha=0.3)
        ax.tick_params(axis="x", rotation=35, labelsize=8)
    fig.suptitle("R026 deployable risk proxy policy comparison")
    fig.tight_layout(rect=[0, 0, 1, 0.94])
    fig.savefig(FIG_PATH)
    plt.close(fig)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    FIG.mkdir(parents=True, exist_ok=True)

    df = load_dataset()
    plant = plant_rows(df)
    risk_table = proxy_table(plant)

    fit_eval_df, models = fit_eval(df, plant)
    policy_eval = compare_policies(df, plant, models)
    policy_summary, policy_by_tau = summarize_policy(policy_eval)

    df.to_csv(PROXY_DATASET_CSV, index=False)
    risk_table.to_csv(RISK_TABLE_CSV, index=False)
    fit_eval_df.to_csv(PROXY_FIT_EVAL_CSV, index=False)
    policy_eval.to_csv(POLICY_EVAL_CSV, index=False)
    policy_summary.to_csv(POLICY_SUMMARY_CSV, index=False)
    policy_by_tau.to_csv(POLICY_BY_TAU_CSV, index=False)

    make_figure(policy_summary)
    write_reports(fit_eval_df, policy_summary, policy_by_tau, policy_eval, risk_table)

    print(f"PROXY_FIT_EVAL={PROXY_FIT_EVAL_CSV}")
    print(f"POLICY_SUMMARY={POLICY_SUMMARY_CSV}")
    print(f"POLICY_BY_TAU={POLICY_BY_TAU_CSV}")
    print(f"RISK_TABLE={RISK_TABLE_CSV}")
    print(f"REPORT={REPORT_MD}")
    print(f"FIGURE={FIG_PATH}")


if __name__ == "__main__":
    main()
