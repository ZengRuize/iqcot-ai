# AI 调节 IQCOT 参数的研究生毕业设计文献调研

检索日期：2026-06-14  
主题：Inverse Charge Constant On-Time (IQCOT) 控制、COT/多相 Buck/VRM 小信号建模、数字 COT、AI/优化控制  
定位：面向“用 AI/智能优化调节 IQCOT 控制参数，以提升 VRM 动态性能、稳定性与效率”的开题与综述准备。

## 0. 结论先行

IQCOT 指的是 Inverse Charge Constant On-Time，不是泛泛的“改进 COT”。它把控制量从输出电压/电流纹波转向反向电荷或电感电流积分概念。核心优势是：在多相交错 Buck 的纹波抵消点仍能工作，不依赖极小输出纹波作为控制变量，并且在负载上升/下降瞬态中可自然改变有效 on-time，以减小欠冲/过冲。核心困难是：小信号模型更复杂，控制品质因数 Q 随 duty cycle 和工作点变化，模拟实现需要额外跨导放大器与积分电容，参数设计与优化空间较高维。

因此，你的题目可以收敛为：

面向多相 Buck VRM 的数字 IQCOT 控制参数自整定方法：利用小信号模型、仿真数据与 AI/智能优化算法，在宽输入、宽负载和器件参数扰动下联合优化瞬态、电压纹波、稳定裕度、开关频率偏移与效率。

更稳妥的研究路线不是让 AI 直接输出 MOSFET 开关动作，而是让 AI 调节 IQCOT 的中高层参数，例如 Ton 裕量、反向电荷积分增益/阈值、Q 值相关补偿、最小关断时间、blanking time、相位调度/重叠策略、电流均衡增益、AVP/输出阻抗目标等。这样更容易保证安全边界，也更适合 Simulink/Simscape 验证。

## 1. 推荐研究问题

主研究问题：

AI 辅助的数字 IQCOT 参数整定能否在宽工作范围内，相比固定参数 IQCOT、CMCOT/RBCOT、UFTCOT 或 DICOT，实现更小负载瞬态欠冲/过冲、更短恢复时间、更稳定的 Q/相位裕度，并保持可接受的效率与开关频率偏移？

子问题：

1. IQCOT 的小信号模型中哪些参数最影响 Q 值、环路带宽和瞬态恢复？
2. 传统 COT 在多相 VRM 中的主要瓶颈是纹波抵消、采样延迟/噪声、外部斜坡补偿折中，还是电流均衡？
3. AI 调节应采用离线全局优化、在线轻量自整定、强化学习，还是“物理模型 + 数据代理模型”的混合方法？
4. 数字 IQCOT 的实现约束是什么：ADC 采样延迟、计时分辨率、DPWM/延迟线、计算延迟、稳定性保护、硬件资源？

## 2. 检索策略

本轮为快速系统性检索，不是完整 PRISMA 系统综述。IEEE Xplore 页面在当前工具环境下受 robots 限制，因此优先使用 DOI、Semantic Scholar、ResearchGate、机构库、dblp、大学仓储、Wiley 摘要页和开放 PDF 进行交叉核验。

关键词组合：

- Inverse Charge Constant On-Time, IQCOT, High Frequency Small Signal Model IQCOT
- constant on-time current mode, COTCM, ripple-based constant on-time, RBCOT
- multiphase Buck, voltage regulator module, VRM, ripple cancellation
- digital constant on-time, DICOT, digital V2 COT, current balance
- genetic algorithm constant on-time buck, machine learning power electronics control
- reinforcement learning buck converter, deep machine learning DC/DC power converter

纳入标准：

- 与 COT/IQCOT/Buck/VRM 小信号建模、瞬态优化、数字实现或 AI 控制直接相关。
- 优先 IEEE TPEL/JESTPE/TIE/TCASII、ECCE/APEC、IET/Wiley、学位论文和机构库。
- AI 文献优先使用已在 DC-DC 或 power electronics control 中实证的工作。

排除标准：

- 只讨论通用 PID、且与 Buck/COT/VRM 无关的智能算法论文。
- 无法确认题名、作者、年份或 DOI 的来源。
- 明显二手搬运页面只作为线索，不作为核心证据。

## 3. IQCOT 小信号模型与机理文献

| 文献 | 质量 | 你要读什么 | 与课题的关系 |
|---|---:|---|---|
| Bari, S. M. K. (2018). A Novel Inverse Charge Constant On-Time Control for High Performance Voltage Regulators. Virginia Tech dissertation. [VT 仓储](https://vtechworks.lib.vt.edu/items/cae05986-a69e-4642-875a-71b230bee9cc) | A | IQCOT 原始博士论文，包含控制概念、VRM 背景、与传统 COT 的比较 | 你的理论源头，应作为第一篇精读 |
| Bari, Li, & Lee (2018). High Frequency Small Signal Model for Inverse Charge Constant On-Time (IQCOT) Control. ECCE 2018, pp. 6000-6007. DOI: [10.1109/ECCE.2018.8557464](https://doi.org/10.1109/ECCE.2018.8557464) | A | 使用 describing function 推导 IQCOT 高频小信号模型；指出 Q 随 duty cycle 变化 | 你做 AI 调参时最核心的模型依据 |
| Bari, Li, & Lee (2021). Inverse Charge Constant On-Time Control With Ultrafast Transient Performance. IEEE JESTPE, 9(1), 68-78. DOI: [10.1109/JESTPE.2020.2973151](https://doi.org/10.1109/JESTPE.2020.2973151) | A | IQCOT 通过自然改变有效 on-time 改善负载上升/下降瞬态；不依赖 ripple 信息 | 解释“为什么值得研究 IQCOT” |
| Liu, Cheng, Mi, & Mercier (2021). A Novel Ultrafast Transient Constant On-Time Buck Converter for Multiphase Operation. IEEE TPEL, 36(11), 13096-13106. DOI: [10.1109/TPEL.2021.3076430](https://doi.org/10.1109/TPEL.2021.3076430) | A | 面向多相场景的 UFTCOT，与 IQCOT、CMCOT、RBCOT 对比；同样基于 DF 小信号建模 | 可作为 IQCOT 竞争方案/对照组 |

关键共识：

1. IQCOT 的提出是为了解决 CMCOT/RBCOT 在多相 VRM 中的两个痛点：固定 Ton 限制负载瞬态电感电流上升/下降速度，以及多相交错时纹波抵消点的噪声/稳定性问题。
2. IQCOT 通过跨导放大器和电容对感测电感电流积分，实现不依赖输出纹波的 COT 控制。
3. IQCOT 小信号模型显示高带宽设计不只是“把增益调大”，还要处理 duty cycle 改变导致的双极点 Q 变化。这正是 AI/优化算法可以切入的地方。

## 4. COT 控制现状与痛点文献

| 方向 | 文献 | 质量 | 关键信息 |
|---|---|---:|---|
| V2/COT 小信号分析 | Tian, S. (2012). Small-signal Analysis and Design of Constant-on-time V2 Control for Low-ESR Capacitors. Virginia Tech. [VT 页面](https://vtechworks.lib.vt.edu/items/5ad60ce4-aaad-4d5f-8b6f-45eea6b169e4) | A- | COT V2 在低 ESR 陶瓷电容下会有亚谐波/稳定性问题；数字 COT 有采样效应 |
| COTCM 外部斜坡模型 | Tian, Lee, Li, Li, & Liu (2014). Equivalent circuit model of constant on-time current mode control with external ramp compensation. ECCE 2014. DOI: [10.1109/ECCE.2014.6953910](https://doi.org/10.1109/ECCE.2014.6953910) | A- | 外部斜坡可解决多相 ripple cancellation，但会引入额外动态和 AVP 误差 |
| RBCOT 虚拟电感电流 | Lin, Chen, Chen, & Wang (2012). A Ripple-Based Constant On-Time Control With Virtual Inductor Current and Offset Cancellation for DC Power Converters. IEEE TPEL, 27(10), 4301-4310. DOI: [10.1109/TPEL.2012.2191799](https://doi.org/10.1109/TPEL.2012.2191799) | A | RBCOT 的输出偏移和亚谐波问题可用虚拟电感电流与 offset cancellation 缓解 |
| Adaptive-ramp RBCOT | Kong et al. (2018). A Novel Adaptive-Ramp Ripple-Based Constant On-Time Buck Converter for Stability and Transient Optimization in Wide Operation Range. IEEE JESTPE, 6(3), 1314-1324. DOI: [10.1109/JESTPE.2018.2812791](https://doi.org/10.1109/JESTPE.2018.2812791) | A | 用 adaptive ramp 使 Q 在不同工作点近似不变；是 AI 调 Q 的直接先例 |
| 宽范围准确 AOT | Liu, Chen, Cheng, & Chen (2020). A Novel Accurate Adaptive Constant On-Time Buck Converter for a Wide-Range Operation. IEEE TPEL, 35(4), 3729-3739. DOI: [10.1109/TPEL.2019.2936524](https://doi.org/10.1109/TPEL.2019.2936524) | A | 宽输入/宽负载下保持输出准确、Q 值与瞬态表现，是传统自适应 COT 代表 |
| COTCM 高频模型 + GA | Cheng, Liu, Shao, & Liu (2022). High-Frequency Modelling of Constant On-Time Current Mode Buck Converter and Controller Design by Combining Genetic Algorithm. IEEE TPEL, 37(12), 15099-15110. DOI: [10.1109/TPEL.2022.3197768](https://doi.org/10.1109/TPEL.2022.3197768) | A | 将高频模型与遗传算法结合做控制器优化；非常支持“AI/智能优化调 COT 参数”的可行性 |
| PRCOT 指数斜率 DF 模型 | Huang & Chen (2024). A Novel Describing Function Small-Signal Modeling Approach for Passive Ripple Constant On-Time Controlled Converter With Exponentially Varying Slope. IEEE TPEL, 39(7), 8425-8435. DOI: [10.1109/TPEL.2024.3383855](https://doi.org/10.1109/TPEL.2024.3383855) | A- | 说明 PRCOT 建模仍在快速发展，DF 方法仍是主流 |
| Sampled-data COT/COFT | Yan, Ruan, & Li (2022). A general approach to sampled-data modeling for ripple-based control-Part II: Constant on-time and constant off-time control. IEEE TPEL, 37(6), 6385-6396. DOI: [10.1109/TPEL.2021.3132624](https://doi.org/10.1109/TPEL.2021.3132624) | A- | 采样数据模型可分析 COT/COFT，适合数字实现研究 |

痛点归纳：

1. Ripple-based COT 在多相交错中会遇到纹波抵消点，控制变量变小，噪声敏感性显著上升。
2. 固定 Ton 在大负载阶跃时限制电感电流爬升；负载下降时若刚进入 on-time，电流下降被延迟，容易产生过冲。
3. 外部斜坡、虚拟电感电流、offset cancellation、adaptive ramp 都能缓解问题，但参数依赖工作点，且稳定性、瞬态、纹波、频率存在折中。
4. 高带宽 COT 模型需要考虑输出纹波、采样/频谱耦合和 ADC/PWM 时序效应；简单平均模型不足。

## 5. 为什么 IQCOT 比 ripple-based COT 更适合数字控制/AI 调参

这个判断要加限定：更准确地说，IQCOT 比传统 RBCOT/CMCOT 更适合做“数字参数调节与 AI 自整定”；不等于所有实现上都比所有 COT 更简单。

### 5.1 控制量更适合数字累计

IQCOT 的核心是电感电流相关量的积分/电荷概念。数字控制天然擅长做离散累加、窗口积分、阈值比较和事件调度。相比直接依赖模拟输出纹波，数字 IQCOT 可以把控制变量变成 q_hat 的离散累加与阈值触发。这与 DICOT 文献中的 signal accumulation 思想一致。Li et al. (2024) 明确提出数字积分 COT 用信号累积减轻 ripple-based digital COT 的 A/D 采样延迟和采样噪声影响，并且适合多相交错。

### 5.2 不依赖极小输出纹波

数字 ripple-based COT 的问题是：ADC 采样延迟、量化噪声、输出电容低 ESR、多相纹波抵消都会让控制纹波不可靠。IQCOT 的非 ripple-based 特性让它更适合高电流多相 VRM，尤其是陶瓷电容、低纹波、高相数场景。

### 5.3 参数空间可显式编码

IQCOT 可调参数可以数字化为寄存器、查表或在线更新项：

- Ton nominal、Ton margin、Toff minimum、blanking time
- inverse-charge 积分增益、积分泄放、阈值
- Q 值补偿表或神经网络/代理模型
- 相位调度、允许 pulse overlap 的边界
- 电流均衡增益、AVP/输出阻抗目标
- 频率锁定或 pseudo-constant-frequency 修正

这些参数比“直接让 AI 输出开关”更安全，也更容易设置稳定性保护。

### 5.4 AI 可补足模型复杂度

Bari et al. (2018) 指出 IQCOT 的 Q 会随 duty cycle 变化；Cheng et al. (2022) 已经证明 COTCM 高频模型可以结合遗传算法优化控制器。由此可推导：对 IQCOT 做“模型引导 + 数据驱动”的参数优化是合理延伸。

## 6. 数字 COT/多相电流均衡文献

| 文献 | 质量 | 对你的启发 |
|---|---:|---|
| Li, Xu, Liu, & Sun (2024). Multiphase digital integration constant on-time-controlled Buck converter with high-resolution current balance scheme for ultrafast load transient. International Journal of Circuit Theory and Applications, 52(7), 3188-3212. DOI: [10.1002/cta.3924](https://doi.org/10.1002/cta.3924) | A- | DICOT 用数字积分解决采样延迟/噪声，并提出高分辨率电流均衡。是数字 IQCOT 的最接近参考 |
| Chen, Zeng, Cheng, & Lin (2020). Comprehensive Analysis and Design of Current-Balance Loop in Constant On-Time Controlled Multi-Phase Buck Converter. IEEE Access, 8, 184752-184764 | A- | 多相 COT 电流均衡环的建模与设计指南；AI 调参不能忽略均流环 |
| Hu, Tsai, & Tsai (2021). Digital V2 Constant ON-Time Control Buck Converter With Adaptive Voltage Positioning and Automatic Calibration Mechanism. IEEE TPEL, 36(6), 7178-7188 | A- | 数字 COT + AVP + 自动校准，说明在线校准机制已是数字 VRM 研究方向 |
| Hu, Yeh, Tsai, & Tsai (2021). Fully Digital Current Mode Constant On-Time Controlled Buck Converter With Output Voltage Offset Cancellation. IEEE Access / related source | B+ | 完全数字 COT 的 offset cancellation，说明数字实现会引入新的偏移/分辨率问题 |

## 7. AI/智能优化控制文献

| 文献 | 质量 | 关键信息 | 与 IQCOT 参数优化的关系 |
|---|---:|---|---|
| Zhao, Blaabjerg, & Wang (2021). An overview of artificial intelligence applications for power electronics. IEEE TPEL, 36(4), 4633-4658. DOI: [10.1109/TPEL.2020.3024914](https://doi.org/10.1109/TPEL.2020.3024914) | A | 综述 AI 在 power electronics 的 design/control/maintenance 三阶段应用，覆盖 expert system、fuzzy、metaheuristic、ML | 作为“AI 必要性与可行性”的总综述 |
| Hajihosseini et al. (2020). DC/DC Power Converter Control-Based Deep Machine Learning Techniques: Real-Time Implementation. IEEE TPEL, 35(10), 9971-9977. DOI: [10.1109/TPEL.2020.2977765](https://doi.org/10.1109/TPEL.2020.2977765) | A | 深度机器学习用于 DC/DC 控制且有实时实现 | 支持“AI 控制不是只停留在仿真” |
| Gao et al. (2023). Inverse Application of Artificial Intelligence for the Control of Power Converters. IEEE TPEL, 38(2), 1535-1548. DOI: [10.1109/TPEL.2022.3209093](https://doi.org/10.1109/TPEL.2022.3209093) | A | AI 反向给出期望控制系数/参考量 | 很适合借鉴为“AI 输出 IQCOT 参数，而不是开关动作” |
| Cheng et al. (2022). COTCM 高频模型 + 遗传算法。DOI: [10.1109/TPEL.2022.3197768](https://doi.org/10.1109/TPEL.2022.3197768) | A | GA 优化 COTCM 控制器设计 | 你的课题可以升级为 IQCOT 的多目标 AI/GA/BO/RL 调参 |
| Cui et al. (2022). Voltage Regulation of DC-DC Buck Converters Feeding CPLs via Deep Reinforcement Learning. IEEE TCAS II, 69, 1777-1781. DOI: [10.1109/TCSII.2021.3107535](https://doi.org/10.1109/TCSII.2021.3107535) | A- | DRL 用于 Buck + constant power load 电压调节 | 支持强化学习处理非线性负载扰动 |
| Cui et al. (2023). Implementation of Transferring Reinforcement Learning for DC-DC Buck Converter Control via Duty Ratio Mapping. IEEE TIE, 70(6), 6141-6150. DOI: [10.1109/TIE.2022.3192676](https://doi.org/10.1109/TIE.2022.3192676) | A | 关注 RL 从仿真到实物迁移问题 | 说明 sim-to-real 是必须讨论的风险 |
| Lee et al. (2024). Reinforcement Learning-Based Control of DC-DC Buck Converter Considering Controller Time Delay. IEEE Access, 12, 118442-118452. DOI: [10.1109/ACCESS.2024.3448535](https://doi.org/10.1109/ACCESS.2024.3448535) | A- | 针对 DSP 控制延迟的实时深度强化学习 | 数字 IQCOT 也必须考虑计算/采样延迟 |
| Bahrami & Khashroum (2023). Review of Machine Learning Techniques for Power Electronics Control and Optimization. CRPASE, 9(3), 1-8. DOI: [10.61186/crpase.9.3.2860](https://doi.org/10.61186/crpase.9.3.2860) | B | 机器学习用于 power electronics control/optimization 的一般综述 | 可作为辅助综述，不宜作为最强证据 |
| Demir & Demirok (2023). Designs of PSO-Based Intelligent PID Controllers and DC/DC Buck Converters. Applied Sciences, 13(5), 2919. DOI: [10.3390/app13052919](https://doi.org/10.3390/app13052919) | B | PSO 调 PID 与 Buck 设计 | 说明群智能可做参数整定，但与 COT/IQCOT 距离较远 |

## 8. AI 控制的必要性分析

### 8.1 传统解析设计难以覆盖宽工作域

IQCOT/COT 的稳定性与瞬态性能同时受 Vin、Vout、负载、电感电流斜率、相数、输出电容 ESR、DCR、MOSFET Ron、采样延迟、计时分辨率等影响。单点设计很容易在另一个 duty cycle 或负载点出现 Q 值过高、带宽下降、频率漂移或电流不均。

### 8.2 参数目标是多目标冲突

要同时优化负载上升 undershoot、负载下降 overshoot、settling time、输出纹波/稳态误差、相位裕度/增益裕度/Q 值、频率偏移/EMI 风险、峰值电流/电流均衡、效率/轻载跳脉冲。这些目标存在天然冲突，适合用多目标优化、贝叶斯优化、遗传算法、强化学习或代理模型。

### 8.3 数字实现提供在线可调入口

模拟 IQCOT 的 gm、积分电容、阈值通常固定或难以在线调。数字 IQCOT 可以把它们映射为可编程系数，因此 AI 才有可执行的调参对象。

### 8.4 AI 不必替代控制理论

更推荐的框架是：物理模型/DF 小信号模型提供约束与稳定性边界；Simulink、PLECS 或 SIMPLIS 数据训练代理模型或奖励函数；AI/优化器输出参数表或补偿律；数字 IQCOT 控制器实时执行；保护逻辑负责限幅、最小关断、峰值电流和频率边界。

## 9. 可行性分析与推荐技术路线

### 方案 A：离线 AI 多目标参数优化，最适合毕业设计落地

可优化参数：

- Ton margin
- inverse-charge 积分增益 Kiq
- 触发阈值 Qth
- blanking time / minimum off-time
- phase overlap limit
- current balance gain Kcb
- AVP load-line / 输出阻抗校准增益

目标函数可由 undershoot、overshoot、settling time、ripple、frequency deviation、current imbalance、estimated efficiency 与 stability/current-limit penalty 加权组成。

算法路线：

1. Latin hypercube / Sobol 采样建立数据集。
2. GA、PSO 或 Bayesian Optimization 找 Pareto 前沿。
3. 用小信号模型约束 Q、相位裕度、带宽。
4. 生成查表控制律：参数 = f(Vin, Vout, Iload, Nphase, temperature)。

优点：风险低、可解释、容易写论文和做 Simulink 验证。

### 方案 B：模型辅助强化学习，创新性更高但风险更大

状态可包含 Vout error、dVout/dt、各相电感电流、负载估计、Vin、active phase count、q_hat、fsw estimate。动作不建议直接为 gate signal，而是 delta Kiq、delta Qth、delta Ton margin、delta Kcb。奖励函数惩罚 overshoot、undershoot、settling、ripple、current imbalance、frequency error 和 loss。必须设置 action clipping、hard limits、forbidden instability region 和固定参数 IQCOT fallback。

适合毕业论文的折中：不要让 RL 直接控制 duty 或 gate，而是让 RL/BO 调 IQCOT 参数。

### 方案 C：小信号模型 + 神经网络代理模型

用 DF 模型和仿真数据训练 surrogate：输入为 Vin、Vout、Iload、L、C、ESR、DCR、N、Kiq、Qth、Ton 等，输出为 Q、PM、undershoot、overshoot、efficiency 等，然后用优化器快速搜索。这个方案能把“理论 + AI”结合得比较好。

## 10. 文献矩阵

| 主题 | 支撑文献 | 证据强度 | 对你的论文可写成 |
|---|---|---:|---|
| IQCOT 原理 | Bari dissertation; Bari et al. 2021 | 强 | “IQCOT 通过反向电荷机制改善固定 Ton 瞬态限制” |
| IQCOT 小信号模型 | Bari et al. 2018 | 强 | “Q 随 duty cycle 变化导致宽域高带宽设计困难” |
| 多相 COT 纹波抵消 | Bari 2018/2021; Liu et al. 2021 | 强 | “传统 ripple-based COT 在多相 VRM 中噪声敏感” |
| RBCOT 稳定/offset | Lin et al. 2012; Kong et al. 2018; Liu et al. 2020 | 强 | “传统补偿方案可行但参数折中明显” |
| COT 高频建模 | Tian 2012; Cheng et al. 2022; Huang & Chen 2024; Yan et al. 2022 | 强 | “平均模型不足，需要高频/采样模型支持优化” |
| 数字 COT 可行性 | Li et al. 2024; Hu et al. 2021; Chen et al. 2020 | 中强 | “数字积分/电流均衡/自动校准已成为趋势” |
| AI 在电力电子 | Zhao et al. 2021; Hajihosseini et al. 2020; Gao et al. 2023 | 强 | “AI 可用于设计、控制和维护，已有实时控制案例” |
| RL/迁移/延迟 | Cui et al. 2022/2023; Lee et al. 2024 | 中强 | “AI 控制必须考虑 sim-to-real 和数字延迟” |
| 智能优化 COT 参数 | Cheng et al. 2022 | 强 | “GA 优化 COTCM 是 IQCOT-AI 调参的直接先例” |

## 11. 开题报告可用论证链

研究背景：AI/ML 加速器、CPU/GPU/XPU 对 VRM 的要求是低电压、大电流、高 di/dt、低纹波、高效率。多相同步 Buck 是主流拓扑，COT 类控制因轻载效率高、瞬态快、补偿简单而被广泛采用。

现有问题：传统 CMCOT/RBCOT 依赖电感/输出纹波，面对多相交错纹波抵消、低 ESR 电容和高采样噪声时稳定性变差；固定 Ton 又限制大负载阶跃下的电感电流响应。外部斜坡、虚拟电感电流、adaptive ramp、UFTCOT、DICOT 等方案均有改善，但参数与工作点强相关，设计复杂。

IQCOT 优势：IQCOT 不依赖 ripple 控制变量，而是通过 inverse-charge 机制实现 COT 控制，在多相 ripple cancellation point 有更好的鲁棒性；负载瞬态时有效 on-time 可自然增减，从而改善欠冲和过冲。

尚未解决的问题：IQCOT 的高频小信号模型表明 Q 值随 duty cycle 变化，宽工作范围内高带宽设计困难；模拟实现也存在额外积分电路、参数漂移和调参复杂度。现有文献主要给出解析模型和固定参数设计，缺少面向数字 IQCOT 的 AI 自整定研究。

研究必要性：AI/智能优化可处理多目标、高维、非线性、工作点变化与器件不确定性问题。已有 COTCM + GA、DC/DC 深度机器学习实时实现、DRL Buck 控制、AI 反向输出控制系数等文献证明可行。将 AI 作用于 IQCOT 参数层，而不是直接替代底层保护控制，是兼顾创新性与工程安全性的路线。

## 12. 建议精读顺序

1. Bari 2018 dissertation：建立 IQCOT 全局概念。
2. Bari et al. 2021 JESTPE：写 IQCOT 优势和问题。
3. Bari et al. 2018 ECCE：写小信号模型与 Q 值问题。
4. Liu et al. 2021 TPEL：写多相 COT 竞争方案与 ripple cancellation 背景。
5. Lin 2012 / Kong 2018 / Liu 2020：写传统 RBCOT 改进现状。
6. Cheng et al. 2022：写“智能优化 COT 控制器”的直接依据。
7. Li et al. 2024 DICOT：写“为什么适合数字控制”。
8. Zhao et al. 2021 + Hajihosseini 2020 + Gao 2023：写 AI 可行性。
9. Cui 2022/2023 + Lee 2024：写 RL、迁移和延迟问题。

## 13. 需要警惕的反方意见

1. “IQCOT 自称无需外部调节，为什么还要 AI？”  
   回应：IQCOT 的瞬态机制有自适应性，但高频小信号 Q、数字延迟、电流均衡、宽输入/宽负载和器件漂移仍需要参数优化。AI 调的是宽域性能，而不是否认 IQCOT 的机制。

2. “AI 控制电源不安全、不稳定。”  
   回应：采用参数层 AI，而非直接 gate-level AI；用 DF/采样模型给出稳定边界；设置硬保护和 fallback。

3. “已有 adaptive ramp/AOT/DICOT 解决了问题。”  
   回应：它们主要是固定结构或规则型自适应，缺少针对 IQCOT 的多目标、宽域、数字参数自整定。

4. “Simulink 结果不能代表芯片实测。”  
   回应：毕业设计可先以可复现实验平台为目标，后续扩展到 HIL/FPGA/低压 Buck 原型；文献中 sim-to-real 和控制延迟必须作为限制讨论。

## 14. 推荐论文题目

1. 基于智能优化的多相 Buck VRM 数字 IQCOT 控制参数自整定研究
2. 面向宽负载瞬态的 IQCOT 控制小信号建模与 AI 参数优化
3. 融合小信号模型与数据驱动优化的数字 IQCOT 多相 Buck 控制方法

## 15. 下一步实验规划

1. 建立基准模型：两相或四相同步 Buck VRM，固定 Vin、Vout、Iload 阶跃、fsw、L/C/ESR/DCR/Ron。
2. 实现对照控制：固定参数 CMCOT/RBCOT、固定参数 IQCOT。
3. 提取指标：undershoot、overshoot、settling time、ripple、phase current imbalance、effective switching frequency、peak current、估算效率。
4. 扫描参数：Ton margin、Kiq、Qth、Tblank、Kcb。
5. 训练/优化：先用 GA/PSO/BO 做离线优化，得到 Pareto 前沿。
6. 数字化：把优化结果变成查表或轻量模型。
7. 验证鲁棒性：输入电压、负载、L/C/ESR/DCR/MOSFET Ron 偏差、采样延迟、量化噪声。

## 16. 参考文献清单

1. Bari, S. M. K. (2018). A Novel Inverse Charge Constant On-Time Control for High Performance Voltage Regulators. Virginia Tech. <https://vtechworks.lib.vt.edu/items/cae05986-a69e-4642-875a-71b230bee9cc>
2. Bari, S., Li, Q., & Lee, F. C. (2018). High Frequency Small Signal Model for Inverse Charge Constant On-Time (IQCOT) Control. IEEE ECCE, 6000-6007. <https://doi.org/10.1109/ECCE.2018.8557464>
3. Bari, S., Li, Q., & Lee, F. C. (2021). Inverse Charge Constant On-Time Control With Ultrafast Transient Performance. IEEE Journal of Emerging and Selected Topics in Power Electronics, 9(1), 68-78. <https://doi.org/10.1109/JESTPE.2020.2973151>
4. Liu, W.-C., Cheng, C.-H., Mi, C. C., & Mercier, P. P. (2021). A Novel Ultrafast Transient Constant On-Time Buck Converter for Multiphase Operation. IEEE Transactions on Power Electronics, 36(11), 13096-13106. <https://doi.org/10.1109/TPEL.2021.3076430>
5. Li, L., Xu, S., Liu, Y., & Sun, W. (2024). Multiphase digital integration constant on-time-controlled Buck converter with high-resolution current balance scheme for ultrafast load transient. International Journal of Circuit Theory and Applications, 52(7), 3188-3212. <https://doi.org/10.1002/cta.3924>
6. Tian, S. (2012). Small-signal Analysis and Design of Constant-on-time V2 Control for Low-ESR Capacitors. Virginia Tech. <https://vtechworks.lib.vt.edu/items/5ad60ce4-aaad-4d5f-8b6f-45eea6b169e4>
7. Tian, S., Lee, F. C., Li, J., Li, Q., & Liu, P.-H. (2014). Equivalent circuit model of constant on-time current mode control with external ramp compensation. IEEE ECCE. <https://doi.org/10.1109/ECCE.2014.6953910>
8. Lin, Y.-C., Chen, C.-J., Chen, D., & Wang, B. (2012). A Ripple-Based Constant On-Time Control With Virtual Inductor Current and Offset Cancellation for DC Power Converters. IEEE Transactions on Power Electronics, 27(10), 4301-4310. <https://doi.org/10.1109/TPEL.2012.2191799>
9. Kong, L., Chen, D. Y., Hsiao, S.-F., Nien, C.-F., Chen, C.-J., & Li, K.-F. (2018). A Novel Adaptive-Ramp Ripple-Based Constant On-Time Buck Converter for Stability and Transient Optimization in Wide Operation Range. IEEE JESTPE, 6(3), 1314-1324. <https://doi.org/10.1109/JESTPE.2018.2812791>
10. Liu, W.-C., Chen, C.-J., Cheng, C.-H., & Chen, H.-J. (2020). A Novel Accurate Adaptive Constant On-Time Buck Converter for a Wide-Range Operation. IEEE Transactions on Power Electronics, 35(4), 3729-3739. <https://doi.org/10.1109/TPEL.2019.2936524>
11. Cheng, X., Liu, J., Shao, Y., & Liu, Z. (2022). High-Frequency Modelling of Constant On-Time Current Mode Buck Converter and Controller Design by Combining Genetic Algorithm. IEEE Transactions on Power Electronics, 37(12), 15099-15110. <https://doi.org/10.1109/TPEL.2022.3197768>
12. Huang, Y.-R., & Chen, C.-J. (2024). A Novel Describing Function Small-Signal Modeling Approach for Passive Ripple Constant On-Time Controlled Converter With Exponentially Varying Slope. IEEE Transactions on Power Electronics, 39(7), 8425-8435. <https://doi.org/10.1109/TPEL.2024.3383855>
13. Yan, N., Ruan, X., & Li, X. (2022). A general approach to sampled-data modeling for ripple-based control-Part II: Constant on-time and constant off-time control. IEEE Transactions on Power Electronics, 37(6), 6385-6396. <https://doi.org/10.1109/TPEL.2021.3132624>
14. Zhao, S., Blaabjerg, F., & Wang, H. (2021). An overview of artificial intelligence applications for power electronics. IEEE Transactions on Power Electronics, 36(4), 4633-4658. <https://doi.org/10.1109/TPEL.2020.3024914>
15. Hajihosseini, M., Andalibi, M., Gheisarnejad, M., Farsizadeh, H., & Khooban, M. H. (2020). DC/DC Power Converter Control-Based Deep Machine Learning Techniques: Real-Time Implementation. IEEE Transactions on Power Electronics, 35(10), 9971-9977. <https://doi.org/10.1109/TPEL.2020.2977765>
16. Gao, Y., Wang, S., Hussaini, H., Yang, T., et al. (2023). Inverse Application of Artificial Intelligence for the Control of Power Converters. IEEE Transactions on Power Electronics, 38(2), 1535-1548. <https://doi.org/10.1109/TPEL.2022.3209093>
17. Cui, C., Yan, N., Huangfu, B., Yang, T., & Zhang, C. (2022). Voltage Regulation of DC-DC Buck Converters Feeding CPLs via Deep Reinforcement Learning. IEEE Transactions on Circuits and Systems II: Express Briefs, 69, 1777-1781. <https://doi.org/10.1109/TCSII.2021.3107535>
18. Cui, C., Yang, T., Dai, Y., Zhang, C., & Xu, Q. (2023). Implementation of Transferring Reinforcement Learning for DC-DC Buck Converter Control via Duty Ratio Mapping. IEEE Transactions on Industrial Electronics, 70(6), 6141-6150. <https://doi.org/10.1109/TIE.2022.3192676>
19. Lee, D., Kim, B., Kwon, S., Nguyen, N. D., Kyu Sim, M., & Lee, Y. I. (2024). Reinforcement Learning-Based Control of DC-DC Buck Converter Considering Controller Time Delay. IEEE Access, 12, 118442-118452. <https://doi.org/10.1109/ACCESS.2024.3448535>
20. Bahrami, M., & Khashroum, Z. (2023). Review of Machine Learning Techniques for Power Electronics Control and Optimization. CRPASE, 9(3), 1-8. <https://doi.org/10.61186/crpase.9.3.2860>
21. Demir, M. H., & Demirok, M. (2023). Designs of Particle-Swarm-Optimization-Based Intelligent PID Controllers and DC/DC Buck Converters for PEM Fuel-Cell-Powered Four-Wheeled Automated Guided Vehicle. Applied Sciences, 13(5), 2919. <https://doi.org/10.3390/app13052919>

## 17. 仍需人工数据库补齐的资料

1. IEEE Xplore 原文下载后，应补齐页码、图表编号和实验参数，尤其是 IQCOT、UFTCOT、phase-overlap COT 和数字 COT 的实验平台参数。
2. 当前浏览器访问国内站 kns.cnki.net 出现证书域名错误和 HTTP 418；CNKI 国际版 oversea.cnki.net 的直达结果页可检索并解析。若需下载原文、查看全文或导出引用，仍需用户登录或机构权限。
3. 若毕业设计落在 Simulink/Simscape，应下一步建立文献参数表：Vin、Vout、Iout、相数、L、C、ESR、fsw、Ton、transient step、slew rate。
4. 对 AI 方案，第二轮已补充 safe reinforcement learning、Bayesian optimization、physics-informed surrogate model 文献；后续可按导师偏好继续扩展到 FPGA/HIL 或硬件实验论文。

## 18. 第二轮完整补充调研

本节是在第一轮文献地图基础上的扩展版，目标是把“可写综述”和“可做毕业设计”之间的桥补完整。第二轮重点扩展了六个面：

1. IQCOT 与 inverse-charge/current-mode COT 的原始谱系。
2. COT/RBCOT/V2/COTCM 的小信号、采样数据和多相 phase-overlap 建模。
3. 数字 COT、数字积分 COT、电流均衡和自动校准。
4. XPU/AI 服务器供电、48 V 到低压大电流 VRM 的应用背景。
5. AI/机器学习/强化学习/安全学习/物理约束学习在电力电子中的可用证据。
6. 可落地的 Simulink/Simscape 课题设计、对照组与指标体系。

### 18.1 第二轮检索审计

检索日期：2026-06-14。  
检索来源：Crossref DOI API、Google/Bing 网页检索、Wiley、Virginia Tech VTechWorks、IEEE DOI 页面、中文期刊公开页面、MPS/SGMICRO/ADI/TI 等厂商技术资料、Google Patents。  
CNKI 状态：当前浏览器访问 CNKI kns8s/search 出现证书域名错误，未能完成站内结构化检索。因此中文学位论文和中文核心期刊仍需后续通过校园网或人工 CNKI/万方检索补齐。

第二轮新增关键词：

- IQCOT / inverse charge / new current mode control / high noise immunity / multiphase
- duty-cycle-independent quality factor / phase overlapping / sampled-data modeling
- digital hybrid ripple-based COT / digital integration constant on-time / DICOT
- current balance loop / adaptive voltage positioning / automatic calibration
- XPU power supply / 48 V xPU voltage regulator / AI server VRM
- safety-enhanced self-learning / stability-guided reinforcement learning / physics-informed machine learning
- Bayesian optimization power electronics / surrogate modeling power converter

来源质量分级：

- A：IEEE TPEL/JESTPE/TIE/TCASII、IEEE Access、ECCE/APEC、Wiley/IET、博士论文、可 DOI 核验。
- B：中文公开期刊、硕士论文公开摘要、行业白皮书或厂商技术文档。
- C：专利、应用笔记、网页文章，只用于说明工程趋势，不作为理论核心证据。

### 18.2 IQCOT 与 inverse-charge 控制谱系

IQCOT 的源头不是孤立的 2021 JESTPE 论文，而是从“高噪声免疫、多相快速瞬态 current-mode COT”逐步演化来的。

| 时间 | 文献 | 贡献 | 对本课题意义 |
|---|---|---|---|
| 2015 | Bari, Li, & Lee. A new current mode control for higher noise immunity and faster transient response in multi-phase operation. ECCE. DOI: 10.1109/ECCE.2015.7309953 | 提出一种新的 current-mode 控制思想，面向多相工作和高噪声免疫 | 可视为 IQCOT 前身，说明问题不是单相 COT，而是多相 VRM 的噪声与瞬态 |
| 2018 | Bari 博士论文 | 系统提出 inverse charge COT，并给出高性能 VRM 设计逻辑 | 理论主线和术语来源 |
| 2018 | Bari et al. High Frequency Small Signal Model for IQCOT. ECCE. DOI: 10.1109/ECCE.2018.8557464 | 高频小信号模型，说明 Q 值、占空比与工作点相关 | AI 参数优化的模型基础 |
| 2021 | Bari et al. IQCOT With Ultrafast Transient Performance. JESTPE. DOI: 10.1109/JESTPE.2020.2973151 | 完整展示 IQCOT 快速瞬态与不依赖 ripple 的优势 | 你的课题“为什么选 IQCOT”的主证据 |

可以在论文中把 IQCOT 定位为：

IQCOT 是一种面向高性能 VRM 的非 ripple-based COT 控制。它保留 COT 的事件触发和快速瞬态特性，同时通过 inverse-charge/current integration 思路避免传统 COT 对输出纹波的依赖，尤其适合多相交错造成纹波抵消的场景。

### 18.3 COT 控制类型与优缺点总表

| 控制类别 | 主要控制量 | 优点 | 典型问题 | 代表文献 |
|---|---|---|---|---|
| Basic COT / AOT | 输出电压触发 + 估算 Ton | 结构简单、瞬态快、轻载效率好 | 频率漂移、纹波依赖、低 ESR 稳定性问题 | MPS 技术文档；Liu 2020 AOT |
| V2 COT | 输出电压纹波/电容电流信息 | 快速瞬态，适合 VRM | 陶瓷电容低 ESR 下可能缺乏足够纹波，需补偿 | Tian 2012；Tian 2011 ECCE |
| RBCOT | 输出纹波或注入纹波 | 简单高带宽 | 输出偏移、噪声、纹波抵消、亚谐波 | Lin 2012；Kong 2018 |
| COTCM | 电感/开关电流 + COT | 多相均流更自然，AVP 方便 | 电流采样延迟、噪声、外部 ramp 折中 | Tian 2014；Cheng 2022 |
| Digital hybrid ripple-based COT | 数字采样 + 混合 ripple | 可编程、适合 VRM | ADC 延迟、量化、采样噪声 | Digital hybrid RBCOT 2014 |
| DICOT | 数字积分/累积信号 | 抗采样延迟和噪声，适合多相 | 仍需解决均流、分辨率、参数调节 | Li et al. 2024 |
| UFTCOT / phase-overlap COT | 多相脉冲重叠/调度 | 瞬态极快，释放多相电流斜率潜力 | 小信号模型和稳定性更复杂 | Liu 2021；Sridhar/Li 2024 |
| IQCOT | inverse charge / 电感电流积分 | 不依赖 ripple，适合多相 ripple cancellation，瞬态快 | Q 随工作点变化，参数空间复杂 | Bari 2018/2021 |

结论：传统 COT 的痛点可以概括为“纹波依赖、工作点依赖、采样延迟、参数折中”。IQCOT 解决了纹波依赖和瞬态 Ton 限制的一部分问题，但没有自动解决所有工作点下的 Q 值、均流、数字延迟和多目标优化。因此 AI 调参有合理空间。

### 18.4 小信号模型：从平均模型到 DF/采样模型

对毕业设计而言，需要明确一点：如果只用传统平均模型，COT 类控制的重要特性会被抹掉。COT 的触发点、纹波斜率、Ton/Toff 限制、外部斜坡、采样延迟都会进入高频动态。

推荐采用三层模型：

1. 低频平均模型：用于解释 Buck 功率级、输出 LC、负载阶跃、AVP 负载线。
2. 高频描述函数或三端开关模型：用于解释 COT/IQCOT 的等效调制增益、双极点 Q 值、占空比相关性。
3. 采样数据/数字延迟模型：用于解释 ADC、DPWM、计算延迟和数字积分带来的相位滞后。

新增核心建模文献：

| 文献 | 贡献 | 推荐用途 |
|---|---|---|
| Unified Three-Terminal Switch Model for Current Mode Controls. IEEE TPEL 2012. DOI: 10.1109/TPEL.2012.2188841 | current-mode 控制统一建模 | 作为 COTCM/电流内环建模背景 |
| Tian et al. Small-signal model analysis and design of constant-on-time V2 control for low-ESR caps with external ramp compensation. ECCE 2011. DOI: 10.1109/ECCE.2011.6064165 | 低 ESR V2 COT 外部 ramp 补偿 | 解释陶瓷电容下为什么需要 ramp/注入 |
| Tian et al. V2 control with capacitor current ramp compensation using lossless capacitor current sensing. ECCE 2013. DOI: 10.1109/ECCE.2013.6646689 | 电容电流 ramp compensation | 解释低损耗电流感测和补偿 |
| Digital Constant On-Time V2 Control With Hybrid Capacitor Current Ramp Compensation. IEEE TPEL 2018. DOI: 10.1109/TPEL.2017.2776265 | 数字 COT V2 混合电容电流补偿 | 数字实现的重要前置文献 |
| Small-Signal Analysis and Design of Constant On-Time Controlled Buck Converters With Duty-Cycle-Independent Quality Factors. IEEE TPEL 2023. DOI: 10.1109/TPEL.2023.3268613 | 关注 Q 值与 duty cycle 脱耦 | 与 IQCOT 的 Q 值问题高度相关 |
| Multiphase Constant On-Time Control With Phase Overlapping-Part I: Small-Signal Model. IEEE TPEL 2024. DOI: 10.1109/TPEL.2024.3368343 | 多相 phase-overlap COT 小信号模型 | 适合作为多相瞬态增强对照 |
| Multiphase Constant On-Time Control With Phase Overlapping-Part II: Stability Analysis. IEEE TPEL 2024. DOI: 10.1109/TPEL.2023.3345275 | phase-overlap COT 稳定性分析 | 说明多相快速瞬态会带来稳定性新约束 |
| A General Approach to Sampled-Data Modeling for Ripple-Based Control-Part II. IEEE TPEL 2022. DOI: 10.1109/TPEL.2021.3132624 | COT/COFT 的采样数据建模 | 数字 IQCOT 延迟分析的参考 |

你的论文可以把“小信号模型”部分写成：

传统平均模型只能解释输出 LC 的低频响应；而 COT/IQCOT 的高频动态由触发比较器、纹波或电流积分斜率、Ton/Toff 限制和数字采样延迟共同决定。IQCOT 文献指出其 Q 值随 duty cycle 改变，因此固定参数设计难以覆盖宽工作域。近年来 duty-cycle-independent Q、phase-overlap COT 和 sampled-data COT 模型的发展，说明 COT 类控制的建模与参数设计仍是活跃问题，也给 AI/智能优化提供了可解释约束。

### 18.5 多相 VRM 与数字控制的工程约束

多相 Buck VRM 的关键不是简单把单相 Buck 复制 N 次，而是同时解决：

1. 相间交错：降低输入/输出纹波，但会出现特定 duty 下的纹波抵消。
2. 电流均衡：电感 DCR、MOSFET Ron、驱动延迟、采样误差都会造成相电流偏差。
3. 瞬态 pulse scheduling：大负载阶跃时，多相是否允许相位重叠直接影响电感总电流斜率。
4. AVP/load-line：降低瞬态电容需求，但带来输出电压随负载变化的问题。
5. 数字实现：ADC 延迟、采样噪声、计算延迟、DPWM 分辨率、计时分辨率会改变环路相位裕度。

新增数字/多相文献：

| 文献 | 贡献 | 对 IQCOT-AI 的启发 |
|---|---|---|
| Digital Hybrid Ripple-Based Constant On-Time Control for Voltage Regulator Modules. IEEE TPEL 2014. DOI: 10.1109/TPEL.2013.2272015 | 数字混合 ripple-based COT for VRM | 说明数字 COT 早已面向 VRM，但仍受 ripple/采样限制 |
| Digital multiphase Constant on-time regulator supporting energy proportional computing. APEC 2015. DOI: 10.1109/APEC.2015.7104613 | 数字多相 COT，面向能量比例计算 | 支撑 XPU/服务器负载随任务快速变化的背景 |
| Comprehensive Analysis and Design of Current-Balance Loop in COT Multi-Phase Buck. IEEE Access 2020. DOI: 10.1109/ACCESS.2020.3029069 | COT 多相均流环分析 | AI 调参必须把电流均衡作为目标或约束 |
| Digital V2 COT Buck Converter With AVP and Automatic Calibration. IEEE TPEL 2021. DOI: 10.1109/TPEL.2020.3039061 | 数字 COT + AVP + 自动校准 | “自动校准”是 AI 自整定的工程先例 |
| Fully Digital Current Mode COT Buck With Output Voltage Offset Cancellation. IEEE Access 2021. DOI: 10.1109/ACCESS.2021.3133489 | 完全数字 COTCM + offset cancellation | 说明数字化后 offset/分辨率问题不能忽略 |
| Multiphase DICOT Buck With High-Resolution Current Balance. Wiley 2024. DOI: 10.1002/cta.3924 | 数字积分 COT + 高分辨率均流 | 与数字 IQCOT 最接近的参考之一 |
| 可多芯片交错并联的快速瞬态 Buck 转换器设计. 微电子学与计算机 2024. DOI: 10.19304/J.ISSN1000-7180.2024.0227 | 中文公开论文：COT current-mode、AVP、多相交错、PLL 稳频 | 可作为中文综述和国产/芯片实现线索 |

数字 IQCOT 的关键实现约束可写为：

- 采样频率必须高于控制事件变化速度，否则积分变量 q_hat 失真。
- ADC 延迟和计算延迟会降低相位裕度，AI 输出参数必须考虑延迟。
- DPWM 或计时器分辨率会限制 Ton、Toff_min 和相位调度精度。
- 电流采样 offset 会导致 inverse-charge 积分漂移，必须加入 offset cancellation 或积分泄放。
- 多相均流不能只靠主电压环，需要相电流误差环或 AI 参数中加入 Kcb。
- AI 输出必须限幅，并有 fallback 固定参数 IQCOT。

### 18.6 应用背景：AI/XPU 供电为什么需要这类课题

高算力 XPU、GPU、AI 加速器的供电特点是：

- 核心电压低，电流极大。
- 负载阶跃快，di/dt 高。
- 封装和主板阻抗限制严格。
- 多相 Buck/DrMOS/垂直供电/48 V 架构并行发展。
- 控制器需要 PMBus/I2C、遥测、在线配置和故障保护。

中文综述“高算力 XPU 供电技术研究综述”（电气工程学报，2025，20(4): 141-154，DOI: 10.11985/2025.04.010）可以作为背景材料。MPS 的中文技术资料也明确指出数字 COT 已用于多相、多回路、相数配置和自动补偿，这虽是厂商材料，但能说明工程趋势。

这部分在开题中可以这样写：

随着 AI 服务器和 XPU 计算平台功耗快速增加，传统 12 V 主板供电向 48 V/54 V 架构、多相 VRM、DrMOS 和高动态响应控制演进。COT 控制由于快速瞬态和较简单补偿，在处理器核心电源中具有工程吸引力。但高相数、低纹波、低 ESR 和高 di/dt 场景同时放大了 COT 的稳定性、均流和参数整定难度。因此，研究面向多相 VRM 的数字 IQCOT 及其 AI 参数自整定具有应用现实性。

### 18.7 AI/智能优化文献扩展

AI 文献可分三类，不建议全部混在一起写。

#### A 类：综述和总体可行性

| 文献 | 作用 |
|---|---|
| Zhao, Blaabjerg, & Wang 2021, An Overview of AI Applications for Power Electronics. DOI: 10.1109/TPEL.2020.3024914 | 证明 AI 已覆盖设计、控制、诊断、优化等方向 |
| Deep Learning Defined Power Electronic Converters. IEEE Power Electronics Magazine 2023. DOI: 10.1109/MPEL.2023.3328164 | 说明深度学习进入电力电子建模和控制范式 |
| Machine Learning based Modeling of Power Electronic Converters. ECCE 2019. DOI: 10.1109/ECCE.2019.8912608 | 支持建立代理模型/数据驱动模型 |

#### B 类：控制器/参数/模型学习

| 文献 | 作用 |
|---|---|
| DC/DC Power Converter Control-Based Deep Machine Learning Techniques: Real-Time Implementation. IEEE TPEL 2020. DOI: 10.1109/TPEL.2020.2977765 | 证明 DC/DC 深度学习控制可实时实现 |
| Inverse Application of AI for the Control of Power Converters. IEEE TPEL 2023. DOI: 10.1109/TPEL.2022.3209093 | 非常适合借鉴为“AI 输出控制系数/参考参数” |
| Parameter Estimation of Power Electronic Converters With Physics-Informed Machine Learning. IEEE TPEL 2022. DOI: 10.1109/TPEL.2022.3176468 | 支持在线估计 L、C、DCR、Ron、ESR 等漂移参数 |
| High-Frequency Modelling of COTCM Buck and Controller Design by GA. IEEE TPEL 2022. DOI: 10.1109/TPEL.2022.3197768 | COT + 高频模型 + 遗传算法，最接近你的“智能优化 COT 参数”论据 |
| Multi-Objective Design Automation in Power Electronics Using Bayesian Optimization Techniques. APEC 2025. DOI: 10.1109/APEC48143.2025.10977506 | 支持 BO 做电力电子多目标设计自动化，但不是专门 COT 控制 |

#### C 类：强化学习、安全学习与延迟

| 文献 | 作用 |
|---|---|
| Voltage Regulation of DC-DC Buck Converters Feeding CPLs via DRL. IEEE TCAS II 2022. DOI: 10.1109/TCSII.2021.3107535 | RL 用于 Buck 电压调节 |
| Implementation of Transferring RL for DC-DC Buck Converter Control via Duty Ratio Mapping. IEEE TIE 2023. DOI: 10.1109/TIE.2022.3192676 | 关注仿真到实物迁移 |
| RL-Based Control of DC-DC Buck Converter Considering Controller Time Delay. IEEE Access 2024. DOI: 10.1109/ACCESS.2024.3448535 | 直接提示数字控制延迟必须进入设计 |
| Safety-Enhanced Self-Learning for Optimal Power Converter Control. IEEE TIE 2024. DOI: 10.1109/TIE.2024.3363759 | 支持 safe learning，不宜让 AI 无保护探索 |
| Stability-Guided RL Control for Power Converters: A Lyapunov Approach. IEEE TIE 2025. DOI: 10.1109/TIE.2024.3522491 | 支持稳定性约束/李雅普诺夫约束 RL |
| Reinforcement Learning-Based Predictive Control for Power Electronic Converters. IEEE TIE 2025. DOI: 10.1109/TIE.2024.3472299 | 说明 RL 与预测控制融合是新方向 |

结论：AI 在本课题中最合理的使用方式有三个层级。

1. 低风险：离线 GA/PSO/BO 优化 IQCOT 参数表。
2. 中风险：physics-informed surrogate model 预测性能指标，优化器在线/离线查表。
3. 高创新高风险：安全约束 RL 在线微调参数，但动作限于参数层，不直接输出 gate。

### 18.8 推荐的完整研究框架

建议你的毕业设计不要一开始就做“AI 控制 IQCOT”，而是拆成五个可验证模块：

1. 基准功率级：2 相或 4 相同步 Buck VRM。
2. 控制对照组：固定参数 COTCM/RBCOT、固定参数 IQCOT、AI 参数 IQCOT。
3. 小信号/稳定性：依据 IQCOT DF 模型和采样延迟模型定义 Q、PM、带宽安全边界。
4. 数据生成：Simulink/Simscape 或 PLECS 扫描 Vin、Iload、L、C、ESR、DCR、Ron、Ton、Kiq、Qth、Kcb。
5. 优化器：先做 NSGA-II/GA/PSO/BO，最后再考虑 RL。

建议论文框架：

第一章：高算力 XPU VRM 与 COT 控制背景。  
第二章：COT/IQCOT 控制机理与小信号模型综述。  
第三章：数字 IQCOT 建模、参数敏感性和性能指标体系。  
第四章：AI/智能优化参数整定方法。  
第五章：Simulink/Simscape 仿真验证与对照实验。  
第六章：结论、局限与硬件实现展望。

### 18.9 参数敏感性地图

| 参数 | 主要影响 | 风险 | AI 优化建议 |
|---|---|---|---|
| Ton 或 Ton_margin | 平均频率、满载能力、电感峰值电流 | 过大导致频率低/纹波大，过小导致满载不足 | 作为主优化变量 |
| Kiq / gm 等效积分增益 | 触发灵敏度、Q 值、瞬态 | 过大导致噪声敏感/振荡，过小响应慢 | 结合 Q/PM 约束优化 |
| Qth / inverse-charge threshold | 事件触发点 | 影响稳态误差与频率偏移 | 查表或 BO 优化 |
| Tblank | 防止误触发、相位调度 | 过大降低瞬态响应，过小误触发 | 随相数和 fsw 设定 |
| Toff_min | 限制连续脉冲、保护低边导通 | 过大限制负载上升瞬态 | 作为安全约束，不建议 AI 自由调 |
| Kcb 电流均衡增益 | 相电流差 | 过大导致均流环振荡 | 多目标约束 |
| AVP load-line | 欠冲/过冲、电容需求 | 输出电压负载相关 | 适合与 transient 指标联合优化 |
| sampling delay | 相位裕度、数字延迟 | 会使 AI 优化结果仿真好、硬件差 | 必须显式建模 |
| current offset | 积分漂移、均流误差 | 长时间稳态偏移 | 需要 offset cancellation |

### 18.10 对照实验矩阵

建议至少做 4 组对照，否则论文贡献不够清楚：

| 组别 | 控制方法 | 目的 |
|---|---|---|
| G1 | 固定参数 RBCOT/COTCM | 传统 COT 基线 |
| G2 | 固定参数 IQCOT | 证明 IQCOT 本身优势 |
| G3 | 规则自适应 IQCOT | 证明简单查表/规则能做到什么程度 |
| G4 | AI 优化 IQCOT | 证明 AI 参数整定的增益 |

工况矩阵：

| 工况 | 扫描范围建议 |
|---|---|
| Vin | 5 V, 8 V, 12 V, 16 V；如做 48 V 架构，可先不直接降到 1 V，而采用两级背景说明 |
| Vout | 0.7 V, 0.8 V, 1.0 V, 1.2 V |
| Iload step | 0-25%, 25-75%, 10-90%, 50-100% |
| slew rate | 50 A/us, 100 A/us, 500 A/us；按模型能力设置 |
| 相数 | 2 相作为基础，4 相作为增强 |
| L/C/ESR/DCR/Ron 偏差 | ±10%, ±20% |
| delay | 0, 0.25 Ts, 0.5 Ts, 1 Ts 等效延迟 |

性能指标：

- Vundershoot
- Vovershoot
- settling time
- steady-state ripple
- effective switching frequency mean/std
- phase-current imbalance
- peak inductor current
- estimated efficiency
- stability proxy：Q、PM、GM 或离散极点位置
- safety violations：overcurrent、overvoltage、minimum off-time violation

### 18.11 研究空白和创新点

可提炼成三个层级：

创新点 1：数字 IQCOT 参数自整定框架  
现有 IQCOT 文献集中在模拟控制结构、小信号模型和固定参数性能展示；数字 COT 文献集中在 DICOT、数字 V2 COT、均流和校准。把 IQCOT 的 inverse-charge 参数数字化，并用智能优化做宽域自整定，是一个明确交叉空白。

创新点 2：模型约束的 AI 优化  
已有 AI/RL Buck 控制文献多直接优化 duty 或控制器输出，存在稳定性和可解释性风险。本课题可把 IQCOT 小信号模型、Q/PM/频率/电流限制作为硬约束或惩罚项，使 AI 输出参数而非开关动作。

创新点 3：多目标宽工况验证  
已有单点调参不能充分说明 VRM 的实际适用性。本课题可以在 Vin、负载、器件参数、延迟、相数变化下验证 Pareto 前沿，给出参数敏感性和鲁棒性结论。

### 18.12 强反方审查

| 反方质疑 | 严重性 | 回应策略 |
|---|---:|---|
| IQCOT 已经自然改变 on-time，AI 是多余的 | Major | 自然改变 on-time 不等于全工况 Q/均流/延迟/效率最优；AI 优化的是参数层和宽域鲁棒性 |
| AI 控制电源会导致不稳定 | Critical if unmanaged | 不让 AI 直接控制 gate；只调参数；加入 PM/Q/电流/频率硬约束和 fallback |
| Simulink 数据训练出的 AI 无法迁移到硬件 | Major | 加入参数扰动、延迟、噪声、offset；引用 transfer RL 和 delay-aware RL；最后只声称仿真验证 |
| 文献中已有 DICOT，为什么还要 IQCOT | Major | DICOT 证明数字积分 COT 可行；IQCOT 的优势是不依赖 ripple 与 inverse-charge 瞬态机制，二者可融合 |
| 只是 GA 调参，不够 AI | Minor/Major depending wording | 可表述为智能优化/AI-assisted tuning；若要更强 AI，可加入 surrogate model 或 safe RL |
| 没有硬件就不够电源方向 | Major | 毕设可定位为建模与仿真；若条件允许补 HIL/FPGA 或低压 Buck demo |

### 18.13 推荐最终题目和题目边界

最推荐题目：

基于模型约束智能优化的多相 Buck VRM 数字 IQCOT 控制参数自整定研究

题目边界：

- 不做芯片版图。
- 不直接设计 48 V 到 0.8 V 单级超大电流硬件。
- 不让 AI 直接产生 MOSFET gate 信号。
- 以 2 相/4 相同步 Buck 为验证对象。
- 以 IQCOT 参数层优化为核心贡献。

### 18.14 扩展参考文献

22. Bari, S., Li, Q., & Lee, F. C. (2015). A new current mode control for higher noise immunity and faster transient response in multi-phase operation. IEEE ECCE. <https://doi.org/10.1109/ECCE.2015.7309953>
23. Unified Three-Terminal Switch Model for Current Mode Controls. IEEE Transactions on Power Electronics, 2012. <https://doi.org/10.1109/TPEL.2012.2188841>
24. Tian, S., et al. (2011). Small-signal model analysis and design of constant-on-time V2 control for low-ESR caps with external ramp compensation. IEEE ECCE. <https://doi.org/10.1109/ECCE.2011.6064165>
25. V2 control with capacitor current ramp compensation using lossless capacitor current sensing. IEEE ECCE, 2013. <https://doi.org/10.1109/ECCE.2013.6646689>
26. Digital Constant On-Time V2 Control With Hybrid Capacitor Current Ramp Compensation. IEEE Transactions on Power Electronics, 2018. <https://doi.org/10.1109/TPEL.2017.2776265>
27. Small-Signal Analysis and Design of Constant On-Time Controlled Buck Converters With Duty-Cycle-Independent Quality Factors. IEEE Transactions on Power Electronics, 2023. <https://doi.org/10.1109/TPEL.2023.3268613>
28. Multiphase Constant On-Time Control With Phase Overlapping-Part I: Small-Signal Model. IEEE Transactions on Power Electronics, 2024. <https://doi.org/10.1109/TPEL.2024.3368343>
29. Multiphase Constant On-Time Control With Phase Overlapping-Part II: Stability Analysis. IEEE Transactions on Power Electronics, 2024. <https://doi.org/10.1109/TPEL.2023.3345275>
30. Small-Signal Model of Multiphase Constant On-Time Control with Phase Overlapping. IEEE APEC, 2023. <https://doi.org/10.1109/APEC43580.2023.10131445>
31. Digital Hybrid Ripple-Based Constant On-Time Control for Voltage Regulator Modules. IEEE Transactions on Power Electronics, 2014. <https://doi.org/10.1109/TPEL.2013.2272015>
32. Digital multiphase Constant on-time regulator supporting energy proportional computing. IEEE APEC, 2015. <https://doi.org/10.1109/APEC.2015.7104613>
33. Chen, Zeng, Cheng, & Lin. Comprehensive Analysis and Design of Current-Balance Loop in Constant On-Time Controlled Multi-Phase Buck Converter. IEEE Access, 2020. <https://doi.org/10.1109/ACCESS.2020.3029069>
34. Hu, Tsai, & Tsai. Digital V2 Constant ON-Time Control Buck Converter With Adaptive Voltage Positioning and Automatic Calibration Mechanism. IEEE TPEL, 2021. <https://doi.org/10.1109/TPEL.2020.3039061>
35. Fully Digital Current Mode Constant On-Time Controlled Buck Converter With Output Voltage Offset Cancellation. IEEE Access, 2021. <https://doi.org/10.1109/ACCESS.2021.3133489>
36. Parameter Estimation of Power Electronic Converters With Physics-Informed Machine Learning. IEEE Transactions on Power Electronics, 2022. <https://doi.org/10.1109/TPEL.2022.3176468>
37. Machine Learning based Modeling of Power Electronic Converters. IEEE ECCE, 2019. <https://doi.org/10.1109/ECCE.2019.8912608>
38. Deep Learning Defined Power Electronic Converters. IEEE Power Electronics Magazine, 2023. <https://doi.org/10.1109/MPEL.2023.3328164>
39. Safety-Enhanced Self-Learning for Optimal Power Converter Control. IEEE Transactions on Industrial Electronics, 2024. <https://doi.org/10.1109/TIE.2024.3363759>
40. Stability-Guided Reinforcement Learning Control for Power Converters: A Lyapunov Approach. IEEE Transactions on Industrial Electronics, 2025. <https://doi.org/10.1109/TIE.2024.3522491>
41. Reinforcement Learning-Based Predictive Control for Power Electronic Converters. IEEE Transactions on Industrial Electronics, 2025. <https://doi.org/10.1109/TIE.2024.3472299>
42. Learning-Based Model Predictive Control of DC-DC Buck Converters in DC Microgrids: A Multi-Agent Deep Reinforcement Learning Approach. Energies, 2022. <https://doi.org/10.3390/en15155399>
43. Multi-Objective Design Automation in Power Electronics Using Bayesian Optimization Techniques. IEEE APEC, 2025. <https://doi.org/10.1109/APEC48143.2025.10977506>
44. 宋昱锋, 吴红飞, 邢岩. 高算力 XPU 供电技术研究综述. 电气工程学报, 2025, 20(4): 141-154. <https://doi.org/10.11985/2025.04.010>
45. 陈添之等. 可多芯片交错并联的快速瞬态 Buck 转换器设计. 微电子学与计算机, 2024. <https://doi.org/10.19304/J.ISSN1000-7180.2024.0227>
46. MPS. 恒定导通时间（COT）控制的过去与现在. <https://www.monolithicpower.cn/cn/learning/resources/the-past-and-present-of-cot-control>
47. MPS. 多相控制器与 Intelli-Phase 产品资料. <https://www.monolithicpower.cn/cn/products/power-management/multi-phase-controllers-intelli-phase.html>

## 19. CNKI 国际版实测检索补充

安装 vluckyzhang/cnki-skills-codex 后，CNKI 国际版可以通过直达结果页检索并解析；国内站当前仍有证书错误或 HTTP 418。

实测日期：2026-06-14。  
入口：CNKI 国际版 oversea.cnki.net。  
限制：本次只验证检索与结果解析；下载原文、原版阅读、HTML 阅读、引用导出仍取决于登录和机构权限。

### 19.1 关键词：定导通时间 Buck

检索式：主题 = “定导通时间 Buck”。  
结果：共 43 条，当前页 1/3。  
结果结构：中文期刊 14 条，学位论文 29 条；主题聚类包括“变换器”“恒定导通时间控制”“导通时间”“DC-DC”“Buck 变换器”；来源类别包含北大核心、CSCD、EI、SCI。

| 序号 | 题名 | 作者 | 来源 | 时间 | 类型 | 被引 | 下载 |
|---:|---|---|---|---|---|---:|---:|
| 1 | 基于自适应恒定导通时间的 Buck 型变换器的设计 | 齐恩光 | 南京邮电大学 | 2025-10-10 | 硕士 |  | 512 |
| 2 | 自适应导通时间谷值电流模控制 Buck 型 DC-DC 稳压器研究与设计 | 郑朝伟 | 武汉科技大学 | 2025-06-01 | 硕士 |  | 190 |
| 3 | 一种恒定导通时间 I2 纹波控制 Buck 车载 LED 驱动电源设计 | 张留洋; 周游; 王艳波 | 农业装备与车辆工程 | 2025-05-25 | 期刊 |  | 111 |
| 4 | 基于自适应导通时间控制 BUCK 型 DC-DC 转换器芯片的研究与设计 | 李潇 | 天津理工大学 | 2025-02-01 | 硕士 |  | 134 |
| 5 | 自适应可调恒定导通时间 Buck 型直流电压变换器设计 | 韩蕾; 郭振山; 游鋆丹; 胡凯 | 天津职业技术师范大学学报 | 2024-06-26 | 期刊 | 2 | 247 |
| 6 | 一款高效同步自适应导通时间控制的 BUCK 变换器的研究与设计 | 张辰 | 西安电子科技大学 | 2024-06-01 | 硕士 |  | 298 |
| 7 | 一种高效低功耗的自适应恒定导通时间 Buck DC-DC 转换器设计 | 姜澳 | 吉林大学 | 2024-05-01 | 硕士 | 6 | 1020 |
| 8 | 基于自适应导通时间控制的多模式 Buck 变换器的研究与设计 | 闫容赫 | 电子科技大学 | 2024-04-01 | 硕士 | 5 | 725 |
| 9 | 自适应导通时间控制的 Buck 芯片设计 | 冯智园 | 东南大学 | 2023-06-29 | 硕士 |  | 171 |
| 10 | 自适应导通时间谷值电流模 BUCK 型 DC-DC 开关变换器设计与研究 | 陈玉 | 南京理工大学 | 2023-04-01 | 硕士 | 2 | 440 |
| 11 | 基于恒定导通时间控制的多相 Buck 变换器研究 | 郭泽惠 | 电子科技大学 | 2022-04-11 | 硕士 | 14 | 1645 |
| 12 | 基于自适应导通时间控制的 BUCK 型 DC-DC 变换器研究与设计 | 杜明浩 | 南京理工大学 | 2021-12-01 | 硕士 | 6 | 391 |
| 13 | V2 恒定导通时间控制 Buck 变换器稳定机理分析 | 张美健 | 通信电源技术 | 2020-03-10 | 期刊 | 8 | 337 |
| 14 | CRM Buck-Buck/Boost PFC 变换器的分段定导通时间控制研究 | 陈杰楠 | 南京理工大学 | 2020-03-01 | 硕士 | 2 | 305 |
| 15 | 快速瞬态响应的变导通时间模式 Buck 变换器 | 曾鹏灏; 杨明宇; 甄少伟; 陈佳伟; 石丹 | 微电子学 | 2019-12-20 | 期刊 | 6 | 189 |
| 16 | 变导通时间控制 Buck 变换器分析与设计 | 曾鹏灏 | 电子科技大学 | 2019-04-01 | 硕士 | 25 | 643 |

对本课题最相关的是第 11、13、15、16 条：多相 Buck、V2 COT 稳定机理、变导通时间快速瞬态。

### 19.2 关键词：IQCOT

检索式：主题 = “IQCOT”。  
结果：共 3 条，均为学位论文。

| 序号 | 题名 | 作者 | 来源 | 时间 | 类型 | 被引 | 下载 |
|---:|---|---|---|---|---|---:|---:|
| 1 | 非对称多相 Buck 变换器高动态控制算法设计 | 聂静雨 | 东南大学 | 2023-06-21 | 硕士 |  | 100 |
| 2 | 基于 Sigma 变换器的恒定导通时间控制算法设计 | 吴昱庚 | 东南大学 | 2023-05-29 | 硕士 |  | 109 |
| 3 | 低压大电流 sigma 变换器的数字控制策略研究 | 于利民 | 东南大学 | 2022-11-28 | 博士 | 1 | 358 |

判断：中文库中 “IQCOT” 直接命中的文献很少，且更偏 Sigma/非对称多相 Buck 数字控制。中文综述不能只搜 IQCOT，应扩展到“恒定导通时间”“自适应导通时间”“多相 Buck”“数字控制”等关键词。

### 19.3 关键词：反向电荷 定导通时间

检索式：主题 = “反向电荷 定导通时间”。  
结果：暂无数据。

判断：IQCOT 的中文直译“反向电荷定导通时间”在 CNKI 里不常用。中文论文中建议保留英文术语 Inverse Charge Constant On-Time (IQCOT)，并解释为“基于反向电荷/电感电流积分思想的定导通时间控制”。

### 19.4 关键词：多相 Buck 恒定导通时间

检索式：主题 = “多相 Buck 恒定导通时间”。  
结果：共 4 条，均为学位论文。

| 序号 | 题名 | 作者 | 来源 | 时间 | 类型 | 被引 | 下载 |
|---:|---|---|---|---|---|---:|---:|
| 1 | 一种高效低功耗的自适应恒定导通时间 Buck DC-DC 转换器设计 | 姜澳 | 吉林大学 | 2024-05-01 | 硕士 | 6 | 1020 |
| 2 | 高压 COT 开关电源的研究与设计 | 李江山 | 西安电子科技大学 | 2023-03-01 | 硕士 | 1 | 414 |
| 3 | 基于恒定导通时间控制的多相 Buck 变换器研究 | 郭泽惠 | 电子科技大学 | 2022-04-11 | 硕士 | 14 | 1645 |
| 4 | 谷值电流模 COT 控制自适应斜坡补偿技术研究 | 罗攀 | 电子科技大学 | 2021-04-01 | 硕士 | 12 | 1355 |

判断：这组结果与多相 COT、谷值电流模、自适应斜坡补偿直接相关，建议作为中文硕士论文背景精读候选。

### 19.5 关键词：数字 恒定导通时间 Buck

检索式：主题 = “数字 恒定导通时间 Buck”。  
结果：共 9 条。

| 序号 | 题名 | 作者 | 来源 | 时间 | 类型 | 被引 | 下载 |
|---:|---|---|---|---|---|---:|---:|
| 1 | 基于自适应恒定导通时间的 Buck 型变换器的设计 | 齐恩光 | 南京邮电大学 | 2025-10-10 | 硕士 |  | 512 |
| 2 | 基于自适应恒定导通时间的降压型开关转换器设计 | 谭杰 | 重庆大学 | 2024-06-01 | 硕士 |  | 27 |
| 3 | 基于 Sigma 变换器的恒定导通时间控制算法设计 | 吴昱庚 | 东南大学 | 2023-05-29 | 硕士 |  | 109 |
| 4 | 数字式多相 DC-DC 变换器稳定性分析 | 朱健; 胡耀华; 李学宁 | 电源学报 | 2023-03-07 | 期刊 |  | 332 |
| 5 | 高压 COT 开关电源的研究与设计 | 李江山 | 西安电子科技大学 | 2023-03-01 | 硕士 | 1 | 414 |
| 6 | 大功率 LED 恒流驱动芯片设计 | 王思盈 | 天津理工大学 | 2023-02-01 | 硕士 | 1 | 148 |
| 7 | 提高同步整流 Buck 变换器轻载效率的数字化控制方案分析 | 徐杨 | 电气技术 | 2017-02-15 | 期刊 | 11 | 283 |
| 8 | 双缘 COT 调制数字电压型控制 Buck 变换器分析 | 周国华; 陈兴; 崔恒丰 | 西南交通大学学报 | 2015-02-15 | 期刊 | 15 | 302 |

判断：数字 COT 的中文论文数量少，但“数字式多相 DC-DC 稳定性分析”和“双缘 COT 调制数字电压型控制 Buck”对数字化约束、采样/稳定性分析有参考价值。

### 19.6 关键词：AI Buck 变换器 控制

检索式：主题 = “AI Buck 变换器 控制”。  
结果：共 849 条。该检索式过宽，包含大量 Buck-Boost、滑模控制、MPC、PID、遗传算法、神经网络控制等结果。前 8 条中较相关的包括：

| 序号 | 题名 | 作者 | 来源 | 时间 | 类型 | 下载 |
|---:|---|---|---|---|---|---:|
| 4 | 基于改进式单神经元自适应 PID 的 Buck 变换器控制策略 | 张丞昊; 陈息坤 | 电器与能效管理技术 | 2026-02-28 | 期刊 | 79 |
| 5 | 基于 PI-模型预测控制的四相交错并联 Buck 变换器 | 杜子桥; 苏淑靖; 亢叶飞 | 舰船电子工程 | 2026-02-20 | 期刊 | 33 |
| 6 | 基于改进遗传算法的 Buck 变换器高性能 MPC 控制策略 | 巩昊辰; 马彬 | 北京信息科技大学学报(自然科学版) | 2026-02-15 | 期刊 | 96 |
| 8 | 四开关 Buck-Boost 变换器数字控制软开关设计 | 何泽平; 董纪清; 赖炳钦; 陈文韬 | 电力电子技术 | 2026-02-11 | 期刊 | 560 |

判断：AI/Buck 中文检索需要进一步限定为“遗传算法 Buck MPC”“强化学习 Buck 变换器”“神经网络 Buck 控制”“智能优化 DC-DC 控制”，否则噪声过高。

### 19.7 对原研究调研的修正

CNKI 实测后，中文文献补充结论如下：

1. 中文库中 IQCOT 直接命中很少，国内研究多用“恒定导通时间”“自适应导通时间”“谷值电流模 COT”“变导通时间”“多相 Buck”等术语。
2. 中文硕士论文对芯片级 COT/AOT、谷值电流模、自适应斜坡、轻载效率、多模式控制覆盖较多，可作为国内研究现状。
3. 与本课题最贴近的中文文献候选包括：郭泽惠 2022 多相 Buck COT、罗攀 2021 谷值电流模 COT 自适应斜坡、周国华等 2015 双缘 COT 数字电压型控制、朱健等 2023 数字式多相 DC-DC 稳定性分析、聂静雨 2023 非对称多相 Buck 高动态控制。
4. 中文文献可支撑“国内 COT/AOT 和多相 Buck 研究基础存在，但 IQCOT + AI 参数自整定仍缺少直接研究”这一研究空白。
