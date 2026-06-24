import csv
import importlib.util
import math
from pathlib import Path


def wrap_phase(x):
    while x > math.pi:
        x -= 2 * math.pi
    while x < -math.pi:
        x += 2 * math.pi
    return x


def pct(pred, actual):
    return (pred / actual - 1.0) * 100.0


def load_dynamic_model():
    path = Path("E:/Desktop/codex/output/iqcot_dynamic_iek_kernel_identification.py")
    spec = importlib.util.spec_from_file_location("dynamic_iek", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.BuckAreaEvent(), mod


def main():
    out = Path("E:/Desktop/codex/output")
    model, dyn = load_dynamic_model()
    lm = model.linear_model()

    amp_area = 2.0e-11
    allowed_period_pk = 1.0e-9
    duty = model.ton / model.tsw

    rows = []
    for ratio in [0.0, 0.001, 0.005, 0.01, 0.02, 0.05, 0.10, 0.20, 0.35, 0.50, 0.70]:
        omega = ratio * math.pi
        gt = model.period_response(omega)
        gd = -duty / model.tsw * gt

        dynamic_period_amp = abs(gt) * amp_area
        dynamic_phase = math.atan2(gt.imag, gt.real)

        static_gt = 1.0 / lm["He"]
        static_period_amp = abs(static_gt) * amp_area
        static_phase = 0.0

        dynamic_allow_area = allowed_period_pk / abs(gt)
        static_allow_area = allowed_period_pk / abs(static_gt)

        rows.append({
            "omega_over_pi": ratio,
            "dynamic_period_amp_ns": dynamic_period_amp * 1e9,
            "static_period_amp_ns": static_period_amp * 1e9,
            "static_amp_error_pct": pct(static_period_amp, dynamic_period_amp),
            "dynamic_phase_deg": dynamic_phase * 180.0 / math.pi,
            "static_phase_error_deg": wrap_phase(static_phase - dynamic_phase) * 180.0 / math.pi,
            "dynamic_duty_amp": abs(gd) * amp_area,
            "area_budget_for_1ns_dynamic": dynamic_allow_area,
            "area_budget_for_1ns_static": static_allow_area,
            "static_budget_error_pct": pct(static_allow_area, dynamic_allow_area),
        })

    # Nonlinear validation rows from the previous script demonstrate that the
    # dynamic IEK model is not just another theory curve.
    nonlinear_rows = []
    for ratio in [0.01, 0.02, 0.05, 0.10, 0.20, 0.35, 0.50, 0.70]:
        omega = ratio * math.pi
        p_amp, p_phase, d_amp, d_phase, _ = model.nonlinear_sine_response(omega, amp_area)
        gt = model.period_response(omega)
        dyn_period_amp = abs(gt) * amp_area
        dyn_phase = math.atan2(gt.imag, gt.real)
        static_period_amp = amp_area / lm["He"]
        nonlinear_rows.append({
            "omega_over_pi": ratio,
            "nonlinear_period_amp_ns": p_amp * 1e9,
            "dynamic_iek_amp_ns": dyn_period_amp * 1e9,
            "static_amp_ns": static_period_amp * 1e9,
            "dynamic_iek_amp_error_pct": pct(dyn_period_amp, p_amp),
            "static_amp_error_pct": pct(static_period_amp, p_amp),
            "dynamic_iek_phase_error_deg": wrap_phase(dyn_phase - p_phase) * 180.0 / math.pi,
            "static_phase_error_deg": wrap_phase(0.0 - p_phase) * 180.0 / math.pi,
        })

    comparison_path = out / "iqcot_iek_practical_value_static_vs_dynamic.csv"
    with comparison_path.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)

    nonlinear_path = out / "iqcot_iek_practical_value_nonlinear_comparison.csv"
    with nonlinear_path.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(nonlinear_rows[0].keys()))
        writer.writeheader()
        writer.writerows(nonlinear_rows)

    worst_static = max(abs(r["static_amp_error_pct"]) for r in nonlinear_rows)
    worst_dynamic = max(abs(r["dynamic_iek_amp_error_pct"]) for r in nonlinear_rows)
    worst_static_phase = max(abs(r["static_phase_error_deg"]) for r in nonlinear_rows)
    worst_dynamic_phase = max(abs(r["dynamic_iek_phase_error_deg"]) for r in nonlinear_rows)

    low = rows[0]
    valley = min(rows, key=lambda r: r["dynamic_period_amp_ns"])
    peak = max(rows, key=lambda r: r["dynamic_period_amp_ns"])

    summary = {
        "He_mV": lm["He"] * 1e3,
        "Hs_mV": lm["Hs"] * 1e3,
        "K1_required_mV": (lm["Hs"] - lm["He"]) * 1e3,
        "amp_area": amp_area,
        "static_period_amp_ns": amp_area / lm["He"] * 1e9,
        "dynamic_dc_period_amp_ns": rows[0]["dynamic_period_amp_ns"],
        "static_dc_amp_error_pct": rows[0]["static_amp_error_pct"],
        "dynamic_sensitivity_valley_omega_over_pi": valley["omega_over_pi"],
        "dynamic_sensitivity_valley_period_amp_ns": valley["dynamic_period_amp_ns"],
        "dynamic_sensitivity_peak_omega_over_pi": peak["omega_over_pi"],
        "dynamic_sensitivity_peak_period_amp_ns": peak["dynamic_period_amp_ns"],
        "worst_static_amp_error_pct_vs_nonlinear": worst_static,
        "worst_dynamic_amp_error_pct_vs_nonlinear": worst_dynamic,
        "worst_static_phase_error_deg_vs_nonlinear": worst_static_phase,
        "worst_dynamic_phase_error_deg_vs_nonlinear": worst_dynamic_phase,
        "dynamic_area_budget_1ns_dc": low["area_budget_for_1ns_dynamic"],
        "static_area_budget_1ns": low["area_budget_for_1ns_static"],
        "static_budget_error_pct_dc": low["static_budget_error_pct"],
    }

    summary_path = out / "iqcot_iek_practical_value_summary.csv"
    with summary_path.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(summary.keys()))
        writer.writeheader()
        writer.writerow(summary)

    print("IEK practical value comparison")
    print(f"SUMMARY_CSV={summary_path}")
    print(f"STATIC_DYNAMIC_CSV={comparison_path}")
    print(f"NONLINEAR_COMPARISON_CSV={nonlinear_path}")
    print(f"He={lm['He']*1e3:.4f} mV, Hs={lm['Hs']*1e3:.4f} mV")
    print(f"Static He-only period amplitude for {amp_area:.2e} area = {amp_area/lm['He']*1e9:.4f} ns")
    print(f"Dynamic DC period amplitude = {rows[0]['dynamic_period_amp_ns']:.4f} ns")
    print(f"Static DC amplitude error = {rows[0]['static_amp_error_pct']:.2f}%")
    print(f"Sensitivity valley: omega/pi={valley['omega_over_pi']}, amp={valley['dynamic_period_amp_ns']:.4f} ns")
    print(f"Sensitivity peak: omega/pi={peak['omega_over_pi']}, amp={peak['dynamic_period_amp_ns']:.4f} ns")
    print(f"Worst static amp error vs nonlinear = {worst_static:.2f}%")
    print(f"Worst dynamic IEK amp error vs nonlinear = {worst_dynamic:.5f}%")
    print(f"Worst static phase error vs nonlinear = {worst_static_phase:.2f} deg")
    print(f"Worst dynamic IEK phase error vs nonlinear = {worst_dynamic_phase:.5f} deg")
    print(f"1 ns area budget, dynamic DC = {low['area_budget_for_1ns_dynamic']:.3e}")
    print(f"1 ns area budget, static = {low['area_budget_for_1ns_static']:.3e}")


if __name__ == "__main__":
    main()
