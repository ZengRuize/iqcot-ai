# Experiment Results: Dynamic Iph Reference Slew Sweep

## 目的

`dynamic_hold` 与 `dynamic_instant` 已经证明了一个关键 trade-off：参考保持不变可以减小切载欠压，但最终电压静差较大；参考瞬时下调可以减小最终静差，但会显著放大切载欠压。本轮实验把这个二选一问题改成连续调度问题：让 `Iph_ref` 在 `0, 5, 10, 20, 40 us` 内从 `40A/4` 线性过渡到目标负载/4。

模型副本：

- `E:/Desktop/codex/output/simulink_iek/four_phase_iek_dynamic_load_refslew.slx`

脚本：

- `E:/Desktop/codex/output/iqcot_dynamic_ref_slew_sweep.m`

输出：

- `E:/Desktop/codex/output/iqcot_dynamic_ref_slew_summary.csv`
- `E:/Desktop/codex/output/iqcot_dynamic_ref_slew_wave_samples.csv`
- `E:/Desktop/codex/output/iqcot_dynamic_ref_slew_report.md`
- `E:/Desktop/codex/output/iqcot_dynamic_ref_slew_best_summary.csv`
- `E:/Desktop/codex/output/figures/fig23_dynamic_ref_slew_sweep.png`

## 扫描规模

- 切载：`40A->20A`, `40A->10A`, `40A->near-0A`
- 参考过渡时间：`0, 5, 10, 20, 40 us`
- 总开关级 Simulink 仿真：`15`

`0 us` 工况在实现上使用一个 `5 ns` 的极快线性过渡，以避免 timeseries 重复时间点；它可视为 `dynamic_instant` 的近似。

## 最优折中点

当前 tradeoff score 定义为：

```text
score = |final_vout_error_mV| + undershoot_mV + 0.02*phase_std_ns + 2*skip_count
```

在该指标下，三个切载深度的最佳点均出现在 `40 us`：

| Target load | Best slew | Undershoot | Final error | Skip | Phase std | Score |
|---:|---:|---:|---:|---:|---:|---:|
| `20A` | `40 us` | `1.199 mV` | `-0.434 mV` | `0` | `43.336 ns` | `2.500` |
| `10A` | `40 us` | `5.010 mV` | `-0.549 mV` | `1` | `91.296 ns` | `9.385` |
| `near-0A` | `40 us` | `10.897 mV` | `-0.569 mV` | `2` | `110.846 ns` | `17.684` |

## 关键观察

1. 参考斜率显著降低 `dynamic_instant` 的欠压风险。以 `40A->near-0A` 为例，`0 us` 近似 instant 的欠压为 `35.750 mV`，`40 us` 降为 `10.897 mV`。
2. 参考斜率仍保留了较小最终静差。`40 us` 下三个切载工况的 final Vout error 约为 `-0.43` 到 `-0.57 mV`，明显优于 `dynamic_hold` 的正静差。
3. 对 `40A->20A`，`40 us` 不仅欠压低，而且 estimated skip 从 `1` 降为 `0`，说明参考调度可以直接改善事件序列质量。
4. `40 us` 是当前扫描网格中的最佳点，不应声称为全局最优。后续可围绕 `20-80 us` 做更密集扫描或让 AI 学习连续动作。

## 对 AI 调参的含义

这组结果把 AI 价值从“可以调参”进一步具体化为：

> AI 可以学习 `Iph_ref` 的过渡时间/斜率，使参考更新既不过慢导致静差，也不过快导致切载欠压和 skip/reentry 加剧。

因此建议把 AI 动作空间扩展为：

```text
u = [Delta Lambda_diff, Delta Ton_diff, Delta Iph_ref, ref_slew_time]
```

其中 `ref_slew_time` 是本轮仿真证明有物理意义的低维调度变量。

