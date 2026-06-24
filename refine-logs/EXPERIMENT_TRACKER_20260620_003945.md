# Experiment Tracker

| Run ID | Milestone | Purpose | System / Variant | Split | Metrics | Priority | Status | Notes |
|---|---|---|---|---|---|---|---|---|
| R001 | M0 | 检查切载信号记录链 | Simulink state-carry surrogate | `40A->20A/10A/near-0A` | `Vout`, `IL1-4`, gate edge, phase spacing | MUST | DONE | 已通过两段仿真和 final state 继承获得首轮结果 |
| R002 | M1 | 标注中等切载模式 | Hybrid PIS-IEK + Simulink | `40A->20A` | `N_skip`, settle time, `sigma_phi` | MUST | DONE | `hold` 无明显 skip；`instant` 出现 1 次估计 skip |
| R003 | M1 | 标注大切载模式 | Hybrid PIS-IEK + Simulink | `40A->10A` | `Vpk`, `N_skip`, `sigma_phi` | MUST | DONE | 两种参考处理均出现 1 次估计 skip，相位扰动增大 |
| R004 | M1 | 极端切载边界 | Hybrid PIS-IEK + Simulink | `40A->near-0A` | `Vpk`, `N_skip`, reentry | MUST | DONE | `instant` 出现 2 次估计 skip，欠压/恢复扰动显著 |
| R004b | M1 | 受控动态负载复核 | Simulink dynamic load copy | `40A->20A/10A/near-0A`, hold ref | `Vpk`, `Vmin`, `N_skip`, `sigma_phi` | MUST | DONE | 连续动态负载确认切载越深 skip 越明显；近空载 estimated skip=2 |
| R004c | M1 | 同步参考阶跃复核 | Simulink dynamic refstep copy | `dynamic_hold` vs `dynamic_instant` | `Vmin`, `N_skip`, final error, `sigma_phi` | MUST | DONE | instant 降低最终静差但显著放大欠压；near-0 欠压从 9.451 mV 到 35.750 mV |
| R004d | M1 | 参考斜率扫描 | Simulink dynamic refslew copy | `T_slew=0,5,10,20,40us` | `Vmin`, final error, skip, tradeoff score | MUST | DONE | 40 us 为当前网格最佳折中；near-0 欠压从 35.750 mV 降至 10.897 mV 且 final error 约 -0.569 mV |
| R005 | M2 | AI 延迟事件映射 | PIS-IEK surrogate | `tau_AI=0,0.5,1,2,5us` | event delay, constraint violation | MUST | DONE | 已完成 15360 episode surrogate；`5us` 延迟约等于 10 个 IQCOT 事件 |
| R006 | M2 | 更新周期扫描 | PIS-IEK surrogate | `T_update=2,5,10,20us` | `sigma_phi`, `sigma_I`, reward | MUST | DONE | 已发现 `20us` 更新周期显著增加 violation，支持显式预算 AI 更新周期 |
| R007 | M3 | 无延迟训练基线 | Black-box tuner | cut-load set | reward, violations | MUST | TODO | 用作反例，不直接声称可上硬件 |
| R008 | M3 | 延迟感知训练 | Delay-aware tuner | cut-load set | reward, violations | MUST | TODO | 动作进入模型时使用 `u_{k-d}` |
| R009 | M3 | 安全投影训练 | Delay-aware + projection | cut-load set | violations, `Vpk`, `sigma_phi` | MUST | TODO | 关键 AI 价值验证：PIS-IEK 约束减少危险动作 |
| R010 | M4 | 小信号边界扫描 | Single-Jacobian PIS-IEK | `Delta I=-5:-40A` | event-time error | MUST | TODO | 找出不发生 skip 的线性有效区 |
| R011 | M4 | 混合模型边界扫描 | Hybrid PIS-IEK | `Delta I=-5:-40A` | `N_skip` error | MUST | TODO | 证明 hybrid extension 的必要性 |
| R012 | M5 | 执行量通道消融 | `Lambda_diff` only | mismatch + cut-load | `sigma_I`, `sigma_phi` | NICE | TODO | 验证面积核差模不是 DC 均流主通道 |
| R013 | M5 | 执行量通道消融 | `Ton_diff` only | mismatch + cut-load | `sigma_I`, `sigma_phi` | NICE | TODO | 验证强均流能力及其相位代价 |
| R014 | M5 | 联合安全策略 | `Lambda+Ton+projection` | mismatch + cut-load | all key metrics | NICE | TODO | 论文应用亮点候选 |
