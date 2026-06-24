"""Summarize table-supervisor delayed-reference switching sensitivity.

Combines:
- zero-delay reference ordering from dense+long sweep post-processing;
- delayed-reference switching results at tau_AI=0.5/1/2 us;
- delayed-reference switching results at tau_AI=5 us.

The resulting tables keep claim boundaries explicit: tau=0 is a reference
ordering, while tau>0 comes from derived Simulink delayed-reference runs.
"""

from __future__ import annotations

import csv
from collections import defaultdict
from html import escape
from pathlib import Path
from statistics import mean


ROOT = Path("E:/Desktop/codex")
OUT = ROOT / "output"
FIG = OUT / "figures"

ZERO_REF = OUT / "iqcot_table_supervisor_zero_delay_reference_eval.csv"
RES_SMALL = OUT / "iqcot_table_supervisor_validation_results_tau0p5_1_2us.csv"
RES_5 = OUT / "iqcot_table_supervisor_validation_results.csv"

SUMMARY = OUT / "iqcot_table_supervisor_delay_sensitivity_by_tau.csv"
BEST = OUT / "iqcot_table_supervisor_delay_sensitivity_best_by_tau.csv"
REPORT = OUT / "iqcot_table_supervisor_delay_sensitivity_report.md"
FIG_PATH = FIG / "fig28_table_supervisor_delay_sensitivity.svg"

POLICY_ORDER = [
    "fixed_40us_precommitted",
    "fixed_80us_precommitted",
    "oracle_base_table",
    "table_settle005",
    "table_settle010",
]


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


def f(row: dict[str, str], key: str) -> float:
    return float(row[key])


def write_csv(path: Path, rows: list[dict[str, object]]) -> None:
    if not rows:
        return
    with path.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)


def zero_rows() -> list[dict[str, object]]:
    rows = []
    for r in read_csv(ZERO_REF):
        rows.append(
            {
                "tau_ai_us": 0.0,
                "policy": r["policy"],
                "mean_undershoot_mV": f(r, "mean_undershoot_mV"),
                "max_undershoot_mV": f(r, "max_undershoot_mV"),
                "mean_abs_final_vout_error_mV": f(r, "mean_abs_final_vout_error_mV"),
                "mean_skip_count": f(r, "mean_skip_count"),
                "mean_settle_time_us": f(r, "mean_settle_time_us"),
                "mean_phase_spacing_std_ns": f(r, "mean_phase_spacing_std_ns"),
                "mean_base_score": f(r, "mean_base_score"),
                "mean_score_settle005": f(r, "mean_score_settle005"),
                "mean_score_settle010": f(r, "mean_score_settle010"),
                "source": "zero_delay_reference_from_dense_long_sweep",
            }
        )
    return rows


def switching_rows(paths: list[Path]) -> list[dict[str, object]]:
    groups: dict[tuple[float, str], list[dict[str, str]]] = defaultdict(list)
    for path in paths:
        for r in read_csv(path):
            if r["success"] not in {"1", "true", "True"}:
                continue
            groups[(f(r, "tau_ai_us"), r["policy"])].append(r)

    rows = []
    for (tau, policy), rs in sorted(groups.items(), key=lambda x: (x[0][0], POLICY_ORDER.index(x[0][1]))):
        rows.append(
            {
                "tau_ai_us": tau,
                "policy": policy,
                "mean_undershoot_mV": mean(f(r, "undershoot_mV") for r in rs),
                "max_undershoot_mV": max(f(r, "undershoot_mV") for r in rs),
                "mean_abs_final_vout_error_mV": mean(abs(f(r, "final_vout_error_mV")) for r in rs),
                "mean_skip_count": mean(f(r, "skip_count_est") for r in rs),
                "mean_settle_time_us": mean(f(r, "settle_time_us") for r in rs),
                "mean_phase_spacing_std_ns": mean(f(r, "final_phase_spacing_std_ns") for r in rs),
                "mean_base_score": mean(f(r, "base_score") for r in rs),
                "mean_score_settle005": mean(f(r, "score_settle005") for r in rs),
                "mean_score_settle010": mean(f(r, "score_settle010") for r in rs),
                "source": "derived_simulink_delayed_reference",
            }
        )
    return rows


def best_rows(summary: list[dict[str, object]]) -> list[dict[str, object]]:
    out = []
    by_tau: dict[float, list[dict[str, object]]] = defaultdict(list)
    for r in summary:
        by_tau[float(r["tau_ai_us"])].append(r)
    objectives = [
        ("base", "mean_base_score"),
        ("score_settle005", "mean_score_settle005"),
        ("score_settle010", "mean_score_settle010"),
    ]
    for tau in sorted(by_tau):
        rows = by_tau[tau]
        for label, col in objectives:
            b = min(rows, key=lambda r: float(r[col]))
            out.append(
                {
                    "tau_ai_us": tau,
                    "objective": label,
                    "best_policy": b["policy"],
                    "best_score": b[col],
                    "mean_undershoot_mV": b["mean_undershoot_mV"],
                    "mean_settle_time_us": b["mean_settle_time_us"],
                    "source": b["source"],
                }
            )
    return out


def fmt(x: object) -> str:
    return f"{float(x):.3f}"


def make_svg(summary: list[dict[str, object]]) -> None:
    FIG.mkdir(parents=True, exist_ok=True)
    taus = sorted({float(r["tau_ai_us"]) for r in summary})
    colors = {
        "fixed_40us_precommitted": "#999999",
        "fixed_80us_precommitted": "#4c78a8",
        "oracle_base_table": "#72b7b2",
        "table_settle005": "#f58518",
        "table_settle010": "#54a24b",
    }
    width, height = 1120, 620
    ml, mr, mt, mb = 80, 210, 55, 80
    pw, ph = width - ml - mr, height - mt - mb
    ymax = max(float(r["mean_score_settle005"]) for r in summary) * 1.12
    xmin, xmax = min(taus), max(taus)
    if xmax == xmin:
        xmax = xmin + 1

    def sx(t: float) -> float:
        return ml + (t - xmin) / (xmax - xmin) * pw

    def sy(v: float) -> float:
        return mt + ph - v / ymax * ph

    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        '<rect width="100%" height="100%" fill="white"/>',
        '<text x="560" y="30" text-anchor="middle" font-family="Arial" font-size="18" font-weight="bold">'
        'Table-supervisor delay sensitivity: mean score+0.05Tsettle</text>',
    ]
    for i in range(6):
        val = ymax * i / 5
        y = sy(val)
        parts.append(f'<line x1="{ml}" y1="{y:.1f}" x2="{ml+pw}" y2="{y:.1f}" stroke="#ddd"/>')
        parts.append(f'<text x="{ml-8}" y="{y+4:.1f}" text-anchor="end" font-family="Arial" font-size="11">{val:.1f}</text>')
    parts.append(f'<line x1="{ml}" y1="{mt+ph}" x2="{ml+pw}" y2="{mt+ph}" stroke="#333"/>')
    parts.append(f'<line x1="{ml}" y1="{mt}" x2="{ml}" y2="{mt+ph}" stroke="#333"/>')
    for tau in taus:
        x = sx(tau)
        parts.append(f'<line x1="{x:.1f}" y1="{mt+ph}" x2="{x:.1f}" y2="{mt+ph+6}" stroke="#333"/>')
        parts.append(f'<text x="{x:.1f}" y="{mt+ph+24}" text-anchor="middle" font-family="Arial" font-size="11">{tau:g}</text>')
    by_policy = {p: [] for p in POLICY_ORDER}
    for r in summary:
        by_policy[str(r["policy"])].append(r)
    for policy in POLICY_ORDER:
        rs = sorted(by_policy[policy], key=lambda r: float(r["tau_ai_us"]))
        points = [(sx(float(r["tau_ai_us"])), sy(float(r["mean_score_settle005"]))) for r in rs]
        d = " ".join(f"{x:.1f},{y:.1f}" for x, y in points)
        parts.append(f'<polyline points="{d}" fill="none" stroke="{colors[policy]}" stroke-width="2.3"/>')
        for x, y in points:
            parts.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="3.4" fill="{colors[policy]}"/>')
    lx, ly = ml + pw + 25, mt + 15
    for i, policy in enumerate(POLICY_ORDER):
        y = ly + i * 25
        parts.append(f'<rect x="{lx}" y="{y-11}" width="14" height="14" fill="{colors[policy]}"/>')
        parts.append(f'<text x="{lx+20}" y="{y}" font-family="Arial" font-size="12">{escape(policy)}</text>')
    parts.append(f'<text x="{ml+pw/2}" y="{height-25}" text-anchor="middle" font-family="Arial" font-size="12">tau_AI (us)</text>')
    parts.append('<text x="25" y="310" text-anchor="middle" font-family="Arial" font-size="12" transform="rotate(-90 25 310)">Mean score+0.05Tsettle</text>')
    parts.append("</svg>")
    FIG_PATH.write_text("\n".join(parts), encoding="utf-8")


def write_report(summary: list[dict[str, object]], best: list[dict[str, object]]) -> None:
    by_tau = defaultdict(list)
    for r in summary:
        by_tau[float(r["tau_ai_us"])].append(r)

    text = """# Table-Supervisor Delay Sensitivity

## Scope

This report combines the zero-delay reference ordering with derived Simulink
delayed-reference switching runs at `tau_AI=0.5/1/2/5 us`.  The table-driven
supervisor still only schedules `T_slew`; it does not replace the IQCOT inner
loop and is not neural-network AI-in-loop.

## Best Policy By Delay

| tau_AI | best base | best 0.05 | best 0.10 |
|---:|---|---|---|
"""
    for tau in sorted(by_tau):
        bbase = next(r for r in best if float(r["tau_ai_us"]) == tau and r["objective"] == "base")
        b005 = next(r for r in best if float(r["tau_ai_us"]) == tau and r["objective"] == "score_settle005")
        b010 = next(r for r in best if float(r["tau_ai_us"]) == tau and r["objective"] == "score_settle010")
        text += (
            f"| `{tau:g} us` | `{bbase['best_policy']}` ({fmt(bbase['best_score'])}) | "
            f"`{b005['best_policy']}` ({fmt(b005['best_score'])}) | "
            f"`{b010['best_policy']}` ({fmt(b010['best_score'])}) |\n"
        )

    text += """
## Interpretation

The ordering is objective-sensitive across all tested delays.  The base-score
winner shifts from the zero-delay oracle base table to `table_settle005` at
`5 us`, while smaller delayed-reference slices favor `oracle_base_table` for
base score.  The strong settling penalty consistently favors
`table_settle010`.  This is a useful result, not a contradiction: the best
`T_slew` schedule depends jointly on the objective and the parameter-commit
delay.

## Boundary

`tau=0` rows are reference-ordering rows from prior dense+long sweep
post-processing.  `tau>0` rows are derived switching-model delayed-reference
runs.  None of these rows prove hardware performance or neural-network
AI-in-loop superiority.
"""
    REPORT.write_text(text, encoding="utf-8")


def main() -> None:
    summary = zero_rows() + switching_rows([RES_SMALL, RES_5])
    summary = sorted(summary, key=lambda r: (float(r["tau_ai_us"]), POLICY_ORDER.index(str(r["policy"]))))
    best = best_rows(summary)
    write_csv(SUMMARY, summary)
    write_csv(BEST, best)
    make_svg(summary)
    write_report(summary, best)
    print(f"SUMMARY={SUMMARY}")
    print(f"BEST={BEST}")
    print(f"REPORT={REPORT}")
    print(f"FIGURE={FIG_PATH}")


if __name__ == "__main__":
    main()
