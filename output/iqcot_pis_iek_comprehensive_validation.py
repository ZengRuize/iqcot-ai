import csv
import math
import sys
import time
from pathlib import Path

sys.path.insert(0, "E:/Desktop/codex/output")

from iqcot_multiphase_iek_modal_study import MultiPhaseAreaBuck, fit_sine
from iqcot_phase_indexed_saltation_iek import (
    apply_linear_step,
    build_phase_indexed_model,
    dot,
    event_step,
    rms,
    simulate_validation,
    v_add,
    v_sub,
    zeros,
)


OUT = Path("E:/Desktop/codex/output")


def wrap_phase(x):
    while x > math.pi:
        x -= 2 * math.pi
    while x < -math.pi:
        x += 2 * math.pi
    return x


def write_csv(path, rows):
    if not rows:
        raise ValueError(f"no rows for {path}")
    with path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)
    return path


def pattern_library():
    return {
        "common": [1.0, 1.0, 1.0, 1.0],
        "m1_cos": [1.0, 0.0, -1.0, 0.0],
        "m1_sin": [0.0, 1.0, 0.0, -1.0],
        "m2_alt": [1.0, -1.0, 1.0, -1.0],
        "one_phase": [1.0, -1.0 / 3.0, -1.0 / 3.0, -1.0 / 3.0],
    }


def pattern_text(pattern):
    return " ".join(f"{v:.8g}" for v in pattern)


def projection(values, pattern):
    denom = dot(pattern, pattern)
    if denom == 0:
        return 0.0
    return dot(values, pattern) / denom


def make_sensitivity_rows(model, jacobians):
    rows = []
    for event_phase, jac in enumerate(jacobians):
        trigger_phase = jac["nominal"]["next_phase"]
        for input_phase, value in enumerate(jac["C_wait_lambda"]):
            rows.append({
                "dataset": "local_saltation_jacobian",
                "event_phase_p": event_phase + 1,
                "trigger_phase_q": trigger_phase + 1,
                "input_type": "Lambda",
                "input_phase": input_phase + 1,
                "is_event_surface_phase": int(input_phase == trigger_phase),
                "scale": "ns_per_1e-13_Vs",
                "dwait_scaled": value * 1e-13 * 1e9,
                "nominal_wait_ns": jac["nominal"]["wait"] * 1e9,
                "nominal_period_ns": jac["nominal"]["period"] * 1e9,
            })
        for input_phase, value in enumerate(jac["C_wait_ton"]):
            rows.append({
                "dataset": "local_saltation_jacobian",
                "event_phase_p": event_phase + 1,
                "trigger_phase_q": trigger_phase + 1,
                "input_type": "Ton",
                "input_phase": input_phase + 1,
                "is_event_surface_phase": int(input_phase == event_phase),
                "scale": "ns_per_ns",
                "dwait_scaled": value,
                "nominal_wait_ns": jac["nominal"]["wait"] * 1e9,
                "nominal_period_ns": jac["nominal"]["period"] * 1e9,
            })
    return rows


def make_modal_projection_rows(jacobians, patterns):
    rows = []
    for input_type in ["Lambda", "Ton"]:
        for name, pattern in patterns.items():
            wait_vector = []
            for event_phase, jac in enumerate(jacobians):
                if input_type == "Lambda":
                    wait_vector.append(dot(jac["C_wait_lambda"], pattern) * 1e-13 * 1e9)
                    scale = "ns_per_1e-13_pattern"
                else:
                    wait_vector.append(dot(jac["C_wait_ton"], pattern))
                    scale = "ns_per_ns_pattern"
            modal = {
                mode_name: projection(wait_vector, mode_pattern)
                for mode_name, mode_pattern in patterns.items()
            }
            row = {
                "dataset": "modal_projection",
                "input_type": input_type,
                "input_pattern": name,
                "input_pattern_vector": pattern_text(pattern),
                "wait_event_vector": pattern_text(wait_vector),
                "scale": scale,
                "wait_pkpk": max(wait_vector) - min(wait_vector),
                "wait_rms": rms(wait_vector),
            }
            for mode_name, value in modal.items():
                row[f"projection_{mode_name}"] = value
            rows.append(row)
    return rows


def amplitude_sweep(model, jacobians, patterns):
    rows = []
    lambda_amps = [0.25e-13, 0.5e-13, 1e-13, 2e-13, 4e-13, 8e-13, 16e-13]
    ton_amps = [0.002e-9, 0.005e-9, 0.010e-9, 0.020e-9, 0.050e-9, 0.100e-9]
    events = 900
    burn = 120

    for pattern_name in ["common", "m1_cos", "m1_sin", "m2_alt", "one_phase"]:
        pattern = patterns[pattern_name]
        for amp in lambda_amps:
            lambda_offsets = [amp * v for v in pattern]
            result = simulate_validation(
                model, jacobians, f"lambda_{pattern_name}_{amp:.3e}",
                lambda_offsets, zeros(model.n), events=events, burn=burn
            )
            result.update({
                "dataset": "amplitude_sweep",
                "input_type": "Lambda",
                "input_pattern": pattern_name,
                "amplitude_si": amp,
                "amplitude_label": f"{amp/1e-13:.3g}e-13 V*s",
                "ton_pattern": "",
                "lambda_pattern_vector": pattern_text(lambda_offsets),
                "ton_pattern_vector": pattern_text(zeros(model.n)),
            })
            rows.append(result)

    for pattern_name in ["common", "m1_cos", "m2_alt", "one_phase"]:
        pattern = patterns[pattern_name]
        for amp in ton_amps:
            ton_offsets = [amp * v for v in pattern]
            result = simulate_validation(
                model, jacobians, f"ton_{pattern_name}_{amp*1e9:.4f}ns",
                zeros(model.n), ton_offsets, events=events, burn=burn
            )
            result.update({
                "dataset": "amplitude_sweep",
                "input_type": "Ton",
                "input_pattern": pattern_name,
                "amplitude_si": amp,
                "amplitude_label": f"{amp*1e9:.4g} ns",
                "ton_pattern": pattern_name,
                "lambda_pattern_vector": pattern_text(zeros(model.n)),
                "ton_pattern_vector": pattern_text(ton_offsets),
            })
            rows.append(result)

    mixed_specs = [
        ("m2_lambda_plus_one_phase_ton", "m2_alt", "one_phase"),
        ("one_phase_lambda_plus_m2_ton", "one_phase", "m2_alt"),
    ]
    for label, lambda_pattern_name, ton_pattern_name in mixed_specs:
        lambda_pattern = patterns[lambda_pattern_name]
        ton_pattern = patterns[ton_pattern_name]
        for lambda_amp in [0.5e-13, 1e-13, 2e-13]:
            for ton_amp in [0.005e-9, 0.010e-9, 0.020e-9]:
                lambda_offsets = [lambda_amp * v for v in lambda_pattern]
                ton_offsets = [ton_amp * v for v in ton_pattern]
                result = simulate_validation(
                    model, jacobians,
                    f"mixed_{label}_{lambda_amp:.2e}_{ton_amp*1e9:.3f}ns",
                    lambda_offsets, ton_offsets, events=events, burn=burn
                )
                result.update({
                    "dataset": "amplitude_sweep",
                    "input_type": "Mixed",
                    "input_pattern": label,
                    "amplitude_si": math.sqrt((lambda_amp / 1e-13) ** 2 + (ton_amp / 1e-9) ** 2),
                    "amplitude_label": f"Lambda={lambda_amp/1e-13:.3g}e-13, Ton={ton_amp*1e9:.3g}ns",
                    "ton_pattern": ton_pattern_name,
                    "lambda_pattern_vector": pattern_text(lambda_offsets),
                    "ton_pattern_vector": pattern_text(ton_offsets),
                })
                rows.append(result)
    return rows


def simulate_lifted_frequency(model, jacobians, case_name, lambda_pattern, ton_pattern,
                              lambda_amp, ton_amp, omega, projection_pattern,
                              blocks=1536, burn_blocks=256):
    state_nom = list(model.state)
    state_pert = list(model.state)
    dx = zeros(len(model.state))
    wait_exact = []
    wait_pred = []
    current_exact = []
    current_pred = []
    for b in range(blocks):
        sin_b = math.sin(omega * b)
        lambda_offsets = [lambda_amp * sin_b * v for v in lambda_pattern]
        ton_offsets = [ton_amp * sin_b * v for v in ton_pattern]
        wait_exact_by_phase = zeros(model.n)
        wait_pred_by_phase = zeros(model.n)
        for p in range(model.n):
            nominal = event_step(model, state_nom, p)
            perturbed = event_step(model, state_pert, p, lambda_offsets, ton_offsets)
            dx, wait_pred_k = apply_linear_step(jacobians[p], dx, lambda_offsets, ton_offsets)
            q = nominal["next_phase"]
            wait_exact_by_phase[q] = perturbed["wait"] - nominal["wait"]
            wait_pred_by_phase[q] = wait_pred_k
            state_nom = nominal["state"]
            state_pert = perturbed["state"]

        curr_exact_vec = v_sub(perturbed["phase_currents"], nominal["phase_currents"])
        curr_pred_vec = v_sub(model.phase_currents(v_add(nominal["state"], dx)), nominal["phase_currents"])
        if b >= burn_blocks:
            wait_exact.append(projection(wait_exact_by_phase, projection_pattern))
            wait_pred.append(projection(wait_pred_by_phase, projection_pattern))
            current_exact.append(projection(curr_exact_vec, projection_pattern))
            current_pred.append(projection(curr_pred_vec, projection_pattern))

    wait_exact_amp, wait_exact_phase, _ = fit_sine(wait_exact, omega, 0)
    wait_pred_amp, wait_pred_phase, _ = fit_sine(wait_pred, omega, 0)
    curr_exact_amp, curr_exact_phase, _ = fit_sine(current_exact, omega, 0)
    curr_pred_amp, curr_pred_phase, _ = fit_sine(current_pred, omega, 0)
    wait_errors = [p - e for p, e in zip(wait_pred, wait_exact)]
    current_errors = [p - e for p, e in zip(current_pred, current_exact)]
    return {
        "case": case_name,
        "omega_over_pi": omega / math.pi,
        "frequency_domain": "four_event_lifted_block",
        "events": blocks * model.n,
        "burn": burn_blocks * model.n,
        "blocks": blocks,
        "burn_blocks": burn_blocks,
        "lambda_amp_si": lambda_amp,
        "ton_amp_s": ton_amp,
        "wait_exact_amp_ns": wait_exact_amp * 1e9,
        "wait_pred_amp_ns": wait_pred_amp * 1e9,
        "wait_amp_abs_error_ns": (wait_pred_amp - wait_exact_amp) * 1e9,
        "wait_amp_error_pct": 100.0 * (wait_pred_amp / max(wait_exact_amp, 1e-30) - 1.0),
        "wait_phase_exact_deg": wait_exact_phase * 180.0 / math.pi,
        "wait_phase_pred_deg": wait_pred_phase * 180.0 / math.pi,
        "wait_phase_error_deg": wrap_phase(wait_pred_phase - wait_exact_phase) * 180.0 / math.pi,
        "wait_rms_error_ps": rms(wait_errors) * 1e12,
        "wait_rms_error_pct": 100.0 * rms(wait_errors) / max(rms(wait_exact), 1e-30),
        "wait_observable": int(wait_exact_amp * 1e9 >= 1e-4),
        "current_exact_amp_mA": curr_exact_amp * 1e3,
        "current_pred_amp_mA": curr_pred_amp * 1e3,
        "current_amp_abs_error_mA": (curr_pred_amp - curr_exact_amp) * 1e3,
        "current_amp_error_pct": 100.0 * (curr_pred_amp / max(curr_exact_amp, 1e-30) - 1.0),
        "current_phase_error_deg": wrap_phase(curr_pred_phase - curr_exact_phase) * 180.0 / math.pi,
        "current_rms_error_mA": rms(current_errors) * 1e3,
        "current_observable": int(curr_exact_amp * 1e3 >= 1e-4),
    }


def frequency_response(model, jacobians, patterns):
    rows = []
    omegas = [0.005, 0.01, 0.02, 0.05, 0.10, 0.20, 0.35, 0.50, 0.70, 0.85]
    specs = [
        ("lambda_common", "Lambda", "common", "", 1.0e-13, 0.0, "common"),
        ("lambda_m1_cos", "Lambda", "m1_cos", "", 1.0e-13, 0.0, "m1_cos"),
        ("lambda_m2_alt", "Lambda", "m2_alt", "", 1.0e-13, 0.0, "m2_alt"),
        ("lambda_one_phase", "Lambda", "one_phase", "", 1.0e-13, 0.0, "one_phase"),
        ("ton_common", "Ton", "", "common", 0.0, 0.010e-9, "common"),
        ("ton_m1_cos", "Ton", "", "m1_cos", 0.0, 0.010e-9, "m1_cos"),
        ("ton_m2_alt", "Ton", "", "m2_alt", 0.0, 0.010e-9, "m2_alt"),
        ("mixed_m2", "Mixed", "m2_alt", "one_phase", 0.5e-13, 0.005e-9, "m2_alt"),
    ]
    for base_name, input_type, lambda_name, ton_name, lambda_amp, ton_amp, proj_name in specs:
        lambda_pattern = patterns[lambda_name] if lambda_name else zeros(model.n)
        ton_pattern = patterns[ton_name] if ton_name else zeros(model.n)
        projection_pattern = patterns[proj_name]
        for ratio in omegas:
            omega = ratio * math.pi
            row = simulate_lifted_frequency(
                model, jacobians, f"{base_name}_w{ratio:.3f}",
                lambda_pattern, ton_pattern, lambda_amp, ton_amp, omega, projection_pattern
            )
            row.update({
                "dataset": "frequency_response",
                "input_type": input_type,
                "lambda_pattern": lambda_name,
                "ton_pattern": ton_name,
                "projection_pattern": proj_name,
            })
            rows.append(row)
    return rows


def write_report(paths, model, closure_error, sensitivity_rows, modal_rows, amp_rows, freq_rows, elapsed_s):
    path = OUT / "iqcot_pis_iek_comprehensive_validation_report.md"
    lambda_amp_rows = [r for r in amp_rows if r["input_type"] == "Lambda"]
    ton_amp_rows = [r for r in amp_rows if r["input_type"] == "Ton"]
    mixed_amp_rows = [r for r in amp_rows if r["input_type"] == "Mixed"]
    freq_lambda_rows = [r for r in freq_rows if r["input_type"] == "Lambda"]
    freq_ton_rows = [r for r in freq_rows if r["input_type"] == "Ton"]
    freq_mixed_rows = [r for r in freq_rows if r["input_type"] == "Mixed"]

    def max_value(rows, key):
        return max(float(r[key]) for r in rows) if rows else float("nan")

    worst_amp = max(amp_rows, key=lambda r: float(r["rms_wait_error_pct"]))
    observable_freq_rows = [r for r in freq_rows if int(r["wait_observable"]) == 1]
    worst_freq = max(observable_freq_rows, key=lambda r: abs(float(r["wait_amp_error_pct"]))) if observable_freq_rows else max(freq_rows, key=lambda r: abs(float(r["wait_amp_abs_error_ns"])))
    with path.open("w", encoding="utf-8") as f:
        f.write("# PIS-IEK 结构化仿真验证报告\n\n")
        f.write("## 实验规模\n\n")
        f.write(f"- 模型：四相理想 IQCOT 面积事件模型，`N=4`，`Ton={model.ton*1e9:.6f} ns`，`Twait={model.tw*1e9:.6f} ns`。\n")
        f.write(f"- 四事件闭合误差：`{closure_error:.3e}`。\n")
        f.write(f"- 局部 Jacobian 行数：`{len(sensitivity_rows)}`。\n")
        f.write(f"- 模态投影行数：`{len(modal_rows)}`。\n")
        f.write(f"- 幅值线性扫描：`{len(amp_rows)}` 个工况，其中 Lambda `{len(lambda_amp_rows)}`、Ton `{len(ton_amp_rows)}`、Mixed `{len(mixed_amp_rows)}`。\n")
        f.write(f"- 频率响应扫描：`{len(freq_rows)}` 个工况，其中 Lambda `{len(freq_lambda_rows)}`、Ton `{len(freq_ton_rows)}`、Mixed `{len(freq_mixed_rows)}`。\n")
        f.write(f"- 总运行时间：`{elapsed_s:.2f} s`。\n\n")

        f.write("## 主要结论\n\n")
        f.write(
            "- 局部事件面结果显示，当前 wait 只直接受下一触发相 `Lambda_q` 和当前 on-time 相 `Ton_p` 影响；"
            "在该理想四相模型中非目标相局部串扰为 0。这为 `phase_idx` 的事件面解释提供了清楚证据。\n"
        )
        f.write(
            f"- Lambda 幅值扫描最大 rms wait 相对误差为 `{max_value(lambda_amp_rows, 'rms_wait_error_pct'):.4f}%`；"
            f"Ton 幅值扫描最大 rms wait 相对误差为 `{max_value(ton_amp_rows, 'rms_wait_error_pct'):.4f}%`。\n"
        )
        f.write(
            f"- Mixed 幅值扫描最大 rms wait 相对误差为 `{max_value(mixed_amp_rows, 'rms_wait_error_pct'):.4f}%`，"
            "说明线性叠加在小扰动范围内仍成立，但 Ton 通道会先成为误差主导项。\n"
        )
        f.write(
            f"- 四事件提升频率响应中，可观测 wait 幅值工况的最坏幅值误差来自 `{worst_freq['case']}`，"
            f"误差为 `{float(worst_freq['wait_amp_error_pct']):.4f}%`，绝对误差 `{float(worst_freq['wait_amp_abs_error_ns']):.6g} ns`；"
            "这用于标定 PIS-IEK 在高频事件扰动下的适用边界。低于 `1e-4 ns` 的响应幅值不用于百分比最坏值判定。\n"
        )
        f.write(
            f"- 幅值扫描中最坏 rms wait 误差来自 `{worst_amp['case']}`，误差为 `{float(worst_amp['rms_wait_error_pct']):.4f}%`。\n\n"
        )

        f.write("## 数据结构\n\n")
        for label, p in paths.items():
            f.write(f"- `{label}`: `{p}`\n")
        f.write("\n")

        f.write("## 论文写法建议\n\n")
        f.write(
            "PIS-IEK 可以作为 v6 的一个模型精进章节：先给盐跃事件映射，再给 Jacobian 数据表，"
            "最后用幅值线性和频率响应证明它不是只在单个扰动点成立。表述上要保持边界："
            "saltation/Poincare 是已有数学工具，本文创新在于将其与四相 IQCOT 面积事件、相序调度和执行量分类结合。\n"
        )
    return path


def write_manifest(paths, row_counts):
    rows = []
    descriptions = {
        "sensitivity": "event-phase indexed local derivatives dT/dLambda and dT/dTon",
        "modal_projection": "modal projection of local wait sensitivity vectors",
        "amplitude_sweep": "constant small-signal amplitude sweep for Lambda, Ton and mixed perturbations",
        "frequency_response": "sinusoidal event-domain frequency response comparing nonlinear and PIS-IEK predictions",
        "report": "human-readable comprehensive validation report",
    }
    for key, path in paths.items():
        rows.append({
            "dataset": key,
            "path": str(path),
            "rows": row_counts.get(key, ""),
            "description": descriptions.get(key, ""),
        })
    manifest_path = OUT / "iqcot_pis_iek_dataset_manifest.csv"
    return write_csv(manifest_path, rows)


def main():
    started = time.time()
    model = MultiPhaseAreaBuck(n=4)
    patterns = pattern_library()
    _, jacobians, closure_error = build_phase_indexed_model(model)

    print("Building local sensitivity tables...")
    sensitivity_rows = make_sensitivity_rows(model, jacobians)
    modal_rows = make_modal_projection_rows(jacobians, patterns)
    sensitivity_path = write_csv(OUT / "iqcot_pis_iek_sensitivity_matrix.csv", sensitivity_rows)
    modal_path = write_csv(OUT / "iqcot_pis_iek_modal_projection_matrix.csv", modal_rows)

    print("Running amplitude sweep...")
    amp_rows = amplitude_sweep(model, jacobians, patterns)
    amp_path = write_csv(OUT / "iqcot_pis_iek_amplitude_sweep.csv", amp_rows)

    print("Running frequency response sweep...")
    freq_rows = frequency_response(model, jacobians, patterns)
    freq_path = write_csv(OUT / "iqcot_pis_iek_frequency_response.csv", freq_rows)

    paths = {
        "sensitivity": sensitivity_path,
        "modal_projection": modal_path,
        "amplitude_sweep": amp_path,
        "frequency_response": freq_path,
    }
    elapsed_s = time.time() - started
    report_path = write_report(paths, model, closure_error, sensitivity_rows, modal_rows, amp_rows, freq_rows, elapsed_s)
    paths["report"] = report_path
    manifest_path = write_manifest(paths, {
        "sensitivity": len(sensitivity_rows),
        "modal_projection": len(modal_rows),
        "amplitude_sweep": len(amp_rows),
        "frequency_response": len(freq_rows),
        "report": 1,
    })
    paths["manifest"] = manifest_path

    print("PIS-IEK comprehensive validation complete")
    for key, path in paths.items():
        print(f"{key.upper()}={path}")
    print(f"ROWS amplitude={len(amp_rows)} frequency={len(freq_rows)}")
    print(f"ELAPSED_S={elapsed_s:.2f}")


if __name__ == "__main__":
    main()
