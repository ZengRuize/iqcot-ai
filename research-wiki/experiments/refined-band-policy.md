# Experiment: R030 refined-band policy

## ID

`exp:refined-band-policy`

## Purpose

把 R029 held-out guard 结果从两个硬编码点整理为局部安全带策略，并从 R027 完整计划中筛选下一轮 dense/proxy 成对挑战工况。

## Inputs

- `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_plan.csv`
- `E:/Desktop/codex/output/iqcot_r028_offline_replay_all_contexts.csv`
- `E:/Desktop/codex/output/iqcot_r028_switching_calibrated_policy_eval_priority.csv`
- `E:/Desktop/codex/output/iqcot_r029_heldout_guard_results_combined.csv`
- `E:/Desktop/codex/output/iqcot_mode_aware_slew_dataset.csv`

## Outputs

- `E:/Desktop/codex/output/iqcot_r030_refined_band_policy.py`
- `E:/Desktop/codex/output/iqcot_r030_refined_band_policy_eval.csv`
- `E:/Desktop/codex/output/iqcot_r030_refined_band_policy_summary.csv`
- `E:/Desktop/codex/output/iqcot_r030_refined_band_context_bands.csv`
- `E:/Desktop/codex/output/iqcot_r030_refined_band_switching_evidence.csv`
- `E:/Desktop/codex/output/iqcot_r030_dense_anchor_challenge_candidates.csv`
- `E:/Desktop/codex/output/iqcot_r030_dense_anchor_challenge_plan.csv`
- `E:/Desktop/codex/output/iqcot_r030_dense_anchor_challenge_postprocess.py`
- `E:/Desktop/codex/output/iqcot_r030_dense_anchor_challenge_results_combined.csv`
- `E:/Desktop/codex/output/iqcot_r030_dense_anchor_challenge_policy_summary.csv`
- `E:/Desktop/codex/output/iqcot_r030_dense_anchor_challenge_context_summary.csv`
- `E:/Desktop/codex/output/iqcot_r030_dense_anchor_challenge_motif_summary.csv`
- `E:/Desktop/codex/output/iqcot_r030_dense_anchor_challenge_report.md`
- `E:/Desktop/codex/output/figures/fig40_r030_dense_anchor_challenge.svg`
- `E:/Desktop/codex/output/iqcot_r030_refined_band_policy_report.md`
- `E:/Desktop/codex/output/figures/fig39_r030_refined_band_policy.svg`

## Result

R030 refined-band 代表策略：

- `10A / score_settle005`: `tau_AI<=1us` 使用 dense-anchor `50us`；`tau_AI≈1.5us` 使用 `40us`；`tau_AI>=2us` 使用 `34us`。
- `near0A / score_settle010`: 使用 `30-38us` 局部安全带；`tau_AI<0.5us` 代表点为 `38us`，`tau_AI>=0.5us` 代表点为 `30us`。
- 其他上下文回退到 R028 dense-anchor projection。

离线 consistency replay 中，R030 mean regret 为 `0.104`，R028 guarded 为 `0.106`，dense-anchor 为 `0.099`。在 R027 priority + R029 held-out 的 `12` 个已知 guard-context 合成证据中，R030 选中行 mean switching regret 为 `0.000`，对应 dense-anchor 为 `0.128`。

R030 同时筛出 `24` 个 dense/proxy 非优先分歧上下文，其中 `20` 个离线 proxy 更优，并生成 `30` 行 dense/proxy 成对挑战计划。

R030 dense-anchor challenge 已完成 `30` 行派生 Simulink delayed-reference 回放，覆盖：

- `10A / score_settle010`: dense `30us` vs proxy `32us`
- `20A / base`: dense `80us` vs proxy `86us`
- `20A / score_settle005`: dense `30us` vs proxy `66us`

合并后按完整上下文重算 regret，得到 `15` 个 dense/proxy 成对上下文：proxy 胜 `7` 个，dense-anchor 胜 `8` 个；dense-anchor mean switching regret 为 `0.186`，proxy 为 `0.574`。其中 `10A/score_settle010` 接近局部 near-tie，`20A/base` 不支持稳定替换 dense-anchor，`20A/score_settle005` 是 proxy 的主要负样本，`66us` 在多个延迟上下文中引入额外 skip 或更长 settling。

## Boundary

R030 refined-band 合成本身不运行新的 `.slx`，不是硬件/HIL 验证，也不是神经网络 AI-in-loop。`0.000` known-context regret 是由 R027/R029 局部证据合成得到的一致性检查，不能作为独立泛化证明。

R030 dense-anchor challenge 虽然运行了派生 Simulink 开关级回放，但仍不是硬件验证；它给出的结论是当前 proxy 排序不够稳，应收紧 `B_epsilon^sw`，而不是证明 dense-anchor 全局最优或证明 proxy/AI 已优于查表。
