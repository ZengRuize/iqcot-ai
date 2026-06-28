from __future__ import annotations

import csv
from pathlib import Path


PROJECT_ROOT = Path("E:/Desktop/codex")
EXPERIMENT_ROOT = PROJECT_ROOT / "experiments" / "E010_load_drop_overshoot"

CASES = [
    ("A0", "e010_a0_40A_to_10A_metrics.csv", "original ideal IQCOT"),
    ("A1", "e010_a1_40A_to_10A_metrics.csv", "Ton truncation only"),
    ("A2", "e010_a2_40A_to_10A_metrics.csv", "Ton truncation + pulse inhibit"),
    ("A3", "e010_a3_40A_to_10A_metrics.csv", "guarded reentry"),
    ("A4", "e010_a4_40A_to_10A_metrics.csv", "AI/table selected a_O"),
]

METRICS = [
    "peak_overshoot_mV",
    "early_local_peak_0_2us_mV",
    "recovery_peak_2_12us_mV",
    "late_settling_12_80us_abs_mV",
    "undershoot_penalty_mV",
    "final_error_mV",
    "phase_current_peak_A",
    "ton_actual_peak_ns",
    "ton_cmd_trunc_peak_ns",
    "ton_trunc_active_fraction",
    "pulse_inhibit_active_fraction",
    "pulse_inhibit_event_est",
]


def read_one(path: Path) -> dict[str, str]:
    with path.open(newline="", encoding="utf-8-sig") as handle:
        rows = list(csv.DictReader(handle))
    if len(rows) != 1:
        raise ValueError(f"Expected exactly one row in {path}, got {len(rows)}")
    return rows[0]


def as_float(row: dict[str, str], name: str) -> float | None:
    raw = row.get(name, "")
    if raw in {"", "NaN", "nan"}:
        return None
    return float(raw)


def fmt(value: float | None) -> str:
    if value is None:
        return "NaN"
    return f"{value:.6g}"


def pct(delta: float | None, base: float | None) -> str:
    if delta is None or base is None or abs(base) < 1e-15:
        return "NaN"
    return f"{100.0 * delta / base:.3g}%"


def main() -> None:
    rows: list[dict[str, str]] = []
    for label, filename, description in CASES:
        row = read_one(EXPERIMENT_ROOT / filename)
        row["case"] = label
        row["description"] = description
        rows.append(row)

    base = rows[0]
    comparison_csv = EXPERIMENT_ROOT / "e010_a0_a4_40A_to_10A_comparison.csv"
    fieldnames = ["case", "description", "variant", "success", *METRICS]
    with comparison_csv.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow({name: row.get(name, "") for name in fieldnames})

    report = EXPERIMENT_ROOT / "e010_a0_a4_40A_to_10A_comparison.md"
    lines: list[str] = []
    lines.append("# E010 A0-A4 40A-to-10A Load-Drop Comparison")
    lines.append("")
    lines.append("Date: 2026-06-28")
    lines.append("")
    lines.append("## Scope")
    lines.append("")
    lines.append(
        "This report compares the first E010 load-drop chunk using derived copies of "
        "the local ideal IQCOT baseline. The `40A -> 10A` load step is an external "
        "disturbance profile, not an AI command."
    )
    lines.append("")
    lines.append("## Metrics")
    lines.append("")
    header = [
        "Case",
        "Description",
        "Peak mV",
        "Recovery 2-12us mV",
        "Late abs mV",
        "Undershoot penalty mV",
        "Final error mV",
        "Pulse inhibit events",
    ]
    lines.append("| " + " | ".join(header) + " |")
    lines.append("|" + "|".join(["---"] * len(header)) + "|")
    for row in rows:
        lines.append(
            "| "
            + " | ".join(
                [
                    row["case"],
                    row["description"],
                    fmt(as_float(row, "peak_overshoot_mV")),
                    fmt(as_float(row, "recovery_peak_2_12us_mV")),
                    fmt(as_float(row, "late_settling_12_80us_abs_mV")),
                    fmt(as_float(row, "undershoot_penalty_mV")),
                    fmt(as_float(row, "final_error_mV")),
                    fmt(as_float(row, "pulse_inhibit_event_est")),
                ]
            )
            + " |"
        )
    lines.append("")
    lines.append("## Delta vs A0")
    lines.append("")
    lines.append("| Case | Delta peak | Delta recovery | Delta late | Delta undershoot | Recovery percent |")
    lines.append("|---|---:|---:|---:|---:|---:|")
    for row in rows[1:]:
        delta_peak = as_float(row, "peak_overshoot_mV") - as_float(base, "peak_overshoot_mV")
        delta_recovery = as_float(row, "recovery_peak_2_12us_mV") - as_float(
            base, "recovery_peak_2_12us_mV"
        )
        delta_late = as_float(row, "late_settling_12_80us_abs_mV") - as_float(
            base, "late_settling_12_80us_abs_mV"
        )
        delta_under = as_float(row, "undershoot_penalty_mV") - as_float(
            base, "undershoot_penalty_mV"
        )
        lines.append(
            f"| {row['case']} | {fmt(delta_peak)} | {fmt(delta_recovery)} | "
            f"{fmt(delta_late)} | {fmt(delta_under)} | "
            f"{pct(delta_recovery, as_float(base, 'recovery_peak_2_12us_mV'))} |"
        )
    lines.append("")
    lines.append("## Classification")
    lines.append("")
    lines.append(
        "`MODEL_REVISED`: A1 confirms that Ton truncation alone reduces the recovery "
        "peak but does not reduce the global peak. A2/A4 show that one projected "
        "early pulse inhibit further reduces recovery peak and slightly reduces the "
        "global peak, but introduces a bounded undershoot penalty. A3 shows the "
        "voltage reentry guard can become a binding safety projection and reject "
        "pulse inhibit, trading performance for zero undershoot."
    )
    lines.append("")
    lines.append("## Evidence Paths")
    lines.append("")
    for label, filename, _description in CASES:
        lines.append(f"- {label} metrics: `{(EXPERIMENT_ROOT / filename).as_posix()}`")
    lines.append(f"- Comparison CSV: `{comparison_csv.as_posix()}`")
    lines.append("")
    report.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"WROTE {comparison_csv}")
    print(f"WROTE {report}")


if __name__ == "__main__":
    main()
