### R027 优先矩阵开关级重放结果

R027 已完成优先矩阵全部 `48` 个派生 Simulink 工况。该优先矩阵不是完整 `315` 行均匀验证，而是故意挑选排序分歧和 proxy regret 较高的压力上下文，因此更适合检验 R026 proxy 的边界。

合并后，dense-long table 与 posterior mode-aware projection 的 mean switching regret 均为 `0.025`，calibrated risk proxy 为 `0.283`，near-opt band 为 `0.257`。proxy 在 `0` 个上下文优于 dense-long，在 `4` 个上下文并列，在 `4` 个上下文更差。

这个结果修正了 R026 的离线乐观结论：`r_hat` proxy 可以作为可执行监督层接口进入派生模型，但当前校准方式在压力上下文中没有稳定超过 dense-long table。论文中应将 R027 写成“完成 proxy 接口开关级压力检验，并暴露需要重标定的安全投影边界”，而不是“proxy 已证明优于查表”。
