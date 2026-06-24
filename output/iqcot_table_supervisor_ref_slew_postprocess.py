"""Build the table-supervisor validation matrix for four-phase IQCOT.

This script does not claim a new switching simulation. It reuses the
completed dense+long Simulink reference-slew sweep to create:

- a policy/case/delay validation plan for table-in-loop testing;
- zero-delay expected policy rankings, used as the reference ordering;
- a short report and paper paragraph with explicit claim boundaries.

The actual delayed switching validation is implemented in the companion
MATLAB script: iqcot_table_supervisor_ref_slew_validation.m.
"""

from __future__ import annotations

import csv
from dataclasses import dataclass
from pathlib import Path
from html import escape
from statistics import mean


ROOT = Path("E:/Desktop/codex")
OUT = ROOT / "output"
FIG = OUT / "figures"

SCORES_CSV = OUT / "iqcot_dynamic_ref_slew_dense_long_combined_scores.csv"
TRAINING_CSV = OUT / "iqcot_ai_supervisor_training_targets.csv"

PLAN_CSV = OUT / "iqcot_table_supervisor_validation_plan.csv"
ZERO_DELAY_EVAL_CSV = OUT / "iqcot_table_supervisor_zero_delay_reference_eval.csv"
REPORT_MD = OUT / "iqcot_table_supervisor_validation_report.md"
PAPER_SECTION_MD = OUT / "iqcot_table_supervisor_paper_section.md"
FIG_PATH = FIG / "fig26_table_supervisor_zero_delay_reference.svg"


@dataclass(frozen=True)
class Policy:
    name: str
    kind: str
    alpha: float | None
    fixed_slew_us: float | None
    delay_mode: str
    objective_column: str


POLICIES = [
    Policy("fixed_40us_precommitted", "fixed", None, 40.0, "precommitted", "tradeoff_score"),
    Policy("fixed_80us_precommitted", "fixed", None, 80.0, "precommitted", "tradeoff_score"),
    Policy("oracle_base_table", "table", 0.00, None, "commit_after_tau_ai", "tradeoff_score"),
    Policy("table_settle005", "table", 0.05, None, "commit_after_tau_ai", "score_settle005"),
    Policy("table_settle010", "table", 0.10, None, "commit_after_tau_ai", "score_settle010"),
]

TARGET_LOADS = [20.0, 10.0, 0.001]
TAU_AI_US = [0.0, 0.5, 1.0, 2.0, 5.0]
EVENT_PERIOD_US = 0.5


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


def f(row: dict[str, str], key: str) -> float:
    return float(row[key])


def load_score_lookup(rows: list[dict[str, str]]) -> dict[tuple[float, float], dict[str, str]]:
    lookup: dict[tuple[float, float], dict[str, str]] = {}
    for row in rows:
        lookup[(f(row, "target_load_A"), f(row, "ref_slew_us"))] = row
    return lookup


def load_table_labels(rows: list[dict[str, str]]) -> dict[tuple[float, float], float]:
    labels: dict[tuple[float, float], float] = {}
    for row in rows:
        tau = f(row, "tau_ai_us")
        if tau != 0.0:
            continue
        labels[(f(row, "target_load_A"), f(row, "objective_alpha_settle"))] = f(
            row, "selected_ref_slew_us"
        )
    return labels


def selected_slew(policy: Policy, target_load: float, labels: dict[tuple[float, float], float]) -> float:
    if policy.kind == "fixed":
        assert policy.fixed_slew_us is not None
        return policy.fixed_slew_us
    assert policy.alpha is not None
    return labels[(target_load, policy.alpha)]


def plan_rows(
    score_lookup: dict[tuple[float, float], dict[str, str]],
    labels: dict[tuple[float, float], float],
) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for policy in POLICIES:
        for target_load in TARGET_LOADS:
            slew = selected_slew(policy, target_load, labels)
            base = score_lookup[(target_load, slew)]
            for tau in TAU_AI_US:
                delay_events = int((tau + EVENT_PERIOD_US - 1e-12) // EVENT_PERIOD_US)
                ref_start_delay = 0.0 if policy.delay_mode == "precommitted" else tau
                rows.append(
                    {
                        "policy": policy.name,
                        "policy_kind": policy.kind,
                        "objective_alpha_settle": "" if policy.alpha is None else policy.alpha,
                        "target_load_A": target_load,
                        "load_drop_A": 40.0 - target_load,
                        "selected_ref_slew_us": slew,
                        "tau_ai_us": tau,
                        "delay_events": delay_events,
                        "event_period_us_assumed": EVENT_PERIOD_US,
                        "ref_start_delay_us_for_simulink": ref_start_delay,
                        "delay_mode": policy.delay_mode,
                        "objective_column": policy.objective_column,
                        "zero_delay_undershoot_mV": f(base, "undershoot_mV"),
                        "zero_delay_final_vout_error_mV": f(base, "final_vout_error_mV"),
                        "zero_delay_skip_count_est": f(base, "skip_count_est"),
                        "zero_delay_settle_time_us": f(base, "settle_time_us"),
                        "zero_delay_phase_spacing_std_ns": f(base, "final_phase_spacing_std_ns"),
                        "zero_delay_base_score": f(base, "tradeoff_score"),
                        "zero_delay_score_settle005": f(base, "score_settle005"),
                        "zero_delay_score_settle010": f(base, "score_settle010"),
                        "status": "planned_delayed_switching_validation",
                        "boundary": (
                            "metrics are reused from zero-delay Simulink sweep; "
                            "ref_start_delay_us_for_simulink is a planned delayed-run variable"
                        ),
                    }
                )
    return rows


def write_csv(path: Path, rows: list[dict[str, object]]) -> None:
    if not rows:
        return
    with path.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)


def zero_delay_eval(rows: list[dict[str, object]]) -> list[dict[str, object]]:
    tau0 = [r for r in rows if float(r["tau_ai_us"]) == 0.0]
    out: list[dict[str, object]] = []
    for policy in POLICIES:
        pr = [r for r in tau0 if r["policy"] == policy.name]
        out.append(
            {
                "policy": policy.name,
                "selected_us_20A": next(r["selected_ref_slew_us"] for r in pr if r["target_load_A"] == 20.0),
                "selected_us_10A": next(r["selected_ref_slew_us"] for r in pr if r["target_load_A"] == 10.0),
                "selected_us_near0A": next(r["selected_ref_slew_us"] for r in pr if r["target_load_A"] == 0.001),
                "mean_undershoot_mV": mean(float(r["zero_delay_undershoot_mV"]) for r in pr),
                "max_undershoot_mV": max(float(r["zero_delay_undershoot_mV"]) for r in pr),
                "mean_abs_final_vout_error_mV": mean(
                    abs(float(r["zero_delay_final_vout_error_mV"])) for r in pr
                ),
                "mean_skip_count": mean(float(r["zero_delay_skip_count_est"]) for r in pr),
                "mean_settle_time_us": mean(float(r["zero_delay_settle_time_us"]) for r in pr),
                "mean_phase_spacing_std_ns": mean(
                    float(r["zero_delay_phase_spacing_std_ns"]) for r in pr
                ),
                "mean_base_score": mean(float(r["zero_delay_base_score"]) for r in pr),
                "mean_score_settle005": mean(float(r["zero_delay_score_settle005"]) for r in pr),
                "mean_score_settle010": mean(float(r["zero_delay_score_settle010"]) for r in pr),
                "status": "zero_delay_reference_ordering_only",
            }
        )
    return out


def make_figure(eval_rows: list[dict[str, object]]) -> None:
    FIG.mkdir(parents=True, exist_ok=True)
    series = [
        ("base", "mean_base_score", "#4c78a8"),
        ("score+0.05Tsettle", "mean_score_settle005", "#f58518"),
        ("score+0.10Tsettle", "mean_score_settle010", "#54a24b"),
    ]
    values = [float(r[key]) for _, key, _ in series for r in eval_rows]
    ymax = max(values) * 1.18
    width = 1040
    height = 560
    margin_l = 80
    margin_r = 30
    margin_t = 65
    margin_b = 150
    plot_w = width - margin_l - margin_r
    plot_h = height - margin_t - margin_b
    group_w = plot_w / len(eval_rows)
    bar_w = group_w / 5.0

    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        '<rect width="100%" height="100%" fill="white"/>',
        '<text x="520" y="30" text-anchor="middle" font-family="Arial" font-size="18" font-weight="bold">'
        'Zero-delay reference ordering for table-supervisor validation</text>',
    ]
    # Grid and y labels.
    for i in range(6):
        val = ymax * i / 5
        y = margin_t + plot_h - (val / ymax) * plot_h
        parts.append(
            f'<line x1="{margin_l}" y1="{y:.1f}" x2="{width - margin_r}" y2="{y:.1f}" '
            'stroke="#ddd" stroke-width="1"/>'
        )
        parts.append(
            f'<text x="{margin_l - 10}" y="{y + 4:.1f}" text-anchor="end" '
            f'font-family="Arial" font-size="11">{val:.1f}</text>'
        )
    parts.append(
        f'<line x1="{margin_l}" y1="{margin_t + plot_h}" x2="{width - margin_r}" '
        f'y2="{margin_t + plot_h}" stroke="#333" stroke-width="1"/>'
    )
    parts.append(
        f'<line x1="{margin_l}" y1="{margin_t}" x2="{margin_l}" '
        f'y2="{margin_t + plot_h}" stroke="#333" stroke-width="1"/>'
    )

    for gi, row in enumerate(eval_rows):
        gx = margin_l + gi * group_w + group_w * 0.20
        for si, (_, key, color) in enumerate(series):
            val = float(row[key])
            h = (val / ymax) * plot_h
            x = gx + si * bar_w * 1.15
            y = margin_t + plot_h - h
            parts.append(
                f'<rect x="{x:.1f}" y="{y:.1f}" width="{bar_w:.1f}" height="{h:.1f}" '
                f'fill="{color}"><title>{escape(str(row["policy"]))}: {key}={val:.3f}</title></rect>'
            )
        label = escape(str(row["policy"]).replace("_", " "))
        lx = margin_l + gi * group_w + group_w * 0.50
        ly = margin_t + plot_h + 24
        parts.append(
            f'<text x="{lx:.1f}" y="{ly:.1f}" text-anchor="end" '
            f'font-family="Arial" font-size="10" transform="rotate(-35 {lx:.1f} {ly:.1f})">{label}</text>'
        )

    legend_x = margin_l
    legend_y = height - 35
    for si, (name, _, color) in enumerate(series):
        x = legend_x + si * 210
        parts.append(f'<rect x="{x}" y="{legend_y - 12}" width="14" height="14" fill="{color}"/>')
        parts.append(
            f'<text x="{x + 20}" y="{legend_y}" font-family="Arial" font-size="12">{escape(name)}</text>'
        )
    parts.append(
        '<text x="24" y="285" text-anchor="middle" font-family="Arial" font-size="12" '
        'transform="rotate(-90 24 285)">Mean objective score</text>'
    )
    parts.append("</svg>")
    FIG_PATH.write_text("\n".join(parts), encoding="utf-8")


def fmt(x: float) -> str:
    return f"{x:.3f}"


def write_report(plan: list[dict[str, object]], eval_rows: list[dict[str, object]]) -> None:
    by_policy = {str(r["policy"]): r for r in eval_rows}
    base_best = min(eval_rows, key=lambda r: float(r["mean_base_score"]))
    s005_best = min(eval_rows, key=lambda r: float(r["mean_score_settle005"]))
    s010_best = min(eval_rows, key=lambda r: float(r["mean_score_settle010"]))

    report = f"""# Table-in-loop AI Supervisor Validation Matrix

## Purpose

This artifact advances the four-phase digital IQCOT / PIS-IEK study from a
training-label design to an executable table-in-loop validation plan.  It does
not introduce a new switching run by itself.  The delayed switching run should
be executed with `E:/Desktop/codex/output/iqcot_table_supervisor_ref_slew_validation.m`.

## Generated files

- Plan CSV: `{PLAN_CSV.as_posix()}`
- Zero-delay reference evaluation: `{ZERO_DELAY_EVAL_CSV.as_posix()}`
- Figure: `{FIG_PATH.as_posix()}`
- Companion MATLAB runner: `E:/Desktop/codex/output/iqcot_table_supervisor_ref_slew_validation.m`

## Matrix

- Target cut-load cases: `40A->20A`, `40A->10A`, `40A->near-0A`
- FPGA latency contexts: `{TAU_AI_US}` us
- Event period assumption: `{EVENT_PERIOD_US}` us
- Planned rows: `{len(plan)}`
- Policies: `{", ".join(p.name for p in POLICIES)}`

For fixed precommitted baselines, `ref_start_delay_us_for_simulink=0`.  For
table-driven policies, the delayed Simulink runner should start the reference
ramp at `t_load_step + tau_AI`, which represents parameter computation and
commit delay.  This is still an equivalent delayed-reference experiment, not a
neural-network-in-the-loop hardware result.

## Zero-delay reference ordering

The completed dense+long Simulink sweep gives the following reference ordering
before adding parameter-commit delay:

| Policy | 20A | 10A | near-0A | mean base | mean score 0.05 | mean score 0.10 |
|---|---:|---:|---:|---:|---:|---:|
"""
    for r in eval_rows:
        report += (
            f"| `{r['policy']}` | {r['selected_us_20A']} | {r['selected_us_10A']} | "
            f"{r['selected_us_near0A']} | {fmt(float(r['mean_base_score']))} | "
            f"{fmt(float(r['mean_score_settle005']))} | {fmt(float(r['mean_score_settle010']))} |\n"
        )

    report += f"""
The best zero-delay base-score policy is `{base_best['policy']}` with mean base
score `{fmt(float(base_best['mean_base_score']))}`.  The best zero-delay
`score+0.05*T_settle` policy is `{s005_best['policy']}` with score
`{fmt(float(s005_best['mean_score_settle005']))}`.  The best zero-delay
`score+0.10*T_settle` policy is `{s010_best['policy']}` with score
`{fmt(float(s010_best['mean_score_settle010']))}`.

## Interpretation boundary

This matrix is a bridge, not a final AI claim.  It tells the next Simulink run
exactly which `T_slew` and `ref_start_delay` values to inject into the existing
`From Workspace` reference path.  Only after running the companion MATLAB script
with switching waveforms should the paper claim whether the ordering is
preserved under microsecond parameter-commit delay.
"""
    REPORT_MD.write_text(report, encoding="utf-8")

    table005 = by_policy["table_settle005"]
    oracle = by_policy["oracle_base_table"]
    paper = f"""### Table-in-loop supervisor validation design

To connect the reference-slew sweep with the FPGA-delay argument, a
table-driven supervisory layer was formulated before training a neural
network.  The validation matrix contains `{len(plan)}` planned cases: three
cut-load depths, five latency contexts, and five policies.  Fixed `40 us` and
`80 us` baselines are treated as precommitted references, while table-driven
policies start the reference transition at `t_load_step + tau_AI` to emulate
parameter computation and commit delay.  Under the zero-delay reference
ordering inherited from the dense+long Simulink sweep, the base-score table
selects `80/80/60 us` and reaches mean base score
`{fmt(float(oracle['mean_base_score']))}`, whereas the settling-aware
`alpha=0.05` table selects `30/50/60 us` and reaches mean
`score+0.05*T_settle` of `{fmt(float(table005['mean_score_settle005']))}`.
The next validation step is therefore not to claim a globally optimal
`T_slew`, but to test whether this ordering is preserved when the selected
reference profile is committed after `0.5-5 us` of equivalent FPGA delay in the
derived switching model.
"""
    PAPER_SECTION_MD.write_text(paper, encoding="utf-8")


def main() -> None:
    scores = read_csv(SCORES_CSV)
    training = read_csv(TRAINING_CSV)
    lookup = load_score_lookup(scores)
    labels = load_table_labels(training)
    plan = plan_rows(lookup, labels)
    eval_rows = zero_delay_eval(plan)
    write_csv(PLAN_CSV, plan)
    write_csv(ZERO_DELAY_EVAL_CSV, eval_rows)
    make_figure(eval_rows)
    write_report(plan, eval_rows)
    print(f"PLAN={PLAN_CSV}")
    print(f"ZERO_DELAY_EVAL={ZERO_DELAY_EVAL_CSV}")
    print(f"REPORT={REPORT_MD}")
    print(f"PAPER_SECTION={PAPER_SECTION_MD}")
    print(f"FIGURE={FIG_PATH}")


if __name__ == "__main__":
    main()
