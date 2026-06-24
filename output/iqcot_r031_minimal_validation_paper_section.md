## R031 最小 held-out 派生验证：`B_epsilon^sw` 的延迟敏感修正

在 R031 tightened projection 完成后，本文进一步执行了 `22` 行最小 held-out
派生 Simulink 验证，并将结果与 R030 中对应的 dense baseline 和原 proxy
行合并。所有工况仍使用派生 `four_phase_iek_dynamic_load_refslew.slx` 与
delayed `Iph_ref_ts`，不修改原始 `.slx`。

结果显示，R031 中间候选不是简单单调改善。`10A/score_settle010` 中，
`tau_AI=1us` 时 dense `30us` 仍优于 `31/33us`，而 `tau_AI=5us` 时
`33us` 反而优于 dense，说明 near-tie 子带应写成延迟敏感局部带。
`20A/base` 中，`82/84us` 没有实质超过 dense `80us`，但中间候选内部
呈现 `0.5us` 偏 `82us`、`2/5us` 偏 `84us` 的延迟分歧，因此仍不应
直接放行 `86us` proxy。`20A/score_settle005` 则出现更明显的模式边界：
`50us` 在 `0.5/2us` 下较好，`38us` 在 `1us` 下较好，`58us` 在 `5us`
下较好。这说明 R030 中 `66us` proxy 不能直接重新放行，但 `38-58us`
中间带值得作为短时 risk predictor 的候选动作集。

因此，R031 held-out 验证把 `B_epsilon^sw` 从静态规则推进为延迟敏感局部带：
AI 或 proxy 可以生成候选 score/risk，但最终动作仍需经过开关级负样本和
held-out 样本校准的投影。该结论仍是派生 Simulink 证据，不是硬件验证，
也不支持 `T_slew` 全局最优或 AI 替代 IQCOT 内环的说法。
