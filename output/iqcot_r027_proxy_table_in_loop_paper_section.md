### R027 R026-proxy table-in-loop 优先矩阵验证

R026 仍是离线后处理，因此下一步需要将 `r_hat(z,T_slew)` 形式的校准 risk proxy 接入派生 Simulink 参考通道。R027 生成完整验证矩阵和优先仿真子集：完整计划覆盖目标负载、目标函数权重、`tau_AI=0/0.5/1/2/5 us` 和固定/查表/proxy/后验上界等策略；优先计划只保留排序分歧和 proxy regret 较高的上下文。

离线预期中，校准 risk proxy 的 mean regret 为 `0.119`，低于 dense-long table `0.163`，但弱于后验上界 `0.064`。R027 的开关级验证问题不是证明全局最优，而是检查这个排序在延迟提交的 `Iph_ref_ts` 波形中是否保持。

当前已完成优先矩阵全部 `48` 个派生 Simulink 工况。合并后，dense-long table 与 posterior mode-aware projection 的 mean switching regret 均为 `0.025`，calibrated risk proxy 为 `0.283`，near-opt band 为 `0.257`。proxy 在 `0` 个上下文优于 dense-long，在 `4` 个上下文并列，在 `4` 个上下文更差。

该结果说明：`r_hat` 表驱动监督层具有开关级接入可行性，但当前校准方式没有在压力上下文中稳定超过 dense-long table。论文应将 R027 写成“完成 proxy 接口开关级压力检验，并暴露需要重标定的安全投影边界”，而不是“proxy 已证明优于查表”。
