# R030 Dense-Anchor Challenge 报告

## 范围

本报告后处理 R030 的 `30` 行 dense/proxy 成对挑战实验。输入来自三段派生 Simulink delayed-reference 开关级回放：

- `iqcot_r027_proxy_table_in_loop_results_r030_challenge_rows001_010.csv`
- `iqcot_r027_proxy_table_in_loop_results_r030_challenge_rows011_020.csv`
- `iqcot_r027_proxy_table_in_loop_results_r030_challenge_rows021_030.csv`

本步骤不修改原始 `.slx`，只读取派生模型结果，并按完整上下文 `(target_label, objective, tau_ai_us)` 重新计算 regret，避免直接采用分块 runner 的局部统计。

## 主要结果

R030 challenge 不支持“dense-anchor 普遍过于保守”的强结论。在 `15` 个成对上下文中，proxy 胜 `7` 个，dense-anchor 胜 `8` 个。dense-anchor 的 mean switching regret 为 `0.186`，proxy 为 `0.574`。

离线 pair ranking 只在 `7/15` 个上下文中保持。这个结果更适合作为负校准证据：event-domain 或离线 proxy 能提出有价值候选，但当前排序还不足以在开关级回放中直接替代 dense-anchor safety projection。

## Policy Summary

| policy | n_cases | mean_switching_regret | max_switching_regret | best_context_count | mean_selected_objective_score | mean_undershoot_mV | mean_settle_time_us | mean_skip_count | mean_phase_spacing_std_ns |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| discrete_dense_long_table | 15 | 0.186 | 1.688 | 8 | 5.303 | 2.274 | 10.096 | 0.467 | 58.134 |
| calibrated_risk_proxy_projection | 15 | 0.574 | 2.793 | 7 | 5.692 | 2.245 | 13.926 | 0.600 | 55.991 |

## Motif Summary

| target_label | objective | n_contexts | proxy_win_count | dense_win_count | mean_proxy_minus_dense_score | max_abs_proxy_minus_dense_score | mean_dense_regret | mean_proxy_regret | ranking_preserved_count |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 10A | score_settle010 | 5 | 3 | 2 | 0.009 | 0.692 | 0.161 | 0.170 | 3 |
| 20A | base | 5 | 2 | 3 | 0.082 | 0.279 | 0.040 | 0.123 | 2 |
| 20A | score_settle005 | 5 | 2 | 3 | 1.073 | 2.793 | 0.357 | 1.430 | 2 |

## 解释

1. `10A / score_settle010` 仍是局部近似并列带。`32us` proxy 在 `tau_AI=0/0.5/2us` 胜出，`30us` dense-anchor 在 `1/5us` 胜出，平均 proxy-minus-dense score 只有 `0.009`，不宜写成 proxy 稳定胜利。
2. `20A / base` 也不支持替换 dense-anchor。`86us` proxy 在 `0/1us` 胜出，但 `80us` dense-anchor 在 `0.5/2/5us` 胜出。
3. `20A / score_settle005` 是 proxy 的主要负样本。`66us` 偶尔能改善，但在 `tau_AI=0.5/2/5us` 下引入额外 skip 或更长 settling，平均比 `30us` dense-anchor 差 `1.073` 分。

## 结论边界

安全结论是：R030 challenge 收紧而不是放宽 proxy 部署边界。dense-anchor 没有被证明为全局最优，但当前 proxy 不能在未验证局部带外直接 override dense-anchor。该结果仍是派生 Simulink 证据，不是硬件验证，也不是神经网络 AI-in-loop 验证。
