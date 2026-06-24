# Experiment Results: PIS-IEK Cut-Load State-Carry Validation

## 目的

本轮验证的目标不是直接证明 AI 控制有效，而是先回答一个更基础的问题：四相数字 IQCOT 在切载后是否会进入普通小信号 Jacobian 无法覆盖的事件模式，例如 pulse skipping、reentry 和相位间隔扰动。如果这些模式确实出现，那么 PIS-IEK 小信号模型需要扩展为混合事件模型，AI 调参也必须被建模为延迟感知、模式感知的低维参数调节，而不是高速逐脉冲替代控制器。

## 方法

脚本：

- `E:/Desktop/codex/output/iqcot_cutload_statecarry_validation.m`

输出：

- `E:/Desktop/codex/output/iqcot_cutload_statecarry_summary.csv`
- `E:/Desktop/codex/output/iqcot_cutload_statecarry_wave_samples.csv`
- `E:/Desktop/codex/output/iqcot_cutload_statecarry_report.md`
- `E:/Desktop/codex/output/figures/fig20_cutload_statecarry_validation.png`

仿真采用两段状态继承方法：

1. 在 `40 A` 下运行四相 PIS-IEK Simulink 副本到稳态，并保存 final state。
2. 从同一 final state 重新启动仿真，将负载切换到 `20 A`、`10 A`、近似空载。
3. 比较两种控制器参考处理：
   - `hold`：物理负载改变，但面积核参考 `Iph` 仍保持 `40 A / 4`。
   - `instant`：物理负载与面积核参考 `Iph` 同时切换到目标负载。

## 主要数据

| Case | Controller ref | Overshoot | Undershoot | Estimated skip | Settling time | Final phase std | Final current imbalance |
|---|---|---:|---:|---:|---:|---:|---:|
| `40A -> 20A` | `hold` | `2.488 mV` | `-0.996 mV` | `0` | `89.952 us` | `49.762 ns` | `0.235 A` |
| `40A -> 20A` | `instant` | `1.739 mV` | `2.860 mV` | `1` | `6.212 us` | `43.880 ns` | `0.310 A` |
| `40A -> 10A` | `hold` | `3.795 mV` | `-2.248 mV` | `1` | `NaN` | `92.780 ns` | `0.307 A` |
| `40A -> 10A` | `instant` | `3.440 mV` | `9.880 mV` | `1` | `13.626 us` | `114.197 ns` | `0.177 A` |
| `40A -> near-0A` | `hold` | `5.810 mV` | `-2.872 mV` | `1` | `NaN` | `108.984 ns` | `0.500 A` |
| `40A -> near-0A` | `instant` | `5.810 mV` | `20.416 mV` | `2` | `20.036 us` | `116.749 ns` | `0.610 A` |

## 结论

1. 切载幅度越大，估计 skip 次数和相位间隔扰动越明显。`40A->10A` 与 `40A->near-0A` 已经不适合用单一连续小信号 Jacobian 覆盖全过程。
2. 面积核参考瞬时下调不一定更优。`instant` 在大切载下会显著放大欠压侧扰动和相位恢复负担，说明 AI 调参不能只学习“响应越快越好”的黑箱策略。
3. PIS-IEK 的实际价值在于把切载后系统拆成 `normal/skip/reentry/saturation` 等事件模式，并为 AI 动作提供安全投影和延迟预算，而不是单独预测大切载第一峰值。
4. 当前结果仍是 state-carry surrogate，不是最终动态负载等价模型。下一步应在 `.slx` 副本中使用 MATLAB API 加入受控动态负载，复核同一 skip/reentry 现象是否在连续负载阶跃中复现。

## 对论文主张的影响

这组结果支持一个更严谨的创新表述：

> 本文提出的 PIS-IEK 小信号模型不是单一线性化模型，而是可扩展到相位索引、事件核和模式切换的 lifted hybrid model。它能够解释四相数字 IQCOT 在切载后从常规事件流进入 skip/reentry 的边界，并为 FPGA 上 us 级 AI 参数调节提供延迟感知的状态表示与安全约束。

