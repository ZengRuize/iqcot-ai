"""Postprocess/audit helper for E040-A active-phase add metrics.

This script is intentionally conservative: it does not synthesize missing
metrics. It checks that the required CSV columns exist and prints the current
per-variant classification hints for the minimal D0-D3 add-phase chunk.
"""

from __future__ import annotations

import csv
from pathlib import Path


REQUIRED_COLUMNS = [
    "variant",
    "success",
    "peak_overshoot_mV",
    "peak_undershoot_mV",
    "settling_time_us",
    "final_Vout_error_mV",
    "Vout_ripple_pp_mV",
    "active_phase_transition_time_us",
    "N_active_initial",
    "N_active_final",
    "phase_add_accept_count",
    "phase_shed_accept_count",
    "phase_add_reject_count",
    "phase_shed_reject_count",
    "new_phase_current_ramp_time_us",
    "new_phase_current_overshoot_A",
    "residual_current_at_shed_A",
    "residual_current_threshold_A",
    "real_max_current_imbalance_A",
    "real_rms_current_imbalance_A",
    "sensed_max_current_imbalance_A",
    "sensed_rms_current_imbalance_A",
    "phase_spacing_std_ns",
    "phase_order_error_rate",
    "REQ_count",
    "dropped_REQ_count",
    "current_limit_hit",
    "Ton_trim_usage",
    "Lambda_trim_usage",
    "fallback_count",
    "guard_clamp_count",
    "classification_hint",
]


def main() -> int:
    repo = Path(__file__).resolve().parents[3]
    csv_path = repo / "experiments" / "E040_active_phase_add_shed" / "e040_metrics.csv"
    if not csv_path.is_file():
        print(f"E040 metrics CSV not found: {csv_path}")
        return 2

    with csv_path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        missing = [col for col in REQUIRED_COLUMNS if col not in (reader.fieldnames or [])]
        if missing:
            print("Missing required E040 columns:")
            for col in missing:
                print(f"- {col}")
            return 1
        rows = list(reader)

    if not rows:
        print("E040 metrics CSV has headers only; E040-A has not produced evidence yet.")
        return 0

    print("E040-A classification hints:")
    for row in rows:
        print(
            f"- {row['variant']}: success={row['success']}, "
            f"N_final={row['N_active_final']}, "
            f"dropped_REQ={row['dropped_REQ_count']}, "
            f"hint={row['classification_hint']}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
