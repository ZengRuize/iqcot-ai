#!/usr/bin/env python3
"""Audit sampled ideal-digital IQCOT events exported from MATLAB."""

from __future__ import annotations

import csv
import math
from pathlib import Path
import sys


ROOT = Path("E:/Desktop/codex")
DEFAULT_INPUT = ROOT / "output" / "ideal_digital_iqcot_data" / "ideal_iqcot_timeseries.csv"
DEFAULT_RESULTS = ROOT / "output" / "ideal_digital_iqcot_results"


def read_rows(path: Path) -> list[dict[str, float]]:
    rows: list[dict[str, float]] = []
    with path.open(newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            parsed: dict[str, float] = {}
            for key, value in row.items():
                try:
                    parsed[key] = float(value)
                except (TypeError, ValueError):
                    parsed[key] = math.nan
            rows.append(parsed)
    return rows


def rising_edges(rows: list[dict[str, float]], signal: str) -> list[int]:
    edges: list[int] = []
    prev = rows[0].get(signal, 0.0) > 0.5 if rows else False
    for idx in range(1, len(rows)):
        cur = rows[idx].get(signal, 0.0) > 0.5
        if cur and not prev:
            edges.append(idx)
        prev = cur
    return edges


def mean_between(rows: list[dict[str, float]], signal: str, start: int, end: int) -> float:
    values = [rows[i].get(signal, math.nan) for i in range(max(start, 0), max(end, start + 1))]
    values = [v for v in values if math.isfinite(v)]
    return sum(values) / len(values) if values else math.nan


def audit(input_csv: Path, results_dir: Path) -> tuple[Path, Path, dict[str, float]]:
    rows = read_rows(input_csv)
    if len(rows) < 2:
        raise RuntimeError(f"Not enough rows in {input_csv}")

    edges = rising_edges(rows, "tr")
    audit_rows: list[dict[str, float]] = []
    prev_edge = None
    pass_count = 0
    max_overshoot = 0.0

    for event_index, idx in enumerate(edges, start=1):
        t = rows[idx]["time_s"]
        # The exported table is a union of solver/event times and sampled
        # controller times. At an accepted trigger row, A_iqcot is the held
        # sampled value that caused/preceded the event; the previous CSV row
        # may simply be the prior 40 ns sample before threshold crossing.
        sample_idx = idx
        a_before = rows[sample_idx].get("A_iqcot", math.nan)
        lam = rows[sample_idx].get("Lambda_i", math.nan)
        h_mean = mean_between(rows, "h_iqcot", prev_edge or 0, idx)
        period = math.nan if prev_edge is None else t - rows[prev_edge]["time_s"]
        err = a_before - lam
        if math.isfinite(err) and err >= -1e-15:
            pass_count += 1
        if math.isfinite(err):
            max_overshoot = max(max_overshoot, abs(err))
        audit_rows.append(
            {
                "event_index": float(event_index),
                "event_time": t,
                "phase_idx": rows[sample_idx].get("phase_idx", math.nan),
                "A_before_tr": a_before,
                "Lambda_i": lam,
                "A_minus_Lambda": err,
                "h_mean_since_last_event": h_mean,
                "period": period,
            }
        )
        prev_edge = idx

    results_dir.mkdir(parents=True, exist_ok=True)
    out_csv = results_dir / "ideal_iqcot_event_audit.csv"
    out_md = results_dir / "ideal_iqcot_event_audit_report.md"

    fields = [
        "event_index",
        "event_time",
        "phase_idx",
        "A_before_tr",
        "Lambda_i",
        "A_minus_Lambda",
        "h_mean_since_last_event",
        "period",
    ]
    with out_csv.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fields)
        writer.writeheader()
        writer.writerows(audit_rows)

    event_count = len(audit_rows)
    pass_fraction = pass_count / event_count if event_count else math.nan
    periods = [r["period"] for r in audit_rows if math.isfinite(r["period"])]
    period_mean = sum(periods) / len(periods) if periods else math.nan
    period_jitter = (
        math.sqrt(sum((p - period_mean) ** 2 for p in periods) / max(len(periods) - 1, 1))
        if len(periods) > 1
        else math.nan
    )

    with out_md.open("w", encoding="utf-8") as f:
        f.write("# Ideal Digital IQCOT Event Audit\n\n")
        f.write(f"- Input timeseries: `{input_csv.as_posix()}`\n")
        f.write(f"- Events audited: `{event_count}`\n")
        f.write(f"- Fraction with `A_before_tr >= Lambda_i`: `{pass_fraction:.4g}`\n")
        f.write(f"- Mean trigger period: `{period_mean:.6g} s`\n")
        f.write(f"- Trigger-period jitter: `{period_jitter:.6g} s`\n")
        f.write(f"- Max absolute event error: `{max_overshoot:.6g} V*s`\n\n")
        f.write(
            "Digital IQCOT events are sampled events: `A>=Lambda` is only observed on "
            "the `Ts_ctrl` grid, so one-sample quantization and overshoot are expected.\n"
        )

    summary = {
        "event_count": float(event_count),
        "pass_fraction": pass_fraction,
        "period_mean": period_mean,
        "period_jitter": period_jitter,
        "max_abs_error": max_overshoot,
    }
    return out_csv, out_md, summary


def main(argv: list[str]) -> int:
    input_csv = Path(argv[1]) if len(argv) > 1 else DEFAULT_INPUT
    results_dir = Path(argv[2]) if len(argv) > 2 else DEFAULT_RESULTS
    out_csv, out_md, summary = audit(input_csv, results_dir)
    print(f"IDEAL_IQCOT_EVENT_AUDIT_CSV={out_csv}")
    print(f"IDEAL_IQCOT_EVENT_AUDIT_REPORT={out_md}")
    print(f"IDEAL_IQCOT_EVENT_COUNT={summary['event_count']:.0f}")
    print(f"IDEAL_IQCOT_EVENT_PASS_FRACTION={summary['pass_fraction']:.6g}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
