## R030 Dense-Anchor Challenge：Proxy 安全带的切换级再校准

为了检验 R030 dense-anchor projection 是否过于保守，本文在派生 delayed-reference Simulink 模型上执行了 `30` 行成对挑战实验。挑战集覆盖三个离线 proxy 与 dense-anchor 分歧的非优先 motif：`10A/score_settle010` 的 `30us` vs `32us`、`20A/base` 的 `80us` vs `86us`、以及 `20A/score_settle005` 的 `30us` vs `66us`，每组均在 `tau_AI=0/0.5/1/2/5us` 下回放。

按完整上下文重新计算 regret 后，dense-anchor 的 mean switching regret 为 `0.186`，deployable proxy 为 `0.574`。proxy 在 `7/15` 个上下文中较好，dense-anchor 在 `8/15` 个上下文中较好。最重要的失败模式出现在 `20A/score_settle005`：`66us` proxy candidate 在若干 delayed-commit 上下文中引入额外 skip 或更长 settling，相对 `30us` dense-anchor 的平均 score 劣化为 `1.073`。

因此，该实验修正而不是推翻 R030 policy。它不能证明 dense-anchor 是全局最优，但说明当前离线 proxy 不足以在未验证局部带外直接覆盖 dense-anchor。对于 PIS-IEK 监督层，更合理的做法是让 AI 或轻量 predictor 输出候选 score/risk，再经过 mode-aware safety projection；AI 仍只作为低速参数调度层，不替代 IQCOT 内环，也不能被写成硬件验证过的 AI-in-loop 控制。
