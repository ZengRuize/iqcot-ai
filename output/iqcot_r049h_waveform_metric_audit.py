"""R049H offline waveform-metric audit for PR-ECB Ton-truncation chunks.

This script intentionally does not run Simulink.  It reuses existing wave CSV
exports from R049C/R049D/R049E/R049F/R049G and separates cut-load response into
three post-step windows:

    early_local_peak: 0-2 us
    recovery_peak:   2-12 us
    late_settling:   12-80 us

Outputs are written under output/cutload_pr_ecb_control/.
"""

from __future__ import annotations

import csv
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


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
    run: str
    target: str
    offset_us: float
    controller: str
    action_class: str
    artifact_note: str
    filename: str


CASES = [
    CaseSpec("R049C", "near0", 0.050, "A0", "baseline", "", "r049c_near0_off0p050_a0_r049c_tontrunc_wave.csv"),
    CaseSpec("R049C", "near0", 0.050, "A2", "ov_triggered_ton_trunc", "", "r049c_near0_off0p050_a2_tontrunc_r049c_tontrunc_wave.csv"),
    CaseSpec("R049C", "near0", 0.105, "A0", "baseline", "", "r049c_near0_off0p105_a0_r049c_tontrunc_wave.csv"),
    CaseSpec("R049C", "near0", 0.105, "A2", "ov_triggered_ton_trunc", "", "r049c_near0_off0p105_a2_tontrunc_r049c_tontrunc_wave.csv"),
    CaseSpec("R049D", "10A", 0.050, "A0", "baseline", "", "r049d_10A_off0p050_a0_r049d_tontrunc_holdout_wave.csv"),
    CaseSpec("R049D", "10A", 0.050, "A2", "ov_triggered_ton_trunc", "", "r049d_10A_off0p050_a2_tontrunc_r049d_tontrunc_holdout_wave.csv"),
    CaseSpec("R049D", "10A", 0.105, "A0", "baseline", "", "r049d_10A_off0p105_a0_r049d_tontrunc_holdout_wave.csv"),
    CaseSpec("R049D", "10A", 0.105, "A2", "ov_triggered_ton_trunc", "", "r049d_10A_off0p105_a2_tontrunc_r049d_tontrunc_holdout_wave.csv"),
    CaseSpec("R049E", "20A", 0.050, "A0", "baseline", "", "r049e_20A_off0p050_a0_r049e_tontrunc_holdout_wave.csv"),
    CaseSpec("R049E", "20A", 0.050, "A2", "late_ov_triggered_ton_trunc", "", "r049e_20A_off0p050_a2_tontrunc_r049e_tontrunc_holdout_wave.csv"),
    CaseSpec("R049E", "20A", 0.105, "A0", "baseline", "", "r049e_20A_off0p105_a0_r049e_tontrunc_holdout_wave.csv"),
    CaseSpec("R049E", "20A", 0.105, "A2", "late_ov_triggered_ton_trunc", "", "r049e_20A_off0p105_a2_tontrunc_r049e_tontrunc_holdout_wave.csv"),
    CaseSpec("R049F", "20A", 0.050, "A0", "baseline", "timing_artifact_reference", "r049f_20A_off0p050_a0_r049f_early_tontrunc_wave.csv"),
    CaseSpec("R049F", "20A", 0.050, "A2", "global_early_ton_trunc", "timing_artifact_early_window_started_at_t0", "r049f_20A_off0p050_a2_early_r049f_early_tontrunc_wave.csv"),
    CaseSpec("R049F", "20A", 0.105, "A0", "baseline", "timing_artifact_reference", "r049f_20A_off0p105_a0_r049f_early_tontrunc_wave.csv"),
    CaseSpec("R049F", "20A", 0.105, "A2", "global_early_ton_trunc", "timing_artifact_early_window_started_at_t0", "r049f_20A_off0p105_a2_early_r049f_early_tontrunc_wave.csv"),
    CaseSpec("R049G", "20A", 0.050, "A0", "baseline", "", "r049g_20A_off0p050_a0_r049g_phase_selective_tontrunc_wave.csv"),
    CaseSpec("R049G", "20A", 0.050, "A2", "repaired_phase_selective_ton_trunc", "", "r049g_20A_off0p050_a2_phase_select_r049g_phase_selective_tontrunc_wave.csv"),
    CaseSpec("R049G", "20A", 0.105, "A0", "baseline", "", "r049g_20A_off0p105_a0_r049g_phase_selective_tontrunc_wave.csv"),
    CaseSpec("R049G", "20A", 0.105, "A2", "repaired_phase_selective_ton_trunc", "", "r049g_20A_off0p105_a2_phase_select_r049g_phase_selective_tontrunc_wave.csv"),
]


def empty_metric() -> dict[str, float | int | str]:
    return {
        "count": 0,
        "max_mV": float("-inf"),
        "max_time_us": float("nan"),
        "min_mV": float("inf"),
        "min_time_us": float("nan"),
        "pp_mV": float("nan"),
    }


def update_metric(metric: dict[str, float | int | str], t_us: float, dv_mV: float) -> None:
    metric["count"] = int(metric["count"]) + 1
    if dv_mV > float(metric["max_mV"]):
        metric["max_mV"] = dv_mV
        metric["max_time_us"] = t_us
    if dv_mV < float(metric["min_mV"]):
        metric["min_mV"] = dv_mV
        metric["min_time_us"] = t_us


def finalize_metric(metric: dict[str, float | int | str]) -> None:
    if int(metric["count"]) == 0:
        metric["max_mV"] = float("nan")
        metric["min_mV"] = float("nan")
        metric["pp_mV"] = float("nan")
        return
    metric["pp_mV"] = float(metric["max_mV"]) - float(metric["min_mV"])


def window_for_time(t_us: float) -> Iterable[tuple[str, float, float]]:
    for idx, window in enumerate(WINDOWS):
        _, lo, hi = window
        if idx == 0:
            if lo <= t_us <= hi:
                yield window
        elif lo < t_us <= hi:
            yield window


def audit_case(spec: CaseSpec) -> list[dict[str, object]]:
    path = DATA / spec.filename
    if not path.exists():
        raise FileNotFoundError(path)

    metrics = {name: empty_metric() for name, _, _ in WINDOWS}
    initial_vout_mV = None
    final_error_mV = None
    qh_at_step = {f"qh{i}": float("nan") for i in range(1, 5)}
    trunc_duration_us = 0.0
    prev_time = None
    prev_trunc = 0.0

    with path.open("r", newline="") as handle:
        reader = csv.DictReader(handle)
        for row in reader:
            t_us = float(row["time_from_load_step_us"])
            vout = float(row["vout_V"])
            dv_mV = (vout - 1.0) * 1000.0
            if initial_vout_mV is None:
                initial_vout_mV = dv_mV
                for key in qh_at_step:
                    if key in row:
                        qh_at_step[key] = float(row[key])
            final_error_mV = dv_mV

            if prev_time is not None and prev_trunc > 0.5:
                trunc_duration_us += max(0.0, t_us - prev_time)
            prev_time = t_us
            prev_trunc = float(row.get("ton_trunc_global", "0") or 0.0)

            for name, _, _ in window_for_time(t_us):
                update_metric(metrics[name], t_us, dv_mV)

    rows: list[dict[str, object]] = []
    for name, lo, hi in WINDOWS:
        metric = metrics[name]
        finalize_metric(metric)
        rows.append(
            {
                "run": spec.run,
                "target": spec.target,
                "offset_us": f"{spec.offset_us:.3f}",
                "controller": spec.controller,
                "action_class": spec.action_class,
                "artifact_note": spec.artifact_note,
                "window": name,
                "window_start_us": f"{lo:.3f}",
                "window_end_us": f"{hi:.3f}",
                "samples": metric["count"],
                "max_mV": f"{float(metric['max_mV']):.6f}",
                "max_time_us": f"{float(metric['max_time_us']):.6f}",
                "min_mV": f"{float(metric['min_mV']):.6f}",
                "min_time_us": f"{float(metric['min_time_us']):.6f}",
                "pp_mV": f"{float(metric['pp_mV']):.6f}",
                "initial_vout_error_mV": f"{float(initial_vout_mV or 0.0):.6f}",
                "final_error_mV": f"{float(final_error_mV or 0.0):.6f}",
                "qh1_at_step": f"{qh_at_step['qh1']:.0f}",
                "qh2_at_step": f"{qh_at_step['qh2']:.0f}",
                "qh3_at_step": f"{qh_at_step['qh3']:.0f}",
                "qh4_at_step": f"{qh_at_step['qh4']:.0f}",
                "global_trunc_duration_us": f"{trunc_duration_us:.6f}",
                "wave_csv": str(path.relative_to(ROOT)),
            }
        )
    return rows


def write_csv(path: Path, rows: list[dict[str, object]]) -> None:
    if not rows:
        raise ValueError(f"No rows for {path}")
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)


def pair_rows(case_rows: list[dict[str, object]]) -> list[dict[str, object]]:
    by_key: dict[tuple[str, str, str, str], dict[str, dict[str, object]]] = {}
    for row in case_rows:
        key = (str(row["run"]), str(row["target"]), str(row["offset_us"]), str(row["window"]))
        by_key.setdefault(key, {})[str(row["controller"])] = row

    deltas: list[dict[str, object]] = []
    for (run, target, offset_us, window), controllers in sorted(by_key.items()):
        if "A0" not in controllers or "A2" not in controllers:
            continue
        a0 = controllers["A0"]
        a2 = controllers["A2"]
        a0_max = float(a0["max_mV"])
        a2_max = float(a2["max_mV"])
        a0_min = float(a0["min_mV"])
        a2_min = float(a2["min_mV"])
        delta_max = a2_max - a0_max
        delta_min = a2_min - a0_min
        deltas.append(
            {
                "run": run,
                "target": target,
                "offset_us": offset_us,
                "window": window,
                "a0_max_mV": f"{a0_max:.6f}",
                "a2_max_mV": f"{a2_max:.6f}",
                "a2_minus_a0_max_mV": f"{delta_max:.6f}",
                "peak_improvement_mV": f"{-delta_max:.6f}",
                "a0_max_time_us": a0["max_time_us"],
                "a2_max_time_us": a2["max_time_us"],
                "a0_min_mV": f"{a0_min:.6f}",
                "a2_min_mV": f"{a2_min:.6f}",
                "a2_minus_a0_min_mV": f"{delta_min:.6f}",
                "undershoot_improvement_mV": f"{delta_min:.6f}",
                "a0_initial_vout_error_mV": a0["initial_vout_error_mV"],
                "a2_initial_vout_error_mV": a2["initial_vout_error_mV"],
                "a2_action_class": a2["action_class"],
                "artifact_note": a2["artifact_note"],
                "a2_global_trunc_duration_us": a2["global_trunc_duration_us"],
            }
        )
    return deltas


def rows_for(pair_deltas: list[dict[str, object]], run: str, target: str, offset: str) -> list[dict[str, object]]:
    return [
        row
        for row in pair_deltas
        if row["run"] == run and row["target"] == target and row["offset_us"] == offset
    ]


def fmt(value: object, digits: int = 4) -> str:
    try:
        return f"{float(value):.{digits}f}"
    except Exception:
        return str(value)


def write_report(case_rows: list[dict[str, object]], pair_deltas: list[dict[str, object]], path: Path) -> None:
    c050 = rows_for(pair_deltas, "R049C", "near0", "0.050")
    d050 = rows_for(pair_deltas, "R049D", "10A", "0.050")
    e050 = rows_for(pair_deltas, "R049E", "20A", "0.050")
    g050 = rows_for(pair_deltas, "R049G", "20A", "0.050")

    def rowmap(rows: list[dict[str, object]]) -> dict[str, dict[str, object]]:
        return {str(row["window"]): row for row in rows}

    summary_sets = [
        ("R049C near0 active-HS", rowmap(c050)),
        ("R049D 10A active-HS", rowmap(d050)),
        ("R049E 20A OV-triggered mild", rowmap(e050)),
        ("R049G 20A repaired phase-selective", rowmap(g050)),
    ]

    lines: list[str] = []
    lines.append("# R049H PR-ECB Waveform Metric Audit\n")
    lines.append("Date: 2026-06-24\n")
    lines.append("## Scope\n")
    lines.append(
        "R049H is an offline audit only.  It reuses existing wave CSV exports "
        "from R049C/R049D/R049E/R049F/R049G and does not run any new Simulink "
        "switching simulation.\n"
    )
    lines.append("The response is split into three windows after the load step:\n")
    lines.append("- `0-2 us`: early local peak / immediate switching interaction.\n")
    lines.append("- `2-12 us`: recovery peak.\n")
    lines.append("- `12-80 us`: late settling and undershoot.\n")
    lines.append("\n## Output files\n")
    lines.append("- `output/cutload_pr_ecb_control/r049h_waveform_metric_case_windows.csv`\n")
    lines.append("- `output/cutload_pr_ecb_control/r049h_waveform_metric_pair_delta.csv`\n")
    lines.append("- `output/cutload_pr_ecb_control/r049h_waveform_metric_summary.md`\n")

    lines.append("\n## Active-HS windowed comparison\n")
    lines.append(
        "| Chunk | Early peak improvement | Recovery peak improvement | Late peak improvement | Early undershoot change | Late undershoot change |\n"
    )
    lines.append("|---|---:|---:|---:|---:|---:|\n")
    for label, mapped in summary_sets:
        early = mapped["early_local_peak"]
        recovery = mapped["recovery_peak"]
        late = mapped["late_settling"]
        lines.append(
            f"| {label} | {fmt(early['peak_improvement_mV'])} mV | "
            f"{fmt(recovery['peak_improvement_mV'])} mV | "
            f"{fmt(late['peak_improvement_mV'])} mV | "
            f"{fmt(early['undershoot_improvement_mV'])} mV | "
            f"{fmt(late['undershoot_improvement_mV'])} mV |\n"
        )

    lines.append("\n## Key observations\n")
    lines.append(
        "1. R049C supports a broad larger-drop Ton-truncation benefit in the "
        "active-HS row: A2 improves both early local and recovery peak windows. "
        "R049D supports a narrower `10A` hold-out benefit: the main improvement "
        "is in the `0-2 us` early local peak, while the recovery/late positive "
        "peak windows are essentially unchanged or slightly worse.\n"
    )
    lines.append(
        "2. R049E confirms the mild-load trigger-lateness issue: the over-voltage "
        "triggered action is too late to change the `40A -> 20A` active-HS "
        "early or recovery peak windows.\n"
    )
    lines.append(
        "3. R049G is the decisive repaired mild-load diagnostic: phase-selective "
        "hard Ton-min truncation removes remaining Ton, but worsens the early "
        "local peak and slightly worsens the recovery/late peak windows.\n"
    )
    lines.append(
        "4. R049F remains useful only as a timing-artifact reference.  Its A2 "
        "rows begin far below regulation because the inherited early-window "
        "lower bound was unconnected before R049G repaired it.\n"
    )

    lines.append("\n## R049F timing-artifact check\n")
    lines.append("| Offset | A0 initial error | A2 initial error | Interpretation |\n")
    lines.append("|---:|---:|---:|---|\n")
    for offset in ["0.050", "0.105"]:
        frows = rows_for(pair_deltas, "R049F", "20A", offset)
        early = rowmap(frows)["early_local_peak"]
        lines.append(
            f"| `{offset} us` | {fmt(early['a0_initial_vout_error_mV'])} mV | "
            f"{fmt(early['a2_initial_vout_error_mV'])} mV | timing artifact, "
            "not controller evidence |\n"
        )

    lines.append("\n## Decision\n\n```text\nMODEL_REVISED\n```\n")
    lines.append("\n## Revised action model\n")
    lines.append(
        "R049H keeps command-path Ton truncation as a valid larger-drop "
        "active-HS action only with segmented wording: R049C shows broad "
        "near0 benefit, while R049D confirms mainly early-local-peak benefit "
        "for the `10A` hold-out.  R049H rejects hard phase-selective Ton-min "
        "truncation as a confirmed mild-load action.  The PR-ECB metric must "
        "remain segmented by early local peak, recovery peak, and late "
        "settling/undershoot windows.\n"
    )
    lines.append("\n## Next validation\n")
    lines.append(
        "R049I should run one minimal repaired-model action chunk, not a full "
        "matrix: use the same `40A -> 20A` two-offset setup but test a gentler "
        "phase-selective Ton trim rather than hard `5 ns` Ton-min.  A practical "
        "first candidate is to cap only the active phase to a moderate floor "
        "(for example `80-120 ns`, to be documented from baseline Ton traces) "
        "and evaluate the same three windows.  If the early local peak remains "
        "worse, stop and move to deferred post-active pulse inhibit or "
        "controlled reentry instead of more Ton-min variants.\n"
    )
    lines.append("\n## Claim boundary\n")
    lines.append(
        "R049H is offline derived-Simulink waveform evidence only.  It is not "
        "hardware/HIL validation, not global calibration, not proof of a "
        "complete PR-ECB controller, and not a universal additive `E_HS,rem` "
        "law.\n"
    )
    path.write_text("".join(lines), encoding="utf-8")


def main() -> None:
    case_rows: list[dict[str, object]] = []
    for spec in CASES:
        case_rows.extend(audit_case(spec))

    pair_deltas = pair_rows(case_rows)

    case_path = OUT / "r049h_waveform_metric_case_windows.csv"
    pair_path = OUT / "r049h_waveform_metric_pair_delta.csv"
    report_path = OUT / "r049h_waveform_metric_summary.md"

    write_csv(case_path, case_rows)
    write_csv(pair_path, pair_deltas)
    write_report(case_rows, pair_deltas, report_path)

    print(f"R049H_CASE_WINDOWS={case_path}")
    print(f"R049H_PAIR_DELTA={pair_path}")
    print(f"R049H_REPORT={report_path}")
    print("R049H_DECISION=MODEL_REVISED")


if __name__ == "__main__":
    main()
