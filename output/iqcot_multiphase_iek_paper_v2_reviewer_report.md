# 四相 IQCOT IEK 论文 v2 审稿式评估报告

## 评估对象

- 稿件：`E:/Desktop/codex/output/iqcot_multiphase_iek_paper_v2_four_phase_dense.md`
- DOCX：`E:/Desktop/codex/output/iqcot_multiphase_iek_article_v2_four_phase_dense.docx`
- 数据：`E:/Desktop/codex/output/iqcot_four_phase_*.csv`、`E:/Desktop/codex/output/iqcot_digital_*_budget.csv`
- 图表：`E:/Desktop/codex/output/figures/fig7_dense_common_sweep.png` 至 `fig10_jitter_budget.png`

## 总体结论

**硕士毕业设计/论文方向：可以成立，建议进入导师审阅与 Simulink/PLECS 补验证阶段。**

**期刊投稿强度：目前相当于“Major Revision”。** 主要原因不是创新边界不清，而是验证层级仍以解析事件模型和本地脚本为主，缺少完整电力电子仿真平台或硬件样机的独立交叉验证。若目标是毕业论文，这一版已经形成了较完整的“理论推导-执行量矩阵-密集数据-工程预算”闭环；若目标是高水平期刊，还需要补充更真实的开关模型、外环补偿器、采样保持和 phase-overlap 稳定性分析。

## 方法学审查

### 主要优点

1. **验证数据密度明显改善**：新增 24 个 common-mode 频点、30 个幅值线性点、54 个执行量点和 140 个 DCR 失配设计点，已经回应“数据点太少”的核心问题。
2. **执行量分类证据强**：`Lambda_diff` 与 `Ton_diff` 的电流通道增益相差约五个数量级，这是比单一波形图更有力的证据。
3. **数字实现价值增强**：面积阈值位宽、检测时钟、Ton 分辨率被映射到 jitter/current 预算，能直接服务毕业设计中的数字控制器设计。
4. **边界比旧稿更诚实**：v2 已明确说明不是首次提出 IQCOT、不是首次提出 COT sampled-data、不是首次提出多相 DICOT 均流。

### 主要问题

1. **验证模型仍然同源**
   - 严重度：Major
   - 说明：IEK 推导、四相事件模型、执行量矩阵和数字预算都来自同一套解析事件仿真框架。它能证明内部一致性，但还不能证明在 Simscape/PLECS/硬件非理想条件下仍保持相同数量级。
   - 建议：后续至少补一个 Simulink/Simscape 或 PLECS 四相 IQCOT 模型，加入 MOSFET Ron、dead time、DCR、ESR、ADC/DPWM 采样保持，用同样的 `Lambda_diff` 和 `Ton_diff` 扫描复核执行量矩阵的数量级。

2. **DCR 失配网格是设计扫描，不是完整闭环验证**
   - 严重度：Major，但 v2 已在正文中标注。
   - 说明：140 点网格的电流结果来自 DC algebra，相位代价来自名义事件模型。它适合构建设计曲线，但不能替代每个失配点的动态闭环仿真。
   - 建议：保留网格作为“设计空间扫描”，再选 3 到 5 个代表点跑完整 mismatched dynamic validation，放在附录或正文小表中。

3. **phase-overlap 边界尚未解决**
   - 严重度：Major for journal, Minor for thesis
   - 说明：当前 duty 约 0.085，满足 `D<1/N`，没有进入多相 COT phase-overlap 区域。不能把结论外推到 `D>1/N`。
   - 建议：正文已经补充限制。若后续继续深化，可研究 `S_eff(z)=H_e+K(z)` 是否改变 critical ramp。

4. **参考文献还需要最终查新/核验**
   - 严重度：Major before submission
   - 说明：引用列表中部分条目还缺少完整卷期页或最终出版信息，例如 Sridhar/Li Part II。当前引用适合作为工作稿，但正式论文需要用 IEEE Xplore、Wiley、Crossref 或学校数据库逐条核对。
   - 建议：最终定稿前做 100% DOI 元数据核验，并补充已下载文献中的具体页码或关键公式来源。

## Domain/创新性审查

### 可辩护创新点

1. **四相数字 IQCOT 面积事件的 IEK 通道化表达**
   - 不是单纯改名，而是把 `F_x δx` 状态记忆项显式纳入面积事件线性化。

2. **执行量矩阵**
   - `Lambda_diff`、`Ton_diff`、`delay_diff` 分别映射到 current、phase-spacing、event jitter，给出了可复现的通道增益。

3. **受限均流设计**
   - 把均流问题从“尽量减小电流误差”变成 current-sharing benefit 与 phase-spacing cost 的约束权衡。

4. **数字 jitter 预算**
   - 将面积位宽、检测时钟和 Ton 分辨率连接到 IEK 灵敏度，是工程上有用的扩展。

### 仍需避免的过度表述

- 不要说“首次建立 IQCOT 小信号模型”。
- 不要说“证明所有多相 IQCOT 均适用”，当前只证明四相、固定工作点、非 phase-overlap。
- 不要说“数字预算已被硬件验证”，当前是小信号估算。
- 不要把最坏相对误差 `7969.65%` 单独作为宣传点，应始终说明它与响应谷值有关。

## Devil's Advocate 压力测试

### 最强反驳

一个严格审稿人可能会说：本文所谓 IEK 创新，仍然是在已有 sampled-data 和 IQCOT 面积事件理论上做重新组织；核心仿真又由作者自建解析模型生成，缺少外部仿真器或实物样机验证。因此，本文当前更像“建模假说 + 数值探索”，还不是充分验证的工程控制方法。尤其是 DCR 失配网格将 DC algebra 与名义事件 timing cost 组合，可能低估真实闭环中外环补偿、采样延迟和非理想开关造成的模态耦合。

### 对该反驳的回应

该反驳有效，但不推翻硕士课题价值。本文已经把创新边界限定在“四相数字 IQCOT 小信号执行量分类”，并且新增密集数据支持主要命题。下一步最关键的是做独立模型交叉验证，而不是继续堆同源脚本数据。

## 修改路线图

1. **短期可做**
   - 给 v2 增加一张“适用边界表”：四相、D<1/N、理想开关、解析事件模型、小信号偏置。
   - 把 `7969.65%` 旁边补绝对幅值，避免只看相对误差。
   - 为参考文献补完整 IEEE/Wiley 元数据。

2. **中期建议**
   - 搭建四相 Simulink/Simscape IQCOT 控制器。
   - 在 Simulink 中复现 `Lambda_diff` 与 `Ton_diff` 的执行量矩阵至少 3 个代表点。
   - 加入 DPWM/TDC/ADC 量化，验证 jitter 预算数量级。

3. **高阶创新**
   - 研究 phase-overlap 下的 `S_eff(z)=H_e+K(z)` 与 critical ramp。
   - 把 IEK 约束嵌入灰盒优化或 AI 调参策略。

## 审稿决定

- **作为硕士毕业设计主线：建议接收，需补仿真交叉验证。**
- **作为期刊论文：Major Revision。**

