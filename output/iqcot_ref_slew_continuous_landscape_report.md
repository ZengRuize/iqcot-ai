# R023 连续 `T_slew` 分数景观与安全区间后处理

## 目的

R022 说明离散候选策略的可解释监督层能够近似 delayed-reference 策略排序，但仍停留在固定 `30/40/50/60/80 us` 等标签。R023 使用已有 dense+long 开关级 sweep，评估连续 `T_slew` 动作是否值得进入下一轮 Simulink 验证。

本实验只做后处理，不运行新的 `.slx`。局部二次候选点是“下一轮仿真候选”，不是全局最优，也不是硬件结果。

## 方法

- 输入：`E:/Desktop/codex/output/iqcot_dynamic_ref_slew_dense_long_combined_scores.csv`，覆盖 `T_slew=20/30/40/50/60/80/100/120 us`、`3` 个切载目标。
- 对每个目标和目标函数，选择采样最优点附近三点做局部二次拟合。
- 在 `20-120 us` 内做 `1 us` piecewise-linear 重采样，计算 `best+0.25` 与 `best+0.50` 的 near-optimal 区间。
- 额外给出一个保守设计带：`score <= best+0.50`、插值 skip 不高于采样最优、phase std 不超过 `120 ns`。这只是设计启发，不是安全证明。

## 汇总结果

| target_label | objective | sampled_best_us | sampled_best_score | local_quad_candidate_us | local_quad_est_score | estimated_continuous_gain | near_opt_0p50_segments_us | safe_band_segments_us | decision |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 20A | score_settle010 | 30.000 | 2.540 | 34.744 | 2.301 | 0.238 | 28-42 | 29-41 | requires_new_switching_validation |
| 20A | score_settle005 | 30.000 | 2.493 | 34.744 | 2.255 | 0.238 | 28-42 | 29-41 | requires_new_switching_validation |
| 20A | base | 80.000 | 2.273 | 87.244 | 2.118 | 0.154 | 29-41;76-101 | 29-41;78-101 | fine_sweep_candidate |
| 10A | score_settle010 | 30.000 | 11.022 | 25.844 | 11.011 | 0.011 | 20-53 | 20-53 | discrete_grid_sufficient |
| 10A | score_settle005 | 50.000 | 10.008 | 47.225 | 9.964 | 0.044 | 20-26;31-55 | 20-26;31-55 | discrete_grid_sufficient |
| 10A | base | 80.000 | 8.825 | 82.773 | 8.816 | 0.009 | 42-57;64-120 | 42-57;64-120 | discrete_grid_sufficient |
| near0A | score_settle010 | 30.000 | 19.784 | 34.633 | 19.545 | 0.239 | 28-58 | 28-58 | requires_new_switching_validation |
| near0A | score_settle005 | 60.000 | 18.567 | 57.251 | 18.552 | 0.015 | 30-69 | 30-69 | discrete_grid_sufficient |
| near0A | base | 60.000 | 16.801 | 65.710 | 16.724 | 0.077 | 51-120 | 51-77;84-120 | fine_sweep_candidate |

## 关键观察

1. 最大局部二次估计收益为 `0.239` 分；这表明连续动作可能带来细小收益，但没有证据支持“连续回归会大幅超过当前采样表”。
2. `4` 个目标/工况的估计收益低于 `0.05`，可视为当前离散网格已足够；`2` 个目标/工况适合做小范围更细 sweep；`3` 个目标/工况需要新开关级仿真确认。
3. near-optimal 区间通常比单点最优更有工程意义。AI 监督层可以优先学习“安全区间内选择”，而不是执着输出一个尖锐最优 `T_slew`。
4. 若后续训练连续动作 AI，reward 应惩罚超出 near-optimal/safe band 的动作，并保留 `tau_AI` 延迟缓冲；AI 仍不能替代 IQCOT 内环。

## 输出文件

- `E:/Desktop/codex/output/iqcot_ref_slew_continuous_landscape_summary.csv`
- `E:/Desktop/codex/output/iqcot_ref_slew_continuous_landscape_grid.csv`
- `E:/Desktop/codex/output/figures/fig30_ref_slew_continuous_landscape.svg`

## 结论边界

- 不声称任何局部二次候选是全局最优。
- 不声称插值曲线等于新的开关级仿真。
- 不把 safe band 当成硬件安全证明。
- 该结果只用于指导下一轮更细 `T_slew` sweep 或连续动作 AI 前置训练。
