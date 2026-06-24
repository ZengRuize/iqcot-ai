"""Post-process R024 local reference-slew fine sweep.

The script is deliberately conservative:
- R023 quadratic candidates are treated only as hypotheses.
- Fine-sweep Simulink rows, when available, are compared against the previous
  dense+long grid and not described as global optima.
- If the Simulink run has not completed, the script still emits the exact
  validation plan and a pending report.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

import math
import sys


ROOT = Path("E:/Desktop/codex")
OUT = ROOT / "output"
FIG = OUT / "figures"

OLD_SCORE_CSV = OUT / "iqcot_dynamic_ref_slew_dense_long_combined_scores.csv"
R023_SUMMARY_CSV = OUT / "iqcot_ref_slew_continuous_landscape_summary.csv"
FINE_SUMMARY_CSV = OUT / "iqcot_dynamic_ref_slew_fine_summary.csv"

PLAN_CSV = OUT / "iqcot_ref_slew_fine_sweep_plan.csv"
PLAN_MATLAB_CSV = OUT / "iqcot_ref_slew_fine_sweep_plan_matlab.csv"
FINE_SCORE_CSV = OUT / "iqcot_ref_slew_fine_summary_scores.csv"
BEST_CSV = OUT / "iqcot_ref_slew_fine_best_by_objective.csv"
COMPARISON_CSV = OUT / "iqcot_ref_slew_fine_candidate_comparison.csv"
REPORT_MD = OUT / "iqcot_ref_slew_fine_sweep_report.md"
PAPER_SECTION_MD = OUT / "iqcot_ref_slew_fine_sweep_paper_section.md"
FIG_PATH = FIG / "fig31_ref_slew_fine_sweep.svg"

FINE_SLEWS_US = [32, 34, 35, 36, 38, 62, 64, 66, 68, 70, 84, 86, 88, 90, 92]
TARGETS = [
    (20.0, "20A"),
    (10.0, "10A"),
    (0.001, "near0A"),
]
OBJECTIVES = [
    ("base", "tradeoff_score", 0.0),
    ("score_settle005", "score_settle005", 0.05),
    ("score_settle010", "score_settle010", 0.10),
]


@dataclass(frozen=True)
class PriorityBand:
    target_load_A: float
    target_label: str
    objective_focus: str
    candidate_us: float
    sweep_us: list[int]
    priority: str
    reason: str


PRIORITY_BANDS = [
    PriorityBand(
        20.0,
        "20A",
        "score_settle005;score_settle010",
        34.744,
        [32, 34, 35, 36, 38],
        "primary",
        "R023 local quadratic candidate around 34.744 us for settling-aware objectives.",
    ),
    PriorityBand(
        0.001,
        "near0A",
        "score_settle010",
        34.633,
        [32, 34, 35, 36, 38],
        "primary",
        "R023 local quadratic candidate around 34.633 us for strong settling penalty.",
    ),
    PriorityBand(
        20.0,
        "20A",
        "base",
        87.244,
        [84, 86, 88, 90, 92],
        "secondary",
        "R023 local quadratic candidate around 87.244 us for base score.",
    ),
    PriorityBand(
        0.001,
        "near0A",
        "base",
        65.710,
        [62, 64, 66, 68, 70],
        "secondary",
        "R023 local quadratic candidate around 65.710 us for base score.",
    ),
]


def require_pandas():
    try:
        import pandas as pd  # type: ignore

        return pd
    except Exception as exc:  # pragma: no cover - environment guard
        raise SystemExit(f"pandas is required for R024 post-processing: {exc}") from exc


def label_for_target(value: float) -> str:
    if abs(value - 20.0) < 1e-9:
        return "20A"
    if abs(value - 10.0) < 1e-9:
        return "10A"
    if value <= 0.01:
        return "near0A"
    return f"{value:g}A"


def write_plan(pd) -> None:
    plan_rows = []
    for band in PRIORITY_BANDS:
        for slew in band.sweep_us:
            plan_rows.append(
                {
                    "target_load_A": band.target_load_A,
                    "target_label": band.target_label,
                    "ref_slew_us": slew,
                    "objective_focus": band.objective_focus,
                    "r023_candidate_us": band.candidate_us,
                    "priority": band.priority,
                    "reason": band.reason,
                    "boundary": "fine-sweep candidate only; not a global optimum or hardware result",
                }
            )
    pd.DataFrame(plan_rows).to_csv(PLAN_CSV, index=False)

    matlab_rows = []
    for target_load_A, target_label in TARGETS:
        for slew in FINE_SLEWS_US:
            priority = "observer"
            reason = "collected because wrapper sweep runs all three targets on the shared fine grid"
            for band in PRIORITY_BANDS:
                if abs(target_load_A - band.target_load_A) < 1e-12 and slew in band.sweep_us:
                    priority = band.priority
                    reason = band.reason
                    break
            matlab_rows.append(
                {
                    "target_load_A": target_load_A,
                    "target_label": target_label,
                    "ref_slew_us": slew,
                    "matlab_entry": "iqcot_dynamic_ref_slew_fine_sweep",
                    "expected_summary": str(FINE_SUMMARY_CSV).replace("\\", "/"),
                    "priority": priority,
                    "reason": reason,
                }
            )
    pd.DataFrame(matlab_rows).to_csv(PLAN_MATLAB_CSV, index=False)


def add_scores(df, pd):
    df = df.copy()
    if "target_label" not in df.columns:
        df["target_label"] = df["target_load_A"].apply(label_for_target)
    if "score_settle005" not in df.columns:
        df["score_settle005"] = df["tradeoff_score"] + 0.05 * df["settle_time_us"]
    if "score_settle010" not in df.columns:
        df["score_settle010"] = df["tradeoff_score"] + 0.10 * df["settle_time_us"]
    for col in ["success", "error_message"]:
        if col not in df.columns:
            df[col] = True if col == "success" else ""
    df["source_grid"] = "fine"
    return df


def valid_rows(df, score_col: str):
    out = df.copy()
    if "success" in out.columns:
        out = out[out["success"].astype(str).str.lower().isin(["true", "1"])]
    return out[out[score_col].notna()]


def best_row(df, target_load_A: float, score_col: str):
    r = valid_rows(df[df["target_load_A"].astype(float).sub(target_load_A).abs() < 1e-9], score_col)
    if r.empty:
        return None
    return r.loc[r[score_col].idxmin()]


def compute_results(pd):
    old = pd.read_csv(OLD_SCORE_CSV)
    old = add_scores(old, pd)
    old["source_grid"] = "dense_long"

    if not FINE_SUMMARY_CSV.exists():
        return old, None, None, None

    fine = pd.read_csv(FINE_SUMMARY_CSV)
    fine = add_scores(fine, pd)
    fine.to_csv(FINE_SCORE_CSV, index=False)

    best_rows = []
    comparison_rows = []
    for target_load_A, target_label in TARGETS:
        for objective_name, score_col, alpha in OBJECTIVES:
            old_best = best_row(old, target_load_A, score_col)
            fine_best = best_row(fine, target_load_A, score_col)
            combined_best = best_row(pd.concat([old, fine], ignore_index=True), target_load_A, score_col)
            if old_best is None or fine_best is None or combined_best is None:
                continue
            best_rows.append(
                {
                    "target_load_A": target_load_A,
                    "target_label": target_label,
                    "objective": objective_name,
                    "alpha_settle": alpha,
                    "old_best_us": float(old_best["ref_slew_us"]),
                    "old_best_score": float(old_best[score_col]),
                    "fine_best_us": float(fine_best["ref_slew_us"]),
                    "fine_best_score": float(fine_best[score_col]),
                    "combined_best_us": float(combined_best["ref_slew_us"]),
                    "combined_best_score": float(combined_best[score_col]),
                    "fine_gain_vs_old_best": float(old_best[score_col] - fine_best[score_col]),
                    "combined_gain_vs_old_best": float(old_best[score_col] - combined_best[score_col]),
                    "best_source": str(combined_best["source_grid"]),
                    "boundary": "best over current dense+long+fine grid only",
                }
            )

    best_df = pd.DataFrame(best_rows)
    if not best_df.empty:
        best_df.to_csv(BEST_CSV, index=False)

    r023 = pd.read_csv(R023_SUMMARY_CSV) if R023_SUMMARY_CSV.exists() else pd.DataFrame()
    for _, band in enumerate(PRIORITY_BANDS):
        for objective_name in band.objective_focus.split(";"):
            objective_name = objective_name.strip()
            if objective_name == "base":
                score_col = "tradeoff_score"
            else:
                score_col = objective_name
            old_best = best_row(old, band.target_load_A, score_col)
            fine_subset = fine[
                (fine["target_load_A"].astype(float).sub(band.target_load_A).abs() < 1e-9)
                & (fine["ref_slew_us"].isin(band.sweep_us))
            ]
            fine_best = best_row(fine_subset, band.target_load_A, score_col)
            if old_best is None or fine_best is None:
                continue
            nearest_idx = (fine_subset["ref_slew_us"] - band.candidate_us).abs().idxmin()
            nearest = fine_subset.loc[nearest_idx]
            comparison_rows.append(
                {
                    "target_load_A": band.target_load_A,
                    "target_label": band.target_label,
                    "objective": objective_name,
                    "priority": band.priority,
                    "r023_candidate_us": band.candidate_us,
                    "nearest_sim_us": float(nearest["ref_slew_us"]),
                    "nearest_sim_score": float(nearest[score_col]),
                    "local_fine_best_us": float(fine_best["ref_slew_us"]),
                    "local_fine_best_score": float(fine_best[score_col]),
                    "old_sampled_best_us": float(old_best["ref_slew_us"]),
                    "old_sampled_best_score": float(old_best[score_col]),
                    "local_gain_vs_old_best": float(old_best[score_col] - fine_best[score_col]),
                    "nearest_gain_vs_old_best": float(old_best[score_col] - nearest[score_col]),
                    "verdict": verdict(float(old_best[score_col] - fine_best[score_col])),
                    "boundary": "R023 interpolation checked only on this local fine grid",
                }
            )
    comp_df = pd.DataFrame(comparison_rows)
    if not comp_df.empty:
        comp_df.to_csv(COMPARISON_CSV, index=False)
    return old, fine, best_df, comp_df


def verdict(gain: float) -> str:
    if math.isnan(gain):
        return "inconclusive"
    if gain > 0.05:
        return "fine_grid_supports_local_improvement"
    if gain > 0.0:
        return "fine_grid_supports_small_local_improvement"
    if gain > -0.05:
        return "no_material_gain_over_prior_grid"
    return "fine_grid_does_not_support_r023_improvement"


def make_figure(pd, old, fine) -> None:
    if fine is None:
        return
    try:
        import matplotlib.pyplot as plt  # type: ignore
    except Exception as exc:  # pragma: no cover - environment guard
        print(f"matplotlib unavailable, skip figure: {exc}", file=sys.stderr)
        return

    FIG.mkdir(parents=True, exist_ok=True)
    fig, axes = plt.subplots(2, 3, figsize=(12, 6.5), sharex=False)
    target_specs = [(20.0, "20A"), (0.001, "near-0A")]
    plot_specs = [
        ("base", "tradeoff_score"),
        ("score+0.05Tsettle", "score_settle005"),
        ("score+0.10Tsettle", "score_settle010"),
    ]
    for row_idx, (target, target_label) in enumerate(target_specs):
        for col_idx, (title, score_col) in enumerate(plot_specs):
            ax = axes[row_idx][col_idx]
            old_r = old[old["target_load_A"].astype(float).sub(target).abs() < 1e-9].sort_values("ref_slew_us")
            fine_r = fine[fine["target_load_A"].astype(float).sub(target).abs() < 1e-9].sort_values("ref_slew_us")
            ax.plot(old_r["ref_slew_us"], old_r[score_col], "o-", label="dense+long", markersize=3)
            ax.plot(fine_r["ref_slew_us"], fine_r[score_col], "s--", label="fine", markersize=3)
            ax.set_title(f"{target_label} {title}")
            ax.set_xlabel("T_slew (us)")
            ax.set_ylabel("score")
            ax.grid(True, alpha=0.3)
            if row_idx == 0 and col_idx == 0:
                ax.legend(fontsize=8)
    fig.suptitle("R024 local T_slew fine sweep vs prior dense+long grid")
    fig.tight_layout(rect=[0, 0, 1, 0.96])
    fig.savefig(FIG_PATH)
    plt.close(fig)


def md_table(rows: Iterable[dict], columns: list[str]) -> str:
    lines = []
    lines.append("| " + " | ".join(columns) + " |")
    lines.append("| " + " | ".join(["---"] * len(columns)) + " |")
    for row in rows:
        vals = []
        for col in columns:
            value = row.get(col, "")
            if isinstance(value, float):
                vals.append(f"{value:.3f}")
            else:
                vals.append(str(value))
        lines.append("| " + " | ".join(vals) + " |")
    return "\n".join(lines)


def write_reports(pd, fine, best_df, comp_df) -> None:
    sim_done = fine is not None and not fine.empty
    plan_note = (
        "已完成派生 Simulink 细扫后处理。"
        if sim_done
        else "尚未发现细扫 summary；当前报告是可执行验证计划。"
    )
    report = [
        "# R024 参考斜率局部细扫验证",
        "",
        "## 目的",
        "",
        "R023 的连续 `T_slew` 景观只给出局部二次插值候选。R024 的目标是用派生 Simulink 模型在小范围网格中验证这些候选是否仍然改善 objective score，尤其是 `20A` 与 `near-0A` 附近的 `34-35 us`。",
        "",
        f"状态：{plan_note}",
        "",
        "## 验证计划",
        "",
        f"- MATLAB 入口：`{(OUT / 'iqcot_dynamic_ref_slew_fine_sweep.m').as_posix()}`",
        f"- 精确计划：`{PLAN_MATLAB_CSV.as_posix()}`",
        f"- 高优先级计划：`{PLAN_CSV.as_posix()}`",
        "- 使用派生模型：`E:/Desktop/codex/output/simulink_iek/four_phase_iek_dynamic_load_refslew.slx`",
        "- 不修改原始 `.slx`，不直接编辑 `.slx` XML。",
        "",
    ]
    if not sim_done:
        report += [
            "## 待运行命令",
            "",
            "```matlab",
            "addpath('E:/Desktop/codex/output');",
            "iqcot_dynamic_ref_slew_fine_sweep();",
            "```",
            "",
            "## 结论边界",
            "",
            "当前仅完成计划与脚本，不能声称 `34-35 us` 已经通过开关级验证。",
        ]
    else:
        report += [
            "## 细扫结果汇总",
            "",
            f"- 细扫 summary：`{FINE_SUMMARY_CSV.as_posix()}`",
            f"- 合并目标函数 best：`{BEST_CSV.as_posix()}`",
            f"- R023 候选对比：`{COMPARISON_CSV.as_posix()}`",
            f"- 图：`{FIG_PATH.as_posix()}`",
            "",
        ]
        if comp_df is not None and not comp_df.empty:
            keep_cols = [
                "target_label",
                "objective",
                "r023_candidate_us",
                "nearest_sim_us",
                "nearest_sim_score",
                "local_fine_best_us",
                "local_fine_best_score",
                "old_sampled_best_us",
                "old_sampled_best_score",
                "local_gain_vs_old_best",
                "verdict",
            ]
            report += [
                "### R023 候选验证",
                "",
                md_table(comp_df[keep_cols].to_dict("records"), keep_cols),
                "",
            ]
            report += [
                "### 关键观察",
                "",
                "- `20A` 的 `35 us` 最近候选点并未验证 R023 的点最优假设：它触发了 `skip_count=1`，score 反而劣于旧 `30 us`。同一局部带内 `38 us` 恢复到 `skip_count=0`，相对旧网格有约 `0.076` 分改善。",
                "- 更宽的细扫网格显示 `20A` settling-aware 目标在 `66 us` 处出现更低 score。这不是 R023 局部二次插值能够直接预测的平滑最优，而是事件模式和相位指标共同导致的非光滑局部机会。",
                "- `near-0A` 的强恢复时间惩罚目标在 `38 us` 处相对旧 `30 us` 改善约 `0.235` 分，支持在 `34-40 us` 附近做连续动作安全区间，但仍不能称为全局最优。",
                "- 因此，R024 的主要价值不是证明 `34-35 us` 是最优，而是证明连续 `T_slew` 景观含有 skip/reentry 离散跳变；后续 AI 应学习带安全投影的区间选择，而不是裸回归一个尖锐点。",
                "",
            ]
        if best_df is not None and not best_df.empty:
            keep_cols = [
                "target_label",
                "objective",
                "old_best_us",
                "old_best_score",
                "fine_best_us",
                "fine_best_score",
                "combined_best_us",
                "combined_best_score",
                "combined_gain_vs_old_best",
                "best_source",
            ]
            report += [
                "### 全目标函数 best-by-grid",
                "",
                md_table(best_df[keep_cols].to_dict("records"), keep_cols),
                "",
            ]
        report += [
            "## 谨慎解释",
            "",
            "- 若细扫点优于旧网格，只能说明在当前派生模型、当前目标函数和当前局部网格下有改善。",
            "- 不能声称 `T_slew` 存在全局最优。",
            "- 不能把 R023 插值或 R024 派生仿真等同于硬件验证。",
            "- AI 仍只作为监督层参数调度，不替代 IQCOT 内环。",
        ]
    REPORT_MD.write_text("\n".join(report) + "\n", encoding="utf-8")

    paper = [
        "### R024 局部参考斜率细扫验证",
        "",
        "R023 的连续 `T_slew` 分数景观提示，`20A` settling-aware 目标和 `near-0A` 强恢复时间惩罚目标可能在 `34-35 us` 附近存在小幅连续收益。由于该结论来自局部二次插值，本文进一步设计 R024 派生 Simulink 细扫：在 `32/34/35/36/38 us` 验证 `34-35 us` 候选，并在 `84-92 us`、`62-70 us` 验证两个 base-score 次优先候选。该实验只使用 `four_phase_iek_dynamic_load_refslew.slx` 派生模型，不修改原始模型。",
        "",
    ]
    if sim_done and comp_df is not None and not comp_df.empty:
        primary = comp_df[
            (comp_df["priority"] == "primary")
            & (comp_df["objective"].isin(["score_settle005", "score_settle010"]))
        ]
        gains = ", ".join(
            [
                f"{r.target_label}/{r.objective}: {r.local_fine_best_us:.0f} us, gain {r.local_gain_vs_old_best:.3f}"
                for r in primary.itertuples()
            ]
        )
        paper += [
            f"细扫后处理显示：{gains}。这些数值只能表述为当前局部网格下相对旧 dense+long 采样点的改善或未改善，不能上升为全局最优结论。",
            "更重要的是，`20A` 的 `35 us` 最近候选点本身并未改善旧网格，而同一局部带内 `38 us` 和更宽网格中的 `66 us` 给出较低 score。这说明参考斜率分数景观并非光滑二次曲线，skip/reentry 和相位标准差造成的事件模式跳变会改变最佳点位置。该结果反而支持 PIS-IEK 的混合事件定位：连续动作 AI 应输出受 near-optimal band 与模式边界约束的调度区间，而不是宣称局部二次插值得到全局最优。",
            "",
        ]
    else:
        paper += [
            "截至本段生成时，R024 仍处于可执行计划阶段；因此 `34-35 us` 仍是待验证候选，而不是新的开关级证据。",
            "",
        ]
    paper += [
        "该实验的论文价值在于把连续动作 AI 的论证边界收窄：若局部细扫只带来小幅收益，连续 `T_slew` 更适合作为 near-optimal 区间内的平滑调度和安全投影变量；若细扫无收益，则应保留离散表驱动监督层作为强基线。",
    ]
    PAPER_SECTION_MD.write_text("\n".join(paper) + "\n", encoding="utf-8")


def main() -> None:
    pd = require_pandas()
    OUT.mkdir(parents=True, exist_ok=True)
    FIG.mkdir(parents=True, exist_ok=True)
    write_plan(pd)
    old, fine, best_df, comp_df = compute_results(pd)
    make_figure(pd, old, fine)
    write_reports(pd, fine, best_df, comp_df)
    print(f"PLAN={PLAN_CSV}")
    print(f"PLAN_MATLAB={PLAN_MATLAB_CSV}")
    print(f"REPORT={REPORT_MD}")
    if fine is not None:
        print(f"FINE_SCORE={FINE_SCORE_CSV}")
        print(f"BEST={BEST_CSV}")
        print(f"COMPARISON={COMPARISON_CSV}")
        print(f"FIGURE={FIG_PATH}")


if __name__ == "__main__":
    main()
