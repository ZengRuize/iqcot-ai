# 实验计划：延迟感知混合事件 PIS-IEK 的切载瞬态与 AI 调参验证

**问题**：现有四相数字 IQCOT / PIS-IEK 研究已经验证稳态小信号执行量分类，但尚未系统验证切载瞬态和 FPGA AI 微秒级延迟对训练/调参效果的影响。

**方法主张**：将 PIS-IEK 扩展为包含 `normal/skip/reentry` 模式和事件索引输入滞后的混合事件模型，可作为 AI 调参训练的物理约束环境，并解释切载恢复阶段的相位、均流和频率动态。

**日期**：2026-06-20

## Claim Map

| Claim | Why It Matters | Minimum Convincing Evidence | Linked Blocks |
|---|---|---|---|
| C1：延迟感知 PIS-IEK 能降低 AI 训练到 FPGA 部署的偏差 | FPGA AI 推理延迟为 us 级，已跨越多个四相事件；无延迟训练可能在硬件上失效 | `tau_AI=1-5 us` 下，延迟感知策略比无延迟训练策略有更低相位抖动、均流误差或更少约束违规 | B1, B3 |
| C2：混合事件 PIS-IEK 能解释切载后的 skip/reentry 恢复动态 | 大切载不是单一小信号过程；必须区分峰值、跳脉冲和重入稳态 | `40A->20A/10A/0A` 中，模型预测的 `N_skip`、重入相位扰动趋势与 Simulink 一致 | B2, B4 |
| C3：PIS-IEK 约束投影使 AI 调参更安全 | AI 不能直接输出不受限参数，必须满足相位、均流、频率和 Ton 限幅 | 安全投影组在延迟和量化存在时约束违规次数更少，且性能不明显劣化 | B3, B5 |

## Paper Storyline

- 主文必须证明：PIS-IEK 不只是稳态小信号矩阵，也能作为延迟感知 AI 调参和切载恢复分析的物理骨架。
- 附录可以支持：不同延迟分布、不同更新周期、不同切载斜率和不同负载终值。
- 暂时剪掉：复杂神经网络架构比较、端到端 gate-level RL、任意相数推广、phase-overlap 区域完整理论。

## Experiment Blocks

### Block 1：AI 推理延迟预算与事件滞后映射

- Claim tested：C1
- Why this block exists：证明 `us` 级 AI 延迟不能忽略，必须转成事件索引延迟。
- Dataset / split / task：解析计算 + 事件域仿真；四相 500 kHz 基准。
- Compared systems：
  - no-delay model：`u_eff,k=u_AI,k`
  - delay-aware model：`u_eff,k=u_AI,k-d`
  - jittered delay model：`d_k` 随 `tau_AI` 抖动变化
- Metrics：
  - `d=ceil(tau_AI/T_e)`
  - 约束违规率
  - phase-spacing std
  - current-sharing rms
- Setup details：
  - `tau_AI = 0, 0.5, 1, 2, 5 us`
  - `T_update = 2, 5, 10, 20 us`
  - 量化：沿用 v7 Monte Carlo 的位宽/时钟/`Ton` 分辨率代表点
- Success criterion：延迟感知模型能准确解释无延迟训练在非零延迟下的性能劣化方向。
- Failure interpretation：若延迟对指标几乎无影响，AI 可只作为慢速 supervisor；论文中降低 AI 延迟建模权重。
- Table / figure target：主文 Figure A：`tau_AI -> event delay -> performance degradation`
- Priority：MUST-RUN

### Block 2：切载混合事件模式识别

- Claim tested：C2
- Why this block exists：补齐 v7 中“静态负载扫点不是负载阶跃验证”的缺口。
- Dataset / split / task：Simulink 四相模型负载阶跃。
- Compared systems：
  - baseline PIS-IEK area model
  - hybrid PIS-IEK normal/skip/reentry model
  - switching Simulink reference
- Metrics：
  - `Vpk`
  - `N_skip`
  - `t_reentry`
  - `t_settle`
  - `sigma_phi,reentry`
  - `sigma_I,reentry`
- Setup details：
  - load steps：`40A->20A`, `40A->10A`, `40A->0A`
  - edge rates：ideal step, `0.5 us`, `2 us`
  - solver step：切换边沿和 dead-time 可观测，参考技能建议最大步长不粗于 `2 ns` 用于精细开关分析
- Success criterion：hybrid 模型能正确预测 skip/reentry 次数趋势和重入相位扰动趋势。
- Failure interpretation：若 `N_skip` 不一致，说明事件条件或 blanking/min-off 约束建模缺失。
- Table / figure target：主文 Figure B：切载波形与模式标签；Table B：模式指标对比。
- Priority：MUST-RUN

### Block 3：延迟感知 AI 调参策略对比

- Claim tested：C1, C3
- Why this block exists：验证 PIS-IEK 是否真的改善 AI 训练效果，而不是只提供解释。
- Dataset / split / task：基于 PIS-IEK surrogate + 少量 Simulink 校准点的参数优化。
- Compared systems：
  - fixed IQCOT parameters
  - black-box BO/RL without delay model
  - delay-aware BO/RL with PIS-IEK state/action model
  - delay-aware + safety projection
- Metrics：
  - reward convergence steps
  - Simulink validation regret
  - constraint violation rate
  - `Vpk`, `t_settle`, `sigma_phi`, `sigma_I`
- Setup details：
  - 动作：`Lambda_cm`, `Lambda_diff`, `Ton_diff`, `delay_comp`
  - 安全约束：`Ton` 限幅、频率范围、phase-spacing std、均流 rms
  - 训练不直接控制 gate command
- Success criterion：延迟感知 + 物理约束策略在 `1-5 us` 延迟下保持更低违规率，并且验证指标优于无模型黑盒策略。
- Failure interpretation：若性能无优势，保留 PIS-IEK 作为安全过滤器而不是训练加速器。
- Table / figure target：主文 Table C：AI 策略对比；Figure C：训练曲线。
- Priority：MUST-RUN

### Block 4：小信号模型边界测试

- Claim tested：C2
- Why this block exists：明确 PIS-IEK 适用边界，避免过度声称。
- Dataset / split / task：切载幅度扫描。
- Compared systems：
  - single-Jacobian PIS-IEK
  - piecewise hybrid PIS-IEK
  - Simulink switching reference
- Metrics：
  - event-time error
  - `N_skip` error
  - reentry phase error
  - first peak prediction error
- Setup details：
  - `Delta I = -5, -10, -20, -30, -40 A`
  - 对每个幅度记录是否发生 skip
- Success criterion：小切载时单一 Jacobian 可用；大切载时 hybrid 模型明显更合理。
- Failure interpretation：若 hybrid 仍不佳，需要纳入完整 comparator/blanking/min-off 逻辑。
- Table / figure target：附录或主文 Figure D：适用边界图。
- Priority：MUST-RUN

### Block 5：执行量通道消融

- Claim tested：C3
- Why this block exists：验证 AI 利用 PIS-IEK 执行量分类后是否避免错误通道调参。
- Dataset / split / task：静态不匹配 + 切载恢复联合场景。
- Compared systems：
  - only `Lambda_diff`
  - only `Ton_diff`
  - `Lambda_diff + Ton_diff`
  - `Lambda_diff + Ton_diff + safety projection`
- Metrics：
  - DC current-sharing rms
  - phase-spacing std
  - output ripple
  - `Vpk`
  - constraint violations
- Setup details：
  - DCR mismatch：沿用 v7 mismatch grid 的代表点
  - load：40 A nominal + 切载至 20/10 A
- Success criterion：`Ton_diff` 仍是均流主执行量，`Lambda_diff` 更适合作相位/纹波辅助调节。
- Failure interpretation：若 `Lambda_diff` 在切载中变强，需区分 transient phase recovery 与 DC 均流。
- Table / figure target：主文 Table D：通道消融。
- Priority：NICE-TO-HAVE，但对论文解释力很高

## Run Order and Milestones

| Milestone | Goal | Runs | Decision Gate | Cost | Risk |
|---|---|---|---|---|---|
| M0 | 建立切载数据记录脚本 | 单个 `40A->20A` baseline | 能记录 `Vout`, `IL1-4`, `REQ`, `phase_idx`, `tr`, `Ton_i` | 0.5 天 | 模型信号命名不统一 |
| M1 | 模式标签验证 | 三个切载终值，ideal step | 能可靠标注 normal/skip/reentry | 1 天 | skip 判断阈值需定义 |
| M2 | AI 延迟预算仿真 | `tau_AI` 和 `T_update` 网格 | 无延迟策略在非零延迟下有可解释退化 | 1 天 | 指标可能不敏感 |
| M3 | 安全投影策略 | black-box vs delay-aware vs projected | projected 违规率更低 | 1-2 天 | BO/RL 实现复杂，可先用 constrained random search |
| M4 | 通道消融 | `Lambda_diff`/`Ton_diff`/joint | 结论与 v7 执行量分类一致 | 1 天 | 切载期间通道作用可能不同 |
| M5 | 论文整合 | 图表与文字 | 边界清晰，不夸大 AI 控制 | 0.5 天 | 叙事过散 |

## Compute and Data Budget

- 总仿真成本：以 Simulink 开关模型为主，先少量核心点，再扩展网格。
- 数据准备：需要统一记录 `Vout`, `IL1-4`, `REQ`, `phase_idx`, `trigger_time`, `Ton_i`, `Lambda_i`。
- 人工检查：需要手动查看至少 3 组切载波形，确认模式标签没有误判。
- 最大瓶颈：Simulink 切换仿真的运行时间和信号提取一致性。

## Risks and Mitigations

- 风险：大切载第一峰值与 PIS-IEK 预测差异大。
  - 缓解：明确第一峰值用能量模型解释，PIS-IEK 负责 skip/reentry 恢复。
- 风险：AI 延迟策略收益不明显。
  - 缓解：把结论改为“安全过滤和部署一致性”，不强行声称性能提升。
- 风险：模型低负载时 phase-spacing 本身不规则。
  - 缓解：把低负载不规则作为数字 IQCOT 风险讨论，不当作失败掩盖。
- 风险：AI 控制叙事喧宾夺主。
  - 缓解：论文主贡献仍是 PIS-IEK 建模；AI 是应用价值和扩展验证。

## Final Checklist

- [ ] 主文表格覆盖切载指标
- [ ] 明确小信号模型和大信号峰值的边界
- [ ] 证明 AI 延迟被纳入训练环境
- [ ] 证明安全投影降低约束违规
- [ ] 区分 `Lambda_diff` 与 `Ton_diff` 的作用
- [ ] 不声称 AI 直接控制开关级事件

