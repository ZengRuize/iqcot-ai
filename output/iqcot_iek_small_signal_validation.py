import csv
import math
import random
from pathlib import Path


def solve_toff(lambda_area, hs, sf):
    disc = hs * hs + 2.0 * sf * lambda_area
    return (-hs + math.sqrt(disc)) / sf


def fit_sine(x, omega, start=0):
    # Fit x[n] = a*sin(w n) + b*cos(w n) + c using the absolute
    # sample index.  Keeping the original time origin makes the fitted
    # phase directly comparable with the z-domain frequency response.
    s2 = c2 = sc = sx = cx = ss = cc = nsum = 0.0
    count = 0
    for idx in range(start, len(x)):
        n = idx
        s = math.sin(omega * n)
        c = math.cos(omega * n)
        y = x[idx]
        s2 += s * s
        c2 += c * c
        sc += s * c
        sx += s * y
        cx += c * y
        ss += s
        cc += c
        nsum += y
        count += 1

    # Solve 3x3 normal equation by small Gaussian elimination.
    a = [
        [s2, sc, ss, sx],
        [sc, c2, cc, cx],
        [ss, cc, count, nsum],
    ]
    for col in range(3):
        pivot = max(range(col, 3), key=lambda r: abs(a[r][col]))
        a[col], a[pivot] = a[pivot], a[col]
        div = a[col][col]
        for j in range(col, 4):
            a[col][j] /= div
        for r in range(3):
            if r == col:
                continue
            fac = a[r][col]
            for j in range(col, 4):
                a[r][j] -= fac * a[col][j]
    sin_coeff, cos_coeff, offset = a[0][3], a[1][3], a[2][3]
    amp = math.sqrt(sin_coeff**2 + cos_coeff**2)
    phase = math.atan2(cos_coeff, sin_coeff)
    return amp, phase, offset


def wrap_phase(x):
    while x > math.pi:
        x -= 2 * math.pi
    while x < -math.pi:
        x += 2 * math.pi
    return x


def channel_validation(params):
    lambda0, hs, sf, ri, il_avg = (
        params["lambda0"],
        params["hs"],
        params["sf"],
        params["ri"],
        params["il_avg"],
    )
    toff0 = solve_toff(lambda0, hs, sf)
    he = hs + sf * toff0
    integral_il = il_avg * toff0
    rows = []

    for rho in [-0.05, -0.02, -0.01, 0.01, 0.02, 0.05]:
        lam = lambda0 * math.exp(rho)
        exact = solve_toff(lam, hs, sf) - toff0
        pred = lambda0 * rho / he
        rows.append({
            "channel": "rho",
            "value": rho,
            "exact_dt_ns": exact * 1e9,
            "pred_dt_ns": pred * 1e9,
            "rel_error_pct": (pred / exact - 1) * 100,
        })

    for kappa in [-0.05, -0.02, 0.02, 0.05]:
        a_ri = -ri * kappa * integral_il
        exact = solve_toff(lambda0 - a_ri, hs, sf) - toff0
        pred = -a_ri / he
        rows.append({
            "channel": "kappa",
            "value": kappa,
            "exact_dt_ns": exact * 1e9,
            "pred_dt_ns": pred * 1e9,
            "rel_error_pct": (pred / exact - 1) * 100,
        })

    for td in [10e-9, 20e-9, 40e-9, 80e-9]:
        delta_a = he * td + 0.5 * sf * td * td
        exact = solve_toff(lambda0 + delta_a, hs, sf) - toff0
        rows.append({
            "channel": "detection_delay",
            "value": td * 1e9,
            "exact_dt_ns": exact * 1e9,
            "pred_dt_ns": td * 1e9,
            "rel_error_pct": (td / exact - 1) * 100,
        })

    return rows


def frequency_response_validation(params):
    he = params["he"]
    alpha = params["alpha"]
    duty = params["duty"]
    tsw = params["tsw"]
    amp_u = 2.0e-12
    n = 8192
    burn = 1024

    rows = []
    for omega in [0.02 * math.pi, 0.05 * math.pi, 0.10 * math.pi, 0.20 * math.pi, 0.35 * math.pi, 0.50 * math.pi, 0.70 * math.pi]:
        tau = [0.0] * (n + 1)
        duty_hat = [0.0] * n
        u = [amp_u * math.sin(omega * k) for k in range(n)]
        for k in range(n):
            tau[k + 1] = alpha * tau[k] + u[k] / he
            duty_hat[k] = -duty / tsw * (tau[k + 1] - tau[k])

        tau_amp, tau_phase, _ = fit_sine(tau[:-1], omega, burn)
        d_amp, d_phase, _ = fit_sine(duty_hat, omega, burn)

        z = complex(math.cos(omega), math.sin(omega))
        h_tau = 1.0 / (he * (z - alpha))
        h_d = -duty / tsw * (z - 1.0) / (he * (z - alpha))
        tau_amp_th = abs(h_tau) * amp_u
        d_amp_th = abs(h_d) * amp_u
        tau_phase_th = math.atan2(h_tau.imag, h_tau.real)
        d_phase_th = math.atan2(h_d.imag, h_d.real)

        rows.append({
            "omega_over_pi": omega / math.pi,
            "tau_amp_ns_sim": tau_amp * 1e9,
            "tau_amp_ns_theory": tau_amp_th * 1e9,
            "tau_amp_error_pct": (tau_amp / tau_amp_th - 1) * 100,
            "tau_phase_error_deg": wrap_phase(tau_phase - tau_phase_th) * 180 / math.pi,
            "duty_amp_sim": d_amp,
            "duty_amp_theory": d_amp_th,
            "duty_amp_error_pct": (d_amp / d_amp_th - 1) * 100,
            "duty_phase_error_deg": wrap_phase(d_phase - d_phase_th) * 180 / math.pi,
        })

    return rows


def memory_kernel_frequency_validation(params):
    he = params["he"]
    hs = params["hs"]
    duty = params["duty"]
    tsw = params["tsw"]
    amp_u = 2.0e-12
    n = 16384
    burn = 2048

    # A synthetic one-lag memory kernel is used only to verify the generalized
    # IEK algebra.  k0 and k1 are chosen so that
    # He*z - Hs + k0 + k1*z^-1 has a zero at z=1.  This is the discrete
    # time-translation invariance expected in an autonomous switching model.
    p_memory = 0.35
    k0 = hs - he * (1.0 + p_memory)
    k1 = he * p_memory

    rows = []
    for omega in [0.02 * math.pi, 0.05 * math.pi, 0.10 * math.pi, 0.20 * math.pi, 0.35 * math.pi, 0.50 * math.pi, 0.70 * math.pi]:
        tau = [0.0] * (n + 1)
        duty_hat = [0.0] * n
        u = [amp_u * math.sin(omega * k) for k in range(n)]
        for k in range(n):
            tau_km1 = tau[k - 1] if k > 0 else 0.0
            tau[k + 1] = ((hs - k0) * tau[k] - k1 * tau_km1 + u[k]) / he
            duty_hat[k] = -duty / tsw * (tau[k + 1] - tau[k])

        tau_amp, tau_phase, _ = fit_sine(tau[:-1], omega, burn)
        d_amp, d_phase, _ = fit_sine(duty_hat, omega, burn)

        z = complex(math.cos(omega), math.sin(omega))
        den = he * z - hs + k0 + k1 / z
        h_tau = 1.0 / den
        h_d = -duty / tsw * (z - 1.0) / den
        tau_amp_th = abs(h_tau) * amp_u
        d_amp_th = abs(h_d) * amp_u
        tau_phase_th = math.atan2(h_tau.imag, h_tau.real)
        d_phase_th = math.atan2(h_d.imag, h_d.real)

        rows.append({
            "omega_over_pi": omega / math.pi,
            "memory_pole": p_memory,
            "k0": k0,
            "k1": k1,
            "tau_amp_ns_sim": tau_amp * 1e9,
            "tau_amp_ns_theory": tau_amp_th * 1e9,
            "tau_amp_error_pct": (tau_amp / tau_amp_th - 1) * 100,
            "tau_phase_error_deg": wrap_phase(tau_phase - tau_phase_th) * 180 / math.pi,
            "duty_amp_sim": d_amp,
            "duty_amp_theory": d_amp_th,
            "duty_amp_error_pct": (d_amp / d_amp_th - 1) * 100,
            "duty_phase_error_deg": wrap_phase(d_phase - d_phase_th) * 180 / math.pi,
        })

    return rows


def noise_validation(params):
    random.seed(17)
    he = params["he"]
    alpha = params["alpha"]
    duty = params["duty"]
    tsw = params["tsw"]
    sigma_a = 8.0e-12
    sigma_eps = sigma_a / he
    n = 300_000
    burn = 5000
    tau = 0.0
    taus = []
    dd = []
    last_tau = tau
    for k in range(n + burn):
        tau = alpha * tau + random.gauss(0.0, sigma_eps)
        if k >= burn:
            taus.append(tau)
            dd.append(-duty / tsw * (tau - last_tau))
        last_tau = tau
    sigma_tau_sim = pstdev(taus)
    sigma_d_sim = pstdev(dd)
    sigma_tau_th = sigma_eps / math.sqrt(1 - alpha**2)
    sigma_d_th = duty / tsw * math.sqrt(2 / (1 + alpha)) * sigma_eps
    return {
        "sigma_A": sigma_a,
        "sigma_tau_ns_sim": sigma_tau_sim * 1e9,
        "sigma_tau_ns_theory": sigma_tau_th * 1e9,
        "sigma_tau_error_pct": (sigma_tau_sim / sigma_tau_th - 1) * 100,
        "sigma_duty_sim": sigma_d_sim,
        "sigma_duty_theory": sigma_d_th,
        "sigma_duty_error_pct": (sigma_d_sim / sigma_d_th - 1) * 100,
    }


def pstdev(vals):
    m = sum(vals) / len(vals)
    return math.sqrt(sum((x - m) ** 2 for x in vals) / len(vals))


def main():
    out = Path("E:/Desktop/codex/output")
    lambda0 = 2.5e-9
    hs = 1.8e-3
    sf = 3.2e3
    toff0 = solve_toff(lambda0, hs, sf)
    he = hs + sf * toff0
    params = {
        "lambda0": lambda0,
        "hs": hs,
        "sf": sf,
        "toff0": toff0,
        "he": he,
        "alpha": hs / he,
        "ri": 0.5e-3,
        "il_avg": 10.0,
        "duty": 0.1,
        "tsw": 1.0e-6,
    }

    channel_rows = channel_validation(params)
    fr_rows = frequency_response_validation(params)
    mem_fr_rows = memory_kernel_frequency_validation(params)
    noise = noise_validation(params)

    channel_path = out / "iqcot_iek_channel_validation.csv"
    with channel_path.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(channel_rows[0].keys()))
        w.writeheader()
        w.writerows(channel_rows)

    fr_path = out / "iqcot_iek_frequency_response_validation.csv"
    with fr_path.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(fr_rows[0].keys()))
        w.writeheader()
        w.writerows(fr_rows)

    mem_fr_path = out / "iqcot_iek_memory_kernel_frequency_response_validation.csv"
    with mem_fr_path.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(mem_fr_rows[0].keys()))
        w.writeheader()
        w.writerows(mem_fr_rows)

    print("IEK-IQCOT small-signal validation")
    print(f"Toff0={toff0:.6e}s, He={he:.6e}, alpha=Hs/He={params['alpha']:.6f}")
    print(f"CHANNEL_CSV={channel_path}")
    print(f"FREQ_RESPONSE_CSV={fr_path}")
    print(f"MEMORY_KERNEL_FREQ_RESPONSE_CSV={mem_fr_path}")
    print("Noise validation:")
    for k, v in noise.items():
        print(f"{k}={v:.6e}")
    print("Selected frequency response rows:")
    for r in fr_rows[:3] + fr_rows[-2:]:
        print(
            f"w/pi={r['omega_over_pi']:.2f}, "
            f"tau_amp_sim={r['tau_amp_ns_sim']:.4f}ns, "
            f"tau_amp_err={r['tau_amp_error_pct']:.3f}%, "
            f"duty_amp_sim={r['duty_amp_sim']:.4e}, "
            f"duty_amp_err={r['duty_amp_error_pct']:.3f}%"
        )
    print("Selected memory-kernel frequency response rows:")
    for r in mem_fr_rows[:3] + mem_fr_rows[-2:]:
        print(
            f"w/pi={r['omega_over_pi']:.2f}, "
            f"tau_amp_sim={r['tau_amp_ns_sim']:.4f}ns, "
            f"tau_amp_err={r['tau_amp_error_pct']:.3f}%, "
            f"duty_amp_sim={r['duty_amp_sim']:.4e}, "
            f"duty_amp_err={r['duty_amp_error_pct']:.3f}%"
        )


if __name__ == "__main__":
    main()
