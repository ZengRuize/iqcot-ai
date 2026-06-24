## R034 部分派生验证：从固定 `50us` 口袋到移动 transition ridge

R034 原先基于 R033 的 `tau_AI=1.5us` 结果，将 `20A/score_settle005` 写成 `50us` transition pocket。为了检查该口袋是否只是单点现象，本文追加运行了两个最小派生 Simulink 边界块：`tau_AI=1.25us` 与 `tau_AI=1.75us`，每个延迟下比较 `38/46/50/54/58us`。结果显示固定 `50us` 假设需要修正：`tau_AI=1.25us` 时 `46us` 最优，而 `50us` 触发 skip 且 regret 达 `2.568`；`tau_AI=1.75us` 时 `54us` 最优，`46us` 反而触发 skip。结合 R033 的 `tau_AI=1.5us -> 50us` 锚点，局部最优候选更像一条随延迟移动的 transition ridge，而不是固定口袋。

因此，R034 对监督层接口的修正是：`q_phi` 可用局部斜脊近似生成候选，例如 `T_ridge(tau_AI)≈26+16 tau_AI us`，但 `r_hat` 必须继续检查 skip 与 settling 风险，最终仍经 `B_epsilon^sw` 投影和 dense fallback 提交。该公式目前只由三个派生模型点支撑，剩余 `tau_AI=1.0us` 与 `2.0us` 的细扫仍需完成；不能把它写成全局最优规律或硬件验证结论。
