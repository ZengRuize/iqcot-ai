import csv
import math
from pathlib import Path


def cclean(x):
    return x.real if abs(x.imag) < 1e-12 else x


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


def m2_inv(a):
    det = a[0][0] * a[1][1] - a[0][1] * a[1][0]
    return [[a[1][1] / det, -a[0][1] / det],
            [-a[1][0] / det, a[0][0] / det]]


def expm2(a, t):
    import cmath
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


def fit_sine(x, omega, start=0):
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
    return math.sqrt(sin_coeff ** 2 + cos_coeff ** 2), math.atan2(cos_coeff, sin_coeff), offset


def pstdev(vals):
    m = sum(vals) / len(vals)
    return math.sqrt(sum((v - m) ** 2 for v in vals) / len(vals))


class MultiPhaseAreaBuck:
    def __init__(self, n=4):
        self.n = n
        self.vin = 12.0
        self.vref = 1.0
        self.iout = 40.0
        self.iph = self.iout / n
        self.fsw_ph = 500e3
        self.tsw_ph = 1.0 / self.fsw_ph
        self.tg = self.tsw_ph / n
        self.l = 200e-9
        self.c = 7.2e-3
        self.r = 1.5e-3
        self.ri = 0.5e-3
        self.dreq = (self.vref + self.iph * self.r) / self.vin
        self.ton = self.dreq * self.tsw_ph
        self.tw = self.tg - self.ton
        self.a2 = [[-self.r / self.l, -1.0 / self.l],
                   [self.n / self.c, 0.0]]
        self.a2_inv = m2_inv(self.a2)
        self.i2 = [[1.0, 0.0], [0.0, 1.0]]
        self.state = self.periodic_state()
        self.vc, self.lambda_phase, self.hs_phase, self.he_phase = self.define_area_thresholds()

    def common_b(self, s_avg):
        return [s_avg * self.vin / self.l, -self.iout / self.c]

    def j2(self, t):
        return m2_mul(self.a2_inv, m2_sub(expm2(self.a2, t), self.i2))

    def step_common(self, x, t, s_avg):
        phi = expm2(self.a2, t)
        g = m2_v(self.j2(t), self.common_b(s_avg))
        return v_add(m2_v(phi, x), g)

    def integral_common_iavg(self, x, t, s_avg):
        b = self.common_b(s_avg)
        xss = v_scale(-1.0, m2_v(self.a2_inv, b))
        integ = v_add(v_scale(t, xss), m2_v(self.j2(t), v_sub(x, xss)))
        return integ[0]

    def step_diff(self, d, t, s_vec):
        s_avg = sum(s_vec) / self.n
        ea = math.exp(-self.r / self.l * t)
        out = []
        for dj, sj in zip(d, s_vec):
            forcing = (sj - s_avg) * self.vin / self.l
            dss = forcing * self.l / self.r
            out.append(dss + (dj - dss) * ea)
        mean = sum(out) / self.n
        return [v - mean for v in out]

    def integral_diff(self, d, t, s_vec):
        s_avg = sum(s_vec) / self.n
        ea = math.exp(-self.r / self.l * t)
        out = []
        for dj, sj in zip(d, s_vec):
            forcing = (sj - s_avg) * self.vin / self.l
            dss = forcing * self.l / self.r
            out.append(dss * t + (dj - dss) * (ea - 1.0) / (-self.r / self.l))
        mean = sum(out) / self.n
        return [v - mean for v in out]

    def segment(self, state, t, s_vec):
        x2, d = state[:2], state[2:]
        s_avg = sum(s_vec) / self.n
        x2n = self.step_common(x2, t, s_avg)
        dn = self.step_diff(d, t, s_vec)
        return x2n + dn

    def phase_currents(self, state):
        iavg = state[0]
        return [iavg + d for d in state[2:]]

    def segment_area_phase(self, state, t, s_vec, phase, vc=None):
        if vc is None:
            vc = self.vc
        x2, d = state[:2], state[2:]
        s_avg = sum(s_vec) / self.n
        int_iavg = self.integral_common_iavg(x2, t, s_avg)
        int_d = self.integral_diff(d, t, s_vec)[phase]
        return vc * t - self.ri * (int_iavg + int_d)

    def segment_current_integrals(self, state, t, s_vec):
        x2, d = state[:2], state[2:]
        s_avg = sum(s_vec) / self.n
        int_iavg = self.integral_common_iavg(x2, t, s_avg)
        int_d = self.integral_diff(d, t, s_vec)
        return [int_iavg + int_d[j] for j in range(self.n)]

    def h_phase(self, state, phase, vc=None):
        if vc is None:
            vc = self.vc
        return vc - self.ri * self.phase_currents(state)[phase]

    def periodic_state(self):
        state = [self.iph, self.vref] + [0.0] * self.n
        for _ in range(20000):
            for p in range(self.n):
                s_on = [0.0] * self.n
                s_on[p] = 1.0
                state = self.segment(state, self.ton, s_on)
                state = self.segment(state, self.tw, [0.0] * self.n)
        return state

    def define_area_thresholds(self):
        hs_target = 1.5e-3
        vcs = []
        lambdas = []
        hs = []
        he = []
        state = list(self.state)
        for p in range(self.n):
            q = (p + 1) % self.n
            s_on = [0.0] * self.n
            s_on[p] = 1.0
            start = self.segment(state, self.ton, s_on)
            vc_q = self.ri * self.phase_currents(start)[q] + hs_target
            area_q = self.segment_area_phase(start, self.tw, [0.0] * self.n, q, vc_q)
            end = self.segment(start, self.tw, [0.0] * self.n)
            vcs.append(vc_q)
            lambdas.append(area_q)
            hs.append(self.h_phase(start, q, vc_q))
            he.append(self.h_phase(end, q, vc_q))
            state = end
        vc = sum(vcs) / len(vcs)
        return vc, sum(lambdas) / len(lambdas), hs, he

    def solve_wait(self, start, phase, lam, guess=None):
        if guess is None:
            guess = self.tw
        t = max(1e-12, guess)
        off = [0.0] * self.n
        for _ in range(20):
            f = self.segment_area_phase(start, t, off, phase) - lam
            end = self.segment(start, t, off)
            hp = self.h_phase(end, phase)
            if abs(f) < 1e-19:
                return t
            nxt = t - f / hp
            if nxt <= 0.0 or nxt > 3.0 * self.tg:
                break
            t = nxt
        lo, hi = 0.0, 3.0 * self.tg
        while self.segment_area_phase(start, hi, off, phase) < lam:
            hi *= 2.0
        for _ in range(70):
            mid = 0.5 * (lo + hi)
            if self.segment_area_phase(start, mid, off, phase) < lam:
                lo = mid
            else:
                hi = mid
        return 0.5 * (lo + hi)

    def run(self, n_events, perturb, initial=None):
        state = list(self.state if initial is None else initial)
        waits = []
        phases = []
        currents = []
        vouts = []
        for k in range(n_events):
            p = k % self.n
            q = (p + 1) % self.n
            s_on = [0.0] * self.n
            s_on[p] = 1.0
            start = self.segment(state, self.ton, s_on)
            lam = self.lambda_phase + perturb(k, q)
            wait = self.solve_wait(start, q, lam)
            state = self.segment(start, wait, [0.0] * self.n)
            waits.append(wait - self.tw)
            phases.append(q)
            currents.append(self.phase_currents(state))
            vouts.append(state[1])
        return waits, phases, currents, vouts

    def run_with_ton_trim(self, n_events, lambda_perturb, ton_trim, burn=2000):
        state = list(self.state)
        waits = []
        phases = []
        currents = []
        int_currents = [0.0] * self.n
        total_time = 0.0
        for k in range(n_events):
            p = k % self.n
            q = (p + 1) % self.n
            ton_k = self.ton + ton_trim(k, p)
            s_on = [0.0] * self.n
            s_on[p] = 1.0
            int_on = self.segment_current_integrals(state, ton_k, s_on)
            start = self.segment(state, ton_k, s_on)
            lam = self.lambda_phase + lambda_perturb(k, q)
            wait = self.solve_wait(start, q, lam, self.tw)
            int_wait = self.segment_current_integrals(start, wait, [0.0] * self.n)
            state = self.segment(start, wait, [0.0] * self.n)
            if k >= burn:
                for j in range(self.n):
                    int_currents[j] += int_on[j] + int_wait[j]
                total_time += ton_k + wait
            waits.append(wait - self.tw)
            phases.append(q)
            currents.append(self.phase_currents(state))
        avg_currents = [x / total_time for x in int_currents]
        return waits, phases, currents, avg_currents


def analyze_common_response(model):
    amp = 4.0e-13
    rows = []
    he_mean = sum(model.he_phase) / model.n
    static_amp = amp / he_mean
    for ratio in [0.005, 0.01, 0.02, 0.05, 0.10, 0.20, 0.35, 0.50, 0.70]:
        omega = ratio * math.pi
        waits, _, _, _ = model.run(
            12000,
            lambda k, q, om=omega: amp * math.sin(om * k),
        )
        sim_amp, sim_phase, _ = fit_sine(waits, omega, 2000)
        rows.append({
            "mode": "common",
            "omega_over_pi": ratio,
            "sim_wait_amp_ns": sim_amp * 1e9,
            "sim_phase_deg": sim_phase * 180.0 / math.pi,
            "static_he_amp_ns": static_amp * 1e9,
            "static_he_amp_error_pct": (static_amp / sim_amp - 1.0) * 100.0,
        })
    return rows


def phase_stats(phases, currents, waits, n, burn=2000):
    sums_i = [0.0] * n
    counts = [0] * n
    sums_w = [0.0] * n
    for ph, cur, w in zip(phases[burn:], currents[burn:], waits[burn:]):
        sums_i[ph] += cur[ph]
        sums_w[ph] += w
        counts[ph] += 1
    mean_i = [sums_i[i] / counts[i] for i in range(n)]
    mean_w = [sums_w[i] / counts[i] for i in range(n)]
    iavg = sum(mean_i) / n
    return {
        "mean_phase_current_A": mean_i,
        "phase_current_dev_A": [x - iavg for x in mean_i],
        "phase_current_rms_mA": math.sqrt(sum((x - iavg) ** 2 for x in mean_i) / n) * 1e3,
        "phase_current_pkpk_mA": (max(mean_i) - min(mean_i)) * 1e3,
        "mean_wait_dev_ns": [x * 1e9 for x in mean_w],
        "wait_pkpk_ns": (max(mean_w) - min(mean_w)) * 1e9,
    }


def analyze_differential_offsets(model):
    patterns = {
        "m1_cos": [math.cos(2.0 * math.pi * q / model.n) for q in range(model.n)],
        "m2_alt": [1.0 if q % 2 == 0 else -1.0 for q in range(model.n)],
        "one_phase": [1.0, -1.0 / 3.0, -1.0 / 3.0, -1.0 / 3.0],
    }
    rows = []
    for name, pat in patterns.items():
        for amp in [1.0e-13, 2.0e-13, 4.0e-13, 8.0e-13]:
            waits, phases, currents, _ = model.run(
                16000,
                lambda k, q, a=amp, p=pat: a * p[q],
            )
            st = phase_stats(phases, currents, waits, model.n)
            rows.append({
                "pattern": name,
                "amp_area": amp,
                "phase_current_rms_mA": st["phase_current_rms_mA"],
                "phase_current_pkpk_mA": st["phase_current_pkpk_mA"],
                "wait_pkpk_ns": st["wait_pkpk_ns"],
                "mean_wait_dev_ns": " ".join(f"{v:.6g}" for v in st["mean_wait_dev_ns"]),
                "phase_current_dev_mA": " ".join(f"{v*1e3:.6g}" for v in st["phase_current_dev_A"]),
            })
    return rows


def analyze_ton_trim_offsets(model):
    patterns = {
        "m1_cos": [math.cos(2.0 * math.pi * q / model.n) for q in range(model.n)],
        "m2_alt": [1.0 if q % 2 == 0 else -1.0 for q in range(model.n)],
        "one_phase": [1.0, -1.0 / 3.0, -1.0 / 3.0, -1.0 / 3.0],
    }
    rows = []
    for name, pat in patterns.items():
        for amp_ton in [0.02e-9, 0.05e-9, 0.10e-9, 0.20e-9, 0.50e-9]:
            waits, phases, currents, avg_i = model.run_with_ton_trim(
                18000,
                lambda k, q: 0.0,
                lambda k, p, a=amp_ton, pattern=pat: a * pattern[p],
            )
            mean_i = sum(avg_i) / model.n
            dev = [x - mean_i for x in avg_i]
            rms = math.sqrt(sum(x * x for x in dev) / model.n)
            rows.append({
                "pattern": name,
                "amp_ton_ns": amp_ton * 1e9,
                "phase_current_rms_mA": rms * 1e3,
                "phase_current_pkpk_mA": (max(avg_i) - min(avg_i)) * 1e3,
                "wait_pkpk_ns": (max(waits[2000:]) - min(waits[2000:])) * 1e9,
                "avg_phase_current_A": " ".join(f"{v:.6g}" for v in avg_i),
                "phase_current_dev_mA": " ".join(f"{v*1e3:.6g}" for v in dev),
                "mA_per_0p1ns_rms": rms * 1e3 / (amp_ton / 0.10e-9),
            })
    return rows


def main():
    out = Path("E:/Desktop/codex/output")
    model = MultiPhaseAreaBuck(n=4)
    common_rows = analyze_common_response(model)
    diff_rows = analyze_differential_offsets(model)
    ton_rows = analyze_ton_trim_offsets(model)

    summary = {
        "N": model.n,
        "Vin": model.vin,
        "Vref": model.vref,
        "Iout": model.iout,
        "Iph": model.iph,
        "L": model.l,
        "C": model.c,
        "DCR": model.r,
        "Ri": model.ri,
        "fsw_phase": model.fsw_ph,
        "Tglobal_ns": model.tg * 1e9,
        "Ton_ns": model.ton * 1e9,
        "Twait_ns": model.tw * 1e9,
        "VC_mV": model.vc * 1e3,
        "Lambda": model.lambda_phase,
        "Hs_mean_mV": sum(model.hs_phase) / model.n * 1e3,
        "He_mean_mV": sum(model.he_phase) / model.n * 1e3,
        "event_state_vout_V": model.state[1],
        "event_phase_currents_A": " ".join(f"{v:.6g}" for v in model.phase_currents(model.state)),
    }

    summary_path = out / "iqcot_multiphase_iek_modal_summary.csv"
    with summary_path.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(summary.keys()))
        w.writeheader()
        w.writerow(summary)

    common_path = out / "iqcot_multiphase_iek_common_response.csv"
    with common_path.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(common_rows[0].keys()))
        w.writeheader()
        w.writerows(common_rows)

    diff_path = out / "iqcot_multiphase_iek_differential_offsets.csv"
    with diff_path.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(diff_rows[0].keys()))
        w.writeheader()
        w.writerows(diff_rows)

    ton_path = out / "iqcot_multiphase_iek_ton_trim_offsets.csv"
    with ton_path.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(ton_rows[0].keys()))
        w.writeheader()
        w.writerows(ton_rows)

    worst_common = max(abs(float(r["static_he_amp_error_pct"])) for r in common_rows)
    best_common = min(abs(float(r["static_he_amp_error_pct"])) for r in common_rows)
    worst_diff = max(diff_rows, key=lambda r: r["phase_current_pkpk_mA"])
    worst_ton = max(ton_rows, key=lambda r: r["phase_current_pkpk_mA"])

    print("Multiphase IEK modal study")
    print(f"SUMMARY_CSV={summary_path}")
    print(f"COMMON_RESPONSE_CSV={common_path}")
    print(f"DIFFERENTIAL_OFFSETS_CSV={diff_path}")
    print(f"TON_TRIM_OFFSETS_CSV={ton_path}")
    print(f"N={model.n}, Ton={model.ton*1e9:.3f} ns, Twait={model.tw*1e9:.3f} ns, VC={model.vc*1e3:.4f} mV")
    print(f"Hs_mean={summary['Hs_mean_mV']:.4f} mV, He_mean={summary['He_mean_mV']:.4f} mV")
    print(f"Static He-only common-mode error range: best={best_common:.2f}%, worst={worst_common:.2f}%")
    print(
        "Worst differential case: "
        f"{worst_diff['pattern']} amp={worst_diff['amp_area']:.2e}, "
        f"I_pkpk={worst_diff['phase_current_pkpk_mA']:.3f} mA, "
        f"wait_pkpk={worst_diff['wait_pkpk_ns']:.4f} ns"
    )
    print(
        "Worst Ton-trim case: "
        f"{worst_ton['pattern']} amp={worst_ton['amp_ton_ns']:.3f} ns, "
        f"I_pkpk={worst_ton['phase_current_pkpk_mA']:.3f} mA, "
        f"wait_pkpk={worst_ton['wait_pkpk_ns']:.4f} ns"
    )


if __name__ == "__main__":
    main()
