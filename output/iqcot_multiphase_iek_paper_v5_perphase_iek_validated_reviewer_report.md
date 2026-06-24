# v5 稿件审稿式自查报告：逐相 IEK 面积核验证版

## Review setup

- Input scope: `iqcot_multiphase_iek_paper_v5_perphase_iek_validated.md` 及其本地脚本、CSV、图表和 Simulink 副本验证摘要。
- Assessment boundary: 本报告只基于当前稿件与本地生成证据，不假设已有硬件样机、PLECS 复现、完整 Bari IQCOT 控制器实现或更多未展示数据。
- Shared manuscript claim summary: 稿件提出四相数字 IQCOT Buck 的积分事件核小信号建模框架，强调 `H_e+K(z)` 动态面积刚度、common/differential 模态执行量分类，以及受限均流设计结论：`Λ_diff` 更适合调节 phase spacing/ripple cancellation，`Ton_diff` 或等效逐相伏秒量才是主要 DC current-sharing 执行量。
- Visible evidence base: 单相动态 IEK 数值验证、四相 common-mode 密集扫频、执行量矩阵、DCR 失配网格、数字 jitter 预算、原用户 Simulink 模型 on-time 交叉验证、面积触发 IEK-REQ 副本验证、逐相 `h_i=Varea_bias+e_v+Ri_area(Iph-IL_i)` 面积核副本验证、20--50 A 静态负载扫点。
- Missing materials affecting confidence: 尚无严格完整的 Bari IQCOT `v_c-R_i i_L` 控制器 Simulink 实现，尚无负载阶跃瞬态/输入扰动/参数蒙特卡洛的系统性闭环验证，尚无硬件数据，phase_idx 与 next-phase 阈值对应关系仍需更精确形式化。

## Reviewer 1

- Overall assessment: 技术证据链比 v4 明显更强。逐相电流项面积核是重要补强，因为它直接回应了“面积触发副本太工程化、没有逐相 IQCOT 电流项”的质疑。当前稿件已经适合写成毕业论文中的一章或一篇较完整的仿真建模论文雏形。
- Who would be interested in the results, and why: 多相 VRM、COT/IQCOT 小信号建模、数字电源控制和均流策略设计方向的读者会关心，因为稿件把面积阈值、on-time 差模、检测延迟差模分成了不同物理执行量。
- Major strengths: 结论不是单纯由解析脚本推出，而是经过原用户 Simulink 模型和两个面积触发副本逐步交叉验证。新增 20--50 A 静态负载扫点降低了“40 A 单点调参偶然性”的风险。`Ton_diff` 与 `Λ_m2` 的 DC 均流能力对比有数量级差异，工程解释清楚。
- Major concerns: v5 的逐相面积核仍是稳态偏置附近的工程实现，不等于完整 IQCOT 控制器。`phase_idx` 选择当前相阈值这一点可能影响差模结论，需要在正文中继续强调边界。
- Technical failings that need to be addressed before the case is established: 静态负载扫点已经补强，但仍需要至少一个动态工况验证，例如负载阶跃后 `Λ_cm`、`Λ_m2`、`Ton_diff` 对恢复时间、相电流峰值和 phase-spacing 的影响；需要更系统地说明逐相面积核中 `Varea_bias` 与实际 `v_c` 产生器的对应关系。
- Assessment against Nature-style criteria: 原创性在电源电子小信号建模领域有清晰局部创新；科学重要性主要是领域内重要，不是广泛跨学科重要；跨领域可读性有限；技术可靠性已有较强仿真支撑但还未到硬件级；非专业读者需要更简单的图解。
- Recommendation posture: 支持作为硕士毕业论文核心创新继续推进；若投高水平期刊，需要补动态工况、严格控制器实现和更多对比。

## Reviewer 2

- Overall assessment: 稿件的真正创新不在“提出 IQCOT”，而在把 IQCOT/COT 事件控制中的小信号扰动拆成可设计的模态执行量，并证明某些看似可用于均流的面积差模量实际不适合作为 DC 均流主通道。这一点有新意。
- Who would be interested in the results, and why: 做数字 COT、D-CAP/ripple-based control、multiphase current balance 的研究者会感兴趣，因为它给出了一套避免“调错参数”的建模语言。
- Major strengths: 与 Bari IQCOT、sampled-data ripple-based control、multiphase phase-overlap COT 文献能形成明确关系；稿件没有把 AI 调参写成空泛口号，而是先建立物理约束模型，这一点更扎实。
- Major concerns: 当前文献差异化已新增对比表，但仍可继续写得更锋利。应在引言中用更短的语言突出：已有 sampled-data/area-balance 思想不新，本文新意在四相数字 IQCOT 的 IEK 动态核、执行量矩阵和受限均流规则。
- Technical failings that need to be addressed before the case is established: 已增加与代表性模型的逐项对比表；下一步应把对比表中的“本文新增关注点”进一步连接到公式和仿真图，避免读者只把它看作文字声明。
- Assessment against Nature-style criteria: 原创性有潜力，但需要更强的 prior-art boundary；科学重要性偏工程方法学；跨学科意义不足；技术 soundness 在仿真层面较好；可读性对本领域读者尚可，对非专业读者偏难。
- Recommendation posture: 有希望成为一篇扎实的专业论文；创新声明应从“全新模型”收窄为“面向四相数字 IQCOT 的动态事件核与执行量分类建模”。

## Reviewer 3

- Overall assessment: 稿件内容充实，但读者进入门槛高。当前版本已补参数选择流程，适合技术评审；若要进一步提升可读性，还需要在开头加一张“为什么这个模型有用”的简图。
- Who would be interested in the results, and why: 除电源控制研究者外，做数字控制实现和优化调参的人也会关心，因为论文给出了哪些参数能调电压、哪些参数会扰动相位、哪些参数才能均流的约束。
- Major strengths: 工程价值明确：避免把 `Λ_diff` 当作主均流旋钮，给 AI/优化算法提供物理可解释边界；同时保留 `Λ_cm` 用于频率/事件间隔调节，`Ton_diff` 用于均流。
- Major concerns: 论文标题和摘要信息密度很高，建议拆分关键术语，避免读者一开始被 `IEK`、`Λ_m2`、`Ton_diff`、`phase-spacing` 同时压住。
- Technical failings that need to be addressed before the case is established: 实际设计步骤已经写成流程表；下一步应把流程表与脚本文件逐项对应，形成更可复现的“从参数到图表”的使用说明。
- Assessment against Nature-style criteria: 原创性与重要性主要面向电源电子专业读者；跨学科吸引力有限；技术证据足以支持阶段性论文；非专业可读性需要增强。
- Recommendation posture: 建议作为毕业论文优先完善表达与设计流程；若作为期刊论文，需要将主线从“模型很多”压缩为“一个模型解决一个明确设计错误”。

## Cross-review synthesis

- Consensus strengths: v5 通过逐相 IEK 面积核副本显著增强了关键结论的可信度；静态负载扫点进一步说明结论不是 40 A 单点偶然；`Λ_m2` 与 `Ton_diff` 的执行量分类有清楚仿真证据；该工作对数字多相 COT/IQCOT 参数设计有实际价值。
- Consensus technical risks: 当前还不是完整严格 IQCOT 控制器验证；静态负载扫点已有，但动态负载阶跃、输入扰动、参数蒙特卡洛和硬件验证仍缺失；`phase_idx` 阈值选择与实际 next-phase 事件关系需进一步形式化。
- Where emphasis differs across reviewers: Reviewer 1 更关注技术闭环完整性；Reviewer 2 更关注创新边界与文献对比；Reviewer 3 更关注论文表达、设计流程和读者可进入性。
- Broad-interest / significance readout: 对电源电子和数字 VRM 控制是有价值的专业创新；当前证据不足以声称广泛跨学科影响，但足以支撑硕士毕业设计中的核心创新章节。
- Most important issues to resolve before a strong case is established: 第一，补负载阶跃或扰动动态验证；第二，继续把静态负载扫点扩展为参数蒙特卡洛或输入扰动验证；第三，继续明确 Simulink 副本是探索验证，不是原始模型或完整商业控制器。

## Risk / unsupported claims

- 不应声称已经完整实现 Bari IQCOT 控制器；当前只能说实现了更接近逐相 IQCOT 小信号形式的面积核副本。
- 不应声称 `Λ_diff` 永远不能影响电流；更准确表述是：在当前四相工作点和验证模型中，它不是强 DC current-sharing 执行量，主要表现为 phase-spacing 扰动。
- 不应把解析 IEK 数值与 Simulink 电路级数值直接等量比较；可以比较方向、数量级差异和物理趋势。
- 不应把当前仿真证据外推到任意相数、任意 duty、phase-overlap 区域或硬件实现。
- 需要继续补充动态工况与严格控制器实现，才能把“阶段性创新”推进到“完整闭环控制方法”。
