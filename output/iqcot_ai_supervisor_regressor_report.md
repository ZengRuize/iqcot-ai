# R022 可解释 AI/回归器监督层基线

## 目的

本实验把已完成的表驱动 `T_slew` 延迟提交开关级结果，整理成一个可解释 AI 监督层前置验证问题：监督层不替代 IQCOT 内环，而是在每个切载上下文中选择一个已经验证过的低维参考斜率策略。评价指标不是单纯标签准确率，而是实际 objective regret：

```text
regret = score(predicted policy) - score(oracle policy)
```

## 数据结构

- 原始开关级 delayed-reference 工况：`60` 行，来自 `tau_AI=0.5/1/2/5 us`、`3` 个切载目标、`5` 个候选策略。
- 展开为候选策略打分数据：`180` 行，即每个工况按 `base`、`score+0.05T_settle`、`score+0.10T_settle` 三个目标函数各生成一行。
- 监督上下文标签：`36` 行，即 `4` 个正延迟 × `3` 个切载目标 × `3` 个目标函数。
- 候选动作限定为：`fixed_40us_precommitted`、`fixed_80us_precommitted`、`oracle_base_table`、`table_settle005`、`table_settle010`。这仍是策略/回归器前置验证，不是神经网络 AI-in-loop。

## 交叉验证结果

### Leave-One-Tau-Out

| model | n_contexts | mean_regret | median_regret | max_regret | zero_regret_rate | policy_accuracy | mean_slew_abs_error_us |
| --- | --- | --- | --- | --- | --- | --- | --- |
| trained_objective_nearest_tau_table | 36.000 | 0.304 | 0.000 | 2.013 | 0.583 | 0.444 | 7.500 |
| zero_delay_objective_table | 36.000 | 0.316 | 0.000 | 2.013 | 0.528 | 0.444 | 9.722 |
| ridge_score_supervisor | 36.000 | 0.416 | 0.191 | 2.013 | 0.417 | 0.417 | 12.500 |
| trained_objective_mean_table | 36.000 | 0.437 | 0.169 | 2.240 | 0.444 | 0.306 | 13.889 |
| knn_score_supervisor | 36.000 | 0.487 | 0.092 | 2.443 | 0.472 | 0.389 | 13.333 |
| fixed_40us | 36.000 | 1.131 | 0.820 | 3.597 | 0.167 | 0.167 | 14.722 |
| fixed_80us | 36.000 | 1.646 | 1.120 | 5.298 | 0.028 | 0.028 | 33.056 |

### Leave-One-Target-Out

| model | n_contexts | mean_regret | median_regret | max_regret | zero_regret_rate | policy_accuracy | mean_slew_abs_error_us |
| --- | --- | --- | --- | --- | --- | --- | --- |
| zero_delay_objective_table | 36.000 | 0.316 | 0.000 | 2.013 | 0.528 | 0.444 | 9.722 |
| ridge_score_supervisor | 36.000 | 0.620 | 0.328 | 2.443 | 0.278 | 0.278 | 16.667 |
| trained_objective_mean_table | 36.000 | 0.668 | 0.238 | 3.119 | 0.389 | 0.361 | 14.722 |
| trained_objective_nearest_tau_table | 36.000 | 0.718 | 0.238 | 3.177 | 0.389 | 0.306 | 14.722 |
| knn_score_supervisor | 36.000 | 0.776 | 0.469 | 2.698 | 0.333 | 0.250 | 22.222 |
| fixed_40us | 36.000 | 1.131 | 0.820 | 3.597 | 0.167 | 0.167 | 14.722 |
| fixed_80us | 36.000 | 1.646 | 1.120 | 5.298 | 0.028 | 0.028 | 33.056 |

## 关键观察

1. 在 leave-one-tau-out 中，最低平均 regret 的模型是 `trained_objective_nearest_tau_table`，mean regret 为 `0.304`，比固定 `40 us` 基线降低约 `73.2%`，但相对零延迟目标表的优势只有 `0.013`。这说明延迟坐标有用，但当前样本下只是边际增益。
2. 在 leave-one-target-out 中，最低平均 regret 仍是 `zero_delay_objective_table`，mean regret 为 `0.316`；最佳 score 回归器 `ridge_score_supervisor` 的 mean regret 为 `0.620`，比零延迟目标表高 `0.304`，但仍明显优于固定 `40 us` 和 `80 us`。这应写成“强基线下的部分正结果”，不能写成 AI 全面获胜。
3. `36` 个监督上下文中有 `11` 个 oracle 决策完全并列，另有 `23` 个上下文的第一、第二策略差距不超过 `0.25` 分。因此 policy accuracy 偏低并不完全等同控制性能差，regret 和 zero-regret rate 更适合作为主指标。
4. 当前最有论文价值的说法是：回归器可在已有开关级表驱动结果上学习“候选策略的相对打分”，从而把查表监督层推进到可解释 score-prediction supervisor。它仍不等于真实神经网络接入 Simulink，也不等同硬件验证。

## Oracle 标签预览

| tau_ai_us | target_label | objective | best_policy | best_selected_ref_slew_us | best_objective_score | second_best_policy | decision_margin |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 0.500 | near0A | base | oracle_base_table | 60.000 | 16.607 | table_settle005 | 0.000 |
| 0.500 | near0A | score_settle005 | table_settle010 | 30.000 | 18.063 | oracle_base_table | 0.312 |
| 0.500 | near0A | score_settle010 | table_settle010 | 30.000 | 18.781 | fixed_40us_precommitted | 1.085 |
| 0.500 | 10A | base | oracle_base_table | 80.000 | 8.749 | fixed_80us_precommitted | 0.076 |
| 0.500 | 10A | score_settle005 | table_settle010 | 30.000 | 9.789 | table_settle005 | 0.190 |
| 0.500 | 10A | score_settle010 | table_settle010 | 30.000 | 10.277 | table_settle005 | 0.784 |
| 0.500 | 20A | base | oracle_base_table | 80.000 | 2.042 | fixed_80us_precommitted | 0.231 |
| 0.500 | 20A | score_settle005 | fixed_40us_precommitted | 40.000 | 2.547 | oracle_base_table | 0.215 |
| 0.500 | 20A | score_settle010 | fixed_40us_precommitted | 40.000 | 2.594 | table_settle005 | 0.238 |
| 1.000 | near0A | base | oracle_base_table | 60.000 | 14.430 | table_settle005 | 0.000 |
| 1.000 | near0A | score_settle005 | table_settle010 | 30.000 | 15.983 | oracle_base_table | 0.248 |
| 1.000 | near0A | score_settle010 | table_settle010 | 30.000 | 16.689 | oracle_base_table | 1.343 |

## 输出文件

- `E:/Desktop/codex/output/iqcot_ai_supervisor_regressor_dataset.csv`
- `E:/Desktop/codex/output/iqcot_ai_supervisor_regressor_context_labels.csv`
- `E:/Desktop/codex/output/iqcot_ai_supervisor_regressor_eval.csv`
- `E:/Desktop/codex/output/iqcot_ai_supervisor_regressor_summary.csv`
- `E:/Desktop/codex/output/figures/fig29_ai_supervisor_regressor_regret.svg`

## 结论边界

- 本实验只复用派生 Simulink delayed-reference 结果，不新增开关级仿真。
- 监督层只在候选策略集合中选择 `T_slew` 调度策略，不输出 gate command。
- 不声称 `T_slew` 存在全局最优，也不声称 PIS-IEK 精确预测大切载第一峰。
- 这一步是 AI/table-in-loop 与真实神经网络 AI-in-loop 之间的中间证据。
