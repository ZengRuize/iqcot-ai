"""R049N offline waveform-metric audit for independent-clock reentry.

Audits the wave CSV files emitted by
``iqcot_r049n_pr_ecb_independent_clock_reentry_chunk(true)`` using the R049H
three-window metric gate.
"""
from __future__ import annotations

import csv
import math
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

R049K_BASELINE = {
    "0.050": {"peak": 2.1103, "t_load": 450.050, "qh4": 1, "ton4": 50.5},
    "0.105": {"peak": 2.0936, "t_load": 450.105, "qh4": 0, "ton4": 0.0},
}

BASELINE_TOLERANCE = {
    "t_load_step_us": 0.001,
    "peak": 0.02,
    "remaining_ton4": 2.0,
}

RESULTS_CSV = OUT / "r049n_independent_clock_reentry_results_full.csv"


@dataclass(frozen=True)
class CaseSpec:
    offset_us: float
    controller: str
    action_class: str
    filename: str


CASES = [
    CaseSpec(0.050, "A0", "baseline_same_model",
             "r049n_20A_off0p050_a0_r049n_independent_clock_reentry_wave.csv"),
    CaseSpec(0.050, "A2", "independent_clock_one_shot_reentry",
             "r049n_20A_off0p050_a2_independent_clock_r049n_independent_clock_reentry_wave.csv"),
    CaseSpec(0.105, "A0", "baseline_same_model",
             "r049n_20A_off0p105_a0_r049n_independent_clock_reentry_wave.csv"),
    CaseSpec(0.105, "A2", "independent_clock_one_shot_reentry",
             "r049n_20A_off0p105_a2_independent_clock_r049n_independent_clock_reentry_wave.csv"),
]


def empty_metric():
    return {"count": 0, "max_mV": float("-inf"), "max_time_us": float("nan"),
            "min_mV": float("inf"), "min_time_us": float("nan"), "pp_mV": float("nan")}


def update_metric(metric, t_us, dv_mV):
    metric["count"] += 1
    if dv_mV > metric["max_mV"]:
        metric["max_mV"] = dv_mV
        metric["max_time_us"] = t_us
    if dv_mV < metric["min_mV"]:
        metric["min_mV"] = dv_mV
        metric["min_time_us"] = t_us


def finalize_metric(metric):
    if metric["count"] == 0:
        metric["max_mV"] = float("nan")
        metric["max_time_us"] = float("nan")
        metric["min_mV"] = float("nan")
        metric["min_time_us"] = float("nan")
        metric["pp_mV"] = float("nan")
        return
    metric["pp_mV"] = metric["max_mV"] - metric["min_mV"]


def window_name_for_time(t_us):
    for idx, (name, lo, hi) in enumerate(WINDOWS):
        if idx == 0 and lo <= t_us <= hi:
            return name
        if idx > 0 and lo < t_us <= hi:
            return name
    return None


def is_nan_value(value):
    try:
        return math.isnan(float(value))
    except (TypeError, ValueError):
        return str(value).strip().lower() in {"nan", ""}


def audit_case(spec):
    path = DATA / spec.filename
    if not path.exists():
        raise FileNotFoundError(path)

    metrics = {name: empty_metric() for name, _, _ in WINDOWS}
    first_inhibit_us = float("nan")
    release_clock_time_us = float("nan")
    oneshot_time_us = float("nan")
    inhibit_raw_duration_us = 0.0
    effective_inhibit_duration_us = 0.0
    initial_error_mV = float("nan")
    final_error_mV = float("nan")
    rows = []

    with path.open(newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        prev_t = None
        for row in reader:
            t_us = float(row["time_from_load_step_us"])
            dv_mV = (float(row["vout_V"]) - 1.0) * 1000.0
            inhibit = float(row.get("inhibit_raw", "0")) > 0.5
            release_clock = float(row.get("release_clock", "0")) > 0.5
            one_shot = float(row.get("one_shot_done", "0")) > 0.5

            if inhibit and is_nan_value(first_inhibit_us):
                first_inhibit_us = t_us
            if release_clock and is_nan_value(release_clock_time_us):
                release_clock_time_us = t_us
            if one_shot and is_nan_value(oneshot_time_us):
                oneshot_time_us = t_us
            if prev_t is not None and inhibit:
                dt = max(0.0, t_us - prev_t)
                inhibit_raw_duration_us += dt
                if not one_shot:
                    effective_inhibit_duration_us += dt
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

    out_rows = []
    for name, lo, hi in WINDOWS:
        metric = metrics[name]
        finalize_metric(metric)
        out_rows.append({
            "run": "R049N", "target": "20A",
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
            "inhibit_raw_duration_us": inhibit_raw_duration_us,
            "effective_inhibit_duration_us": effective_inhibit_duration_us,
            "first_inhibit_us": first_inhibit_us,
            "release_clock_time_us": release_clock_time_us,
            "oneshot_time_us": oneshot_time_us,
            "wave_csv": str(path),
        })
    return out_rows


def write_csv(path, rows):
    if not rows:
        return
    with path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)


def pair_rows(case_rows):
    by_key = {}
    for row in case_rows:
        key = (row["offset_us"], row["window"], row["controller"])
        by_key[key] = row

    out = []
    for offset_us in ["0.050", "0.105"]:
        for window, _, _ in WINDOWS:
            a0 = by_key.get((offset_us, window, "A0"))
            a2 = by_key.get((offset_us, window, "A2"))
            if a0 is None or a2 is None:
                continue
            a0_max = float(a0["max_mV"])
            a2_max = float(a2["max_mV"])
            a0_min = float(a0["min_mV"])
            a2_min = float(a2["min_mV"])
            out.append({
                "run": "R049N",
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
                "a2_inhibit_raw_duration_us": a2["inhibit_raw_duration_us"],
                "a2_effective_inhibit_duration_us": a2["effective_inhibit_duration_us"],
                "a2_first_inhibit_us": a2["first_inhibit_us"],
                "a2_release_clock_time_us": a2["release_clock_time_us"],
                "a2_oneshot_time_us": a2["oneshot_time_us"],
            })
    return out


def check_baseline():
    failures = []
    if not RESULTS_CSV.exists():
        return [f"missing results CSV: {RESULTS_CSV}"]

    with RESULTS_CSV.open(newline="", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))

    for offset_key, ref in R049K_BASELINE.items():
        candidates = [
            row for row in rows
            if row.get("controller") == "A0_no_inhibit"
            and abs(float(row.get("load_step_offset_us", "nan")) - float(offset_key)) < 1e-9
        ]
        if len(candidates) != 1:
            failures.append(f"offset {offset_key}: expected one A0 row, found {len(candidates)}")
            continue
        row = candidates[0]

        t_load = float(row["t_load_step_us"])
        if abs(t_load - ref["t_load"]) > BASELINE_TOLERANCE["t_load_step_us"]:
            failures.append(f"offset {offset_key}: t_load_step {t_load:.6f}us vs {ref['t_load']:.6f}us")

        peak = float(row["delta_v_actual_peak_mV"])
        if abs(peak - ref["peak"]) > BASELINE_TOLERANCE["peak"]:
            failures.append(f"offset {offset_key}: peak {peak:.4f}mV vs {ref['peak']:.4f}mV")

        qh4 = int(round(float(row["qh4_at_step"])))
        if qh4 != int(ref["qh4"]):
            failures.append(f"offset {offset_key}: qh4_at_step {qh4} vs {int(ref['qh4'])}")

        ton4 = float(row["remaining_ton4_ns"])
        if abs(ton4 - ref["ton4"]) > BASELINE_TOLERANCE["remaining_ton4"]:
            failures.append(f"offset {offset_key}: remaining Ton4 {ton4:.4f}ns vs {ref['ton4']:.4f}ns")

    return failures


def select_decision(pair_deltas, baseline_failures):
    if baseline_failures:
        return "IMPLEMENTATION_ISSUE"
    early_a2 = [r for r in pair_deltas if r["window"] == "early_local_peak"]
    if any(is_nan_value(row.get("a2_oneshot_time_us")) for row in early_a2):
        return "IMPLEMENTATION_ISSUE"
    if any(is_nan_value(row.get("a2_release_clock_time_us")) for row in early_a2):
        return "IMPLEMENTATION_ISSUE"
    by_key = {(str(r["offset_us"]), str(r["window"])): r for r in pair_deltas}
    active_early = by_key.get(("0.050", "early_local_peak"))
    if active_early is None:
        return "IMPLEMENTATION_ISSUE"
    recovery_improvements = [
        float(r["peak_improvement_mV"]) for r in pair_deltas
        if str(r["window"]) == "recovery_peak"
    ]
    undershoot_penalties = [
        float(r["undershoot_improvement_mV"]) for r in pair_deltas
    ]
    if any(v < -0.5 for v in undershoot_penalties):
        return "MODEL_REVISED"
    if float(active_early["peak_improvement_mV"]) >= 0.05:
        return "MODEL_CONFIRMED"
    if any(p > 0.02 for p in recovery_improvements):
        return "MODEL_REVISED"
    return "CLAIM_DOWNGRADED"


def fmt(value, digits=4):
    try:
        return f"{float(value):.{digits}f}"
    except (TypeError, ValueError):
        return str(value)


def write_report(pair_deltas, baseline_failures, decision, path):
    lines = [
        "# R049N PR-ECB Independent-Clock Reentry Waveform Metric Audit\n",
        "Date: 2026-06-25\n",
        "\n## Baseline check vs R049K / R049L repair\n",
    ]
    if baseline_failures:
        lines.append("\n**BASELINE MISMATCH:**\n")
        for failure in baseline_failures:
            lines.append(f"- {failure}\n")
        lines.append("\nStatus: IMPLEMENTATION_ISSUE\n")
    else:
        lines.append("\nBaseline matches the repaired R049K-compatible gate within tolerance.\n")

    lines += [
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

    lines += [
        "\n## Independent-clock one-shot timing\n",
        "| Offset | A2 first inhibit us | A2 release_clock us | A2 one-shot done us | A2 raw inhibit us | A2 effective inhibit us |\n",
        "|---:|---:|---:|---:|---:|---:|\n",
    ]
    for row in pair_deltas:
        if str(row["window"]) == "early_local_peak":
            lines.append(
                f"| `{row['offset_us']}` | "
                f"`{fmt(row['a2_first_inhibit_us'])}` | "
                f"`{fmt(row['a2_release_clock_time_us'])}` | "
                f"`{fmt(row['a2_oneshot_time_us'])}` | "
                f"`{fmt(row['a2_inhibit_raw_duration_us'])}` | "
                f"`{fmt(row['a2_effective_inhibit_duration_us'])}` |\n"
            )

    lines += [
        "\n## Decision\n",
        f"```text\n{decision}\n```\n",
        "\n## Claim boundary\n",
        "R049N is a derived-Simulink switching chunk only. It does not validate hardware/HIL behavior, "
        "does not complete PR-ECB, and does not make the independent phase-clock a final controller; "
        "it only tests whether an upstream predicted-slot release can fire and how it changes the "
        "R049H early/recovery/late waveform windows.\n",
    ]
    path.write_text("".join(lines), encoding="utf-8")


def main():
    case_rows = []
    for spec in CASES:
        try:
            case_rows.extend(audit_case(spec))
        except FileNotFoundError as exc:
            print(f"SKIP (no wave data yet): {exc}")
    if not case_rows:
        print("R049N_DECISION=IMPLEMENTATION_ISSUE (no wave data to audit)")
        return

    pair_deltas = pair_rows(case_rows)
    baseline_failures = check_baseline()
    decision = select_decision(pair_deltas, baseline_failures)

    case_path = OUT / "r049n_waveform_metric_case_windows.csv"
    pair_path = OUT / "r049n_waveform_metric_pair_delta.csv"
    report_path = OUT / "r049n_waveform_metric_summary.md"
    write_csv(case_path, case_rows)
    write_csv(pair_path, pair_deltas)
    write_report(pair_deltas, baseline_failures, decision, report_path)
    print(f"R049N_CASE_WINDOWS={case_path}")
    print(f"R049N_PAIR_DELTA={pair_path}")
    print(f"R049N_REPORT={report_path}")
    print(f"R049N_DECISION={decision}")
    if baseline_failures:
        print("BASELINE_CHECK=FAIL")
        for failure in baseline_failures:
            print(f"  {failure}")
    else:
        print("BASELINE_CHECK=PASS")


if __name__ == "__main__":
    main()
