# R027 R026-proxy table-in-loop 验证计划

## 目的

R026 已经把后验 `skip/phase/settle` 指标降级为可部署 `r_hat(z,T_slew)` 风险 proxy。R027 的目标不是再次证明离线排序，而是为派生 Simulink table-in-loop 验证生成可执行矩阵：检查校准 risk proxy 在参数提交延迟下是否仍优于强查表基线，并用后验 mode-aware projection 仅作为上界对照。

## 产物

- 完整计划：`E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_plan.csv`，`315` 行。
- 优先仿真计划：`E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_priority_plan.csv`，`48` 行。
- 离线预期汇总：`E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_expected_summary.csv`。
- MATLAB runner：`E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_validation.m`。
- 已完成优先矩阵全部 `48` 行派生模型 switching run：`E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_combined_report.md`。

## 离线预期排序

| policy | n_cases | mean_regret | max_regret | mean_skip | mean_phase_std_ns | mean_settle_time_us | online_available_inputs_only |
| --- | --- | --- | --- | --- | --- | --- | --- |
| posterior_mode_aware_projection | 45 | 0.064 | 0.235 | 1.000 | 72.974 | 18.609 | False |
| near_opt_band_clipping | 45 | 0.101 | 0.209 | 1.000 | 75.307 | 21.120 | False |
| calibrated_risk_proxy_projection | 45 | 0.119 | 0.355 | 1.000 | 74.350 | 21.090 | True |
| discrete_dense_long_table | 45 | 0.163 | 0.490 | 1.000 | 74.475 | 18.528 | True |
| fixed_40us_precommitted | 45 | 0.434 | 1.103 | 1.000 | 81.826 | 13.431 | True |
| naked_smooth_continuous | 45 | 0.654 | 2.429 | 1.222 | 75.173 | 22.203 | True |
| fixed_80us_precommitted | 45 | 0.949 | 2.438 | 1.000 | 80.949 | 32.169 | True |

## 优先仿真矩阵预览

| r027_case_id | target_label | objective | tau_ai_us | policy | selected_ref_slew_us | ref_start_delay_us_for_simulink | offline_regret_vs_oracle |
| --- | --- | --- | --- | --- | --- | --- | --- |
| R027_0036 | 10A | score_settle005 | 0.000 | fixed_40us_precommitted | 40.000 | 0.000 | 0.254 |
| R027_0037 | 10A | score_settle005 | 0.000 | fixed_80us_precommitted | 80.000 | 0.000 | 0.531 |
| R027_0038 | 10A | score_settle005 | 0.000 | discrete_dense_long_table | 50.000 | 0.000 | 0.000 |
| R027_0039 | 10A | score_settle005 | 0.000 | calibrated_risk_proxy_projection | 62.000 | 0.000 | 0.355 |
| R027_0040 | 10A | score_settle005 | 0.000 | near_opt_band_clipping | 34.000 | 0.000 | 0.209 |
| R027_0041 | 10A | score_settle005 | 0.000 | posterior_mode_aware_projection | 50.000 | 0.000 | 0.000 |
| R027_0043 | 10A | score_settle005 | 0.500 | fixed_40us_precommitted | 40.000 | 0.000 | 0.254 |
| R027_0044 | 10A | score_settle005 | 0.500 | fixed_80us_precommitted | 80.000 | 0.000 | 0.531 |
| R027_0045 | 10A | score_settle005 | 0.500 | discrete_dense_long_table | 50.000 | 0.500 | 0.000 |
| R027_0046 | 10A | score_settle005 | 0.500 | calibrated_risk_proxy_projection | 62.000 | 0.500 | 0.355 |
| R027_0047 | 10A | score_settle005 | 0.500 | near_opt_band_clipping | 34.000 | 0.500 | 0.209 |
| R027_0048 | 10A | score_settle005 | 0.500 | posterior_mode_aware_projection | 50.000 | 0.500 | 0.000 |
| R027_0050 | 10A | score_settle005 | 1.000 | fixed_40us_precommitted | 40.000 | 0.000 | 0.254 |
| R027_0051 | 10A | score_settle005 | 1.000 | fixed_80us_precommitted | 80.000 | 0.000 | 0.531 |
| R027_0052 | 10A | score_settle005 | 1.000 | discrete_dense_long_table | 50.000 | 1.000 | 0.000 |
| R027_0053 | 10A | score_settle005 | 1.000 | calibrated_risk_proxy_projection | 62.000 | 1.000 | 0.355 |
| R027_0054 | 10A | score_settle005 | 1.000 | near_opt_band_clipping | 34.000 | 1.000 | 0.209 |
| R027_0055 | 10A | score_settle005 | 1.000 | posterior_mode_aware_projection | 50.000 | 1.000 | 0.000 |
| R027_0057 | 10A | score_settle005 | 2.000 | fixed_40us_precommitted | 40.000 | 0.000 | 0.254 |
| R027_0058 | 10A | score_settle005 | 2.000 | fixed_80us_precommitted | 80.000 | 0.000 | 0.531 |
| R027_0059 | 10A | score_settle005 | 2.000 | discrete_dense_long_table | 50.000 | 2.000 | 0.000 |
| R027_0060 | 10A | score_settle005 | 2.000 | calibrated_risk_proxy_projection | 62.000 | 2.000 | 0.355 |
| R027_0061 | 10A | score_settle005 | 2.000 | near_opt_band_clipping | 34.000 | 2.000 | 0.209 |
| R027_0062 | 10A | score_settle005 | 2.000 | posterior_mode_aware_projection | 50.000 | 2.000 | 0.000 |
| R027_0281 | near0A | score_settle010 | 0.000 | fixed_40us_precommitted | 40.000 | 0.000 | 0.316 |
| R027_0282 | near0A | score_settle010 | 0.000 | fixed_80us_precommitted | 80.000 | 0.000 | 2.438 |
| R027_0283 | near0A | score_settle010 | 0.000 | discrete_dense_long_table | 30.000 | 0.000 | 0.235 |
| R027_0284 | near0A | score_settle010 | 0.000 | calibrated_risk_proxy_projection | 30.000 | 0.000 | 0.235 |
| R027_0285 | near0A | score_settle010 | 0.000 | near_opt_band_clipping | 35.000 | 0.000 | 0.124 |
| R027_0286 | near0A | score_settle010 | 0.000 | posterior_mode_aware_projection | 30.000 | 0.000 | 0.235 |

## 执行边界

- 只使用派生模型 `E:/Desktop/codex/output/simulink_iek/four_phase_iek_dynamic_load_refslew.slx`。
- 不修改原始 `.slx`，不直接编辑 `.slx` XML。
- `posterior_mode_aware_projection` 只作为离线上界对照，不可写成可部署 AI。
- R027 计划本身不是开关级结果；只有运行 MATLAB wrapper 后才可报告 switching-level 指标。
- 当前完整优先矩阵显示 calibrated proxy mean switching regret 为 `0.283`，高于 dense-long table 的 `0.025`；该压力矩阵负面证据必须保留，并用于重标定 `B_epsilon(z,r_hat,tau_AI)`。
