import math
import random
from statistics import mean, pstdev


def simulate_ar1(alpha, sigma_eps, n=300_000, burn=5_000, seed=7):
    random.seed(seed)
    tau = 0.0
    taus = []
    diffs = []
    last_tau = tau
    for k in range(n + burn):
        eps = random.gauss(0.0, sigma_eps)
        tau = alpha * tau + eps
        if k >= burn:
            taus.append(tau)
            diffs.append(tau - last_tau)
        last_tau = tau
    return taus, diffs


def main():
    # Normalized low-order RSE-PETS-IQCOT event model:
    # tau[k+1] = alpha*tau[k] + e[k], e = w_A / He.
    # Values are chosen as a numerical sanity check, not as a final converter design.
    fsw = 1.0e6
    tsw = 1.0 / fsw
    duty = 0.10
    he = 4.0e-3      # normalized event-kernel end value, V-equivalent
    hs = 2.0e-3      # normalized event-kernel start value
    alpha = hs / he

    # Noise budget in equivalent area units.
    toff = tsw * (1.0 - duty)
    sigma_lambda = 2.0e-12
    sigma_v = 30.0e-6
    sigma_i = 20.0e-3
    ri = 0.5e-3
    tq = 100.0e-12
    delta_aq = 1.0e-12

    sigma_a = math.sqrt(
        sigma_lambda**2
        + (toff * sigma_v) ** 2
        + (ri * toff * sigma_i) ** 2
        + (he * tq / math.sqrt(12.0)) ** 2
        + (delta_aq / math.sqrt(12.0)) ** 2
    )
    sigma_eps = sigma_a / he

    sigma_tau_theory = sigma_eps / math.sqrt(1.0 - alpha**2)
    sigma_diff_theory = math.sqrt(2.0 / (1.0 + alpha)) * sigma_eps
    sigma_d_theory = duty / tsw * sigma_diff_theory

    taus, diffs = simulate_ar1(alpha, sigma_eps)
    sigma_tau_sim = pstdev(taus)
    sigma_diff_sim = pstdev(diffs)
    sigma_d_sim = duty / tsw * sigma_diff_sim

    print("RSE-PETS-IQCOT low-order stochastic event sanity check")
    print(f"fsw = {fsw:.3e} Hz, D = {duty:.3f}, alpha = Hs/He = {alpha:.3f}")
    print(f"sigma_A = {sigma_a:.3e} area-unit, sigma_eps = {sigma_eps:.3e} s")
    print()
    print("Predicted vs simulated:")
    print(f"sigma_tau theory = {sigma_tau_theory:.3e} s")
    print(f"sigma_tau sim    = {sigma_tau_sim:.3e} s")
    print(f"rel error        = {(sigma_tau_sim/sigma_tau_theory-1.0)*100:.2f}%")
    print()
    print(f"sigma_delta_tau theory = {sigma_diff_theory:.3e} s")
    print(f"sigma_delta_tau sim    = {sigma_diff_sim:.3e} s")
    print(f"rel error              = {(sigma_diff_sim/sigma_diff_theory-1.0)*100:.2f}%")
    print()
    print(f"sigma_duty theory = {sigma_d_theory:.3e}")
    print(f"sigma_duty sim    = {sigma_d_sim:.3e}")
    print(f"rel error         = {(sigma_d_sim/sigma_d_theory-1.0)*100:.2f}%")

    # Show how DPWM/event time quantization degrades duty jitter.
    print()
    print("Time-quantization sweep:")
    for tq_sweep in [25e-12, 50e-12, 100e-12, 200e-12, 500e-12, 1e-9]:
        sigma_a_sweep = math.sqrt(
            sigma_lambda**2
            + (toff * sigma_v) ** 2
            + (ri * toff * sigma_i) ** 2
            + (he * tq_sweep / math.sqrt(12.0)) ** 2
            + (delta_aq / math.sqrt(12.0)) ** 2
        )
        sigma_eps_sweep = sigma_a_sweep / he
        sigma_d_sweep = duty / tsw * math.sqrt(2.0 / (1.0 + alpha)) * sigma_eps_sweep
        print(f"Tq={tq_sweep*1e12:7.1f} ps -> sigma_duty={sigma_d_sweep:.3e}")

    print()
    print("Time-quantization sweep with low analog noise:")
    low_sigma_lambda = 0.1e-12
    low_sigma_v = 0.2e-6
    low_sigma_i = 0.05e-3
    low_delta_aq = 0.05e-12
    for tq_sweep in [25e-12, 50e-12, 100e-12, 200e-12, 500e-12, 1e-9, 2e-9]:
        sigma_a_sweep = math.sqrt(
            low_sigma_lambda**2
            + (toff * low_sigma_v) ** 2
            + (ri * toff * low_sigma_i) ** 2
            + (he * tq_sweep / math.sqrt(12.0)) ** 2
            + (low_delta_aq / math.sqrt(12.0)) ** 2
        )
        sigma_eps_sweep = sigma_a_sweep / he
        sigma_d_sweep = duty / tsw * math.sqrt(2.0 / (1.0 + alpha)) * sigma_eps_sweep
        print(f"Tq={tq_sweep*1e12:7.1f} ps -> sigma_duty={sigma_d_sweep:.3e}")


if __name__ == "__main__":
    main()
