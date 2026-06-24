# 四相数字 IQCOT Buck 变换器的积分事件核小信号建模、受限均流执行量设计与 Simulink 交叉验证

## 摘要

四相交错 Buck 变换器是低压大电流 VRM 的典型结构，COT 与 IQCOT 控制因快速瞬态和紧凑实现而具有吸引力。已有研究已经提出 IQCOT 控制律及其高频小信号模型，也已经建立 ripple-based COT sampled-data 模型、多相 COT phase-overlap 模型和多相数字积分 COT 均流方案。本文不声称首次提出 IQCOT、COT sampled-data 建模或多相数字均流，而是针对四相数字 IQCOT 中更具体的工程问题：面积阈值、检测延迟、数字量化、相位间隔和 Ton-trim 均流执行量究竟通过哪些小信号通道影响系统。

本文提出积分事件核（Integral-Event Kernel, IEK）建模框架，从 IQCOT 面积事件

```math
\int_{a_k}^{t_{k+1}} [v_c(t)-R_i i_{L}(t)]dt=\Lambda
```

出发，用移动边界线性化保留 off-time 积分区间内的功率级状态记忆，并将四相事件扰动分解为 common-mode 与 differential-mode。已有单相验证显示，动态 IEK 对周期响应的最大幅值误差低于 0.00018%，而 He-only 局部面积刚度模型最大误差可达 771.62%。本文新增四相密集验证：在 24 个 common-mode 频点中，He-only 模型最坏相对幅值误差达到 7969.65%，但在 `ω/π=0.2` 附近误差仅为 -0.66%。最坏相对误差发生在真实 wait 响应接近谷值的频段，需与绝对幅值曲线共同解读；其意义不是夸大单点百分比，而是说明局部刚度模型缺少频率选择性事件记忆。执行量矩阵进一步表明，m2 差模下 Lambda_diff 的电流增益约为 0.0100 mA/(1e-13)，Ton_diff 的电流增益约为 765.07 mA/(0.1 ns)，二者相差约五个数量级；检测延迟差模主要表现为相位时序扰动。本文进一步使用用户已有四相 Simulink/Simscape COT-IQCOT 模型进行 14 点交叉验证，在不保存模型的前提下临时钳位四相 on-time，结果显示 m2 `Ton` 差模的电流投影斜率约为 0.482 A/ns，而 common-mode `Ton` 主要表现为闭环频率调整，支持“`Ton_diff` 是主要均流执行量”的物理解释。基于 140 个 DCR 失配设计点、数字 jitter 预算和 Simulink 交叉验证，本文给出受限均流设计规则：Lambda_diff 适合 phase-spacing/ripple-cancellation 调节，Ton_diff 是主要 DC current-sharing 执行量，但必须受 phase-spacing margin 约束。

**关键词**：IQCOT；COT；四相 Buck；小信号模型；sampled-data；积分事件核；均流；phase-spacing jitter；数字量化

## Abstract

Four-phase interleaved buck converters are widely used in low-voltage high-current VRMs. COT and IQCOT control are attractive for fast transient response and compact implementation. This paper does not claim to invent IQCOT, COT sampled-data modeling, or multiphase digital current balancing. Instead, it develops a focused integral-event kernel (IEK) framework for four-phase digital IQCOT converters, separating area-threshold, detection-delay, phase-spacing, and Ton-trim current-sharing channels. Starting from the IQCOT area event, the model linearizes the moving event boundary and retains the state memory accumulated during the off-time integration interval. Dense four-phase validation shows that a local He-only stiffness approximation can be accurate at some frequencies but can fail severely at others, with a worst-case amplitude error of 7969.65% in the studied operating point. The actuator matrix shows that differential area threshold is primarily a phase-spacing actuator, whereas differential on-time trim is the dominant DC current-sharing actuator. A digital jitter budget maps area-threshold bit width, detection clock, and Ton resolution into event jitter, phase-spacing jitter, and current-sharing quantization. A separate 14-case Simulink/Simscape cross-validation on an existing four-phase COT-IQCOT model confirms the modal interpretation of differential on-time trim: m2 Ton perturbation produces an approximately linear current projection of about 0.482 A/ns, while common-mode Ton perturbation is mainly absorbed as closed-loop frequency adjustment. The resulting framework provides a reproducible small-signal basis for constrained tuning of four-phase digital IQCOT buck converters.

## 1. 引言

处理器和 AI 加速器供电要求 VRM 在低电压、大电流、快速负载阶跃和高电流密度之间取得平衡。多相交错 Buck 通过相位错开降低输入与输出纹波，并通过相电流分担降低热应力，是 VRM 中最常见的拓扑之一。COT 控制由于不依赖固定周期调制器、瞬态响应快、轻载模式自然，长期被用于低压大电流电源。IQCOT 将 COT 的触发条件从瞬时纹波比较扩展为面积积分事件，在多相纹波抵消点附近仍能保持有效检测量，因此适合高性能 VRM。

然而，在数字四相 IQCOT 实现中，设计者面对的并不是一个单一参数。面积阈值 `Λ`、积分电流系数 `Ri`、检测延迟、阈值量化、phase manager、Ton-trim 和 DCR 失配都会改变事件时刻；这些变化又同时影响输出调节、相位间隔和相电流均衡。如果把所有参数都当成“能调频率/能调电流”的经验旋钮，容易出现两个误判：一是用 Lambda_diff 试图做 DC 均流，二是为了追求 Ton 均流而破坏相位间隔。

本文的核心问题是：**四相数字 IQCOT 的面积事件能否被写成一个可用于执行量分类和数字预算的小信号模型？** 本文给出的答案是肯定的，但边界必须清楚。已有工作已经覆盖 IQCOT 控制律、高频小信号模型、RBCOT sampled-data 模型、多相 COT phase-overlap 以及多相 DICOT 均流。本文的增量不在“首次提出控制律”，而在四相数字实现层面提出 IEK 模态化分析，用同一框架解释 `Λ_cm`、`Λ_diff`、检测延迟差模和 `Ton_diff` 的不同物理通道。

## 2. 相关工作与创新边界

Bari 的博士论文和后续 ECCE/JESTPE 论文已经提出 IQCOT 控制思想，并给出 IQCOT 高频小信号模型与 ultrafast transient 结果。因此，本文不把 IQCOT 控制律本身作为创新点。Yan、Ruan、Li 以及 Gabriele 等已经系统发展了 ripple-based COT sampled-data 模型，能处理事件调制、边带效应和任意纹波注入网络；本文借鉴 sampled-data 思想，但事件函数是 IQCOT 的面积积分条件，而不是一般纹波比较器的瞬时阈值交叉。

多相方面，Li 等关于 DICOT 和 high-resolution current balance 的工作已经说明数字积分 COT 与高分辨率均流在工程上可行；Sridhar 和 Li 关于 multiphase COT phase-overlap 的研究也已经指出多相 COT 不能简单由单相模型外推。本文因此把创新边界收缩为一个更可辩护的问题：**在四相数字 IQCOT 中，面积事件核如何区分相位执行量和均流执行量，并如何给出数字 jitter/量化预算。**

本文贡献概括为四点：

1. 从 IQCOT 面积事件出发，推导保留状态记忆的 IEK 小信号模型，说明 He-only 是忽略动态事件核 `K(z)` 的退化近似。
2. 在四相固定工作点下建立 common/differential 模态解释，将 `Λ_cm`、`Λ_diff`、检测延迟差模和 `Ton_diff` 分到不同执行通道。
3. 通过密集扫频、幅值线性、执行量矩阵和 DCR 失配网格，验证 `Λ_diff` 不是有效 DC 均流执行量，`Ton_diff` 才是主要均流执行量但有相位代价。
4. 基于 IEK 灵敏度建立数字面积阈值位宽、检测时钟和 Ton 分辨率的 jitter 预算方法。
5. 使用已有四相 Simulink/Simscape COT-IQCOT 模型进行不保存模型的交叉验证，证明 `Ton_diff` 均流通道在更接近电路级的模型中仍成立，并明确该验证尚不等同于完整 `Λ` 面积事件核验证。

## 3. IQCOT 面积事件与 IEK 小信号推导

第 `k` 次 off-time 面积事件可写为

```math
F_k(x_k,T_{off,k},\Lambda_k)
=\int_0^{T_{off,k}} h(x_k,\tau)d\tau-\Lambda_k=0,
\qquad h(t)=v_c(t)-R_i i_L(t).
```

设 off-time 内功率级满足

```math
\dot{x}=A_{off}x+B_{off}u,\qquad
h(t)=C_h x(t)+D_hu(t).
```

则

```math
x(\tau)=e^{A_{off}\tau}x_k
+\int_0^\tau e^{A_{off}(\tau-s)}B_{off}u(s)ds.
```

对移动事件边界线性化：

```math
\delta F
=F_x\delta x_k+H_e\delta T_{off,k}-\delta\Lambda_k=0,
```

其中

```math
F_x=\int_0^{T_{off}} C_h e^{A_{off}\tau}d\tau,
\qquad H_e=h(T_{off}^{-}).
```

因此

```math
\delta T_{off,k}
=\frac{1}{H_e}(\delta\Lambda_k-F_x\delta x_k).
```

这一步揭示了 He-only 近似的隐含假设：若令 `F_x δx_k=0`，就得到 `δT≈δΛ/H_e`；但真实 IQCOT 面积事件中，`δx_k` 由过去事件时刻、Ton 扰动、输出电容状态和相电流状态共同决定。将事件后的状态更新写成

```math
\delta x_{k+1}=A_d\delta x_k+B_T\delta T_{off,k}+B_u\delta u_k,
```

代入上式得到

```math
\delta x_{k+1}
=\left(A_d-\frac{B_TF_x}{H_e}\right)\delta x_k
+\frac{B_T}{H_e}\delta\Lambda_k+B_u\delta u_k.
```

定义

```math
A_{IEK}=A_d-\frac{B_TF_x}{H_e},
```

即可得到阈值面积到事件时刻的 sampled-data 传函

```math
G_{T\Lambda}(z)=D_{T\Lambda}+C_T(zI-A_{IEK})^{-1}B_{IEK}.
```

也可写成动态面积刚度形式：

```math
G_{T\Lambda}(z)=\frac{1}{H_e+K(z)}.
```

其中 `K(z)` 是由功率级状态记忆引起的积分事件核。He-only 模型对应 `K(z)=0`。对于自治开关系统，整体时间平移不应改变物理轨道，因此低频处满足

```math
K(1)=H_s-H_e.
```

该条件在已有单相脚本中已数值验证：`K(1)=H_s-H_e=-4.5837 mV`，动态 IEK 对非线性逐周期仿真的周期幅值误差低于 `0.00018%`。

![Figure 1. Integral-event kernel view](E:/Desktop/codex/output/figures/fig1_iek_event_kernel.svg)

## 4. 四相 common/differential IEK 与执行量分类

四相系统中，事件按相序轮转。设当前导通相为 `p_k=k mod 4`，下一触发相为 `q_k=(p_k+1) mod 4`，则下一相 IQCOT 事件为

```math
\int_{a_k}^{t_{k+1}} [V_C-R_{i,q}i_q(t)]dt=\Lambda_q.
```

对匹配四相系统，小信号矩阵近似具有循环对称性，可使用 DFT/Clarke-like 变换分解为 common-mode 与 differential-mode：

```math
\tilde{\Lambda}_m=Q^{-1}\delta\boldsymbol{\Lambda},\qquad
\tilde{T}_m=Q^{-1}\delta\boldsymbol{T}.
```

`m=0` 为共模，主要影响总事件周期、输出调节和总 jitter；`m=1,2,3` 为差模，主要影响相位间隔、差模 jitter 和纹波抵消。本文把输出定义为

```math
y=
\begin{bmatrix}
\Delta I_{diff} \\
\Delta \phi \\
\Delta v_o
\end{bmatrix},
\qquad
u=
\begin{bmatrix}
\Delta\Lambda_{diff} \\
\Delta T_{on,diff} \\
\Delta t_{d,diff}
\end{bmatrix}.
```

小信号执行量矩阵为

```math
y(z)=
\begin{bmatrix}
G_{I\Lambda} & G_{IT} & G_{Id} \\
G_{\phi\Lambda} & G_{\phi T} & G_{\phi d} \\
G_{v\Lambda} & G_{vT} & G_{vd}
\end{bmatrix}
u(z).
```

本文的核心设计命题是

```math
|G_{I\Lambda}(1)|\ll |G_{IT}(1)|,
\qquad
|G_{\phi\Lambda}(1)|>0,
\qquad
|G_{\phi T}(1)|>0.
```

也就是说，`Λ_diff` 主要是相位间隔执行量，`Ton_diff` 是主要 DC 均流执行量，但 `Ton_diff` 同样会扰动相位间隔。

![Figure 3. Modal decomposition](E:/Desktop/codex/output/figures/fig3_multiphase_modal_channels.svg)

## 5. 仿真与数据设置

四相模型参数为：`Vin=12.0 V`、`Vref=1.0 V`、`Iout=40.0 A`、每相电流 `Iph=10.0 A`、`L=200 nH`、`C=7.2 mF`、`DCR=1.5 mΩ`、`Ri=0.5 mΩ`、每相开关频率 `500 kHz`。稳态 `Ton=169.167 ns`，`Twait=330.833 ns`，`VC=5.0167 mV`，面积阈值 `Λ=6.343943e-10`。

新增验证脚本为：

```text
E:/Desktop/codex/output/iqcot_four_phase_dense_validation.py
E:/Desktop/codex/output/iqcot_digital_jitter_budget.py
E:/Desktop/codex/output/iqcot_generate_paper_figures_v2.py
E:/Desktop/codex/output/iqcot_export_article_v2.py
E:/Desktop/codex/output/iqcot_simulink_modal_cross_validation.m
```

新增数据包括：

| 数据集 | 点数 | 文件 |
|---|---:|---|
| common-mode 密集扫频 | 24 | `iqcot_four_phase_dense_common_sweep.csv` |
| common-mode 幅值线性 | 30 | `iqcot_four_phase_common_amplitude_linearity.csv` |
| 执行量扫描 | 54 | `iqcot_four_phase_actuator_sweep.csv` |
| 执行量矩阵 | 9 | `iqcot_four_phase_actuator_matrix.csv` |
| DCR 失配设计网格 | 140 | `iqcot_four_phase_mismatch_grid.csv` |
| 数字 jitter 预算 | 80+ | `iqcot_digital_*_budget.csv` |
| Simulink 模态交叉验证 | 14 + 8 | `iqcot_simulink_modal_cross_validation_summary.csv`；`iqcot_simulink_modal_cross_validation_highres_summary.csv` |

Simulink 交叉验证使用的模型为 `E:/Desktop/4cot/versions/v0027_20260611_135822_iqcot_optimized_final_cn_docs/four_phase.slx`。该模型的事实源参数与解析 IEK 脚本不同：`Ton_cmd=196.5 ns`、`Tblank=480 ns`、`L=200 nH`、`DCR_L1..4=10 mΩ`、`Cout=7.26 mF`、`ESR_C=90 μΩ`，控制链为 `Vout -> Relay -> global blanking -> PhaseScheduler_4Phase -> COT cells -> gate drivers -> MOSFETs`。模型中的 IQCOT 路径是每相电流误差的泄放积分去调节 `Ton_iqcot_i`，不是本文完整的输出误差面积阈值 `Λ` 触发器。因此，本文把该模型用于验证差模 on-time 均流通道和模态执行量解释，而不把它作为完整 IEK 面积核的直接证明。

## 6. 结果一：He-only 模型的频率选择性失效

旧稿只给出少数 common-mode 频点，容易被质疑为挑点。本文新增 24 个频点，覆盖 `ω/π=0.002` 到 `0.85`。结果显示，He-only 模型并非处处错误：在 `ω/π=0.2` 附近，误差仅为 -0.66%。但在 `ω/π=0.008` 附近，相对误差达到 7969.65%。这个百分比应谨慎解读：该频点真实 wait 响应幅值接近局部谷值，因此相对误差会被放大；更可靠的读法是同时观察 Fig. 7 左侧的绝对幅值曲线和右侧的误差曲线。结论不是“He-only 永远错误”，而是它无法表达 `K(z)` 的频率选择性。

![Figure 7. Dense common-mode sweep](E:/Desktop/codex/output/figures/fig7_dense_common_sweep.png)

从工程角度看，这个结果很重要。若用 `δT≈δΛ/H_e` 直接设计面积 DAC 位宽或 dither 幅值，可能在某些频段严重低估或高估 wait jitter。IEK 模型通过 `H_e+K(z)` 描述动态面积刚度，因此能回答“在哪些频段阈值噪声最敏感”。

## 7. 结果二：执行量矩阵证明 Lambda_diff 与 Ton_diff 不等价

表 1 给出三种差模执行量在 `m2_alt` 模式下的关键增益。

| 执行量 | 归一化幅值 | 电流 pk-pk 增益 | 相等待 pk-pk 增益 | 解释 |
|---|---:|---:|---:|---|
| Lambda_diff | 1e-13 | 0.00996 mA | 0.1322 ns | 基本不改变 DC 均流，主要移动事件间隔 |
| Ton_diff | 0.1 ns | 765.07 mA | 84.64 ns | 强均流执行量，但相位代价大 |
| delay_diff | 0.1 ns | 0.02325 mA | 0.3088 ns | 主要是检测时序/phase-spacing 扰动 |

![Figure 8. Actuator matrix](E:/Desktop/codex/output/figures/fig8_actuator_matrix.png)

该矩阵是本文最直接的创新证据之一。它把“Lambda_diff 不能均流、Ton_diff 可以均流”从观察性描述变成了可量化的小信号通道分离。对四相数字 IQCOT 而言，`Λ_diff` 可以用于相位间隔修正、差模 jitter shaping 或纹波抵消点附近的 phase management，但不应被当作主要 DC current-sharing 执行量。`Ton_diff` 则直接改变每相平均伏秒，因此是强均流执行量；它的代价是后续 IQCOT wait 时间被迫补偿，造成相位间隔扰动。

## 8. 结果三：DCR 失配网格给出受限均流设计曲线

对 DCR 失配，若各相 Ton 相同，平均相电流满足近似 DC 关系

```math
I_j=\frac{D V_{in}-V_o}{R_j},\qquad \sum_j I_j=I_{out}.
```

若使用 zero-mean Ton trim 补偿 DCR 差异，则解析补偿为

```math
\delta T_{on,j}=\frac{T_s I_{ref}(R_j-\bar{R})}{V_{in}}.
```

但工程上 Ton trim 有分辨率和范围限制，也会消耗 phase-spacing margin。因此本文新增 140 个 DCR 失配设计点，覆盖 monotonic、alternating、one-phase-high 和 one-phase-low 四类模式，以及 5% 到 25% 失配幅值。该网格用于设计扫描：电流不均由 DC algebra 计算，相位代价由名义四相 IQCOT 事件模型估计；它不是每个网格点都运行完整失配闭环。旧稿中的 selected mismatched dynamic validation 已对强单调、交替和单相失配等代表性工况验证过通道结论。结果形成一条清晰的收益-代价曲线：更大的 Ton trim 可以显著降低电流不均，但相位等待时间 pk-pk 代价快速增加。

![Figure 9. DCR mismatch grid](E:/Desktop/codex/output/figures/fig9_mismatch_grid.png)

该结果的实际价值是把均流从“尽量调平”改写为受限优化问题：

```math
\min_{\Delta T_{on},\Delta\Lambda}
w_I\|\Delta I_{diff}\|^2+w_\phi\|\Delta\phi\|^2+w_v\|\Delta v_o\|^2
```

subject to

```math
|\Delta T_{on,i}|\leq T_{trim,max},
\qquad
|\Delta\phi_i|\leq \phi_{margin}.
```

这也解释了为什么未来若加入 AI/优化算法，不应让模型黑箱调全部参数，而应把动作限制在 IEK 执行量矩阵给出的物理通道中。

## 9. 结果四：数字面积阈值、检测时钟与 Ton 分辨率预算

数字实现中，面积阈值量化、检测时钟和 Ton 分辨率都会造成事件 jitter。设面积阈值量化步长为 `q_Λ`，白噪声近似下

```math
\sigma_\Lambda^2=\frac{q_\Lambda^2}{12}.
```

由 IEK 传函得到

```math
\sigma_T^2\approx \|G_{T\Lambda}\|_2^2\frac{q_\Lambda^2}{12}.
```

若检测时钟为 `T_clk`，则单事件检测延迟量化约为

```math
\sigma_d=\frac{T_{clk}}{\sqrt{12}},
```

相邻相位间隔可近似按两个独立检测误差之差估算。对于 Ton 分辨率 `q_T`，m2 差模均流量化尺度可由 `G_{IT}` 估算。

本文采用 `2Λ` 作为面积阈值 full-scale 的保守预算假设。12 bit 面积阈值对应 `q_Λ/Λ≈0.000488`，估计 common wait jitter 为 0.0324 ns rms，m2 phase-spacing jitter 为 0.1183 ns。相比之下，1 ns 检测时钟的单事件延迟 rms 为 0.2887 ns，10 ps Ton 分辨率对应 m2 电流量化尺度约 22.09 mA，phase-spacing 尺度约 2.443 ns。综合 12 bit、1 ns 检测时钟和 10 ps Ton 分辨率时，估计 common wait jitter 为 0.2905 ns rms，phase-spacing jitter 为 2.4801 ns rms，均流量化尺度为 22.09 mA。

![Figure 10. Digital jitter budget](E:/Desktop/codex/output/figures/fig10_jitter_budget.png)

这部分不是硬件测量，而是设计预算。它的价值在于把“面积位宽要多少、检测时钟要多快、Ton 分辨率要多细”连接到同一个 IEK 灵敏度框架中。

## 10. 结果五：Simulink 模态交叉验证

为了回应“解析事件脚本是否过于同源验证”的质疑，本文进一步使用已有四相 Simulink/Simscape 模型进行交叉验证。实验不保存或修改 `.slx` 文件，而是通过 `SimulationInput.setBlockParameter` 在仿真时临时钳位四相 `IQCOT_Ton_Adapter/Ton_Limit1..4`，从而注入指定的 common-mode 与 differential-mode on-time 扰动。主扫描包含 14 个场景，仿真窗口为 `0.65 ms`，稳态统计窗口为最后 `50 μs`，最大步长为 `5 ns`，软启动时间临时设为 `0.18 ms` 以加快稳定。考虑到 sub-ns 扰动可能受到数值事件分辨率影响，本文又对 baseline、common ±4 ns、m2 1/2/4 ns、m13 和 m24 对照共 8 个关键点用 `MaxStep=2 ns` 复核；关键数值与主扫描一致。

基线结果为：`Vout_mean=1.000015530 V`，`Vout_ripple=0.735095 mVpp`，四相平均电流为 `[9.978771, 9.993619, 10.058002, 9.980875] A`，相电流不均衡为 `0.079230 A`，平均相频率为 `499.579 kHz`。所有 14 个场景的相位触发顺序错误率均为 0，说明临时 on-time 钳位没有破坏四相轮转调度。

Common-mode on-time 扰动主要被闭环 COT 转化为等效频率调整。以基线为参照，`Ton=Ton_cmd-4 ns` 时平均相频率升至 `510.683 kHz`，`Ton=Ton_cmd+4 ns` 时降至 `489.360 kHz`；在 `[-4 ns,+4 ns]` 范围内，频率斜率约为 `-2.76 kHz/ns`。由于输出电压仍由闭环滞环调节，`Vout_mean` 变化维持在几十微伏量级，这与 common-mode 主要调节总事件频率而不直接造成差模均流的解释一致。

m2 差模 on-time 扰动则强烈放大相电流差模，而输出均值仍基本保持在 1 V 附近。`[+1,-1,+1,-1] ns` 时相电流不均衡为 `0.950 A`，m2 电流投影为 `0.464 A`；`[+2,-2,+2,-2] ns` 时相电流不均衡为 `2.017 A`，m2 投影为 `0.997 A`；`[+4,-4,+4,-4] ns` 时相电流不均衡为 `3.928 A`，m2 投影为 `1.943 A`。对 `1 ns`、`2 ns`、`4 ns` 三点进行过原点斜率估计，m2 电流投影约为 `0.482 A/ns`。这与解析 IEK 执行量矩阵在数值大小上不应直接相等，因为两者模型参数、控制器实现和扰动定义不同；但它在物理方向上独立支持了同一结论：`Ton_diff` 是有效 DC current-sharing 执行量。

成对差模对照进一步验证了模态解释。`[+2,0,-2,0] ns` 主要激发相 1-3 电流差，其相 1-3 投影达到 `1.024 A`；`[0,+2,0,-2] ns` 主要激发相 2-4 电流差，其相 2-4 投影达到 `0.967 A`。这说明“哪个差模 pattern 被注入，哪个电流差模被激发”的对应关系在真实 Simulink 电路级模型中仍然成立。

![Figure 11. Simulink modal cross-validation](E:/Desktop/codex/output/figures/fig11_simulink_modal_cross_validation.png)

![Figure 12. Simulink high-resolution modal cross-validation](E:/Desktop/codex/output/figures/fig12_simulink_modal_cross_validation_highres.png)

需要强调的是，该 Simulink 模型验证的是“差模 on-time 均流通道”和“模态执行量分类”的物理合理性，而不是完整 `Λ` 面积阈值事件核。当前模型中的 IQCOT 是每相电流误差泄放积分后修正 on-time；若要验证 `Λ_diff`、`Λ_cm` 与动态事件核 `K(z)`，下一步应在该模型中加入输出误差面积积分触发器，或搭建等效数字 IEK 控制子系统。

## 11. 实际价值与相对优势

与 He-only 局部面积刚度相比，IEK 的优势不是公式更复杂，而是保留了 off-time 面积积分区间内的状态记忆。密集扫频显示，He-only 在某些频点可接近真实响应，但在另一些频点误差非常大；因此它适合做局部直觉，不适合作为数字 jitter 预算的唯一依据。

与一般 COT sampled-data 模型相比，本文的优势是面向 IQCOT 面积事件和四相数字执行量分类。传统模型更擅长回答控制到输出传函、环路增益和稳定性问题；本文更擅长回答数字实现中具体的“哪个旋钮影响哪个物理量”：`Λ_cm` 影响共模调节和总周期 jitter，`Λ_diff` 影响相位间隔，`Ton_diff` 影响平均相电流但消耗相位裕量，检测延迟差模主要是时序 jitter 源。

与 DICOT 高分辨率均流方案相比，本文不提出新的硬件均流电路，而是给出约束设计依据。也就是说，已有 DICOT 证明“可以做”，本文试图回答“为什么某些执行量不能混用、怎样设定均流收益与 phase-spacing cost 的边界”。这对研究生毕设尤其重要，因为它既有理论推导，也能落到脚本、表格和设计规则。

## 12. 局限性与后续工作

本文仍有明确局限。第一，四相 IEK 脚本采用理想开关与解析分段功率级，尚未纳入完整 MOSFET 非线性、驱动死区、PCB 寄生和采样保持。第二，新增 Simulink 交叉验证虽然使用了更接近电路级的四相 COT-IQCOT 模型，但该模型目前不含本文严格定义的输出误差面积阈值 `Λ` 触发器，因此只能验证 `Ton_diff` 均流通道与模态执行量解释，不能直接证明完整 IEK 面积核。第三，本文聚焦四相固定工作点，没有展开任意 N 相推广；这是根据当前课题聚焦作出的选择。第四，当前解析工作点 duty 约为 0.085，处于 `D<1/N` 的非 phase-overlap 区域，不能直接外推到 `D>1/N` 的重叠相区。第五，数字 jitter 预算是基于小信号灵敏度的估算，不等同于 FPGA/ASIC 或实物样机测量。第六，外环补偿器尚未完整纳入 IEK 状态空间；当前慢速 VC 适配主要用于隔离共模调压与差模均流。第七，phase-overlap 区域的稳定边界还没有严格推导，未来可将 `S_eff(z)=H_e+K(z)` 与 Sridhar/Li 的 critical ramp 条件联系起来。

后续工作建议按三个层级推进：首先在 Simulink/Simscape 或 PLECS 中实现严格面积积分 IQCOT 控制器，验证本文事件脚本结论；其次加入外环 PI/Type-III 状态和采样保持，形成完整闭环 sampled-data 模型；最后把 IEK 执行量矩阵作为约束，让 AI 或优化算法只在物理可解释的参数空间中调节 `Λ_cm`、`Λ_diff` 和 `Ton_diff`。

## 13. 结论

本文面向四相数字 IQCOT Buck 变换器，提出积分事件核小信号建模与受限均流执行量设计框架。通过移动边界线性化，IEK 将面积阈值、检测延迟、数字量化和功率级状态记忆统一到 `H_e+K(z)` 的动态面积刚度中。四相密集验证表明，He-only 模型在频率选择性事件记忆存在时会严重失效；执行量矩阵表明，`Λ_diff` 主要调节 phase spacing，`Ton_diff` 才是主要 DC current-sharing 执行量；DCR 失配网格和数字 jitter 预算进一步把均流收益、相位代价、面积位宽、检测时钟和 Ton 分辨率连接为可复现的设计规则。新增 Simulink 交叉验证在不同参数、不同实现层级的四相 COT-IQCOT 模型中复现了 `Ton_diff` 差模均流通道，增强了本文模态执行量分类的外部证据。本文的创新不在于重新提出 IQCOT，而在于为四相数字 IQCOT 的小信号执行量分类和工程约束设计提供了更严谨的模型化证据链。

## 数据与代码可用性

本文所有脚本、CSV 和图表位于 `E:/Desktop/codex/output`。核心新增文件包括：

```text
iqcot_four_phase_dense_validation.py
iqcot_digital_jitter_budget.py
iqcot_generate_paper_figures_v2.py
iqcot_export_article_v2.py
iqcot_simulink_modal_cross_validation.m
iqcot_four_phase_dense_common_sweep.csv
iqcot_four_phase_actuator_matrix.csv
iqcot_four_phase_mismatch_grid.csv
iqcot_digital_combined_jitter_budget.csv
iqcot_simulink_modal_cross_validation_summary.csv
iqcot_simulink_modal_cross_validation_highres_summary.csv
iqcot_simulink_modal_cross_validation_report.md
iqcot_simulink_modal_cross_validation_highres_report.md
```

## AI 使用声明

本文写作、代码整理、图表生成和审稿式自查过程中使用了 AI 辅助。AI 参与包括文献边界梳理、公式组织、仿真脚本编写和语言润色；所有数值结果均由本地脚本生成，所有学术结论需由作者进一步结合原始文献、仿真模型和导师意见复核。AI 辅助不替代作者对研究诚信和技术正确性的责任。

## 参考文献

[1] S. M. K. Bari, *A Novel Inverse Charge Constant On-Time Control for High Performance Voltage Regulators*, Ph.D. dissertation, Virginia Tech, 2018.

[2] S. M. K. Bari, Q. Li, and F. C. Lee, “High Frequency Small Signal Model for Inverse Charge Constant On-Time (IQCOT) Control,” in *2018 IEEE Energy Conversion Congress and Exposition (ECCE)*, 2018, pp. 6000-6007, doi: 10.1109/ECCE.2018.8557464.

[3] S. M. K. Bari, Q. Li, and F. C. Lee, “Inverse Charge Constant-On-Time Control With Ultrafast Transient Performance,” *IEEE Journal of Emerging and Selected Topics in Power Electronics*, vol. 9, no. 1, pp. 68-78, 2021, doi: 10.1109/JESTPE.2020.2973151.

[4] N. Yan, X. Ruan, and X. Li, “A general approach to sampled-data modeling for ripple-based control-Part I: Peak/valley current mode and peak/valley voltage mode,” *IEEE Transactions on Power Electronics*, vol. 37, no. 6, pp. 6371-6384, 2022, doi: 10.1109/TPEL.2021.3132619.

[5] F. Gabriele et al., “A Unified Sampled-Data Small-Signal Model for a Ripple-Based COT Buck Converter With Arbitrary Ripple Injection Network,” *IEEE Transactions on Circuits and Systems I: Regular Papers*, vol. 72, no. 6, pp. 2942-2955, 2025, doi: 10.1109/TCSI.2025.3557278.

[6] Y. Li et al., “Multiphase digital integration constant on-time-controlled Buck converter with high-resolution current balance scheme for ultrafast load transient,” *International Journal of Circuit Theory and Applications*, vol. 52, no. 7, pp. 3188-3212, 2024, doi: 10.1002/cta.3924.

[7] S. Sridhar and Q. Li, “Multiphase constant on-time control with phase overlapping-Part I: Small-signal model,” *IEEE Transactions on Power Electronics*, vol. 39, no. 6, pp. 6703-6720, 2024, doi: 10.1109/TPEL.2024.3368343.

[8] S. Sridhar and Q. Li, “Multiphase constant on-time control with phase overlapping-Part II: Stability analysis,” *IEEE Transactions on Power Electronics*, vol. 39, no. 3, pp. 3156-3174, 2024, doi: 10.1109/TPEL.2023.3345275.

[9] W.-C. Liu, C.-H. Cheng, P. P. Mercier, and C. C. Mi, “Small-Signal Analysis and Design of Constant On-Time Controlled Buck Converters With Duty-Cycle-Independent Quality Factors,” *IEEE Transactions on Power Electronics*, vol. 38, no. 7, pp. 8379-8393, 2023, doi: 10.1109/TPEL.2023.3268613.

## 附录 A：核心论断与证据矩阵

| 论断 | 证据 | 状态 |
|---|---|---|
| IEK 必须包含动态事件核 `K(z)`，He-only 是退化近似 | 单相动态 IEK 验证误差 <0.00018%；四相密集扫频中 He-only 最坏误差 7969.65% | 已由本地脚本支持 |
| `Λ_diff` 不是主要 DC 均流执行量 | m2 模式下 `G_IΛ≈0.00996 mA/(1e-13)` | 已由执行量矩阵支持 |
| `Ton_diff` 是强均流执行量，但相位代价大 | m2 模式下 `G_IT≈765.07 mA/(0.1 ns)`，`G_φT≈84.64 ns/(0.1 ns)` | 已由执行量矩阵支持 |
| `Ton_diff` 均流通道在电路级四相模型中仍可观察 | Simulink 14 点交叉验证中 m2 电流投影斜率约 0.482 A/ns，`[+4,-4,+4,-4] ns` 引起 3.928 A 相电流不均衡 | 已由 Simulink 交叉验证支持 |
| Simulink 关键结论不是 5 ns 步长伪影 | 8 点精选复核使用 `MaxStep=2 ns`，baseline、common ±4 ns、m2 1/2/4 ns 与主扫描关键值一致 | 已由高分辨率复核支持 |
| 检测延迟差模主要是时序扰动 | m2 模式下 `G_φd≈0.3088 ns/(0.1 ns)`，电流增益很小 | 已由执行量矩阵支持 |
| 数字实现可用 IEK 灵敏度做预算 | 12 bit、1 ns 时钟、10 ps Ton 示例预算给出 wait/phase/current 量化尺度 | 设计估算，需硬件验证 |
| 当前 Simulink 验证尚未覆盖完整 `Λ` 面积事件核 | 用户模型中的 IQCOT 为电流误差泄放积分调 `Ton_iqcot`，不是输出误差面积阈值触发 | 已明确为局限 |

## 附录 B：图表追踪

| 图号 | 文件 | 支持内容 |
|---|---|---|
| Fig. 1 | `fig1_iek_event_kernel.svg` | IEK 概念与动态核 |
| Fig. 3 | `fig3_multiphase_modal_channels.svg` | common/differential 执行量分类 |
| Fig. 7 | `fig7_dense_common_sweep.png` | 四相 common-mode 密集扫频 |
| Fig. 8 | `fig8_actuator_matrix.png` | `Λ_diff`、`Ton_diff`、`delay_diff` 执行量矩阵 |
| Fig. 9 | `fig9_mismatch_grid.png` | DCR 失配均流收益与相位代价 |
| Fig. 10 | `fig10_jitter_budget.png` | 面积位宽、检测时钟、Ton 分辨率预算 |
| Fig. 11 | `fig11_simulink_modal_cross_validation.png` | Simulink 四相 COT-IQCOT 模态交叉验证 |
| Fig. 12 | `fig12_simulink_modal_cross_validation_highres.png` | Simulink 关键点 2 ns 高分辨率复核 |
