# 多相数字 IQCOT IEK 论文最终自审与完整性报告

## Review setup

- Input scope: `iqcot_multiphase_iek_paper_final.md` 完整论文草稿、6 张 SVG 图、单相动态 IEK 验证、多相 common/differential 仿真、DCR/Ri 失配动态验证、Crossref DOI 元数据核查。
- Assessment boundary: 本评审只基于本地脚本、CSV、草稿和 DOI/Crossref 元数据；不假定已有硬件实验或严格 Simulink 面积事件控制器验证。
- Shared manuscript claim summary: 论文声称提出面向多相数字 IQCOT Buck 的积分事件核（IEK）模态建模方法，将 IQCOT 面积事件分解为 common-mode 与 differential-mode 通道，并区分 Lambda_cm、Lambda_diff、Ton_diff 在输出调节、相位间隔和均流中的作用。
- Visible evidence base: 单相动态 IEK 最大周期幅值误差 <0.00018%；四相 common-mode He-only 最大误差 3512.46%；差模面积偏置导致约 1 ns wait pk-pk 但平均相电流 pk-pk <0.002 mA；失配动态仿真显示强 DCR no-trim 和 Lambda_diff-only 均约 4.086 A pk-pk，而 full Ton-trim 后残差约 0.029 A。
- Missing materials affecting confidence: 无硬件验证；无严格 Simulink 面积积分控制器验证；外环补偿器仅以慢速 common-mode VC 适配器近似；MOSFET 非线性、死区、采样/量化同步未纳入。

## Reviewer 1

### Overall assessment

新版论文已经形成清晰的技术闭环。单相 IEK 不再单独承担创新压力，而是作为多相模态 IEK 的理论基础；新增失配动态验证显著增强了“Lambda_diff 不是 DC 均流执行量”的说服力。

### Who would be interested in the results, and why

多相 VRM、数字 COT/IQCOT 控制、phase manager、DPWM 细调和 current balance 设计者会感兴趣，因为论文把 jitter、phase spacing 和 current sharing 放入了同一个事件域设计框架。

### Major strengths

- 创新边界稳健，没有声称首次提出 IQCOT 或 COT sampled-data。
- 单相动态 IEK 与非线性事件仿真闭合，证明模型不是纯形式推导。
- 多相 common/differential 分解直接对应工程执行量。
- 新增失配动态仿真补足了旧版“DC algebra + timing cost”证据不足的问题。

### Major concerns

- 慢速 VC 适配器不是完整补偿器，不能替代闭环控制设计验证。
- Ton-trim 的相位代价在受限补偿工况中仍较大，需要在答辩和论文中强调约束设计而非无限制均流。
- 图表为独立 SVG，后续若转 Word/LaTeX 需要确认字体、尺寸和图题编号。

### Technical failings that need to be addressed before the case is established

- 若目标是正式投稿，应补一个严格面积事件 Simulink 模型或硬件波形验证。
- 应补充含 DPWM/ADC 量化、采样延迟和死区的工程验证。
- 应将外环 PI/Type-III 补偿器状态纳入 K_m(z)，或明确说明本文只研究事件链路和功率级记忆。

### Assessment against Nature-style criteria

- Originality: 对电源电子子领域有明确原创性，核心在多相 IQCOT 面积事件核模态化与执行量分类。
- Scientific importance: 对 VRM 数字控制设计有实用价值，但主要是领域内方法贡献。
- Interdisciplinary readership: 当前读者主要是电源电子和数字控制方向，跨学科广度有限。
- Technical soundness: 理论和仿真证据较强，工程验证仍不足。
- Readability for nonspecialists: 通过图 1 和图 3 已改善，但公式密度仍较高。

### Recommendation posture

作为硕士毕业论文核心创新已经较强；作为期刊初稿有潜力，但需补 Simulink/硬件或完整闭环补偿器验证。

## Reviewer 2

### Overall assessment

论文最有价值的结论是执行量分类：Lambda_cm、Lambda_diff 和 Ton_diff 不是同一个“调参旋钮”。该分类在匹配与失配动态仿真中都得到支持，尤其是 Lambda_diff-only 在 DCR 失配下几乎不改善电流不均，这一负结果很有辨识度。

### Who would be interested in the results, and why

研究多相 DICOT/IQCOT current balance 的读者会感兴趣，因为论文说明了为什么单纯面积阈值差模调节不应被当作 DC 均流执行量。

### Major strengths

- 与 Bari、Gabriele、Yan/Ruan/Li、Li 2024、Sridhar/Li、Liu 2023 的边界写得明确。
- 新增 Crossref 核查后参考文献可信度提高。
- 论文保留了局限性，不把仿真结果写成硬件结论。

### Major concerns

- 目前参考文献数量仍偏少，若投专业期刊，建议补充更多 multi-phase VRM current balance、digital COT implementation、DPWM resolution/jitter 文献。
- IEK 的“新”与已有 sampled-data 模型的差异在方法章节已经写出，但还可以在相关工作中用表格更直观地比较。
- 失配动态模型的 VC 适配器需要更明确的控制律参数和稳定性说明。

### Technical failings that need to be addressed before the case is established

- 应补充模型假设表：理想同步 Buck、连续导通、固定 on-time、轮转相位管理、忽略开关非线性等。
- 应给出失配动态仿真的控制参数，例如 VC 适配增益和夹紧范围。
- 应把小信号适用边界量化，例如 Ton_trim 或 wait perturbation 相对 Tglobal 的上限。

### Assessment against Nature-style criteria

- Originality: 中等偏强，贡献是已有方法的多相 IQCOT 事件域重组和执行量分解。
- Scientific importance: 对专业领域有明确价值。
- Interdisciplinary readership: 不足以支撑 broad-interest 期刊，但适合电源电子/控制类论文。
- Technical soundness: 当前证据足以支撑毕业论文主张。
- Readability for nonspecialists: 需要在摘要和引言中继续减少缩写密度。

### Recommendation posture

建议接受为毕业设计论文核心稿；若投稿，建议增加文献表格、工程模型验证和补偿器扩展。

## Reviewer 3

### Overall assessment

新版论文的叙事比旧版成熟：从“AI 调参”转为“事件核建模与受限均流设计”，研究对象更清晰，也更容易答辩。图 5 和图 6 让实际价值更直观。

### Who would be interested in the results, and why

VRM firmware、数字控制器实现、相位管理器和自动调参约束设计读者会感兴趣，因为论文给出可执行的参数分工。

### Major strengths

- 图表覆盖了框架、验证、模态分解和设计 tradeoff。
- 摘要中包含定量结果，读者能快速判断贡献强度。
- 附录包含 claim-evidence matrix 和图表追踪说明，增强可复现性。

### Major concerns

- 论文仍偏“方法 + 仿真”，缺少与实际器件约束的深度耦合。
- 图 5 使用双 y 轴，虽然表达紧凑，但正式投稿时可考虑拆成两个面板以避免误导。
- 英文摘要可以进一步压缩，以适配期刊摘要长度。

### Technical failings that need to be addressed before the case is established

- 图表 trace 已有，但建议补每个 CSV 的生成命令和脚本版本/hash。
- 需要在正文说明为何 max_step=20/10/5 ns 收敛完全一致，避免读者怀疑数值积分过粗。
- 如果答辩委员会偏工程实现，需准备 Simulink v0027 与本文模型关系的单独说明页。

### Assessment against Nature-style criteria

- Originality: 对本领域读者有新意。
- Scientific importance: 工程方法贡献明确，但不是广泛科学突破。
- Interdisciplinary readership: 主要局限在电源电子。
- Technical soundness: 当前适合毕业论文，投稿前还需工程验证。
- Readability for nonspecialists: 图示改善明显，但仍需口头答辩中用“调相位”和“调均流”的直观类比解释。

### Recommendation posture

建议作为高质量硕士论文主稿继续完善格式与仿真附录；投稿前补 Simulink/硬件和更多文献。

## Cross-review synthesis

### Consensus strengths

- 创新边界清晰，不与已有 IQCOT/COT sampled-data 工作正面冲突。
- 多相 IEK + 执行量分类是足以支撑毕业论文的核心贡献。
- 新增失配动态验证显著增强了证据链。
- 图表和附录提高了可读性与可复现性。

### Consensus technical risks

- 尚无硬件或严格 Simulink 面积事件验证。
- 外环补偿器没有完整纳入 K_m(z)。
- 大 Ton-trim 或大 wait perturbation 可能超过小信号范围。
- 工程非理想因素尚未纳入。

### Where emphasis differs across reviewers

- Reviewer 1 更关注技术闭环和验证层级。
- Reviewer 2 更关注创新边界、文献覆盖和方法差异。
- Reviewer 3 更关注图表表达、答辩可读性和提交格式。

### Broad-interest / significance readout

该工作对多相 VRM 和数字 IQCOT 控制设计具有明确领域价值；目前更适合硕士论文和电源电子专业期刊初稿，不宜包装为 broad-interest 科学突破。

### Most important issues to resolve before a strong Nature-style case is established

1. 补严格面积事件 Simulink 或硬件验证。
2. 将外环补偿器状态纳入多相 K_m(z)。
3. 增加实际 DPWM/ADC 量化、采样延迟、死区和 MOSFET 非线性。
4. 增加更系统的文献对比表。
5. 量化小信号适用边界。

## Risk / unsupported claims

- 不能声称首次提出 IQCOT。
- 不能声称首次提出 COT sampled-data。
- 不能声称首次提出多相数字 COT 均流。
- 不能声称已有硬件验证。
- 不能把慢速 VC 适配器写成完整外环补偿器。
- 不能把受限 Ton-trim 的小信号趋势推广到任意大扰动。

## Integrity verification summary

### Reference existence and metadata

已用 Crossref API 核查 DOI 元数据：

| Ref | DOI | Crossref status | Metadata note |
|---|---|---|---|
| [2] Bari ECCE 2018 | 10.1109/ECCE.2018.8557464 | VERIFIED | pp. 6000-6007 |
| [3] Bari JESTPE 2021 | 10.1109/JESTPE.2020.2973151 | VERIFIED | vol. 9, no. 1, pp. 68-78；已修正旧页码错误 |
| [4] Yan/Ruan/Li TPEL 2022 | 10.1109/TPEL.2021.3132619 | VERIFIED | vol. 37, no. 6, pp. 6371-6384 |
| [5] Gabriele TCSI 2025 | 10.1109/TCSI.2025.3557278 | VERIFIED | vol. 72, no. 6, pp. 2942-2955 |
| [6] Li IJCTA 2024 | 10.1002/cta.3924 | VERIFIED | vol. 52, no. 7, pp. 3188-3212 |
| [7] Sridhar/Li TPEL 2024 | 10.1109/TPEL.2024.3368343 | VERIFIED | vol. 39, no. 6, pp. 6703-6720 |
| [8] Liu TPEL 2023 | 10.1109/TPEL.2023.3268613 | VERIFIED | vol. 38, no. 7, pp. 8379-8393 |

Reference [1] 为 Virginia Tech 机构库博士论文页面，正文提供 URL。

### Data and figure trace

- 所有定量结果均来自 `E:/Desktop/codex/output` 下脚本和 CSV。
- 图 1 与图 3 是概念示意图，不承载数值 claim。
- 图 2、图 4、图 5、图 6 均由 `iqcot_generate_paper_figures.py` 从对应 CSV 生成。

### Verdict

**PASS WITH NOTES**：作为毕业论文主稿当前证据链基本成立；作为投稿论文仍需补工程验证、补偿器建模和更完整文献覆盖。
