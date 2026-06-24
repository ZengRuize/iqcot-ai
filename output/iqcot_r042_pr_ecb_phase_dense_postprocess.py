from __future__ import annotations

import csv
import math
from collections import defaultdict
from pathlib import Path
from statistics import mean, pstdev


ROOT = Path(__file__).resolve().parent
INPUTS = sorted(ROOT.glob("iqcot_r042_pr_ecb_phase_dense_results_rows*.csv"))
RESULTS = ROOT / "iqcot_r042_pr_ecb_phase_dense_results_combined.csv"
SUMMARY = ROOT / "iqcot_r042_pr_ecb_phase_dense_summary.csv"
REPORT = ROOT / "iqcot_r042_pr_ecb_phase_dense_report.md"
PAPER_SECTION = ROOT / "iqcot_r042_pr_ecb_phase_dense_paper_section.md"

VIN_V = 12.0


def read_rows() -> list[dict[str, str]]:
    if not INPUTS:
        raise FileNotFoundError("No R042 chunk result files found")
    rows: list[dict[str, str]] = []
    for path in INPUTS:
        with path.open(newline="", encoding="utf-8-sig") as f:
            rows.extend(r for r in csv.DictReader(f) if r.get("success") in {"1", "true", "True"})
    rows.sort(key=lambda r: (r["target_label"], float(r["load_step_offset_us"])))
    if not rows:
        raise RuntimeError("No successful R042 rows available")
    return rows


def f(row: dict[str, str], key: str) -> float:
    return float(row[key])


def ratio(num: float, den: float) -> float:
    return num / den if abs(den) > 1e-12 else float("nan")


def infer_l_h(row: dict[str, str]) -> float:
    energy_j = f(row, "energy_surplus_uJ") * 1e-6
    i_new = f(row, "target_load_A") / 4.0
    surplus_i2 = sum(max(f(row, f"il{p}_0_A") ** 2 - i_new**2, 0.0) for p in range(1, 5))
    return 2.0 * energy_j / surplus_i2


def infer_cout_f(row: dict[str, str]) -> float:
    energy_j = f(row, "energy_surplus_uJ") * 1e-6
    v0 = f(row, "vout0_V")
    dv = f(row, "delta_v_energy_mV") * 1e-3
    return 2.0 * energy_j / ((v0 + dv) ** 2 - v0**2)


def voltage_from_energy(v0: float, energy_j: float, cout_f: float) -> float:
    return 1e3 * (math.sqrt(max(v0 * v0 + 2.0 * energy_j / cout_f, 0.0)) - v0)


def fmt(value: float, digits: int = 6) -> str:
    return f"{value:.{digits}f}"


def build_results(rows: list[dict[str, str]]) -> tuple[list[dict[str, object]], dict[str, float]]:
    l_values = [infer_l_h(r) for r in rows]
    c_values = [infer_cout_f(r) for r in rows]
    l_h = mean(l_values)
    cout_f = mean(c_values)

    out: list[dict[str, object]] = []
    for r in rows:
        v0 = f(r, "vout0_V")
        energy_j = f(r, "energy_surplus_uJ") * 1e-6
        i_new = f(r, "target_load_A") / 4.0
        actual = f(r, "delta_v_actual_peak_mV")
        allowance = f(r, "delta_v_allow_mV")
        energy_mV = f(r, "delta_v_energy_mV")
        charge_esr_mV = f(r, "delta_v_charge_esr_mV")
        hsrem_extra_j = 0.0
        active_phases: list[str] = []
        total_remaining_ns = 0.0

        for phase in range(1, 5):
            qh = f(r, f"qh{phase}_at_step")
            remaining_s = f(r, f"remaining_ton{phase}_ns") * 1e-9
            if qh <= 0.5 or remaining_s <= 0.0:
                continue
            i0 = f(r, f"il{phase}_0_A")
            di = (VIN_V - v0) / l_h * remaining_s
            before = max(i0 * i0 - i_new * i_new, 0.0)
            after = max((i0 + di) ** 2 - i_new * i_new, 0.0)
            hsrem_extra_j += 0.5 * l_h * max(after - before, 0.0)
            active_phases.append(str(phase))
            total_remaining_ns += remaining_s * 1e9

        energy_corr_mV = voltage_from_energy(v0, energy_j + hsrem_extra_j, cout_f)
        max_r042_mV = max(energy_mV, charge_esr_mV)
        max_corr_mV = max(energy_corr_mV, charge_esr_mV)

        item: dict[str, object] = {
            "case_id": r["case_id"],
            "target_label": r["target_label"],
            "load_step_offset_us": fmt(f(r, "load_step_offset_us")),
            "target_load_A": fmt(f(r, "target_load_A")),
            "load_drop_A": fmt(f(r, "load_drop_A")),
            "active_hsrem_phases": ",".join(active_phases),
            "remaining_ton_total_ns": fmt(total_remaining_ns),
            "E_HS_rem_uJ": fmt(hsrem_extra_j * 1e6),
            "delta_v_energy_mV": fmt(energy_mV),
            "delta_v_charge_esr_mV": fmt(charge_esr_mV),
            "delta_v_energy_corr_mV": fmt(energy_corr_mV),
            "delta_v_max_r042_mV": fmt(max_r042_mV),
            "delta_v_max_corr_mV": fmt(max_corr_mV),
            "delta_v_actual_peak_mV": fmt(actual),
            "r_E_energy": fmt(energy_mV / allowance),
            "r_E_charge_esr": fmt(charge_esr_mV / allowance),
            "r_E_max_raw": fmt(max_r042_mV / allowance),
            "r_E_energy_corr": fmt(energy_corr_mV / allowance),
            "r_E_max_corr": fmt(max_corr_mV / allowance),
            "energy_over_actual": fmt(ratio(energy_mV, actual)),
            "charge_esr_over_actual": fmt(ratio(charge_esr_mV, actual)),
            "max_r042_over_actual": fmt(ratio(max_r042_mV, actual)),
            "energy_corr_over_actual": fmt(ratio(energy_corr_mV, actual)),
            "max_corr_over_actual": fmt(ratio(max_corr_mV, actual)),
            "energy_under_actual": int(energy_mV < actual),
            "energy_corr_under_actual": int(energy_corr_mV < actual),
        }
        out.append(item)

    physics = {
        "L_H_mean": l_h,
        "L_H_min": min(l_values),
        "L_H_max": max(l_values),
        "Cout_F_mean": cout_f,
        "Cout_F_min": min(c_values),
        "Cout_F_max": max(c_values),
    }
    return out, physics


def write_csv(path: Path, rows: list[dict[str, object]]) -> None:
    with path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)


def summarize_group(label: str, rows: list[dict[str, object]]) -> dict[str, object]:
    def vals(key: str) -> list[float]:
        return [float(r[key]) for r in rows]

    max_corr = vals("max_corr_over_actual")
    max_raw = vals("max_r042_over_actual")
    energy_corr = vals("energy_corr_over_actual")
    return {
        "target_label": label,
        "n": len(rows),
        "active_hsrem_rows": sum(1 for r in rows if str(r["active_hsrem_phases"])),
        "energy_under_actual_count": sum(int(r["energy_under_actual"]) for r in rows),
        "energy_corr_under_actual_count": sum(int(r["energy_corr_under_actual"]) for r in rows),
        "r_E_max_corr_min": fmt(min(vals("r_E_max_corr"))),
        "r_E_max_corr_max": fmt(max(vals("r_E_max_corr"))),
        "max_r042_over_actual_mean": fmt(mean(max_raw)),
        "max_corr_over_actual_mean": fmt(mean(max_corr)),
        "max_corr_over_actual_std": fmt(pstdev(max_corr) if len(max_corr) > 1 else 0.0),
        "energy_corr_over_actual_mean": fmt(mean(energy_corr)),
        "energy_corr_over_actual_std": fmt(pstdev(energy_corr) if len(energy_corr) > 1 else 0.0),
    }


def build_summary(rows: list[dict[str, object]]) -> list[dict[str, object]]:
    groups: dict[str, list[dict[str, object]]] = defaultdict(list)
    for r in rows:
        groups[str(r["target_label"])].append(r)
    summary = [summarize_group(label, groups[label]) for label in sorted(groups)]
    summary.append(summarize_group("ALL", rows))
    return summary


def markdown_table(rows: list[dict[str, object]]) -> str:
    lines = [
        "| case | target | offset us | active HS rem | E_HS,rem uJ | energy mV | energy+corr mV | charge+ESR mV | max corr mV | actual mV | max corr/actual |",
        "| --- | --- | ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |",
    ]
    for r in rows:
        active = str(r["active_hsrem_phases"]) or "-"
        lines.append(
            f"| {r['case_id']} | {r['target_label']} | {float(r['load_step_offset_us']):.3f} | "
            f"{active} | {float(r['E_HS_rem_uJ']):.3f} | {float(r['delta_v_energy_mV']):.3f} | "
            f"{float(r['delta_v_energy_corr_mV']):.3f} | {float(r['delta_v_charge_esr_mV']):.3f} | "
            f"{float(r['delta_v_max_corr_mV']):.3f} | {float(r['delta_v_actual_peak_mV']):.3f} | "
            f"{float(r['max_corr_over_actual']):.3f} |"
        )
    return "\n".join(lines)


def write_reports(rows: list[dict[str, object]], summary: list[dict[str, object]], physics: dict[str, float]) -> None:
    all_row = next(r for r in summary if r["target_label"] == "ALL")
    active_rows = [r for r in rows if str(r["active_hsrem_phases"])]
    REPORT.write_text(
        "# R042 PR-ECB Remaining High-Side On-Time Correction\n\n"
        "## Scope\n\n"
        "R042 post-processes the currently completed phase-dense derived-Simulink rows around the high-side remaining-on-time boundary. It does not modify or save any .slx model. It estimates E_HS,rem for rows where a phase is still high-side-on at the load-step instant, then compares energy-only, charge+ESR, raw max-bound, corrected-energy, and corrected max-bound variants.\n\n"
        "## Inferred Physical Parameters\n\n"
        f"- L inferred from R042 energy rows: mean {physics['L_H_mean']:.3e} H, range {physics['L_H_min']:.3e} to {physics['L_H_max']:.3e} H.\n"
        f"- Cout inferred from R042 energy rows: mean {physics['Cout_F_mean']:.6e} F, range {physics['Cout_F_min']:.6e} to {physics['Cout_F_max']:.6e} F.\n"
        f"- Vin assumption for residual high-side slope: {VIN_V:.1f} V.\n\n"
        "## Results\n\n"
        f"{markdown_table(rows)}\n\n"
        "## Summary\n\n"
        + "\n".join(
            "- {target}: n={n}, active-HS rows={active}, energy under-actual {eu}->{ecu} after correction, r_E(max corrected) {rmin} to {rmax}, max-corr/actual mean {mean_ratio}".format(
                target=s["target_label"],
                n=s["n"],
                active=s["active_hsrem_rows"],
                eu=s["energy_under_actual_count"],
                ecu=s["energy_corr_under_actual_count"],
                rmin=s["r_E_max_corr_min"],
                rmax=s["r_E_max_corr_max"],
                mean_ratio=s["max_corr_over_actual_mean"],
            )
            for s in summary
        )
        + "\n\n"
        "## Interpretation\n\n"
        f"Nonzero E_HS,rem appears in {len(active_rows)} of {len(rows)} completed rows. In the completed R042 matrix, phase-4 remaining on-time follows the same boundary for near0/5A/10A/20A: 52 ns at 0.05 us, 12 ns at 0.09 us, and 0 ns from 0.105 us onward. charge+ESR remains the dominant max-bound for near0 and 5A, while corrected-energy/raw energy dominates most 10A and 20A rows. This supports a segmented PR-ECB calibration feature, not a global additive correction law.\n\n"
        "Boundary: this is offline post-processing of derived-Simulink R042 rows. It is not hardware/HIL validation, does not prove global PR-ECB calibration, and does not replace PIS-IEK/r_hat/B_epsilon post-peak recovery logic.\n",
        encoding="utf-8",
    )

    PAPER_SECTION.write_text(
        "## R042 remaining high-side on-time correction\n\n"
        "R042 extends R041 by adding phase-dense derived-Simulink rows around the high-side turn-off boundary. L and Cout are re-inferred from each completed result row, and E_HS,rem is applied only when the load step occurs while a phase remains high-side-on.\n\n"
        "The useful comparison is not a single corrected max-bound number, but the transition from pre-turnoff rows with nonzero remaining on-time to post-turnoff rows where E_HS,rem vanishes. The safest wording is that E_HS,rem is a phase-state feature for segmented PR-ECB calibration, not a globally validated additive law.\n\n"
        "R042 remains derived-Simulink/offline evidence only. It supports a supervisory first-peak risk feature, while PIS-IEK, r_hat, and B_epsilon continue to govern post-peak recovery and T_slew deployment.\n",
        encoding="utf-8",
    )


def main() -> None:
    rows = read_rows()
    results, physics = build_results(rows)
    write_csv(RESULTS, results)
    summary = build_summary(results)
    write_csv(SUMMARY, summary)
    write_reports(results, summary, physics)
    print(f"R042_RESULTS={RESULTS}")
    print(f"R042_SUMMARY={SUMMARY}")
    print(f"R042_REPORT={REPORT}")
    print(f"R042_PAPER_SECTION={PAPER_SECTION}")


if __name__ == "__main__":
    main()

