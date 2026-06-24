import csv
import importlib.util
import math
from pathlib import Path


def load_nominal_model():
    path = Path("E:/Desktop/codex/output/iqcot_multiphase_iek_modal_study.py")
    spec = importlib.util.spec_from_file_location("mpiek_nominal", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.MultiPhaseAreaBuck(n=4)


def mean(vals):
    return sum(vals) / len(vals)


def rms_about_mean(vals):
    m = mean(vals)
    return math.sqrt(sum((x - m) ** 2 for x in vals) / len(vals))


def pkpk(vals):
    return max(vals) - min(vals)


def dc_currents_from_dcr(r_vals, vin, duty_vals, iout):
    conductance = sum(1.0 / r for r in r_vals)
    vout = (vin * sum(d / r for d, r in zip(duty_vals, r_vals)) - iout) / conductance
    currents = [(d * vin - vout) / r for d, r in zip(duty_vals, r_vals)]
    return vout, currents


def equal_current_trim_for_dcr(r_vals, vin, tsw, iref):
    r_mean = mean(r_vals)
    return [tsw * iref * (r - r_mean) / vin for r in r_vals]


class MismatchedAreaBuck:
    def __init__(self, nominal, r_scale=None, l_scale=None, ri_scale=None, max_step=30e-9):
        self.n = nominal.n
        self.vin = nominal.vin
        self.iout = nominal.iout
        self.c = nominal.c
        self.vref = nominal.vref
        self.tsw_ph = nominal.tsw_ph
        self.tg = nominal.tg
        self.ton = nominal.ton
        self.tw = nominal.tw
        self.vc = nominal.vc
        self.vc_run = nominal.vc
        self.lambda_phase = nominal.lambda_phase
        self.max_step = max_step
        r_scale = r_scale or [1.0] * self.n
        l_scale = l_scale or [1.0] * self.n
        ri_scale = ri_scale or [1.0] * self.n
        self.r = [nominal.r * s for s in r_scale]
        self.l = [nominal.l * s for s in l_scale]
        self.ri = [nominal.ri * s for s in ri_scale]
        self.state = [nominal.iph] * self.n + [nominal.vref]

    def deriv(self, y, s_vec):
        v = y[-1]
        dy = []
        for j in range(self.n):
            dy.append((s_vec[j] * self.vin - v - self.r[j] * y[j]) / self.l[j])
        dy.append((sum(y[:self.n]) - self.iout) / self.c)
        return dy

    def h_phase(self, y, phase):
        return self.vc_run - self.ri[phase] * y[phase]

    def rk4_step(self, y, area, i_int, v_int, dt, s_vec, area_phase, collect):
        def aug_deriv(yy):
            dy = self.deriv(yy, s_vec)
            da = 0.0 if area_phase is None else self.h_phase(yy, area_phase)
            di = yy[:self.n] if collect else [0.0] * self.n
            dv = yy[-1] if collect else 0.0
            return dy, da, di, dv

        k1, a1, i1, v1 = aug_deriv(y)
        y2 = [yy + 0.5 * dt * kk for yy, kk in zip(y, k1)]
        k2, a2, i2, v2 = aug_deriv(y2)
        y3 = [yy + 0.5 * dt * kk for yy, kk in zip(y, k2)]
        k3, a3, i3, v3 = aug_deriv(y3)
        y4 = [yy + dt * kk for yy, kk in zip(y, k3)]
        k4, a4, i4, v4 = aug_deriv(y4)

        yn = [
            yy + dt * (u1 + 2.0 * u2 + 2.0 * u3 + u4) / 6.0
            for yy, u1, u2, u3, u4 in zip(y, k1, k2, k3, k4)
        ]
        an = area + dt * (a1 + 2.0 * a2 + 2.0 * a3 + a4) / 6.0
        if collect:
            for j in range(self.n):
                i_int[j] += dt * (i1[j] + 2.0 * i2[j] + 2.0 * i3[j] + i4[j]) / 6.0
            v_int += dt * (v1 + 2.0 * v2 + 2.0 * v3 + v4) / 6.0
        return yn, an, i_int, v_int

    def integrate(self, y0, duration, s_vec, area_phase=None, collect=False):
        if duration <= 0.0:
            return list(y0), 0.0, [0.0] * self.n, 0.0
        steps = max(1, int(math.ceil(duration / self.max_step)))
        dt = duration / steps
        y = list(y0)
        area = 0.0
        i_int = [0.0] * self.n
        v_int = 0.0
        for _ in range(steps):
            y, area, i_int, v_int = self.rk4_step(
                y, area, i_int, v_int, dt, s_vec, area_phase, collect
            )
        return y, area, i_int, v_int

    def solve_wait(self, start, phase, lam, guess):
        off = [0.0] * self.n
        t = max(1e-12, guess)
        end = None
        for _ in range(8):
            end, area, _, _ = self.integrate(start, t, off, phase, False)
            err = area - lam
            if abs(err) < 1e-19:
                return t, end
            slope = max(self.h_phase(end, phase), 1e-9)
            nxt = t - err / slope
            if nxt <= 0.0 or nxt > 4.0 * self.tg:
                break
            if abs(nxt - t) < 1e-15:
                return nxt, end
            t = nxt

        lo, hi = 0.0, max(guess, self.tw)
        _, area_hi, _, _ = self.integrate(start, hi, off, phase, False)
        while area_hi < lam:
            hi *= 1.6
            if hi > 8.0 * self.tg:
                raise RuntimeError("area event did not bracket within the allowed wait window")
            _, area_hi, _, _ = self.integrate(start, hi, off, phase, False)
        for _ in range(42):
            mid = 0.5 * (lo + hi)
            _, area_mid, _, _ = self.integrate(start, mid, off, phase, False)
            if area_mid < lam:
                lo = mid
            else:
                hi = mid
        wait = 0.5 * (lo + hi)
        end, _, _, _ = self.integrate(start, wait, off, phase, False)
        return wait, end

    def simulate(
        self,
        n_events,
        ton_offset,
        lambda_offset=None,
        burn=3000,
        regulate_vout=True,
        vc_ki=5.0e-5,
    ):
        lambda_offset = lambda_offset or (lambda k, q: 0.0)
        y = list(self.state)
        self.vc_run = self.vc
        i_int = [0.0] * self.n
        v_int = 0.0
        vc_int = 0.0
        total_time = 0.0
        waits = []
        wait_by_phase = [[] for _ in range(self.n)]
        guess = self.tw
        for k in range(n_events):
            p = k % self.n
            q = (p + 1) % self.n
            ton = max(1e-12, self.ton + ton_offset(k, p))
            s_on = [0.0] * self.n
            s_on[p] = 1.0
            y_on, _, int_on, vint_on = self.integrate(y, ton, s_on, None, k >= burn)
            lam = self.lambda_phase + lambda_offset(k, q)
            wait, _ = self.solve_wait(y_on, q, lam, guess)
            y_off, _, int_off, vint_off = self.integrate(
                y_on, wait, [0.0] * self.n, None, k >= burn
            )
            y = y_off
            if regulate_vout:
                self.vc_run += vc_ki * (self.vref - y[-1])
                self.vc_run = max(1.0e-3, min(40.0e-3, self.vc_run))
            guess = wait
            if k >= burn:
                for j in range(self.n):
                    i_int[j] += int_on[j] + int_off[j]
                v_int += vint_on + vint_off
                vc_int += self.vc_run * (ton + wait)
                total_time += ton + wait
                waits.append(wait)
                wait_by_phase[q].append(wait)
        avg_i = [x / total_time for x in i_int]
        avg_v = v_int / total_time
        mean_wait_by_phase = [mean(x) for x in wait_by_phase]
        return {
            "avg_i": avg_i,
            "avg_v": avg_v,
            "avg_vc": vc_int / total_time,
            "mean_period": total_time / max(1, len(waits)),
            "event_wait_pkpk": pkpk(waits),
            "event_wait_rms": rms_about_mean(waits),
            "mean_wait_by_phase": mean_wait_by_phase,
            "mean_wait_phase_pkpk": pkpk(mean_wait_by_phase),
        }


def format_vec(vals, scale=1.0, nd=6):
    return " ".join(f"{v * scale:.{nd}g}" for v in vals)


def summarize_run(case, label, result, r_vals, vin):
    avg_i = result["avg_i"]
    eff_duty = mean(avg_i) * 0.0
    # Estimate the common duty from the output voltage and weighted conduction drops.
    eff_duty = mean([(result["avg_v"] + r * i) / vin for r, i in zip(r_vals, avg_i)])
    _, algebra_i_eff = dc_currents_from_dcr(r_vals, vin, [eff_duty] * len(r_vals), sum(avg_i))
    return {
        "case": case,
        "actuator": label,
        "avg_vout_V": result["avg_v"],
        "avg_vc_mV": result["avg_vc"] * 1e3,
        "estimated_common_duty": eff_duty,
        "avg_phase_current_A": format_vec(avg_i),
        "current_pkpk_A": pkpk(avg_i),
        "current_rms_A": rms_about_mean(avg_i),
        "event_wait_pkpk_ns": result["event_wait_pkpk"] * 1e9,
        "event_wait_rms_ns": result["event_wait_rms"] * 1e9,
        "mean_wait_phase_pkpk_ns": result["mean_wait_phase_pkpk"] * 1e9,
        "mean_wait_by_phase_ns": format_vec(result["mean_wait_by_phase"], 1e9),
        "algebra_current_pkpk_at_eff_duty_A": pkpk(algebra_i_eff),
        "dyn_vs_algebra_current_pkpk_error_pct": (
            (pkpk(avg_i) / pkpk(algebra_i_eff) - 1.0) * 100.0
            if pkpk(algebra_i_eff) > 1e-12 else 0.0
        ),
    }


def run_case(nominal, name, r_scale, ri_scale=None):
    model = MismatchedAreaBuck(nominal, r_scale=r_scale, ri_scale=ri_scale)
    r_vals = model.r
    full_trim = equal_current_trim_for_dcr(r_vals, model.vin, model.tsw_ph, nominal.iph)
    limited_01 = [max(-0.10e-9, min(0.10e-9, x)) for x in full_trim]
    limited_02 = [max(-0.20e-9, min(0.20e-9, x)) for x in full_trim]
    for trim in (limited_01, limited_02):
        m = mean(trim)
        for j in range(len(trim)):
            trim[j] -= m

    lambda_pattern = [(r - mean(r_vals)) / mean(r_vals) for r in r_vals]
    lambda_amp = 8.0e-13

    runs = [
        ("no_trim", lambda k, p: 0.0, lambda k, q: 0.0),
        ("lambda_diff_only_8e-13_scaled_to_DCR", lambda k, p: 0.0,
         lambda k, q, pat=lambda_pattern: lambda_amp * pat[q]),
        ("analytic_full_ton_trim", lambda k, p, t=full_trim: t[p], lambda k, q: 0.0),
        ("limited_ton_trim_0p10ns", lambda k, p, t=limited_01: t[p], lambda k, q: 0.0),
        ("limited_ton_trim_0p20ns", lambda k, p, t=limited_02: t[p], lambda k, q: 0.0),
    ]
    rows = []
    for label, ton_func, lam_func in runs:
        res = model.simulate(3500, ton_func, lam_func, burn=1500)
        row = summarize_run(name, label, res, r_vals, model.vin)
        row["r_scale"] = format_vec(r_scale, nd=5)
        row["ri_scale"] = format_vec(ri_scale or [1.0] * model.n, nd=5)
        row["required_full_ton_trim_ns"] = format_vec(full_trim, 1e9)
        row["required_full_ton_trim_pkpk_ns"] = pkpk(full_trim) * 1e9
        row["lambda_diff_pattern"] = format_vec(lambda_pattern, nd=5)
        rows.append(row)
    return rows


def convergence_check(nominal):
    rows = []
    r_scale = [0.80, 0.93, 1.07, 1.20]
    for step_ns in [20.0, 10.0, 5.0]:
        model = MismatchedAreaBuck(nominal, r_scale=r_scale, max_step=step_ns * 1e-9)
        res = model.simulate(1600, lambda k, p: 0.0, burn=600)
        rows.append({
            "max_step_ns": step_ns,
            "avg_phase_current_A": format_vec(res["avg_i"]),
            "current_pkpk_A": pkpk(res["avg_i"]),
            "avg_vout_V": res["avg_v"],
            "event_wait_pkpk_ns": res["event_wait_pkpk"] * 1e9,
        })
    return rows


def main():
    out = Path("E:/Desktop/codex/output")
    nominal = load_nominal_model()
    cases = [
        ("strong_monotonic_DCR_pm20pct", [0.80, 0.93, 1.07, 1.20], None),
        ("alternating_DCR_pm10pct", [0.90, 1.10, 0.90, 1.10], None),
        ("one_phase_high_DCR20pct", [1.20, 0.933333, 0.933333, 0.933333], None),
        ("strong_DCR_pm20pct_Ri_pm10pct", [0.80, 0.93, 1.07, 1.20], [0.90, 0.97, 1.03, 1.10]),
    ]
    rows = []
    for name, r_scale, ri_scale in cases:
        rows.extend(run_case(nominal, name, r_scale, ri_scale))

    path = out / "iqcot_multiphase_mismatch_dynamic_validation.csv"
    with path.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)

    conv = convergence_check(nominal)
    conv_path = out / "iqcot_multiphase_mismatch_rk_convergence.csv"
    with conv_path.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(conv[0].keys()))
        writer.writeheader()
        writer.writerows(conv)

    no_trim = [r for r in rows if r["actuator"] == "no_trim"]
    full = [r for r in rows if r["actuator"] == "analytic_full_ton_trim"]
    lambda_only = [r for r in rows if r["actuator"].startswith("lambda_diff")]
    print("Mismatched multiphase dynamic IQCOT event validation")
    print(f"CSV={path}")
    print(f"CONVERGENCE_CSV={conv_path}")
    print(
        "No-trim dynamic current imbalance range: "
        f"{min(float(r['current_pkpk_A']) for r in no_trim):.3f} A to "
        f"{max(float(r['current_pkpk_A']) for r in no_trim):.3f} A"
    )
    print(
        "Full analytic Ton-trim residual range: "
        f"{min(float(r['current_pkpk_A']) for r in full):.3f} A to "
        f"{max(float(r['current_pkpk_A']) for r in full):.3f} A"
    )
    print(
        "Lambda-diff-only current imbalance range: "
        f"{min(float(r['current_pkpk_A']) for r in lambda_only):.3f} A to "
        f"{max(float(r['current_pkpk_A']) for r in lambda_only):.3f} A"
    )
    for r in conv:
        print(
            f"RK max_step={r['max_step_ns']:.0f} ns: "
            f"Ipkpk={r['current_pkpk_A']:.6f} A, "
            f"Vout={r['avg_vout_V']:.6f} V"
        )


if __name__ == "__main__":
    main()
