### 10.3 可解释 score 回归监督层前置验证

在完成表驱动监督层的 `0.5/1/2/5 us` 参数提交延迟验证后，本文进一步将同一批派生开关级结果整理为一个可解释 AI/回归器前置验证问题。原始数据包含 `60` 个 delayed-reference 开关级工况；按 `base`、`score+0.05T_settle` 和 `score+0.10T_settle` 三个目标函数展开后，形成 `180` 行候选策略打分样本和 `36` 个监督上下文标签。监督层输入为切载幅度、目标函数权重、`tau_AI` 与事件延迟数，输出不直接作用于门极，而是在 `fixed 40us`、`fixed 80us`、base-score table、`alpha=0.05` table 和 `alpha=0.10` table 之间选择低维参考斜率策略。

评价采用 leave-one-tau-out 与 leave-one-target-out 交叉验证，并以 regret 衡量模型选择的策略与当前上下文 oracle 策略之间的差距。leave-one-tau-out 中，最佳基线 `trained_objective_nearest_tau_table` 的 mean regret 为 `0.304`；leave-one-target-out 中，最佳基线 `zero_delay_objective_table` 的 mean regret 为 `0.316`。这说明已有 PIS-IEK 坐标下的目标权重、负载下降幅度和参数提交延迟可以被组织成 score-prediction supervisor 的训练接口，而不必把 AI 直接接入 IQCOT 内环。

更重要的是，这个结果没有给出“AI 全面优于查表”的过强结论。leave-one-tau-out 中，延迟最近邻目标表相对零延迟目标表只降低 `0.013` 的 mean regret；leave-one-target-out 中，零延迟目标表仍是最强基线，ridge score supervisor 虽优于固定斜率，却没有超过该强基线。由于 `36` 个监督上下文里有 `11` 个 oracle 策略并列、`23` 个上下文的一二名差距不超过 `0.25` 分，本文更稳妥的表述应是：可解释监督层能够近似 delayed-reference 策略排序，并显著优于固定斜率基线，但当前数据尚不足以证明其稳定优于零延迟目标表。

该结果仍需谨慎解释。首先，候选动作仍来自离散表驱动策略，尚未证明连续 `T_slew` 回归或神经网络 AI-in-loop 优于表驱动策略。其次，交叉验证样本只有 `36` 个上下文标签，因此应把它写成“可解释监督层可近似已有 delayed-reference 策略排序”的前置证据，而不是“AI 已经完成开关级闭环验证”。它的实际价值在于把下一步 AI 训练目标从黑箱调参收窄为：学习候选低维参数策略的相对 objective score，并在 PIS-IEK 给出的事件延迟坐标中做安全选择。
