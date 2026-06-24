import csv
import sys
from pathlib import Path

sys.path.insert(0, "E:/Desktop/codex/output/python_deps")

import matplotlib.pyplot as plt
import numpy as np


OUT = Path("E:/Desktop/codex/output")
FIG = OUT / "figures"
FIG.mkdir(exist_ok=True)


def read_csv(name):
    with (OUT / name).open(newline="") as f:
        return list(csv.DictReader(f))


def savefig(name):
    path = FIG / name
    plt.tight_layout()
    plt.savefig(path, dpi=220)
    plt.close()
    return path


def fig7_dense_common_sweep():
    rows = read_csv("iqcot_four_phase_dense_common_sweep.csv")
    x = np.array([float(r["omega_over_pi"]) for r in rows])
    sim = np.array([float(r["sim_wait_amp_ns"]) for r in rows])
    static = np.array([float(r["static_he_wait_amp_ns"]) for r in rows])
    err = np.abs(np.array([float(r["static_he_amp_error_pct"]) for r in rows]))

    fig, axes = plt.subplots(1, 2, figsize=(10.8, 4.2))
    ax = axes[0]
    ax.plot(x, sim, "o-", label="nonlinear event simulation")
    ax.plot(x, static, "--", label="He-only estimate")
    ax.set_xlabel(r"normalized event frequency $\omega/\pi$")
    ax.set_ylabel("wait amplitude (ns)")
    ax.set_title("Four-phase common-mode response")
    ax.grid(True, alpha=0.3)
    ax.legend(fontsize=8)

    ax = axes[1]
    ax.semilogy(x, err, "o-", color="#b23a48")
    ax.set_xlabel(r"normalized event frequency $\omega/\pi$")
    ax.set_ylabel("absolute amplitude error (%)")
    ax.set_title("He-only model error")
    ax.grid(True, which="both", alpha=0.3)
    savefig("fig7_dense_common_sweep.png")


def fig8_actuator_matrix():
    rows = read_csv("iqcot_four_phase_actuator_matrix.csv")
    labels = []
    current = []
    phase = []
    for actuator in ["lambda_diff", "delay_diff", "ton_diff"]:
        for pattern in ["m1_cos", "m2_alt", "one_phase"]:
            r = [x for x in rows if x["actuator"] == actuator and x["pattern"] == pattern][0]
            unit = "1e-13" if actuator == "lambda_diff" else "0.1 ns"
            labels.append(f"{actuator}\n{pattern}\nper {unit}")
            current.append(max(float(r["G_current_pkpk_mA"]), 1e-5))
            phase.append(max(float(r["G_phase_wait_pkpk_ns"]), 1e-5))

    x = np.arange(len(labels))
    fig, axes = plt.subplots(2, 1, figsize=(11.5, 7.2), sharex=True)
    axes[0].bar(x, current, color="#4f81bd")
    axes[0].set_yscale("log")
    axes[0].set_ylabel("current pk-pk gain (mA)")
    axes[0].set_title("Actuator matrix: current channel")
    axes[0].grid(True, axis="y", which="both", alpha=0.3)

    axes[1].bar(x, phase, color="#c0504d")
    axes[1].set_yscale("log")
    axes[1].set_ylabel("phase-wait pk-pk gain (ns)")
    axes[1].set_title("Actuator matrix: phase-spacing channel")
    axes[1].grid(True, axis="y", which="both", alpha=0.3)
    axes[1].set_xticks(x)
    axes[1].set_xticklabels(labels, rotation=45, ha="right", fontsize=8)
    savefig("fig8_actuator_matrix.png")


def fig9_mismatch_grid():
    rows = read_csv("iqcot_four_phase_mismatch_grid.csv")
    xs = np.array([float(r["nominal_event_phase_wait_pkpk_ns_cost"]) for r in rows])
    ys = np.array([float(r["current_pkpk_reduction_pct"]) for r in rows])
    cs = np.array([float(r["trim_limit_ns"]) for r in rows])
    no_trim = cs == 0.0
    nonzero = cs > 0.0

    plt.figure(figsize=(8.4, 5.2))
    plt.scatter(xs[no_trim], ys[no_trim], c="gray", s=28, label="no trim")
    sc = plt.scatter(xs[nonzero], ys[nonzero], c=cs[nonzero], cmap="viridis", s=36)
    cb = plt.colorbar(sc)
    cb.set_label("Ton trim limit (ns)")
    plt.xlabel("nominal phase-wait cost (ns pk-pk)")
    plt.ylabel("current pk-pk reduction (%)")
    plt.title("Four-phase DCR mismatch grid: benefit versus phase-spacing cost")
    plt.grid(True, alpha=0.3)
    plt.legend(loc="lower right")
    savefig("fig9_mismatch_grid.png")


def fig10_jitter_budget():
    bit_rows = read_csv("iqcot_digital_area_bit_budget.csv")
    comb_rows = read_csv("iqcot_digital_combined_jitter_budget.csv")
    bits = np.array([int(r["area_bits"]) for r in bit_rows])
    common = np.array([float(r["sigma_wait_common_rms_ns"]) for r in bit_rows])
    phase = np.array([float(r["sigma_phase_spacing_m2_ns"]) for r in bit_rows])

    fig, axes = plt.subplots(1, 2, figsize=(11.0, 4.4))
    ax = axes[0]
    ax.semilogy(bits, common, "o-", label="common wait jitter")
    ax.semilogy(bits, phase, "s-", label="m2 phase-spacing jitter")
    ax.set_xlabel("area threshold bits")
    ax.set_ylabel("jitter estimate (ns rms)")
    ax.set_title("Area-threshold quantization budget")
    ax.grid(True, which="both", alpha=0.3)
    ax.legend(fontsize=8)

    chosen = [r for r in comb_rows if int(r["ton_resolution_ps"]) == 10]
    xbits = sorted(set(int(r["area_bits"]) for r in chosen))
    yclocks = sorted(set(float(r["detect_clock_ns"]) for r in chosen))
    z = np.zeros((len(yclocks), len(xbits)))
    for r in chosen:
        i = yclocks.index(float(r["detect_clock_ns"]))
        j = xbits.index(int(r["area_bits"]))
        z[i, j] = float(r["sigma_phase_spacing_ns_rss"])
    ax = axes[1]
    im = ax.imshow(z, origin="lower", aspect="auto", cmap="magma",
                   extent=[min(xbits)-0.5, max(xbits)+0.5, min(yclocks), max(yclocks)])
    ax.set_xlabel("area threshold bits")
    ax.set_ylabel("detection clock (ns)")
    ax.set_title("Combined phase-spacing jitter, 10 ps Ton")
    cb = fig.colorbar(im, ax=ax)
    cb.set_label("ns rms")
    savefig("fig10_jitter_budget.png")


def main():
    fig7_dense_common_sweep()
    fig8_actuator_matrix()
    fig9_mismatch_grid()
    fig10_jitter_budget()
    print(f"Generated v2 figures under {FIG}")


if __name__ == "__main__":
    main()
