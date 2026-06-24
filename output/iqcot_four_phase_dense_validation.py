import csv
import importlib.util
import math
from pathlib import Path


OUT = Path("E:/Desktop/codex/output")


def load_modal_module():
    path = OUT / "iqcot_multiphase_iek_modal_study.py"
    spec = importlib.util.spec_from_file_location("mpiek_dense", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def mean(vals):
    return sum(vals) / len(vals)


def rms_about_mean(vals):
    m = mean(vals)
    return math.sqrt(sum((x - m) ** 2 for x in vals) / len(vals))


def pkpk(vals):
    return max(vals) - min(vals)


def fmt(vals, scale=1.0, digits=7):
    return " ".join(f"{v * scale:.{digits}g}" for v in vals)


def normalize_zero_mean(pattern):
    m = mean(pattern)
    return [x - m for x in pattern]


def pattern_library(n):
    if n != 4:
        raise ValueError("This dense validation script is intentionally fixed to four phases.")
    return {
        "m1_cos": normalize_zero_mean([math.cos(2.0 * math.pi * q / n) for q in range(n)]),
        "m2_alt": normalize_zero_mean([1.0 if q % 2 == 0 else -1.0 for q in range(n)]),
        "one_phase": normalize_zero_mean([1.0, -1.0 / 3.0, -1.0 / 3.0, -1.0 / 3.0]),
    }


def dc_currents_from_dcr(r_vals, vin, duty_vals, iout):
    conductance = sum(1.0 / r for r in r_vals)
    vout = (vin * sum(d / r for d, r in zip(duty_vals, r_vals)) - iout) / conductance
    currents = [(d * vin - vout) / r for d, r in zip(duty_vals, r_vals)]
    return vout, currents


def equal_current_trim_for_dcr(r_vals, vin, tsw, iref):
    r_mean = mean(r_vals)
    return [tsw * iref * (r - r_mean) / vin for r in r_vals]


def run_constant_offsets(model, lambda_vec, ton_vec, delay_vec, n_events=2600, burn=500):
    state = list(model.state)
    total_time = 0.0
    int_currents = [0.0] * model.n
    vout_events = []
    waits = []
    wait_by_phase = [[] for _ in range(model.n)]
    phase_periods = []
    off = [0.0] * model.n

    for k in range(n_events):
        p = k % model.n
        q = (p + 1) % model.n
        ton_k = max(1e-12, model.ton + ton_vec[p])
        s_on = [0.0] * model.n
        s_on[p] = 1.0

        int_on = model.segment_current_integrals(state, ton_k, s_on)
        start = model.segment(state, ton_k, s_on)
        lam = model.lambda_phase + lambda_vec[q]
        wait_cross = model.solve_wait(start, q, lam, model.tw)

        # Detection delay is modeled as additional time after the ideal area
        # crossing.  A signed per-phase offset represents digital calibration
        # around a nominal common delay.
        wait_actual = max(1e-12, wait_cross + delay_vec[q])
        int_wait = model.segment_current_integrals(start, wait_actual, off)
        state = model.segment(start, wait_actual, off)

        if k >= burn:
            for j in range(model.n):
                int_currents[j] += int_on[j] + int_wait[j]
            event_period = ton_k + wait_actual
            total_time += event_period
            waits.append(wait_actual - model.tw)
            wait_by_phase[q].append(wait_actual - model.tw)
            phase_periods.append(event_period - model.tg)
            vout_events.append(state[1])

    avg_i = [x / total_time for x in int_currents]
    wait_mean_by_phase = [mean(x) if x else 0.0 for x in wait_by_phase]
    return {
        "avg_i": avg_i,
        "current_pkpk_mA": pkpk(avg_i) * 1e3,
        "current_rms_mA": rms_about_mean(avg_i) * 1e3,
        "mean_wait_by_phase_ns": [x * 1e9 for x in wait_mean_by_phase],
        "mean_wait_phase_pkpk_ns": pkpk(wait_mean_by_phase) * 1e9,
        "event_wait_pkpk_ns": pkpk(waits) * 1e9,
        "event_wait_rms_ns": rms_about_mean(waits) * 1e9,
        "phase_period_pkpk_ns": pkpk(phase_periods) * 1e9,
        "avg_vout_event_V": mean(vout_events),
        "vout_event_pkpk_mV": pkpk(vout_events) * 1e3,
        "total_time_s": total_time,
    }


def dense_common_sweep(model, fit_sine):
    amp = 4.0e-13
    he_mean = mean(model.he_phase)
    static_amp = amp / he_mean
    ratios = [
        0.002, 0.004, 0.006, 0.008, 0.010, 0.015, 0.020, 0.030,
        0.040, 0.050, 0.070, 0.100, 0.130, 0.160, 0.200, 0.250,
        0.300, 0.350, 0.400, 0.500, 0.600, 0.700, 0.800, 0.850,
    ]
    rows = []
    for ratio in ratios:
        omega = ratio * math.pi
        n_events = 12000 if ratio <= 0.006 else 6500
        burn = 3000 if ratio <= 0.006 else 1200
        waits, _, _, vouts = model.run(
            n_events,
            lambda k, q, om=omega: amp * math.sin(om * k),
        )
        sim_amp, sim_phase, sim_offset = fit_sine(waits, omega, burn)
        v_amp, v_phase, v_offset = fit_sine(vouts, omega, burn)
        rows.append({
            "omega_over_pi": ratio,
            "amp_area": amp,
            "sim_wait_amp_ns": sim_amp * 1e9,
            "sim_wait_phase_deg": sim_phase * 180.0 / math.pi,
            "static_he_wait_amp_ns": static_amp * 1e9,
            "static_he_amp_error_pct": (static_amp / sim_amp - 1.0) * 100.0,
            "wait_offset_ns": sim_offset * 1e9,
            "vout_amp_mV": v_amp * 1e3,
            "vout_phase_deg": v_phase * 180.0 / math.pi,
            "vout_offset_V": v_offset,
            "gain_wait_ns_per_1e13_area": sim_amp * 1e9 / (amp / 1e-13),
        })
    return rows


def common_amplitude_linearity(model, fit_sine):
    rows = []
    ratios = [0.01, 0.05, 0.20, 0.50, 0.80]
    amps = [0.5e-13, 1.0e-13, 2.0e-13, 4.0e-13, 8.0e-13, 1.6e-12]
    for ratio in ratios:
        omega = ratio * math.pi
        for amp in amps:
            waits, _, _, _ = model.run(
                6500,
                lambda k, q, om=omega, a=amp: a * math.sin(om * k),
            )
            sim_amp, sim_phase, _ = fit_sine(waits, omega, 1200)
            rows.append({
                "omega_over_pi": ratio,
                "amp_area": amp,
                "wait_amp_ns": sim_amp * 1e9,
                "wait_phase_deg": sim_phase * 180.0 / math.pi,
                "gain_wait_ns_per_1e13_area": sim_amp * 1e9 / (amp / 1e-13),
            })
    return rows


def actuator_sweeps(model):
    rows = []
    patterns = pattern_library(model.n)
    actuator_defs = [
        ("lambda_diff", [0.5e-13, 1e-13, 2e-13, 4e-13, 8e-13, 1.6e-12], "area"),
        ("ton_diff", [0.005e-9, 0.010e-9, 0.020e-9, 0.050e-9, 0.100e-9, 0.200e-9], "s"),
        ("delay_diff", [0.005e-9, 0.010e-9, 0.020e-9, 0.050e-9, 0.100e-9, 0.200e-9], "s"),
    ]
    for actuator, amps, unit in actuator_defs:
        for pname, pat in patterns.items():
            for amp in amps:
                lambda_vec = [0.0] * model.n
                ton_vec = [0.0] * model.n
                delay_vec = [0.0] * model.n
                if actuator == "lambda_diff":
                    lambda_vec = [amp * x for x in pat]
                elif actuator == "ton_diff":
                    ton_vec = [amp * x for x in pat]
                elif actuator == "delay_diff":
                    delay_vec = [amp * x for x in pat]

                st = run_constant_offsets(model, lambda_vec, ton_vec, delay_vec)
                amp_norm = amp / 1e-13 if unit == "area" else amp / 0.1e-9
                rows.append({
                    "actuator": actuator,
                    "pattern": pname,
                    "amplitude": amp,
                    "amplitude_display": amp if unit == "area" else amp * 1e9,
                    "amplitude_unit": unit if unit == "area" else "ns",
                    "pattern_vector": fmt(pat),
                    "avg_phase_current_A": fmt(st["avg_i"]),
                    "phase_current_pkpk_mA": st["current_pkpk_mA"],
                    "phase_current_rms_mA": st["current_rms_mA"],
                    "mean_wait_phase_pkpk_ns": st["mean_wait_phase_pkpk_ns"],
                    "event_wait_pkpk_ns": st["event_wait_pkpk_ns"],
                    "event_wait_rms_ns": st["event_wait_rms_ns"],
                    "phase_period_pkpk_ns": st["phase_period_pkpk_ns"],
                    "avg_vout_event_V": st["avg_vout_event_V"],
                    "vout_event_pkpk_mV": st["vout_event_pkpk_mV"],
                    "mean_wait_by_phase_ns": fmt(st["mean_wait_by_phase_ns"]),
                    "gain_current_pkpk_mA_per_norm_amp": st["current_pkpk_mA"] / amp_norm,
                    "gain_wait_phase_pkpk_ns_per_norm_amp": st["mean_wait_phase_pkpk_ns"] / amp_norm,
                    "gain_event_wait_rms_ns_per_norm_amp": st["event_wait_rms_ns"] / amp_norm,
                })
    return rows


def actuator_matrix_from_sweeps(rows):
    selected = {
        "lambda_diff": 8e-13,
        "ton_diff": 0.100e-9,
        "delay_diff": 0.100e-9,
    }
    matrix = []
    for r in rows:
        target = selected[r["actuator"]]
        if abs(float(r["amplitude"]) - target) > max(1e-30, abs(target) * 1e-9):
            continue
        actuator = r["actuator"]
        norm_name = "per_1e-13_area" if actuator == "lambda_diff" else "per_0p1ns"
        matrix.append({
            "actuator": actuator,
            "pattern": r["pattern"],
            "reference_amplitude": r["amplitude"],
            "gain_normalization": norm_name,
            "G_current_pkpk_mA": r["gain_current_pkpk_mA_per_norm_amp"],
            "G_phase_wait_pkpk_ns": r["gain_wait_phase_pkpk_ns_per_norm_amp"],
            "G_event_wait_rms_ns": r["gain_event_wait_rms_ns_per_norm_amp"],
            "G_vout_pkpk_mV": float(r["vout_event_pkpk_mV"]) / (
                float(r["amplitude"]) / (1e-13 if actuator == "lambda_diff" else 0.1e-9)
            ),
            "raw_current_pkpk_mA": r["phase_current_pkpk_mA"],
            "raw_phase_wait_pkpk_ns": r["mean_wait_phase_pkpk_ns"],
            "raw_event_wait_rms_ns": r["event_wait_rms_ns"],
        })
    return matrix


def mismatch_grid(model):
    rows = []
    trim_limits = [0.0, 0.05e-9, 0.10e-9, 0.20e-9, 0.30e-9, 0.50e-9, 1.00e-9]
    cases = []
    for pct in [0.05, 0.10, 0.15, 0.20, 0.25]:
        cases.append((f"monotonic_pm{pct:.0%}", [1 - pct, 1 - pct / 3.0, 1 + pct / 3.0, 1 + pct]))
        cases.append((f"alternating_pm{pct:.0%}", [1 - pct, 1 + pct, 1 - pct, 1 + pct]))
        cases.append((f"one_high_pm{pct:.0%}", [1 + pct, 1 - pct / 3.0, 1 - pct / 3.0, 1 - pct / 3.0]))
        cases.append((f"one_low_pm{pct:.0%}", [1 - pct, 1 + pct / 3.0, 1 + pct / 3.0, 1 + pct / 3.0]))

    d0 = model.ton / model.tsw_ph
    for case_name, scales in cases:
        r_vals = [model.r * s for s in scales]
        _, i_no = dc_currents_from_dcr(r_vals, model.vin, [d0] * model.n, model.iout)
        full_trim = equal_current_trim_for_dcr(r_vals, model.vin, model.tsw_ph, model.iph)
        no_pkpk = pkpk(i_no)
        for limit in trim_limits:
            if limit <= 0.0:
                trim = [0.0] * model.n
            else:
                trim = [max(-limit, min(limit, t)) for t in full_trim]
                m = mean(trim)
                trim = [t - m for t in trim]
            duty_vals = [d0 + t / model.tsw_ph for t in trim]
            vout, currents = dc_currents_from_dcr(r_vals, model.vin, duty_vals, model.iout)
            st = run_constant_offsets(model, [0.0] * model.n, trim, [0.0] * model.n, n_events=1500, burn=300)
            rows.append({
                "case": case_name,
                "r_scale": fmt(scales, digits=6),
                "trim_limit_ns": limit * 1e9,
                "full_required_trim_ns": fmt(full_trim, 1e9),
                "full_required_trim_pkpk_ns": pkpk(full_trim) * 1e9,
                "applied_trim_ns": fmt(trim, 1e9),
                "applied_trim_pkpk_ns": pkpk(trim) * 1e9,
                "dc_vout_V": vout,
                "dc_current_A": fmt(currents),
                "no_trim_current_pkpk_A": no_pkpk,
                "trimmed_current_pkpk_A": pkpk(currents),
                "current_pkpk_reduction_pct": (1.0 - pkpk(currents) / no_pkpk) * 100.0 if no_pkpk > 1e-12 else 0.0,
                "nominal_event_phase_wait_pkpk_ns_cost": st["mean_wait_phase_pkpk_ns"],
                "nominal_event_wait_rms_ns_cost": st["event_wait_rms_ns"],
                "cost_per_reduction_ns_per_pct": (
                    st["mean_wait_phase_pkpk_ns"] / ((1.0 - pkpk(currents) / no_pkpk) * 100.0)
                    if no_pkpk > 1e-12 and pkpk(currents) < no_pkpk else ""
                ),
            })
    return rows


def write_csv(path, rows):
    with path.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)


def main():
    mod = load_modal_module()
    model = mod.MultiPhaseAreaBuck(n=4)
    common_rows = dense_common_sweep(model, mod.fit_sine)
    amp_rows = common_amplitude_linearity(model, mod.fit_sine)
    actuator_rows = actuator_sweeps(model)
    matrix_rows = actuator_matrix_from_sweeps(actuator_rows)
    mismatch_rows = mismatch_grid(model)

    write_csv(OUT / "iqcot_four_phase_dense_common_sweep.csv", common_rows)
    write_csv(OUT / "iqcot_four_phase_common_amplitude_linearity.csv", amp_rows)
    write_csv(OUT / "iqcot_four_phase_actuator_sweep.csv", actuator_rows)
    write_csv(OUT / "iqcot_four_phase_actuator_matrix.csv", matrix_rows)
    write_csv(OUT / "iqcot_four_phase_mismatch_grid.csv", mismatch_rows)

    lambda_matrix = [r for r in matrix_rows if r["actuator"] == "lambda_diff"]
    ton_matrix = [r for r in matrix_rows if r["actuator"] == "ton_diff"]
    delay_matrix = [r for r in matrix_rows if r["actuator"] == "delay_diff"]
    worst_common = max(common_rows, key=lambda r: abs(float(r["static_he_amp_error_pct"])))
    best_common = min(common_rows, key=lambda r: abs(float(r["static_he_amp_error_pct"])))
    mismatch_best = max(
        [r for r in mismatch_rows if float(r["trim_limit_ns"]) <= 0.200001],
        key=lambda r: float(r["current_pkpk_reduction_pct"]),
    )
    summary = [{
        "N": model.n,
        "Vin": model.vin,
        "Vref": model.vref,
        "Iout": model.iout,
        "Iph": model.iph,
        "L": model.l,
        "C": model.c,
        "DCR": model.r,
        "Ri": model.ri,
        "Ton_ns": model.ton * 1e9,
        "Twait_ns": model.tw * 1e9,
        "VC_mV": model.vc * 1e3,
        "Lambda": model.lambda_phase,
        "common_points": len(common_rows),
        "amplitude_linearity_points": len(amp_rows),
        "actuator_sweep_points": len(actuator_rows),
        "mismatch_grid_points": len(mismatch_rows),
        "worst_common_ratio": worst_common["omega_over_pi"],
        "worst_common_he_error_pct": worst_common["static_he_amp_error_pct"],
        "best_common_ratio": best_common["omega_over_pi"],
        "best_common_he_error_pct": best_common["static_he_amp_error_pct"],
        "lambda_max_G_current_mA_per_1e13": max(float(r["G_current_pkpk_mA"]) for r in lambda_matrix),
        "lambda_max_G_wait_ns_per_1e13": max(float(r["G_phase_wait_pkpk_ns"]) for r in lambda_matrix),
        "ton_max_G_current_mA_per_0p1ns": max(float(r["G_current_pkpk_mA"]) for r in ton_matrix),
        "ton_max_G_wait_ns_per_0p1ns": max(float(r["G_phase_wait_pkpk_ns"]) for r in ton_matrix),
        "delay_max_G_current_mA_per_0p1ns": max(float(r["G_current_pkpk_mA"]) for r in delay_matrix),
        "delay_max_G_wait_ns_per_0p1ns": max(float(r["G_phase_wait_pkpk_ns"]) for r in delay_matrix),
        "best_under_0p2ns_trim_case": mismatch_best["case"],
        "best_under_0p2ns_trim_limit_ns": mismatch_best["trim_limit_ns"],
        "best_under_0p2ns_current_reduction_pct": mismatch_best["current_pkpk_reduction_pct"],
        "best_under_0p2ns_phase_wait_cost_ns": mismatch_best["nominal_event_phase_wait_pkpk_ns_cost"],
    }]
    write_csv(OUT / "iqcot_four_phase_dense_summary.csv", summary)

    print("Four-phase dense IQCOT validation complete")
    print(f"COMMON_POINTS={len(common_rows)}")
    print(f"AMPLITUDE_LINEARITY_POINTS={len(amp_rows)}")
    print(f"ACTUATOR_SWEEP_POINTS={len(actuator_rows)}")
    print(f"MISMATCH_GRID_POINTS={len(mismatch_rows)}")
    print(
        "Worst common He-only error: "
        f"omega/pi={float(worst_common['omega_over_pi']):.3f}, "
        f"error={float(worst_common['static_he_amp_error_pct']):.2f}%"
    )
    print(
        "Actuator separation: "
        f"max Lambda current gain={summary[0]['lambda_max_G_current_mA_per_1e13']:.6g} mA/(1e-13), "
        f"max Ton current gain={summary[0]['ton_max_G_current_mA_per_0p1ns']:.6g} mA/(0.1 ns), "
        f"max delay wait gain={summary[0]['delay_max_G_wait_ns_per_0p1ns']:.6g} ns/(0.1 ns)"
    )


if __name__ == "__main__":
    main()
