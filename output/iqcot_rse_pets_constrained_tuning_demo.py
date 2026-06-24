import csv
import importlib.util
from pathlib import Path


def load_dynamic_module():
    path = Path("E:/Desktop/codex/output/iqcot_ideal_dynamic_area_event_sim.py")
    spec = importlib.util.spec_from_file_location("dyn_iqcot", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def score(row):
    # Simple scalar objective for demonstration. Lower is better.
    # It intentionally trades transient voltage deviation and event jitter.
    return (
        1.0 * abs(row["v_min_after_mV"])
        + 0.7 * abs(row["v_max_after_mV"])
        + 0.6 * row["high_period_std_ns"]
        + 0.3 * row["pre_period_std_ns"]
    )


def unconstrained_score(row):
    # What a naive tuner might do: focus almost only on transient voltage
    # deviation and ignore event jitter / robustness.
    return abs(row["v_min_after_mV"]) + 0.4 * abs(row["v_max_after_mV"])


def feasible(row):
    return (
        row["v_min_after_mV"] >= -22.0
        and row["v_max_after_mV"] <= 12.0
        and row["pre_period_std_ns"] <= 2.2
        and row["high_period_std_ns"] <= 4.0
    )


def main():
    mod = load_dynamic_module()
    out_dir = Path("E:/Desktop/codex/output")

    rows = []
    # A tiny grid standing in for a future AI/surrogate optimizer.
    # Variables:
    #   rho controls Lambda = CT*VTH/gm
    #   kp_vc controls how strongly voltage error modulates VC
    #   sigma_area represents digital/threshold noise budget
    for rho in [-0.08, -0.04, -0.02, 0.0, 0.02, 0.04, 0.08]:
        for kp in [0.04, 0.08, 0.12, 0.16, 0.24, 0.32]:
            for sigma_area in [0.0, 8e-12]:
                case = mod.Case(
                    name=f"rho{rho:+.2f}_kp{kp:.2f}_sig{sigma_area:.0e}",
                    rho=rho,
                    kp_vc=kp,
                    sigma_area=sigma_area,
                )
                sim = mod.simulate(case, seed=13)
                row = mod.metrics(sim)
                row["kp_vc"] = kp
                row["objective"] = score(row)
                row["unconstrained_objective"] = unconstrained_score(row)
                row["feasible"] = feasible(row)
                rows.append(row)

    all_path = out_dir / "iqcot_rse_pets_constrained_tuning_grid.csv"
    with all_path.open("w", newline="") as f:
        fieldnames = list(rows[0].keys())
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    # Aggregate by tunable parameters. sigma_area is treated as an uncertainty
    # scenario, not as an AI decision variable.
    groups = {}
    for r in rows:
        key = (r["rho"], r["kp_vc"])
        groups.setdefault(key, []).append(r)

    agg_rows = []
    for (rho, kp), rs in groups.items():
        nominal = min(rs, key=lambda r: r["sigma_area"])
        worst_pre = max(r["pre_period_std_ns"] for r in rs)
        worst_high = max(r["high_period_std_ns"] for r in rs)
        worst_vmin = min(r["v_min_after_mV"] for r in rs)
        worst_vmax = max(r["v_max_after_mV"] for r in rs)
        robust_feasible = (
            worst_vmin >= -22.0
            and worst_vmax <= 12.0
            and worst_pre <= 2.2
            and worst_high <= 4.0
        )
        agg_rows.append({
            "rho": rho,
            "kp_vc": kp,
            "nominal_unconstrained_objective": nominal["unconstrained_objective"],
            "robust_objective": (
                abs(worst_vmin)
                + 0.4 * abs(worst_vmax)
                + 0.6 * worst_high
                + 0.3 * worst_pre
            ),
            "worst_vmin_mV": worst_vmin,
            "worst_vmax_mV": worst_vmax,
            "worst_pre_std_ns": worst_pre,
            "worst_high_std_ns": worst_high,
            "robust_feasible": robust_feasible,
        })

    agg_path = out_dir / "iqcot_rse_pets_constrained_tuning_robust_grid.csv"
    with agg_path.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(agg_rows[0].keys()))
        writer.writeheader()
        writer.writerows(agg_rows)

    unconstrained = min(agg_rows, key=lambda r: r["nominal_unconstrained_objective"])
    feasible_rows = [r for r in agg_rows if r["robust_feasible"]]
    constrained = min(feasible_rows, key=lambda r: r["robust_objective"]) if feasible_rows else None

    print(f"GRID={all_path}")
    print(f"ROBUST_GRID={agg_path}")
    print("Unconstrained best:")
    print_agg_summary(unconstrained)
    if constrained:
        print("Constrained best:")
        print_agg_summary(constrained)
    else:
        print("No feasible point under current constraints.")


def print_summary(row):
    print(
        f"case={row['case']}, rho={row['rho']:+.3f}, kp={row['kp_vc']:.3f}, "
        f"sigmaA={row['sigma_area']:.2e}, obj={row['objective']:.3f}, "
        f"feasible={row['feasible']}, vmin={row['v_min_after_mV']:.3f}mV, "
        f"vmax={row['v_max_after_mV']:.3f}mV, preStd={row['pre_period_std_ns']:.3f}ns, "
        f"highStd={row['high_period_std_ns']:.3f}ns"
    )


def print_agg_summary(row):
    print(
        f"rho={row['rho']:+.3f}, kp={row['kp_vc']:.3f}, "
        f"nomObj={row['nominal_unconstrained_objective']:.3f}, "
        f"robObj={row['robust_objective']:.3f}, "
        f"robust_feasible={row['robust_feasible']}, "
        f"worst_vmin={row['worst_vmin_mV']:.3f}mV, "
        f"worst_vmax={row['worst_vmax_mV']:.3f}mV, "
        f"worstPreStd={row['worst_pre_std_ns']:.3f}ns, "
        f"worstHighStd={row['worst_high_std_ns']:.3f}ns"
    )


if __name__ == "__main__":
    main()
