"""R049K offline waveform-metric audit for shortened soft-reentry proxy.

This script does not run Simulink.  It audits the R049K wave CSV files emitted
by ``iqcot_r049k_pr_ecb_soft_reentry_chunk(true)`` using the R049H
three-window metric gate.
"""

from __future__ import annotations

import csv
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "output" / "data"
OUT = ROOT / "output" / "cutload_pr_ecb_control"

WINDOWS = [
    ("early_local_peak", 0.0, 2.0),
    ("recovery_peak", 2.0, 12.0),
    ("late_settling", 12.0, 80.0),
]


@dataclass(frozen=True)
class CaseSpec:
    offset_us: float
    controller: str
    action_class: str
    filename: str


CASES = [
    CaseSpec(0.050, "A0", "baseline_same_model", "r049k_20A_off0p050_a0_r049k_soft_reentry_wave.csv"),
    CaseSpec(0.050, "A2", "deferred_soft_reentry", "r049k_20A_off0p050_a2_soft_reentry_r049k_soft_reentry_wave.csv"),
    CaseSpec(0.105, "A0", "baseline_same_model", "r049k_20A_off0p105_a0_r049k_soft_reentry_wave.csv"),
    CaseSpec(0.105, "A2", "deferred_soft_reentry", "r049k_20A_off0p105_a2_soft_reentry_r049k_soft_reentry_wave.csv"),
]


def empty_metric() -> dict[str, float | int]:
    return {
        "count": 0,
        "max_mV": float("-inf"),
        "max_time_us": float("nan"),
        "min_mV": float("inf"),
        "min_time_us": float("nan"),
        "pp_mV": float("nan"),
    }


def update_metric(metric: dict[str, float | int], t_us: float, dv_mV: float) -> None:
    metric["count"] = int(metric["count"]) + 1
    if dv_mV > float(metric["max_mV"]):
        metric["max_mV"] = dv_mV
        metric["max_time_us"] = t_us
    if dv_mV < float(metric["min_mV"]):
        metric["min_mV"] = dv_mV
        metric["min_time_us"] = t_us


def finalize_metric(metric: dict[str, float | int]) -> None:
    if int(metric["count"]) == 0:
        metric["max_mV"] = float("nan")
        metric["max_time_us"] = float("nan")
        metric["min_mV"] = float("nan")
        metric["min_time_us"] = float("nan")
        metric["pp_mV"] = float("nan")
        return
    metric["pp_mV"] = float(metric["max_mV"]) - float(metric["min_mV"])


def window_name_for_time(t_us: float) -> str | None:
    for idx, (name, lo, hi) in enumerate(WINDOWS):
        if idx == 0 and lo <= t_us <= hi:
            return name
        if idx > 0 and lo < t_us <= hi:
            return name
    return None


def audit_case(spec: CaseSpec) -> list[dict[str, object]]:
    path = DATA / spec.filename
    if not path.exists():
        raise FileNotFoundError(path)

    metrics = {name: empty_metric() for name, _, _ in WINDOWS}
    initial_error_mV = float("nan")
    final_error_mV = float("nan")
    inhibit_duration_us = 0.0
    first_inhibit_us = float("nan")
    rows: list[tuple[float, float]] = []

    with path.open(newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        prev_t = None
        for row in reader:
            t_us = float(row["time_from_load_step_us"])
            dv_mV = (float(row["vout_V"]) - 1.0) * 1000.0
            inhibit = float(row.get("soft_reentry", "0")) > 0.5
            if inhibit and first_inhibit_us != first_inhibit_us:
                first_inhibit_us = t_us
            if prev_t is not None and inhibit:
                inhibit_duration_us += max(0.0, t_us - prev_t)
            prev_t = t_us
            rows.append((t_us, dv_mV))
            name = window_name_for_time(t_us)
            if name is not None:
                update_metric(metrics[name], t_us, dv_mV)

    if rows:
        initial_error_mV = rows[0][1]
        tail = [dv for t_us, dv in rows if 70.0 <= t_us <= 80.0]
        if tail:
            final_error_mV = sum(tail) / len(tail)

    out_rows: list[dict[str, object]] = []
    for name, lo, hi in WINDOWS:
        metric = metrics[name]
        finalize_metric(metric)
        out_rows.append(
            {
                "run": "R049K",
                "target": "20A",
                "offset_us": f"{spec.offset_us:.3f}",
                "controller": spec.controller,
                "action_class": spec.action_class,
                "window": name,
                "window_lo_us": lo,
                "window_hi_us": hi,
                "count": metric["count"],
                "max_mV": metric["max_mV"],
                "max_time_us": metric["max_time_us"],
                "min_mV": metric["min_mV"],
                "min_time_us": metric["min_time_us"],
                "pp_mV": metric["pp_mV"],
                "initial_error_mV": initial_error_mV,
                "final_error_mV": final_error_mV,
                "inhibit_duration_us": inhibit_duration_us,
                "first_inhibit_us": first_inhibit_us,
                "wave_csv": str(path),
            }
        )
    return out_rows


def write_csv(path: Path, rows: list[dict[str, object]]) -> None:
    if not rows:
        raise ValueError(f"No rows for {path}")
    with path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)


def pair_rows(case_rows: list[dict[str, object]]) -> list[dict[str, object]]:
    grouped: dict[tuple[str, str], dict[str, dict[str, object]]] = {}
    for row in case_rows:
        key = (str(row["offset_us"]), str(row["window"]))
        grouped.setdefault(key, {})[str(row["controller"])] = row

    out: list[dict[str, object]] = []
    for (offset_us, window), by_controller in sorted(grouped.items()):
        if "A0" not in by_controller or "A2" not in by_controller:
            continue
        a0 = by_controller["A0"]
        a2 = by_controller["A2"]
        a0_max = float(a0["max_mV"])
        a2_max = float(a2["max_mV"])
        a0_min = float(a0["min_mV"])
        a2_min = float(a2["min_mV"])
        out.append(
            {
                "run": "R049K",
                "target": "20A",
                "offset_us": offset_us,
                "window": window,
                "a0_max_mV": a0_max,
                "a2_max_mV": a2_max,
                "a2_minus_a0_max_mV": a2_max - a0_max,
                "peak_improvement_mV": a0_max - a2_max,
                "a0_max_time_us": a0["max_time_us"],
                "a2_max_time_us": a2["max_time_us"],
                "a0_min_mV": a0_min,
                "a2_min_mV": a2_min,
                "a2_minus_a0_min_mV": a2_min - a0_min,
                "undershoot_improvement_mV": a2_min - a0_min,
                "a0_final_error_mV": a0["final_error_mV"],
                "a2_final_error_mV": a2["final_error_mV"],
                "a2_minus_a0_final_error_mV": float(a2["final_error_mV"]) - float(a0["final_error_mV"]),
            }
        )
    return out


def select_decision(pair_deltas: list[dict[str, object]]) -> str:
    by_key = {(str(r["offset_us"]), str(r["window"])): r for r in pair_deltas}
    active_early = by_key.get(("0.050", "early_local_peak"))
    if active_early is None:
        return "IMPLEMENTATION_ISSUE"
    if float(active_early["a2_minus_a0_max_mV"]) > 0.05:
        return "MODEL_REVISED"
    if any(float(row["undershoot_improvement_mV"]) < -0.5 for row in pair_deltas):
        return "MODEL_REVISED"
    if float(active_early["peak_improvement_mV"]) >= 0.05:
        return "MODEL_CONFIRMED"
    return "CLAIM_DOWNGRADED"


def fmt(value: object, digits: int = 4) -> str:
    try:
        return f"{float(value):.{digits}f}"
    except (TypeError, ValueError):
        return str(value)


def write_report(pair_deltas: list[dict[str, object]], decision: str, path: Path) -> None:
    lines = [
        "# R049K PR-ECB Short Soft-Reentry Proxy Waveform Metric Audit\n",
        "Date: 2026-06-25\n",
        "## Scope\n",
        "R049K audits one new derived-Simulink request-path action chunk: "
        "`40A -> 20A` at `0.05us` and `0.105us`, A0 same-model no-inhibit "
        "versus A2 shortened soft-reentry proxy.  Ton truncation is "
        "disabled in both A0 and A2.\n",
        "\n## Windowed comparison\n",
        "| Offset | Window | Peak improvement | A2-A0 max | Undershoot change | A0 min | A2 min | Final error change |\n",
        "|---:|---|---:|---:|---:|---:|---:|---:|\n",
    ]
    for row in pair_deltas:
        lines.append(
            f"| `{row['offset_us']}` | `{row['window']}` | "
            f"`{fmt(row['peak_improvement_mV'])} mV` | "
            f"`{fmt(row['a2_minus_a0_max_mV'])} mV` | "
            f"`{fmt(row['undershoot_improvement_mV'])} mV` | "
            f"`{fmt(row['a0_min_mV'])} mV` | "
            f"`{fmt(row['a2_min_mV'])} mV` | "
            f"`{fmt(row['a2_minus_a0_final_error_mV'])} mV` |\n"
        )
    lines.append("\n## Decision\n")
    lines.append(f"```text\n{decision}\n```\n")
    lines.append("\n## Diagnosis\n")
    if decision == "MODEL_REVISED":
        lines.append(
            "The request-path action satisfies the no-current-pulse-truncation "
            "intent, but the shortened `0.07-1.76us` proxy still has an undershoot cost: "
            "it creates an undershoot penalty even while reducing "
            "positive recovery peaks.  The state "
            "machine should either shorten/phase-select the reentry gate further "
            "or move to controlled reentry with softer request restoration.\n"
        )
    else:
        lines.append(
            "The action does not worsen early local peak, but its benefit is too "
            "narrow to promote without the next controlled-reentry step.\n"
        )
    lines.append("\n## Claim boundary\n")
    lines.append(
        "R049K is derived-Simulink switching evidence only.  It is not hardware/HIL "
        "validation, not complete PR-ECB control, and not global calibration.\n"
    )
    path.write_text("".join(lines), encoding="utf-8")


def main() -> None:
    case_rows: list[dict[str, object]] = []
    for spec in CASES:
        case_rows.extend(audit_case(spec))
    pair_deltas = pair_rows(case_rows)
    decision = select_decision(pair_deltas)

    case_path = OUT / "r049k_waveform_metric_case_windows.csv"
    pair_path = OUT / "r049k_waveform_metric_pair_delta.csv"
    report_path = OUT / "r049k_waveform_metric_summary.md"
    write_csv(case_path, case_rows)
    write_csv(pair_path, pair_deltas)
    write_report(pair_deltas, decision, report_path)
    print(f"R049K_CASE_WINDOWS={case_path}")
    print(f"R049K_PAIR_DELTA={pair_path}")
    print(f"R049K_REPORT={report_path}")
    print(f"R049K_DECISION={decision}")


if __name__ == "__main__":
    main()
