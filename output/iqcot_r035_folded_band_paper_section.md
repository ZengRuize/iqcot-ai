## R035：folded-band 可部署投影与审稿式收束

R034 完整细扫证明 `20A/score_settle005` 的过渡候选并不是固定 `50us` 口袋，也不是随 `tau_AI` 单调上升的 ridge；在 `tau_AI=1.0/1.25/1.5/1.75/2.0us` 的过渡候选集中，当前最佳序列为 `38/46/50/54/46us`。R035 对这一结论做了更严格的部署化修正：该序列只能称为 folded transition candidate band，不能直接写成最终 plant commit 序列。原因是 R034 细扫主要比较 `38/46/50/54/58us` 过渡候选，部分延迟点并未与 dense fallback `30us` 成对比较；而 R031/R033 的 dense-inclusive 结果显示，在 `tau_AI=2us` 等位置，保守 `30us` fallback 仍可能优于 transition probe。因此，更稳妥的监督层接口应写成

```text
q_phi(z_k,T_slew,tau_AI) -> candidate score/ranking
r_hat(z_k,T_slew,tau_AI,recent_event_state) -> skip/settling/phase risk
T_slew,plant = Proj_{B_epsilon^sw}(candidate; T_dense, r_hat, tau_AI)
```

在这个接口下，`10A/score_settle010` 保留 `30-34us` near-tie 候选带，`20A/base` 继续以 `80us` 为 plant fallback 并把 `86us` 限定为目标函数相关探针；`20A/score_settle005` 则把 `38/46/50/54/46us` 作为 folded 候选带，同时继续阻止 `66us` direct override，并在缺少 dense 成对证据的位置保持 candidate-only 状态。这个修正比“AI 直接选择最优斜率”更克制，但更有论文价值：它说明 PIS-IEK 的创新点不是给出一个万能 `T_slew`，而是把非光滑 skip/reentry 与 settling 风险转化为可验证、可迭代收紧的 `B_epsilon^sw` 安全投影边界。
