# Experiment: R031 tightened B_epsilon^sw

## ID

`exp:tightened-bepsilon-sw`

## Purpose

把 R030 dense-anchor challenge 中暴露的 proxy 负样本转化为更严格的 switching-calibrated `B_epsilon^sw` 投影接口，并生成下一轮最小 held-out 派生 Simulink 验证矩阵。

## Inputs

- `E:/Desktop/codex/output/iqcot_r030_dense_anchor_challenge_results_combined.csv`
- `E:/Desktop/codex/output/iqcot_r030_dense_anchor_challenge_context_summary.csv`
- `E:/Desktop/codex/output/iqcot_r030_dense_anchor_challenge_motif_summary.csv`

## Outputs

- `E:/Desktop/codex/output/iqcot_r031_tightened_bepsilon_sw.py`
- `E:/Desktop/codex/output/iqcot_r031_pair_risk_features.csv`
- `E:/Desktop/codex/output/iqcot_r031_tightened_bepsilon_policy_eval.csv`
- `E:/Desktop/codex/output/iqcot_r031_tightened_bepsilon_policy_summary.csv`
- `E:/Desktop/codex/output/iqcot_r031_tightened_bepsilon_rules.csv`
- `E:/Desktop/codex/output/iqcot_r031_minimal_validation_plan.csv`
- `E:/Desktop/codex/output/iqcot_r031_tightened_bepsilon_report.md`
- `E:/Desktop/codex/output/figures/fig41_r031_tightened_bepsilon.svg`

## Result

R031 不运行或修改 `.slx`，只做离线后处理。它在 R030 challenge 的 `15` 个成对上下文上比较了五类策略：

| 策略 | mean regret | max regret | 说明 |
|---|---:|---:|---|
| pair oracle upper bound | `0.000` | `0.000` | 非部署上界 |
| R031 tightened projection | `0.132` | `1.688` | 校准候选 |
| dense-anchor baseline | `0.186` | `1.688` | 强基线 |
| small-delta only | `0.189` | `1.688` | 简单局部带不足 |
| direct proxy override | `0.574` | `2.793` | 负面对照 |

三条 tightened rule：

- `10A / score_settle010`: `30-32us` near-tie band；只在已观测 proxy 胜出的延迟子带保留候选，下一步检查 `31/33us`。
- `20A / base`: 暂阻止 `86us` 直接覆盖 `80us` dense-anchor，下一步检查 `82/84us`。
- `20A / score_settle005`: 将 `66us` 作为 large-jump settling-sensitive 负样本排除，下一步检查 `38/50/58us` 的中间带。

随后已执行 `22` 行最小 held-out 派生 Simulink 验证，入口为：

- `E:/Desktop/codex/output/iqcot_r031_minimal_validation.m`
- `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_validation.m` 的 `planMode="r031_minimal"`

分块结果：

- `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_results_r031_minimal_rows001_008.csv`
- `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_results_r031_minimal_rows009_016.csv`
- `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_results_r031_minimal_rows017_022.csv`

后处理文件：

- `E:/Desktop/codex/output/iqcot_r031_minimal_validation_postprocess.py`
- `E:/Desktop/codex/output/iqcot_r031_minimal_validation_results_combined.csv`
- `E:/Desktop/codex/output/iqcot_r031_minimal_validation_context_summary.csv`
- `E:/Desktop/codex/output/iqcot_r031_minimal_validation_family_summary.csv`
- `E:/Desktop/codex/output/iqcot_r031_minimal_validation_report.md`
- `E:/Desktop/codex/output/figures/fig42_r031_minimal_validation.svg`

验证结论：

- R031 best intermediate candidates 优于 dense baseline：`3/9` contexts。
- R031 best intermediate candidates 优于 R030 original proxy：`8/9` contexts。
- best-family counts：dense `6`，R031 intermediate `3`。
- `10A / score_settle010`：`tau=1us` 保持 dense `30us`，`tau=5us` 支持 `33us`。
- `20A / base`：`82/84us` 未实质超过 dense `80us`，仍阻止 `86us` direct override。
- `20A / score_settle005`：`38/50/58us` 中间带有局部价值，但 `66us` proxy 仍需短时 risk predictor 认证后才可重新考虑。

## Boundary

R031 的 `0.132` 是校准集重放，不是硬件验证或神经网络 AI-in-loop。后续 `22` 行最小 held-out 派生验证支持 delay-aware local band with dense fallback；不能说 proxy 已经可以直接替代 dense-anchor，也不能说 `T_slew` 存在全局最优。

## Next Validation

下一步应把 delay-aware band 写成短时 predictor 或轻量 score/risk 回归器接口。这些后续点仍只能在派生 `E:/Desktop/codex/output/simulink_iek` 模型上运行；不修改原始 `.slx`，不编辑 `.slx` XML。
