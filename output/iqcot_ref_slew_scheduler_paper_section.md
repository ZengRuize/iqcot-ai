## 参考斜率调度器策略验证

为避免把单个 `T_slew` 误写成全局最优，本文进一步将 dense+long sweep 后处理为离线调度器策略验证。比较对象包括固定 `30/40/60/80 us` 参考斜率，以及按负载目标分别最小化 base score、`score + 0.05T_settle` 和 `score + 0.10T_settle` 的 oracle scheduler。该步骤不引入新的开关级仿真，而是直接复用已完成的四相 IQCOT Simulink sweep 数据。

策略评估表明，若只看 base score，最优调度为 `80/80/60 us`，平均 base score 为 `9.299`；若引入较强 settling penalty，则 `30/30/30 us` 在 `score + 0.10T_settle` 下达到最低平均分 `11.115`。这说明参考斜率不是一个应被固定写死的设计常数，而是与设计目标有关的调度变量。

这一结果为 FPGA 上微秒级 AI 监督层提供了更明确的训练目标：AI 不需要替代 IQCOT 内环的快速事件响应，而应根据负载阶跃幅度、相位同步状态、skip/reentry 状态和 settling 权重选择合适的参数轨迹。当前验证仍属于离线 oracle/surrogate 调度器评估，不能等同于硬件闭环 AI-in-the-loop 结果。

相关数据文件见 `output/iqcot_ref_slew_scheduler_policy_eval.csv`，图见 `output/figures/fig25_ref_slew_scheduler_policy_eval.png`。
