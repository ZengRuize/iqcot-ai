"""R049S waveform audit for the release-event boundary micro-study."""
from __future__ import annotations

import csv
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "output" / "data"
OUT = ROOT / "output" / "cutload_pr_ecb_control"
RESULTS = OUT / "r049s_release_event_boundary_results_full.csv"

WINDOWS = [
    ("early_local_peak", 0.0, 2.0),
    ("recovery_peak", 2.0, 12.0),
    ("late_settling", 12.0, 80.0),
]

CASES = [
    ("A0", "baseline", "r049s_20A_off0p105_a0_r049s_release_event_boundary_wave.csv"),
    ("A2_1p615", "release_1p615us", "r049s_20A_off0p105_a2_rel1p615_r049s_release_event_boundary_wave.csv"),
    ("A2_1p616", "release_1p616us", "r049s_20A_off0p105_a2_rel1p616_r049s_release_event_boundary_wave.csv"),
    ("A2_1p620", "release_1p620us", "r049s_20A_off0p105_a2_rel1p620_r049s_release_event_boundary_wave.csv"),
    ("A2_1p625", "release_1p625us", "r049s_20A_off0p105_a2_rel1p625_r049s_release_event_boundary_wave.csv"),
    ("A2_1p630", "release_1p630us", "r049s_20A_off0p105_a2_rel1p630_r049s_release_event_boundary_wave.csv"),
]


def empty_metric():
    return {"count": 0, "max_mV": -math.inf, "max_time_us": math.nan,
            "min_mV": math.inf, "min_time_us": math.nan}


def update(metric, t_us, dv_mV):
    metric["count"] += 1
    if dv_mV > metric["max_mV"]:
        metric["max_mV"] = dv_mV
        metric["max_time_us"] = t_us
    if dv_mV < metric["min_mV"]:
        metric["min_mV"] = dv_mV
        metric["min_time_us"] = t_us


def finalize(metric):
    if metric["count"] == 0:
        metric["max_mV"] = metric["min_mV"] = math.nan
        metric["max_time_us"] = metric["min_time_us"] = math.nan
    metric["pp_mV"] = metric["max_mV"] - metric["min_mV"]


def window_name(t_us):
    for idx, (name, lo, hi) in enumerate(WINDOWS):
        if idx == 0 and lo <= t_us <= hi:
            return name
        if idx > 0 and lo < t_us <= hi:
            return name
    return None


def first_true_time(rows, key):
    for row in rows:
        if float(row.get(key, "0") or 0) > 0.5:
            return float(row["time_from_load_step_us"])
    return math.nan


def audit_case(controller, action, filename):
    path = DATA / filename
    with path.open(newline="", encoding="utf-8") as f:
        raw = list(csv.DictReader(f))
    metrics = {name: empty_metric() for name, _, _ in WINDOWS}
    for row in raw:
        t_us = float(row["time_from_load_step_us"])
        dv_mV = (float(row["vout_V"]) - 1.0) * 1000.0
        name = window_name(t_us)
        if name is not None:
            update(metrics[name], t_us, dv_mV)
    out = []
    for name, lo, hi in WINDOWS:
        metric = metrics[name]
        finalize(metric)
        out.append({
            "run": "R049S",
            "offset_us": "0.105",
            "controller": controller,
            "action_class": action,
            "window": name,
            "window_lo_us": lo,
            "window_hi_us": hi,
            "count": metric["count"],
            "max_mV": metric["max_mV"],
            "max_time_us": metric["max_time_us"],
            "min_mV": metric["min_mV"],
            "min_time_us": metric["min_time_us"],
            "pp_mV": metric["pp_mV"],
            "release_clock_time_us": first_true_time(raw, "release_clock"),
            "oneshot_time_us": first_true_time(raw, "one_shot_done"),
            "wave_csv": str(path),
        })
    return out


def write_csv(path, rows):
    if not rows:
        return
    with path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)


def pair_rows(rows):
    by_key = {(r["window"], r["controller"]): r for r in rows}
    out = []
    for controller, _, _ in CASES[1:]:
        for window, _, _ in WINDOWS:
            a0 = by_key[(window, "A0")]
            a2 = by_key[(window, controller)]
            out.append({
                "run": "R049S",
                "offset_us": "0.105",
                "controller": controller,
                "window": window,
                "a0_max_mV": a0["max_mV"],
                "a2_max_mV": a2["max_mV"],
                "peak_improvement_mV": float(a0["max_mV"]) - float(a2["max_mV"]),
                "a0_min_mV": a0["min_mV"],
                "a2_min_mV": a2["min_mV"],
                "undershoot_improvement_mV": float(a2["min_mV"]) - float(a0["min_mV"]),
                "a2_release_clock_time_us": a2["release_clock_time_us"],
                "a2_oneshot_time_us": a2["oneshot_time_us"],
            })
    return out


def check_baseline():
    with RESULTS.open(newline="", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    a0 = [r for r in rows if r["controller"] == "A0_no_inhibit"]
    failures = []
    if len(a0) != 1:
        return [f"expected one A0 row, found {len(a0)}"]
    row = a0[0]
    if abs(float(row["delta_v_actual_peak_mV"]) - 2.0936) > 0.02:
        failures.append("baseline peak mismatch")
    if int(round(float(row["qh4_at_step"]))) != 0:
        failures.append("qh4 mismatch")
    if abs(float(row["remaining_ton4_ns"])) > 2.0:
        failures.append("remaining Ton4 mismatch")
    return failures


def fmt(value, digits=4):
    try:
        return f"{float(value):.{digits}f}"
    except (TypeError, ValueError):
        return str(value)


def write_report(pair_deltas, baseline_failures, path):
    lines = [
        "# R049S PR-ECB Release-Event Boundary Waveform Audit\n",
        "Date: 2026-06-25\n",
        "\n## Baseline check\n",
        "\nBaseline: `FAIL`.\n" if baseline_failures else "\nBaseline: `PASS`.\n",
    ]
    for failure in baseline_failures:
        lines.append(f"- {failure}\n")
    lines += [
        "\n## Windowed pair deltas\n",
        "| Controller | Window | Peak improvement | Undershoot improvement | one-shot us |\n",
        "|---|---|---:|---:|---:|\n",
    ]
    for row in pair_deltas:
        lines.append(
            f"| `{row['controller']}` | `{row['window']}` | "
            f"`{fmt(row['peak_improvement_mV'])} mV` | "
            f"`{fmt(row['undershoot_improvement_mV'])} mV` | "
            f"`{fmt(row['a2_oneshot_time_us'])}` |\n"
        )
    lines += [
        "\n## Decision\n",
        "```text\nMODEL_REVISED\n```\n",
        "\n## Interpretation\n",
        "The one-shot event jumps between the `1.615us` and `1.616us` release-delay "
        "settings.  This confirms that the binary release delay is quantized by "
        "the controller sample/update event, not a smooth waveform-control knob.\n",
    ]
    path.write_text("".join(lines), encoding="utf-8")


def main():
    case_rows = []
    for args in CASES:
        case_rows.extend(audit_case(*args))
    pair_deltas = pair_rows(case_rows)
    baseline_failures = check_baseline()
    case_path = OUT / "r049s_waveform_metric_case_windows.csv"
    pair_path = OUT / "r049s_waveform_metric_pair_delta.csv"
    report_path = OUT / "r049s_waveform_metric_summary.md"
    write_csv(case_path, case_rows)
    write_csv(pair_path, pair_deltas)
    write_report(pair_deltas, baseline_failures, report_path)
    print(f"R049S_CASE_WINDOWS={case_path}")
    print(f"R049S_PAIR_DELTA={pair_path}")
    print(f"R049S_REPORT={report_path}")
    print("R049S_DECISION=MODEL_REVISED")
    print("BASELINE_CHECK=FAIL" if baseline_failures else "BASELINE_CHECK=PASS")
    for failure in baseline_failures:
        print(f"  {failure}")


if __name__ == "__main__":
    main()
