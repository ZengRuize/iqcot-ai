import csv
import math
import random
from dataclasses import dataclass
from pathlib import Path


@dataclass
class Case:
    name: str
    rho: float = 0.0
    detection_delay: float = 0.0
    sigma_area: float = 0.0
    kp_vc: float = 0.08
    ki_vc: float = 250.0


def load_current(t: float) -> float:
    # Single-phase equivalent load step: 10 A -> 15 A -> 10 A.
    if 0.25e-3 <= t < 0.55e-3:
        return 15.0
    return 10.0


def simulate(case: Case, seed: int = 3):
    random.seed(seed)

    # Single-phase idealized Buck/IQCOT parameters. These are not a device
    # design; they are chosen to make the event dynamics clear and comparable
    # to the v0027 phase-scale numbers.
    vin = 12.0
    vref = 1.0
    fsw = 500e3
    tsw = 1.0 / fsw
    ton = (vref / vin) * tsw * 1.02
    l = 200e-9
    c = 1.8e-3
    dcr = 1.5e-3
    ri = 0.5e-3

    # Choose a nominal steady event shape: h starts around Hs and increases
    # during off-time as current decays.
    toff_nom = tsw - ton
    iph = 10.0
    dil = (vin - vref) * ton / l
    i_off_start = iph + 0.5 * dil
    hs_target = 1.5e-3
    vc0 = ri * i_off_start + hs_target
    sf_nom = ri * vref / l
    lambda0 = hs_target * toff_nom + 0.5 * sf_nom * toff_nom**2
    lambda_case = lambda0 * math.exp(case.rho)

    dt = 2e-9
    t_end = 0.80e-3
    steps = int(t_end / dt)

    i = iph
    v = vref
    ierr_int = 0.0
    mode_on = True
    on_timer = 0.0
    acc = 0.0
    pending_delay = None
    threshold = lambda_case + random.gauss(0.0, case.sigma_area)

    events = []
    records = []
    duty_periods = []
    last_event_time = 0.0
    last_on_time = ton

    for n in range(steps):
        t = n * dt
        iload = load_current(t)

        # A simple voltage-loop proxy for VC. This is not the thesis
        # contribution; it just lets load steps modulate the event frequency.
        verr = vref - v
        ierr_int += verr * dt
        vc = vc0 + case.kp_vc * verr + case.ki_vc * ierr_int
        vc = max(ri * 0.0 + 0.2e-3, min(vc, 40e-3))

        if mode_on:
            sw_v = vin
            on_timer += dt
            if on_timer >= ton:
                mode_on = False
                on_timer = 0.0
                acc = 0.0
                pending_delay = None
        else:
            sw_v = 0.0
            h = vc - ri * i
            acc += h * dt
            if pending_delay is None and acc >= threshold:
                pending_delay = case.detection_delay
            if pending_delay is not None:
                pending_delay -= dt
                if pending_delay <= 0.0:
                    period = t - last_event_time if last_event_time > 0 else math.nan
                    if last_event_time > 0 and period > 0:
                        duty_periods.append(last_on_time / period)
                    events.append((t, period, acc, threshold, vc, i, v))
                    last_event_time = t
                    last_on_time = ton
                    threshold = lambda_case + random.gauss(0.0, case.sigma_area)
                    mode_on = True
                    on_timer = 0.0
                    acc = 0.0
                    pending_delay = None

        # Power stage. ESR omitted in state equation; DCR included.
        di = (sw_v - v - dcr * i) / l
        dv = (i - iload) / c
        i += di * dt
        v += dv * dt

        if n % 50 == 0:
            records.append((t, v, i, iload, vc, 1.0 if mode_on else 0.0, acc))

    return {
        "case": case,
        "params": {
            "vin": vin,
            "vref": vref,
            "fsw": fsw,
            "ton": ton,
            "toff_nom": toff_nom,
            "lambda0": lambda0,
            "lambda_case": lambda_case,
            "vc0": vc0,
            "ri": ri,
            "l": l,
            "c": c,
            "dt": dt,
        },
        "records": records,
        "events": events,
        "duties": duty_periods,
    }


def metrics(sim):
    rec = sim["records"]
    events = sim["events"]
    duties = sim["duties"]

    # Analyze around the high-load interval after immediate edge settling.
    high = [r for r in rec if 0.28e-3 <= r[0] < 0.55e-3]
    pre = [r for r in rec if 0.18e-3 <= r[0] < 0.24e-3]
    post = [r for r in rec if 0.58e-3 <= r[0] < 0.72e-3]
    all_after = [r for r in rec if r[0] >= 0.18e-3]

    def pp(vals):
        return max(vals) - min(vals) if vals else math.nan

    periods = [e[1] for e in events if not math.isnan(e[1]) and e[0] >= 0.18e-3]
    pre_periods = [e[1] for e in events if not math.isnan(e[1]) and 0.18e-3 <= e[0] < 0.24e-3]
    high_periods = [e[1] for e in events if not math.isnan(e[1]) and 0.34e-3 <= e[0] < 0.52e-3]
    post_periods = [e[1] for e in events if not math.isnan(e[1]) and 0.62e-3 <= e[0] < 0.76e-3]

    v_all = [r[1] for r in all_after]
    v_high = [r[1] for r in high]
    v_pre = [r[1] for r in pre]
    v_post = [r[1] for r in post]

    return {
        "case": sim["case"].name,
        "rho": sim["case"].rho,
        "detection_delay_ns": sim["case"].detection_delay * 1e9,
        "sigma_area": sim["case"].sigma_area,
        "v_min_after_mV": (min(v_all) - 1.0) * 1e3,
        "v_max_after_mV": (max(v_all) - 1.0) * 1e3,
        "v_pp_high_mV": pp(v_high) * 1e3,
        "v_mean_pre_V": sum(v_pre) / len(v_pre) if v_pre else math.nan,
        "v_mean_high_V": sum(v_high) / len(v_high) if v_high else math.nan,
        "v_mean_post_V": sum(v_post) / len(v_post) if v_post else math.nan,
        "period_mean_us": (sum(periods) / len(periods)) * 1e6 if periods else math.nan,
        "period_std_ns": pstdev(periods) * 1e9 if len(periods) > 1 else math.nan,
        "pre_period_mean_us": (sum(pre_periods) / len(pre_periods)) * 1e6 if pre_periods else math.nan,
        "pre_period_std_ns": pstdev(pre_periods) * 1e9 if len(pre_periods) > 1 else math.nan,
        "high_period_mean_us": (sum(high_periods) / len(high_periods)) * 1e6 if high_periods else math.nan,
        "high_period_std_ns": pstdev(high_periods) * 1e9 if len(high_periods) > 1 else math.nan,
        "post_period_mean_us": (sum(post_periods) / len(post_periods)) * 1e6 if post_periods else math.nan,
        "post_period_std_ns": pstdev(post_periods) * 1e9 if len(post_periods) > 1 else math.nan,
        "duty_mean": sum(duties) / len(duties) if duties else math.nan,
        "duty_std": pstdev(duties) if len(duties) > 1 else math.nan,
        "event_count": len(events),
    }


def pstdev(vals):
    if not vals:
        return math.nan
    m = sum(vals) / len(vals)
    return math.sqrt(sum((x - m) ** 2 for x in vals) / len(vals))


def main():
    out_dir = Path("E:/Desktop/codex/output")
    cases = [
        Case("nominal"),
        Case("rho_plus_2pct", rho=0.02),
        Case("rho_minus_2pct", rho=-0.02),
        Case("delay_40ns", detection_delay=40e-9),
        Case("area_noise", sigma_area=8e-12),
        Case("noise_delay", detection_delay=40e-9, sigma_area=8e-12),
    ]

    summaries = []
    for c in cases:
        sim = simulate(c)
        summaries.append(metrics(sim))
        # Save one decimated waveform per case.
        with (out_dir / f"iqcot_ideal_dynamic_{c.name}_waveform.csv").open("w", newline="") as f:
            w = csv.writer(f)
            w.writerow(["t_s", "vout_V", "iL_A", "iload_A", "vc_V", "on", "area_acc"])
            w.writerows(sim["records"])

    summary_path = out_dir / "iqcot_ideal_dynamic_area_event_summary.csv"
    with summary_path.open("w", newline="") as f:
        fieldnames = list(summaries[0].keys())
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        w.writerows(summaries)

    print(f"SUMMARY={summary_path}")
    for s in summaries:
        print(
            f"{s['case']}: v_min={s['v_min_after_mV']:.3f} mV, "
            f"v_max={s['v_max_after_mV']:.3f} mV, "
            f"pre_std={s['pre_period_std_ns']:.3f} ns, "
            f"high_std={s['high_period_std_ns']:.3f} ns, "
            f"post_std={s['post_period_std_ns']:.3f} ns, "
            f"duty_std={s['duty_std']:.3e}, events={s['event_count']}"
        )


if __name__ == "__main__":
    main()
