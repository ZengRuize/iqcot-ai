import math


def q_from_vth(vin, vo, fsw, l_value, ct, gm, ri, vth):
    tsw = 1.0 / fsw
    duty = vo / vin
    psi = ct * l_value * vth / (gm * ri * vo * tsw * tsw)
    zeta = psi - duty / 2.0
    if zeta <= 0:
        return math.nan, psi, duty, zeta
    return 1.0 / (math.pi * zeta), psi, duty, zeta


def constant_q_vth(vin, vo, fsw, l_value, ct, gm, ri, q_target):
    tsw = 1.0 / fsw
    duty = vo / vin
    alpha = gm * ri * tsw * tsw / (math.pi * q_target * ct * l_value)
    beta = gm * ri * tsw * tsw / (2.0 * ct * l_value)
    return (alpha + beta * duty) * vo, alpha, beta


def q_sensitivity(psi, duty):
    zeta = psi - duty / 2.0
    return {
        "dlnQ_dlnVTH": -psi / zeta,
        "dlnQ_dlngm": psi / zeta,
        "dlnQ_dlnRi": psi / zeta,
        "dlnQ_dlnL": -psi / zeta,
        "dlnQ_dD": 1.0 / (2.0 * zeta),
    }


def main():
    vo = 1.2
    fsw = 1e6
    l_value = 250e-9
    ct = 0.2e-9
    gm = 0.1
    ri = 1e-3
    q_target = 0.7

    vins = [5, 8, 12, 16, 20]
    _, alpha, beta = constant_q_vth(vins[0], vo, fsw, l_value, ct, gm, ri, q_target)
    print(f"alpha={alpha:.6g}, beta={beta:.6g}, q_target={q_target}")
    print("Vin  D      Q_fixed_1p2V  VTH_constQ  Q_constQ")

    for vin in vins:
        q_fixed, _, duty, _ = q_from_vth(vin, vo, fsw, l_value, ct, gm, ri, 1.2)
        vth_cq, _, _ = constant_q_vth(vin, vo, fsw, l_value, ct, gm, ri, q_target)
        q_cq, _, _, _ = q_from_vth(vin, vo, fsw, l_value, ct, gm, ri, vth_cq)
        print(f"{vin:>3}  {duty:.3f}  {q_fixed:>12.4g}  {vth_cq:>10.4g}  {q_cq:>8.4g}")

    vin = 12
    vth_cq, _, _ = constant_q_vth(vin, vo, fsw, l_value, ct, gm, ri, q_target)
    q_value, psi, duty, zeta = q_from_vth(vin, vo, fsw, l_value, ct, gm, ri, vth_cq)
    print("\nSensitivity at Vin=12 V")
    print(f"D={duty:.4f}, psi={psi:.4f}, zeta={zeta:.4f}, Q={q_value:.4f}")
    for key, value in q_sensitivity(psi, duty).items():
        print(f"{key}={value:.4f}")


if __name__ == "__main__":
    main()
