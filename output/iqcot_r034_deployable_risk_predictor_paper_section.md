## R034 可部署短时风险接口：由 R033 边界修正到 `q_phi/r_hat/B_epsilon^sw`

基于 R033 的 `31` 行派生 Simulink 边界验证，本文进一步将局部结论整理为可部署风格的短时风险接口。该接口由三部分组成：候选评分 `q_phi(z_k,T_slew,tau_AI)`、风险估计 `r_hat(z_k,T_slew,tau_AI)`，以及最终安全投影 `B_epsilon^sw`。需要强调的是，R034 不是新的硬件实验，也不是神经网络闭环控制；它是把已有派生模型证据转成监督层参数调度接口和下一轮验证矩阵。

R034 的核心修正是：`T_slew` 的可提交集合不能只随 `tau_AI` 平滑移动，而必须识别 skip/settling 模式边界。对于 `10A/score_settle010`，接口保留 `30-34 us` near-tie candidate band；对于 `20A/base`，`86 us` 只保留为 base objective 下的候选探针，plant 侧默认仍回到 `80 us` fallback；对于 `20A/score_settle005`，接口在 `tau_AI≈1.5 us` 附近形成 `50 us` transition pocket，但在口袋外回到 `30 us` fallback，并继续阻止 `66 us` 直接覆盖。

为了检验该 transition pocket 是否只是单点偶然，R034 生成了 `20` 行下一轮派生 Simulink 细扫计划，覆盖 `tau_AI=1.0/1.25/1.75/2.0 us` 与 `T_slew=38/46/50/54/58 us`。因此，R034 对论文主张的贡献是把 PIS-IEK 的事件域小信号思想落成“候选生成 + 风险预测 + 安全投影 + 最小验证矩阵”的闭环研究流程，而不是宣称 AI/proxy 已经全局优于查表或完成硬件验证。
