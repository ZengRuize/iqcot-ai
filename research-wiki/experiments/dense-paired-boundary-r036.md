# R036 Dense-Paired Boundary Validation

R036补齐了R035中两个pending点的dense对照：`20A/score_settle005`在
`tau_AI=1.25us`和`1.75us`下的`30us` fallback。两行派生Simulink均成功。

| tau_ai_us | dense_score | dense_skip_count_est | folded_best_slew_us | folded_best_score | dense_minus_folded_score |
| --- | --- | --- | --- | --- | --- |
| 1.250 | 4.989 | 1.000 | 46.000 | 2.146 | 2.843 |
| 1.750 | 4.317 | 1.000 | 54.000 | 2.142 | 2.175 |

结论边界：`46us`和`54us`分别升级为当前派生模型/当前目标函数下的局部
dense-paired候选；这不是硬件验证、不是全局最优，也不意味着AI替代IQCOT内环。
`66us`仍为blocked direct override，`tau_AI=2us`仍由R031/R035证据保持`30us`
fallback。
