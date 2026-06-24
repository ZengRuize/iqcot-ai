import math
import random
from statistics import mean, pstdev


def solve_toff(lambda_area, hs, sf):
    # 0.5*sf*T^2 + hs*T - lambda = 0
    disc = hs * hs + 2.0 * sf * lambda_area
    return (-hs + math.sqrt(disc)) / sf


def area(hs, sf, t):
    return hs * t + 0.5 * sf * t * t


def validate_parameter_sensitivity():
    # Normalized IQCOT off-time event:
    # integral_0^Toff h(t)dt = Lambda, h(t)=Hs+Sf*t.
    # This validates the boundary result delta_t ~= delta_Lambda/He
    # and the independent Ri channel represented as an area perturbation.
    lambda0 = 2.5e-9
    hs = 1.8e-3
    sf = 3.2e3
    toff0 = solve_toff(lambda0, hs, sf)
    he = hs + sf * toff0

    rows = []
    for rho in [-0.05, -0.02, -0.01, 0.01, 0.02, 0.05]:
        lam = lambda0 * math.exp(rho)
        toff = solve_toff(lam, hs, sf)
        exact = toff - toff0
        pred = lambda0 * rho / he
        rows.append(("rho", rho, exact, pred, (pred / exact - 1.0) if exact else 0.0))

    # Ri channel: A_Ri = -Ri*kappa*integral(IL)dt.
    # In the linear event equation, tau shift is +(-A_Ri)/He depending on sign convention.
    # Here we inject an equivalent area perturbation directly.
    il_avg = 10.0
    ri = 0.5e-3
    integral_il = il_avg * toff0
    for kappa in [-0.05, -0.02, 0.02, 0.05]:
        a_ri = -ri * kappa * integral_il
        # Event equation: A_nom(t) + A_ri - Lambda = 0
        # Equivalent threshold lambda_eff = lambda0 - A_ri.
        toff = solve_toff(lambda0 - a_ri, hs, sf)
        exact = toff - toff0
        pred = -a_ri / he
        rows.append(("kappa", kappa, exact, pred, (pred / exact - 1.0) if exact else 0.0))

    return toff0, he, rows


def validate_noise_jitter(samples=200_000, seed=11):
    random.seed(seed)
    lambda0 = 2.5e-9
    hs = 1.8e-3
    sf = 3.2e3
    toff0 = solve_toff(lambda0, hs, sf)
    he = hs + sf * toff0

    sigma_a = 8.0e-12
    exact_dt = []
    pred_dt = []
    for _ in range(samples):
        w = random.gauss(0.0, sigma_a)
        # Event with area noise on RHS: A(t)-Lambda = w -> A(t)=Lambda+w.
        t = solve_toff(lambda0 + w, hs, sf)
        exact_dt.append(t - toff0)
        pred_dt.append(w / he)

    return {
        "sigma_A": sigma_a,
        "toff0": toff0,
        "He": he,
        "sigma_tau_exact": pstdev(exact_dt),
        "sigma_tau_pred": sigma_a / he,
        "mean_error_s": mean([e - p for e, p in zip(exact_dt, pred_dt)]),
        "std_error_s": pstdev([e - p for e, p in zip(exact_dt, pred_dt)]),
    }


def main():
    toff0, he, rows = validate_parameter_sensitivity()
    print("Ideal IQCOT area-event validation")
    print(f"Toff0 = {toff0:.6e} s, He = {he:.6e}")
    print()
    print("Small-signal parameter sensitivity:")
    print("channel,value,exact_dt_s,pred_dt_s,relative_prediction_error")
    for row in rows:
        print(f"{row[0]},{row[1]:.6g},{row[2]:.6e},{row[3]:.6e},{row[4]:.3%}")

    print()
    noise = validate_noise_jitter()
    print("Area-noise jitter:")
    for k, v in noise.items():
        print(f"{k} = {v:.6e}")


if __name__ == "__main__":
    main()
