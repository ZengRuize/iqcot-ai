### R028 开关级校准的 proxy 安全投影

R027 表明，R026 离线 `r_hat(z,T_slew)` proxy 的平均优势不能直接迁移到派生 Simulink 的延迟参考通道中。尤其在 `10A/score_settle005` 压力上下文中，旧 proxy 选择 `62 us`，使切载后的恢复时间惩罚增大；dense-long 表的 `50 us` 在 `tau_AI=0/0.5/1 us` 更稳，而 `tau_AI=2 us` 下较短斜率比较器更优。基于这一负面边界，本文将 `B_epsilon(z,r_hat,tau_AI)` 改写为开关级校准的安全投影：当 proxy 偏离 dense-long 基准超过上下文带宽时，回退到 dense-long 表；同时保留一个仅用于下一轮验证的延迟防护候选。

在 R027 优先压力矩阵的回放中，旧 proxy 的 mean switching regret 为 `0.283`，dense-long 表为 `0.025`。R028 的保守 dense-anchor proxy 将 regret 降至 `0.025`，与 dense-long 表并列；stress-calibrated guarded candidate 在同一压力集合上为 `0.000`，但由于该规则由 R027 压力点校准得到，只能作为 R029 held-out 派生仿真的候选策略，不能写成独立泛化结论。

这一结果的价值不在于宣称 proxy 已优于查表，而在于把 PIS-IEK 小信号/事件域模型中的 `tau_AI`、目标函数权重和 skip/settling 风险转化为可部署的监督层安全接口：AI 或表驱动监督器可以先给出候选 `T_slew`，再经过 `B_epsilon` 投影，避免在开关级压力场景中选择明显过慢的参考斜率。
