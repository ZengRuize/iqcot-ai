# 多相数字 IQCOT Buck 变换器的积分事件核模态建模与均流执行量约束设计

## 摘要

多相交错 Buck 变换器广泛用于低压大电流电压调节模块。constant on-time（COT）及 inverse charge constant on-time（IQCOT）控制因瞬态响应快、轻载效率高和结构紧凑而受到关注，但数字多相实现中的面积阈值、检测延迟、量化噪声、相位间隔和相电流均衡往往被混合为经验调参问题。已有 IQCOT 高频小信号模型、ripple-based COT sampled-data 模型和多相数字积分 COT 均流方案为该领域奠定了基础；本文的目标不是重新提出 IQCOT 或 COT sampled-data 建模，而是针对多相数字 IQCOT 的积分面积事件建立可区分共模、差模和均流执行量的设计模型。本文提出积分事件核（Integral-Event Kernel, IEK）模态建模方法，从 IQCOT 面积事件

```text
∫[vc(t) - Ri iL(t)]dt = CT VTH / gm
```

出发，通过移动边界线性化建立事件时刻、面积阈值、检测延迟和功率级状态记忆之间的 sampled-data 关系，并将多相事件扰动分解为 common-mode 与 differential-mode 事件核。单相非线性逐周期面积事件仿真表明，动态 IEK 对周期响应的最大幅值误差低于 0.00018%，而 He-only 局部面积刚度模型的最大幅值误差达到 771.62%。在四相交错 Buck 中，common-mode 面积扰动下 He-only 模型最大误差达到 3512.46%，说明面积阈值和 jitter 预算不能仅由局部事件终点刚度决定。差模仿真进一步表明，Lambda_diff 主要改变 phase spacing，而非 DC 均流；8e-13 的差模面积偏置仅产生小于 0.002 mA 的平均相电流 pk-pk 变化。相反，Ton_diff 是强均流执行量，但会消耗 phase-spacing margin。带慢速共模 VC 适配的失配动态仿真显示，在 20% 单调 DCR 失配下，no-trim 电流不均为 4.086 A pk-pk，Lambda_diff-only 后仍为 4.086 A，而解析 Ton-trim 可将残差降至 0.029 A；受限 ±0.1 ns 与 ±0.2 ns Ton-trim 分别将电流不均降至 3.281 A 与 2.473 A，并对应约 409 ns 与 309 ns 的平均相等待时间 pk-pk 代价。结果表明，多相数字 IQCOT 的参数设计应区分 Lambda_cm、Lambda_diff 与 Ton_diff 的物理通道，并用事件核模型统一约束输出调节、相位间隔和均流代价。

**关键词**：IQCOT；constant on-time；多相 Buck；小信号模型；sampled-data；积分事件核；均流；phase-spacing jitter

## Abstract

Multiphase interleaved buck converters are widely used in low-voltage high-current voltage regulator modules. Constant-on-time (COT) and inverse-charge constant-on-time (IQCOT) control are attractive because of their fast transient response and compact architecture, yet digital multiphase IQCOT implementations often mix area thresholds, detection delay, quantization noise, phase spacing and current balancing into empirical tuning rules. This paper proposes an integral-event kernel (IEK) modal model for multiphase digital IQCOT buck converters. Starting from the IQCOT area event, the model linearizes the moving event boundary and represents power-stage memory as a dynamic kernel K(z). The model is then decomposed into common-mode and differential-mode event channels. Single-phase nonlinear event simulation validates the dynamic IEK with less than 0.00018% period-response error. Four-phase simulations show that a local He-only stiffness approximation can fail by more than 3500% in common-mode area perturbations. Differential-mode analysis shows that Lambda_diff mainly changes phase spacing rather than DC current sharing, whereas Ton_diff is an effective current-sharing actuator with a measurable phase-spacing cost. Mismatched dynamic simulations with common-mode VC adaptation further confirm that Ton-trim, not differential area-threshold trim, is the dominant current-balancing actuator under DCR mismatch. The proposed IEK framework therefore provides a bounded small-signal design basis for threshold resolution, delay/noise budgeting, phase management and constrained current balancing in multiphase digital IQCOT converters.

## 1. 引言

低压大电流处理器供电要求电压调节模块同时具备高带宽、低纹波、高电流密度和良好的负载瞬态响应。多相交错 Buck 通过相位错开降低输入与输出纹波，并通过相电流分担降低器件热应力，是 VRM 的常见拓扑。COT 控制因不依赖固定频率时钟、负载瞬态响应快而被广泛采用；IQCOT 进一步将 off-time 触发条件写为电压和电流信息的积分面积事件，使控制律在纹波抵消点附近仍可保持可检测性，并可实现自然的脉冲重叠瞬态行为。

已有研究已经覆盖了 IQCOT 和 COT 小信号分析的重要基础。Bari 的博士论文提出 inverse charge COT 控制思想，并指出 IQCOT 可改善多相纹波抵消点附近的噪声免疫和瞬态行为 [1]；Bari、Li 和 Lee 后续给出了 IQCOT 高频小信号模型 [2]、[3]。针对 ripple-based COT，Yan、Ruan、Li 以及 Gabriele 等的 sampled-data 模型已经能够处理事件触发、边带效应和任意纹波注入网络 [4]、[5]。针对数字多相实现，Li 等提出了多相 DICOT 和高分辨率均流方案 [6]，Sridhar 和 Li 也研究了多相 COT 相位重叠的小信号模型 [7]。因此，本文不声称首次提出 IQCOT，也不声称首次建立 COT sampled-data 模型。

本文关注一个更窄但更直接的设计问题：在多相数字 IQCOT 中，面积阈值、检测延迟、面积噪声、相位间隔和 Ton-trim 均流执行量如何进入同一个小信号设计框架？如果只使用局部面积刚度

```text
δT ≈ δΛ / He
```

设计阈值分辨率和 jitter 预算，则隐含假设 off-time 起点状态不受过去事件扰动影响。对于含输出电容、电感 DCR、多相相位管理和 current-sharing 执行量的系统，这一假设通常不成立。本文提出 IEK-IQCOT 模型，用动态事件核 K(z) 表示功率级和控制链路的记忆效应，并将多相事件扰动分解为 common-mode 与 differential-mode。

本文贡献如下：

1. 从 IQCOT 积分面积事件出发，推导事件时刻扰动、面积阈值扰动、检测延迟和功率级状态记忆之间的 IEK sampled-data 模型。
2. 给出由阈值面积到周期扰动传函反推出动态事件核 K(z) 的方法，并验证时间平移不变性条件 K(1)=Hs-He。
3. 将 IEK 扩展到四相交错 Buck，提出 common/differential modal decomposition，用于区分输出调节、相位间隔扰动和均流执行量。
4. 通过匹配与失配动态仿真表明：Lambda_diff 主要表现为 phase-spacing actuator，Ton_diff 才是强 current-sharing actuator；Ton-trim 的均流收益必须与 phase-spacing cost 共同约束。

![Figure 1. Integral-event kernel view of IQCOT](E:/Desktop/codex/output/figures/fig1_iek_event_kernel.svg)

## 2. 相关工作与研究边界

### 2.1 IQCOT 与高频小信号模型

IQCOT 的核心思想是将 COT 的触发条件从瞬时比较扩展为积分面积事件。Bari 的博士论文系统提出了 inverse charge COT 控制思想，目标包括改善 conventional ripple-based COTCM 在多相纹波抵消点附近的可控性与噪声免疫，并改善负载阶跃瞬态响应 [1]。Bari、Li 和 Lee 在 ECCE 2018 中进一步给出 IQCOT 高频小信号模型 [2]，并在后续 JESTPE 论文中讨论了 ultrafast transient performance [3]。因此，本文不把 IQCOT 控制律本身作为创新点，而是将 IQCOT 面积事件重写为适合数字多相参数设计的动态事件核。

### 2.2 COT sampled-data 与事件驱动建模

ripple-based COT 的 sampled-data 建模已经相当成熟。Yan、Ruan、Li 的工作从 peak/valley current mode 和 voltage mode 等角度建立了通用 sampled-data 方法 [4]；Gabriele 等进一步提出了适用于任意纹波注入网络的统一 RBCOT sampled-data 小信号模型，并通过 SIMetrix/SIMPLIS 和实验验证其高频准确性 [5]。面向 COT Buck 的小信号设计，Liu 等还讨论了 duty-cycle-independent quality factors 的建模与设计问题 [8]。本文借鉴 sampled-data 思想，但事件函数不同：本文对象是 IQCOT 积分面积条件，而不是一般 ripple comparator 的瞬时阈值交叉；同时本文重点不是单相控制到输出传函，而是多相数字实现中的事件通道和执行量分类。

### 2.3 多相数字积分 COT 与 current balance

多相 DICOT 和高分辨率 current balance 研究已经展示了 signal accumulation、phase manager 和 delay-line current balance 的工程可行性 [6]；多相 COT 相位重叠建模也已经给出专门的小信号分析 [7]。本文不提出新的均流硬件电路，而是给出一个解释和约束框架：面积阈值差模、检测延迟差模、Ton-trim 差模在多相 IQCOT 中并不等价。本文的核心边界是：面向多相 IQCOT 积分面积事件，建立 common/differential IEK，并区分 Lambda_cm、Lambda_diff 和 Ton_diff 在输出调节、相位间隔和平均相电流中的作用。

## 3. 单相 IQCOT 积分事件核模型

单相 IQCOT 的 off-time 面积事件写为

```math
F_k=\int_{a_k}^{t_{k+1}} h(t)\,dt-\Lambda=0,
\qquad h(t)=v_c(t)-R_i i_L(t),
\qquad \Lambda=\frac{C_T V_{TH}}{g_m}.
```

其中，a_k 为积分起点，t_{k+1} 为下一次触发时刻。定义事件时刻扰动 τ_k，并对稳态周期轨道做移动边界线性化，可得

```math
H_e\tau_{k+1}
-H_s(\tau_k+\widehat t_{on,k}+\widehat t_{blank,k})
+A_{\mathrm{state},k}
+A_{\mathrm{param},k}
-\Lambda\rho_k
-\Delta A_{\mathrm{det},k}=0,
```

其中

```math
H_e=h_0(t_{k+1}^-),\qquad
H_s=h_0(a_k^+),
```

```math
\rho_k=\delta\ln\Lambda
=\delta\ln C_T+\delta\ln V_{TH}-\delta\ln g_m.
```

在真实 Buck-IQCOT 中，A_state,k 由功率级状态记忆决定，可写为事件核卷积形式：

```math
A_{\mathrm{state},k}=K_0\tau_k+K_1\tau_{k-1}+K_2\tau_{k-2}+\cdots .
```

于是得到 IEK 表达式：

```math
\left[H_e z-H_s+K(z)\right]\Tau(z)=U_A(z).
```

面积域输入 U_A 汇总阈值、参数、延迟和噪声：

```math
U_{A,k}=
\Lambda\rho_k
-A_{\mathrm{param},k}
+H_s(\widehat t_{on,k}+\widehat t_{blank,k})
+\Delta A_{\mathrm{det},k}
+w_{A,k}.
```

固定 on-time 下，周期扰动和 duty 扰动满足

```math
\Delta T_k=\tau_{k+1}-\tau_k,\qquad
\widehat d_k=-\frac{D}{T_s}\Delta T_k.
```

因此

```math
\frac{\widehat D(z)}{U_A(z)}
=-\frac{D}{T_s}
\frac{z-1}{H_e z-H_s+K(z)}.
```

自治开关系统对整体时间平移不敏感，因此

```math
H_e-H_s+K(1)=0,\qquad K(1)=H_s-H_e.
```

该条件说明，绝对事件相位 τ 不是最终工程指标；周期扰动 ΔT、duty 扰动和相位间隔扰动才直接影响频率、纹波和平均模型。

## 4. 动态 K(z) 识别方法

为避免将 K(z) 作为经验拟合项，本文从显式 Buck-IQCOT 面积事件模型识别动态事件核。取状态

```math
x=[i_L,\ v_C]^T,
```

on/off 区间为

```math
\dot x=A x+b_{\mathrm{on}},\qquad
\dot x=A x+b_{\mathrm{off}}.
```

状态转移用矩阵指数精确计算：

```math
x(t)=x_{ss}+e^{At}(x_0-x_{ss}),
```

```math
\int_0^t x(s)\,ds=t x_{ss}+A^{-1}(e^{At}-I)(x_0-x_{ss}).
```

固定 Ton、变 off-time 的面积事件线性化为

```math
M\delta x_{a,k}+H_e\delta T_k-\delta\Lambda_k=0.
```

因此

```math
\delta T_k=C_t\delta x_k+D_t\delta\Lambda_k,
\qquad C_t=-\frac{M\Phi_{\mathrm{on}}}{H_e},
\qquad D_t=\frac{1}{H_e}.
```

事件后的状态扰动为

```math
\delta x_{k+1}=A_d\delta x_k+B_d\delta\Lambda_k,
```

其中

```math
A_d=\Phi_{\mathrm{off}}\Phi_{\mathrm{on}}+f_e C_t,\qquad
B_d=f_e D_t.
```

阈值面积到周期扰动传函为

```math
G_T(z)=\frac{\Delta T(z)}{\Delta\Lambda(z)}
=C_t(zI-A_d)^{-1}B_d+D_t.
```

由 IEK 定义反解得到

```math
K(z)=\frac{z-1}{G_T(z)}-(H_e z-H_s).
```

该识别方式的优点是：K(z) 由显式状态空间和面积事件共同决定，低频处必须满足 K(1)=H_s-H_e，高频处则保留功率级记忆导致的频率选择性。

## 5. 多相模态 IEK

四相交错 Buck 中，事件按相序轮转。设 p_k 为当前 on-time 相，q_k 为下一触发相：

```math
p_k=k\bmod N,\qquad q_k=(p_k+1)\bmod N.
```

下一相 IQCOT 面积事件为

```math
\int_{a_k}^{t_{k+1}}\left[V_C-R_{i,q}i_q(t)\right]dt=\Lambda_q.
```

对于相参数匹配的 N 相系统，线性化模型具有循环对称性，可使用离散傅里叶模态分解：

```math
\Tau_m(z)=\mathrm{DFT}\{\tau_q\},\qquad
U_m(z)=\mathrm{DFT}\{u_{A,q}\},
```

```math
\left[H_{e,m}z-H_{s,m}+K_m(z)\right]\Tau_m(z)=U_m(z).
```

m=0 为 common-mode，主要影响总周期 jitter、输出电压和等效开关频率；m=1...N-1 为 differential modes，主要影响相位间隔、相间 ripple cancellation、limit cycle 和均流相关动态。由此得到执行量分类：

```text
Lambda_cm   -> 输出调节 / 总周期 jitter
Lambda_diff -> 相位间隔 / 差模 jitter / ripple cancellation
Ton_diff    -> 平均相电流 / current sharing
```

![Figure 3. Multiphase modal decomposition and actuator channels](E:/Desktop/codex/output/figures/fig3_multiphase_modal_channels.svg)

## 6. 仿真设置与可复现材料

本文使用独立脚本进行理论验证。主要脚本如下：

```text
E:/Desktop/codex/output/iqcot_dynamic_iek_kernel_identification.py
E:/Desktop/codex/output/iqcot_multiphase_iek_modal_study.py
E:/Desktop/codex/output/iqcot_multiphase_current_balance_design.py
E:/Desktop/codex/output/iqcot_multiphase_mismatch_dynamic_validation.py
E:/Desktop/codex/output/iqcot_generate_paper_figures.py
```

单相动态 IEK 验证参数为 Vin=12 V、Iload=10 A、L=200 nH、C=1.8 mF、DCR=1.5 mΩ、Ri=0.5 mΩ、fsw=500 kHz、Ton=166.667 ns、Toff=1833.333 ns。四相模型参数为 N=4、Vin=12 V、Vref=1 V、Iout=40 A、L=200 nH、C=7.2 mF、DCR=1.5 mΩ、Ri=0.5 mΩ、fsw,phase=500 kHz、Tglobal=500 ns、Ton=169.167 ns、Twait=330.833 ns、VC=5.0167 mV。失配动态仿真在四相逐事件模型中加入 per-phase DCR/Ri mismatch，并加入一个慢速 common-mode VC 适配器，使平均 Vout 保持在 1 V 附近。该适配器只承担共模调压，不参与差模均流。

主要 CSV 输出如下：

```text
iqcot_dynamic_iek_nonlinear_frequency_validation.csv
iqcot_dynamic_iek_kernel_samples.csv
iqcot_multiphase_iek_common_response.csv
iqcot_multiphase_iek_differential_offsets.csv
iqcot_multiphase_iek_ton_trim_offsets.csv
iqcot_multiphase_current_balance_limited_trim.csv
iqcot_multiphase_mismatch_dynamic_validation.csv
iqcot_multiphase_mismatch_rk_convergence.csv
```

## 7. 结果

### 7.1 动态 IEK 准确预测单相非线性面积事件响应

在单相模型中，对面积阈值施加小正弦扰动：

```math
\Lambda_k=\Lambda_0+2\times10^{-11}\sin(\omega k).
```

动态 IEK 预测与非线性逐周期面积事件求解高度一致。频率点 0.01π 至 0.70π 范围内，周期幅值最大误差低于 0.00018%，周期相位最大误差约 4.07e-5 deg；duty 幅值与相位误差同量级。低频核极限满足时间平移不变性：K(1)=H_s-H_e=-4.5837 mV，在 ω/π=0.001 时 K=-4.5877-j0.0072 mV。该结果说明 K(z) 不是任意拟合项，而是与自治事件系统结构约束一致。

![Figure 2. Single-phase dynamic IEK validation](E:/Desktop/codex/output/figures/fig2_single_phase_dynamic_iek_validation.svg)

### 7.2 He-only 静态模型不能可靠预测多相面积阈值扰动

若忽略 K(z)，采用 δT≈δΛ/He，则相当于认为当前事件仅受终点面积斜率控制。单相验证中，He-only 模型相对非线性仿真的最大幅值误差为 771.62%，最大相位误差为 77.18 deg。对于 2e-11 面积扰动，He-only 周期幅值预测为 3.2875 ns，而动态 IEK 的 DC 周期幅值为 5.2672 ns，对应 -37.58% 误差。

在四相 common-mode 面积阈值扰动下，He-only 模型失效更加显著。静态模型给出的幅值为 0.1713 ns；非线性事件仿真显示 ω/π=0.005 时 wait 幅值为 0.01355 ns，误差为 1164.04%；ω/π=0.01 时 wait 幅值为 0.00474 ns，误差达到 3512.46%。在 ω/π=0.20 附近，He-only 误差降至 -0.66%，说明静态模型并非处处错误，而是无法描述频率选择性事件记忆。对数字阈值分辨率、dither、面积噪声整形和 jitter budget 来说，K_0(z) 比局部 He 更能反映真实敏感频段。

![Figure 4. Common-mode He-only error](E:/Desktop/codex/output/figures/fig4_common_mode_he_only_error.svg)

### 7.3 差模面积阈值主要影响 phase spacing，而非 DC 均流

对四相模型施加差模面积阈值偏置：

```text
m1_cos    = [1, 0, -1, 0]
m2_alt    = [1, -1, 1, -1]
one_phase = [1, -1/3, -1/3, -1/3]
```

当 amp_area=8e-13 时，m1_cos 与 m2_alt 均产生约 1.0667 ns 的 wait-time pk-pk 偏差，但平均相电流 pk-pk 小于 0.002 mA。该结果说明，理想匹配、固定 Ton 和轮转相位管理条件下，Lambda_diff 主要是 phase-spacing actuator，而不是 DC current-sharing actuator。它可以用于相位间隔修正或 ripple cancellation 优化，但不能替代均流执行量。

### 7.4 Ton-trim 是强均流执行量，但有相位代价

每相 Ton_trim 对平均相电流具有强作用。在小信号区间内，m2_alt Ton_trim=0.02 ns 时 I_pkpk=159.92 mA、wait_pkpk=17.57 ns；Ton_trim=0.05 ns 时 I_pkpk=398.82 mA、wait_pkpk=44.07 ns；Ton_trim=0.10 ns 时 I_pkpk=790.81 mA、wait_pkpk=88.89 ns。该结果说明 Ton_diff 是有效均流执行量，但会通过 IQCOT 面积事件扰动后续等待时间，造成 phase-spacing cost。因此，多相数字 IQCOT 的均流设计不能只最小化 current-sharing error，还必须同时约束 phase-spacing jitter。

### 7.5 DCR 失配下的受限 Ton-trim 设计链

为了连接实际均流问题，本文先建立 DCR 失配下的 DC current-sharing algebra。等 Ton 条件下：

```math
I_j=\frac{D V_{in}-V_o}{R_j},\qquad \sum_j I_j=I_{out}.
```

若使用 zero-mean Ton_trim 补偿，则解析补偿量为

```math
\delta T_{on,j}=\frac{T_s I_{\mathrm{ref}}(R_j-\bar R)}{V_{in}}.
```

20% 单调 DCR 失配 `[0.80, 0.93, 1.07, 1.20]` 下，无补偿 current pk-pk 为 4.072 A，全均流所需 Ton_trim pk-pk 为 1.000 ns。全补偿可在 DC algebra 中消除电流不均，但相位代价可能过大。受限 Ton-trim 评估显示，0.10 ns trim limit 的平均 current pk-pk 降低为 31.98%，最大 wait-time cost 为 108.07 ns；0.20 ns trim limit 的平均 current pk-pk 降低为 61.97%，最大 wait-time cost 为 252.03 ns。

![Figure 6. Limited Ton-trim design curve](E:/Desktop/codex/output/figures/fig6_limited_ton_trim_design_curve.svg)

### 7.6 失配动态闭环验证：Lambda_diff 仍不是主要均流通道

上述 DC algebra 仍可能被质疑：它将电流不均和事件 timing cost 分开计算。为补足这一点，本文进一步建立 per-phase DCR/Ri mismatch 的逐事件动态模型，并加入慢速 common-mode VC 适配器，使输出电压保持在约 1 V。该模型保留 IQCOT 面积事件求解，不使用固定周期平均假设。RK4 步长收敛检查显示，在强单调 DCR 失配下，max step=20 ns、10 ns 和 5 ns 得到的 Ipkpk 均为 4.207323 A，Vout 均为 1.011004 V，说明数值步长不是主要误差来源。

在输出被共模 VC 调住后，强单调 DCR 失配的 no-trim 动态电流不均为 4.086 A pk-pk，平均 Vout=0.9993 V。施加按 DCR 模式缩放的 Lambda_diff-only（amp=8e-13）后，电流不均仍为 4.086 A，几乎不变。解析 full Ton-trim 后，电流残差降至 0.029 A，平均相等待时间 pk-pk 仅约 5.12 ns。受限 ±0.1 ns Ton-trim 后，电流不均降至 3.281 A，对应平均相等待时间 pk-pk 约 409 ns；受限 ±0.2 ns Ton-trim 后，电流不均降至 2.473 A，对应约 309 ns 相等待时间 pk-pk 代价。

在 alternating ±10% DCR 失配下，no-trim 与 Lambda_diff-only 的电流不均均约为 2.029 A，full Ton-trim 后残差约 0.021 A；在 one-phase high 20% DCR 失配下，no-trim 与 Lambda_diff-only 均约为 2.370 A，full Ton-trim 后残差约 0.019 A。加入 Ri ±10% 失配后，强 DCR 工况下 no-trim 为 4.087 A，Lambda_diff-only 仍为 4.087 A，full Ton-trim 后残差约 0.016 A。该失配动态结果将“Lambda_diff 不是 DC 均流执行量”的结论从理想匹配条件扩展到更接近工程实现的失配条件。

![Figure 5. Mismatch actuator tradeoff](E:/Desktop/codex/output/figures/fig5_mismatch_actuator_tradeoff.svg)

## 8. 讨论

### 8.1 实际价值

IEK 模型的实际价值在于把多相数字 IQCOT 的调参问题拆成可解释的通道。传统 He-only 思路适合估算单次事件的局部灵敏度，但无法描述功率级状态记忆和多相事件序列带来的频率选择性。本文的结果显示，He-only 在某些频点会严重高估或低估 wait jitter；因此，数字面积阈值 DAC、面积噪声、延迟预算和 dither 设计应基于 K_m(z)，而不仅是 He。

执行量分类同样具有工程意义。Lambda_cm 适合作为输出调节和总周期 jitter 通道；Lambda_diff 适合用于相位间隔、差模 jitter 和 ripple cancellation 调节；Ton_diff 才是主要 DC current-sharing actuator。若优化器或人工调参不区分这些通道，可能会误用 Lambda_diff 试图均流，或者用 Ton-trim 追求均流却破坏 phase spacing。本文的受限 Ton-trim 曲线把这种矛盾变成显式约束：给定允许的 phase-spacing cost，可估算可接受的 current-sharing improvement。

### 8.2 相比已有模型的优势与边界

与 IQCOT 描述函数模型相比，IEK 不是替代连续域环路分析，而是补充数字实现中的事件通道分析。描述函数模型有利于控制到输出的小信号设计；IEK 更适合回答“面积阈值、延迟、噪声和 Ton-trim 分别通过哪些事件通道影响多相系统”。与通用 RBCOT sampled-data 模型相比，本文将事件函数具体化为 IQCOT 积分面积，并显式引入 CT、VTH、gm、Ri、检测延迟和面积噪声等参数通道。与多相 DICOT current balance 工作相比，本文不提出新的硬件 current balance 电路，而是提供执行量分类和相位代价评估框架。

### 8.3 局限性

本文仍有明确局限。第一，多相 IEK 目前没有纳入完整 Type-III 或 PI 外环补偿器状态；失配动态仿真使用慢速 common-mode VC 适配器实现调压，主要用于隔离差模均流通道，而非完整补偿器设计。第二，本文尚未在 Simulink 或硬件中实现严格面积积分 IQCOT 控制器；此前 v0027 工程模型可作为 COT/IQCOT 工程实现参考，但不能直接等同于本文的显式面积事件模型。第三，MOSFET 非线性、驱动死区、采样保持、DPWM/ADC 同步和 PCB 寄生没有纳入本文数值模型。第四，较大 Ton-trim 下的 wait perturbation 可能接近或超过小信号范围，因此本文对 Ton-trim 的结论应理解为约束设计趋势，而不是任意大扰动下的线性保证。

## 9. 结论

本文提出一种面向多相数字 IQCOT Buck 的积分事件核模态建模方法。该方法从 IQCOT 面积事件出发，将阈值、延迟、噪声和功率级状态记忆统一表示为动态事件核 K(z)，并进一步分解为 common-mode 与 differential-mode 通道。单相非线性逐周期仿真验证了动态 IEK 的准确性；四相 common-mode 仿真表明，传统 He-only 面积刚度模型可能严重失效；差模阈值仿真与失配动态仿真共同表明，Lambda_diff 主要影响 phase spacing 而非 DC 均流，Ton_diff 才是强 current-sharing actuator，但其均流收益伴随 phase-spacing cost。该框架为多相数字 IQCOT 的阈值分辨率、延迟预算、相位管理和受限均流调参提供了统一的小信号分析基础。

## 数据与代码可用性

本文所有数值结果与图表由 `E:/Desktop/codex/output` 下的脚本和 CSV 生成。核心脚本包括：

```text
iqcot_dynamic_iek_kernel_identification.py
iqcot_multiphase_iek_modal_study.py
iqcot_multiphase_current_balance_design.py
iqcot_multiphase_mismatch_dynamic_validation.py
iqcot_generate_paper_figures.py
```

图表位于：

```text
E:/Desktop/codex/output/figures
```

## 利益冲突、伦理与 AI 使用声明

本研究为电源电子建模与仿真研究，不涉及人体受试者、动物实验或个人敏感数据。作者声明无利益冲突。本文写作与代码整理过程中使用了 AI 辅助进行文献边界梳理、文字组织、脚本编写和审稿式自查；所有公式、数值结果、脚本输出和参考文献元数据均由作者在本地文件、仿真脚本或公开来源中复核。AI 辅助不替代作者对研究结论与学术诚信的责任。

## 参考文献

[1] S. M. K. Bari, *A Novel Inverse Charge Constant On-Time Control for High Performance Voltage Regulators*, Ph.D. dissertation, Virginia Tech, 2018. [Online]. Available: https://vtechworks.lib.vt.edu/items/cae05986-a69e-4642-875a-71b230bee9cc

[2] S. M. K. Bari, Q. Li, and F. C. Lee, “High Frequency Small Signal Model for Inverse Charge Constant On-Time (IQCOT) Control,” in *2018 IEEE Energy Conversion Congress and Exposition (ECCE)*, 2018, pp. 6000-6007, doi: 10.1109/ECCE.2018.8557464.

[3] S. M. K. Bari, Q. Li, and F. C. Lee, “Inverse Charge Constant-On-Time Control With Ultrafast Transient Performance,” *IEEE Journal of Emerging and Selected Topics in Power Electronics*, vol. 9, no. 1, pp. 68-78, 2021, doi: 10.1109/JESTPE.2020.2973151.

[4] N. Yan, X. Ruan, and X. Li, “A general approach to sampled-data modeling for ripple-based control-Part I: Peak/valley current mode and peak/valley voltage mode,” *IEEE Transactions on Power Electronics*, vol. 37, no. 6, pp. 6371-6384, 2022, doi: 10.1109/TPEL.2021.3132619.

[5] F. Gabriele, A. Carlucci, D. Lena, F. Pareschi, R. Rovatti, S. Grivet-Talocia, and G. Setti, “A Unified Sampled-Data Small-Signal Model for a Ripple-Based COT Buck Converter With Arbitrary Ripple Injection Network,” *IEEE Transactions on Circuits and Systems I: Regular Papers*, vol. 72, no. 6, pp. 2942-2955, 2025, doi: 10.1109/TCSI.2025.3557278.

[6] Y. Li, Y. Wang, X. Yang, G. Wei, H. Liu, C. Zhang, and S. Mao, “Multiphase digital integration constant on-time-controlled Buck converter with high-resolution current balance scheme for ultrafast load transient,” *International Journal of Circuit Theory and Applications*, vol. 52, no. 7, pp. 3188-3212, 2024, doi: 10.1002/cta.3924.

[7] S. Sridhar and Q. Li, “Multiphase constant on-time control with phase overlapping-Part I: Small-signal model,” *IEEE Transactions on Power Electronics*, vol. 39, no. 6, pp. 6703-6720, 2024, doi: 10.1109/TPEL.2024.3368343.

[8] W.-C. Liu, C.-H. Cheng, P. P. Mercier, and C. C. Mi, “Small-Signal Analysis and Design of Constant On-Time Controlled Buck Converters With Duty-Cycle-Independent Quality Factors,” *IEEE Transactions on Power Electronics*, vol. 38, no. 7, pp. 8379-8393, 2023, doi: 10.1109/TPEL.2023.3268613.

## 附录 A：术语表

| 术语 | 定义 |
|---|---|
| IQCOT | Inverse charge constant-on-time control |
| IEK | Integral-Event Kernel，积分事件核 |
| Lambda / Λ | IQCOT 面积阈值 CT VTH/gm |
| He | 事件终点面积函数值 h(t_event^-) |
| Hs | 积分起点面积函数值 h(a_k^+) |
| K(z) | 功率级和控制链路状态记忆形成的动态事件核 |
| Lambda_cm | 多相面积阈值共模分量 |
| Lambda_diff | 多相面积阈值差模分量 |
| Ton_diff | 每相 on-time trim 的差模分量 |
| phase-spacing jitter | 相邻相触发间隔扰动 |
| current-sharing error | 平均相电流不均衡 |

## 附录 B：核心论断与证据矩阵

| 论断 | 证据 | 状态 |
|---|---|---|
| 动态 IEK 可准确预测单相 IQCOT 面积阈值到周期扰动的响应 | `iqcot_dynamic_iek_nonlinear_frequency_validation.csv`，最大周期幅值误差 <0.00018% | 已由非线性逐周期仿真支持 |
| He-only 模型不能可靠描述多相面积阈值扰动 | `iqcot_multiphase_iek_common_response.csv`，common-mode 最大误差 3512.46% | 已由四相事件仿真支持 |
| Lambda_diff 主要影响 phase spacing 而非 DC 均流 | `iqcot_multiphase_iek_differential_offsets.csv`，8e-13 差模面积偏置下相电流 pk-pk <0.002 mA | 已由匹配模型支持 |
| Ton_diff 是强 current-sharing actuator | `iqcot_multiphase_iek_ton_trim_offsets.csv`，0.10 ns Ton_trim 产生约 790.81 mA 电流 pk-pk | 已由匹配模型支持 |
| DCR 失配下 Lambda_diff-only 仍不能有效均流 | `iqcot_multiphase_mismatch_dynamic_validation.csv`，强 DCR no-trim 与 Lambda_diff-only 均约 4.086 A pk-pk | 已由失配动态仿真支持 |
| 受限 Ton-trim 存在 current-sharing benefit 与 phase-spacing cost 权衡 | `iqcot_multiphase_current_balance_limited_trim.csv` 与 Fig. 6 | 已由设计链和事件仿真支持 |
| 本研究尚未完成硬件或严格 Simulink 面积事件验证 | 当前工作记录与脚本范围 | 作为局限性明确声明 |

## 附录 C：图表追踪说明

| 图号 | 文件 | 数据来源 | 支持的正文论断 | 局限 |
|---|---|---|---|---|
| Fig. 1 | `fig1_iek_event_kernel.svg` | 理论框架示意 | IEK 将面积事件、状态记忆和事件时刻统一表示 | 概念图，不含数值数据 |
| Fig. 2 | `fig2_single_phase_dynamic_iek_validation.svg` | `iqcot_dynamic_iek_nonlinear_frequency_validation.csv` | 动态 IEK 与非线性事件仿真一致 | 单相模型 |
| Fig. 3 | `fig3_multiphase_modal_channels.svg` | 理论框架示意 | common/differential 模态与执行量分类 | 概念图，不含数值数据 |
| Fig. 4 | `fig4_common_mode_he_only_error.svg` | `iqcot_multiphase_iek_common_response.csv` | He-only 不能描述多相频率选择性事件记忆 | 匹配四相模型 |
| Fig. 5 | `fig5_mismatch_actuator_tradeoff.svg` | `iqcot_multiphase_mismatch_dynamic_validation.csv` | Lambda_diff 与 Ton_diff 在失配均流中的作用不同 | 使用慢速 VC 适配器而非完整补偿器 |
| Fig. 6 | `fig6_limited_ton_trim_design_curve.svg` | `iqcot_multiphase_current_balance_limited_trim.csv` | 受限 Ton-trim 的均流收益与相位代价权衡 | 基于 DC algebra 与事件 timing cost 组合设计 |
