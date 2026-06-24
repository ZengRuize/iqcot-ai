from __future__ import annotations

import csv
from collections import defaultdict
from math import ceil, floor
from pathlib import Path
from statistics import mean, pstdev


ROOT = Path(__file__).resolve().parent
INPUTS = [
    ("r040_r041_corrected", ROOT / "iqcot_r041_pr_ecb_hsrem_results.csv"),
    ("r042_phase_dense", ROOT / "iqcot_r042_pr_ecb_phase_dense_results_combined.csv"),
]
ROWS_OUT = ROOT / "iqcot_r043_pr_ecb_segmented_rows.csv"
RULES_OUT = ROOT / "iqcot_r043_pr_ecb_segmented_rules.csv"
REPORT = ROOT / "iqcot_r043_pr_ecb_segmented_report.md"
PAPER_SECTION = ROOT / "iqcot_r043_pr_ecb_segmented_paper_section.md"


def f(row: dict[str, str], key: str, default: float = 0.0) -> float:
    value = row.get(key, "")
    if value == "" or value is None:
        return default
    return float(value)


def fmt(value: float, digits: int = 6) -> str:
    return f"{value:.{digits}f}"


def ratio(num: float, den: float) -> float:
    return num / den if abs(den) > 1e-12 else float("nan")


def load_segment(load_drop: float) -> str:
    if load_drop >= 35.0:
        return "high_drop_charge_esr"
    if load_drop >= 30.0:
        return "mid_drop_transition"
    return "low_drop_energy"


def target_order(label: str) -> int:
    order = {"near0": 0, "5A": 1, "10A": 2, "20A": 3}
    return order.get(label, 99)


def choose_bound(row: dict[str, object]) -> str:
    load_drop = float(row["load_drop_A"])
    active = bool(row["active_hsrem"])
    if load_drop >= 35.0:
        return "charge_esr"
    if active:
        return "corrected_energy"
    return "energy"


def corrected_family(energy_corr: float, charge: float, active: bool) -> str:
    if energy_corr < charge:
        return "charge_esr"
    return "corrected_energy" if active else "energy"


def outward_ratio_band(values: list[float], step: float = 0.05) -> str:
    lower = floor(min(values) / step) * step
    upper = ceil(max(values) / step) * step
    return f"{lower:.2f}-{upper:.2f}x"


def read_rows() -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for source, path in INPUTS:
        if not path.exists():
            raise FileNotFoundError(path)
        with path.open(newline="", encoding="utf-8-sig") as handle:
            for raw in csv.DictReader(handle):
                case_id = raw["case_id"]
                target = raw["target_label"]
                load_drop = f(raw, "load_drop_A")
                offset = f(raw, "load_step_offset_us")
                actual = f(raw, "delta_v_actual_peak_mV")
                energy = f(raw, "delta_v_energy_mV")
                charge = f(raw, "delta_v_charge_esr_mV")
                energy_corr = f(raw, "delta_v_energy_corr_mV", energy)
                max_corr = f(raw, "delta_v_max_corr_mV", max(energy_corr, charge))
                active_phases = raw.get("active_hsrem_phases", "")
                active = bool(str(active_phases).strip())
                recommended = choose_bound({"load_drop_A": load_drop, "active_hsrem": active})
                if recommended == "charge_esr":
                    rec_value = charge
                elif recommended == "corrected_energy":
                    rec_value = energy_corr
                else:
                    rec_value = energy
                item: dict[str, object] = {
                    "source": source,
                    "case_id": case_id,
                    "target_label": target,
                    "target_load_A": f(raw, "target_load_A"),
                    "load_drop_A": load_drop,
                    "load_segment": load_segment(load_drop),
                    "load_step_offset_us": offset,
                    "active_hsrem": active,
                    "active_hsrem_phases": active_phases,
                    "remaining_ton_total_ns": f(raw, "remaining_ton_total_ns"),
                    "E_HS_rem_uJ": f(raw, "E_HS_rem_uJ"),
                    "delta_v_energy_mV": energy,
                    "delta_v_charge_esr_mV": charge,
                    "delta_v_energy_corr_mV": energy_corr,
                    "delta_v_max_corr_mV": max_corr,
                    "delta_v_actual_peak_mV": actual,
                    "dominant_raw": "energy" if energy >= charge else "charge_esr",
                    "dominant_corrected": corrected_family(energy_corr, charge, active),
                    "recommended_bound": recommended,
                    "recommended_bound_mV": rec_value,
                    "recommended_over_actual": ratio(rec_value, actual),
                    "r_E_recommended": rec_value / f(raw, "delta_v_allow_mV", 10.0),
                    "max_corr_over_actual": f(raw, "max_corr_over_actual", ratio(max_corr, actual)),
                    "r_E_max_corr": f(raw, "r_E_max_corr", max_corr / f(raw, "delta_v_allow_mV", 10.0)),
                }
                rows.append(item)
    rows.sort(key=lambda r: (target_order(str(r["target_label"])), float(r["load_step_offset_us"]), str(r["source"])))
    return rows


def group_rules(rows: list[dict[str, object]]) -> list[dict[str, object]]:
    groups: dict[tuple[str, bool, str], list[dict[str, object]]] = defaultdict(list)
    for row in rows:
        key = (str(row["load_segment"]), bool(row["active_hsrem"]), str(row["recommended_bound"]))
        groups[key].append(row)

    rules: list[dict[str, object]] = []
    for (segment, active, bound), items in sorted(groups.items()):
        rec_ratios = [float(r["recommended_over_actual"]) for r in items]
        r_e = [float(r["r_E_recommended"]) for r in items]
        max_ratios = [float(r["max_corr_over_actual"]) for r in items]
        load_drops = [float(r["load_drop_A"]) for r in items]
        offsets = [float(r["load_step_offset_us"]) for r in items]
        targets = sorted({str(r["target_label"]) for r in items}, key=target_order)
        dominant_counts: dict[str, int] = defaultdict(int)
        for r in items:
            dominant_counts[str(r["dominant_corrected"])] += 1
        dominant_summary = ";".join(f"{k}:{v}" for k, v in sorted(dominant_counts.items()))
        rules.append(
            {
                "segment": segment,
                "active_hsrem": int(active),
                "targets": "/".join(targets),
                "n_rows": len(items),
                "load_drop_min_A": fmt(min(load_drops)),
                "load_drop_max_A": fmt(max(load_drops)),
                "offset_min_us": fmt(min(offsets)),
                "offset_max_us": fmt(max(offsets)),
                "recommended_bound": bound,
                "r_E_recommended_min": fmt(min(r_e)),
                "r_E_recommended_max": fmt(max(r_e)),
                "recommended_over_actual_min": fmt(min(rec_ratios)),
                "recommended_over_actual_max": fmt(max(rec_ratios)),
                "recommended_over_actual_mean": fmt(mean(rec_ratios)),
                "recommended_over_actual_std": fmt(pstdev(rec_ratios) if len(rec_ratios) > 1 else 0.0),
                "conservative_ratio_band": outward_ratio_band(rec_ratios),
                "max_corr_over_actual_min": fmt(min(max_ratios)),
                "max_corr_over_actual_max": fmt(max(max_ratios)),
                "dominant_corrected_counts": dominant_summary,
                "claim_boundary": claim_boundary(segment, active, bound),
            }
        )
    return rules


def claim_boundary(segment: str, active: bool, bound: str) -> str:
    if segment == "high_drop_charge_esr":
        return "Use charge+ESR as dominant first-peak risk feature for near0/5A-like large cut-loads; E_HS,rem is diagnostic only."
    if segment == "mid_drop_transition":
        if active:
            return "Use corrected energy for active-HS 10A-like transition rows; treat as transition band, not universal law."
        return "Use raw energy for post-turnoff 10A-like transition rows; treat as transition band, not universal law."
    if active:
        return "Use corrected energy for active-HS 20A-like smaller cut-loads; note high conservatism versus actual first peak."
    return "Use raw energy for post-turnoff 20A-like smaller cut-loads; note conservatism is high versus actual first peak."


def write_csv(path: Path, rows: list[dict[str, object]]) -> None:
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)


def markdown_rules(rules: list[dict[str, object]]) -> str:
    lines = [
        "| segment | active HS | targets | bound | r_E range | bound/actual range | conservative band | claim boundary |",
        "| --- | ---: | --- | --- | ---: | ---: | ---: | --- |",
    ]
    for r in rules:
        lines.append(
            "| {segment} | {active} | {targets} | {bound} | {rmin}-{rmax} | {amin}-{amax} | {band} | {claim} |".format(
                segment=r["segment"],
                active=r["active_hsrem"],
                targets=r["targets"],
                bound=r["recommended_bound"],
                rmin=r["r_E_recommended_min"],
                rmax=r["r_E_recommended_max"],
                amin=r["recommended_over_actual_min"],
                amax=r["recommended_over_actual_max"],
                band=r["conservative_ratio_band"],
                claim=r["claim_boundary"],
            )
        )
    return "\n".join(lines)


def write_reports(rows: list[dict[str, object]], rules: list[dict[str, object]]) -> None:
    high = [r for r in rules if r["segment"] == "high_drop_charge_esr"]
    mid = [r for r in rules if r["segment"] == "mid_drop_transition"]
    low = [r for r in rules if r["segment"] == "low_drop_energy"]
    active_rows = sum(1 for r in rows if r["active_hsrem"])
    REPORT.write_text(
        "# R043 Segmented PR-ECB Calibration Surface\n\n"
        "## Scope\n\n"
        "R043 merges the completed R040/R041/R042 derived-Simulink evidence and fits an offline segmented PR-ECB calibration surface. No new Simulink run is performed. The surface is expressed as a conservative rule table over load-drop magnitude, active high-side remaining-on-time, and dominant bound class.\n\n"
        "## Rule Table\n\n"
        f"{markdown_rules(rules)}\n\n"
        "## Interpretation\n\n"
        f"The merged dataset contains {len(rows)} rows, including {active_rows} active-HS rows. The completed R042 matrix shows a consistent phase-4 boundary: remaining on-time is present before 0.105 us and absent from 0.105 us onward. R043 therefore treats E_HS,rem as a segmentation feature, not a universal additive term.\n\n"
        "The conservative ratio band is the observed recommended-bound/actual range rounded outward to 0.05x. It is a paper-facing summary of this derived-model dataset, not a universal safety factor.\n\n"
        "The load segmentation is stable enough for a paper-safe statement: near0/5A-like large cut-loads are charge+ESR dominated; 10A is a transition band where corrected-energy resolves active-HS rows; 20A-like smaller cut-loads are energy/corrected-energy dominated but conservative versus actual first peak.\n\n"
        "Boundary: this is derived-Simulink and offline post-processing evidence only. It is not hardware/HIL validation and does not prove global PR-ECB calibration.\n",
        encoding="utf-8",
    )

    PAPER_SECTION.write_text(
        "## R043 segmented PR-ECB calibration surface\n\n"
        "R043 converts the R040/R041/R042 first-peak evidence into a segmented calibration surface. The recommended first-peak risk feature is selected by load-drop magnitude and active high-side remaining-on-time. For near0/5A-like large cut-loads, charge+ESR remains the dominant bound. For 10A-like transition cases, corrected-energy is used when a high-side phase is still active and raw energy otherwise. For 20A-like smaller cut-loads, energy/corrected-energy dominates, but with higher conservatism versus the derived-Simulink actual peak. The rule table reports r_E, observed bound/actual ratios, and an outward-rounded conservative ratio band for each segment.\n\n"
        "This supports writing PR-ECB as a segmented supervisory risk feature rather than a single additive correction law. The evidence remains derived-Simulink/offline only and should not be described as hardware or HIL validation.\n",
        encoding="utf-8",
    )


def main() -> None:
    rows = read_rows()
    rules = group_rules(rows)
    write_csv(ROWS_OUT, rows)
    write_csv(RULES_OUT, rules)
    write_reports(rows, rules)
    print(f"R043_ROWS={ROWS_OUT}")
    print(f"R043_RULES={RULES_OUT}")
    print(f"R043_REPORT={REPORT}")
    print(f"R043_PAPER_SECTION={PAPER_SECTION}")


if __name__ == "__main__":
    main()
