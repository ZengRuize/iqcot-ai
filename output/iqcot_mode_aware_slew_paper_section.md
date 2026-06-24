### R025 mode-aware 连续 `T_slew` score surrogate 与安全投影

R024 说明局部二次插值不能直接给出点最优，因为 `T_slew` 改变会跨越 skip/reentry 和相位间隔的离散模式边界。为将这一发现转化为 AI 监督层接口，本文进一步把 dense+long+fine 派生 Simulink 数据展开为 objective-level 数据集，并比较两类 score surrogate：只含 `target_load_A`、`alpha_settle` 和 `T_slew` 的平滑模型，以及显式加入 `skip_count_est`、`phase_spacing_std_ns` 和 `settle_time_us` 的 mode-aware 模型。

当前数据集包含 `207` 行 objective-expanded 样本。模型评估显示，mode-aware 特征能显著降低 score 解释误差，但这不等同于部署时已知这些指标；它们在真实 AI 中应由事件状态估计器或快速预测器给出。因此，本文将其定位为安全投影和 reward shaping 的设计证据，而不是闭环 AI 结果。

策略后处理比较了 `discrete_dense_long_table`、`naked_quadratic_continuous`、`near_opt_band_clipping`、`mode_aware_safety_projection` 和当前网格 oracle。最重要的论文结论不是某个策略取得绝对最优，而是裸连续二次最小化容易忽略模式跳变；加入 near-optimal band 和 mode-aware 约束后，连续动作更适合以安全区间形式提交给 IQCOT 监督层。

该结果进一步支持 PIS-IEK 的混合事件定位：AI 只应作为低速监督层调度 `T_slew` 等参数，并通过 `B_epsilon(z,m_k,tau_AI)` 做安全投影；IQCOT 内环仍负责快速事件触发。

当前最优策略汇总如下：

| policy | mean_regret | mean_skip | mean_phase_std_ns | mean_settle_time_us |
| --- | --- | --- | --- | --- |
| combined_grid_oracle | 0.000 | 1.000 | 70.986 | 19.359 |
| mode_aware_safety_projection | 0.064 | 1.000 | 72.974 | 18.609 |
| near_opt_band_clipping | 0.101 | 1.000 | 75.307 | 21.120 |
