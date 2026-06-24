# Experiment Results: Dynamic Load With Synchronous Iph Reference Step

## 目的

上一轮受控动态负载只完成 `dynamic_hold`：物理负载连续阶跃，但控制器参考 `Iph` 保持 `40A/4`。本轮进一步构建 `four_phase_iek_dynamic_load_refstep.slx`，把以下内部常量替换为同步 Step：

- `IEK_PerPhase_Request/Iph1`
- `IEK_PerPhase_Request/Iph2`
- `IEK_PerPhase_Request/Iph3`
- `IEK_PerPhase_Request/Iph4`
- `IQCOT_Ton_Adapter/Iref_Phase`

因此 `dynamic_instant` 同时完成物理负载阶跃和控制器参考阶跃，可与 state-carry 的 `instant` 思路对齐。

## 关键数据

| Case | Mode | Overshoot | Undershoot | Skip | Settling | Final Vout error | Phase std | Current imbalance |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| `40A -> 20A` | `hold` | `2.475 mV` | `0.992 mV` | `1` | `NaN` | `2.058 mV` | `40.094 ns` | `0.166 A` |
| `40A -> 20A` | `instant` | `2.235 mV` | `13.466 mV` | `1` | `18.256 us` | `-0.435 mV` | `41.954 ns` | `0.252 A` |
| `40A -> 10A` | `hold` | `4.196 mV` | `4.292 mV` | `1` | `NaN` | `3.199 mV` | `79.875 ns` | `0.184 A` |
| `40A -> 10A` | `instant` | `4.196 mV` | `23.830 mV` | `2` | `22.384 us` | `-0.563 mV` | `87.335 ns` | `0.362 A` |
| `40A -> near-0A` | `hold` | `6.817 mV` | `9.451 mV` | `2` | `NaN` | `4.413 mV` | `103.595 ns` | `0.569 A` |
| `40A -> near-0A` | `instant` | `6.817 mV` | `35.750 mV` | `2` | `24.970 us` | `-0.566 mV` | `108.304 ns` | `0.153 A` |

输出文件：

- `E:/Desktop/codex/output/iqcot_dynamic_load_summary.csv`
- `E:/Desktop/codex/output/iqcot_dynamic_reference_mode_comparison.csv`
- `E:/Desktop/codex/output/simulink_iek/four_phase_iek_dynamic_load_refstep.slx`
- `E:/Desktop/codex/output/figures/fig22_dynamic_load_validation.png`

## 结论

1. `dynamic_instant` 会显著降低最终电压静差：例如近空载从 `+4.413 mV` 变为 `-0.566 mV`。
2. 代价是切载欠压大幅增加：`40A->near-0A` 从 `9.451 mV` 增至 `35.750 mV`，`40A->10A` 从 `4.292 mV` 增至 `23.830 mV`。
3. 中等和大切载下 `instant` 也会增加 skip 或相位扰动：`40A->10A` 的 estimated skip 从 `1` 增到 `2`。
4. 这为 AI 调参提供了更强动机：AI 不应简单学习“参考越快越好”，而应在 PIS-IEK 的事件模式和安全约束下选择分段、延迟感知、幅度受限的参考/参数更新策略。

## 论文表述建议

可写为：

> Continuous dynamic-load simulations show a nontrivial trade-off between reference tracking and cut-load safety. Synchronous Iph reference stepping reduces steady-state voltage error but can strongly amplify undershoot and skip/reentry activity. This trade-off motivates the use of PIS-IEK as a constraint-aware state representation for AI parameter scheduling.

