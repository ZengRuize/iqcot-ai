import math


def nominal_values():
    # Representative IQCOT/VRM values inspired by the local literature corpus.
    vo = 1.2
    vin = 12.0
    fsw = 1.0e6
    tsw = 1.0 / fsw
    ton = vo / vin * tsw
    toff = tsw - ton
    l_value = 120e-9
    ri = 1.0e-3
    ct = 120e-12
    # Choose VTH near Q2 ~= 0.7 for the nominal operating point.
    # This also keeps Hs positive, which is required by the event-pole argument.
    vth = 4.2
    gm = 100e-3
    iavg = 25.0
    return vo, vin, fsw, tsw, ton, toff, l_value, ri, ct, vth, gm, iavg


def compute_pets_terms(td):
    vo, vin, fsw, tsw, ton, toff, l_value, ri, ct, vth, gm, iavg = nominal_values()
    lam = ct * vth / gm
    sf = ri * vo / l_value
    hs = lam / toff - 0.5 * sf * toff
    he = lam / toff + 0.5 * sf * toff
    alpha = hs / he
    d = ton / tsw
    delay_area = he * td + 0.5 * sf * td * td
    psi = lam * l_value / (ri * vo * tsw * tsw)
    psi_eff = psi + l_value * delay_area / (ri * vo * tsw * tsw)
    q2 = 1.0 / (math.pi * (psi - d / 2.0))
    q2_eff = 1.0 / (math.pi * (psi_eff - d / 2.0))
    return {
        "lambda": lam,
        "sf": sf,
        "hs": hs,
        "he": he,
        "alpha": alpha,
        "d": d,
        "psi": psi,
        "psi_eff": psi_eff,
        "q2": q2,
        "q2_eff": q2_eff,
    }


def parameter_timing_sensitivity():
    vo, vin, fsw, tsw, ton, toff, l_value, ri, ct, vth, gm, iavg = nominal_values()
    base = compute_pets_terms(0.0)
    lam = base["lambda"]
    he = base["he"]
    integral_il = iavg * toff
    one_percent = 0.01

    # rho = dln(CT) + dln(VTH) - dln(gm)
    dt_vth_plus_1pct = lam * one_percent / he
    dt_gm_plus_1pct = -lam * one_percent / he
    dt_ri_plus_1pct = ri * integral_il * one_percent / he
    return dt_vth_plus_1pct, dt_gm_plus_1pct, dt_ri_plus_1pct


if __name__ == "__main__":
    base = compute_pets_terms(0.0)
    print("Nominal PETS-IQCOT terms")
    print(f"Lambda = {base['lambda']:.4e} V*s")
    print(f"Sf     = {base['sf']:.4e} V/s")
    print(f"Hs     = {base['hs']:.4e} V")
    print(f"He     = {base['he']:.4e} V")
    print(f"alpha  = Hs/He = {base['alpha']:.4f}")
    print(f"psi    = {base['psi']:.4f}")
    print(f"Q2     = {base['q2']:.4f}")
    print()

    print("Delay-corrected Q2")
    for td_ns in [0, 5, 10, 20, 50]:
        terms = compute_pets_terms(td_ns * 1e-9)
        print(
            f"Td={td_ns:>2} ns  psi_eff={terms['psi_eff']:.4f}  "
            f"Q2_eff={terms['q2_eff']:.4f}"
        )
    print()

    dt_vth, dt_gm, dt_ri = parameter_timing_sensitivity()
    print("Predicted one-cycle trigger delay for +1% parameter perturbation")
    print(f"+1% VTH -> Delta t = {dt_vth*1e9:.3f} ns")
    print(f"+1% gm  -> Delta t = {dt_gm*1e9:.3f} ns")
    print(f"+1% Ri  -> Delta t = {dt_ri*1e9:.3f} ns")
