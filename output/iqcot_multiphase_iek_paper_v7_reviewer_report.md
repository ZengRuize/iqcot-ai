# v7 稿件审稿式评估报告

## Review setup

- Input scope: `iqcot_multiphase_iek_paper_v7_validated_budgeted.md` 及本轮新增数据文件、Simulink trim 副本、Monte Carlo 报告。
- Assessment boundary: 这是预投稿/毕业论文外审式评估，不是编辑决定。评估依据仅限本地稿件事实、用户提供的审稿建议和 Nature-style 评审轴。
- Shared manuscript claim summary: 稿件提出面向四相数字 IQCOT Buck 的相索引积分事件映射模型，核心贡献不是重新提出 IQCOT 或 COT sampled-data，而是把面积事件、`phase_idx`、积分 reset、`Lambda_i/Ton_i` 执行量、数字量化和受限均流设计统一进 event-to-event Jacobian 与工程预算框架。
- Visible evidence base: IEK/PIS-IEK 推导，32 行局部灵敏度、10 行模态投影、77 个幅值扫描、80 个 lifted 频响、20--50 A 静态负载扫点、27 个 Simulink trim 样本、12 行 Simulink 有限差分 Jacobian、4096 行 Monte Carlo 明细和 256 行聚合预算。
- Missing materials affecting confidence: 尚无硬件实测、PLECS/硬件等价模型、phase-overlap 区域验证、完整外环补偿器状态空间、MOSFET/driver/PCB 非理想链路、严格任意 duty 推广证明。

## Reviewer 1

- Overall assessment: 技术链条比 v6 明显增强。新增 Simulink trim 副本和 Monte Carlo 预算让“执行量分类”从解析脚本结论变成了多层证据。但作为高水平英文期刊稿，技术边界仍需主动收缩；作为硕士论文或中文工程论文，当前证据已经相当充分。
- Who would be interested in the results, and why: 多相 VRM、数字 COT/IQCOT 控制、DPWM/ADC 量化预算、相电流均衡设计的研究者会感兴趣，因为稿件给出了“哪个执行量影响哪个物理通道”的可计算依据。
- Major strengths: PIS-IEK 将 `phase_idx`、面积事件、reset 与执行量写进统一事件映射；Simulink trim 副本直接暴露 `Lambda1..4` 与 `Ton_trim1..4`；Monte Carlo 将位宽、检测时钟和比较器延迟转化为可引用的 jitter 预算。
- Major concerns: Simulink 有限差分使用 `4 ns` Ton 步长，属于有限步长方向验证，不是严格微分；20 A 工况 baseline phase-spacing std 很大，说明模型在低负载下事件时序已有不规则性，不能把该点作为理想线性工作点解释；`Ton_m2` 对电流通道的 Simulink 增益与解析模型数量级并不完全一致，需要解释模型层级差异。
- Technical failings that need to be addressed before the case is established: 需要明确每个验证层的用途和不可互换性；需要在正文中说明 ps 级 Ton 在 Simulink 中被时序量化吞没的观察；需要避免把 Monte Carlo 事件域结果说成开关电路瞬态纹波或硬件实测。
- Assessment against Nature-style criteria: originality 较好但必须限定为四相数字 IQCOT 事件映射嵌入；scientific importance 对电源电子领域明确，对跨学科读者有限；interdisciplinary readership 尚弱；technical soundness 对毕业论文强，对顶刊仍缺硬件/phase-overlap；readability 对非专业读者偏难。
- Recommendation posture: 支持作为硕士论文/中文期刊方向继续完善；若面向 TPEL/JESTPE，建议 major revision 级补证。

## Reviewer 2

- Overall assessment: 创新表述比早期版本更稳，最值得保留的是“相索引积分事件映射 + 执行量分类 + 数字预算”。稿件不应再扩张为“提出新的 saltation 方法”或“通用多相 COT 小信号模型”。
- Who would be interested in the results, and why: 关心 digital COT 调参、相位间隔控制、均流执行量设计的工程研究者会使用这些矩阵与预算表，因为它们可直接指导 `Lambda_diff` 和 `Ton_diff` 的分工。
- Major strengths: 稿件已经有清楚的负面边界：不声称首次提出 IQCOT，不声称取代传统 loop-gain 或 sampled-data 模型。新增 v7 章节也把 reviewer guidance 中最重要的两个缺口补上了一部分。
- Major concerns: 与已有 IQCOT、高频小信号模型、DICOT、高分辨率均流、多相 COT phase-overlap 的对比仍主要是文字边界，缺少更正式的文献表格和公式对照；若投稿英文期刊，相关工作章节还需要把已有模型具体能解释什么、不能解释什么写得更尖锐。
- Technical failings that need to be addressed before the case is established: 建议增加一张“已有模型 vs 本文模型状态变量/事件函数/执行量/输出指标”的对比表；在摘要和贡献中减少“盐跃”权重，主标题可用“phase-indexed event-map linearization”更稳；需要把 12 行 Simulink Jacobian 的有限步长性质写进方法而不是只放局限。
- Assessment against Nature-style criteria: originality 在工程建模组合上成立；scientific importance 是 field-local strong，不是 broad scientific outstanding；interdisciplinary readership 较有限；technical soundness 对主张“执行量分类”基本成立；readability 需要更强图示和术语表。
- Recommendation posture: promising but broad-interest case remains underdeveloped.

## Reviewer 3

- Overall assessment: 稿件材料丰富，但对非本领域读者仍偏重。v7 的实验量已经足够支撑“不是单点调参”，但论文叙事应从“我做了很多仿真”转为“为什么这些仿真分别验证理论、开关电路和数字实现预算”。
- Who would be interested in the results, and why: 电源管理 IC、VRM 控制、FPGA/数字电源实现方向读者会关心。更广的控制理论读者可能只对混杂系统事件映射嵌入工程系统这一点感兴趣，但需要更清晰的抽象层次。
- Major strengths: v7 证据链四层划分非常有帮助；数据清单完整，可复现性增强；发现 ps 级 Ton 修正在 Simulink 中被吞没这一点很实际，能说明为什么数字控制必须有分辨率预算。
- Major concerns: 摘要过长且信息密度过高；中文正文中中英符号混排多，非专业读者会吃力；图表编号较多，建议把核心论文图压缩到 6--8 张，其余放附录。
- Technical failings that need to be addressed before the case is established: 需要一个总框图，把 `Lambda_cm/Lambda_diff/Ton_diff/delay_diff` 到 `wait/phase-spacing/current-sharing` 的通道画清楚；需要将 v7 新增的 Simulink FD 与 Monte Carlo 放入主证据链，而非作为最后追加章节；需要统一 `Lambda`、`Λ`、`螞` 等符号，避免编码/字体造成阅读问题。
- Assessment against Nature-style criteria: originality 可以被专业读者理解，但非专业读者需要更强引导；scientific importance 对电源工程明确；interdisciplinary readership 目前不足；technical soundness 在可复现实验层面提升明显；readability 是当前最明显短板。
- Recommendation posture: technically promising, but readability and positioning need substantial revision.

## Cross-review synthesis

- Consensus strengths: v7 已经把核心创新从“漂亮推导”推进到“理论模型、解析验证、Simulink 电路副本、数字实现预算”四层证据链。`Lambda_diff` 弱 DC 均流、`Ton_diff` 强均流但有时序代价的结论得到更强支撑。
- Consensus technical risks: 仍需克制在四相、低占空比、非 phase-overlap 区域；Simulink FD 是有限步长验证；Monte Carlo 是事件域预算；缺硬件/PLECS/phase-overlap/完整外环。
- Where emphasis differs across reviewers: Reviewer 1 最关注技术证据和有限差分解释；Reviewer 2 最关注创新边界和已有文献区分；Reviewer 3 最关注论文叙事与可读性。
- Broad-interest / significance readout: 对电源电子领域是有价值的工程建模与设计方法；对 Nature-style broad interdisciplinary readership 的吸引力尚未建立，不应以此定位。
- Most important issues to resolve before a strong Nature-style case is established: 增补 phase-overlap 或主动收缩边界；加入硬件/PLECS/更高保真电路验证；把外环补偿器纳入状态空间；压缩叙事并增加总框图；进一步系统化文献对比。

## Risk / unsupported claims

- 不应声称首次提出 IQCOT、COT sampled-data、多相 COT 小信号模型或 saltation/Poincare 方法。
- 不应声称 PIS-IEK 已覆盖任意 duty、任意相数或 phase-overlap 区域。
- 不应把 4096 行 Monte Carlo 解释为开关电路级仿真或硬件样机验证。
- 不应把 Simulink `4 ns` Ton 有限差分解释为严格微分灵敏度；它是考虑模型有效时序分辨率后的方向/量级验证。
- 不应忽略 20 A 低负载下 phase-spacing std 较大的事实；该点说明事件时序在某些负载下更不规则，反而应作为数字实现风险讨论。
