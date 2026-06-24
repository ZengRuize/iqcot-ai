# R026 可部署 `T_slew` 风险 proxy 与安全投影验证

## 目的

R025 的 mode-aware 投影使用 `skip_count_est`、相位间隔标准差和恢复时间等后验指标，不能直接被在线 AI 监督层读取。R026 将这一步拆成两个可审查接口：

1. `parametric_proxy_only`：只用 `target_load_A`、`load_drop_norm`、`alpha_settle`、`T_slew` 和 `tau_AI` 拟合风险，作为负面对照。
2. `calibrated_risk_proxy_projection`：把离线开关级细扫得到的模式风险固化为 `r_hat(z,T_slew)` 校准表，再与平滑 score surrogate 组合做投影。

这两个接口都不替代 IQCOT 内环；它们只给监督层提交 `T_slew` 前的安全选择规则。

## 数据与输入边界

- R025 objective-level rows：`9 contexts x 5 tau settings` 的策略重放。
- 校准风险表 plant rows：`69` 个 `target/ref_slew` 点。
- 在线可得输入限定为：`target_load_A`、`load_drop_norm`、`alpha_settle`、候选 `T_slew`、`tau_AI`/`delay_events`，以及离线预存的风险 proxy 表或短时预测器输出。
- `skip_count_est`、`phase_std_ns` 和 `settle_time_us` 在报告表中只作为评价标签；不把它们写成在线可直接观测量。

## Proxy 拟合与泛化检查

| model | target | split | n_rows | rmse | mae | accuracy | precision | recall |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| deployable_score_smooth | objective_score | in_sample | 207 | 0.855 | 0.638 |  |  |  |
| parametric_phase_proxy | final_phase_spacing_std_ns | in_sample | 69 | 9.580 | 7.393 |  |  |  |
| parametric_settle_proxy | settle_time_us | in_sample | 69 | 2.226 | 1.480 |  |  |  |
| parametric_excess_skip_proxy | excess_skip_count | in_sample | 69 | 0.319 | 0.222 | 0.855 | 0.625 | 0.417 |
| deployable_score_smooth | objective_score | leave_one_target:20A | 69 | 10.613 | 10.505 |  |  |  |
| parametric_phase_proxy | final_phase_spacing_std_ns | leave_one_target:20A | 23 | 36.617 | 35.085 |  |  |  |
| parametric_settle_proxy | settle_time_us | leave_one_target:20A | 23 | 17.686 | 17.336 |  |  |  |
| parametric_excess_skip_proxy | excess_skip_count | leave_one_target:20A | 23 | 0.609 | 0.451 | 0.565 | 0.000 | 0.000 |
| deployable_score_smooth | objective_score | leave_one_target:10A | 69 | 5.834 | 5.819 |  |  |  |
| parametric_phase_proxy | final_phase_spacing_std_ns | leave_one_target:10A | 23 | 9.734 | 8.147 |  |  |  |
| parametric_settle_proxy | settle_time_us | leave_one_target:10A | 23 | 3.605 | 3.073 |  |  |  |
| parametric_excess_skip_proxy | excess_skip_count | leave_one_target:10A | 23 | 0.169 | 0.145 | 1.000 | 0.000 | 0.000 |
| deployable_score_smooth | objective_score | leave_one_target:near0A | 69 | 12.844 | 12.793 |  |  |  |
| parametric_phase_proxy | final_phase_spacing_std_ns | leave_one_target:near0A | 23 | 48.524 | 47.240 |  |  |  |
| parametric_settle_proxy | settle_time_us | leave_one_target:near0A | 23 | 19.422 | 19.146 |  |  |  |
| parametric_excess_skip_proxy | excess_skip_count | leave_one_target:near0A | 23 | 0.333 | 0.217 | 0.913 | 0.000 | 0.000 |

该表的主要含义是负面的：平滑可部署特征可以给出 score 粗排序，但对 skip/reentry 非光滑边界不可靠。leave-one-target 误差进一步说明，风险 proxy 需要目标相关校准或短时事件预测，不能直接声称跨负载泛化。

## 策略比较

| policy | n_cases | mean_regret | max_regret | mean_skip | mean_phase_std_ns | mean_settle_time_us | online_available_inputs_only |
| --- | --- | --- | --- | --- | --- | --- | --- |
| combined_grid_oracle | 45 | 0.000 | 0.000 | 1.000 | 70.986 | 19.359 | False |
| posterior_mode_aware_projection | 45 | 0.064 | 0.235 | 1.000 | 72.974 | 18.609 | False |
| near_opt_band_clipping | 45 | 0.101 | 0.209 | 1.000 | 75.307 | 21.120 | False |
| calibrated_risk_proxy_projection | 45 | 0.119 | 0.355 | 1.000 | 74.350 | 21.090 | True |
| discrete_dense_long_table | 45 | 0.163 | 0.490 | 1.000 | 74.475 | 18.528 | True |
| naked_smooth_continuous | 45 | 0.654 | 2.429 | 1.222 | 75.173 | 22.203 | True |
| parametric_proxy_only | 45 | 0.857 | 2.406 | 1.289 | 78.415 | 22.833 | True |

关键数值解释：

- 后验 `posterior_mode_aware_projection` 仍是最强的可解释投影之一，mean regret 为 `0.064`，但它使用后验模式标签，不能直接部署。
- `calibrated_risk_proxy_projection` 的 mean regret 为 `0.119`，低于旧 `discrete_dense_long_table` 的 `0.163` 和裸平滑连续的 `0.654`，但略弱于 R025 后验投影。
- `parametric_proxy_only` 的 mean regret 为 `0.857`，说明只用光滑参数模型会重新踩到 R024 的 skip/reentry 跳变风险。

## 延迟敏感性

| tau_AI_us | policy | mean_regret | max_regret | mean_skip | mean_phase_std_ns | mean_settle_time_us |
| --- | --- | --- | --- | --- | --- | --- |
| 0.000 | calibrated_risk_proxy_projection | 0.128 | 0.355 | 1.000 | 74.544 | 21.317 |
| 0.000 | parametric_proxy_only | 0.987 | 2.406 | 1.333 | 79.756 | 23.117 |
| 0.500 | calibrated_risk_proxy_projection | 0.128 | 0.355 | 1.000 | 74.544 | 21.317 |
| 0.500 | parametric_proxy_only | 0.752 | 2.406 | 1.222 | 79.261 | 23.117 |
| 1.000 | calibrated_risk_proxy_projection | 0.128 | 0.355 | 1.000 | 74.544 | 21.317 |
| 1.000 | parametric_proxy_only | 0.766 | 2.406 | 1.222 | 80.038 | 23.117 |
| 2.000 | calibrated_risk_proxy_projection | 0.128 | 0.355 | 1.000 | 74.544 | 21.317 |
| 2.000 | parametric_proxy_only | 0.957 | 2.406 | 1.333 | 78.558 | 22.879 |
| 5.000 | calibrated_risk_proxy_projection | 0.080 | 0.235 | 1.000 | 73.570 | 20.179 |
| 5.000 | parametric_proxy_only | 0.823 | 2.406 | 1.333 | 74.463 | 21.934 |

当前 R026 的 `tau_AI` 只作为安全裕量进入离线重放，不是新增开关级延迟仿真。它可用于设计下一步 table-in-loop 或 AI-in-loop 派生 Simulink 验证点。

## 结论边界

- 不声称 `T_slew` 存在全局最优。
- 不声称校准风险表等同硬件安全集合。
- 不声称 R026 已完成神经网络 AI-in-loop 或硬件验证。
- 可以谨慎声称：PIS-IEK 给出的 mode-aware 安全投影可以被降级为可部署的风险 proxy 接口；在当前离线网格上，该接口优于裸连续和平滑参数 proxy，并接近但不超过后验投影。
