import csv
import importlib.util
import math
import random
from pathlib import Path


OUT = Path("E:/Desktop/codex/output")
FIG = OUT / "figures"


def load_model_module():
    path = OUT / "iqcot_multiphase_iek_modal_study.py"
    spec = importlib.util.spec_from_file_location("mpiek_mc", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def mean(vals):
    return sum(vals) / len(vals) if vals else 0.0


def rms_about_mean(vals):
    if not vals:
        return 0.0
    m = mean(vals)
    return math.sqrt(sum((x - m) ** 2 for x in vals) / len(vals))


def pkpk(vals):
    return max(vals) - min(vals) if vals else 0.0


def percentile(vals, q):
    if not vals:
        return 0.0
    x = sorted(vals)
    idx = (len(x) - 1) * q
    lo = math.floor(idx)
    hi = math.ceil(idx)
    if lo == hi:
        return x[lo]
    return x[lo] * (hi - idx) + x[hi] * (idx - lo)


def phase_projection(vals, pattern):
    denom = sum(v * v for v in pattern)
    if denom == 0:
        return 0.0
    m = mean(vals)
    return sum((x - m) * p for x, p in zip(vals, pattern)) / denom


def simulate_random_case(model, case, seed):
    rng = random.Random(seed)
    state = list(model.state)
    off = [0.0] * model.n
    int_currents = [0.0] * model.n
    total_time = 0.0
    waits = []
    periods = []
    vouts = []
    current_snapshots = []

    q_lambda = (2.0 * model.lambda_phase) / (2 ** case["area_bits"])
    q_ton = case["ton_resolution_ps"] * 1e-12
    tclk = case["detect_clock_ns"] * 1e-9
    sigma_delay = case["comp_delay_sigma_ns"] * 1e-9

    for k in range(case["events"]):
        p = k % model.n
        q = (p + 1) % model.n
        ton_err = rng.uniform(-0.5 * q_ton, 0.5 * q_ton)
        ton_k = max(1e-12, model.ton + ton_err)
        s_on = [0.0] * model.n
        s_on[p] = 1.0

        int_on = model.segment_current_integrals(state, ton_k, s_on)
        start = model.segment(state, ton_k, s_on)

        lambda_err = rng.uniform(-0.5 * q_lambda, 0.5 * q_lambda)
        wait_cross = model.solve_wait(start, q, model.lambda_phase + lambda_err, model.tw)
        detect_err = rng.uniform(-0.5 * tclk, 0.5 * tclk)
        delay_err = rng.gauss(0.0, sigma_delay) if sigma_delay > 0.0 else 0.0
        wait_actual = max(1e-12, wait_cross + detect_err + delay_err)

        int_wait = model.segment_current_integrals(start, wait_actual, off)
        state = model.segment(start, wait_actual, off)

        if k >= case["burn"]:
            period = ton_k + wait_actual
            for j in range(model.n):
                int_currents[j] += int_on[j] + int_wait[j]
            total_time += period
            waits.append(wait_actual - model.tw)
            periods.append(period - model.tg)
            vouts.append(state[1])
            current_snapshots.append(model.phase_currents(state))

    avg_i = [x / total_time for x in int_currents]
    current_rms_snapshot = mean([rms_about_mean(x) for x in current_snapshots]) if current_snapshots else 0.0
    m2 = [1.0, -1.0, 1.0, -1.0]
    return {
        "seed": seed,
        "area_bits": case["area_bits"],
        "detect_clock_ns": case["detect_clock_ns"],
        "ton_resolution_ps": case["ton_resolution_ps"],
        "comp_delay_sigma_ns": case["comp_delay_sigma_ns"],
        "events": case["events"],
        "burn": case["burn"],
        "q_lambda": q_lambda,
        "q_lambda_over_nominal": q_lambda / model.lambda_phase,
        "wait_jitter_rms_ns": rms_about_mean(waits) * 1e9,
        "wait_jitter_pkpk_ns": pkpk(waits) * 1e9,
        "phase_spacing_std_ns": rms_about_mean(periods) * 1e9,
        "phase_spacing_pkpk_ns": pkpk(periods) * 1e9,
        "avg_phase_current_A": " ".join(f"{v:.9g}" for v in avg_i),
        "current_share_rms_mA": rms_about_mean(avg_i) * 1e3,
        "current_share_pkpk_mA": pkpk(avg_i) * 1e3,
        "current_snapshot_rms_mA": current_rms_snapshot * 1e3,
        "current_m2_projection_mA": phase_projection(avg_i, m2) * 1e3,
        "vout_event_rms_mV": rms_about_mean(vouts) * 1e3,
        "vout_event_pkpk_mV": pkpk(vouts) * 1e3,
    }


def write_csv(path, rows):
    if not rows:
        raise RuntimeError(f"no rows for {path}")
    with path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)


def aggregate(rows):
    keys = ["area_bits", "detect_clock_ns", "ton_resolution_ps", "comp_delay_sigma_ns"]
    metrics = [
        "wait_jitter_rms_ns",
        "phase_spacing_std_ns",
        "current_share_rms_mA",
        "current_share_pkpk_mA",
        "current_snapshot_rms_mA",
        "vout_event_rms_mV",
        "vout_event_pkpk_mV",
    ]
    groups = {}
    for row in rows:
        key = tuple(row[k] for k in keys)
        groups.setdefault(key, []).append(row)
    out = []
    for key, vals in sorted(groups.items()):
        item = {k: v for k, v in zip(keys, key)}
        item["seeds"] = len(vals)
        for metric in metrics:
            x = [float(v[metric]) for v in vals]
            item[f"{metric}_mean"] = mean(x)
            item[f"{metric}_p95"] = percentile(x, 0.95)
            item[f"{metric}_max"] = max(x)
        out.append(item)
    return out


def write_report(detail_rows, summary_rows, model):
    path = OUT / "iqcot_pis_iek_monte_carlo_budget_report.md"
    pick = [
        r for r in summary_rows
        if int(r["area_bits"]) == 12
        and abs(float(r["detect_clock_ns"]) - 1.0) < 1e-12
        and int(r["ton_resolution_ps"]) == 10
        and abs(float(r["comp_delay_sigma_ns"]) - 0.5) < 1e-12
    ][0]
    worst = max(summary_rows, key=lambda r: float(r["phase_spacing_std_ns_p95"]))
    best = min(summary_rows, key=lambda r: float(r["phase_spacing_std_ns_p95"]))
    with path.open("w", encoding="utf-8") as f:
        f.write("# PIS-IEK 数字量化与检测延迟 Monte Carlo 预算\n\n")
        f.write("## 数据规模\n\n")
        f.write(f"- 解析事件模型：四相 IQCOT，Lambda={model.lambda_phase:.6e} V*s。\n")
        f.write(f"- 随机样本行数：`{len(detail_rows)}`。\n")
        f.write(f"- 聚合工况行数：`{len(summary_rows)}`。\n")
        f.write("- 扫描维度：area bits = {10,12,14,16}，检测时钟 = {0.5,1,2,5} ns，Ton 分辨率 = {5,10,20,50} ps，比较器随机延迟 sigma = {0,0.5,1,2} ns。\n\n")
        f.write("## 代表性结果\n\n")
        f.write(
            "- 12 bit 面积阈值、1 ns 检测时钟、10 ps Ton 分辨率、0.5 ns 比较器延迟 sigma 下："
            f"wait jitter rms 均值 `{float(pick['wait_jitter_rms_ns_mean']):.4f} ns`，"
            f"phase-spacing std 均值 `{float(pick['phase_spacing_std_ns_mean']):.4f} ns`，"
            f"电流均分 rms 均值 `{float(pick['current_share_rms_mA_mean']):.4f} mA`。\n"
        )
        f.write(
            f"- 最差聚合工况：bits={worst['area_bits']}，clock={worst['detect_clock_ns']} ns，"
            f"Ton={worst['ton_resolution_ps']} ps，delay sigma={worst['comp_delay_sigma_ns']} ns，"
            f"phase-spacing std p95=`{float(worst['phase_spacing_std_ns_p95']):.4f} ns`。\n"
        )
        f.write(
            f"- 最好聚合工况：bits={best['area_bits']}，clock={best['detect_clock_ns']} ns，"
            f"Ton={best['ton_resolution_ps']} ps，delay sigma={best['comp_delay_sigma_ns']} ns，"
            f"phase-spacing std p95=`{float(best['phase_spacing_std_ns_p95']):.4f} ns`。\n\n"
        )
        f.write("## 论文解释\n\n")
        f.write(
            "该 Monte Carlo 不是替代 Simulink 开关电路仿真，而是把 PIS-IEK 的局部灵敏度转化为数字实现预算。"
            "它回答的问题是：面积阈值位宽、检测时钟、Ton 分辨率和比较器随机延迟共同存在时，事件 wait jitter、"
            "相位间隔质量和均流误差处在什么量级。该结果可作为后续 AI/优化调参的约束边界。\n"
        )
    return path


def make_figure(summary_rows):
    try:
        import matplotlib.pyplot as plt
    except Exception:
        return None

    FIG.mkdir(exist_ok=True)
    path = FIG / "fig19_pis_iek_monte_carlo_budget.png"
    fig, axes = plt.subplots(1, 2, figsize=(11, 4.4))

    filt = [
        r for r in summary_rows
        if int(r["ton_resolution_ps"]) == 10
        and abs(float(r["comp_delay_sigma_ns"]) - 0.5) < 1e-12
    ]
    for clock in [0.5, 1.0, 2.0, 5.0]:
        rows = sorted([r for r in filt if abs(float(r["detect_clock_ns"]) - clock) < 1e-12], key=lambda r: int(r["area_bits"]))
        axes[0].plot(
            [int(r["area_bits"]) for r in rows],
            [float(r["phase_spacing_std_ns_p95"]) for r in rows],
            marker="o",
            label=f"{clock:g} ns clock",
        )
    axes[0].set_xlabel("area threshold bits")
    axes[0].set_ylabel("phase-spacing std p95 (ns)")
    axes[0].grid(True, alpha=0.3)
    axes[0].legend(fontsize=8)

    filt = [
        r for r in summary_rows
        if int(r["area_bits"]) == 12
        and abs(float(r["detect_clock_ns"]) - 1.0) < 1e-12
    ]
    for delay in [0.0, 0.5, 1.0, 2.0]:
        rows = sorted([r for r in filt if abs(float(r["comp_delay_sigma_ns"]) - delay) < 1e-12], key=lambda r: int(r["ton_resolution_ps"]))
        axes[1].plot(
            [int(r["ton_resolution_ps"]) for r in rows],
            [float(r["current_snapshot_rms_mA_p95"]) for r in rows],
            marker="s",
            label=f"{delay:g} ns delay sigma",
        )
    axes[1].set_xlabel("Ton resolution (ps)")
    axes[1].set_ylabel("instantaneous current rms p95 (mA)")
    axes[1].grid(True, alpha=0.3)
    axes[1].legend(fontsize=8)

    fig.tight_layout()
    fig.savefig(path, dpi=180)
    plt.close(fig)
    return path


def main():
    mod = load_model_module()
    model = mod.MultiPhaseAreaBuck(n=4)
    detail_rows = []
    seeds = range(16)
    for bits in [10, 12, 14, 16]:
        for clock_ns in [0.5, 1.0, 2.0, 5.0]:
            for ton_ps in [5, 10, 20, 50]:
                for delay_sigma_ns in [0.0, 0.5, 1.0, 2.0]:
                    case = {
                        "area_bits": bits,
                        "detect_clock_ns": clock_ns,
                        "ton_resolution_ps": ton_ps,
                        "comp_delay_sigma_ns": delay_sigma_ns,
                        "events": 720,
                        "burn": 120,
                    }
                    for seed in seeds:
                        detail_rows.append(simulate_random_case(model, case, seed))

    summary_rows = aggregate(detail_rows)
    detail_path = OUT / "iqcot_pis_iek_monte_carlo_detail.csv"
    summary_path = OUT / "iqcot_pis_iek_monte_carlo_summary.csv"
    write_csv(detail_path, detail_rows)
    write_csv(summary_path, summary_rows)
    report_path = write_report(detail_rows, summary_rows, model)
    fig_path = make_figure(summary_rows)

    print("PIS-IEK Monte Carlo budget complete")
    print(f"DETAIL={detail_path}")
    print(f"SUMMARY={summary_path}")
    print(f"REPORT={report_path}")
    if fig_path:
        print(f"FIGURE={fig_path}")
    print(f"DETAIL_ROWS={len(detail_rows)} SUMMARY_ROWS={len(summary_rows)}")


if __name__ == "__main__":
    main()
