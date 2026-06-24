## R033 派生 Simulink 验证：delay-aware `B_epsilon^sw` 的边界修正

在 R032 将 R031 结果整理为 `q_phi/r_hat/B_epsilon^sw` 接口之后，本文进一步执行了 `31` 行派生 Simulink delayed-reference 验证。验证仍只使用 `output/simulink_iek` 下的派生模型，不修改原始 `.slx`，也不构成硬件验证。该轮实验的价值在于把 R032 的已知上下文拟合规则放到新的延迟边界点上检查，从而修正可部署安全投影的局部边界。

结果显示，非 dense 候选在 `4/7` 个上下文中成为当前候选集最优，但这种优势具有明显的目标函数和延迟依赖性。`10A/score_settle010` 形成 `30-34 us` 的 near-tie 候选带：`tau_AI=2 us` 时 `32 us` 最优，`tau_AI=3 us` 时 `33 us` 最优，但各候选差距较小且均出现一次 skip，因此不能写成尖锐点最优。`20A/base` 中，`86 us` 在 `tau_AI=1 us` 的 base score 下略优于 `80 us`，但在 `tau_AI=3 us` 下变差，且 settling 更长；因此它只能作为 objective-dependent probe，而不是被全局解除阻断。最关键的是 `20A/score_settle005`：`tau_AI=0.75 us` 时 `30 us` 最优且 `66 us` 触发 skip，`tau_AI=1.5 us` 时 `50 us` 最优且 `30 us` 触发 skip，`tau_AI=3 us` 时又回到 `30 us` 最优。这说明安全投影需要一个窄的延迟过渡口袋，而不是简单的 `tau_AI` 近邻插值或 proxy 直接覆盖。

因此，R033 对论文主张的强化不是“AI/proxy 已优于查表”，而是更谨慎地说明：PIS-IEK 可以把短时 skip、settling 与相位风险转化为监督层安全投影边界；AI 或表驱动监督层只产生候选 score/risk，最终提交给 IQCOT 内环的 `T_slew` 必须经过 delay-aware `B_epsilon^sw` 投影。`66 us` 负控在当前派生模型中仍不能作为直接覆盖动作，除非后续短时风险预测器或 HIL/硬件验证证明其风险可控。
