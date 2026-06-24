### 表驱动监督层的延迟敏感性验证

在 `tau_AI=5 us` 验证之后，本文进一步补齐 `tau_AI=0.5/1/2 us`
的派生开关级 delayed-reference 工况，并与零延迟参考排序合并分析。正延迟实验共
`60` 个工况，仍只使用表驱动 `T_slew` 监督层，IQCOT 内环不变。

best-by-tau 结果显示，base score 的最佳策略随延迟移动：零延迟以及
`0.5/1 us` 下为 base-score table，`2/5 us` 下转为 `alpha=0.05`
table。`score+0.05T_settle` 在零延迟、`2 us` 和 `5 us` 下偏向
`alpha=0.05` table，但在 `0.5/1 us` 下更偏向 `alpha=0.10`
table。`score+0.10T_settle` 同样不是单调规律：`0.5/1/5 us`
下由 `alpha=0.10` table 取得最低分，而 `2 us` 下 `alpha=0.05`
table 最优。

因此，表驱动结果支持的不是“某个固定 `T_slew` 最优”，也不是“延迟越大越应该单调调快或调慢”，而是一个更适合 AI 监督层学习的结论：

```text
T_slew = pi(Delta I_load, alpha_settle, tau_AI, delay_events, phase/current state).
```

该结论仍限于派生 Simulink delayed-reference 验证，不等同于神经网络 AI-in-loop 或硬件验证。
