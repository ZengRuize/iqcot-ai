# Experiment Results: Controlled Dynamic Load Cut-Load Validation

## 目的

前一轮 state-carry 验证通过两段仿真继承 final state 来模拟切载，能够快速暴露 skip/reentry 趋势，但仍不是连续动态负载模型。本轮实验把 `four_phase_iek_perphase_trim.slx` 复制为 `four_phase_iek_dynamic_load.slx`，并用 Specialized Power Systems 的 `Controlled Current Source` 替换静态 `Series RLC Branch8` 负载，从而在同一次仿真中施加 `Iload_initial -> Iload_final` 连续阶跃。

该实验仍保持控制器参考 `Iph=40A/4` 不变，因此对应 state-carry 中的 `hold` 参考处理。`instant` 参考需要进一步把控制器内部 `Iph` 常量改为同步阶跃信号，尚未在本轮实现。

## 输出文件

- `E:/Desktop/codex/output/iqcot_dynamic_load_validation.m`
- `E:/Desktop/codex/output/simulink_iek/four_phase_iek_dynamic_load.slx`
- `E:/Desktop/codex/output/iqcot_dynamic_load_summary.csv`
- `E:/Desktop/codex/output/iqcot_dynamic_load_wave_samples.csv`
- `E:/Desktop/codex/output/iqcot_dynamic_load_report.md`
- `E:/Desktop/codex/output/figures/fig22_dynamic_load_validation.png`
- `E:/Desktop/codex/output/iqcot_dynamic_vs_statecarry_comparison.csv`

## 动态负载结果

| Case | Overshoot | Undershoot | Estimated skip | Final phase std | Final current imbalance |
|---|---:|---:|---:|---:|---:|
| `40A -> 20A` | `2.475 mV` | `0.992 mV` | `1` | `40.094 ns` | `0.166 A` |
| `40A -> 10A` | `4.196 mV` | `4.292 mV` | `1` | `79.875 ns` | `0.184 A` |
| `40A -> near-0A` | `6.817 mV` | `9.451 mV` | `2` | `103.595 ns` | `0.569 A` |

## 与 state-carry hold 的对照

| Target load | Dynamic overshoot | State-carry overshoot | Dynamic undershoot | State-carry undershoot | Dynamic skip | State-carry skip |
|---:|---:|---:|---:|---:|---:|---:|
| `20A` | `2.475 mV` | `2.488 mV` | `0.992 mV` | `-0.996 mV` | `1` | `0` |
| `10A` | `4.196 mV` | `3.795 mV` | `4.292 mV` | `-2.248 mV` | `1` | `1` |
| `near-0A` | `6.817 mV` | `5.810 mV` | `9.451 mV` | `-2.872 mV` | `2` | `1` |

## 结论

1. 动态负载验证保留了 state-carry 的主要趋势：切载越深，过压峰值、相位间隔扰动和 skip 数增加。
2. 动态负载比 state-carry 更严格。连续电流阶跃引入了真实欠压谷值，尤其在 `40A->near-0A` 中欠压达到 `9.451 mV`，而 state-carry hold 没有暴露这一点。
3. 近空载切载的 estimated skip 从 state-carry 的 `1` 增加到动态负载的 `2`，说明混合事件模型中的 `skip/reentry` 模式不是 state-carry 伪影。
4. `settle_time` 为 `NaN` 的原因是 90 us 后仍存在超过 `2 mV` 的尾部误差，尤其 hold reference 保持 `Iph=10A` 会造成轻载下参考-物理负载失配。这是后续实现同步 `Iph` 阶跃的理由。

## 对论文主张的影响

这组结果把 PIS-IEK 混合事件建模 claim 从“state-carry surrogate 支持”推进到“开关级连续动态负载副本支持”。论文中可以更有底气地说：

> Continuous controlled-load simulations confirm that large cut-load transitions drive the four-phase IQCOT event stream into skip/reentry regimes that a single small-signal Jacobian cannot represent.

但仍应保留边界：当前动态负载只验证了 `hold` 参考；若要讨论 AI 或 `instant` reference 调度，需要进一步把 `Iph` 与 AI 参数 schedule 接入 Simulink 副本。

