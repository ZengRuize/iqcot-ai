### R026 可部署 risk proxy：从后验 mode-aware 指标到监督层接口

R025 的一个潜在问题是，`skip_count_est`、相位间隔标准差和恢复时间都是开关级仿真后的指标。如果直接把它们写入 AI 输入，就会把后验评价量误当成部署前可用信息。为避免这一点，本文进一步构造 R026 可部署 risk proxy：在线监督层只接收 `target_load_A`、`load_drop_norm`、`alpha_settle`、候选 `T_slew` 与 `tau_AI`，模式风险由离线校准表或短时事件预测器给出。

实验比较了两个 proxy 层级。第一，`parametric_proxy_only` 只用光滑可部署特征拟合风险和 score；它的平均 regret 明显较高，说明单纯的平滑 `target/load/T_slew` 回归无法可靠穿过 skip/reentry 边界。第二，`calibrated_risk_proxy_projection` 将已完成细扫中的 skip、phase 和 settling 风险整理为 `r_hat(z,T_slew)` 校准表，再与平滑 score surrogate 组合选择动作。在当前 `9` 个目标/目标函数上下文和 `5` 个 `tau_AI` 设置的离线重放中，该策略平均 regret 为 `0.119`，低于旧 dense-long 表 `0.163` 与裸平滑连续 `0.654`，但仍弱于后验 mode-aware 投影 `0.064`。

因此，R026 不把 AI 结论写成“已经优于查表或硬件验证”，而把创新点收束为更严谨的接口：PIS-IEK 不仅指出连续 `T_slew` 需要 mode-aware 约束，还给出了把后验模式指标转化为可部署风险 proxy 的路径。下一步应在派生 Simulink 模型中把该 proxy 作为 table-in-loop 监督层接入，验证动作提交延迟下的排序是否保持。
