# R049L Repair External Model Execution Prompt

Date: 2026-06-25

用途：把本文件完整交给外部模型。它必须先修复 R049L 的基线不可比问题，再重新运行受控重入验证。不要把上一版 R049L 的 `CLAIM_DOWNGRADED` 当作科研结论。

---

## 交给外部模型的完整 Prompt

你现在是 IQCOT / PR-ECB / PIS-IEK 项目的仿真修复执行模型。上一版 R049L 输出已被监督模型判定为：

```text
IMPLEMENTATION_ISSUE
```

原因不是 one-shot controlled reentry 概念失败，而是 runner 没有复现 R049K 的仿真基线。你的任务是修复 R049L，使 A0 baseline 与 R049K 完全可比，然后重新测试 explicit controlled-reentry proxy。

---

## 一、必须读取的文件

开始前读取：

1. `AGENTS.md`
2. `.engramory-memory/MEMORY.md`，如果存在
3. `docs/R049L_SUPERVISOR_REVIEW_20260625.md`
4. `docs/R049L_EXTERNAL_MODEL_EXECUTION_PROMPT_20260625.md`
5. `docs/pr_ecb_soft_reentry_r049k.md`
6. `refine-logs/LOCAL_AUDIT_R049K_PR_ECB_SOFT_REENTRY_20260625.md`
7. `output/iqcot_r049k_pr_ecb_soft_reentry_chunk.m`
8. `output/iqcot_r049k_waveform_metric_audit.py`
9. `output/cutload_pr_ecb_control/r049k_soft_reentry_results_full.csv`
10. `output/cutload_pr_ecb_control/r049k_waveform_metric_pair_delta.csv`
11. `output/data/*r049k*soft_reentry*wave.csv`
12. 你上一轮生成的 R049L 文件：
    - `output/iqcot_r049l_pr_ecb_controlled_reentry_chunk.m`
    - `output/iqcot_r049l_build_controlled_reentry_model.m`
    - `output/iqcot_r049l_waveform_metric_audit.py`

必须应用 `power-electronics-simulink-design` 原则：

- `.slx` 是事实源；
- 只能通过 MATLAB / Simulink API 生成或修改派生副本；
- 不允许直接编辑 `.slx` XML；
- 不允许修改原始模型、R048 源派生模型、R049A-K 已完成模型；
- 先验证基线，再跑 A2。

---

## 二、上一版 R049L 的错误清单

必须逐条修复：

1. `t_load_step_s` 错误
   错误：`spec.t_load_step_s = spec.load_step_offset_s`
   正确：`spec.t_load_step_s = common.baseTStep + spec.load_step_offset_us * 1e-6`

2. `StopTime` 错误
   错误：`spec.stopTime = 81e-6`
   正确：`spec.stopTime = spec.t_load_step_s + common.postStepDuration`

3. R049K operating parameters 没保留
   必须从 R049K runner 复制：
   ```matlab
   common.lambdaArea = 6e-10;
   common.vAreaBias = 2e-3;
   common.riArea = 0.5e-3;
   common.baseTStep = 0.45e-3;
   common.postStepDuration = 0.150e-3;
   common.maxStep = "5e-9";
   common.fastTss = 5e-9;
   common.preWindow = 2e-6;
   common.peakWindow = 80e-6;
   common.finalWindow = 10e-6;
   ```

4. plan 参数必须恢复为 R049K-compatible：
   ```text
   tau_ai_us = 1.25
   selected_ref_slew_us = 60
   tton_trunc_min_ns = 196.5
   tton_trunc_window_us = -0.001
   base_load_A = 40
   target_load_A = 20
   offsets = 0.050 / 0.105 us
   ```

5. `Iph_ref_ts` 必须使用 R049K 同款 `makeDelayedIphRefTimeseries`，不要自己改成 0.3us reference slew。

6. `remainingHighSideOnTime` 必须恢复 R049K 语义：
   如果 `qh_i(t_load_step)` 不是 high，则 remaining Ton 返回 `0`，不能测未来下一次 pulse 宽度。

7. `inhibit_duration_us` 必须分清：
   - `inhibit_raw_duration_us`: raw state high duration
   - `effective_inhibit_duration_us`: `inhibit_raw AND NOT(one_shot_done)`，这才是实际 gate 关闭时间

---

## 三、基线复现质量门

在跑任何 A2 controlled-reentry 之前，必须先跑 A0 baseline，并与 R049K 对齐。

R049K baseline 必须匹配：

| Offset | Required check |
|---:|---|
| `0.050us` | `t_load_step_us ≈ 450.05` |
| `0.050us` | `vout0 ≈ 0.9995155 V` |
| `0.050us` | `qh4_at_step = 1` |
| `0.050us` | `remaining_ton4_ns ≈ 52 ns` |
| `0.050us` | A0 peak ≈ `2.1103 mV` |
| `0.105us` | `t_load_step_us ≈ 450.105` |
| `0.105us` | `vout0 ≈ 0.9995169 V` |
| `0.105us` | `qh4_at_step = 0` |
| `0.105us` | `remaining_ton4_ns = 0 ns` |
| `0.105us` | A0 peak ≈ `2.0936 mV` |

容差：

- `t_load_step_us`: ±`0.001us`
- `vout0`: ±`0.0001V`
- peak: ±`0.02mV`
- remaining Ton4: ±`2ns`

如果 A0 baseline 不满足上述任一条件：

```text
状态 = IMPLEMENTATION_ISSUE
停止；不要跑 A2；不要写科研结论。
```

---

## 四、修复后的 R049L 设计目标

修复基线后，再测试 explicit controlled-reentry proxy。

不要继续使用 raw `req_global` 作为 one-shot 触发源。上一版已经显示 raw comparator request 不是 phase boundary。

优先实现：

```text
phase-boundary one-shot release
```

可选触发源，按优先级：

1. `qh1` rising edge after inhibit starts
2. `phase_idx` transition to the desired release slot
3. 若实现困难，先做离线边界审计，确认模型中可可靠读取哪个 phase-boundary signal，再停止并报告

推荐 A2 语义：

```text
inhibit_raw starts at t_load_step + 0.070us
release trigger = first qh1 rising edge after inhibit starts
one_shot_done latches high at that phase-boundary event
allow_to_scheduler = existing_allow AND (NOT(inhibit_raw) OR one_shot_done)
```

注意：如果用 `qh1` 作为 release trigger，必须避免组合环路。必要时用 `Memory` / `Unit Delay` 做边沿检测。

---

## 五、必须输出的文件

建议用修复后文件名，避免覆盖上一版坏结果：

```text
output/iqcot_r049l_repair_build_controlled_reentry_model.m
output/iqcot_r049l_repair_pr_ecb_controlled_reentry_chunk.m
output/iqcot_r049l_repair_waveform_metric_audit.py
output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control_r049l_repair_controlled_reentry.slx
```

结果输出：

```text
docs/pr_ecb_controlled_reentry_r049l_repair.md
refine-logs/LOCAL_AUDIT_R049L_REPAIR_PR_ECB_CONTROLLED_REENTRY_20260625.md
output/cutload_pr_ecb_control/r049l_repair_controlled_reentry_results_full.csv
output/cutload_pr_ecb_control/r049l_repair_controlled_reentry_comparison_full.csv
output/cutload_pr_ecb_control/r049l_repair_controlled_reentry_report_full.md
output/cutload_pr_ecb_control/r049l_repair_waveform_metric_case_windows.csv
output/cutload_pr_ecb_control/r049l_repair_waveform_metric_pair_delta.csv
output/cutload_pr_ecb_control/r049l_repair_waveform_metric_summary.md
output/data/*r049l_repair*controlled_reentry*wave.csv
```

---

## 六、执行顺序

1. 修复 runner 参数和 metric 函数。
2. dry-run，只生成 plan，不仿真。
3. MATLAB Code Analyzer 检查两个 `.m` 文件。
4. update-diagram。
5. 只跑 A0 两行 baseline。
6. 检查 A0 是否匹配 R049K 基线。
7. 只有 baseline 通过，才跑完整 4 行 A0/A2。
8. 运行三窗口 audit。
9. 写 repair 报告和 refine-log。

---

## 七、判定规则

状态只能是：

```text
MODEL_CONFIRMED
MODEL_REVISED
IMPLEMENTATION_ISSUE
CLAIM_DOWNGRADED
```

`IMPLEMENTATION_ISSUE`：

- baseline 不匹配 R049K；
- update-diagram 失败；
- 任一真仿真失败；
- current active-HS pulse 被截断；
- `ton_trunc_global` 或 `ton_truncate1-4` 非零；
- phase-boundary one-shot 没有按预期触发；
- 日志缺关键字段。

`MODEL_CONFIRMED`：

- baseline 与 R049K 匹配；
- current pulse 不截断；
- early local peak 不变或改善；
- recovery positive peak 有收益；
- recovery undershoot penalty 显著低于 R049K；
- late positive peak penalty 显著低于 R049K 或接近 0；
- phase-boundary one-shot 语义成立。

`CLAIM_DOWNGRADED`：

- baseline 与 R049K 匹配；
- phase-boundary one-shot 语义成立；
- current pulse 不截断；
- 但 A2 与 A0 几乎相同或收益太窄。

`MODEL_REVISED`：

- baseline 与 R049K 匹配；
- controlled reentry 产生可测作用；
- 但仍存在明显 recovery undershoot / late peak trade-off。

---

## 八、最终交付模板

最终输出：

```text
R049L repair 执行完成。

状态: <...>

1. 是否修复了基线
| offset | R049K A0 peak | repair A0 peak | R049K rem Ton4 | repair rem Ton4 | pass/fail |

2. A2 reentry 语义
- trigger source:
- release time:
- effective inhibit duration:
- one_shot count:
- current pulse truncation:

3. 三窗口结果
| offset | early peak Δ | recovery peak improvement | recovery undershoot penalty | late peak penalty |

4. 与 R049K 对比
- recovery peak:
- recovery undershoot:
- late peak:

5. 质量门
- MATLAB checkcode:
- update diagram:
- A0 baseline:
- 4-row true run:
- Python audit:
- old .slx untouched:

6. 证据文件
- ...

7. 给监督模型的建议
- ...
```

如果 baseline 失败，最终输出必须是：

```text
状态: IMPLEMENTATION_ISSUE
失败原因: baseline mismatch
具体不匹配项:
复现命令:
不要进入 A2 或科研结论。
```

---

## 九、禁止事项

- 禁止把上一版 R049L 的 `CLAIM_DOWNGRADED` 作为科研结论。
- 禁止覆盖 R049K 文件。
- 禁止修改 R049A-K 已完成模型。
- 禁止直接编辑 `.slx` XML。
- 禁止跳过 A0 baseline equivalence gate。
- 禁止在 baseline 不匹配时继续跑 A2。
- 禁止自动 commit，除非用户明确要求。
