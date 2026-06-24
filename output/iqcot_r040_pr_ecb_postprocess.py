from __future__ import annotations

import csv
from collections import defaultdict
from pathlib import Path
from statistics import mean, pstdev


ROOT = Path(__file__).resolve().parent
INPUTS = sorted(ROOT.glob("iqcot_r040_pr_ecb_phase_load_results_rows*.csv"))
COMBINED = ROOT / "iqcot_r040_pr_ecb_phase_load_results_combined.csv"
SUMMARY = ROOT / "iqcot_r040_pr_ecb_phase_load_summary.csv"
REPORT = ROOT / "iqcot_r040_pr_ecb_phase_load_report.md"
PAPER_SECTION = ROOT / "iqcot_r040_pr_ecb_phase_load_paper_section.md"


def read_rows() -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    if not INPUTS:
        raise FileNotFoundError("No R040 chunk results found")
    for path in INPUTS:
        if not path.exists():
            raise FileNotFoundError(path)
        with path.open(newline="", encoding="utf-8-sig") as f:
            rows.extend(csv.DictReader(f))
    rows.sort(key=lambda r: (r["target_label"], float(r["load_step_offset_us"])))
    return rows


def write_csv(path: Path, rows: list[dict[str, object]], fieldnames: list[str]) -> None:
    with path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def f(row: dict[str, str], key: str) -> float:
    return float(row[key])


def success(row: dict[str, str]) -> bool:
    return row["success"] in {"1", "true", "True"}


def ratio(num: float, den: float) -> float:
    return num / den if abs(den) > 1e-12 else float("nan")


def build_augmented(rows: list[dict[str, str]]) -> list[dict[str, object]]:
    out: list[dict[str, object]] = []
    for r in rows:
        item: dict[str, object] = dict(r)
        if success(r):
            actual = f(r, "delta_v_actual_peak_mV")
            energy = f(r, "delta_v_energy_mV")
            charge = f(r, "delta_v_charge_esr_mV")
            item["energy_over_actual"] = f"{ratio(energy, actual):.6f}"
            item["charge_esr_over_actual"] = f"{ratio(charge, actual):.6f}"
            item["dominant_bound"] = "energy" if energy >= charge else "charge_esr"
        else:
            item["energy_over_actual"] = ""
            item["charge_esr_over_actual"] = ""
            item["dominant_bound"] = ""
        out.append(item)
    return out


def build_summary(rows: list[dict[str, str]]) -> list[dict[str, object]]:
    groups: dict[str, list[dict[str, str]]] = defaultdict(list)
    for r in rows:
        if success(r):
            groups[r["target_label"]].append(r)
    summary: list[dict[str, object]] = []
    for label, g in sorted(groups.items()):
        energy = [f(r, "delta_v_energy_mV") for r in g]
        charge = [f(r, "delta_v_charge_esr_mV") for r in g]
        actual = [f(r, "delta_v_actual_peak_mV") for r in g]
        risk = [f(r, "r_E") for r in g]
        e_ratio = [ratio(e, a) for e, a in zip(energy, actual)]
        q_ratio = [ratio(q, a) for q, a in zip(charge, actual)]
        offsets = [f(r, "load_step_offset_us") for r in g]
        summary.append(
            {
                "target_label": label,
                "n_success": len(g),
                "offset_min_us": f"{min(offsets):.6f}",
                "offset_max_us": f"{max(offsets):.6f}",
                "energy_mV_min": f"{min(energy):.6f}",
                "energy_mV_max": f"{max(energy):.6f}",
                "charge_esr_mV_min": f"{min(charge):.6f}",
                "charge_esr_mV_max": f"{max(charge):.6f}",
                "actual_peak_mV_min": f"{min(actual):.6f}",
                "actual_peak_mV_max": f"{max(actual):.6f}",
                "r_E_min": f"{min(risk):.6f}",
                "r_E_max": f"{max(risk):.6f}",
                "energy_over_actual_mean": f"{mean(e_ratio):.6f}",
                "charge_esr_over_actual_mean": f"{mean(q_ratio):.6f}",
                "energy_over_actual_std": f"{pstdev(e_ratio):.6f}" if len(e_ratio) > 1 else "0.000000",
                "charge_esr_over_actual_std": f"{pstdev(q_ratio):.6f}" if len(q_ratio) > 1 else "0.000000",
            }
        )
    return summary


def markdown_table(rows: list[dict[str, object]]) -> str:
    lines = [
        "| case | target | offset us | energy mV | charge+ESR mV | actual peak mV | r_E | energy/actual | charge+ESR/actual | dominant |",
        "| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |",
    ]
    for r in rows:
        lines.append(
            "| {case} | {target} | {offset:.3f} | {energy:.3f} | {charge:.3f} | {actual:.3f} | {risk:.3f} | {er} | {qr} | {dom} |".format(
                case=r["case_id"],
                target=r["target_label"],
                offset=float(r["load_step_offset_us"]),
                energy=float(r["delta_v_energy_mV"]),
                charge=float(r["delta_v_charge_esr_mV"]),
                actual=float(r["delta_v_actual_peak_mV"]),
                risk=float(r["r_E"]),
                er=r["energy_over_actual"],
                qr=r["charge_esr_over_actual"],
                dom=r["dominant_bound"],
            )
        )
    return "\n".join(lines)


def write_reports(augmented: list[dict[str, object]], summary: list[dict[str, object]]) -> None:
    r20 = next((s for s in summary if s["target_label"] == "20A"), None)
    r10 = next((s for s in summary if s["target_label"] == "10A"), None)
    REPORT.write_text(
        "# R040 PR-ECB Phase/Load Calibration\n\n"
        "## Scope\n\n"
        "R040 extends R039 by changing the load-step phase offset and adding larger 40A->10A and 40A->near0 cut-load points. It still uses only the derived delayed-reference Simulink model and offline PR-ECB post-processing.\n\n"
        "## Results\n\n"
        f"{markdown_table(augmented)}\n\n"
        "## Summary\n\n"
        + "\n".join(
            "- {target}: n={n}, r_E {rmin} to {rmax}, energy/actual mean {er}, charge+ESR/actual mean {qr}".format(
                target=s["target_label"],
                n=s["n_success"],
                rmin=s["r_E_min"],
                rmax=s["r_E_max"],
                er=s["energy_over_actual_mean"],
                qr=s["charge_esr_over_actual_mean"],
            )
            for s in summary
        )
        + "\n\n"
        "## Interpretation\n\n"
        "The complete 8-row R040 matrix shows that PR-ECB is phase-sensitive and load-magnitude-sensitive. The 20A phase-offset sweep changes r_E from about 0.409 to 0.565. The 10A rows raise r_E to about 0.587-0.678. The near0 rows are the closest to the 10 mV allowance, with r_E about 0.858-0.993 and charge+ESR dominant. Energy-only can under-estimate the actual peak in the near0 offset-0 case, so the max(energy, charge+ESR) rule should be kept and a remaining high-side on-time correction should be investigated before claiming a calibration law. These results are not hardware/HIL validation.\n",
        encoding="utf-8",
    )
    paper = [
        "## R040 PR-ECB phase/load calibration",
        "",
        "R040 extends the R039 first-peak boundary probe by varying load-step phase offset and load-drop magnitude. All 8 derived-Simulink cases were executed. For 40A->20A, changing the load-step offset from 0 to 0.375us changes the energy-bound estimate from 4.085 to 5.649mV and r_E from 0.409 to 0.565, while the actual first peak stays in the narrower 2.134 to 2.244mV range. This supports the PR-ECB design choice: the first-peak risk feature should include phase-resolved inductor/gate state rather than only load-drop magnitude.",
        "",
        "For 40A->10A, r_E spans 0.587-0.678 across the two phase offsets. For 40A->near0, r_E spans 0.858-0.993 and charge+ESR is dominant. The near0 offset-0 case is especially informative: energy-only is below the actual peak, while charge+ESR remains conservative. This means the R039 conservatism ratios are not constants; calibration should remain piecewise by load magnitude and phase state, and the remaining high-side on-time correction E_HS,rem should be tested before any stronger law is claimed.",
        "",
        "Boundary: these are derived-Simulink and offline post-processing results only. PR-ECB remains a first-peak risk feature and safety-bound generator; it is not hardware validation and does not replace PIS-IEK/r_hat/B_epsilon post-peak recovery logic.",
        "",
    ]
    PAPER_SECTION.write_text("\n".join(paper), encoding="utf-8")


def main() -> None:
    rows = read_rows()
    augmented = build_augmented(rows)
    write_csv(COMBINED, augmented, list(augmented[0].keys()))
    summary = build_summary(rows)
    write_csv(SUMMARY, summary, list(summary[0].keys()))
    write_reports(augmented, summary)
    print(f"R040_COMBINED={COMBINED}")
    print(f"R040_SUMMARY={SUMMARY}")
    print(f"R040_REPORT={REPORT}")
    print(f"R040_PAPER_SECTION={PAPER_SECTION}")


if __name__ == "__main__":
    main()
