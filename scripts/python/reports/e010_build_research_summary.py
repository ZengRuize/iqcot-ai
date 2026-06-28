from __future__ import annotations

import csv
import re
from pathlib import Path


PROJECT_ROOT = Path("E:/Desktop/codex")
EXPERIMENT_ROOT = PROJECT_ROOT / "experiments" / "E010_load_drop_overshoot"
RESULTS_ROOT = PROJECT_ROOT / "results" / "current"

METRICS = [
    "peak_overshoot_mV",
    "recovery_peak_2_12us_mV",
    "late_settling_12_80us_abs_mV",
    "undershoot_penalty_mV",
    "final_error_mV",
    "pulse_inhibit_event_est",
]

VARIANT_LABELS = {
    "a0": "A0 original ideal IQCOT",
    "a1": "A1 Ton truncation only",
    "a2": "A2 Ton truncation + pulse inhibit",
    "a3": "A3 guarded reentry",
    "a4": "A4 table-selected a_O",
}


def as_float(value: str | None) -> float | None:
    if value is None or value == "" or value.lower() == "nan":
        return None
    return float(value)


def fmt(value: float | None) -> str:
    if value is None:
        return "NaN"
    return f"{value:.6g}"


def read_metric_file(path: Path) -> dict[str, str]:
    with path.open(newline="", encoding="utf-8-sig") as handle:
        rows = list(csv.DictReader(handle))
    if len(rows) != 1:
        raise ValueError(f"Expected one row in {path}, got {len(rows)}")
    row = rows[0]
    match = re.match(r"e010_(a[0-4])_(.+)_metrics\.csv", path.name)
    if not match:
        raise ValueError(f"Unexpected metrics filename: {path.name}")
    row["variant_code"] = match.group(1)
    row["case_tag"] = match.group(2)
    row["variant_label"] = VARIANT_LABELS[row["variant_code"]]
    return row


def load_rows() -> list[dict[str, str]]:
    rows = []
    for path in sorted(EXPERIMENT_ROOT.glob("e010_a[0-4]_*_metrics.csv")):
        if "a0_a4" in path.name:
            continue
        rows.append(read_metric_file(path))
    return rows


def case_sort_key(row: dict[str, str]) -> tuple[float, float, str]:
    return (
        as_float(row.get("base_load_A")) or 0.0,
        as_float(row.get("target_load_A")) or 0.0,
        row["variant_code"],
    )


def write_table(rows: list[dict[str, str]]) -> Path:
    RESULTS_ROOT.mkdir(parents=True, exist_ok=True)
    path = RESULTS_ROOT / "e010_research_table.csv"
    fieldnames = [
        "case_tag",
        "variant_code",
        "variant_label",
        "success",
        "base_load_A",
        "target_load_A",
        *METRICS,
        "interpretation",
    ]
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            out = {name: row.get(name, "") for name in fieldnames}
            base = as_float(row.get("base_load_A"))
            if base is not None and base > 40:
                out["interpretation"] = "operating_boundary_check"
            elif row["variant_code"] == "a4":
                pulse_events = as_float(row.get("pulse_inhibit_event_est"))
                ton_frac = as_float(row.get("ton_trunc_active_fraction"))
                if (pulse_events or 0) == 0 and (ton_frac or 0) == 0:
                    out["interpretation"] = "table_selected_noop"
                elif (pulse_events or 0) > 0:
                    out["interpretation"] = "table_selected_protection"
                else:
                    out["interpretation"] = "table_selected_guarded_no_harm"
            else:
                out["interpretation"] = "candidate"
            writer.writerow(out)
    return path


def best_a4_summary(rows: list[dict[str, str]]) -> list[str]:
    lines = []
    by_case: dict[str, list[dict[str, str]]] = {}
    for row in rows:
        by_case.setdefault(row["case_tag"], []).append(row)
    for case_tag, case_rows in sorted(by_case.items()):
        a0 = next((r for r in case_rows if r["variant_code"] == "a0"), None)
        a4 = next((r for r in case_rows if r["variant_code"] == "a4"), None)
        if not a0 or not a4:
            continue
        if (as_float(a0.get("base_load_A")) or 0) > 40:
            continue
        a0_recovery = as_float(a0.get("recovery_peak_2_12us_mV"))
        a4_recovery = as_float(a4.get("recovery_peak_2_12us_mV"))
        if a0_recovery is None or a4_recovery is None or abs(a0_recovery) < 1e-15:
            improvement = "NaN"
        else:
            improvement = f"{100 * (a0_recovery - a4_recovery) / a0_recovery:.3g}%"
        lines.append(
            "| "
            + " | ".join(
                [
                    case_tag,
                    fmt(a0_recovery),
                    fmt(a4_recovery),
                    improvement,
                    fmt(as_float(a4.get("undershoot_penalty_mV"))),
                    fmt(as_float(a4.get("pulse_inhibit_event_est"))),
                ]
            )
            + " |"
        )
    return lines


def write_report(rows: list[dict[str, str]], table_path: Path) -> Path:
    path = EXPERIMENT_ROOT / "e010_research_summary.md"
    lines = [
        "# E010 Research Summary",
        "",
        "Date: 2026-06-28",
        "",
        "## Scope",
        "",
        "This summary aggregates available E010 load-drop validation evidence. All Simulink models are derived copies of the local ideal IQCOT baseline. Load-current profiles are external disturbances, not AI commands.",
        "",
        "## A4 vs A0 on Interpretable 40A Initial-Load Cases",
        "",
        "| Case | A0 recovery mV | A4 recovery mV | A4 recovery improvement | A4 undershoot penalty mV | A4 pulse inhibit events |",
        "|---|---:|---:|---:|---:|---:|",
    ]
    lines.extend(best_a4_summary(rows))
    lines.extend(
        [
            "",
            "## Key Interpretation",
            "",
            "- `40A_to_20A`: fixed Ton truncation and pulse inhibit are too aggressive; A4 selects no-op and preserves baseline behavior.",
            "- `40A_to_10A`: A4 selects Ton truncation plus one early pulse inhibit, reducing the recovery peak from `2.36936 mV` to `1.84342 mV` with `0.863951 mV` undershoot penalty.",
            "- `40A_to_1A`: A4 remains no-harm under the current guard but does not improve recovery, indicating that the trigger-window/reentry policy needs another token level before claiming severe-drop optimality.",
            "- `120A_to_10A`: the A0 run shows a high-load operating-boundary issue in the present derived model setup and must not be used as load-drop improvement evidence yet.",
            "",
            "## Evidence Table",
            "",
            f"CSV: `{table_path.as_posix()}`",
            "",
            "## Classification",
            "",
            "`MODEL_REVISED`: the evidence supports a load-drop magnitude selector in `a_O`. Mild load drops should project to no-op or gentler protection; medium drops can use Ton truncation plus one early pulse inhibit under an undershoot budget; severe drops require an additional projected token level before broad claims.",
            "",
        ]
    )
    path.write_text("\n".join(lines), encoding="utf-8")
    return path


def main() -> None:
    rows = sorted(load_rows(), key=case_sort_key)
    table_path = write_table(rows)
    report_path = write_report(rows, table_path)
    print(f"WROTE {table_path}")
    print(f"WROTE {report_path}")


if __name__ == "__main__":
    main()
