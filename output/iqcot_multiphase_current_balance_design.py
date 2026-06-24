import csv
import importlib.util
import math
from pathlib import Path


def load_modal_model():
    path = Path("E:/Desktop/codex/output/iqcot_multiphase_iek_modal_study.py")
    spec = importlib.util.spec_from_file_location("mpiek", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.MultiPhaseAreaBuck(n=4), mod


def dc_currents_from_dcr(r_vals, vin, d_vals, iout):
    conductance = sum(1.0 / r for r in r_vals)
    vout = (vin * sum(d / r for d, r in zip(d_vals, r_vals)) - iout) / conductance
    currents = [(d * vin - vout) / r for d, r in zip(d_vals, r_vals)]
    return vout, currents


def equal_current_trim_for_dcr(r_vals, vin, d0, tsw, iref):
    r_mean = sum(r_vals) / len(r_vals)
    # Enforce zero-mean Ton trim so the current-balance actuator does not carry
    # common-mode voltage regulation.
    return [tsw * iref * (r - r_mean) / vin for r in r_vals]


def rms(vals):
    m = sum(vals) / len(vals)
    return math.sqrt(sum((v - m) ** 2 for v in vals) / len(vals))


def run_case(model, mod, name, r_scale):
    n = model.n
    r_vals = [model.r * s for s in r_scale]
    d0 = model.ton / model.tsw_ph
    d_equal = [d0] * n
    v0, i0 = dc_currents_from_dcr(r_vals, model.vin, d_equal, model.iout)
    trim = equal_current_trim_for_dcr(r_vals, model.vin, d0, model.tsw_ph, model.iph)
    d_trim = [d0 + t / model.tsw_ph for t in trim]
    v1, i1 = dc_currents_from_dcr(r_vals, model.vin, d_trim, model.iout)

    # Use the dynamic multi-phase area-event model to estimate the phase-spacing
    # cost of applying the same differential Ton pattern.  The current-balance
    # DC value above uses the mismatched DCR algebra; the event timing cost below
    # isolates the IQCOT phase-spacing side effect.
    waits, phases, currents, avg_i = model.run_with_ton_trim(
        18000,
        lambda k, q: 0.0,
        lambda k, p, trims=trim: trims[p],
    )
    waits_ss = waits[2000:]
    wait_pkpk = (max(waits_ss) - min(waits_ss)) * 1e9
    wait_rms = rms(waits_ss) * 1e9

    return {
        "case": name,
        "r_scale": " ".join(f"{x:.4f}" for x in r_scale),
        "r_mOhm": " ".join(f"{x*1e3:.4f}" for x in r_vals),
        "no_trim_vout_V": v0,
        "no_trim_currents_A": " ".join(f"{x:.6g}" for x in i0),
        "no_trim_current_pkpk_A": max(i0) - min(i0),
        "no_trim_current_rms_A": rms(i0),
        "required_ton_trim_ns": " ".join(f"{x*1e9:.6g}" for x in trim),
        "required_ton_trim_pkpk_ns": (max(trim) - min(trim)) * 1e9,
        "trimmed_vout_V": v1,
        "trimmed_currents_A": " ".join(f"{x:.6g}" for x in i1),
        "trimmed_current_pkpk_A": max(i1) - min(i1),
        "trimmed_current_rms_A": rms(i1),
        "event_wait_pkpk_ns_cost": wait_pkpk,
        "event_wait_rms_ns_cost": wait_rms,
        "phase_spacing_cost_per_A_pkpk_ns": wait_pkpk / (max(i0) - min(i0)) if max(i0) > min(i0) else 0.0,
    }


def run_limited_case(model, name, r_scale, trim_limit):
    n = model.n
    r_vals = [model.r * s for s in r_scale]
    d0 = model.ton / model.tsw_ph
    d_equal = [d0] * n
    _, i0 = dc_currents_from_dcr(r_vals, model.vin, d_equal, model.iout)
    full_trim = equal_current_trim_for_dcr(r_vals, model.vin, d0, model.tsw_ph, model.iph)
    trim = [max(-trim_limit, min(trim_limit, t)) for t in full_trim]
    # Remove common-mode introduced by clipping so the current-balancing
    # actuator does not change the voltage-regulation duty.
    mean_trim = sum(trim) / len(trim)
    trim = [t - mean_trim for t in trim]
    d_trim = [d0 + t / model.tsw_ph for t in trim]
    v1, i1 = dc_currents_from_dcr(r_vals, model.vin, d_trim, model.iout)
    waits, _, _, _ = model.run_with_ton_trim(
        14000,
        lambda k, q: 0.0,
        lambda k, p, trims=trim: trims[p],
    )
    waits_ss = waits[2000:]
    return {
        "case": name,
        "trim_limit_ns": trim_limit * 1e9,
        "full_required_trim_pkpk_ns": (max(full_trim) - min(full_trim)) * 1e9,
        "applied_trim_ns": " ".join(f"{x*1e9:.6g}" for x in trim),
        "applied_trim_pkpk_ns": (max(trim) - min(trim)) * 1e9,
        "no_trim_current_pkpk_A": max(i0) - min(i0),
        "limited_trim_current_pkpk_A": max(i1) - min(i1),
        "current_pkpk_reduction_pct": (1.0 - (max(i1) - min(i1)) / (max(i0) - min(i0))) * 100.0,
        "event_wait_pkpk_ns_cost": (max(waits_ss) - min(waits_ss)) * 1e9,
        "event_wait_rms_ns_cost": rms(waits_ss) * 1e9,
    }


def main():
    out = Path("E:/Desktop/codex/output")
    model, mod = load_modal_model()
    cases = [
        ("mild_monotonic_pm10pct", [0.90, 0.97, 1.03, 1.10]),
        ("strong_monotonic_pm20pct", [0.80, 0.93, 1.07, 1.20]),
        ("alternating_pm10pct", [0.90, 1.10, 0.90, 1.10]),
        ("one_phase_high_20pct", [1.20, 0.933333, 0.933333, 0.933333]),
        ("one_phase_low_20pct", [0.80, 1.066667, 1.066667, 1.066667]),
    ]
    rows = [run_case(model, mod, name, scales) for name, scales in cases]
    limited_rows = [
        run_limited_case(model, name, scales, limit)
        for name, scales in cases
        for limit in [0.05e-9, 0.10e-9, 0.20e-9, 0.50e-9]
    ]

    path = out / "iqcot_multiphase_current_balance_design.csv"
    with path.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)

    limited_path = out / "iqcot_multiphase_current_balance_limited_trim.csv"
    with limited_path.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(limited_rows[0].keys()))
        writer.writeheader()
        writer.writerows(limited_rows)

    worst_no_trim = max(rows, key=lambda r: r["no_trim_current_pkpk_A"])
    worst_cost = max(rows, key=lambda r: r["event_wait_pkpk_ns_cost"])
    best_residual = max(rows, key=lambda r: r["trimmed_current_pkpk_A"])
    print("Multiphase current-balance design chain")
    print(f"CSV={path}")
    print(f"LIMITED_TRIM_CSV={limited_path}")
    print(
        "Worst no-trim imbalance: "
        f"{worst_no_trim['case']}, Ipkpk={worst_no_trim['no_trim_current_pkpk_A']:.3f} A, "
        f"trim_pkpk={worst_no_trim['required_ton_trim_pkpk_ns']:.3f} ns"
    )
    print(
        "Worst phase-spacing cost: "
        f"{worst_cost['case']}, wait_pkpk={worst_cost['event_wait_pkpk_ns_cost']:.3f} ns"
    )
    print(
        "Residual after analytic trim: "
        f"max Ipkpk={best_residual['trimmed_current_pkpk_A']:.3e} A"
    )
    for limit in [0.10e-9, 0.20e-9]:
        candidates = [r for r in limited_rows if abs(r["trim_limit_ns"] - limit * 1e9) < 1e-12]
        avg_red = sum(r["current_pkpk_reduction_pct"] for r in candidates) / len(candidates)
        max_cost = max(r["event_wait_pkpk_ns_cost"] for r in candidates)
        print(
            f"Limited trim {limit*1e9:.2f} ns: "
            f"avg current pkpk reduction={avg_red:.2f}%, max wait cost={max_cost:.2f} ns"
        )


if __name__ == "__main__":
    main()
