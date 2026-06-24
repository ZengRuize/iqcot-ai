#!/usr/bin/env python3
"""R022 interpretable supervisor baselines for four-phase IQCOT T_slew scheduling.

This script uses only completed delayed-reference switching results. It does not
modify or run any Simulink model. The goal is to test whether a small
interpretable score model can choose among the already validated supervisory
policies with low regret.
"""

from __future__ import annotations

import csv
import math
import statistics
from collections import defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "output"
FIG = OUT / "figures"

RAW_FILES = [
    OUT / "iqcot_table_supervisor_validation_results_tau0p5_1_2us.csv",
    OUT / "iqcot_table_supervisor_validation_results.csv",
]

DATASET_CSV = OUT / "iqcot_ai_supervisor_regressor_dataset.csv"
LABELS_CSV = OUT / "iqcot_ai_supervisor_regressor_context_labels.csv"
EVAL_CSV = OUT / "iqcot_ai_supervisor_regressor_eval.csv"
SUMMARY_CSV = OUT / "iqcot_ai_supervisor_regressor_summary.csv"
REPORT_MD = OUT / "iqcot_ai_supervisor_regressor_report.md"
PAPER_SECTION_MD = OUT / "iqcot_ai_supervisor_regressor_paper_section.md"
FIG_SVG = FIG / "fig29_ai_supervisor_regressor_regret.svg"

OBJECTIVES = [
    ("base", 0.0, "base_score"),
    ("score_settle005", 0.05, "score_settle005"),
    ("score_settle010", 0.10, "score_settle010"),
]

POLICIES = [
    "fixed_40us_precommitted",
    "fixed_80us_precommitted",
    "oracle_base_table",
    "table_settle005",
    "table_settle010",
]

ZERO_DELAY_OBJECTIVE_POLICY = {
    "base": "oracle_base_table",
    "score_settle005": "table_settle005",
    "score_settle010": "table_settle010",
}


def fnum(value: str | float | int | None, default: float = math.nan) -> float:
    if value is None:
        return default
    if isinstance(value, (float, int)):
        return float(value)
    text = str(value).strip()
    if not text or text.lower() == "nan":
        return default
    return float(text)


def read_raw_rows() -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    for path in RAW_FILES:
        if not path.exists():
            raise FileNotFoundError(path)
        with path.open("r", encoding="utf-8-sig", newline="") as fp:
            for row in csv.DictReader(fp):
                if int(fnum(row.get("success"), 0)) != 1:
                    continue
                row["_source_file"] = path.name
                rows.append(row)
    return rows


def target_label(target_load: float) -> str:
    if target_load < 0.01:
        return "near0A"
    return f"{target_load:g}A"


def make_dataset(raw_rows: list[dict[str, str]]) -> list[dict[str, object]]:
    dataset: list[dict[str, object]] = []
    seen: set[tuple] = set()
    for row in raw_rows:
        tau = fnum(row["tau_ai_us"])
        target = fnum(row["target_load_A"])
        policy = row["policy"]
        policy_kind = row.get("policy_kind", "")
        slew = fnum(row["selected_ref_slew_us"])
        delay_events = int(round(fnum(row["delay_events"])))
        ref_start_delay = fnum(row.get("ref_start_delay_us"), 0.0)
        drop = 40.0 - target
        drop_norm = drop / 40.0

        base = fnum(row["base_score"])
        settle = fnum(row["settle_time_us"])
        undershoot = fnum(row["undershoot_mV"])
        final_err = fnum(row["final_vout_error_mV"])
        phase_std = fnum(row["final_phase_spacing_std_ns"])
        skip = fnum(row["skip_count_est"])

        for objective, alpha, score_col in OBJECTIVES:
            key = (tau, target, policy, objective)
            if key in seen:
                continue
            seen.add(key)
            dataset.append(
                {
                    "context_id": f"tau{tau:g}_target{target_label(target)}_{objective}",
                    "tau_ai_us": tau,
                    "delay_events": delay_events,
                    "target_load_A": target,
                    "target_label": target_label(target),
                    "load_drop_A": drop,
                    "load_drop_norm": drop_norm,
                    "objective": objective,
                    "objective_alpha_settle": alpha,
                    "policy": policy,
                    "policy_kind": policy_kind,
                    "selected_ref_slew_us": slew,
                    "ref_start_delay_us": ref_start_delay,
                    "undershoot_mV": undershoot,
                    "abs_final_vout_error_mV": abs(final_err),
                    "final_vout_error_mV": final_err,
                    "skip_count_est": skip,
                    "settle_time_us": settle,
                    "final_phase_spacing_std_ns": phase_std,
                    "base_score": base,
                    "objective_score": fnum(row[score_col]),
                    "source_file": row["_source_file"],
                    "note": "candidate policy row from derived Simulink delayed-reference switching validation",
                }
            )
    dataset.sort(key=lambda r: (r["tau_ai_us"], r["target_load_A"], r["objective"], r["policy"]))
    return dataset


def context_key(row: dict[str, object]) -> tuple[float, float, str]:
    return (float(row["tau_ai_us"]), float(row["target_load_A"]), str(row["objective"]))


def group_by_context(dataset: list[dict[str, object]]) -> dict[tuple[float, float, str], list[dict[str, object]]]:
    grouped: dict[tuple[float, float, str], list[dict[str, object]]] = defaultdict(list)
    for row in dataset:
        grouped[context_key(row)].append(row)
    return dict(grouped)


def make_labels(dataset: list[dict[str, object]]) -> list[dict[str, object]]:
    labels: list[dict[str, object]] = []
    for key, rows in sorted(group_by_context(dataset).items()):
        ranked = sorted(rows, key=lambda r: (float(r["objective_score"]), str(r["policy"])))
        best = ranked[0]
        second = ranked[1] if len(ranked) > 1 else ranked[0]
        labels.append(
            {
                "context_id": best["context_id"],
                "tau_ai_us": best["tau_ai_us"],
                "delay_events": best["delay_events"],
                "target_load_A": best["target_load_A"],
                "target_label": best["target_label"],
                "load_drop_norm": best["load_drop_norm"],
                "objective": best["objective"],
                "objective_alpha_settle": best["objective_alpha_settle"],
                "n_candidate_policies": len(rows),
                "best_policy": best["policy"],
                "best_selected_ref_slew_us": best["selected_ref_slew_us"],
                "best_objective_score": best["objective_score"],
                "second_best_policy": second["policy"],
                "second_best_score": second["objective_score"],
                "decision_margin": float(second["objective_score"]) - float(best["objective_score"]),
            }
        )
    return labels


def write_csv(path: Path, rows: list[dict[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if not rows:
        raise ValueError(f"No rows for {path}")
    fields = list(rows[0].keys())
    with path.open("w", encoding="utf-8", newline="") as fp:
        writer = csv.DictWriter(fp, fieldnames=fields)
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def policy_row(rows: list[dict[str, object]], policy: str) -> dict[str, object] | None:
    for row in rows:
        if row["policy"] == policy:
            return row
    return None


def mean(values: list[float]) -> float:
    if not values:
        return math.nan
    return sum(values) / len(values)


def choose_mean_policy(rows: list[dict[str, object]]) -> str:
    by_policy: dict[str, list[float]] = defaultdict(list)
    for row in rows:
        by_policy[str(row["policy"])].append(float(row["objective_score"]))
    if not by_policy:
        return POLICIES[0]
    return min(by_policy.items(), key=lambda kv: (mean(kv[1]), kv[0]))[0]


def predict_objective_mean(train: list[dict[str, object]], ctx_rows: list[dict[str, object]]) -> str:
    obj = str(ctx_rows[0]["objective"])
    pool = [r for r in train if r["objective"] == obj]
    return choose_mean_policy(pool or train)


def predict_objective_nearest_tau(train: list[dict[str, object]], ctx_rows: list[dict[str, object]]) -> str:
    obj = str(ctx_rows[0]["objective"])
    tau = float(ctx_rows[0]["tau_ai_us"])
    obj_pool = [r for r in train if r["objective"] == obj]
    if not obj_pool:
        return choose_mean_policy(train)
    dmin = min(abs(float(r["tau_ai_us"]) - tau) for r in obj_pool)
    tau_pool = [r for r in obj_pool if abs(float(r["tau_ai_us"]) - tau) == dmin]
    return choose_mean_policy(tau_pool or obj_pool)


def distance(a: dict[str, object], b: dict[str, object]) -> float:
    return math.sqrt(
        (float(a["load_drop_norm"]) - float(b["load_drop_norm"])) ** 2
        + 4.0 * (float(a["objective_alpha_settle"]) - float(b["objective_alpha_settle"])) ** 2
        + 0.08 * (float(a["delay_events"]) - float(b["delay_events"])) ** 2
        + 0.15 * ((float(a["selected_ref_slew_us"]) - float(b["selected_ref_slew_us"])) / 80.0) ** 2
    )


def predict_knn_score(train: list[dict[str, object]], ctx_rows: list[dict[str, object]]) -> str:
    predictions: dict[str, float] = {}
    for candidate in ctx_rows:
        same_policy = [r for r in train if r["policy"] == candidate["policy"]]
        pool = same_policy or train
        scored = sorted((distance(candidate, r), float(r["objective_score"])) for r in pool)
        k = min(5, len(scored))
        weights = []
        for d, score in scored[:k]:
            w = 1.0 / (1.0 + 20.0 * d)
            weights.append((w, score))
        predictions[str(candidate["policy"])] = sum(w * s for w, s in weights) / sum(w for w, _ in weights)
    return min(predictions.items(), key=lambda kv: (kv[1], kv[0]))[0]


def feature_vector(row: dict[str, object]) -> list[float]:
    load = float(row["load_drop_norm"])
    alpha = float(row["objective_alpha_settle"]) / 0.10
    delay = float(row["delay_events"]) / 10.0
    slew = float(row["selected_ref_slew_us"]) / 80.0
    feats = [
        1.0,
        load,
        alpha,
        delay,
        slew,
        slew * slew,
        delay * delay,
        load * alpha,
        load * delay,
        alpha * delay,
        load * slew,
        alpha * slew,
        delay * slew,
    ]
    for policy in POLICIES[:-1]:
        feats.append(1.0 if row["policy"] == policy else 0.0)
    return feats


def solve_linear_system(a: list[list[float]], b: list[float]) -> list[float]:
    n = len(b)
    aug = [row[:] + [b[i]] for i, row in enumerate(a)]
    for col in range(n):
        pivot = max(range(col, n), key=lambda r: abs(aug[r][col]))
        if abs(aug[pivot][col]) < 1e-12:
            aug[col][col] += 1e-8
            pivot = col
        aug[col], aug[pivot] = aug[pivot], aug[col]
        div = aug[col][col]
        for j in range(col, n + 1):
            aug[col][j] /= div
        for r in range(n):
            if r == col:
                continue
            factor = aug[r][col]
            if factor == 0:
                continue
            for j in range(col, n + 1):
                aug[r][j] -= factor * aug[col][j]
    return [aug[i][n] for i in range(n)]


def fit_ridge(train: list[dict[str, object]], ridge: float = 0.04) -> list[float]:
    xs = [feature_vector(r) for r in train]
    ys = [float(r["objective_score"]) for r in train]
    n = len(xs[0])
    xtx = [[0.0 for _ in range(n)] for _ in range(n)]
    xty = [0.0 for _ in range(n)]
    for x, y in zip(xs, ys):
        for i in range(n):
            xty[i] += x[i] * y
            for j in range(n):
                xtx[i][j] += x[i] * x[j]
    for i in range(1, n):
        xtx[i][i] += ridge
    return solve_linear_system(xtx, xty)


def predict_ridge_score(train: list[dict[str, object]], ctx_rows: list[dict[str, object]]) -> str:
    beta = fit_ridge(train)
    preds: dict[str, float] = {}
    for row in ctx_rows:
        x = feature_vector(row)
        preds[str(row["policy"])] = sum(b * xi for b, xi in zip(beta, x))
    return min(preds.items(), key=lambda kv: (kv[1], kv[0]))[0]


def evaluate(dataset: list[dict[str, object]]) -> list[dict[str, object]]:
    grouped = group_by_context(dataset)
    contexts = sorted(grouped.keys())
    eval_rows: list[dict[str, object]] = []

    split_defs: list[tuple[str, str, float | str]] = []
    for tau in sorted({float(k[0]) for k in contexts}):
        split_defs.append(("leave_one_tau", "tau_ai_us", tau))
    for target in sorted({float(k[1]) for k in contexts}):
        split_defs.append(("leave_one_target", "target_load_A", target))

    model_fns = {
        "fixed_40us": lambda tr, rows: "fixed_40us_precommitted",
        "fixed_80us": lambda tr, rows: "fixed_80us_precommitted",
        "zero_delay_objective_table": lambda tr, rows: ZERO_DELAY_OBJECTIVE_POLICY[str(rows[0]["objective"])],
        "trained_objective_mean_table": predict_objective_mean,
        "trained_objective_nearest_tau_table": predict_objective_nearest_tau,
        "knn_score_supervisor": predict_knn_score,
        "ridge_score_supervisor": predict_ridge_score,
    }

    for split_type, split_field, heldout in split_defs:
        if split_field == "tau_ai_us":
            test_keys = [k for k in contexts if float(k[0]) == float(heldout)]
            train = [r for r in dataset if float(r["tau_ai_us"]) != float(heldout)]
        else:
            test_keys = [k for k in contexts if float(k[1]) == float(heldout)]
            train = [r for r in dataset if float(r["target_load_A"]) != float(heldout)]

        for key in test_keys:
            rows = sorted(grouped[key], key=lambda r: str(r["policy"]))
            oracle = min(rows, key=lambda r: (float(r["objective_score"]), str(r["policy"])))
            for model, fn in model_fns.items():
                pred_policy = fn(train, rows)
                pred = policy_row(rows, pred_policy)
                if pred is None:
                    pred_policy = "fixed_40us_precommitted"
                    pred = policy_row(rows, pred_policy)
                assert pred is not None
                regret = float(pred["objective_score"]) - float(oracle["objective_score"])
                eval_rows.append(
                    {
                        "split_type": split_type,
                        "heldout_field": split_field,
                        "heldout_value": heldout,
                        "model": model,
                        "context_id": oracle["context_id"],
                        "tau_ai_us": oracle["tau_ai_us"],
                        "target_load_A": oracle["target_load_A"],
                        "target_label": oracle["target_label"],
                        "objective": oracle["objective"],
                        "objective_alpha_settle": oracle["objective_alpha_settle"],
                        "oracle_policy": oracle["policy"],
                        "oracle_selected_ref_slew_us": oracle["selected_ref_slew_us"],
                        "oracle_score": oracle["objective_score"],
                        "pred_policy": pred["policy"],
                        "pred_selected_ref_slew_us": pred["selected_ref_slew_us"],
                        "pred_score": pred["objective_score"],
                        "regret": regret,
                        "policy_correct": int(pred["policy"] == oracle["policy"]),
                        "slew_abs_error_us": abs(float(pred["selected_ref_slew_us"]) - float(oracle["selected_ref_slew_us"])),
                    }
                )
    return eval_rows


def summarize(eval_rows: list[dict[str, object]]) -> list[dict[str, object]]:
    grouped: dict[tuple[str, str], list[dict[str, object]]] = defaultdict(list)
    for row in eval_rows:
        grouped[(str(row["split_type"]), str(row["model"]))].append(row)
    summary: list[dict[str, object]] = []
    for (split_type, model), rows in sorted(grouped.items()):
        regrets = [float(r["regret"]) for r in rows]
        acc = [float(r["policy_correct"]) for r in rows]
        slew_err = [float(r["slew_abs_error_us"]) for r in rows]
        summary.append(
            {
                "split_type": split_type,
                "model": model,
                "n_contexts": len(rows),
                "mean_regret": mean(regrets),
                "median_regret": statistics.median(regrets),
                "max_regret": max(regrets),
                "zero_regret_rate": mean([1.0 if r <= 1e-9 else 0.0 for r in regrets]),
                "regret_le_0p5_rate": mean([1.0 if r <= 0.5 else 0.0 for r in regrets]),
                "policy_accuracy": mean(acc),
                "mean_slew_abs_error_us": mean(slew_err),
            }
        )
    return summary


def fmt(x: object, digits: int = 3) -> str:
    if isinstance(x, str):
        return x
    try:
        return f"{float(x):.{digits}f}"
    except Exception:
        return str(x)


def markdown_table(rows: list[dict[str, object]], fields: list[str]) -> str:
    out = ["| " + " | ".join(fields) + " |", "| " + " | ".join(["---"] * len(fields)) + " |"]
    for row in rows:
        out.append("| " + " | ".join(fmt(row.get(f, "")) for f in fields) + " |")
    return "\n".join(out)


def make_svg(summary: list[dict[str, object]]) -> None:
    FIG.mkdir(parents=True, exist_ok=True)
    models = [
        "zero_delay_objective_table",
        "trained_objective_nearest_tau_table",
        "knn_score_supervisor",
        "ridge_score_supervisor",
        "fixed_40us",
        "fixed_80us",
    ]
    split_names = ["leave_one_tau", "leave_one_target"]
    lookup = {(r["split_type"], r["model"]): float(r["mean_regret"]) for r in summary}
    rows = [(split, model, lookup.get((split, model), 0.0)) for split in split_names for model in models]
    width, height = 920, 430
    left, top = 260, 42
    bar_h, gap = 16, 7
    max_val = max(v for _, _, v in rows) or 1.0
    chart_w = 560
    colors = {
        "leave_one_tau": "#3b82f6",
        "leave_one_target": "#f97316",
    }
    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        '<rect width="100%" height="100%" fill="white"/>',
        '<text x="24" y="26" font-size="18" font-family="Arial" font-weight="bold">R022 supervisor mean regret by cross-validation split</text>',
        '<text x="24" y="48" font-size="12" font-family="Arial" fill="#555">Lower is better; regret is predicted-policy objective score minus oracle score.</text>',
    ]
    y = top + 30
    for split, model, val in rows:
        if model == models[0]:
            parts.append(f'<text x="24" y="{y-8}" font-size="13" font-family="Arial" font-weight="bold" fill="#333">{split}</text>')
        w = 0 if max_val == 0 else chart_w * val / max_val
        parts.append(f'<text x="34" y="{y+12}" font-size="11" font-family="Arial" fill="#333">{model}</text>')
        parts.append(f'<rect x="{left}" y="{y}" width="{w:.1f}" height="{bar_h}" fill="{colors[split]}" opacity="0.82"/>')
        parts.append(f'<text x="{left + w + 6:.1f}" y="{y+12}" font-size="11" font-family="Arial" fill="#333">{val:.3f}</text>')
        y += bar_h + gap
        if model == models[-1]:
            y += 18
    parts.append(f'<line x1="{left}" y1="{top+10}" x2="{left}" y2="{height-36}" stroke="#999" stroke-width="1"/>')
    parts.append('</svg>')
    FIG_SVG.write_text("\n".join(parts), encoding="utf-8")


def write_reports(dataset: list[dict[str, object]], labels: list[dict[str, object]], summary: list[dict[str, object]]) -> None:
    summary_sorted = sorted(summary, key=lambda r: (r["split_type"], float(r["mean_regret"])))
    tau_rows = [r for r in summary_sorted if r["split_type"] == "leave_one_tau"]
    target_rows = [r for r in summary_sorted if r["split_type"] == "leave_one_target"]
    best_tau = min(tau_rows, key=lambda r: float(r["mean_regret"]))
    best_target = min(target_rows, key=lambda r: float(r["mean_regret"]))
    zero_tau = next(r for r in tau_rows if r["model"] == "zero_delay_objective_table")
    zero_target = next(r for r in target_rows if r["model"] == "zero_delay_objective_table")
    fixed40_tau = next(r for r in tau_rows if r["model"] == "fixed_40us")
    fixed40_target = next(r for r in target_rows if r["model"] == "fixed_40us")
    ridge_target = next(r for r in target_rows if r["model"] == "ridge_score_supervisor")
    fixed_improve_tau = 100.0 * (float(fixed40_tau["mean_regret"]) - float(best_tau["mean_regret"])) / float(fixed40_tau["mean_regret"])
    fixed_improve_target = 100.0 * (float(fixed40_target["mean_regret"]) - float(best_target["mean_regret"])) / float(fixed40_target["mean_regret"])
    tau_margin_vs_zero = float(zero_tau["mean_regret"]) - float(best_tau["mean_regret"])
    target_margin_vs_zero = float(ridge_target["mean_regret"]) - float(zero_target["mean_regret"])
    zero_margin_count = sum(1 for r in labels if abs(float(r["decision_margin"])) <= 1e-9)
    small_margin_count = sum(1 for r in labels if float(r["decision_margin"]) <= 0.25)

    label_rows = sorted(labels, key=lambda r: (float(r["tau_ai_us"]), float(r["target_load_A"]), str(r["objective"])))
    label_preview = label_rows[:12]

    report = f"""# R022 可解释 AI/回归器监督层基线

## 目的

本实验把已完成的表驱动 `T_slew` 延迟提交开关级结果，整理成一个可解释 AI 监督层前置验证问题：监督层不替代 IQCOT 内环，而是在每个切载上下文中选择一个已经验证过的低维参考斜率策略。评价指标不是单纯标签准确率，而是实际 objective regret：

```text
regret = score(predicted policy) - score(oracle policy)
```

## 数据结构

- 原始开关级 delayed-reference 工况：`60` 行，来自 `tau_AI=0.5/1/2/5 us`、`3` 个切载目标、`5` 个候选策略。
- 展开为候选策略打分数据：`{len(dataset)}` 行，即每个工况按 `base`、`score+0.05T_settle`、`score+0.10T_settle` 三个目标函数各生成一行。
- 监督上下文标签：`{len(labels)}` 行，即 `4` 个正延迟 × `3` 个切载目标 × `3` 个目标函数。
- 候选动作限定为：`fixed_40us_precommitted`、`fixed_80us_precommitted`、`oracle_base_table`、`table_settle005`、`table_settle010`。这仍是策略/回归器前置验证，不是神经网络 AI-in-loop。

## 交叉验证结果

### Leave-One-Tau-Out

{markdown_table(tau_rows, ["model", "n_contexts", "mean_regret", "median_regret", "max_regret", "zero_regret_rate", "policy_accuracy", "mean_slew_abs_error_us"])}

### Leave-One-Target-Out

{markdown_table(target_rows, ["model", "n_contexts", "mean_regret", "median_regret", "max_regret", "zero_regret_rate", "policy_accuracy", "mean_slew_abs_error_us"])}

## 关键观察

1. 在 leave-one-tau-out 中，最低平均 regret 的模型是 `{best_tau["model"]}`，mean regret 为 `{fmt(best_tau["mean_regret"])}`，比固定 `40 us` 基线降低约 `{fmt(fixed_improve_tau, 1)}%`，但相对零延迟目标表的优势只有 `{fmt(tau_margin_vs_zero)}`。这说明延迟坐标有用，但当前样本下只是边际增益。
2. 在 leave-one-target-out 中，最低平均 regret 仍是 `zero_delay_objective_table`，mean regret 为 `{fmt(best_target["mean_regret"])}`；最佳 score 回归器 `ridge_score_supervisor` 的 mean regret 为 `{fmt(ridge_target["mean_regret"])}`，比零延迟目标表高 `{fmt(target_margin_vs_zero)}`，但仍明显优于固定 `40 us` 和 `80 us`。这应写成“强基线下的部分正结果”，不能写成 AI 全面获胜。
3. `36` 个监督上下文中有 `{zero_margin_count}` 个 oracle 决策完全并列，另有 `{small_margin_count}` 个上下文的第一、第二策略差距不超过 `0.25` 分。因此 policy accuracy 偏低并不完全等同控制性能差，regret 和 zero-regret rate 更适合作为主指标。
4. 当前最有论文价值的说法是：回归器可在已有开关级表驱动结果上学习“候选策略的相对打分”，从而把查表监督层推进到可解释 score-prediction supervisor。它仍不等于真实神经网络接入 Simulink，也不等同硬件验证。

## Oracle 标签预览

{markdown_table(label_preview, ["tau_ai_us", "target_label", "objective", "best_policy", "best_selected_ref_slew_us", "best_objective_score", "second_best_policy", "decision_margin"])}

## 输出文件

- `{DATASET_CSV.as_posix()}`
- `{LABELS_CSV.as_posix()}`
- `{EVAL_CSV.as_posix()}`
- `{SUMMARY_CSV.as_posix()}`
- `{FIG_SVG.as_posix()}`

## 结论边界

- 本实验只复用派生 Simulink delayed-reference 结果，不新增开关级仿真。
- 监督层只在候选策略集合中选择 `T_slew` 调度策略，不输出 gate command。
- 不声称 `T_slew` 存在全局最优，也不声称 PIS-IEK 精确预测大切载第一峰。
- 这一步是 AI/table-in-loop 与真实神经网络 AI-in-loop 之间的中间证据。
"""

    paper = f"""### 10.3 可解释 score 回归监督层前置验证

在完成表驱动监督层的 `0.5/1/2/5 us` 参数提交延迟验证后，本文进一步将同一批派生开关级结果整理为一个可解释 AI/回归器前置验证问题。原始数据包含 `60` 个 delayed-reference 开关级工况；按 `base`、`score+0.05T_settle` 和 `score+0.10T_settle` 三个目标函数展开后，形成 `{len(dataset)}` 行候选策略打分样本和 `{len(labels)}` 个监督上下文标签。监督层输入为切载幅度、目标函数权重、`tau_AI` 与事件延迟数，输出不直接作用于门极，而是在 `fixed 40us`、`fixed 80us`、base-score table、`alpha=0.05` table 和 `alpha=0.10` table 之间选择低维参考斜率策略。

评价采用 leave-one-tau-out 与 leave-one-target-out 交叉验证，并以 regret 衡量模型选择的策略与当前上下文 oracle 策略之间的差距。leave-one-tau-out 中，最佳基线 `{best_tau["model"]}` 的 mean regret 为 `{fmt(best_tau["mean_regret"])}`；leave-one-target-out 中，最佳基线 `{best_target["model"]}` 的 mean regret 为 `{fmt(best_target["mean_regret"])}`。这说明已有 PIS-IEK 坐标下的目标权重、负载下降幅度和参数提交延迟可以被组织成 score-prediction supervisor 的训练接口，而不必把 AI 直接接入 IQCOT 内环。

更重要的是，这个结果没有给出“AI 全面优于查表”的过强结论。leave-one-tau-out 中，延迟最近邻目标表相对零延迟目标表只降低 `{fmt(tau_margin_vs_zero)}` 的 mean regret；leave-one-target-out 中，零延迟目标表仍是最强基线，ridge score supervisor 虽优于固定斜率，却没有超过该强基线。由于 `36` 个监督上下文里有 `{zero_margin_count}` 个 oracle 策略并列、`{small_margin_count}` 个上下文的一二名差距不超过 `0.25` 分，本文更稳妥的表述应是：可解释监督层能够近似 delayed-reference 策略排序，并显著优于固定斜率基线，但当前数据尚不足以证明其稳定优于零延迟目标表。

该结果仍需谨慎解释。首先，候选动作仍来自离散表驱动策略，尚未证明连续 `T_slew` 回归或神经网络 AI-in-loop 优于表驱动策略。其次，交叉验证样本只有 `36` 个上下文标签，因此应把它写成“可解释监督层可近似已有 delayed-reference 策略排序”的前置证据，而不是“AI 已经完成开关级闭环验证”。它的实际价值在于把下一步 AI 训练目标从黑箱调参收窄为：学习候选低维参数策略的相对 objective score，并在 PIS-IEK 给出的事件延迟坐标中做安全选择。
"""

    REPORT_MD.write_text(report, encoding="utf-8")
    PAPER_SECTION_MD.write_text(paper, encoding="utf-8")


def main() -> None:
    raw = read_raw_rows()
    dataset = make_dataset(raw)
    labels = make_labels(dataset)
    eval_rows = evaluate(dataset)
    summary = summarize(eval_rows)

    write_csv(DATASET_CSV, dataset)
    write_csv(LABELS_CSV, labels)
    write_csv(EVAL_CSV, eval_rows)
    write_csv(SUMMARY_CSV, summary)
    make_svg(summary)
    write_reports(dataset, labels, summary)

    print(f"raw_rows={len(raw)}")
    print(f"dataset_rows={len(dataset)}")
    print(f"context_labels={len(labels)}")
    print(f"eval_rows={len(eval_rows)}")
    print(f"summary_rows={len(summary)}")
    print(f"wrote={REPORT_MD}")


if __name__ == "__main__":
    main()
