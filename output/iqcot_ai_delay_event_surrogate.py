"""Delay-aware AI tuning surrogate for four-phase IQCOT/PIS-IEK.

The experiment is intentionally lightweight: it does not claim to replace the
switching Simulink model.  It maps FPGA AI inference latency to event-domain
delay and tests whether a delay-aware PIS-IEK state representation improves a
low-dimensional parameter tuner under cut-load recovery conditions.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import math
import numpy as np
import pandas as pd


OUT = Path(r"E:/Desktop/codex/output")
FIG = OUT / "figures"
FIG.mkdir(parents=True, exist_ok=True)

EVENT_US = 0.5
HORIZON_EVENTS = 240
SEEDS = 64


@dataclass(frozen=True)
class CutCase:
    name: str
    severity: float
    v0_mV: float
    phi0_ns: float
    i0_mA: float
    skip_bias: int


CUT_CASES = [
    CutCase("40A_to_20A", 0.50, 2.5, 50.0, 310.0, 0),
    CutCase("40A_to_10A", 0.75, 5.0, 105.0, 310.0, 1),
    CutCase("40A_to_near0A", 1.00, 20.0, 118.0, 610.0, 2),
]

TAU_AI_US = [0.0, 0.5, 1.0, 2.0, 5.0]
UPDATE_US = [2.0, 5.0, 10.0, 20.0]
POLICIES = ["no_ai", "zero_delay_trained", "delay_aware", "delay_aware_projected"]

# State x = [voltage deviation mV, phase-spacing disturbance ns, m2 current imbalance mA].
# The matrices below are a compact, event-domain surrogate calibrated in scale
# from the existing Simulink/PIS-IEK artifacts rather than fitted as a black box.
A_NORMAL = np.array(
    [
        [0.978, 0.0020, 0.0006],
        [-0.020, 0.962, 0.0060],
        [0.018, -0.045, 0.940],
    ],
    dtype=float,
)
A_SKIP = np.array(
    [
        [0.990, 0.0045, 0.0008],
        [0.020, 1.010, 0.0080],
        [0.010, -0.020, 0.970],
    ],
    dtype=float,
)
A_REENTRY = np.array(
    [
        [0.984, -0.0015, 0.0008],
        [-0.070, 0.935, 0.0110],
        [0.025, -0.060, 0.925],
    ],
    dtype=float,
)

# Inputs u = [Lambda_diff in 1e-13 V*s units, Ton_diff in 0.1 ns units].
# Local wait sensitivity gives Lambda_diff -> phase timing, and circuit-level
# finite difference gives Ton_diff -> current sharing as the stronger actuator.
B_NORMAL = np.array(
    [
        [-0.006, 0.018],
        [-0.043, -0.0217],
        [-0.004, -49.4],
    ],
    dtype=float,
)
B_SKIP = 0.45 * B_NORMAL
B_REENTRY = np.array(
    [
        [-0.004, 0.012],
        [-0.036, -0.018],
        [-0.003, -42.0],
    ],
    dtype=float,
)

Q = np.diag([1.0 / 8.0**2, 1.0 / 80.0**2, 1.0 / 450.0**2])
R = np.diag([1.0 / 22.0**2, 1.0 / 4.0**2])
U_MAX = np.array([24.0, 4.0], dtype=float)
PHI_LIMIT_NS = 130.0
I_LIMIT_MA = 900.0
V_LIMIT_MV = 28.0


def choose_mode(x: np.ndarray, cooldown: int) -> tuple[str, int]:
    if cooldown > 0:
        return "reentry", cooldown - 1
    if abs(x[0]) > 12.0 or abs(x[1]) > 100.0:
        return "skip", 5
    return "normal", 0


def matrices_for_mode(mode: str) -> tuple[np.ndarray, np.ndarray]:
    if mode == "skip":
        return A_SKIP, B_SKIP
    if mode == "reentry":
        return A_REENTRY, B_REENTRY
    return A_NORMAL, B_NORMAL


def dlqr_gain(A: np.ndarray, B: np.ndarray) -> np.ndarray:
    P = Q.copy()
    for _ in range(250):
        gain_term = R + B.T @ P @ B
        K = np.linalg.solve(gain_term, B.T @ P @ A)
        P_next = Q + A.T @ P @ (A - B @ K)
        if np.max(np.abs(P_next - P)) < 1e-11:
            P = P_next
            break
        P = P_next
    return np.linalg.solve(R + B.T @ P @ B, B.T @ P @ A)


K0 = dlqr_gain(A_NORMAL, B_NORMAL)


def predict_state(
    x: np.ndarray,
    current_event: int,
    u_current: np.ndarray,
    schedule: dict[int, np.ndarray],
    delay_events: int,
) -> np.ndarray:
    xp = x.copy()
    u = u_current.copy()
    cooldown = 0
    for j in range(delay_events):
        event = current_event + j
        if event in schedule:
            u = schedule[event]
        mode, cooldown = choose_mode(xp, cooldown)
        A, B = matrices_for_mode(mode)
        xp = A @ xp + B @ u
    return xp


def projected_action(u: np.ndarray, x_apply: np.ndarray) -> tuple[np.ndarray, bool]:
    """Project action onto simple PIS-IEK-inspired safety constraints."""

    u_clip = np.clip(u, -U_MAX, U_MAX)
    mode, _ = choose_mode(x_apply, 0)
    A, B = matrices_for_mode(mode)

    # Restrict Ton_diff when current-sharing correction would be too abrupt.
    candidates = [u_clip]
    for scale in np.linspace(0.9, 0.0, 10):
        candidates.append(np.array([u_clip[0], u_clip[1] * scale]))
    for lam_scale in np.linspace(0.8, 0.0, 9):
        candidates.append(np.array([u_clip[0] * lam_scale, 0.0]))

    for cand in candidates:
        x_next = A @ x_apply + B @ cand
        safe = (
            abs(x_next[0]) <= V_LIMIT_MV
            and abs(x_next[1]) <= PHI_LIMIT_NS
            and abs(x_next[2]) <= I_LIMIT_MA
        )
        if safe:
            return cand, not np.allclose(cand, u_clip)
    return np.zeros(2), True


def policy_action(
    policy: str,
    x: np.ndarray,
    current_event: int,
    u_current: np.ndarray,
    schedule: dict[int, np.ndarray],
    delay_events: int,
) -> tuple[np.ndarray, bool]:
    if policy == "no_ai":
        return np.zeros(2), False

    if policy == "zero_delay_trained":
        x_control = x
    else:
        x_control = predict_state(x, current_event, u_current, schedule, delay_events)

    u = -K0 @ x_control
    u = np.clip(u, -U_MAX, U_MAX)

    if policy == "delay_aware_projected":
        return projected_action(u, x_control)
    return u, False


def run_episode(
    case: CutCase,
    tau_us: float,
    update_us: float,
    policy: str,
    seed: int,
) -> dict[str, float | int | str]:
    rng = np.random.default_rng(seed)
    delay_events = int(math.ceil(tau_us / EVENT_US - 1e-12))
    update_events = max(1, int(round(update_us / EVENT_US)))

    x = np.array([case.v0_mV, case.phi0_ns, case.i0_mA], dtype=float)
    x += rng.normal([0.0, 0.0, 0.0], [0.8, 5.0, 35.0])

    u_current = np.zeros(2)
    schedule: dict[int, np.ndarray] = {}
    cooldown = case.skip_bias * 3
    projected_count = 0
    violations = 0
    skip_events = 0
    reward = 0.0
    max_abs_v = abs(x[0])
    max_abs_phi = abs(x[1])
    max_abs_i = abs(x[2])
    total_u2 = 0.0
    settle_event = math.nan
    recovery_start = max(delay_events + update_events, 1)
    tail_cost = 0.0
    tail_count = 0
    tail_phase_abs = 0.0
    tail_current_abs = 0.0

    for k in range(HORIZON_EVENTS):
        if k in schedule:
            u_current = schedule.pop(k)

        if k % update_events == 0:
            u_new, projected = policy_action(policy, x, k, u_current, schedule, delay_events)
            if projected:
                projected_count += 1
            if delay_events == 0:
                u_current = u_new
            else:
                schedule[k + delay_events] = u_new

        u_apply = u_current

        mode, cooldown = choose_mode(x, cooldown)
        if mode == "skip":
            skip_events += 1
        A, B = matrices_for_mode(mode)

        process = rng.normal(
            [0.0, 0.0, 0.0],
            [0.015 + 0.01 * case.severity, 0.08 + 0.08 * case.severity, 0.9 + 0.9 * case.severity],
        )
        x = A @ x + B @ u_apply + process

        max_abs_v = max(max_abs_v, abs(float(x[0])))
        max_abs_phi = max(max_abs_phi, abs(float(x[1])))
        max_abs_i = max(max_abs_i, abs(float(x[2])))

        bad = (
            abs(x[0]) > V_LIMIT_MV
            or abs(x[1]) > PHI_LIMIT_NS
            or abs(x[2]) > I_LIMIT_MA
        )
        violations += int(bad)
        reward -= float(x.T @ Q @ x + u_apply.T @ R @ u_apply + 0.25 * bad)
        total_u2 += float(u_apply.T @ u_apply)
        if k >= recovery_start:
            tail_cost += float(x.T @ Q @ x)
            tail_phase_abs += abs(float(x[1]))
            tail_current_abs += abs(float(x[2]))
            tail_count += 1

        if math.isnan(settle_event):
            if abs(x[0]) < 2.0 and abs(x[1]) < 20.0 and abs(x[2]) < 100.0:
                settle_event = k

    tail_count = max(tail_count, 1)
    return {
        "case": case.name,
        "severity": case.severity,
        "tau_ai_us": tau_us,
        "delay_events": delay_events,
        "update_us": update_us,
        "update_events": update_events,
        "policy": policy,
        "seed": seed,
        "reward": reward,
        "max_abs_v_mV": max_abs_v,
        "max_abs_phase_ns": max_abs_phi,
        "max_abs_i_mA": max_abs_i,
        "violations": violations,
        "skip_events": skip_events,
        "projected_count": projected_count,
        "control_energy": total_u2,
        "tail_state_cost_mean": tail_cost / tail_count,
        "tail_abs_phase_ns_mean": tail_phase_abs / tail_count,
        "tail_abs_i_mA_mean": tail_current_abs / tail_count,
        "settle_us": settle_event * EVENT_US if not math.isnan(settle_event) else math.nan,
        "final_abs_v_mV": abs(float(x[0])),
        "final_abs_phase_ns": abs(float(x[1])),
        "final_abs_i_mA": abs(float(x[2])),
    }


def make_summary(df: pd.DataFrame) -> pd.DataFrame:
    group_cols = ["case", "tau_ai_us", "delay_events", "update_us", "update_events", "policy"]
    agg = df.groupby(group_cols).agg(
        reward_mean=("reward", "mean"),
        reward_std=("reward", "std"),
        max_abs_v_mV_p95=("max_abs_v_mV", lambda s: np.percentile(s, 95)),
        max_abs_phase_ns_p95=("max_abs_phase_ns", lambda s: np.percentile(s, 95)),
        max_abs_i_mA_p95=("max_abs_i_mA", lambda s: np.percentile(s, 95)),
        violations_mean=("violations", "mean"),
        violation_rate=("violations", lambda s: float(np.mean(np.asarray(s) > 0))),
        skip_events_mean=("skip_events", "mean"),
        projected_mean=("projected_count", "mean"),
        settle_us_median=("settle_us", "median"),
        control_energy_mean=("control_energy", "mean"),
        tail_state_cost_mean=("tail_state_cost_mean", "mean"),
        tail_abs_phase_ns_mean=("tail_abs_phase_ns_mean", "mean"),
        tail_abs_i_mA_mean=("tail_abs_i_mA_mean", "mean"),
        final_abs_phase_ns_mean=("final_abs_phase_ns", "mean"),
        final_abs_i_mA_mean=("final_abs_i_mA", "mean"),
    )
    agg = agg.reset_index()

    baseline = agg[agg["policy"] == "zero_delay_trained"][
        ["case", "tau_ai_us", "update_us", "reward_mean", "violations_mean", "max_abs_phase_ns_p95"]
    ].rename(
        columns={
            "reward_mean": "baseline_reward_mean",
            "violations_mean": "baseline_violations_mean",
            "max_abs_phase_ns_p95": "baseline_phase_p95",
        }
    )
    out = agg.merge(baseline, on=["case", "tau_ai_us", "update_us"], how="left")
    out["reward_delta_vs_zero_delay"] = out["reward_mean"] - out["baseline_reward_mean"]
    out["violation_delta_vs_zero_delay"] = out["violations_mean"] - out["baseline_violations_mean"]
    out["phase_p95_delta_vs_zero_delay_ns"] = out["max_abs_phase_ns_p95"] - out["baseline_phase_p95"]
    return out


def df_to_markdown(df: pd.DataFrame, floatfmt: str = ".3f") -> str:
    headers = list(df.columns)
    rows = []
    for _, row in df.iterrows():
        vals = []
        for col in headers:
            val = row[col]
            if isinstance(val, (float, np.floating)):
                vals.append(format(float(val), floatfmt))
            else:
                vals.append(str(val))
        rows.append(vals)

    def esc(text: str) -> str:
        return text.replace("|", "\\|")

    lines = []
    lines.append("| " + " | ".join(esc(h) for h in headers) + " |")
    lines.append("| " + " | ".join("---" for _ in headers) + " |")
    for vals in rows:
        lines.append("| " + " | ".join(esc(v) for v in vals) + " |")
    return "\n".join(lines)


def write_report(summary: pd.DataFrame, detail: pd.DataFrame) -> None:
    focus = summary[
        (summary["policy"].isin(["zero_delay_trained", "delay_aware", "delay_aware_projected"]))
        & (summary["update_us"].isin([5.0, 10.0]))
        & (summary["tau_ai_us"].isin([0.0, 1.0, 2.0, 5.0]))
    ].copy()
    best_rows = (
        focus.sort_values(["case", "tau_ai_us", "update_us", "reward_mean"], ascending=[True, True, True, False])
        .groupby(["case", "tau_ai_us", "update_us"], as_index=False)
        .head(1)
    )

    delay_impact = summary[
        (summary["case"] == "40A_to_near0A")
        & (summary["update_us"] == 5.0)
        & (summary["policy"].isin(["zero_delay_trained", "delay_aware_projected"]))
    ][
        [
            "policy",
            "tau_ai_us",
            "delay_events",
            "reward_mean",
            "violations_mean",
            "max_abs_phase_ns_p95",
            "max_abs_i_mA_p95",
            "tail_abs_phase_ns_mean",
            "tail_abs_i_mA_mean",
            "tail_state_cost_mean",
        ]
    ].sort_values(["tau_ai_us", "policy"])

    lines: list[str] = []
    lines.append("# AI Delay Event-Domain Surrogate Results")
    lines.append("")
    lines.append("## Experiment Scale")
    lines.append("")
    lines.append(f"- Cut-load cases: `{len(CUT_CASES)}`")
    lines.append(f"- AI latency values: `{TAU_AI_US}` us")
    lines.append(f"- Update periods: `{UPDATE_US}` us")
    lines.append(f"- Policies: `{POLICIES}`")
    lines.append(f"- Seeds per cell: `{SEEDS}`")
    lines.append(f"- Total episodes: `{len(detail)}`")
    lines.append(f"- Event period: `{EVENT_US} us`; `tau_AI=5 us` therefore spans `{int(5.0 / EVENT_US)}` IQCOT events.")
    lines.append("")
    lines.append("## Policy Meaning")
    lines.append("")
    lines.append("- `no_ai`: no parameter adaptation.")
    lines.append("- `zero_delay_trained`: controller designed as if the action acted immediately, then deployed with delayed actuation.")
    lines.append("- `delay_aware`: predicts the event-domain state at the action arrival event before choosing `Lambda_diff/Ton_diff`.")
    lines.append("- `delay_aware_projected`: adds PIS-IEK safety projection on voltage, phase-spacing, and current-sharing bounds.")
    lines.append("")
    lines.append("## Representative Near-Zero Cut-Load Slice")
    lines.append("")
    lines.append(df_to_markdown(delay_impact, floatfmt=".3f"))
    lines.append("")
    lines.append("## Best Policy by Case / Delay / Update")
    lines.append("")
    lines.append(
        df_to_markdown(
            best_rows[
            [
                "case",
                "tau_ai_us",
                "update_us",
                "policy",
                "reward_mean",
                "violations_mean",
                "max_abs_phase_ns_p95",
                "max_abs_i_mA_p95",
                "tail_abs_phase_ns_mean",
                "tail_abs_i_mA_mean",
                "tail_state_cost_mean",
            ]
            ],
            floatfmt=".3f",
        )
    )
    lines.append("")
    near0_u5 = summary[(summary["case"] == "40A_to_near0A") & (summary["update_us"] == 5.0)]
    z5 = near0_u5[(near0_u5["tau_ai_us"] == 5.0) & (near0_u5["policy"] == "zero_delay_trained")].iloc[0]
    p5 = near0_u5[(near0_u5["tau_ai_us"] == 5.0) & (near0_u5["policy"] == "delay_aware_projected")].iloc[0]
    z1 = near0_u5[(near0_u5["tau_ai_us"] == 1.0) & (near0_u5["policy"] == "zero_delay_trained")].iloc[0]
    d1 = near0_u5[(near0_u5["tau_ai_us"] == 1.0) & (near0_u5["policy"] == "delay_aware")].iloc[0]
    slow = summary[
        (summary["update_us"] == 20.0)
        & (summary["policy"].isin(["zero_delay_trained", "delay_aware", "delay_aware_projected"]))
    ]["violations_mean"].mean()
    fast = summary[
        (summary["update_us"] == 5.0)
        & (summary["policy"].isin(["zero_delay_trained", "delay_aware", "delay_aware_projected"]))
    ]["violations_mean"].mean()
    lines.append("## Key Findings")
    lines.append("")
    lines.append(
        f"1. In the severe `40A->near-0A`, `T_update=5us` slice, a `5us` AI delay equals "
        f"`{int(5.0 / EVENT_US)}` event slots. The zero-delay-trained tuner reaches "
        f"`{z5['violations_mean']:.3f}` mean violations, whereas the delay-aware projected tuner reaches "
        f"`{p5['violations_mean']:.3f}`. Tail phase error drops from `{z5['tail_abs_phase_ns_mean']:.3f} ns` "
        f"to `{p5['tail_abs_phase_ns_mean']:.3f} ns`, and tail current imbalance drops from "
        f"`{z5['tail_abs_i_mA_mean']:.3f} mA` to `{p5['tail_abs_i_mA_mean']:.3f} mA`."
    )
    lines.append(
        f"2. At `tau_AI=1us`, the zero-delay-trained tuner is still competitive in the same slice "
        f"(`reward={z1['reward_mean']:.3f}` versus `{d1['reward_mean']:.3f}` for delay-aware). "
        "Thus the model should not claim that delay-aware AI is universally superior; it identifies the delay range "
        "where zero-delay training becomes a train-test mismatch."
    )
    lines.append(
        f"3. Slower update periods are dangerous in this surrogate. Across adaptive policies, mean violations are "
        f"`{fast:.3f}` at `T_update=5us` but `{slow:.3f}` at `T_update=20us`. "
        "This supports treating FPGA AI as a supervisory parameter tuner with an explicitly budgeted update period."
    )
    lines.append("")
    lines.append("## Interpretation")
    lines.append("")
    lines.append(
        "The useful role of PIS-IEK is not to make a microsecond-latency AI act like a sub-nanosecond comparator. "
        "Instead, it lets the AI train and deploy in the same delayed event coordinates: `u_k` is evaluated as `u_{k-d}` "
        "with `d=ceil(tau_AI/T_event)`.  This removes a train-test mismatch that appears when a zero-delay tuner is deployed "
        "on FPGA with microsecond inference latency."
    )
    lines.append("")
    lines.append(
        "The projected policy is deliberately conservative.  Its value should be judged by lower violation rate and bounded "
        "phase/current excursions, not only by raw reward.  This matches the thesis that AI should tune low-dimensional IQCOT "
        "parameters under physical constraints instead of directly replacing the event generator."
    )
    lines.append("")
    lines.append("## Boundary")
    lines.append("")
    lines.append(
        "This is a surrogate experiment.  The next stronger validation is to implement a controlled dynamic load in the Simulink "
        "copy and compare whether the same delay-aware policy ordering is preserved on switching waveforms."
    )
    (OUT / "iqcot_ai_delay_event_surrogate_report.md").write_text("\n".join(lines), encoding="utf-8")


def make_plot(summary: pd.DataFrame) -> None:
    try:
        import matplotlib.pyplot as plt
    except Exception:
        make_svg_plot(summary)
        return

    sub = summary[
        (summary["case"] == "40A_to_near0A")
        & (summary["update_us"] == 5.0)
        & (summary["policy"].isin(["zero_delay_trained", "delay_aware", "delay_aware_projected"]))
    ].copy()

    fig, axes = plt.subplots(1, 2, figsize=(10, 4), constrained_layout=True)
    for policy, g in sub.groupby("policy"):
        g = g.sort_values("tau_ai_us")
        axes[0].plot(g["tau_ai_us"], g["violations_mean"], marker="o", label=policy)
        axes[1].plot(g["tau_ai_us"], g["max_abs_phase_ns_p95"], marker="o", label=policy)
    axes[0].set_xlabel("AI latency (us)")
    axes[0].set_ylabel("Mean constraint violations")
    axes[0].grid(True, alpha=0.3)
    axes[1].set_xlabel("AI latency (us)")
    axes[1].set_ylabel("P95 phase excursion (ns)")
    axes[1].grid(True, alpha=0.3)
    axes[1].legend(fontsize=8)
    fig.suptitle("Near-zero cut-load: delay-aware PIS-IEK surrogate")
    fig.savefig(FIG / "fig21_ai_delay_event_surrogate.png", dpi=180)
    plt.close(fig)


def make_svg_plot(summary: pd.DataFrame) -> None:
    sub = summary[
        (summary["case"] == "40A_to_near0A")
        & (summary["update_us"] == 5.0)
        & (summary["policy"].isin(["zero_delay_trained", "delay_aware", "delay_aware_projected"]))
    ].copy()

    width, height = 900, 360
    margin = 55
    panel_w = (width - 3 * margin) / 2
    panel_h = height - 2 * margin

    def scale(vals: pd.Series, lo: float, hi: float, x0: float, w: float) -> list[float]:
        denom = hi - lo if hi != lo else 1.0
        return [x0 + (float(v) - lo) / denom * w for v in vals]

    def yscale(vals: pd.Series, lo: float, hi: float) -> list[float]:
        denom = hi - lo if hi != lo else 1.0
        return [height - margin - (float(v) - lo) / denom * panel_h for v in vals]

    tau_lo, tau_hi = 0.0, 5.0
    viol_hi = max(1.0, float(sub["violations_mean"].max()) * 1.08)
    phase_hi = max(1.0, float(sub["tail_abs_phase_ns_mean"].max()) * 1.08)
    colors = {
        "zero_delay_trained": "#d62728",
        "delay_aware": "#1f77b4",
        "delay_aware_projected": "#2ca02c",
    }

    lines = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        '<rect width="100%" height="100%" fill="white"/>',
        '<text x="450" y="25" text-anchor="middle" font-size="17" font-family="Arial">Near-zero cut-load, update=5us: AI delay surrogate</text>',
    ]

    panels = [
        ("Mean constraint violations", "violations_mean", 0.0, viol_hi, margin),
        ("Tail phase mean (ns)", "tail_abs_phase_ns_mean", 0.0, phase_hi, 2 * margin + panel_w),
    ]
    for title, metric, ymin, ymax, x0 in panels:
        lines.append(f'<rect x="{x0:.1f}" y="{margin}" width="{panel_w:.1f}" height="{panel_h:.1f}" fill="none" stroke="#333"/>')
        lines.append(f'<text x="{x0 + panel_w / 2:.1f}" y="{margin - 14}" text-anchor="middle" font-size="13" font-family="Arial">{title}</text>')
        for tick in range(6):
            tx = x0 + tick / 5 * panel_w
            tau = tick
            lines.append(f'<line x1="{tx:.1f}" y1="{height - margin}" x2="{tx:.1f}" y2="{height - margin + 4}" stroke="#333"/>')
            lines.append(f'<text x="{tx:.1f}" y="{height - margin + 18}" text-anchor="middle" font-size="10" font-family="Arial">{tau}</text>')
        for tick in range(5):
            y = height - margin - tick / 4 * panel_h
            val = ymin + tick / 4 * (ymax - ymin)
            lines.append(f'<line x1="{x0 - 4:.1f}" y1="{y:.1f}" x2="{x0:.1f}" y2="{y:.1f}" stroke="#333"/>')
            lines.append(f'<text x="{x0 - 8:.1f}" y="{y + 3:.1f}" text-anchor="end" font-size="10" font-family="Arial">{val:.0f}</text>')

        for policy, g in sub.groupby("policy"):
            g = g.sort_values("tau_ai_us")
            xs = scale(g["tau_ai_us"], tau_lo, tau_hi, x0, panel_w)
            ys = yscale(g[metric], ymin, ymax)
            pts = " ".join(f"{x:.1f},{y:.1f}" for x, y in zip(xs, ys))
            color = colors.get(policy, "#555")
            lines.append(f'<polyline points="{pts}" fill="none" stroke="{color}" stroke-width="2"/>')
            for x, y in zip(xs, ys):
                lines.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="3" fill="{color}"/>')

    legend_x = width - 255
    legend_y = 46
    for idx, (policy, color) in enumerate(colors.items()):
        y = legend_y + idx * 18
        lines.append(f'<line x1="{legend_x}" y1="{y}" x2="{legend_x + 24}" y2="{y}" stroke="{color}" stroke-width="2"/>')
        lines.append(f'<text x="{legend_x + 30}" y="{y + 4}" font-size="11" font-family="Arial">{policy}</text>')
    lines.append(f'<text x="{width / 2:.1f}" y="{height - 8}" text-anchor="middle" font-size="11" font-family="Arial">AI latency tau_AI (us)</text>')
    lines.append("</svg>")
    (FIG / "fig21_ai_delay_event_surrogate.svg").write_text("\n".join(lines), encoding="utf-8")


def main() -> None:
    rows = []
    for case in CUT_CASES:
        for tau in TAU_AI_US:
            for update in UPDATE_US:
                for policy in POLICIES:
                    for seed in range(SEEDS):
                        rows.append(run_episode(case, tau, update, policy, seed))
    detail = pd.DataFrame(rows)
    summary = make_summary(detail)

    detail.to_csv(OUT / "iqcot_ai_delay_event_surrogate_detail.csv", index=False)
    summary.to_csv(OUT / "iqcot_ai_delay_event_surrogate_summary.csv", index=False)
    write_report(summary, detail)
    make_plot(summary)

    print(f"Wrote {len(detail)} episodes")
    print(OUT / "iqcot_ai_delay_event_surrogate_summary.csv")
    print(OUT / "iqcot_ai_delay_event_surrogate_report.md")


if __name__ == "__main__":
    main()
