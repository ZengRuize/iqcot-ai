# R024 参考斜率局部细扫验证

## 目的

R023 的连续 `T_slew` 景观只给出局部二次插值候选。R024 的目标是用派生 Simulink 模型在小范围网格中验证这些候选是否仍然改善 objective score，尤其是 `20A` 与 `near-0A` 附近的 `34-35 us`。

状态：已完成派生 Simulink 细扫后处理。

## 验证计划

- MATLAB 入口：`E:/Desktop/codex/output/iqcot_dynamic_ref_slew_fine_sweep.m`
- 精确计划：`E:/Desktop/codex/output/iqcot_ref_slew_fine_sweep_plan_matlab.csv`
- 高优先级计划：`E:/Desktop/codex/output/iqcot_ref_slew_fine_sweep_plan.csv`
- 使用派生模型：`E:/Desktop/codex/output/simulink_iek/four_phase_iek_dynamic_load_refslew.slx`
- 不修改原始 `.slx`，不直接编辑 `.slx` XML。

## 细扫结果汇总

- 细扫 summary：`E:/Desktop/codex/output/iqcot_dynamic_ref_slew_fine_summary.csv`
- 合并目标函数 best：`E:/Desktop/codex/output/iqcot_ref_slew_fine_best_by_objective.csv`
- R023 候选对比：`E:/Desktop/codex/output/iqcot_ref_slew_fine_candidate_comparison.csv`
- 图：`E:/Desktop/codex/output/figures/fig31_ref_slew_fine_sweep.svg`

### R023 候选验证

| target_label | objective | r023_candidate_us | nearest_sim_us | nearest_sim_score | local_fine_best_us | local_fine_best_score | old_sampled_best_us | old_sampled_best_score | local_gain_vs_old_best | verdict |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 20A | score_settle005 | 34.744 | 35.000 | 4.291 | 38.000 | 2.417 | 30.000 | 2.493 | 0.076 | fine_grid_supports_local_improvement |
| 20A | score_settle010 | 34.744 | 35.000 | 4.338 | 38.000 | 2.464 | 30.000 | 2.540 | 0.076 | fine_grid_supports_local_improvement |
| near0A | score_settle010 | 34.633 | 35.000 | 19.673 | 38.000 | 19.549 | 30.000 | 19.784 | 0.235 | fine_grid_supports_local_improvement |
| 20A | base | 87.244 | 88.000 | 4.383 | 86.000 | 2.133 | 80.000 | 2.273 | 0.140 | fine_grid_supports_local_improvement |
| near0A | base | 65.710 | 66.000 | 16.913 | 68.000 | 16.655 | 60.000 | 16.801 | 0.146 | fine_grid_supports_local_improvement |

### 关键观察

- `20A` 的 `35 us` 最近候选点并未验证 R023 的点最优假设：它触发了 `skip_count=1`，score 反而劣于旧 `30 us`。同一局部带内 `38 us` 恢复到 `skip_count=0`，相对旧网格有约 `0.076` 分改善。
- 更宽的细扫网格显示 `20A` settling-aware 目标在 `66 us` 处出现更低 score。这不是 R023 局部二次插值能够直接预测的平滑最优，而是事件模式和相位指标共同导致的非光滑局部机会。
- `near-0A` 的强恢复时间惩罚目标在 `38 us` 处相对旧 `30 us` 改善约 `0.235` 分，支持在 `34-40 us` 附近做连续动作安全区间，但仍不能称为全局最优。
- 因此，R024 的主要价值不是证明 `34-35 us` 是最优，而是证明连续 `T_slew` 景观含有 skip/reentry 离散跳变；后续 AI 应学习带安全投影的区间选择，而不是裸回归一个尖锐点。

### 全目标函数 best-by-grid

| target_label | objective | old_best_us | old_best_score | fine_best_us | fine_best_score | combined_best_us | combined_best_score | combined_gain_vs_old_best | best_source |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 20A | base | 80.000 | 2.273 | 86.000 | 2.133 | 86.000 | 2.133 | 0.140 | fine |
| 20A | score_settle005 | 30.000 | 2.493 | 66.000 | 2.398 | 66.000 | 2.398 | 0.095 | fine |
| 20A | score_settle010 | 30.000 | 2.540 | 66.000 | 2.445 | 66.000 | 2.445 | 0.095 | fine |
| 10A | base | 80.000 | 8.825 | 70.000 | 8.738 | 70.000 | 8.738 | 0.087 | fine |
| 10A | score_settle005 | 50.000 | 10.008 | 32.000 | 10.024 | 50.000 | 10.008 | 0.000 | dense_long |
| 10A | score_settle010 | 30.000 | 11.022 | 32.000 | 10.532 | 32.000 | 10.532 | 0.490 | fine |
| near0A | base | 60.000 | 16.801 | 92.000 | 16.581 | 92.000 | 16.581 | 0.220 | fine |
| near0A | score_settle005 | 60.000 | 18.567 | 38.000 | 18.464 | 38.000 | 18.464 | 0.103 | fine |
| near0A | score_settle010 | 30.000 | 19.784 | 38.000 | 19.549 | 38.000 | 19.549 | 0.235 | fine |

## 谨慎解释

- 若细扫点优于旧网格，只能说明在当前派生模型、当前目标函数和当前局部网格下有改善。
- 不能声称 `T_slew` 存在全局最优。
- 不能把 R023 插值或 R024 派生仿真等同于硬件验证。
- AI 仍只作为监督层参数调度，不替代 IQCOT 内环。
