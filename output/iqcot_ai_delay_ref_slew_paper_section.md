## 延迟感知 AI 监督层训练接口

参考斜率策略评估和 AI 延迟 surrogate 可以进一步合并为一个监督层训练接口。令 AI 输入特征为

```text
z_k = [Delta I_load, alpha_settle, phase_std, skip_flag, current_imbalance, tau_AI]
```

输出动作限定为低维参数 `a_k=[T_slew, Delta Lambda_diff, Delta Ton_diff]`，并通过事件域延迟缓冲进入 PIS-IEK：

```text
a_k^plant = a_{k-d},  d = ceil(tau_AI / T_event).
```

本文已将 dense+long Simulink sweep 转换为监督标签表 `iqcot_ai_supervisor_training_targets.csv`。该表显示，当目标函数从 base score 改为 `score+0.05T_settle` 和 `score+0.10T_settle` 时，`T_slew` 标签分别从 `80/80/60 us` 变为 `30/50/60 us` 与 `30/30/30 us`。这说明 AI 训练不应学习单一固定斜率，而应学习目标权重和负载幅值相关的调度律。

这一路径的实际价值在于降低 AI 控制的搜索维度：AI 不需要学习开关动作，只需在 PIS-IEK 给定的事件坐标和安全边界内选择参数轨迹。FPGA 上微秒级推理延迟不再被忽略，而是作为 `delay_events` 进入训练样本和验证矩阵。当前阶段仍是训练接口与验证设计，不能等同于开关级 AI-in-the-loop 或硬件结果。

