import csv
import cmath
import math
from pathlib import Path


def cclean(x):
    return x.real if abs(x.imag) < 1e-12 else x


def m2_add(a, b):
    return [[a[0][0] + b[0][0], a[0][1] + b[0][1]],
            [a[1][0] + b[1][0], a[1][1] + b[1][1]]]


def m2_sub(a, b):
    return [[a[0][0] - b[0][0], a[0][1] - b[0][1]],
            [a[1][0] - b[1][0], a[1][1] - b[1][1]]]


def m2_mul(a, b):
    return [
        [a[0][0] * b[0][0] + a[0][1] * b[1][0],
         a[0][0] * b[0][1] + a[0][1] * b[1][1]],
        [a[1][0] * b[0][0] + a[1][1] * b[1][0],
         a[1][0] * b[0][1] + a[1][1] * b[1][1]],
    ]


def m2_v(a, x):
    return [a[0][0] * x[0] + a[0][1] * x[1],
            a[1][0] * x[0] + a[1][1] * x[1]]


def v_add(a, b):
    return [a[0] + b[0], a[1] + b[1]]


def v_sub(a, b):
    return [a[0] - b[0], a[1] - b[1]]


def v_scale(s, x):
    return [s * x[0], s * x[1]]


def dot(c, x):
    return c[0] * x[0] + c[1] * x[1]


def m2_inv(a):
    det = a[0][0] * a[1][1] - a[0][1] * a[1][0]
    return [[a[1][1] / det, -a[0][1] / det],
            [-a[1][0] / det, a[0][0] / det]]


def outer(u, v):
    return [[u[0] * v[0], u[0] * v[1]],
            [u[1] * v[0], u[1] * v[1]]]


def expm2(a, t):
    tr2 = 0.5 * (a[0][0] + a[1][1])
    b00 = a[0][0] - tr2
    b01 = a[0][1]
    b10 = a[1][0]
    b11 = a[1][1] - tr2
    delta = cmath.sqrt(0.25 * (a[0][0] - a[1][1]) ** 2 + a[0][1] * a[1][0])
    em = cmath.exp(tr2 * t)
    if abs(delta) < 1e-30:
        s_over_d = t
    else:
        s_over_d = cmath.sinh(delta * t) / delta
    ch = cmath.cosh(delta * t)
    return [
        [cclean(em * (ch + s_over_d * b00)), cclean(em * s_over_d * b01)],
        [cclean(em * s_over_d * b10), cclean(em * (ch + s_over_d * b11))],
    ]


def solve2(a, b):
    return m2_v(m2_inv(a), b)


def row_m2(c, a):
    return [c[0] * a[0][0] + c[1] * a[1][0],
            c[0] * a[0][1] + c[1] * a[1][1]]


def row_v(c, x):
    return c[0] * x[0] + c[1] * x[1]


def pstdev(vals):
    m = sum(vals) / len(vals)
    return math.sqrt(sum((x - m) ** 2 for x in vals) / len(vals))


def fit_sine(x, omega, start=0):
    # Fit x[k] = a*sin(w*k) + b*cos(w*k) + c.
    s2 = c2 = sc = sx = cx = ss = cc = nsum = 0.0
    count = 0
    for k in range(start, len(x)):
        s = math.sin(omega * k)
        c = math.cos(omega * k)
        y = x[k]
        s2 += s * s
        c2 += c * c
        sc += s * c
        sx += s * y
        cx += c * y
        ss += s
        cc += c
        nsum += y
        count += 1
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
    amp = math.sqrt(sin_coeff ** 2 + cos_coeff ** 2)
    phase = math.atan2(cos_coeff, sin_coeff)
    return amp, phase, offset


def wrap_phase(x):
    while x > math.pi:
        x -= 2 * math.pi
    while x < -math.pi:
        x += 2 * math.pi
    return x


class BuckAreaEvent:
    def __init__(self):
        self.vin = 12.0
        self.fs = 500e3
        self.tsw = 1.0 / self.fs
        self.ton = (1.0 / self.vin) * self.tsw
        self.toff = self.tsw - self.ton
        self.l = 200e-9
        self.c = 1.8e-3
        self.r = 1.5e-3
        self.iload = 10.0
        self.ri = 0.5e-3
        self.a = [[-self.r / self.l, -1.0 / self.l],
                  [1.0 / self.c, 0.0]]
        self.ainv = m2_inv(self.a)
        self.i2 = [[1.0, 0.0], [0.0, 1.0]]
        self.c_area = [-self.ri, 0.0]
        self.b_on = [self.vin / self.l, -self.iload / self.c]
        self.b_off = [0.0, -self.iload / self.c]

        self.pon = expm2(self.a, self.ton)
        self.poff = expm2(self.a, self.toff)
        self.gon = self.g(self.ton, self.b_on)
        self.goff = self.g(self.toff, self.b_off)
        self.x0 = self.periodic_event_state()
        self.xa0 = self.step(self.x0, self.ton, self.b_on)

        # Pick VC after the steady orbit is known so that the event signal is
        # positive over the off interval.  Lambda is then defined by the orbit.
        self.h_start_target = 1.5e-3
        self.vc = self.ri * self.xa0[0] + self.h_start_target
        self.lambda0 = self.area(self.toff, self.xa0)
        self.h_start = self.h(self.xa0)
        self.xe0 = self.step(self.xa0, self.toff, self.b_off)
        self.h_end = self.h(self.xe0)

    def j(self, t):
        phi = expm2(self.a, t)
        return m2_mul(self.ainv, m2_sub(phi, self.i2))

    def g(self, t, b):
        return m2_v(self.j(t), b)

    def step(self, x, t, b):
        return v_add(m2_v(expm2(self.a, t), x), self.g(t, b))

    def periodic_event_state(self):
        p = m2_mul(self.poff, self.pon)
        rhs = v_add(m2_v(self.poff, self.gon), self.goff)
        return solve2(m2_sub(self.i2, p), rhs)

    def x_ss(self, b):
        return v_scale(-1.0, m2_v(self.ainv, b))

    def integral_x(self, t, xstart, b):
        xss = self.x_ss(b)
        return v_add(v_scale(t, xss), m2_v(self.j(t), v_sub(xstart, xss)))

    def h(self, x):
        return self.vc - self.ri * x[0]

    def area(self, t, xstart):
        ix = self.integral_x(t, xstart, self.b_off)
        return self.vc * t + dot(self.c_area, ix)

    def f_off(self, x):
        return v_add(m2_v(self.a, x), self.b_off)

    def solve_toff(self, xstart, lam, guess=None):
        if guess is None:
            guess = self.toff
        t = max(1e-12, guess)
        for _ in range(20):
            f = self.area(t, xstart) - lam
            hp = self.h(self.step(xstart, t, self.b_off))
            if abs(f) < 1e-18:
                return t
            t_next = t - f / hp
            if t_next <= 0.0 or t_next > 5.0 * self.tsw:
                break
            t = t_next
        lo, hi = 0.0, 5.0 * self.tsw
        while self.area(hi, xstart) < lam:
            hi *= 2.0
        for _ in range(80):
            mid = 0.5 * (lo + hi)
            if self.area(mid, xstart) < lam:
                lo = mid
            else:
                hi = mid
        return 0.5 * (lo + hi)

    def linear_model(self):
        joff = self.j(self.toff)
        m_row = row_m2(self.c_area, joff)
        mpon = row_m2(m_row, self.pon)
        he = self.h_end
        hs = self.h_start
        f_end = self.f_off(self.xe0)
        ct = [-mpon[0] / he, -mpon[1] / he]
        dt = 1.0 / he
        ad_base = m2_mul(self.poff, self.pon)
        ad = m2_add(ad_base, outer(f_end, ct))
        bd = v_scale(dt, f_end)
        return {
            "M": m_row,
            "M_Pon": mpon,
            "He": he,
            "Hs": hs,
            "Ct": ct,
            "Dt": dt,
            "Ad": ad,
            "Bd": bd,
        }

    def period_response(self, omega):
        lm = self.linear_model()
        z = complex(math.cos(omega), math.sin(omega))
        zi_minus_ad = [[z - lm["Ad"][0][0], -lm["Ad"][0][1]],
                       [-lm["Ad"][1][0], z - lm["Ad"][1][1]]]
        xgain = m2_v(m2_inv(zi_minus_ad), lm["Bd"])
        return row_v(lm["Ct"], xgain) + lm["Dt"]

    def kernel_response(self, omega):
        lm = self.linear_model()
        z = complex(math.cos(omega), math.sin(omega))
        gt = self.period_response(omega)
        return (z - 1.0) / gt - (lm["He"] * z - lm["Hs"])

    def nonlinear_sine_response(self, omega, amp_area, n=8192, burn=1024):
        x = [self.x0[0], self.x0[1]]
        periods = []
        duties = []
        for k in range(n):
            xa = self.step(x, self.ton, self.b_on)
            lam = self.lambda0 + amp_area * math.sin(omega * k)
            toff = self.solve_toff(xa, lam, self.toff)
            x = self.step(xa, toff, self.b_off)
            period_hat = toff - self.toff
            periods.append(period_hat)
            duties.append(-self.ton / (self.tsw * self.tsw) * period_hat)
        p_amp, p_phase, _ = fit_sine(periods, omega, burn)
        d_amp, d_phase, _ = fit_sine(duties, omega, burn)
        return p_amp, p_phase, d_amp, d_phase, pstdev(periods[burn:])


def eig2(a):
    tr = a[0][0] + a[1][1]
    det = a[0][0] * a[1][1] - a[0][1] * a[1][0]
    disc = cmath.sqrt(tr * tr - 4.0 * det)
    return ((tr + disc) / 2.0, (tr - disc) / 2.0)


def main():
    out = Path("E:/Desktop/codex/output")
    model = BuckAreaEvent()
    lm = model.linear_model()
    eigs = eig2(lm["Ad"])
    amp_area = 2.0e-11
    duty = model.ton / model.tsw

    summary = {
        "Vin": model.vin,
        "Iload": model.iload,
        "L": model.l,
        "C": model.c,
        "DCR": model.r,
        "Ri": model.ri,
        "fsw": model.fs,
        "Ton_ns": model.ton * 1e9,
        "Toff_ns": model.toff * 1e9,
        "Duty": duty,
        "x_event_i_A": model.x0[0],
        "x_event_v_V": model.x0[1],
        "x_off_start_i_A": model.xa0[0],
        "x_off_start_v_V": model.xa0[1],
        "VC_mV": model.vc * 1e3,
        "Lambda": model.lambda0,
        "Hs_mV": lm["Hs"] * 1e3,
        "He_mV": lm["He"] * 1e3,
        "K1_required_mV": (lm["Hs"] - lm["He"]) * 1e3,
        "eig1": eigs[0],
        "eig2": eigs[1],
    }

    summary_path = out / "iqcot_dynamic_iek_kernel_summary.csv"
    with summary_path.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(summary.keys()))
        w.writeheader()
        w.writerow(summary)

    rows = []
    kernel_rows = []
    validation_omegas = [
        0.01 * math.pi, 0.02 * math.pi, 0.05 * math.pi,
        0.10 * math.pi, 0.20 * math.pi, 0.35 * math.pi,
        0.50 * math.pi, 0.70 * math.pi,
    ]
    kernel_omegas = [
        0.001 * math.pi, 0.002 * math.pi, 0.005 * math.pi,
        0.01 * math.pi, 0.02 * math.pi, 0.05 * math.pi,
        0.10 * math.pi, 0.20 * math.pi, 0.35 * math.pi,
        0.50 * math.pi, 0.70 * math.pi,
    ]
    for omega in validation_omegas:
        gt = model.period_response(omega)
        gd = -duty / model.tsw * gt
        p_amp, p_phase, d_amp, d_phase, p_std = model.nonlinear_sine_response(omega, amp_area)
        p_th = abs(gt) * amp_area
        d_th = abs(gd) * amp_area
        p_phase_th = math.atan2(gt.imag, gt.real)
        d_phase_th = math.atan2(gd.imag, gd.real)
        rows.append({
            "omega_over_pi": omega / math.pi,
            "period_amp_ns_sim": p_amp * 1e9,
            "period_amp_ns_theory": p_th * 1e9,
            "period_amp_error_pct": (p_amp / p_th - 1.0) * 100.0,
            "period_phase_error_deg": wrap_phase(p_phase - p_phase_th) * 180.0 / math.pi,
            "duty_amp_sim": d_amp,
            "duty_amp_theory": d_th,
            "duty_amp_error_pct": (d_amp / d_th - 1.0) * 100.0,
            "duty_phase_error_deg": wrap_phase(d_phase - d_phase_th) * 180.0 / math.pi,
            "period_std_ns_after_burn": p_std * 1e9,
        })

    for omega in kernel_omegas:
        kresp = model.kernel_response(omega)
        kernel_rows.append({
            "omega_over_pi": omega / math.pi,
            "K_real_mV": kresp.real * 1e3,
            "K_imag_mV": kresp.imag * 1e3,
            "K_abs_mV": abs(kresp) * 1e3,
            "K_phase_deg": math.atan2(kresp.imag, kresp.real) * 180.0 / math.pi,
            "K1_required_mV": (lm["Hs"] - lm["He"]) * 1e3,
        })

    fr_path = out / "iqcot_dynamic_iek_nonlinear_frequency_validation.csv"
    with fr_path.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)

    kernel_path = out / "iqcot_dynamic_iek_kernel_samples.csv"
    with kernel_path.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(kernel_rows[0].keys()))
        w.writeheader()
        w.writerows(kernel_rows)

    print("Dynamic IEK kernel identification")
    print(f"SUMMARY_CSV={summary_path}")
    print(f"NONLINEAR_FREQ_CSV={fr_path}")
    print(f"KERNEL_CSV={kernel_path}")
    print(f"Ton={model.ton*1e9:.3f} ns, Toff={model.toff*1e9:.3f} ns, D={duty:.6f}")
    print(f"Lambda={model.lambda0:.6e}, Hs={lm['Hs']*1e3:.4f} mV, He={lm['He']*1e3:.4f} mV")
    print(f"Time-shift condition requires K(1)=Hs-He={(lm['Hs']-lm['He'])*1e3:.4f} mV")
    print(f"Ad eigenvalues: {eigs[0]:.6g}, {eigs[1]:.6g}")
    print("Selected nonlinear validation rows:")
    for r in rows[:3] + rows[-2:]:
        print(
            f"w/pi={r['omega_over_pi']:.2f}, "
            f"period_amp={r['period_amp_ns_sim']:.5f} ns, "
            f"period_err={r['period_amp_error_pct']:.4f}%, "
            f"duty_err={r['duty_amp_error_pct']:.4f}%, "
            f"phase_err={r['period_phase_error_deg']:.4f} deg"
        )


if __name__ == "__main__":
    main()
