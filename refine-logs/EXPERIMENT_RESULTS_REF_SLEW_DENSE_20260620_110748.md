# Experiment Results: Dense Dynamic Iph Reference Slew Sweep

## 目的

上一轮 `T_slew=0,5,10,20,40 us` 扫描证明参考斜率是有效的低维调度变量，但 `40 us` 位于扫描上边界，无法判断更慢参考是否继续改善折中。本轮围绕 `20-80 us` 做更密集开关级 Simulink 扫描，以验证最佳区域是否仍在 40 us 附近。

## 模型与脚本

- 模型副本：`E:/Desktop/codex/output/simulink_iek/four_phase_iek_dynamic_load_refslew.slx`
- 脚本：`E:/Desktop/codex/output/iqcot_dynamic_ref_slew_sweep.m`
- 运行命令：`iqcot_dynamic_ref_slew_sweep([20 30 40 50 60 80], "dense")`

原始模型未被修改。脚本仍通过 `From Workspace` 驱动 `IEK_PerPhase_Request/Iph1..4` 与 `IQCOT_Ton_Adapter/Iref_Phase`，负载为受控电流源切载。

## 扫描规模

- 切载：`40A->20A`, `40A->10A`, `40A->near-0A`
- 参考过渡时间：`20,30,40,50,60,80 us`
- 总开关级 Simulink 工况：`18`
- 全部工况：成功

## 输出文件

- `E:/Desktop/codex/output/iqcot_dynamic_ref_slew_dense_summary.csv`
- `E:/Desktop/codex/output/iqcot_dynamic_ref_slew_dense_wave_samples.csv`
- `E:/Desktop/codex/output/iqcot_dynamic_ref_slew_dense_best_summary.csv`
- `E:/Desktop/codex/output/iqcot_dynamic_ref_slew_dense_report.md`
- `E:/Desktop/codex/output/figures/fig23_dynamic_ref_slew_dense_sweep.png`

## 最佳折中点

当前 tradeoff score 仍定义为：

```text
score = |final_vout_error_mV| + undershoot_mV + 0.02*phase_std_ns + 2*skip_count
```

| Target load | Best slew | Undershoot | Final error | Skip | Phase std | Score |
|---:|---:|---:|---:|---:|---:|---:|
| `20A` | `80 us` | `1.094 mV` | `-0.436 mV` | `0` | `37.140 ns` | `2.273` |
| `10A` | `80 us` | `4.631 mV` | `-0.551 mV` | `1` | `82.183 ns` | `8.825` |
| `near-0A` | `60 us` | `10.452 mV` | `-0.543 mV` | `2` | `90.263 ns` | `16.801` |

## 与近似 instant 的对比

| Target load | Instant undershoot | Best slew | Best undershoot | Reduction |
|---:|---:|---:|---:|---:|
| `20A` | `13.466 mV` | `80 us` | `1.094 mV` | `91.87%` |
| `10A` | `23.830 mV` | `80 us` | `4.631 mV` | `80.57%` |
| `near-0A` | `35.750 mV` | `60 us` | `10.452 mV` | `70.76%` |

## 与上一轮 `40 us` 结论的关系

上一轮不能把 `40 us` 写成全局最优，因为它正好在扫描边界。本轮验证了这一点：更慢参考可以进一步改善 tradeoff score。

| Target load | `40 us` score | Dense best | Best score | Score improvement |
|---:|---:|---:|---:|---:|
| `20A` | `2.500` | `80 us` | `2.273` | `9.09%` |
| `10A` | `9.385` | `80 us` | `8.825` | `5.97%` |
| `near-0A` | `17.684` | `60 us` | `16.801` | `4.99%` |

## 关键解释

密集扫描强化了一个更稳健的论文结论：`Iph_ref` 参考斜率确实是可调度的物理参数，而不是 40 us 单点偶然。对 20A 和 10A 切载，更慢的 `80 us` 在当前评分下最好；对 near-0A，`80 us` 虽有更低欠压 `10.151 mV`，但 phase-spacing 标准差升至 `123.524 ns` 且最终误差略变大，因此当前 score 选择 `60 us`。

这说明 AI 调度目标不应只最小化欠压，还要同时考虑 settling、phase-spacing 和 final error。PIS-IEK 的价值正是在事件域提供这些代价项的低维、物理可解释表示。

## 边界

- `80 us` 和 `60 us` 仍不是全局最优，只是当前 `20-80 us` 密集网格中的最佳折中点。
- 本轮没有引入 AI-in-the-loop，只验证 `T_slew` 动作本身的开关级价值。
- 后续若要把该结论做强，需要扫描 `80 us` 以上，或让 AI/优化器把 `T_slew` 作为连续动作学习。
