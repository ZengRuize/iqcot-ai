# 四相数字 IQCOT Buck 变换器的积分事件核与相索引盐跃小信号建模、受限均流执行量设计及仿真验证

## 摘要

四相交错 Buck 变换器是低压大电流 VRM 的典型结构，COT 与 IQCOT 控制因快速瞬态和紧凑实现而具有吸引力。已有研究已经提出 IQCOT 控制律及其高频小信号模型，也已经建立 ripple-based COT sampled-data 模型、多相 COT phase-overlap 模型和多相数字积分 COT 均流方案。本文不声称首次提出 IQCOT、COT sampled-data 建模或多相数字均流，而是针对四相数字 IQCOT 中更具体的工程问题：面积阈值、检测延迟、数字量化、相位间隔和 Ton-trim 均流执行量究竟通过哪些小信号通道影响系统。

本文提出积分事件核（Integral-Event Kernel, IEK）建模框架，从 IQCOT 面积事件

```math
\int_{a_k}^{t_{k+1}} [v_c(t)-R_i i_{L}(t)]dt=\Lambda
```

出发，用移动边界线性化保留 off-time 积分区间内的功率级状态记忆，并将四相事件扰动分解为 common-mode 与 differential-mode。已有单相验证显示，动态 IEK 对周期响应的最大幅值误差低于 0.00018%，而 He-only 局部面积刚度模型最大误差可达 771.62%。本文新增四相密集验证：在 24 个 common-mode 频点中，He-only 模型最坏相对幅值误差达到 7969.65%，但在 `ω/π=0.2` 附近误差仅为 -0.66%。执行量矩阵进一步表明，m2 差模下 Lambda_diff 的电流增益约为 0.0100 mA/(1e-13)，Ton_diff 的电流增益约为 765.07 mA/(0.1 ns)，二者相差约五个数量级；检测延迟差模主要表现为相位时序扰动。本文进一步使用用户已有四相 Simulink/Simscape COT-IQCOT 模型进行 14 点 on-time 交叉验证，m2 `Ton` 差模的电流投影斜率约为 0.482 A/ns。为补足面积阈值通道证据，本文先在模型副本中把瞬时 Relay 请求替换为面积积分请求 `REQ = ∫max(e_v,0)dt >= Λ_area + Λ_m2 cos(π phase_idx)`，证明 `Λ_cm` 可闭环、`Λ_m2` 主要扰动 phase-spacing。进一步，本文构建逐相 IEK 副本，采用 `h_i=Varea_bias+e_v+Ri_area(Iph-IL_i)`，按 `phase_idx` 选择对应相面积比较结果生成 `REQ`。在 25 点扫描中，候选点 `Λ_area=6e-10 V·s`、`Varea_bias=2 mV`、`Ri_area=0.5 mΩ` 得到 `Vout_mean=0.999548 V`、`Vout_ripple=0.785960 mVpp`、平均相频率 `502.097 kHz`、相电流不均衡 `0.02390 A`；`Λ_m2/Λ_area=0.4` 时 m2 电流投影仅 `0.00116 A`。新增 20/30/40/50 A 静态负载扫点显示，逐相 IEK 副本在该范围内输出均值误差约小于 1 mV，且 `Λ_m2/Λ_area=0.4` 的跨负载最大 m2 电流投影仅约 9.4 mA。v6 进一步提出相索引盐跃 IEK（PIS-IEK），把四相面积事件、phase scheduler、积分 reset 和 `Λ_i/Ton_i` 执行量统一为周期 event-to-event Jacobian，并完成 32 行局部灵敏度、10 行模态投影、77 个幅值扫描工况和 80 个四事件提升频响工况。结果显示，`Λ` 全范围幅值扫描最大 rms wait 误差仅 `0.05025%`，`Ton<=0.02 ns` 时最大 rms wait 误差为 `1.83345%`，四事件提升频响中可观测工况 wait 幅值误差低于 `0.004%`。这些结果共同支持本文关键判断：Lambda_diff 更适合 phase-spacing/ripple-cancellation 调节，Ton_diff 才是主要 DC current-sharing 执行量。

**关键词**：IQCOT；COT；四相 Buck；小信号模型；sampled-data；积分事件核；均流；phase-spacing jitter；数字量化

## Abstract

Four-phase interleaved buck converters are widely used in low-voltage high-current VRMs. COT and IQCOT control are attractive for fast transient response and compact implementation. This paper does not claim to invent IQCOT, COT sampled-data modeling, or multiphase digital current balancing. Instead, it develops a focused integral-event kernel (IEK) framework for four-phase digital IQCOT converters, separating area-threshold, detection-delay, phase-spacing, and Ton-trim current-sharing channels. Starting from the IQCOT area event, the model linearizes the moving event boundary and retains the state memory accumulated during the off-time integration interval. Dense four-phase validation shows that a local He-only stiffness approximation can be accurate at some frequencies but can fail severely at others, with a worst-case amplitude error of 7969.65% in the studied operating point. The actuator matrix shows that differential area threshold is primarily a phase-spacing actuator, whereas differential on-time trim is the dominant DC current-sharing actuator. A digital jitter budget maps area-threshold bit width, detection clock, and Ton resolution into event jitter, phase-spacing jitter, and current-sharing quantization. A separate 14-case Simulink/Simscape cross-validation confirms the modal interpretation of differential on-time trim. Two copied Simulink models then replace the hysteretic Relay request by area-integral requests. The first copy validates common area triggering, and the second copy introduces a per-phase current term, h_i = Varea_bias + e_v + Ri_area(Iph-IL_i). Both copies regulate near 500 kHz per phase and show that differential area threshold has little DC current-sharing authority compared with differential on-time trim. The resulting framework provides a reproducible small-signal basis for constrained tuning of four-phase digital IQCOT buck converters.

## 1. 引言

处理器和 AI 加速器供电要求 VRM 在低电压、大电流、快速负载阶跃和高电流密度之间取得平衡。多相交错 Buck 通过相位错开降低输入与输出纹波，并通过相电流分担降低热应力，是 VRM 中最常见的拓扑之一。COT 控制由于不依赖固定周期调制器、瞬态响应快、轻载模式自然，长期被用于低压大电流电源。IQCOT 将 COT 的触发条件从瞬时纹波比较扩展为面积积分事件，在多相纹波抵消点附近仍能保持有效检测量，因此适合高性能 VRM。

然而，在数字四相 IQCOT 实现中，设计者面对的并不是一个单一参数。面积阈值 `Λ`、积分电流系数 `Ri`、检测延迟、阈值量化、phase manager、Ton-trim 和 DCR 失配都会改变事件时刻；这些变化又同时影响输出调节、相位间隔和相电流均衡。如果把所有参数都当成“能调频率/能调电流”的经验旋钮，容易出现两个误判：一是用 Lambda_diff 试图做 DC 均流，二是为了追求 Ton 均流而破坏相位间隔。

本文的核心问题是：**四相数字 IQCOT 的面积事件能否被写成一个可用于执行量分类和数字预算的小信号模型？** 本文给出的答案是肯定的，但边界必须清楚。已有工作已经覆盖 IQCOT 控制律、高频小信号模型、RBCOT sampled-data 模型、多相 COT phase-overlap 以及多相 DICOT 均流。本文的增量不在“首次提出控制律”，而在四相数字实现层面提出 IEK 模态化分析，用同一框架解释 `Λ_cm`、`Λ_diff`、检测延迟差模和 `Ton_diff` 的不同物理通道。

## 2. 相关工作与创新边界

Bari 的博士论文和后续 ECCE/JESTPE 论文已经提出 IQCOT 控制思想，并给出 IQCOT 高频小信号模型与 ultrafast transient 结果。因此，本文不把 IQCOT 控制律本身作为创新点。Yan、Ruan、Li 以及 Gabriele 等已经系统发展了 ripple-based COT sampled-data 模型，能处理事件调制、边带效应和任意纹波注入网络；本文借鉴 sampled-data 思想，但事件函数是 IQCOT 的面积积分条件，而不是一般纹波比较器的瞬时阈值交叉。

多相方面，Li 等关于 DICOT 和 high-resolution current balance 的工作已经说明数字积分 COT 与高分辨率均流在工程上可行；Sridhar 和 Li 关于 multiphase COT phase-overlap 的研究也已经指出多相 COT 不能简单由单相模型外推。本文因此把创新边界收缩为一个更可辩护的问题：**在四相数字 IQCOT 中，面积事件核如何区分相位执行量和均流执行量，并如何给出数字 jitter/量化预算。**

为避免把已有工作重新包装成创新，表 1 给出本文与代表性文献的边界：

| 工作 | 已解决的问题 | 本文不重复声称的内容 | 本文新增关注点 |
|---|---|---|---|
| Bari IQCOT | IQCOT 控制律、高频小信号模型、快速瞬态 | 不重新提出 IQCOT 控制思想 | 面向四相数字实现的事件核记忆与执行量分类 |
| Yan/Gabriele ripple-based sampled-data | 一般 ripple-based COT 的 sampled-data 建模与纹波注入网络 | 不声称 sampled-data 方法本身新 | 把面积积分事件写成 `H_e+K(z)`，识别 off-time 积分记忆 |
| Li DICOT 均流 | 数字积分 COT 与高分辨率均流工程方案 | 不提出新的硬件均流电路 | 给出 `Λ_diff` 与 `Ton_diff` 不能混用的约束依据 |
| Sridhar/Li 多相 COT | 多相 COT phase-overlap 小信号与稳定性 | 不展开任意相数或重叠相区完整理论 | 聚焦四相非重叠工作点的 common/differential 执行量矩阵 |

本文贡献概括为九点：

1. 从 IQCOT 面积事件出发，推导保留状态记忆的 IEK 小信号模型，说明 He-only 是忽略动态事件核 `K(z)` 的退化近似。
2. 在四相固定工作点下建立 common/differential 模态解释，将 `Λ_cm`、`Λ_diff`、检测延迟差模和 `Ton_diff` 分到不同执行通道。
3. 通过密集扫频、幅值线性、执行量矩阵和 DCR 失配网格，验证 `Λ_diff` 不是有效 DC 均流执行量，`Ton_diff` 才是主要均流执行量但有相位代价。
4. 基于 IEK 灵敏度建立数字面积阈值位宽、检测时钟和 Ton 分辨率的 jitter 预算方法。
5. 使用已有四相 Simulink/Simscape COT-IQCOT 模型进行不保存模型的交叉验证，证明 `Ton_diff` 均流通道在更接近电路级的模型中仍成立。
6. 在模型副本中实现面积积分 `REQ` 触发器，首次用用户四相 Simulink 模型直接验证 `Λ_cm` 可闭环调节、`Λ_m2` 主要影响 phase-spacing 而非 DC 均流。
7. 进一步实现逐相 IEK 面积核 `h_i=Varea_bias+e_v+Ri_area(Iph-IL_i)`，验证显式相电流项加入后 `Λ_m2` 仍不是强 DC 均流执行量。
8. 在 20--50 A 静态负载范围内复核逐相 IEK 副本，补充证明该结论不是 40 A 单点调参偶然性。
9. 提出相索引盐跃 IEK，将 `phase_idx`、积分 reset、事件边界移动和 `Λ_i/Ton_i` 执行量写成四相周期 Jacobian，并用 157 个结构化仿真工况验证其小信号适用范围。

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
E:/Desktop/codex/output/iqcot_build_iek_area_model.m
E:/Desktop/codex/output/iqcot_iek_area_model_validation.m
E:/Desktop/codex/output/iqcot_build_iek_perphase_model.m
E:/Desktop/codex/output/iqcot_iek_perphase_model_validation.m
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
| 面积触发 Simulink 副本验证 | 13 | `iqcot_iek_area_model_validation_summary.csv` |
| 逐相 IEK 面积核副本验证 | 25 | `iqcot_iek_perphase_model_validation_summary.csv` |
| 逐相 IEK 静态负载扫点 | 8 | `iqcot_iek_perphase_load_sweep_summary.csv` |
| PIS-IEK 局部灵敏度与模态投影 | 42 | `iqcot_pis_iek_sensitivity_matrix.csv`；`iqcot_pis_iek_modal_projection_matrix.csv` |
| PIS-IEK 幅值扫描与四事件提升频响 | 157 | `iqcot_pis_iek_amplitude_sweep.csv`；`iqcot_pis_iek_frequency_response.csv` |

Simulink 交叉验证使用的模型为 `E:/Desktop/4cot/versions/v0027_20260611_135822_iqcot_optimized_final_cn_docs/four_phase.slx`。该模型的事实源参数与解析 IEK 脚本不同：`Ton_cmd=196.5 ns`、`Tblank=480 ns`、`L=200 nH`、`DCR_L1..4=10 mΩ`、`Cout=7.26 mF`、`ESR_C=90 μΩ`，控制链为 `Vout -> Relay -> global blanking -> PhaseScheduler_4Phase -> COT cells -> gate drivers -> MOSFETs`。模型中的 IQCOT 路径是每相电流误差的泄放积分去调节 `Ton_iqcot_i`，不是本文完整的输出误差面积阈值 `Λ` 触发器。因此，本文把该模型用于验证差模 on-time 均流通道和模态执行量解释，而不把它作为完整 IEK 面积核的直接证明。

为了进一步验证面积阈值通道，本文在 `E:/Desktop/codex/output/simulink_iek/four_phase_iek_area.slx` 中建立了一个模型副本。副本保留功率级、global blanking、rise detector、`PhaseScheduler_4Phase`、COT cells 和 gate drivers，仅把 `Relay -> REQ` 替换为面积积分请求：

```math
REQ =
\left[
\int \max(e_v,0)dt
\geq
\Lambda_{area}+\Lambda_{m2}\cos(\pi \, phase\_idx)
\right].
```

为避免 `REQ -> tr -> phase_idx/reset -> REQ` 零延迟代数环，副本在面积子系统内对 `tr_reset` 和 `phase_idx` 加入 `Memory`，这相当于数字控制中的一拍寄存器。该副本是探索验证模型，不覆盖原始 `.slx`。

v5 进一步建立 `E:/Desktop/codex/output/simulink_iek/four_phase_iek_perphase.slx`。该副本把面积核改为逐相形式：

```math
h_i(t)=V_{area,bias}+e_v(t)+R_{i,area}(I_{ph}-i_{L,i}(t)).
```

这等价于在稳态偏置附近写 `v_c-R_i i_{L,i}` 的小信号实现，其中 `Varea_bias` 提供正平均面积，`R_{i,area}(I_{ph}-i_{L,i})` 显式引入逐相电感电流项。模型仍按 `phase_idx` 选择当前相的面积比较结果生成 `REQ`，并保留原始 global blanking 和 phase scheduler。

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

## 11. 结果六：面积触发 IEK-REQ 模型副本验证

在 v4 中，本文进一步构建 `four_phase_iek_area.slx`，将原始瞬时滞环 `Relay` 请求替换为面积积分请求。这个改动的意义在于，它把前文的 `Λ` 面积阈值从解析脚本推进到用户四相 Simulink 模型副本中，同时不改变原始模型。

`Λ_cm` 扫描首先验证面积触发器能否闭环工作。结果显示，在 `Λ_area=1e-12` 到 `3e-9 V·s` 范围内，模型均能保持四相轮转且相序错误率为 0。随着 `Λ_area` 增大，平均相频率从约 `502.8 kHz` 逐渐下降到 `498.7 kHz`，phase-spacing 标准差从 `34.5 ns` 降至 `1.31 ns`。这说明面积阈值不仅能替代 Relay 形成闭环请求，还能作为 common-mode 事件间隔整形参数。

综合输出精度、频率和相位间隔，本文选取 `Λ_area=3e-10 V·s` 作为候选点。该点得到：

| 指标 | 数值 |
|---|---:|
| `Vout_mean` | `0.999395652 V` |
| `Vout_ripple` | `0.650821 mVpp` |
| 平均相频率 | `501.707 kHz` |
| 相电流不均衡 | `0.068008 A` |
| phase-spacing 标准差 | `2.876 ns` |

随后在该候选点上扫描 `Λ_m2/Λ_area=0, 0.05, 0.10, 0.20, 0.40`。结果与解析执行量矩阵一致：`Λ_m2` 并不形成强 DC 均流通道。即使在最大扫描比值 0.40 下，m2 电流投影也只有 `0.00397 A`，相电流不均衡为 `0.07177 A`，与基线 `0.06801 A` 同量级。相反，phase-spacing 标准差从 `2.876 ns` 增加到约 `17.03 ns`。因此，在面积触发 Simulink 副本中，`Λ_m2` 的主要作用仍是事件间隔/相位扰动，而不是平均电流分配。

![Figure 13. IEK area-trigger Simulink validation](E:/Desktop/codex/output/figures/fig13_iek_area_simulink_validation.png)

这组结果把本文的创新证据链补得更完整：解析 IEK 说明 `Λ_diff` 的电流增益远小于 `Ton_diff`；on-time Simulink 交叉验证说明 `Ton_diff` 的确能强烈改变相电流；面积触发 Simulink 副本进一步说明 `Λ_cm` 可以闭环调节，而 `Λ_m2` 更像 phase-spacing 执行量。三者共同支持“受限均流执行量设计”的核心结论。

## 12. 结果七：逐相电流项 IEK 面积核验证

v4 面积触发副本已经把 `Λ` 通道放入 Simulink，但其积分量仍是工程化的 `∫max(e_v,0)dt`。v5 进一步加入逐相电感电流项，建立

```math
h_i=V_{area,bias}+e_v+R_{i,area}(I_{ph}-I_{L,i}).
```

其中 `R_{i,area}=0.5 mΩ`，`Varea_bias` 和 `Λ_area` 通过 20 点 common-mode 扫描选择。该模型保留原始功率级、global blanking、rise detector、phase scheduler 和 COT cells，仅替换请求生成器。

综合输出均值、频率、相电流不均衡和 phase-spacing 标准差，本文选择候选点：

| 参数/指标 | 数值 |
|---|---:|
| `Λ_area` | `6e-10 V·s` |
| `Varea_bias` | `2.0 mV` |
| `R_i,area` | `0.5 mΩ` |
| `Vout_mean` | `0.999548295 V` |
| `Vout_ripple` | `0.785960 mVpp` |
| 平均相频率 | `502.097 kHz` |
| 相电流不均衡 | `0.023902 A` |
| phase-spacing 标准差 | `21.113 ns` |

随后在该候选点上扫描 `Λ_m2/Λ_area=0, 0.05, 0.10, 0.20, 0.40`。结果显示，即使显式引入逐相电流项，`Λ_m2` 仍不表现为强 DC 均流执行量。最大比值 0.40 时，相电流不均衡为 `0.039699 A`，m2 电流投影仅 `0.001163 A`；作为对照，`Ton_diff` 的 Simulink on-time 扫描在 `[+4,-4,+4,-4] ns` 下产生约 `1.943 A` 的 m2 电流投影。二者相差三个数量级以上。

![Figure 14. Per-phase IEK area-kernel Simulink validation](E:/Desktop/codex/output/figures/fig14_iek_perphase_simulink_validation.png)

该结果非常适合写入毕业论文的创新章节：它说明本文不是只用解析脚本声称 `Λ_diff` 不能均流，而是在用户四相 Simulink 模型副本中逐步实现了两级面积触发器，并在更接近 IQCOT 小信号形式的逐相电流面积核中复现了相同方向的结论。其工程解释是：`Λ_m2` 改变的是“何时允许下一次事件发生”的相位/间隔条件；要改变相平均伏秒和 DC 均流，仍需 `Ton_diff` 或等效 per-phase volt-second 执行量。

## 13. 结果八：逐相 IEK 静态负载扫点验证

审稿式自查指出，单一 40 A 工作点仍可能被质疑为“只在一个调好的点成立”。因此本文新增 `iqcot_iek_perphase_load_sweep.m`，在不保存模型的前提下，通过 `SimulationInput` 同步设置 `Rload`、`Iout` 和 `Iph`，对 20/30/40/50 A 四个负载点进行静态扫点，并比较 `Λ_m2/Λ_area=0` 与 `0.4` 两种情况。面积核参数保持为上一节候选点：`Λ_area=6e-10 V·s`、`Varea_bias=2 mV`、`Ri_area=0.5 mΩ`。

8 个工况全部成功。baseline `Λ_m2=0` 下，20--50 A 范围内输出均值误差约在 `-0.43 mV` 到 `-0.62 mV`，最大相电流不均衡为 `0.13064 A`。加入最大差模面积扰动 `Λ_m2/Λ_area=0.4` 后，输出均值误差仍约小于 `1 mV`，跨负载最大 m2 电流投影仅 `0.00938 A`，最大相电流不均衡为 `0.10179 A`。这说明逐相 IEK 副本的核心判断不是 40 A 单点偶然：在 20--50 A 静态负载范围内，`Λ_m2` 仍没有表现为强 DC 均流执行量。

![Figure 15. Per-phase IEK static load sweep](E:/Desktop/codex/output/figures/fig15_iek_perphase_load_sweep.png)

该结果还给出一个更谨慎的工程解释：`Λ_m2` 可以改变相位间隔统计量，且低负载时 phase-spacing std 更敏感；但在本文工作点和模型结构下，它并不会像 `Ton_diff` 一样产生安培级的 DC 均流作用。因此，毕业论文中可以把 `Λ_diff` 定位为“相位/纹波调节受限执行量”，而不是“均流主执行量”。

## 14. 结果九：PIS-IEK 相索引盐跃小信号模型

v5 的 IEK 已经把 IQCOT 面积事件写成 `H_e+K(z)`，但 `K(z)` 仍是等效动态核。为进一步解释 `phase_idx`、积分 reset 和相序调度在小信号模型中的位置，本文提出相索引盐跃 IEK（PIS-IEK）。第 `k` 个事件中，当前 on-time 相为

```math
p_k=k\bmod 4,
```

下一触发相为

```math
q_k=(p_k+1)\bmod 4.
```

一次事件写成

```math
x_{k+1}=F_{p_k}(x_k,u_k,T_k),\qquad g_{q_k}(x_k,u_k,T_k)=0.
```

其中事件面为

```math
g_{q_k}=\int_0^{T_k}\left[v_c(t)-R_i i_{L,q_k}(t)\right]dt-\Lambda_{q_k}.
```

隐函数线性化给出

```math
\delta T_k=-g_T^{-1}(g_x\delta x_k+g_u\delta u_k),
```

代回状态更新后得到盐跃校正的周期小信号映射：

```math
\delta x_{k+1}
=
\left(F_x-F_Tg_T^{-1}g_x\right)\delta x_k
+
\left(F_u-F_Tg_T^{-1}g_u\right)\delta u_k.
```

该模型的创新不在于重新发明 saltation matrix，而在于把混杂系统事件面线性化具体用于四相数字 IQCOT 面积积分事件，使 `phase_idx` 从工程实现变量变成事件面索引 `g_{q_k}`，并使积分 reset 成为 `F_{p_k}` 的一部分。

结构化验证由 `iqcot_pis_iek_comprehensive_validation.py` 生成。局部灵敏度矩阵包含 32 行，模态投影矩阵包含 10 行，幅值扫描包含 77 个工况，四事件提升频响包含 80 个工况。局部结果表明，当前 wait 只直接受下一触发相 `Λ_q` 和当前 on-time 相 `Ton_p` 影响：

| 指标 | 数值 |
|---|---:|
| `dT/dΛ_q` | `0.0428305 ns/(1e-13 V·s)` |
| 非目标相 `Λ` 串扰 | `0` |
| `dT/dTon_p` | `-0.357596 ns/ns` |
| 非当前相 `Ton` 串扰 | `0` |

幅值扫描进一步给出小信号适用边界：

| 扫描集合 | 工况数 | 最大 rms wait 误差 | 平均 rms wait 误差 | 最大相电流误差 |
|---|---:|---:|---:|---:|
| `Λ` 全范围 | 35 | `0.05025%` | `0.01189%` | `0.00914 mA` |
| `Ton <= 0.02 ns` | 16 | `1.83345%` | `0.51047%` | `1.28022 mA` |
| `Ton <= 0.05 ns` | 20 | `4.57963%` | `0.95984%` | `8.13116 mA` |
| Mixed 全范围 | 18 | `1.71860%` | `0.75130%` | `1.30087 mA` |

频率响应采用四事件提升块域，而不是逐事件直接拟合，原因是四相空间模态会与时间频率发生混叠。可观测 wait 幅值工况统计如下：

| 输入类型 | 可观测工况数 | 最大 wait 幅值误差 | 最大 wait 绝对误差 | 最大 wait rms 误差 |
|---|---:|---:|---:|---:|
| `Λ` | 40 | `0.000138%` | `2.60e-08 ns` | `0.00427%` |
| `Ton` | 30 | `0.003712%` | `9.64e-05 ns` | `0.01056%` |
| Mixed | 10 | `0.003874%` | `1.16e-05 ns` | `0.24971%` |

![Figure 16. PIS-IEK amplitude sweep](E:/Desktop/codex/output/figures/fig16_pis_iek_amplitude_error.svg)

![Figure 17. PIS-IEK lifted frequency response](E:/Desktop/codex/output/figures/fig17_pis_iek_lifted_frequency_response.svg)

PIS-IEK 的实际价值是把 `phase_idx/reset` 从实现描述提升为小信号模型结构，并为后续 AI/优化调参提供更严格的物理约束：`B_\Lambda^s`、`B_{Ton}^s` 和 `C^s` 可以直接限制搜索方向，避免把 `Λ_diff` 当作 DC 均流主旋钮。

## 15. 实际价值与相对优势

与 He-only 局部面积刚度相比，IEK 的优势不是公式更复杂，而是保留了 off-time 面积积分区间内的状态记忆。密集扫频显示，He-only 在某些频点可接近真实响应，但在另一些频点误差非常大；因此它适合做局部直觉，不适合作为数字 jitter 预算的唯一依据。

与一般 COT sampled-data 模型相比，本文的优势是面向 IQCOT 面积事件和四相数字执行量分类。传统模型更擅长回答控制到输出传函、环路增益和稳定性问题；本文更擅长回答数字实现中具体的“哪个旋钮影响哪个物理量”：`Λ_cm` 影响共模调节和总周期 jitter，`Λ_diff` 影响相位间隔，`Ton_diff` 影响平均相电流但消耗相位裕量，检测延迟差模主要是时序 jitter 源。

与 DICOT 高分辨率均流方案相比，本文不提出新的硬件均流电路，而是给出约束设计依据。也就是说，已有 DICOT 证明“可以做”，本文试图回答“为什么某些执行量不能混用、怎样设定均流收益与 phase-spacing cost 的边界”。这对研究生毕设尤其重要，因为它既有理论推导，也能落到脚本、表格和设计规则。

由此可以形成一个四相数字 IQCOT 的参数设计流程：

| 步骤 | 输入 | IEK 输出 | 设计动作 |
|---|---|---|---|
| 1. 固定工作点 | `Vin, Vo, Iout, L, Cout, ESR, DCR, Ton, Tblank` | 名义事件周期、相位间隔、面积阈值尺度 | 先保证 `Λ_cm` 能闭环维持目标频率和输出均值 |
| 2. 识别面积通道 | `Λ_cm` 与 `Λ_diff` 微扰 | `G_wait,Λ`、`G_φ,Λ`、`G_I,Λ` | 将 `Λ_diff` 限制为 phase-spacing/ripple-cancellation 调节量 |
| 3. 识别均流通道 | `Ton_diff` 微扰与 DCR 失配模式 | `G_I,Ton` 与 phase-spacing 代价 | 用受限 `Ton_diff` 或等效逐相伏秒量补偿 DC current sharing |
| 4. 做数字预算 | ADC/DPWM 位宽、检测时钟、Ton 分辨率 | wait jitter、phase jitter、电流扰动估计 | 给 AI/优化器设置物理可解释边界和惩罚项 |
| 5. 仿真复核 | 原模型或副本中的代表性差模扰动 | 输出均值、纹波、相电流不均、phase-spacing | 只接受同时满足调压、均流和相位裕量的参数组合 |

## 16. 局限性与后续工作

本文仍有明确局限。第一，四相 IEK/PIS-IEK 脚本采用理想开关与解析分段功率级，尚未纳入完整 MOSFET 非线性、驱动死区、PCB 寄生和采样保持。第二，v5 逐相面积核已经显式引入 `R_i(Iph-I_Li)`，但仍是围绕稳态偏置的工程实现；严格 Bari IQCOT 原式中的 `v_c-R_i i_L` 还需要把控制电压产生器、逐相 off-time window 和 reset 逻辑进一步形式化。第三，PIS-IEK 已经把 `phase_idx` 写成事件面索引，但仍需要在 Simulink 副本中提取电路级小扰动 Jacobian 进行交叉验证。第四，本文聚焦四相固定工作点，没有展开任意 N 相推广；这是根据当前课题聚焦作出的选择。第五，当前解析工作点 duty 约为 0.085，处于 `D<1/N` 的非 phase-overlap 区域，不能直接外推到 `D>1/N` 的重叠相区。第六，数字 jitter 预算是基于小信号灵敏度的估算，不等同于 FPGA/ASIC 或实物样机测量。第七，外环补偿器尚未完整纳入 IEK 状态空间；当前慢速 VC 适配主要用于隔离共模调压与差模均流。第八，phase-overlap 区域的稳定边界还没有严格推导，未来可将 `S_eff(z)=H_e+K(z)` 或 PIS-IEK 提升映射与 Sridhar/Li 的 critical ramp 条件联系起来。

后续工作建议按三个层级推进：首先在 Simulink/Simscape 或 PLECS 中实现严格面积积分 IQCOT 控制器，验证本文事件脚本结论；其次加入外环 PI/Type-III 状态和采样保持，形成完整闭环 sampled-data 模型；最后把 IEK 执行量矩阵作为约束，让 AI 或优化算法只在物理可解释的参数空间中调节 `Λ_cm`、`Λ_diff` 和 `Ton_diff`。

## 17. 结论

本文面向四相数字 IQCOT Buck 变换器，提出积分事件核小信号建模、相索引盐跃 IEK 与受限均流执行量设计框架。通过移动边界线性化，IEK 将面积阈值、检测延迟、数字量化和功率级状态记忆统一到 `H_e+K(z)` 的动态面积刚度中；PIS-IEK 进一步把四相面积事件、phase scheduler、积分 reset 和 `Λ_i/Ton_i` 执行量统一到周期 event-to-event Jacobian 中。四相密集验证表明，He-only 模型在频率选择性事件记忆存在时会严重失效；执行量矩阵表明，`Λ_diff` 主要调节 phase spacing，`Ton_diff` 才是主要 DC current-sharing 执行量；DCR 失配网格和数字 jitter 预算进一步把均流收益、相位代价、面积位宽、检测时钟和 Ton 分辨率连接为可复现的设计规则。新增 on-time Simulink 交叉验证复现了 `Ton_diff` 差模均流通道；面积触发和逐相 IEK Simulink 副本进一步验证 `Λ_cm` 可作为闭环事件间隔参数，而 `Λ_m2` 即便显式加入逐相电流项，也几乎不产生 DC 均流。PIS-IEK 的 157 个幅值/频响工况进一步说明该结论不是单点经验，而是可由相索引事件面和周期 Jacobian 支撑的小信号结构。本文的创新不在于重新提出 IQCOT，而在于为四相数字 IQCOT 的小信号执行量分类和工程约束设计提供了更严谨的模型化证据链。

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
iqcot_build_iek_area_model.m
iqcot_iek_area_model_validation.m
iqcot_iek_area_model_validation_summary.csv
iqcot_iek_area_model_validation_report.md
simulink_iek/four_phase_iek_area.slx
iqcot_build_iek_perphase_model.m
iqcot_iek_perphase_model_validation.m
iqcot_iek_perphase_model_validation_summary.csv
iqcot_iek_perphase_model_validation_report.md
simulink_iek/four_phase_iek_perphase.slx
iqcot_iek_perphase_load_sweep.m
iqcot_iek_perphase_load_sweep_summary.csv
iqcot_iek_perphase_load_sweep_report.md
figures/fig15_iek_perphase_load_sweep.png
iqcot_phase_indexed_saltation_iek.py
iqcot_pis_iek_comprehensive_validation.py
iqcot_pis_iek_generate_figures.py
iqcot_pis_iek_sensitivity_matrix.csv
iqcot_pis_iek_modal_projection_matrix.csv
iqcot_pis_iek_amplitude_sweep.csv
iqcot_pis_iek_frequency_response.csv
iqcot_pis_iek_dataset_manifest.csv
iqcot_pis_iek_comprehensive_validation_report.md
iqcot_pis_iek_v6_research_note.md
figures/fig16_pis_iek_amplitude_error.svg
figures/fig17_pis_iek_lifted_frequency_response.svg
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
| `Λ_cm` 能在用户模型副本中形成面积触发闭环 | `four_phase_iek_area.slx` 在 `Λ_area=3e-10 V·s` 时得到 `Vout_mean=0.999396 V`、`Vout_ripple=0.650821 mVpp`、平均相频率 `501.707 kHz` | 已由面积触发 Simulink 副本支持 |
| `Λ_m2` 主要扰动 phase-spacing 而不是 DC 均流 | `Λ_m2/Λ_area=0.4` 时 m2 电流投影仅 `0.00397 A`，phase-spacing 标准差从 `2.876 ns` 增至约 `17.03 ns` | 已由面积触发 Simulink 副本支持 |
| 逐相 IEK 面积核能在用户模型副本中闭环 | `four_phase_iek_perphase.slx` 在 `Λ_area=6e-10 V·s`、`Varea_bias=2 mV`、`Ri_area=0.5 mΩ` 时得到 `Vout_mean=0.999548 V`、`Vout_ripple=0.785960 mVpp`、平均相频率 `502.097 kHz`、相电流不均衡 `0.023902 A` | 已由逐相 IEK Simulink 副本支持 |
| `Λ_m2` 在逐相 IEK 中仍不是强 DC 均流执行量 | `Λ_m2/Λ_area=0.4` 时 m2 电流投影仅 `0.001163 A`；同一模型体系中 `Ton_diff` 的 `[+4,-4,+4,-4] ns` 对照产生约 `1.943 A` m2 投影 | 已由逐相 IEK Simulink 副本与 on-time 交叉验证共同支持 |
| 逐相 IEK 结论不是 40 A 单点偶然 | 20/30/40/50 A 静态负载扫点全部成功，`Λ_m2/Λ_area=0.4` 跨负载最大 m2 电流投影仅 `0.00938 A` | 已由逐相 IEK 静态负载扫点支持 |
| `phase_idx/reset` 可进入严格小信号结构 | PIS-IEK 将事件写成 `x_{k+1}=F_{p_k}(x_k,u_k,T_k)` 与 `g_{q_k}=0`，局部 Jacobian 显示 wait 直接受 `Λ_q` 与 `Ton_p` 影响 | 已由 PIS-IEK 局部 Jacobian 支持 |
| PIS-IEK 不是单点验证 | 77 个幅值扫描和 80 个四事件提升频响工况显示，`Λ` 全范围最大 rms wait 误差 `0.05025%`，可观测频响 wait 幅值误差低于 `0.004%` | 已由结构化 PIS-IEK 仿真支持 |
| 当前面积触发副本仍是工程近似 | v4 使用 `∫max(e_v,0)dt`；v5 已加入 `R_i(Iph-I_Li)`，但 `phase_idx` 对 next-phase 阈值选择和严格 `v_c-R_i i_L` 逐相 off-time window 仍需进一步形式化 | 已明确为局限 |

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
| Fig. 13 | `fig13_iek_area_simulink_validation.png` | 面积触发 IEK-REQ 模型副本验证 |
| Fig. 14 | `fig14_iek_perphase_simulink_validation.png` | 逐相 IEK 面积核模型副本验证 |
| Fig. 15 | `fig15_iek_perphase_load_sweep.png` | 逐相 IEK 静态负载扫点验证 |
| Fig. 16 | `fig16_pis_iek_amplitude_error.svg` | PIS-IEK 幅值扫描误差边界 |
| Fig. 17 | `fig17_pis_iek_lifted_frequency_response.svg` | PIS-IEK 四事件提升频率响应 |

## 15. v7 新增验证一：Simulink 逐相有限差分 Jacobian

根据审稿式建议，v7 不再只依赖解析 PIS-IEK 脚本，而是在逐相面积触发 Simulink 副本上构建了 trim 版模型：

```text
E:/Desktop/codex/output/simulink_iek/four_phase_iek_perphase_trim.slx
```

该副本仍然不修改用户原始 `four_phase.slx`，只在已有逐相面积副本上暴露 `Lambda1..Lambda4` 与 `Ton_trim1..Ton_trim4`。模型 XML 抽查确认，四个面积阈值常数已经分别绑定到 `Lambda1..Lambda4`，四个 `Ton_trim` 常数已经接入 `IQCOT_Ton_Adapter/Ton_Sum1..4`。因此，本节有限差分直接作用于 Simulink 开关模型中的执行量，而不是解析脚本里的替代变量。

有限差分实验采用 3 个负载点、2 个空间图样和 2 类执行量，共 27 个原始 Simulink 样本与 12 行中心差分 Jacobian。`Lambda` 扰动幅值为 `0.10 Lambda_area = 6e-11 V*s`；`Ton` 扰动幅值采用 `4 ns`。这里不使用 20 ps 作为 Simulink 有限差分幅值，是因为该开关模型包含离散时序/事件检测分辨率，ps 级 `Ton` 修正在部分工况中会被有效时序量化吞没。该现象本身也是数字控制建模必须保留的工程约束。

| 通道 | Simulink 有限差分中值 | 相位间隔代价中值 | 解释 |
|---|---:|---:|---|
| `Lambda_m2 -> m2 current` | `0.00397031 mA/(1e-13 V*s)` | `0.00149489 ns/(1e-13 V*s)` | 电流通道极弱，主要不是 DC 均流旋钮 |
| `Ton_m2 -> m2 current` | `49.3951 mA/(0.1 ns)` | `0.0217058 ns/(0.1 ns)` | 电流通道强，是主要均流执行量 |

按 m2 电流投影中值估算，`Ton_m2` 与 `Lambda_m2` 的电流通道强度相差约 `1.24e+04` 倍。这个数量级小于理想解析模型中“数个到五个数量级”的差距，原因是 Simulink 副本包含离散时序、有限仿真窗口、负载点差异和面积触发工程近似；但方向结论保持一致：`Lambda_diff` 不是强 DC current-sharing 执行量，`Ton_diff` 才是强均流通道。

![Fig. 18. Simulink per-phase finite-difference Jacobian](E:/Desktop/codex/output/figures/fig18_simulink_fd_jacobian.png)

## 16. v7 新增验证二：数字量化与检测延迟 Monte Carlo 预算

为回应“仿真数据点太少”和“数字实现预算不足”的问题，v7 增加了 PIS-IEK 事件域 Monte Carlo。该实验扫描：

| 参数 | 扫描值 |
|---|---|
| 面积阈值位宽 | `10, 12, 14, 16 bit` |
| 检测时钟 | `0.5, 1, 2, 5 ns` |
| `Ton` 分辨率 | `5, 10, 20, 50 ps` |
| 比较器随机延迟标准差 | `0, 0.5, 1, 2 ns` |
| 每个组合随机种子 | `16` |

总计生成 `4096` 行随机样本和 `256` 行聚合统计。代表性工况 `12 bit / 1 ns clock / 10 ps Ton / 0.5 ns delay sigma` 的结果为：

| 指标 | 均值 | 95 分位 |
|---|---:|---:|
| wait jitter rms | `0.6466 ns` | `0.6744 ns` |
| phase-spacing std | `0.6466 ns` | `0.6745 ns` |
| current-sharing rms | `0.5059 mA` | `0.9026 mA` |
| event-level Vout rms | `0.0154 mV` | `0.0261 mV` |

最差聚合工况为 `bits=10, clock=5.0 ns, Ton=50 ps, delay_sigma=2.0 ns`，其 phase-spacing std 的 95 分位为 `2.8818 ns`。最好聚合工况为 `bits=16, clock=0.5 ns, Ton=5 ps, delay_sigma=0.0 ns`，其 phase-spacing std 的 95 分位为 `0.1684 ns`。

![Fig. 19. PIS-IEK Monte Carlo digital implementation budget](E:/Desktop/codex/output/figures/fig19_pis_iek_monte_carlo_budget.png)

## 17. v7 证据链更新与创新边界

v7 后，本文证据链可重新整理为四层：

1. 理论层：IEK 与 PIS-IEK 将 IQCOT 面积事件、`phase_idx`、积分 reset、`Lambda_i/Ton_i` 写入 event-to-event Jacobian。
2. 解析验证层：局部灵敏度、模态投影、幅值扫描和 lifted frequency response 验证 PIS-IEK 的小信号适用范围。
3. 电路交叉验证层：Simulink 逐相面积触发副本与 trim 副本给出静态负载、面积差模和 `Ton` 差模有限差分证据。
4. 数字实现预算层：Monte Carlo 将面积位宽、检测时钟、Ton 分辨率和比较器延迟映射为 wait jitter、phase-spacing 与均流误差。

创新边界仍需克制。本文不声称首次提出 IQCOT、COT sampled-data、saltation/Poincare 方法或任意 duty 的多相 COT 通用模型。本文可主张的创新是：面向四相数字 IQCOT 非重叠工作区，把面积积分事件、相索引调度、积分 reset、数字量化与受限均流执行量统一到可计算的小信号设计框架中，并用解析大样本与 Simulink 副本交叉验证 `Lambda_diff` 与 `Ton_diff` 的执行通道差异。

## 18. v7 审稿式自查

| 审稿风险 | v7 后状态 | 仍需保留的边界 |
|---|---|---|
| 验证点太少 | 已增加 4096 行 Monte Carlo、256 行聚合统计、27 个 Simulink 样本和 12 行有限差分 Jacobian | Monte Carlo 是事件域预算，不等同于硬件实测 |
| 只在解析脚本中成立 | 已新增 trim 版 Simulink 副本，直接扰动 `Lambda1..4` 与 `Ton_trim1..4` | Simulink 副本仍是工程近似，未纳入完整 PCB/驱动非理想 |
| `Ton` 小信号与数字分辨率冲突 | 已发现 ps 级 `Ton` 在 Simulink 中可能被有效时序量化吞没，改用 4 ns 有限步长验证方向 | Simulink 有限差分是有限步长方向验证，不是解析微分等式 |
| 工作点范围偏窄 | 已补 20/40/50 A 有限差分与 20--50 A 静态负载扫点 | 仍聚焦 12 V 到 1 V、四相、非 phase-overlap 区域 |
| 外环/硬件链路不足 | 已将其列入局限，数字预算提供下一步设计约束 | 仍未完成实物、FPGA/ASIC、phase-overlap 扩展 |

因此，v7 稿件更适合作为硕士论文或中文期刊论文的完整版本；若目标是 TPEL/JESTPE，还需要补充 phase-overlap 区域、硬件链路和实测/PLECS 交叉验证。

## 19. v7 数据与脚本清单

| 类型 | 文件 |
|---|---|
| Simulink trim 副本构建 | `E:/Desktop/codex/output/iqcot_build_iek_perphase_trim_model.m` |
| Simulink trim 副本 | `E:/Desktop/codex/output/simulink_iek/four_phase_iek_perphase_trim.slx` |
| Simulink 有限差分脚本 | `E:/Desktop/codex/output/iqcot_simulink_perphase_fd_validation.m` |
| Simulink 原始样本 | `E:/Desktop/codex/output/iqcot_simulink_perphase_fd_samples.csv` |
| Simulink Jacobian | `E:/Desktop/codex/output/iqcot_simulink_perphase_fd_jacobian.csv` |
| Simulink 报告 | `E:/Desktop/codex/output/iqcot_simulink_perphase_fd_validation_report.md` |
| Monte Carlo 脚本 | `E:/Desktop/codex/output/iqcot_pis_iek_monte_carlo_budget.py` |
| Monte Carlo 明细 | `E:/Desktop/codex/output/iqcot_pis_iek_monte_carlo_detail.csv` |
| Monte Carlo 聚合 | `E:/Desktop/codex/output/iqcot_pis_iek_monte_carlo_summary.csv` |
| Monte Carlo 报告 | `E:/Desktop/codex/output/iqcot_pis_iek_monte_carlo_budget_report.md` |
| 新增图表 | `E:/Desktop/codex/output/figures/fig18_simulink_fd_jacobian.png`, `E:/Desktop/codex/output/figures/fig19_pis_iek_monte_carlo_budget.png` |
