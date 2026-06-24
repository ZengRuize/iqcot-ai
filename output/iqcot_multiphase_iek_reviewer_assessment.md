# 多相 IEK-IQCOT 创新点的审稿人式评审

## Review setup

- Input scope: 研究概念、推导报告、单相动态 IEK 验证、多相 common/differential 模态仿真、DCR 失配下 Ton-trim 均流设计链；尚非正式投稿稿件。
- Assessment boundary: 本评审只基于本地报告和脚本结果，不假定已有硬件实验或 Simulink 严格面积事件模型结果。
- Shared manuscript claim summary: 作者声称提出一种面向多相数字 IQCOT Buck 的积分事件核模态建模方法，将 IQCOT 面积事件分解为共模和差模事件核，并区分面积阈值、检测延迟、面积噪声与 Ton-trim 在周期 jitter、phase-spacing jitter 和 current-sharing 中的作用。
- Visible evidence base: 单相动态 IEK 与非线性逐周期仿真误差约 0.00018%；多相 common-mode 中 He-only 静态模型最大误差 3512.46%；差模阈值偏置产生约 1.0667 ns phase-spacing jitter 但平均相电流变化小于 0.002 mA；DCR 失配设计链显示 20% DCR 失配可产生 4.072 A pk-pk 电流不均，全均流 Ton-trim 需要 1 ns pk-pk 且可能造成大相位间隔代价；0.1 ns 限幅平均降低电流 pk-pk 约 31.98%，最大 wait cost 约 108.07 ns。
- Missing materials affecting confidence: 缺少硬件实验、缺少 Simulink 严格面积事件 IQCOT 验证、缺少外环补偿器状态纳入模型、缺少对实际数字延迟/DPWM 分辨率的器件级预算验证。

## Reviewer 1

### Overall assessment

本文的技术链条比最初的单相 IEK 更有说服力。作者没有把“事件驱动 sampled-data”本身当作原创，而是将贡献收敛到多相 IQCOT 面积事件的模态化建模和执行量分类。该方向具有明确工程价值，尤其是指出 Lambda_diff 和 Ton_diff 的作用不同，能够避免把阈值调节误当作均流控制。

### Who would be interested in the results, and why

多相 VRM、数字 COT/IQCOT 控制器、相位管理器和高分辨率均流方案的设计者会感兴趣，因为该模型把 jitter、phase-spacing 和均流执行量放入同一个定量框架。

### Major strengths

- 单相动态 IEK 与非线性逐周期仿真闭合，说明模型不是纯形式推导。
- 多相 common-mode 结果显示 He-only 模型可严重失效，给出了强烈的建模必要性。
- 差模阈值与 Ton-trim 的执行量分类是一个有价值的设计洞察。
- DCR 失配补偿链把研究从“模型漂亮”推进到“均流补偿量与相位代价”。

### Major concerns

- 多相模型仍是独立脚本模型，尚未在 Simulink 或硬件中验证。
- Ton-trim 带来的 wait_pkpk 在部分场景中过大，说明全均流补偿可能已经超出小信号范围。
- 外环 VC 动态尚未纳入多相 K_m(z)，这会限制模型对闭环 VRM 的预测能力。

### Technical failings that need to be addressed before the case is established

- 需要明确小信号适用边界，例如 Ton_trim 小于多少 ns 或 wait perturbation 小于 Tglobal 的多少比例。
- 需要加入至少一个含 L/DCR/Ri/driver delay mismatch 的动态仿真，而不仅是 DC algebra 加事件代价估计。
- 需要给出 K_0(z)、K_diff(z) 的识别流程图或伪代码，保证可复现。

### Assessment against Nature-style criteria

- Originality: 边界清楚后具有原创性，尤其是多相模态 IEK 与执行量分类。
- Scientific importance: 对电源电子子领域有较高重要性，但跨学科影响有限。
- Interdisciplinary readership: 主要是电源管理和数字控制读者；对广泛 Nature 读者不够直接。
- Technical soundness: 理论和数值仿真较强，但工程验证仍不足。
- Readability for nonspecialists: 需要增加示意图解释 common/differential modes 和执行量分类。

### Recommendation posture

支持作为硕士论文核心创新；若作为期刊论文，需要补充 Simulink/硬件级验证和闭环补偿器建模。

## Reviewer 2

### Overall assessment

本文最有价值的不是单相 IEK，而是从多相角度提出的“面积阈值调相位，Ton-trim 调均流”的结论。这个结论具有非显然性，因为许多读者可能直觉认为相阈值调节可直接实现均流。作者的仿真反而说明，在理想固定 Ton 与轮转相位管理下，Lambda_diff 主要是 phase-spacing actuator。

### Who would be interested in the results, and why

研究多相 DICOT/IQCOT current balance 的读者会感兴趣，因为本文给出了均流执行量分配的解释框架，也能为 AI 或优化器调参提供更安全的参数空间。

### Major strengths

- 创新边界没有夸大，承认 Bari、Gabriele、Li 等已有工作。
- 结果中包含一个“负结果”：Lambda_diff 不等于 DC 均流执行量。这增强了可信度。
- 受限 Ton-trim 结果显示补偿收益与相位代价之间存在清楚 tradeoff。

### Major concerns

- 论文若只强调 3512% 误差，可能被认为挑选了静态模型最不适用的频点；应同时报告在哪些频段 He-only 模型可用。
- DCR 失配补偿中的 phase-spacing cost 来自匹配动态事件模型而非完全失配动态模型，这一点必须在正文中透明说明。
- 目前引用与已有工作的差异需要更系统地写，特别是与多相 DICOT current balance 的区别。

### Technical failings that need to be addressed before the case is established

- 需要把“DC current-sharing algebra”和“dynamic phase-spacing cost”之间的耦合假设写清楚。
- 需要补充至少一个 ablation：去掉 K(z) 后误差如何变化，使用 K_0/K_diff 后误差如何下降。
- 需要把 Ton-trim 限幅的设计规则写成工程指标，例如 I_pkpk reduction per ns 与 wait_pkpk cost per ns。

### Assessment against Nature-style criteria

- Originality: 中等偏强；关键是执行量分类与多相模态化。
- Scientific importance: 对 VRM 控制设计有实际价值。
- Interdisciplinary readership: 较窄，除非把它包装为事件驱动电力电子系统的通用建模方法。
- Technical soundness: 数学与脚本结果支持核心结论，但验证层次仍偏仿真。
- Readability for nonspecialists: 需要更清楚地区分 He、Hs、K(z)、Lambda_diff、Ton_diff。

### Recommendation posture

有潜力，但需以“多相数字 IQCOT 设计工具”为中心重写，而不是以单相小信号推导为中心。

## Reviewer 3

### Overall assessment

作为论文叙事，本文已经从一个较抽象的小信号模型演化为更有读者价值的多相设计方法。当前最需要改进的是读者入口：非专业读者很难一开始理解为什么事件核比已有 sampled-data 模型更值得关注。建议用一个设计痛点开篇：多相 IQCOT 中同一个“调参”动作可能改善均流，却破坏 phase spacing。

### Who would be interested in the results, and why

除了电源电子控制读者，数字控制实现、VRM firmware/DPWM 设计、自动调参约束设计读者也可能感兴趣，因为模型直接涉及分辨率、延迟、jitter 和多目标约束。

### Major strengths

- 有清楚的问题化：均流、相位间隔、jitter 不能混为一个目标。
- 论文能产生设计建议：Lambda_cm、Lambda_diff、Ton_diff 应分别承担不同任务。
- 结果有定量支撑，尤其是受限 Ton-trim 的 tradeoff 表。

### Major concerns

- 若目标是“优质论文”，需要更强的图表表达：系统图、事件核示意图、共模/差模分解图、tradeoff 曲线。
- 现在文字中的“创新”仍需避免绝对措辞，应坚持“extends, formulates, separates, quantifies”等限定性动词。
- 缺少实验环境和代码可复现描述，例如步长、事件求解、矩阵指数、稳态收敛标准。

### Technical failings that need to be addressed before the case is established

- 需要明确多相模型假设：理想同步 Buck、固定 on-time、轮转 phase manager、忽略 MOSFET 非线性、无外环补偿动态。
- 需要用图或表展示模型适用边界。
- 需要把 Simulink v0027 与本文严格面积事件模型的关系写清楚，避免读者误以为已在 v0027 上完全验证。

### Assessment against Nature-style criteria

- Originality: 对本领域读者有明确新意。
- Scientific importance: 更像工程控制方法论文，不是广泛科学突破。
- Interdisciplinary readership: 需要更强概念化才可能外扩。
- Technical soundness: 目前可支撑毕业论文，不足以支撑高影响期刊的最终结论。
- Readability for nonspecialists: 需加入直观解释和术语表。

### Recommendation posture

建议作为硕士论文或专业期刊初稿继续发展；若投稿，需要补 Simulink/硬件验证和图表化叙事。

## Cross-review synthesis

### Consensus strengths

- 创新边界比早期版本更稳，不再与已有 IQCOT 小信号和 COT sampled-data 工作正面冲突。
- 多相 common/differential IEK 与执行量分类是当前最强贡献。
- 差模阈值不是 DC 均流执行量、Ton-trim 有强均流但带来 phase-spacing cost，是有价值的设计洞察。
- DCR 失配链条把模型与实际均流问题连接起来。

### Consensus technical risks

- 仍缺少严格 Simulink 或硬件验证。
- 外环补偿器和实际数字延迟尚未纳入。
- 部分 Ton-trim 场景超过小信号范围，必须限制解释。
- DCR 失配补偿中的 phase-spacing cost 与 DC current algebra 是组合验证，不是完整失配动态闭环验证。

### Where emphasis differs across reviewers

- Reviewer 1 更关注技术闭环和适用范围。
- Reviewer 2 更关注原创性边界和与已有多相 DICOT 的区别。
- Reviewer 3 更关注论文叙事、图表表达和非专业读者可读性。

### Broad-interest / significance readout

该工作对多相 VRM 和数字 IQCOT 控制设计有明确价值，但目前属于领域内重要方法，而不是广泛跨学科突破。若要提升影响力，应把方法表述为“事件驱动电力电子系统的模态化设计框架”，并用更强验证展示它能改变实际设计决策。

### Most important issues to resolve before a strong case is established

1. 增加显式面积 IQCOT Simulink 验证。
2. 纳入外环 VC 补偿器状态。
3. 加入实际相参数失配动态仿真。
4. 把 Ton-trim tradeoff 限定在线性适用范围。
5. 生成系统图、模态分解图和设计流程图。

## Risk / unsupported claims

- 不能声称首次提出 IQCOT 小信号模型。
- 不能声称首次提出多相数字 COT 均流。
- 不能声称本文已完成硬件验证。
- 不能声称 Ton-trim 可无代价均流。
- 不能把 DCR 失配 DC algebra + 匹配事件模型 timing cost 写成完整失配动态闭环验证。
