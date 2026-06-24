## R032：短时风险预测接口与延迟感知 `B_\epsilon^{sw}` 投影

基于 R031 的 `22` 行最小 held-out 派生 Simulink 结果，本文进一步将
`B_\epsilon^{sw}` 从人工规则表整理为短时风险预测接口。该接口不让 AI 直接提交
最终 `T_slew`，而是先给出候选分数或候选分布，再由
`r_hat(z_k,T_slew,tau_AI,recent_phase_state)` 估计 skip、settling 和
phase-spacing 风险，最后经过安全投影得到 plant 侧参数：

```text
T_slew,plant = Proj_B(T_slew,candidate; z_k, tau_AI, r_hat, T_dense)
```

在 R031 已知上下文上，R032 拟合投影的 mean regret 为
`0.000`，dense fallback 为 `0.337`，
direct proxy override 为 `1.107`。这个结果只能说明
R032 规则与 R031 局部证据一致，不能写成独立泛化证明。更有信息量的是
leave-one-tau nearest-neighbor stress policy 的 mean regret 为
`0.589`，说明仅按 `tau_AI` 近邻插值会在
`20A/score_settle005` 一类非光滑边界上失败；因此短时 predictor 需要显式处理
skip/reentry 和 settling 风险，而不是把 `T_slew` 当作平滑连续变量直接回归。

R032 的当前可部署边界为：`10A/score_settle010` 保留 `30/33us` 延迟敏感近似并列带；
`20A/base` 保持 `80us` dense fallback，`82/84us` 仅作为候选探针，继续阻止
`86us` direct override；`20A/score_settle005` 将 `38/50/58us` 作为中间候选带，
但继续阻止 `66us` 直接覆盖，除非未来短时风险预测器能在新的派生 Simulink 或
硬件/HIL 验证中证明低 skip/settling 风险。AI 在这里仍只是监督层参数调度器，
不替代 IQCOT 内环，也不构成硬件验证。