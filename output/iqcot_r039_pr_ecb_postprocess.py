from __future__ import annotations

import csv
from pathlib import Path
from statistics import mean


ROOT = Path(__file__).resolve().parent
INPUTS = [
    ROOT / "iqcot_r039_pr_ecb_large_signal_results_rows001_001.csv",
    ROOT / "iqcot_r039_pr_ecb_large_signal_results_rows002_005.csv",
]
COMBINED = ROOT / "iqcot_r039_pr_ecb_large_signal_results_combined.csv"
SUMMARY = ROOT / "iqcot_r039_pr_ecb_large_signal_summary.csv"
REPORT = ROOT / "iqcot_r039_pr_ecb_large_signal_report.md"
PAPER_SECTION = ROOT / "iqcot_r039_pr_ecb_large_signal_paper_section.md"


def read_rows() -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    for path in INPUTS:
        if not path.exists():
            raise FileNotFoundError(path)
        with path.open(newline="", encoding="utf-8-sig") as f:
            rows.extend(csv.DictReader(f))
    rows.sort(key=lambda r: (float(r["tau_ai_us"]), float(r["selected_ref_slew_us"])))
    return rows


def write_csv(path: Path, rows: list[dict[str, object]], fieldnames: list[str]) -> None:
    with path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def f(row: dict[str, str], key: str) -> float:
    return float(row[key])


def build_summary(rows: list[dict[str, str]]) -> list[dict[str, object]]:
    ok = [r for r in rows if r["success"] in {"1", "true", "True"}]
    if not ok:
        return []
    energy = [f(r, "delta_v_energy_mV") for r in ok]
    charge = [f(r, "delta_v_charge_esr_mV") for r in ok]
    actual = [f(r, "delta_v_actual_peak_mV") for r in ok]
    risk = [f(r, "r_E") for r in ok]
    first = ok[0]
    invariant = (
        max(actual) - min(actual) < 1e-9
        and max(energy) - min(energy) < 1e-9
        and max(charge) - min(charge) < 1e-9
    )
    return [
        {
            "target_label": "20A",
            "objective": first["objective"],
            "n_cases": len(rows),
            "n_success": len(ok),
            "load_step_A": f"{f(first, 'base_load_A'):.1f}->{f(first, 'target_load_A'):.1f}",
            "delta_v_energy_mV_mean": f"{mean(energy):.6f}",
            "delta_v_charge_esr_mV_mean": f"{mean(charge):.6f}",
            "delta_v_actual_peak_mV_mean": f"{mean(actual):.6f}",
            "r_E_mean": f"{mean(risk):.6f}",
            "energy_over_actual": f"{mean(energy) / mean(actual):.6f}",
            "charge_esr_over_actual": f"{mean(charge) / mean(actual):.6f}",
            "first_peak_invariant_across_delayed_slew": str(invariant).lower(),
            "interpretation": (
                "PR-ECB gives a conservative first-peak risk bound for the shared 40A->20A cut-load event; "
                "the first peak is invariant across these delayed T_slew cases because the supervisory reference action occurs after the peak-forming interval."
            ),
        }
    ]


def markdown_table(rows: list[dict[str, str]]) -> str:
    lines = [
        "| case | role | tau AI us | slew us | energy mV | charge+ESR mV | actual peak mV | r_E |",
        "| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |",
    ]
    for r in rows:
        lines.append(
            "| {case} | {role} | {tau:.3f} | {slew:.3f} | {energy:.3f} | {charge:.3f} | {actual:.3f} | {risk:.3f} |".format(
                case=r["case_id"],
                role=r["role"],
                tau=f(r, "tau_ai_us"),
                slew=f(r, "selected_ref_slew_us"),
                energy=f(r, "delta_v_energy_mV"),
                charge=f(r, "delta_v_charge_esr_mV"),
                actual=f(r, "delta_v_actual_peak_mV"),
                risk=f(r, "r_E"),
            )
        )
    return "\n".join(lines)


def write_report(rows: list[dict[str, str]], summary: list[dict[str, object]]) -> None:
    s = summary[0]
    REPORT.write_text(
        "# R039 PR-ECB Large-Signal Boundary Probe\n\n"
        "## Scope\n\n"
        "R039 starts the large-signal branch after R038. It uses the derived delayed-reference Simulink model to export first-peak wave snapshots and evaluates a phase-resolved energy-charge boundary model.\n\n"
        "## Combined Results\n\n"
        f"{markdown_table(rows)}\n\n"
        "## Main Interpretation\n\n"
        f"- Successful derived-Simulink cases: {s['n_success']}/{s['n_cases']}.\n"
        f"- Energy upper-bound estimate: {s['delta_v_energy_mV_mean']} mV.\n"
        f"- Charge+ESR estimate: {s['delta_v_charge_esr_mV_mean']} mV.\n"
        f"- Actual derived-Simulink first peak: {s['delta_v_actual_peak_mV_mean']} mV.\n"
        f"- With a 10 mV allowance, r_E = {s['r_E_mean']}.\n"
        f"- Energy/actual ratio: {s['energy_over_actual']}; charge+ESR/actual ratio: {s['charge_esr_over_actual']}.\n\n"
        "The identical first-peak values across 46/50/54/30/48 us delayed-reference cases are expected: these cases share the same load-drop instant, phase state, and inductor-current state, while the supervisory T_slew action is delayed by at least 1.25 us. The first voltage peak occurs at about 0.534 us after the load step, before the AI reference trajectory materially changes the plant.\n\n"
        "## Boundary\n\n"
        "This is derived-Simulink plus offline post-processing evidence. It is not hardware validation, HIL validation, or proof of a global T_slew optimum. PR-ECB should be used as a first-peak risk feature r_E and safety-bound generator; PIS-IEK remains the normal/quasi-normal event recovery model.\n",
        encoding="utf-8",
    )
    PAPER_SECTION.write_text(
        "## R039 PR-ECB: large-signal first-peak boundary for delayed supervisory actions\n\n"
        "R039 adds a large-signal branch to the PIS-IEK research line. For the shared 40A->20A load-drop event, the phase-resolved energy-charge boundary model uses the load-step instant values of iL1..iL4, the active high-side phase state, Cout, ESR, and L to estimate a first-peak risk feature r_E. Across five delayed-reference derived-Simulink cases, including the R038 local anchors 46/50/54us and the tau_AI=2us 30/48us foldback near-tie pair, the first-peak state is identical because the peak occurs before the delayed T_slew command can affect the plant.\n\n"
        f"The first R039 sweep gives a conservative boundary: energy estimate {s['delta_v_energy_mV_mean']} mV, charge+ESR estimate {s['delta_v_charge_esr_mV_mean']} mV, and derived-Simulink first peak {s['delta_v_actual_peak_mV_mean']} mV. With Delta V_allow=10 mV, r_E={s['r_E_mean']}. This supports the intended separation: PR-ECB handles load-drop first-peak risk, while PIS-IEK and r_hat/B_epsilon^sw handle post-peak event recovery, skip/reentry, phase spacing, and T_slew deployment. The result must not be written as hardware validation or as evidence that PIS-IEK precisely predicts the first peak.\n",
        encoding="utf-8",
    )


def main() -> None:
    rows = read_rows()
    write_csv(COMBINED, rows, list(rows[0].keys()))
    summary = build_summary(rows)
    write_csv(SUMMARY, summary, list(summary[0].keys()))
    write_report(rows, summary)
    print(f"R039_COMBINED={COMBINED}")
    print(f"R039_SUMMARY={SUMMARY}")
    print(f"R039_REPORT={REPORT}")
    print(f"R039_PAPER_SECTION={PAPER_SECTION}")


if __name__ == "__main__":
    main()
