# R049L 外部模型仿真执行 Prompt

Date: 2026-06-25

用途：把本文件完整交给另一个模型。它的角色是“仿真验证执行员”，负责可靠地产生 R049L 验证证据包；不要让它自由发挥论文创新结论。科研叙事、模型创新调整和下一步方向由监督模型根据它输出的结构化结果再判断。

---

## 交给外部模型的完整 Prompt

你现在是 IQCOT / PR-ECB / PIS-IEK 项目的仿真验证执行模型。请严格按以下流程执行，不要扩展任务范围，不要自作主张提出未验证科研结论。

总目标：

在 `E:\Desktop\codex` 仓库中继续 R049L：基于 R049K 结果，做一个最小 explicit controlled-reentry state-machine proxy 验证。你只负责构建派生模型、运行小 chunk 仿真、做三窗口指标审计、输出结构化证据包。科研创新解释和下一步主线由监督模型根据你的结果再决定。

---

## 一、必须先读取的文件

开始前逐项读取：

1. `AGENTS.md`
2. `.engramory-memory/MEMORY.md`，如果存在
3. `docs/research_direction_after_user_feedback_20260624.md`
4. `docs/auto_research_plan_after_feedback_20260624.md`
5. `docs/ai_control_oriented_model_innovation_20260624.md`
6. `docs/adaptive_validation_automation_20260624.md`
7. `docs/control_state_machine_after_feedback.md`
8. `research-wiki/query_pack.md`
9. `research-wiki/log.md`
10. `output/iqcot_claims_evidence_matrix.md`
11. `refine-logs/LOCAL_AUDIT_R049K_PR_ECB_SOFT_REENTRY_20260625.md`
12. `docs/pr_ecb_soft_reentry_r049k.md`
13. `output/cutload_pr_ecb_control/r049k_waveform_metric_summary.md`
14. `output/cutload_pr_ecb_control/r049k_soft_reentry_results_full.csv`
15. `output/data/*r049k*soft_reentry*wave.csv`

如果涉及 Buck、VRM、COT、Simulink、`.slx`，必须应用 `power-electronics-simulink-design` 规则：

- `.slx` 是事实源。
- 只能用 MATLAB API / Simulink API 改派生副本。
- 不允许直接编辑 `.slx` XML。
- 不允许修改原始模型、R048 源派生模型、R049A-K 已完成模型。
- 修改前后必须验证旧模型没有被误动。

---

## 二、当前已知事实

最新完成状态：

- R049K 已完成并推送。
- commit: `0a14acd`
- 状态: `MODEL_REVISED`
- 模型: `output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control_r049k_soft_reentry.slx`

R049K 结论：

- A2 使用 `soft_reentry = 0.070us -> 1.760us`
- `0.05us` active-HS 行没有截断当前 pulse：
  - remaining Ton4: `52ns -> 52ns`
  - global / phase Ton truncation duration: `0us`
- qh1 在 release 后约 `1.772us` 上升
- 相比 R049J：
  - recovery undershoot penalty 从 `-2.9901/-4.1571mV` 降到 `-0.6388/-1.6588mV`
  - recovery positive peak improvement 缩窄到 `+0.1796/+0.1954mV`
  - late positive peak 轻微变差：
    - `0.05us`: `-0.1318mV`
    - `0.105us`: `-0.0223mV`

R049K 模型修订：

固定 scalar inhibit / soft-reentry window 仍然在 recovery peak、undershoot、late peak 之间 trade off，不能作为 confirmed PR-ECB action。

---

## 三、R049L 要做什么

不要做：

- 不要扩完整 A matrix。
- 不要回到 Ton floor / Ton truncation。
- 不要继续扫描固定 post-active inhibit / soft-reentry scalar window。
- 不要直接声称 controller confirmed。
- 不要把 PR-ECB 写成硬件/HIL 已验证。
- 不要把 AI 或 `T_slew` 作为主线。
- 不要把 `E_HS,rem` 写成全局加性律。

要做：

只做一个最小 explicit controlled-reentry state-machine proxy。

优先候选：

1. edge-aligned one-shot request restoration
2. phase-aware release

建议语义：

在 post-active inhibit 后，不是用固定窗口粗暴放行，而是在首个 future request / phase boundary 附近显式恢复一个 scheduler request / one pulse，然后回到正常 IQCOT 或受控 release。

---

## 四、R049L 设计约束

A0/A2 对比必须保持：

- load step: `40A -> 20A`
- offsets: `0.05us`, `0.105us`
- A0: same-model no-reentry-control
- A2: explicit controlled-reentry proxy
- Ton truncation disabled in A0 and A2
- 当前已经导通的 active-HS pulse 不能被截断

必须记录：

- `vout`
- `req_global`
- `allow_after_reentry` 或 `allow_after_inhibit`
- `reentry_state` 或等价状态信号
- `one_shot_restore` 或等价信号
- `qh1-4`
- `ql1-4`
- `phase_idx`
- `ton_trunc_global`
- `ton_truncate1-4`
- `pulse_inhibit1-4`
- `ton_cmd1-4`
- `iph_ref`

---

## 五、执行步骤清单

### Step 0: 工作树检查

运行：

```powershell
git status --short
git rev-parse --short HEAD
git log -1 --oneline
```

要求：

- HEAD 应为 `0a14acd` 或更新。
- 如果 `.gitignore` / `AGENTS.md` 有未提交改动，视为用户已有改动，不要 stage，不要修改。
- 若发现已有 R049L 文件，先报告，不要覆盖，除非确认它们是你本次创建的失败残留。

### Step 1: 离线边界检查

读取 R049K wave CSV，输出一个边界表，至少包含：

- `req_global` rising/falling edges, `0-5us`
- `allow_after_inhibit` 或 `allow_after_reentry` edges
- `soft_reentry` edges
- `qh1-4` rising/falling edges
- early/recovery/late 的 `vout` max/min

重点确认：

- `0.05us` A0:
  - qh4 falling edge 约 `0.052us`
  - qh1 future boundary 约 `1.690us`
- `0.05us` R049K A2:
  - soft_reentry fall 约 `1.760us`
  - qh1 rise 约 `1.772us`

one-shot / phase-aware release 的候选边界必须来自这些波形，不允许拍脑袋。

必须输出：

```text
R049L_BOUNDARY_TABLE.md
```

如果不单独建文件，至少要在最终报告中给出等价表。

### Step 2: 构建 R049L 派生模型

建议新增：

```text
output/iqcot_r049l_build_controlled_reentry_model.m
output/iqcot_r049l_pr_ecb_controlled_reentry_chunk.m
output/iqcot_r049l_waveform_metric_audit.py
```

建议派生模型：

```text
output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control_r049l_controlled_reentry.slx
```

源模型建议从 R049I 或 R049K 复制，但要明确说明理由：

- 如果从 R049I 复制：干净，只有继承 repaired lower bound / no Ton truncation 语义。
- 如果从 R049K 复制：可复用 request-path gate，但必须删除/替换固定 soft_reentry 语义，避免只是换名字。

不管选哪个源，都必须保证：

- 不修改 R049A-K 已完成模型。
- 不直接编辑 `.slx` XML。
- 通过 MATLAB API 添加模块、连线、日志信号。
- 新增信号名不可与旧 signal log 污染冲突。

### Step 3: dry-run

运行 MATLAB 静态检查：

```matlab
checkcode('E:/Desktop/codex/output/iqcot_r049l_build_controlled_reentry_model.m')
checkcode('E:/Desktop/codex/output/iqcot_r049l_pr_ecb_controlled_reentry_chunk.m')
```

或用可用工具做 MATLAB Code Analyzer。

然后 dry-run：

```matlab
addpath('E:/Desktop/codex/output');
rows = iqcot_r049l_pr_ecb_controlled_reentry_chunk(false);
disp(rows);
```

dry-run 必须输出 plan CSV：

```text
output/cutload_pr_ecb_control/r049l_controlled_reentry_plan.csv
```

plan 必须只有 4 行：

1. `20A off0p050 A0`
2. `20A off0p050 A2`
3. `20A off0p105 A0`
4. `20A off0p105 A2`

### Step 4: update-diagram 结构预检

必须运行非仿真 update diagram。

要求输出：

```text
UPDATE_DIAGRAM_OK model=<r049l_model_name> R049L_controlled_reentry
```

如果失败：

- 停止。
- 报告结构错误。
- 不跑真仿真。
- 不进入文档结论。

### Step 5: 运行唯一真仿真 chunk

只运行 4 行，不扩矩阵：

```matlab
addpath('E:/Desktop/codex/output');
rows = iqcot_r049l_pr_ecb_controlled_reentry_chunk(true);
disp(rows(:, {'case_id','controller','load_step_offset_us','success', ...
    'delta_v_actual_peak_mV','remaining_ton4_ns','reentry_duration_us', ...
    'one_shot_restore_count','req_edges_during_reentry','allow_edge_count', ...
    'first_reentry_us','secondary_undershoot_mV','final_error_mV'}));
```

实际列名可以按实现调整，但最终报告必须包含这些信息：

- `case_id`
- `controller`
- `load_step_offset_us`
- `success`
- `delta_v_actual_peak_mV`
- `remaining_ton4_ns`
- `reentry_duration_us` 或等价字段
- `one_shot_restore_count` 或等价字段
- `req_edges_during_reentry` 或等价字段
- `allow_edge_count`
- `first_reentry_us` / `first_restore_us`
- `secondary_undershoot_mV`
- `final_error_mV`
- `ton_trunc_global_duration_us`
- `ton_truncate1-4 duration`
- current-pulse truncation check

### Step 6: 三窗口审计

必须新增并运行：

```text
output/iqcot_r049l_waveform_metric_audit.py
```

输出：

```text
output/cutload_pr_ecb_control/r049l_waveform_metric_case_windows.csv
output/cutload_pr_ecb_control/r049l_waveform_metric_pair_delta.csv
output/cutload_pr_ecb_control/r049l_waveform_metric_summary.md
```

窗口定义必须和 R049H 一致：

- `0-2us` early local peak
- `2-12us` recovery peak
- `12-80us` late settling / undershoot

额外必须报告：

- recovery undershoot penalty
- late positive peak penalty
- current-pulse truncation check
- first restore / one-shot timing
- one-shot state 是否真的按预期触发

### Step 7: 判定规则

R049L 状态只能是下面四个之一：

```text
MODEL_CONFIRMED
MODEL_REVISED
IMPLEMENTATION_ISSUE
CLAIM_DOWNGRADED
```

`IMPLEMENTATION_ISSUE`：

- 任意 case 仿真失败
- update-diagram 失败
- A2 误触当前 active-HS pulse
- remaining Ton4 被减少超过 `1ns`
- `ton_trunc_global` 或 `ton_truncate1-4` 非零
- one-shot / phase-aware state 没有按预期触发
- 日志缺关键字段

`MODEL_CONFIRMED`：

同时满足：

- early local peak 不变或改善
- current active pulse 不截断
- recovery positive peak 有明确收益
- recovery undershoot penalty 显著低于 R049K
- late positive peak penalty 显著低于 R049K 或接近 0
- one-shot / phase-aware reentry 语义成立

参考 R049K 基线：

```text
R049K recovery undershoot penalty:
0.05us: -0.6388mV
0.105us: -1.6588mV

R049K recovery peak improvement:
0.05us: +0.1796mV
0.105us: +0.1954mV

R049K late peak penalty:
0.05us: -0.1318mV
0.105us: -0.0223mV
```

`CLAIM_DOWNGRADED`：

- current pulse 不截断
- one-shot / phase-aware 边界更清楚
- 但 recovery 收益太窄，不能支撑 confirmed action

`MODEL_REVISED`：

- 仍有明显 recovery undershoot / late peak penalty
- 或收益与副作用 trade-off 仍然存在
- 或 explicit reentry 思路需要进一步改状态机

### Step 8: 输出文件要求

无论结果好坏，都要输出一个结构化结果包：

```text
docs/pr_ecb_controlled_reentry_r049l.md
refine-logs/LOCAL_AUDIT_R049L_PR_ECB_CONTROLLED_REENTRY_20260625.md
output/cutload_pr_ecb_control/r049l_controlled_reentry_results_full.csv
output/cutload_pr_ecb_control/r049l_controlled_reentry_comparison_full.csv
output/cutload_pr_ecb_control/r049l_controlled_reentry_report_full.md
output/cutload_pr_ecb_control/r049l_waveform_metric_summary.md
output/data/*r049l*controlled_reentry*wave.csv
```

报告必须包含：

1. Scope
2. Source model
3. Exact reentry proxy design
4. Boundary evidence from R049K wave
5. A0/A2 plan
6. Structural validation result
7. Per-case simulation table
8. Three-window audit table
9. Current-pulse truncation check
10. R049K comparison table
11. Decision
12. Diagnosis
13. Claim boundary
14. Proposed next step, but only as evidence-based suggestion

### Step 9: 文档同步范围

如果被授权修改仓库，则同步这些文件：

- `docs/ai_control_oriented_model_innovation_20260624.md`
- `docs/control_state_machine_after_feedback.md`
- `docs/adaptive_validation_automation_20260624.md`
- `docs/auto_research_plan_after_feedback_20260624.md`
- `research-wiki/query_pack.md`
- `research-wiki/log.md`
- `output/iqcot_claims_evidence_matrix.md`

注意：

- 只写事实和安全措辞。
- 不写硬件/HIL 已验证。
- 不写“完整 PR-ECB 控制器已完成”。
- 不写“AI 替代 IQCOT 内环”。
- 不写“`E_HS,rem` 是全局加性律”。

### Step 10: 提交前验证

提交前必须运行：

```powershell
python -m py_compile output/iqcot_r049l_waveform_metric_audit.py
git diff --name-only -- '*.slx'
git status --short
git diff --cached --check
```

MATLAB：

```matlab
checkcode('E:/Desktop/codex/output/iqcot_r049l_build_controlled_reentry_model.m')
checkcode('E:/Desktop/codex/output/iqcot_r049l_pr_ecb_controlled_reentry_chunk.m')
```

要求：

- 旧 `.slx` 没有 modified diff。
- 只有 R049L 新 `.slx` 是新增。
- `.gitignore` 和 `AGENTS.md` 如果是用户原有改动，不要 stage。
- MATLAB Code Analyzer 不能有 error，info 可以接受。
- `git diff --cached --check` 必须干净。

---

## 六、最终交付模板

请最终输出以下模板：

```text
R049L 执行完成。

状态: <MODEL_CONFIRMED / MODEL_REVISED / IMPLEMENTATION_ISSUE / CLAIM_DOWNGRADED>

1. 派生模型
- <path>

2. 设计语义
- source model:
- A2 reentry proxy:
- one-shot / phase-aware boundary:
- 是否截断 current active-HS pulse:

3. 关键结果
| offset | early peak Δ | recovery peak improvement | recovery undershoot penalty | late peak penalty | remaining Ton4 | one-shot count |
|---|---:|---:|---:|---:|---:|---:|

4. 相对 R049K 是否改善
- recovery undershoot:
- recovery peak:
- late peak:
- current-pulse truncation:

5. 质量门
- MATLAB static check:
- update diagram:
- true-run cases:
- Python audit:
- old .slx untouched:
- git diff check:

6. 证据文件
- results csv:
- comparison csv:
- wave audit summary:
- refine log:
- docs report:

7. 不确定性 / 失败点
- ...

8. 给监督模型的建议
- 下一步应当:
- 不应当:
```

如果仿真或结构检查失败，不要硬凑结论，直接输出：

```text
状态: IMPLEMENTATION_ISSUE
阻塞点:
复现命令:
错误日志:
已确认未误动的文件:
建议的最小修复:
```

---

## 七、监督模型将如何使用你的结果

执行模型只需要把 R049L 证据包交回来。监督模型会根据结果决定：

- 是否将 explicit controlled reentry 写入 PR-ECB 主线；
- 是否降级 request-path reentry claim；
- 是否转向 phase-aware release、PIS-IEK balance recovery，或 variable-phase event management；
- 是否更新自动化 prompt 到 R049M。

不要由执行模型自行扩大科研结论。
