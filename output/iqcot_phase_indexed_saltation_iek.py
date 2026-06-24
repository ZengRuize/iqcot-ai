import csv
import math
import sys
from pathlib import Path

sys.path.insert(0, "E:/Desktop/codex/output")

from iqcot_multiphase_iek_modal_study import MultiPhaseAreaBuck


def zeros(n):
    return [0.0] * n


def dot(a, b):
    return sum(x * y for x, y in zip(a, b))


def v_add(a, b):
    return [x + y for x, y in zip(a, b)]


def v_sub(a, b):
    return [x - y for x, y in zip(a, b)]


def v_scale(s, a):
    return [s * x for x in a]


def mat_vec(a, x):
    return [dot(row, x) for row in a]


def mat_add(a, b):
    return [v_add(ra, rb) for ra, rb in zip(a, b)]


def mat_col(a, j):
    return [row[j] for row in a]


def vec_norm_inf(x):
    return max(abs(v) for v in x) if x else 0.0


def rms(vals):
    if not vals:
        return 0.0
    return math.sqrt(sum(v * v for v in vals) / len(vals))


def event_step(model, state, phase, lambda_offsets=None, ton_offsets=None):
    if lambda_offsets is None:
        lambda_offsets = zeros(model.n)
    if ton_offsets is None:
        ton_offsets = zeros(model.n)

    p = phase % model.n
    q = (p + 1) % model.n
    ton = model.ton + ton_offsets[p]
    s_on = zeros(model.n)
    s_on[p] = 1.0
    int_on = model.segment_current_integrals(state, ton, s_on)
    start = model.segment(state, ton, s_on)
    lam = model.lambda_phase + lambda_offsets[q]
    wait = model.solve_wait(start, q, lam, model.tw)
    int_wait = model.segment_current_integrals(start, wait, zeros(model.n))
    next_state = model.segment(start, wait, zeros(model.n))
    current_integrals = [a + b for a, b in zip(int_on, int_wait)]
    return {
        "phase": p,
        "next_phase": q,
        "ton": ton,
        "wait": wait,
        "period": ton + wait,
        "state": next_state,
        "phase_currents": model.phase_currents(next_state),
        "current_integrals": current_integrals,
    }


def central_diff_vector(fn, base, idx, step):
    xp = list(base)
    xm = list(base)
    xp[idx] += step
    xm[idx] -= step
    yp = fn(xp)
    ym = fn(xm)
    return v_scale(0.5 / step, v_sub(yp, ym))


def central_diff_scalar(fn, base, idx, step):
    xp = list(base)
    xm = list(base)
    xp[idx] += step
    xm[idx] -= step
    return 0.5 * (fn(xp) - fn(xm)) / step


def event_jacobian(model, state, phase):
    n_state = len(state)
    n_phase = model.n
    state_steps = [1e-5, 1e-7] + [1e-5] * model.n
    lambda_step = 1e-14
    ton_step = 1e-12

    nominal = event_step(model, state, phase)

    def state_to_next(x):
        return event_step(model, x, phase)["state"]

    def state_to_wait(x):
        return event_step(model, x, phase)["wait"]

    a_cols = []
    c_x = []
    for i in range(n_state):
        a_cols.append(central_diff_vector(state_to_next, state, i, state_steps[i]))
        c_x.append(central_diff_scalar(state_to_wait, state, i, state_steps[i]))
    a = [[a_cols[j][i] for j in range(n_state)] for i in range(n_state)]

    b_lambda_cols = []
    c_lambda = []
    lambda_base = zeros(n_phase)
    for j in range(n_phase):
        def lam_to_next(lam):
            return event_step(model, state, phase, lambda_offsets=lam)["state"]

        def lam_to_wait(lam):
            return event_step(model, state, phase, lambda_offsets=lam)["wait"]

        b_lambda_cols.append(central_diff_vector(lam_to_next, lambda_base, j, lambda_step))
        c_lambda.append(central_diff_scalar(lam_to_wait, lambda_base, j, lambda_step))
    b_lambda = [[b_lambda_cols[j][i] for j in range(n_phase)] for i in range(n_state)]

    b_ton_cols = []
    c_ton = []
    ton_base = zeros(n_phase)
    for j in range(n_phase):
        def ton_to_next(ton):
            return event_step(model, state, phase, ton_offsets=ton)["state"]

        def ton_to_wait(ton):
            return event_step(model, state, phase, ton_offsets=ton)["wait"]

        b_ton_cols.append(central_diff_vector(ton_to_next, ton_base, j, ton_step))
        c_ton.append(central_diff_scalar(ton_to_wait, ton_base, j, ton_step))
    b_ton = [[b_ton_cols[j][i] for j in range(n_phase)] for i in range(n_state)]

    return {
        "nominal": nominal,
        "A": a,
        "B_lambda": b_lambda,
        "B_ton": b_ton,
        "C_wait_x": c_x,
        "C_wait_lambda": c_lambda,
        "C_wait_ton": c_ton,
    }


def build_phase_indexed_model(model):
    states = []
    jacobians = []
    state = list(model.state)
    for phase in range(model.n):
        states.append(list(state))
        jac = event_jacobian(model, state, phase)
        jacobians.append(jac)
        state = jac["nominal"]["state"]
    closure_error = vec_norm_inf(v_sub(state, model.state))
    return states, jacobians, closure_error


def apply_linear_step(jac, dx, lambda_offsets, ton_offsets):
    dwait = (
        dot(jac["C_wait_x"], dx)
        + dot(jac["C_wait_lambda"], lambda_offsets)
        + dot(jac["C_wait_ton"], ton_offsets)
    )
    next_dx = v_add(mat_vec(jac["A"], dx), mat_vec(jac["B_lambda"], lambda_offsets))
    next_dx = v_add(next_dx, mat_vec(jac["B_ton"], ton_offsets))
    return next_dx, dwait


def simulate_validation(model, jacobians, case_name, lambda_offsets, ton_offsets, events=800, burn=80):
    state_nom = list(model.state)
    state_pert = list(model.state)
    dx = zeros(len(state_nom))
    wait_err = []
    state_err = []
    current_err = []
    wait_pred_vals = []
    wait_exact_vals = []
    for k in range(events):
        p = k % model.n
        nominal = event_step(model, state_nom, p)
        perturbed = event_step(model, state_pert, p, lambda_offsets, ton_offsets)
        dx, wait_pred = apply_linear_step(jacobians[p], dx, lambda_offsets, ton_offsets)
        wait_exact = perturbed["wait"] - nominal["wait"]
        dx_exact = v_sub(perturbed["state"], nominal["state"])
        current_exact = v_sub(perturbed["phase_currents"], nominal["phase_currents"])
        current_pred = v_sub(model.phase_currents(v_add(nominal["state"], dx)), nominal["phase_currents"])

        if k >= burn:
            wait_err.append(wait_pred - wait_exact)
            state_err.append(vec_norm_inf(v_sub(dx, dx_exact)))
            current_err.append(vec_norm_inf(v_sub(current_pred, current_exact)))
            wait_pred_vals.append(wait_pred)
            wait_exact_vals.append(wait_exact)

        state_nom = nominal["state"]
        state_pert = perturbed["state"]

    return {
        "case": case_name,
        "events": events,
        "burn": burn,
        "max_abs_wait_exact_ns": max(abs(v) for v in wait_exact_vals) * 1e9,
        "rms_wait_exact_ns": rms(wait_exact_vals) * 1e9,
        "rms_wait_pred_ns": rms(wait_pred_vals) * 1e9,
        "rms_wait_error_ps": rms(wait_err) * 1e12,
        "rms_wait_error_pct": 100.0 * rms(wait_err) / max(rms(wait_exact_vals), 1e-30),
        "max_wait_error_ps": max(abs(v) for v in wait_err) * 1e12,
        "max_wait_error_pct_of_peak": 100.0 * max(abs(v) for v in wait_err) / max(max(abs(v) for v in wait_exact_vals), 1e-30),
        "max_state_error": max(state_err),
        "max_current_error_mA": max(current_err) * 1e3,
    }


def write_jacobian_summary(out, model, jacobians, closure_error):
    rows = []
    for phase, jac in enumerate(jacobians):
        q = jac["nominal"]["next_phase"]
        rows.append({
            "event_phase_p": phase + 1,
            "trigger_phase_q": q + 1,
            "nominal_wait_ns": jac["nominal"]["wait"] * 1e9,
            "nominal_period_ns": jac["nominal"]["period"] * 1e9,
            "dwait_dlambda_q_ns_per_1e_13": jac["C_wait_lambda"][q] * 1e-13 * 1e9,
            "dwait_dlambda_offdiag_max_ns_per_1e_13": max(
                abs(v) for j, v in enumerate(jac["C_wait_lambda"]) if j != q
            ) * 1e-13 * 1e9,
            "dwait_dton_p_ns_per_ns": jac["C_wait_ton"][phase],
            "dwait_dton_offdiag_max_ns_per_ns": max(
                abs(v) for j, v in enumerate(jac["C_wait_ton"]) if j != phase
            ),
            "A_row_sum_inf": max(sum(abs(v) for v in row) for row in jac["A"]),
            "closure_error_inf": closure_error,
        })
    path = out / "iqcot_phase_indexed_saltation_jacobians.csv"
    with path.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)
    return path, rows


def write_validation(out, rows):
    path = out / "iqcot_phase_indexed_saltation_validation.csv"
    with path.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)
    return path


def write_report(out, jac_rows, validation_rows, closure_error):
    path = out / "iqcot_phase_indexed_saltation_iek_report.md"
    max_offdiag_lambda = max(r["dwait_dlambda_offdiag_max_ns_per_1e_13"] for r in jac_rows)
    max_offdiag_ton = max(r["dwait_dton_offdiag_max_ns_per_ns"] for r in jac_rows)
    max_wait_err = max(r["max_wait_error_ps"] for r in validation_rows)
    max_wait_err_pct = max(r["max_wait_error_pct_of_peak"] for r in validation_rows)
    max_current_err = max(r["max_current_error_mA"] for r in validation_rows)
    with path.open("w", encoding="utf-8") as f:
        f.write("# 相索引盐跃 IEK 小信号模型精进报告\n\n")
        f.write("## 核心增量\n\n")
        f.write(
            "v5 的 IEK 用 `H_e+K(z)` 表示面积事件的动态刚度，但 `K(z)` 仍是等效核。"
            "本报告把四相轮转显式写成 phase-indexed event map：\n\n"
        )
        f.write("```math\n")
        f.write("x_{k+1}=F_{p_k}(x_k,u_k,T_k),\\qquad g_{q_k}(x_k,u_k,T_k)=0.\n")
        f.write("```\n\n")
        f.write(
            "对事件边界做隐函数线性化后得到盐跃式更新：\n\n"
        )
        f.write("```math\n")
        f.write("\\delta T_k=-g_T^{-1}(g_x\\delta x_k+g_u\\delta u_k),\n")
        f.write("```\n\n")
        f.write("```math\n")
        f.write("\\delta x_{k+1}=(F_x-F_Tg_T^{-1}g_x)\\delta x_k+(F_u-F_Tg_T^{-1}g_u)\\delta u_k.\n")
        f.write("```\n\n")
        f.write(
            "这里 `p_k` 是当前 on-time 相，`q_k=(p_k+1) mod 4` 是下一触发相。"
            "它把 `phase_idx`、面积积分 reset 和事件时刻移动统一进同一个小信号映射，"
            "比单纯的 scalar `H_e+K(z)` 更适合解释四相数字实现。\n\n"
        )
        f.write("## 数值检查\n\n")
        f.write(f"- 四事件闭合误差 inf-norm：`{closure_error:.3e}`。\n")
        f.write(
            f"- 非目标相 `Lambda` 对当前 wait 的最大串扰："
            f"`{max_offdiag_lambda:.3e} ns/(1e-13 V*s)`。\n"
        )
        f.write(
            f"- 非当前相 `Ton` 对当前 wait 的最大串扰："
            f"`{max_offdiag_ton:.3e} ns/ns`。\n"
        )
        f.write(
            f"- 小扰动多事件验证最大 wait 预测误差：`{max_wait_err:.3f} ps`；"
            f"最大相对峰值误差：`{max_wait_err_pct:.3f}%`；"
            f"最大相电流预测误差：`{max_current_err:.6f} mA`。\n\n"
        )
        f.write("## 解释\n\n")
        f.write(
            "该模型给出一个比 v5 更严谨的创新表述：IEK 不只是一个频域动态核，"
            "还可以被写成四相周期盐跃 Jacobian。这样能够直接回答三个以前较弱的问题："
            "第一，`phase_idx` 选择的是哪个相的事件面；第二，积分器 reset 如何进入小信号状态更新；"
            "第三，`Lambda_diff` 与 `Ton_diff` 的执行量分类能否从局部 event map 推出。"
            "这仍不是完整硬件控制器模型，但已经把小信号建模从经验核推进到可验证的混杂系统线性化。\n"
        )
    return path


def main():
    out = Path("E:/Desktop/codex/output")
    model = MultiPhaseAreaBuck(n=4)
    _, jacobians, closure_error = build_phase_indexed_model(model)
    jac_path, jac_rows = write_jacobian_summary(out, model, jacobians, closure_error)

    m2 = [1.0, -1.0, 1.0, -1.0]
    one_phase = [1.0, -1.0 / 3.0, -1.0 / 3.0, -1.0 / 3.0]
    cases = [
        ("lambda_m2_1e_13", [1e-13 * v for v in m2], zeros(4)),
        ("lambda_one_phase_1e_13", [1e-13 * v for v in one_phase], zeros(4)),
        ("ton_m2_0p02ns", zeros(4), [0.02e-9 * v for v in m2]),
        ("mixed_lambda_ton_small", [0.5e-13 * v for v in m2], [0.01e-9 * v for v in one_phase]),
    ]
    validation_rows = [
        simulate_validation(model, jacobians, name, lam, ton)
        for name, lam, ton in cases
    ]
    val_path = write_validation(out, validation_rows)
    report_path = write_report(out, jac_rows, validation_rows, closure_error)

    print("Phase-indexed saltation IEK")
    print(f"JACOBIANS_CSV={jac_path}")
    print(f"VALIDATION_CSV={val_path}")
    print(f"REPORT_MD={report_path}")
    for row in validation_rows:
        print(
            f"{row['case']}: max_wait_err={row['max_wait_error_ps']:.4f} ps, "
            f"max_current_err={row['max_current_error_mA']:.6f} mA"
        )


if __name__ == "__main__":
    main()
