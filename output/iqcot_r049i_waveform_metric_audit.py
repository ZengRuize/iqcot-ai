"""R049I offline waveform-metric audit for gentle phase-selective Ton trim.

This script does not run Simulink.  It audits the R049I wave CSV files emitted
by ``iqcot_r049i_pr_ecb_gentle_tontrim_chunk(true)`` using the R049H window
definitions:

    early_local_peak: 0-2 us
    recovery_peak:   2-12 us
    late_settling:   12-80 us
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
    CaseSpec(0.050, "A0", "baseline_same_model", "r049i_20A_off0p050_a0_r049i_gentle_tontrim_wave.csv"),
    CaseSpec(0.050, "A2", "gentle_phase_selective_ton_trim_120ns", "r049i_20A_off0p050_a2_gentle_trim_r049i_gentle_tontrim_wave.csv"),
    CaseSpec(0.105, "A0", "baseline_same_model", "r049i_20A_off0p105_a0_r049i_gentle_tontrim_wave.csv"),
    CaseSpec(0.105, "A2", "gentle_phase_selective_ton_trim_120ns", "r049i_20A_off0p105_a2_gentle_trim_r049i_gentle_tontrim_wave.csv"),
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
    ton_cmd4_ns = float("nan")

    rows: list[tuple[float, float, float]] = []
    with path.open(newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            t_us = float(row["time_from_load_step_us"])
            dv_mV = (float(row["vout_V"]) - 1.0) * 1000.0
            ton_cmd4_ns = float(row.get("ton_cmd4_s", "nan")) * 1e9
            rows.append((t_us, dv_mV, ton_cmd4_ns))
            name = window_name_for_time(t_us)
            if name is not None:
                update_metric(metrics[name], t_us, dv_mV)

    if rows:
        initial_error_mV = rows[0][1]
        tail = [dv for t_us, dv, _ in rows if 70.0 <= t_us <= 80.0]
        if tail:
            final_error_mV = sum(tail) / len(tail)

    out_rows: list[dict[str, object]] = []
    for name, lo, hi in WINDOWS:
        metric = metrics[name]
        finalize_metric(metric)
        out_rows.append(
            {
                "run": "R049I",
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
                "ton_cmd4_ns_first_sample": ton_cmd4_ns,
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
                "run": "R049I",
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
    active_recovery = by_key.get(("0.050", "recovery_peak"))
    post_early = by_key.get(("0.105", "early_local_peak"))
    if active_early is None or active_recovery is None:
        return "IMPLEMENTATION_ISSUE"
    if float(active_early["a2_minus_a0_max_mV"]) > 0.05:
        return "MODEL_REVISED"
    if post_early and abs(float(post_early["a2_minus_a0_max_mV"])) > 0.05:
        return "MODEL_REVISED"
    if float(active_early["peak_improvement_mV"]) >= 0.05 and float(active_recovery["peak_improvement_mV"]) >= -0.05:
        return "MODEL_CONFIRMED"
    return "CLAIM_DOWNGRADED"


def fmt(value: object, digits: int = 4) -> str:
    try:
        return f"{float(value):.{digits}f}"
    except (TypeError, ValueError):
        return str(value)


def get_pair(pair_deltas: list[dict[str, object]], offset_us: str, window: str) -> dict[str, object]:
    for row in pair_deltas:
        if row["offset_us"] == offset_us and row["window"] == window:
            return row
    raise KeyError((offset_us, window))


def write_report(pair_deltas: list[dict[str, object]], decision: str, path: Path) -> None:
    lines: list[str] = []
    lines.append("# R049I PR-ECB Gentle Ton-Trim Waveform Metric Audit\n")
    lines.append("Date: 2026-06-24\n")
    lines.append("## Scope\n")
    lines.append(
        "R049I audits one new derived-Simulink action chunk: `40A -> 20A` at "
        "`0.05us` and `0.105us`, A0 same-model no-trim versus A2 gentle "
        "phase-selective Ton trim with `Tton_trunc_min=120ns`.\n"
    )
    lines.append("It uses the R049H three-window metric gate:\n")
    lines.append("- `0-2 us`: early local peak / immediate switching interaction.\n")
    lines.append("- `2-12 us`: recovery peak.\n")
    lines.append("- `12-80 us`: late settling and undershoot.\n")
    lines.append("\n## Floor selection note\n")
    lines.append(
        "R049G baseline traces show `Ton_cmd4=196.5ns`; in the `0.05us` "
        "active-HS row, phase 4 has about `52ns` remaining at the load step, "
        "so the pulse has already been on for about `144.5ns`.  R049I selects "
        "`120ns`, the gentlest end of the suggested `80-120ns` first-candidate "
        "band, while explicitly treating the already-elapsed on-time as a risk: "
        "the action may still terminate the current active-HS pulse quickly.\n"
    )
    lines.append("\n## A2 versus A0 windowed comparison\n")
    lines.append("| Offset | Window | Peak improvement | A2-A0 max | A0 max time | A2 max time | Undershoot change | Final error change |\n")
    lines.append("|---:|---|---:|---:|---:|---:|---:|---:|\n")
    for row in pair_deltas:
        lines.append(
            f"| `{row['offset_us']}` | `{row['window']}` | "
            f"`{fmt(row['peak_improvement_mV'])} mV` | "
            f"`{fmt(row['a2_minus_a0_max_mV'])} mV` | "
            f"`{fmt(row['a0_max_time_us'], 3)} us` | "
            f"`{fmt(row['a2_max_time_us'], 3)} us` | "
            f"`{fmt(row['undershoot_improvement_mV'])} mV` | "
            f"`{fmt(row['a2_minus_a0_final_error_mV'])} mV` |\n"
        )

    lines.append("\n## Decision\n")
    lines.append(f"```text\n{decision}\n```\n")

    early = get_pair(pair_deltas, "0.050", "early_local_peak")
    recovery = get_pair(pair_deltas, "0.050", "recovery_peak")
    lines.append("\n## Diagnosis\n")
    if decision == "MODEL_REVISED":
        lines.append(
            "The gentle `120ns` phase-selective Ton trim still fails the R049H "
            "early-local-peak acceptance gate: "
            f"`A2-A0={fmt(early['a2_minus_a0_max_mV'])}mV` in `0-2us`, with "
            f"recovery-window `A2-A0={fmt(recovery['a2_minus_a0_max_mV'])}mV`. "
            "Per the R049I stopping rule, do not continue scanning Ton floors; "
            "the next action should move to deferred post-active pulse inhibit "
            "or controlled reentry.\n"
        )
    elif decision == "MODEL_CONFIRMED":
        lines.append(
            "The gentle Ton trim passes the active-HS early-local-peak gate "
            "without a recovery-window penalty in this minimal chunk.  This is "
            "still derived-Simulink evidence only and should not be expanded "
            "into a broad claim without held-out validation.\n"
        )
    else:
        lines.append(
            "The action does not provide enough windowed benefit in this small "
            "chunk to support promotion beyond a downgraded or implementation "
            "diagnosis.\n"
        )

    lines.append("\n## Claim boundary\n")
    lines.append(
        "R049I is derived-Simulink switching evidence only.  It is not hardware/HIL "
        "validation, not complete PR-ECB control, not global calibration, and not "
        "a universal additive `E_HS,rem` law.\n"
    )
    path.write_text("".join(lines), encoding="utf-8")


def main() -> None:
    case_rows: list[dict[str, object]] = []
    for spec in CASES:
        case_rows.extend(audit_case(spec))

    pair_deltas = pair_rows(case_rows)
    decision = select_decision(pair_deltas)

    case_path = OUT / "r049i_waveform_metric_case_windows.csv"
    pair_path = OUT / "r049i_waveform_metric_pair_delta.csv"
    report_path = OUT / "r049i_waveform_metric_summary.md"

    write_csv(case_path, case_rows)
    write_csv(pair_path, pair_deltas)
    write_report(pair_deltas, decision, report_path)

    print(f"R049I_CASE_WINDOWS={case_path}")
    print(f"R049I_PAIR_DELTA={pair_path}")
    print(f"R049I_REPORT={report_path}")
    print(f"R049I_DECISION={decision}")


if __name__ == "__main__":
    main()
