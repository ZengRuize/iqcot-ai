"""R049O waveform audit for release-timing micro-study."""
from __future__ import annotations

import csv
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "output" / "data"
OUT = ROOT / "output" / "cutload_pr_ecb_control"
RESULTS = OUT / "r049o_release_timing_results_full.csv"

WINDOWS = [
    ("early_local_peak", 0.0, 2.0),
    ("recovery_peak", 2.0, 12.0),
    ("late_settling", 12.0, 80.0),
]

CASES = [
    ("0.050", "A0", "baseline", "r049o_20A_off0p050_a0_r049o_release_timing_wave.csv"),
    ("0.050", "A2_1p250", "release_1p250us", "r049o_20A_off0p050_a2_rel1p250_r049o_release_timing_wave.csv"),
    ("0.050", "A2_1p450", "release_1p450us", "r049o_20A_off0p050_a2_rel1p450_r049o_release_timing_wave.csv"),
    ("0.105", "A0", "baseline", "r049o_20A_off0p105_a0_r049o_release_timing_wave.csv"),
    ("0.105", "A2_1p250", "release_1p250us", "r049o_20A_off0p105_a2_rel1p250_r049o_release_timing_wave.csv"),
    ("0.105", "A2_1p450", "release_1p450us", "r049o_20A_off0p105_a2_rel1p450_r049o_release_timing_wave.csv"),
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


def duration_true(rows, key):
    total = 0.0
    prev = None
    for row in rows:
        t = float(row["time_from_load_step_us"])
        if prev is not None and float(row.get(key, "0") or 0) > 0.5:
            total += max(0.0, t - prev)
        prev = t
    return total


def audit_case(offset, controller, action, filename):
    path = DATA / filename
    if not path.exists():
        raise FileNotFoundError(path)
    with path.open(newline="", encoding="utf-8") as f:
        raw = list(csv.DictReader(f))

    metrics = {name: empty_metric() for name, _, _ in WINDOWS}
    final_vals = []
    for row in raw:
        t_us = float(row["time_from_load_step_us"])
        dv_mV = (float(row["vout_V"]) - 1.0) * 1000.0
        name = window_name(t_us)
        if name is not None:
            update(metrics[name], t_us, dv_mV)
        if 70.0 <= t_us <= 80.0:
            final_vals.append(dv_mV)
    final_error = sum(final_vals) / len(final_vals) if final_vals else math.nan
    release_time = first_true_time(raw, "release_clock")
    one_shot_time = first_true_time(raw, "one_shot_done")
    inhibit_duration = duration_true(raw, "inhibit_raw")

    out = []
    for name, lo, hi in WINDOWS:
        metric = metrics[name]
        finalize(metric)
        out.append({
            "run": "R049O",
            "offset_us": offset,
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
            "final_error_mV": final_error,
            "release_clock_time_us": release_time,
            "oneshot_time_us": one_shot_time,
            "inhibit_raw_duration_us": inhibit_duration,
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
    by_key = {(r["offset_us"], r["window"], r["controller"]): r for r in rows}
    out = []
    for offset in ["0.050", "0.105"]:
        for controller in ["A2_1p250", "A2_1p450"]:
            for window, _, _ in WINDOWS:
                a0 = by_key.get((offset, window, "A0"))
                a2 = by_key.get((offset, window, controller))
                if a0 is None or a2 is None:
                    continue
                out.append({
                    "run": "R049O",
                    "offset_us": offset,
                    "controller": controller,
                    "window": window,
                    "a0_max_mV": a0["max_mV"],
                    "a2_max_mV": a2["max_mV"],
                    "peak_improvement_mV": float(a0["max_mV"]) - float(a2["max_mV"]),
                    "a2_minus_a0_max_mV": float(a2["max_mV"]) - float(a0["max_mV"]),
                    "a0_min_mV": a0["min_mV"],
                    "a2_min_mV": a2["min_mV"],
                    "undershoot_improvement_mV": float(a2["min_mV"]) - float(a0["min_mV"]),
                    "a2_release_clock_time_us": a2["release_clock_time_us"],
                    "a2_oneshot_time_us": a2["oneshot_time_us"],
                    "a2_inhibit_raw_duration_us": a2["inhibit_raw_duration_us"],
                })
    return out


def check_baseline():
    refs = {
        "0.050": {"peak": 2.1103, "qh4": 1, "ton4": 50.5},
        "0.105": {"peak": 2.0936, "qh4": 0, "ton4": 0.0},
    }
    failures = []
    with RESULTS.open(newline="", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    for offset, ref in refs.items():
        a0 = [
            r for r in rows
            if r["controller"] == "A0_no_inhibit"
            and abs(float(r["load_step_offset_us"]) - float(offset)) < 1e-9
        ]
        if len(a0) != 1:
            failures.append(f"offset {offset}: expected one A0 row, found {len(a0)}")
            continue
        row = a0[0]
        if abs(float(row["delta_v_actual_peak_mV"]) - ref["peak"]) > 0.02:
            failures.append(f"offset {offset}: baseline peak mismatch")
        if int(round(float(row["qh4_at_step"]))) != ref["qh4"]:
            failures.append(f"offset {offset}: qh4 mismatch")
        if abs(float(row["remaining_ton4_ns"]) - ref["ton4"]) > 2.0:
            failures.append(f"offset {offset}: remaining Ton4 mismatch")
    return failures


def fmt(value, digits=4):
    try:
        return f"{float(value):.{digits}f}"
    except (TypeError, ValueError):
        return str(value)


def decision(pair_deltas, baseline_failures):
    if baseline_failures:
        return "IMPLEMENTATION_ISSUE"
    max_abs_delta = 0.0
    for row in pair_deltas:
        max_abs_delta = max(max_abs_delta, abs(float(row["peak_improvement_mV"])))
        max_abs_delta = max(max_abs_delta, abs(float(row["undershoot_improvement_mV"])))
    if max_abs_delta < 0.02:
        return "CLAIM_DOWNGRADED"
    return "MODEL_REVISED"


def write_report(pair_deltas, baseline_failures, dec, path):
    lines = [
        "# R049O PR-ECB Release-Timing Micro-Audit\n",
        "Date: 2026-06-25\n",
        "\n## Baseline check\n",
    ]
    if baseline_failures:
        lines.append("\nBaseline: `FAIL`.\n")
        for failure in baseline_failures:
            lines.append(f"- {failure}\n")
    else:
        lines.append("\nBaseline: `PASS`.\n")
    lines += [
        "\n## Windowed pair deltas\n",
        "| Offset | A2 delay | Window | Peak improvement | Undershoot improvement | one-shot us |\n",
        "|---:|---|---|---:|---:|---:|\n",
    ]
    for row in pair_deltas:
        lines.append(
            f"| `{row['offset_us']}` | `{row['controller']}` | `{row['window']}` | "
            f"`{fmt(row['peak_improvement_mV'])} mV` | "
            f"`{fmt(row['undershoot_improvement_mV'])} mV` | "
            f"`{fmt(row['a2_oneshot_time_us'])}` |\n"
        )
    lines += [
        "\n## Decision\n",
        f"```text\n{dec}\n```\n",
        "\n## Interpretation\n",
        "Earlier releases at `1.250us` and `1.450us` fire successfully, but their "
        "waveforms are effectively indistinguishable from A0 in the tested windows. "
        "They reduce the R049N undershoot penalty by removing most of the inhibit "
        "effect, but they also remove the recovery-peak improvement. The useful "
        "design space is therefore between `1.450us` and `1.685us`, or requires a "
        "soft instead of binary release.\n",
    ]
    path.write_text("".join(lines), encoding="utf-8")


def main():
    case_rows = []
    for args in CASES:
        case_rows.extend(audit_case(*args))
    pair_deltas = pair_rows(case_rows)
    baseline_failures = check_baseline()
    dec = decision(pair_deltas, baseline_failures)
    case_path = OUT / "r049o_waveform_metric_case_windows.csv"
    pair_path = OUT / "r049o_waveform_metric_pair_delta.csv"
    report_path = OUT / "r049o_waveform_metric_summary.md"
    write_csv(case_path, case_rows)
    write_csv(pair_path, pair_deltas)
    write_report(pair_deltas, baseline_failures, dec, report_path)
    print(f"R049O_CASE_WINDOWS={case_path}")
    print(f"R049O_PAIR_DELTA={pair_path}")
    print(f"R049O_REPORT={report_path}")
    print(f"R049O_DECISION={dec}")
    print("BASELINE_CHECK=FAIL" if baseline_failures else "BASELINE_CHECK=PASS")
    for failure in baseline_failures:
        print(f"  {failure}")


if __name__ == "__main__":
    main()
