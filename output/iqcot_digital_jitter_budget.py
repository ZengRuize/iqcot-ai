import csv
import importlib.util
import math
from pathlib import Path


OUT = Path("E:/Desktop/codex/output")


def read_csv(name):
    with (OUT / name).open(newline="") as f:
        return list(csv.DictReader(f))


def write_csv(path, rows):
    with path.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)


def load_model():
    path = OUT / "iqcot_multiphase_iek_modal_study.py"
    spec = importlib.util.spec_from_file_location("mpiek_budget", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.MultiPhaseAreaBuck(n=4)


def rms(vals):
    return math.sqrt(sum(x * x for x in vals) / len(vals))


def max_float(rows, key):
    return max(float(r[key]) for r in rows)


def gain_lookup(matrix, actuator, pattern):
    hits = [r for r in matrix if r["actuator"] == actuator and r["pattern"] == pattern]
    if not hits:
        raise RuntimeError(f"missing actuator matrix row: {actuator}/{pattern}")
    return hits[0]


def main():
    model = load_model()
    common = read_csv("iqcot_four_phase_dense_common_sweep.csv")
    matrix = read_csv("iqcot_four_phase_actuator_matrix.csv")
    actuator = read_csv("iqcot_four_phase_actuator_sweep.csv")

    # Common-mode area-threshold gain is estimated from dense swept-sine data.
    # Units: ns / area.
    common_gains_ns_per_area = [
        float(r["sim_wait_amp_ns"]) / float(r["amp_area"]) for r in common
    ]
    common_gain_rms_ns_per_area = rms(common_gains_ns_per_area)
    common_gain_peak_ns_per_area = max(abs(g) for g in common_gains_ns_per_area)

    # Differential area and delay gains use m2_alt as the worst simple interleaving
    # mode in the four-phase study.
    lambda_m2 = gain_lookup(matrix, "lambda_diff", "m2_alt")
    ton_m2 = gain_lookup(matrix, "ton_diff", "m2_alt")
    delay_m2 = gain_lookup(matrix, "delay_diff", "m2_alt")

    lambda_phase_gain_ns_per_area = (
        float(lambda_m2["G_phase_wait_pkpk_ns"]) / 1e-13
    )
    lambda_event_rms_gain_ns_per_area = (
        float(lambda_m2["G_event_wait_rms_ns"]) / 1e-13
    )
    ton_current_gain_mA_per_ns = float(ton_m2["G_current_pkpk_mA"]) / 0.1
    ton_phase_gain_ns_per_ns = float(ton_m2["G_phase_wait_pkpk_ns"]) / 0.1
    delay_phase_gain_ns_per_ns = float(delay_m2["G_phase_wait_pkpk_ns"]) / 0.1
    delay_current_gain_mA_per_ns = float(delay_m2["G_current_pkpk_mA"]) / 0.1

    lambda_full_scale = 2.0 * model.lambda_phase
    bit_rows = []
    for bits in [8, 9, 10, 11, 12, 13, 14, 15, 16, 18]:
        q_lambda = lambda_full_scale / (2 ** bits)
        sigma_lambda = q_lambda / math.sqrt(12.0)
        bit_rows.append({
            "area_bits": bits,
            "lambda_full_scale": lambda_full_scale,
            "q_lambda": q_lambda,
            "q_lambda_over_nominal": q_lambda / model.lambda_phase,
            "sigma_wait_common_rms_ns": common_gain_rms_ns_per_area * sigma_lambda,
            "sigma_wait_common_peakgain_ns": common_gain_peak_ns_per_area * sigma_lambda,
            "sigma_phase_spacing_m2_ns": lambda_phase_gain_ns_per_area * sigma_lambda,
            "sigma_event_wait_m2_ns": lambda_event_rms_gain_ns_per_area * sigma_lambda,
        })

    clock_rows = []
    for tclk_ns in [0.25, 0.5, 1.0, 2.0, 5.0, 10.0]:
        sigma_event = tclk_ns / math.sqrt(12.0)
        # Adjacent spacing is approximately a difference of two independently
        # quantized detection instants.  The calibrated delay-diff channel gives
        # an additional system-level gain estimate.
        sigma_adjacent = math.sqrt(2.0) * sigma_event
        clock_rows.append({
            "detect_clock_ns": tclk_ns,
            "sigma_single_event_delay_ns": sigma_event,
            "sigma_adjacent_spacing_direct_ns": sigma_adjacent,
            "sigma_phase_spacing_m2_model_ns": delay_phase_gain_ns_per_ns * sigma_event,
            "sigma_current_m2_model_mA": delay_current_gain_mA_per_ns * sigma_event,
        })

    ton_rows = []
    for qton_ps in [1, 2, 5, 10, 20, 50, 100]:
        qton_ns = qton_ps * 1e-3
        sigma_ton_ns = qton_ns / math.sqrt(12.0)
        ton_rows.append({
            "ton_resolution_ps": qton_ps,
            "sigma_ton_quant_ns": sigma_ton_ns,
            "sigma_current_pkpk_m2_mA": ton_current_gain_mA_per_ns * sigma_ton_ns,
            "sigma_phase_spacing_m2_ns": ton_phase_gain_ns_per_ns * sigma_ton_ns,
        })

    combined_rows = []
    for bits in [10, 12, 14, 16]:
        b = [r for r in bit_rows if r["area_bits"] == bits][0]
        for tclk_ns in [0.5, 1.0, 2.0, 5.0]:
            c = [r for r in clock_rows if abs(r["detect_clock_ns"] - tclk_ns) < 1e-12][0]
            for qton_ps in [5, 10, 20, 50]:
                t = [r for r in ton_rows if r["ton_resolution_ps"] == qton_ps][0]
                combined_rows.append({
                    "area_bits": bits,
                    "detect_clock_ns": tclk_ns,
                    "ton_resolution_ps": qton_ps,
                    "sigma_common_wait_ns_rss": math.sqrt(
                        b["sigma_wait_common_rms_ns"] ** 2
                        + c["sigma_single_event_delay_ns"] ** 2
                    ),
                    "sigma_phase_spacing_ns_rss": math.sqrt(
                        b["sigma_phase_spacing_m2_ns"] ** 2
                        + c["sigma_adjacent_spacing_direct_ns"] ** 2
                        + t["sigma_phase_spacing_m2_ns"] ** 2
                    ),
                    "sigma_current_mA_rss": math.sqrt(
                        c["sigma_current_m2_model_mA"] ** 2
                        + t["sigma_current_pkpk_m2_mA"] ** 2
                    ),
                })

    gain_rows = [{
        "lambda_nominal": model.lambda_phase,
        "lambda_full_scale_assumption": lambda_full_scale,
        "common_gain_rms_ns_per_area": common_gain_rms_ns_per_area,
        "common_gain_peak_ns_per_area": common_gain_peak_ns_per_area,
        "lambda_phase_gain_ns_per_area_m2": lambda_phase_gain_ns_per_area,
        "lambda_event_rms_gain_ns_per_area_m2": lambda_event_rms_gain_ns_per_area,
        "ton_current_gain_mA_per_ns_m2": ton_current_gain_mA_per_ns,
        "ton_phase_gain_ns_per_ns_m2": ton_phase_gain_ns_per_ns,
        "delay_phase_gain_ns_per_ns_m2": delay_phase_gain_ns_per_ns,
        "delay_current_gain_mA_per_ns_m2": delay_current_gain_mA_per_ns,
        "source_common_points": len(common),
        "source_actuator_points": len(actuator),
    }]

    write_csv(OUT / "iqcot_digital_area_bit_budget.csv", bit_rows)
    write_csv(OUT / "iqcot_digital_detection_clock_budget.csv", clock_rows)
    write_csv(OUT / "iqcot_digital_ton_resolution_budget.csv", ton_rows)
    write_csv(OUT / "iqcot_digital_combined_jitter_budget.csv", combined_rows)
    write_csv(OUT / "iqcot_digital_jitter_gain_summary.csv", gain_rows)

    best_12 = [r for r in bit_rows if r["area_bits"] == 12][0]
    combined_pick = [
        r for r in combined_rows
        if r["area_bits"] == 12 and abs(r["detect_clock_ns"] - 1.0) < 1e-12 and r["ton_resolution_ps"] == 10
    ][0]
    print("Digital IQCOT jitter budget complete")
    print(f"LAMBDA_NOMINAL={model.lambda_phase:.6e}")
    print(
        "12-bit area threshold: "
        f"sigma_common_wait={best_12['sigma_wait_common_rms_ns']:.4f} ns, "
        f"sigma_phase_spacing={best_12['sigma_phase_spacing_m2_ns']:.4f} ns"
    )
    print(
        "Example combined budget (12 bit, 1 ns clock, 10 ps Ton): "
        f"sigma_common_wait={combined_pick['sigma_common_wait_ns_rss']:.4f} ns, "
        f"sigma_phase_spacing={combined_pick['sigma_phase_spacing_ns_rss']:.4f} ns, "
        f"sigma_current={combined_pick['sigma_current_mA_rss']:.3f} mA"
    )


if __name__ == "__main__":
    main()
