## R031：由负样本收紧的 `B_epsilon^sw` 安全投影

R030 dense-anchor challenge 表明，离线 proxy 可以提出候选，但不能直接覆盖
dense-anchor。为了把这一负面证据转成可部署设计，本文进一步构造 R031
switching-calibrated projection 原型。该原型不新增 `.slx` 仿真，而是把
R030 的 `15` 个成对上下文整理为 pair-level risk features，并比较 direct
proxy、dense-anchor、small-delta rule、R031 tightened projection 和 pair
oracle 上界。

结果显示，direct proxy override 的 mean regret 为 `0.574`，
高于 dense-anchor 的 `0.186`；单纯允许小斜率差 proxy
也只有 `0.189`，说明近似并列带仍存在延迟非单调。
R031 tightened projection 将 `20A/score_settle005` 的 `66us` 标为 large-jump
settling-sensitive 负样本，同时只在 `10A/score_settle010` 的已观测 near-tie
子带中保留 proxy 候选，得到 `0.132` 的校准集
mean regret。这个数值不能作为独立泛化证明；它的意义是说明 `B_epsilon^sw`
可以由开关级负样本收紧，并为下一轮少量 held-out 派生仿真提供候选矩阵。

因此，PIS-IEK 支持的 AI 角色应进一步限定为“候选 score/risk 生成器 +
mode-aware safety projection”。AI 不替代 IQCOT 内环，不直接输出 gate
command，也不应把 R031 的离线投影候选写成硬件验证结果。
