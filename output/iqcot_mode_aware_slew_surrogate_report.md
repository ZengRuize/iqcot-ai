# R025 mode-aware 连续 `T_slew` score surrogate 与安全投影

## 目的

R024 显示 `T_slew` 分数景观存在 skip/reentry 与相位指标造成的非光滑跳变。R025 不运行新的 `.slx`，而是把 dense+long+fine 派生 Simulink 结果组织为一个可解释 score surrogate 与策略后处理问题。

## 数据

- 源 plant rows：`69` 个目标/斜率组合。
- objective-expanded rows：`207` 行。
- 特征包括 `target_load_A`、`alpha_settle`、`ref_slew_us`、`skip_count_est`、`final_phase_spacing_std_ns`、`settle_time_us`。
- mode-aware 特征是后处理指标；若用于真实 AI，它们必须由事件状态估计器或预测器提前给出。

## Surrogate 误差

| model | split | n_rows | rmse | mae | max_abs_error |
| --- | --- | --- | --- | --- | --- |
| smooth_quadratic_context | in_sample | 207 | 0.855 | 0.638 | 2.369 |
| mode_aware_score_surrogate | in_sample | 207 | 0.101 | 0.074 | 0.408 |
| smooth_quadratic_context | leave_one_target | 207 | 10.192 | 9.706 | 16.159 |
| mode_aware_score_surrogate | leave_one_target | 207 | 5.940 | 5.720 | 8.614 |

## 策略汇总

| policy | n_contexts | mean_regret | max_regret | mean_score | mean_skip | mean_phase_std_ns | mean_settle_time_us |
| --- | --- | --- | --- | --- | --- | --- | --- |
| combined_grid_oracle | 9 | 0.000 | 0.000 | 10.094 | 1.000 | 70.986 | 19.359 |
| mode_aware_safety_projection | 9 | 0.064 | 0.235 | 10.158 | 1.000 | 72.974 | 18.609 |
| near_opt_band_clipping | 9 | 0.101 | 0.209 | 10.195 | 1.000 | 75.307 | 21.120 |
| discrete_dense_long_table | 9 | 0.163 | 0.490 | 10.257 | 1.000 | 74.475 | 18.528 |
| naked_quadratic_continuous | 9 | 0.654 | 2.429 | 10.749 | 1.222 | 75.173 | 22.203 |

## 关键解释

- `naked_quadratic_continuous` 故意忽略模式指标，只用平滑二次曲线选择连续斜率；它用于暴露 R024 所说的非光滑风险。
- `near_opt_band_clipping` 把裸连续候选裁剪到已仿真的 `best+0.25` 经验近优带内，体现连续动作的保守落地方式。
- `mode_aware_safety_projection` 在 `best+0.50` 带内加入 skip、phase std 和 settling 约束，再用 mode-aware surrogate 选择动作；它是离线设计规则，不是硬件安全证明。
- `combined_grid_oracle` 是当前已仿真网格下界；论文中不能把它写成可部署 AI。

## 结论边界

- 不声称 `T_slew` 有全局最优。
- 不声称 mode-aware surrogate 已完成神经网络 AI-in-loop 或硬件验证。
- 不声称 R025 的安全投影是硬件安全集合；它只是基于当前派生 Simulink 数据的设计带。
