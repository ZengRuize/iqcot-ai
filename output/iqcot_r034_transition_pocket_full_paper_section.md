## R034 完整派生验证：`20A/score_settle005` 的 folded transition band

在 R034 的完整细扫中，本文完成了 `20A/score_settle005` 过渡口袋的全部 `20` 行派生 Simulink delayed-reference 验证，并与 R033 的 `tau_AI=1.5us` 锚点合并分析。结果否定了“固定 `50us` 口袋”作为一般局部规则：当前候选集中最优动作序列为 `tau_AI=1.0us -> 38us`、`1.25us -> 46us`、`1.5us -> 50us`、`1.75us -> 54us`、`2.0us -> 46us`。其中 `tau_AI=1.0us` 时 `46us` 以上候选均触发 skip；而 `tau_AI=2.0us` 时 `46us` 最优、`50us` 近似并列，但 `54/58us` 因 settling 变长而退化。

这说明过渡集合不是简单随 `tau_AI` 单调移动的 ridge，而是由 skip/reentry 与 settling 边界共同折叠出的局部安全带。对 AI 监督层而言，这个结果比单点最优更有价值：它要求 `q_phi` 输出候选带，`r_hat` 显式预测 skip/settling 风险，最终由 `B_epsilon^sw` 投影提交到 IQCOT 参数通道。该结论仍然只来自派生 Simulink，不应写成硬件验证或 `T_slew` 全局最优证明；它支持的是“PIS-IEK 能把非光滑事件风险转化为可验证的安全投影边界”。
