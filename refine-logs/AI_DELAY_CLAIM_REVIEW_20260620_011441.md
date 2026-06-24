# Reviewer-Style Claim Review: AI Delay + PIS-IEK

## Verdict

当前 AI 延迟实验可以支撑“PIS-IEK 有助于延迟感知 AI 参数调节”的中等强度 claim，但还不能支撑“AI 控制显著优于传统 IQCOT”或“该策略已在开关级动态负载下验证”的强 claim。

## Supported Claims

| Claim | Status | Evidence |
|---|---|---|
| FPGA `us` 级推理延迟应转写为 IQCOT 事件域滞后 | Strong | `T_event=0.5us`，`tau_AI=5us` 对应 10 个事件 |
| 零延迟训练在大延迟部署时会出现 train-test mismatch | Moderate | `40A->near-0A`, `T_update=5us`, `tau_AI=5us` 下 violation 从 `147.875` 降至 `24.297` |
| PIS-IEK 可提供低维动作通道和安全投影接口 | Moderate | 已结合 `Lambda_diff/Ton_diff` 灵敏度和 projection surrogate |
| 延迟感知策略在所有延迟下都更优 | Not supported | `tau_AI=1us` 下 zero-delay-trained 反而更优 |
| 当前结果足以替代 Simulink 动态负载验证 | Not supported | 当前仍是 event-domain surrogate |

## Main Weaknesses

1. `iqcot_ai_delay_event_surrogate.py` 是低阶 surrogate，而非 `.slx` 开关级动态负载仿真。论文中必须把它定位为训练环境与假设检验，不应当作最终硬件等价证据。
2. safety projection 的收益主要出现在大延迟/严苛切载下；小延迟时它可能过于保守。因此推荐写成“延迟阈值识别 + 大延迟保护”，不要写成“普适最优”。
3. 当前 reward/violation 阈值仍由 surrogate 设定，后续需要在 Simulink 副本中用真实电压、电流和 gate event 日志复核。

## Recommended Next Experiment

构建受控动态负载 `.slx` 副本，在同一个模型中完成 `40A->20A/10A/near-0A` 连续切载，而不是两段 state-carry。将以下策略作为外部参数 schedule 注入：

- `zero_delay_trained`
- `delay_aware`
- `delay_aware_projected`

若开关级仿真也复现 `5us` 延迟下 zero-delay 策略恶化、delay-aware/projection 降低相位和均流尾部误差，则 AI 延迟建模 claim 可从 moderate 提升到 strong。

## Writing Recommendation

论文中建议把这一节放在“小信号模型对 AI 控制的价值”之后，作为 deployment-aware extension。标题可以是：

> Delay-aware AI parameter tuning enabled by the PIS-IEK event model

核心句：

> PIS-IEK does not make AI faster; it makes AI training honest about the delayed event coordinates in which FPGA deployment actually operates.

