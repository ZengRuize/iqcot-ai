# 四相数字 IQCOT Buck 变换器的 PIS-IEK 混合事件小信号模型、切载参考斜率调度与延迟感知 AI 参数优化

## 摘要

面向低压大电流 VRM 的四相交错 Buck 变换器中，COT/IQCOT 控制具有快速瞬态响应和数字实现紧凑的优势，但其触发事件、相序调度、积分复位、脉冲跳跃以及逐相均流执行量共同构成了一个典型的混合事件系统。传统的局部事件斜率模型能够给出直观解释，却容易忽略 off-time 积分区间内由功率级状态积累形成的事件记忆；另一方面，若直接把 AI 调参视为逐脉冲开关控制，则会与 FPGA 上微秒级推理延迟发生时间尺度冲突。本文在已有四相 IQCOT 文献和本地 Simulink/Simscape 开关级模型基础上，形成一个聚焦四相的相索引盐跃积分事件核模型（Phase-Indexed Saltation Integral-Event Kernel, PIS-IEK）。该模型将 IQCOT 面积事件写成移动边界线性化问题，并进一步把 `phase_idx`、积分 reset、`Lambda_i/Ton_i` 执行量和 `normal/skip/reentry/saturation` 模式切换统一到 event-to-event Jacobian 中。最新动态负载验证显示，参考瞬时下调可把最终电压静差压到约 `-0.43` 至 `-0.57 mV`，但会把切载欠压显著放大；在 `40A->near-0A` 工况中，近似瞬时参考的欠压为 `35.750 mV`，而 `40 us` 参考斜率在当前扫描网格中将欠压降至 `10.897 mV`，同时保持 `-0.569 mV` 的最终电压误差。事件域 AI 延迟 surrogate 进一步表明，当 `tau_AI=5 us`、约等于 `10` 个 IQCOT 事件时，零延迟训练策略在严苛切载下出现明显 train-test mismatch，平均 violation 从延迟感知安全投影策略的 `24.297` 增至 `147.875`。这些结果支持一个克制但有实际价值的结论：PIS-IEK 不应被表述为替代 IQCOT 内环或精确预测大切载第一峰值的工具，而应作为四相数字 IQCOT 的事件域小信号骨架，用于执行量分类、切载模式解释、参考斜率调度和 FPGA 延迟感知 AI 参数训练。

## 1. 引言

四相交错 Buck VRM 的控制难点不只在于平均输出电压调节，还在于多相电流均衡、相位间隔、纹波抵消、瞬态切载恢复和数字实现延迟之间的耦合。IQCOT 通过反电荷或面积类触发机制改善负载瞬态响应，但在多相数字实现中，控制器面对的并不是单一连续时间环路，而是由事件触发、相序轮转、blanking/off-time 约束、逐相 on-time 修正和积分复位组成的离散事件链。

已有 COT/IQCOT 小信号模型在控制到输出传递函数、稳定性和频域响应方面已经提供了重要理论基础。本文的目标不是重新提出 IQCOT 控制律，也不是声称 AI 能替代 COT 比较器或逐脉冲事件发生器。本文关心一个更窄但更适合作为研究生毕业设计创新点的问题：

> 四相数字 IQCOT 的面积触发、相索引调度和切载 skip/reentry 行为，能否被组织成一个足够严谨的小信号/混合事件模型，使其既能解释执行量物理通道，又能为参考斜率调度和 FPGA 延迟感知 AI 调参提供可验证的约束？

本文的核心贡献如下。

1. 从 IQCOT 面积事件出发，使用移动事件边界线性化推导积分事件核（IEK），明确指出 He-only 局部面积斜率模型是忽略动态事件核 `K(z)` 的退化形式。
2. 针对四相数字 IQCOT，提出 PIS-IEK 表达，将当前导通相 `p_k`、下一触发相 `q_k`、积分 reset 和 `Lambda_i/Ton_i` 执行量纳入周期 event-to-event Jacobian。
3. 将大切载过程划分为 `normal/skip/reentry/saturation` 混合事件模式，说明 PIS-IEK 的强项在于描述事件恢复、相位扰动和均流恢复，而不是单独精确预测第一峰值。
4. 在用户 Simulink/Simscape 模型派生副本中完成受控动态负载、参考阶跃和参考斜率扫描，证明 `Iph_ref` 过渡时间是具有物理意义的低维调度变量。
5. 将 FPGA AI 延迟写成事件索引滞后 `d=ceil(tau_AI/T_e)`，并用 15360 episode 事件域 surrogate 验证：当 AI 延迟跨越多个 IQCOT 事件时，延迟感知训练和安全投影可以显著减少约束 violation。

## 2. 相关工作与创新边界

IQCOT 控制及其高频小信号模型已有 Bari、Li 和 Lee 等工作的系统研究；COT/RBCOT 的 sampled-data 建模、任意纹波注入网络、相重叠多相 COT 稳定性分析也已有较成熟文献。近期多相数字 integration COT 和高分辨率均流方案进一步说明，数字 COT 可以实现快速负载瞬态和多相均流。

本文与这些工作的关系需要清楚限定。已有文献更多回答“控制律是否成立、环路如何稳定、控制到输出如何建模、多相相重叠如何影响小信号稳定性”。本文更聚焦于四相数字实现中的执行量分类问题：`Lambda_cm`、`Lambda_diff`、检测延迟差模、`Ton_diff`、参考斜率和 AI 延迟分别通过什么物理通道影响 wait time、phase spacing、current sharing 和 cut-load recovery。

因此，本文的创新边界不是“首次建立 COT 小信号模型”，而是：

- 将 IQCOT 面积积分事件的动态状态记忆显式保留为 `H_e+K(z)`；
- 将四相 `phase_idx/reset` 从工程实现变量提升为事件面索引与 saltation correction；
- 将切载下的 skip/reentry 作为模式变量加入小信号模型边界；
- 将 `Iph_ref` 参考斜率和 FPGA AI 延迟写成可训练、可约束、可仿真的低维调度问题。

## 3. 基础 IEK 小信号推导

考虑第 `k` 次 off-time 面积事件。令事件状态为 `x_k`，off-time 长度为 `T_{off,k}`，面积阈值为 `Lambda_k`，则 IQCOT 类面积触发可写成

```math
F_k(x_k,T_{off,k},\Lambda_k)
=\int_0^{T_{off,k}} h(x_k,\tau)d\tau-\Lambda_k=0,
```

其中典型 IQCOT 面积核可写作

```math
h(t)=v_c(t)-R_i i_L(t).
```

在某一工作点附近，off-time 内功率级满足线性化状态方程

```math
\dot{x}=A_{off}x+B_{off}u,\qquad
h(t)=C_h x(t)+D_hu(t).
```

于是

```math
x(\tau)=e^{A_{off}\tau}x_k
+\int_0^\tau e^{A_{off}(\tau-s)}B_{off}u(s)ds.
```

对移动事件边界做一阶线性化，得到

```math
\delta F
=F_x\delta x_k+H_e\delta T_{off,k}-\delta\Lambda_k=0,
```

其中

```math
F_x=\int_0^{T_{off}} C_h e^{A_{off}\tau}d\tau,
\qquad
H_e=h(T_{off}^{-}).
```

因此事件时间扰动为

```math
\delta T_{off,k}
=\frac{1}{H_e}(\delta\Lambda_k-F_x\delta x_k).
```

这一式子揭示了 He-only 模型的隐含假设。若令 `F_x delta x_k=0`，就退化为

```math
\delta T_{off,k}\approx \frac{\delta\Lambda_k}{H_e}.
```

但在真实 IQCOT 事件链中，`delta x_k` 由过去事件、输出电容状态、相电流状态、on-time 扰动和负载扰动共同决定。将事件后的状态更新写成

```math
\delta x_{k+1}=A_d\delta x_k+B_T\delta T_{off,k}+B_u\delta u_k,
```

代入事件时间扰动可得

```math
\delta x_{k+1}
=\left(A_d-\frac{B_TF_x}{H_e}\right)\delta x_k
+\frac{B_T}{H_e}\delta\Lambda_k+B_u\delta u_k.
```

定义

```math
A_{IEK}=A_d-\frac{B_TF_x}{H_e},
```

并令 `B_IEK=B_T/H_e`，即可得到从面积阈值到事件时间的 sampled-data 形式

```math
G_{T\Lambda}(z)
=D_{T\Lambda}+C_T(zI-A_{IEK})^{-1}B_{IEK}.
```

等价地，可写为动态面积刚度

```math
G_{T\Lambda}(z)=\frac{1}{H_e+K(z)}.
```

其中 `K(z)` 是由功率级状态记忆造成的积分事件核；He-only 模型对应 `K(z)=0`。这给出基础 IEK 的实际价值：它不是为了让公式变复杂，而是为了在数字面积阈值位宽、检测时钟、Ton 分辨率和相位 jitter 预算中保留频率选择性的事件记忆。

已有本地验证给出两个关键事实：单相动态 IEK 对逐周期非线性仿真的周期幅值误差低于 `0.00018%`；四相密集扫频中，He-only 模型在部分频点可接近真实响应，但最坏相对幅值误差达到 `7969.65%`。这说明 He-only 可以作为局部直觉，却不适合作为完整数字预算和执行量调参依据。

## 4. 四相 PIS-IEK：相索引盐跃事件模型

四相交错系统中，事件不仅发生在时间轴上，还绑定到相序索引。令当前 on-time 相为

```math
p_k=k\bmod 4,
```

下一触发相为

```math
q_k=(p_k+1)\bmod 4.
```

一次事件写成

```math
x_{k+1}=F_{p_k}(x_k,u_k,T_k),
\qquad
g_{q_k}(x_k,u_k,T_k)=0.
```

其中 `F_{p_k}` 包含当前相导通、off-time 演化、积分 reset、scheduler 更新和数字执行量保持；`g_{q_k}` 是下一触发相的事件面。对逐相 IQCOT 面积事件，事件面可写成

```math
g_{q_k}
=\int_0^{T_k}
\left[v_c(t)-R_i i_{L,q_k}(t)\right]dt-\Lambda_{q_k}.
```

对隐函数 `g_{q_k}=0` 线性化得

```math
\delta T_k
=-g_T^{-1}(g_x\delta x_k+g_u\delta u_k).
```

代回状态更新，得到相索引盐跃校正后的事件小信号映射

```math
\delta x_{k+1}
=
\left(F_x-F_Tg_T^{-1}g_x\right)\delta x_k
+
\left(F_u-F_Tg_T^{-1}g_u\right)\delta u_k.
```

这就是 PIS-IEK 的核心。其创新不在于重新发明 saltation matrix，而在于把混合系统事件面线性化具体落实到四相数字 IQCOT 面积积分事件中：`phase_idx` 不再只是代码里的轮转变量，而是事件面 `g_{q_k}` 的索引；积分 reset 不再是仿真细节，而是 `F_{p_k}` 的一部分；`Lambda_i` 与 `Ton_i` 不再是等价可调旋钮，而是进入不同 Jacobian 列的物理执行量。

本地 PIS-IEK 结构化验证包含 32 行局部灵敏度、10 行模态投影、77 个幅值扫描工况和 80 个四事件 lifted frequency response 工况。关键结论是：当前 wait time 直接受下一触发相 `Lambda_q` 和当前 on-time 相 `Ton_p` 影响；`Lambda` 全范围幅值扫描最大 rms wait 误差为 `0.05025%`，可观测频响工况的 wait 幅值误差低于 `0.004%`。这说明 PIS-IEK 在小扰动、非 skip 的事件域内具有可用的局部预测能力。

## 5. 执行量分类：为什么小信号模型能帮控制设计

PIS-IEK 最直接的工程收益是把执行量通道分清。

`Lambda_diff` 是面积阈值差模。它主要改变事件等待时间和相位间隔，因此适合用于 phase-spacing、纹波抵消和事件节奏微调。已有解析执行量矩阵显示，m2 差模下 `Lambda_diff` 的电流增益约为 `0.0100 mA/(1e-13 V*s)`，非常弱。

`Ton_diff` 是逐相 on-time 差模。它直接改变每相注入能量，因此是主要 DC current-sharing 执行量，但会付出相位间隔扰动代价。解析执行量矩阵显示，m2 模式下 `Ton_diff` 的电流增益约为 `765.07 mA/(0.1 ns)`。用户模型的 Simulink 交叉验证也给出同向证据：`[+4,-4,+4,-4] ns` 的 m2 on-time 扰动引起约 `1.943 A` 的 m2 电流投影，中心差分斜率约 `0.482 A/ns`。

检测延迟差模主要表现为时序扰动，而不是强 DC 均流通道。这对数字控制很关键：如果把检测延迟误差、面积阈值误差和 on-time 修正混成一个黑箱动作，AI 或优化算法会浪费大量搜索在物理通道错误的方向上。PIS-IEK 将这些通道拆开，使 AI 的动作空间可以被约束为

```math
u_k=
\begin{bmatrix}
\Delta\Lambda_{\mathrm{diff}} &
\Delta T_{\mathrm{on,diff}} &
\Delta I_{\mathrm{ph,ref}} &
T_{\mathrm{slew}}
\end{bmatrix}^{T},
```

而不是直接输出 gate command。

## 6. 切载瞬态的混合事件扩展

大幅切载不应被单一线性 Jacobian 覆盖。切载过程至少包含三个阶段。

| 阶段 | 物理过程 | PIS-IEK 作用 | 需要补充的模型 |
|---|---|---|---|
| 第一峰值阶段 | 负载下降，电感电流大于负载电流，输出电容被充电 | 只能提供趋势和事件恢复初值 | 大信号能量/电容约束 |
| skip 阶段 | 过压导致触发事件推迟或脉冲跳跃 | 需要切换到 skip 模式 | 模式变量 `m_k=skip` |
| reentry 阶段 | 电压回落后事件重新触发，相序和均流恢复 | PIS-IEK 最有解释力 | reentry Jacobian、相位恢复指标 |

因此本文采用混合事件扩展：

```math
x_{k+1}=F_{m_k,p_k}(x_k,u_{k-d_k},I_{o,k},T_k),
```

```math
m_k\in\{\mathrm{normal},\mathrm{skip},\mathrm{reentry},\mathrm{saturation}\}.
```

对于第一峰值，可用能量近似给出下界或趋势解释：

```math
\Delta E_L
\approx
\frac{1}{2}\sum_{i=1}^{4}L_i(i_{Li,0}^2-i_{Li,new}^2),
```

```math
\Delta V_{o,pk}
\approx
\sqrt{V_{o,0}^2+\frac{2\Delta E_L}{C_o}}-V_{o,0}.
```

这部分不是 PIS-IEK 的强项，也不应把 PIS-IEK 写成“能精确预测大切载第一峰值”。PIS-IEK 的强项是描述后续事件等待时间、skip/reentry、phase-spacing 标准差、current-sharing 恢复和参考调度对事件序列的影响。

## 7. Simulink 受控动态负载验证

为避免只依赖两段 state-carry surrogate，本文使用用户模型的派生副本构建了受控动态负载验证。原始模型未被修改，所有模型副本位于：

```text
E:/Desktop/codex/output/simulink_iek
```

动态负载模型包括：

```text
four_phase_iek_dynamic_load.slx
four_phase_iek_dynamic_load_refstep.slx
four_phase_iek_dynamic_load_refslew.slx
```

负载命令为

```math
I_{\mathrm{load}}(t)=
\begin{cases}
40\ \mathrm{A}, & t<t_{\mathrm{step}},\\
I_{\mathrm{target}}, & t\ge t_{\mathrm{step}}.
\end{cases}
```

`dynamic_hold` 保持控制器内部 `Iph_ref=40A/4`；`dynamic_instant` 在切载时把 `Iph_ref` 同步阶跃到 `I_target/4`。结果如下。

| Case | Mode | Overshoot | Undershoot | Skip | Settling | Final Vout error | Phase std | Current imbalance |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| `40A -> 20A` | hold | `2.475 mV` | `0.992 mV` | `1` | `NaN` | `+2.058 mV` | `40.094 ns` | `0.166 A` |
| `40A -> 20A` | instant | `2.235 mV` | `13.466 mV` | `1` | `18.256 us` | `-0.435 mV` | `41.954 ns` | `0.252 A` |
| `40A -> 10A` | hold | `4.196 mV` | `4.292 mV` | `1` | `NaN` | `+3.199 mV` | `79.875 ns` | `0.184 A` |
| `40A -> 10A` | instant | `4.196 mV` | `23.830 mV` | `2` | `22.384 us` | `-0.563 mV` | `87.335 ns` | `0.362 A` |
| `40A -> near-0A` | hold | `6.817 mV` | `9.451 mV` | `2` | `NaN` | `+4.413 mV` | `103.595 ns` | `0.569 A` |
| `40A -> near-0A` | instant | `6.817 mV` | `35.750 mV` | `2` | `24.970 us` | `-0.566 mV` | `108.304 ns` | `0.153 A` |

这个对比揭示了一个非常适合 AI 调度的问题：瞬时参考更新能改善最终电压静差，却显著放大切载欠压；保持参考更安全，但会留下较大稳态误差。控制目标不是简单二选一，而是选择合适的参考过渡速度和事件参数，使欠压、skip/reentry、最终静差和均流恢复同时受控。

## 8. 参考斜率调度：从二选一到低维连续动作

为进一步验证参考调度是否有实际价值，本文构建 `four_phase_iek_dynamic_load_refslew.slx`，用 `From Workspace` 信号同时驱动 `IEK_PerPhase_Request/Iph1..4` 和 `IQCOT_Ton_Adapter/Iref_Phase`。参考电流从 `40A/4` 线性过渡到 `I_target/4`：

```math
I_{\mathrm{ph,ref}}(t)=
\begin{cases}
10\ \mathrm{A}, & t<t_{\mathrm{step}},\\
10+\frac{I_{\mathrm{target}}/4-10}{T_{\mathrm{slew}}}(t-t_{\mathrm{step}}),
& t_{\mathrm{step}}\le t<t_{\mathrm{step}}+T_{\mathrm{slew}},\\
I_{\mathrm{target}}/4, & t\ge t_{\mathrm{step}}+T_{\mathrm{slew}}.
\end{cases}
```

扫描 `T_slew=0,5,10,20,40 us`，其中 `0 us` 在实现上采用 `5 ns` 极快线性过渡，因此是近似 instant，而不是数学上绝对零时间。tradeoff score 定义为

```text
score = |final_vout_error_mV| + undershoot_mV + 0.02*phase_std_ns + 2*skip_count
```

在当前扫描网格内，三个切载深度的最佳折中点均为 `40 us`。

| Target load | Best scanned slew | Undershoot | Final Vout error | Skip | Phase std | Score |
|---:|---:|---:|---:|---:|---:|---:|
| `20A` | `40 us` | `1.199 mV` | `-0.434 mV` | `0` | `43.336 ns` | `2.500` |
| `10A` | `40 us` | `5.010 mV` | `-0.549 mV` | `1` | `91.296 ns` | `9.385` |
| `near-0A` | `40 us` | `10.897 mV` | `-0.569 mV` | `2` | `110.846 ns` | `17.684` |

与近似 instant 相比，`40 us` 参考斜率将三种切载的欠压分别降低约 `91.1%`、`79.0%` 和 `69.5%`，同时维持亚毫伏级最终电压误差。特别是 `40A->20A` 工况，估计 skip 从 `1` 降至 `0`。这说明参考斜率不是装饰性参数，而是可被 PIS-IEK 解释、可由 AI 学习的低维调度变量。

需要强调，`40 us` 只能被称为“当前扫描网格中的最佳折中点”，不能写成全局最优。后续若要强化该结论，应围绕 `20-80 us` 做更密集扫描，或直接把 `T_slew` 作为连续动作交给延迟感知 AI 策略学习。

## 9. FPGA AI 延迟的事件域建模

四相 `500 kHz` 设计中，单相开关周期约为

```math
T_{sw}=2\ \mu s.
```

四相交错后，相邻事件间隔约为

```math
T_e=\frac{T_{sw}}{4}=0.5\ \mu s.
```

若 FPGA AI 推理、ADC、commit 和参数同步总延迟为 `tau_AI=1-5 us`，则事件域滞后为

```math
d=\left\lceil\frac{\tau_{AI}}{T_e}\right\rceil=2\sim 10.
```

这意味着 AI 不适合逐事件替代 IQCOT 内环。更合理的定位是中速参数调度器：AI 输出低维参数，IQCOT 内环继续完成快速事件触发。考虑 AI 更新周期 `T_u`，实际进入事件核的动作可写成

```math
u_k^a=u_{\kappa(k)},\qquad
\kappa(k)=\max\{jT_u+d\le k\}.
```

于是延迟感知 PIS-IEK 写成

```math
x_{k+1}
=F_{m_k,p_k}(x_k,u_k^a,I_{o,k},T_k).
```

在某一模式附近线性化，得到

```math
\delta x_{k+1}
=A_{m_k,p_k}\delta x_k
+B_{m_k,p_k}\delta u_k^a
+E_{m_k,p_k}\delta I_{o,k}.
```

这给 AI 训练提供了三个具体帮助。

第一，延迟从连续时间 `us` 量级转写为事件域滞后 `d`，避免训练时用 `u_k`、部署时实际生效 `u_{k-d}` 的不一致。

第二，动作通道被限制在物理可解释参数，如 `Delta Lambda_diff`、`Delta Ton_diff`、`Delta Iph_ref`、`T_slew`，而不是直接开关指令。

第三，可以使用安全投影约束候选动作：

```math
\Pi_{\mathcal U(x)}(u_k)
=\arg\min_{\bar u\in\mathcal U(x)}\|\bar u-u_k\|_2^2,
```

```math
\mathcal U(x)=
\{\bar u:\ |v_{k+1}|\le V_{\max},\
|\phi_{k+1}|\le \Phi_{\max},\
|i_{m2,k+1}|\le I_{\max}\}.
```

该投影不追求理论最优控制的完美解，而是保证 AI 调参不输出破坏 COT 事件秩序的危险动作。

## 10. AI 延迟 surrogate 结果

事件域 surrogate 扫描了 3 个切载工况、5 个 AI 延迟、4 个更新周期、4 类策略和每格 64 个 seeds，总计 `15360` episode。策略含义如下。

| 策略 | 含义 |
|---|---|
| `no_ai` | 不进行参数自适应 |
| `zero_delay_trained` | 训练时假设动作立即生效，部署时带实际延迟 |
| `delay_aware` | 选择动作前预测动作到达时的事件域状态 |
| `delay_aware_projected` | 在 delay-aware 基础上加入 PIS-IEK 安全投影 |

严苛切片 `40A->near-0A, T_update=5us` 中，关键结果如下。

| `tau_AI` | Strategy | Mean violations | Tail phase mean | Tail current mean | Reward |
|---:|---|---:|---:|---:|---:|
| `1us` | `zero_delay_trained` | `17.219` | `12.745 ns` | `430.978 mA` | `-637.369` |
| `1us` | `delay_aware` | `24.422` | `13.459 ns` | `502.307 mA` | `-772.161` |
| `5us` | `zero_delay_trained` | `147.875` | `60.276 ns` | `1095.563 mA` | `-2411.740` |
| `5us` | `delay_aware_projected` | `24.297` | `13.360 ns` | `513.768 mA` | `-802.252` |

这些数据支持两个有边界的结论。第一，延迟感知策略不是在所有延迟下普遍更优；`tau_AI=1us` 时，零延迟训练策略仍有竞争力。第二，当 `tau_AI=5us`、动作跨越约 `10` 个 IQCOT 事件才生效时，零延迟训练和实际部署之间出现明显失配：相对于零延迟训练，延迟感知安全投影把 mean violations 降低约 `83.6%`，tail phase mean 降低约 `77.8%`，tail current mean 降低约 `53.1%`。

因此，本文不应声称“AI 控制总是优于传统 IQCOT”，而应声称：PIS-IEK 让 AI 训练和 FPGA 部署处在一致的延迟事件坐标中，这对微秒级推理延迟下的参数调度尤其重要。

## 11. 讨论：实际价值与相对优势

PIS-IEK 的实际价值体现在三个层次。

第一，它让小信号模型从“平均环路增益”扩展到“事件执行量分类”。对于多相数字 IQCOT，工程问题常常不是不知道如何闭环，而是不知道哪个参数应该调什么量。PIS-IEK 明确 `Lambda_diff` 更像相位/事件节奏执行量，`Ton_diff` 才是强均流执行量，检测延迟主要是时序扰动源，参考斜率是切载安全与最终静差之间的调度量。

第二，它能解释为什么 AI 需要物理约束。没有 PIS-IEK，AI 可能把瞬时降低参考当成“快速消除稳态误差”的好动作；动态 Simulink 结果显示，这种动作会显著放大切载欠压。加入 PIS-IEK 后，AI 可以把 `T_slew`、skip 风险、相位标准差和最终静差同时纳入 reward 或 safety projection。

第三，它能把 FPGA 延迟写进训练环境。微秒级 AI 推理延迟对于人类控制直觉可能不算大，但对于四相 IQCOT 事件链相当于数个到十个事件滞后。PIS-IEK 的事件域表达使这个延迟可以直接写成 `u_{k-d}`，而不是在部署阶段才暴露为不可解释的性能下降。

相比以前只用 He-only 或平均模型，本文模型更优秀的地方不是“能预测所有现象”，而是它更诚实地区分了适用范围：小扰动 normal 区域用 Jacobian；大切载第一峰用能量约束；skip/reentry 用模式切换；AI 延迟用事件滞后；参考更新用斜率调度。这种分层使模型更适合工程设计和论文论证。

## 12. 局限性

本文仍有明确局限。

第一，PIS-IEK 不能单独精确预测大切载第一峰值。第一峰主要由电感剩余能量和输出电容吸收决定，应与大信号能量模型联合使用。

第二，AI 延迟结果来自事件域 surrogate，不等同于完整开关级 AI-in-the-loop Simulink 验证。当前能支持的是“延迟感知训练必要性”和“安全投影可能减少 violation”，不能支持“AI 已在开关级模型中全面优于基线”的强 claim。

第三，参考斜率扫描只有 `0,5,10,20,40 us` 五个点。`40 us` 是当前网格最佳折中点，不是全局最优。

第四，当前研究聚焦四相，不展开任意 N 相推广。这是为了让推导、仿真和毕业设计工作量保持一致。

第五，用户模型中的具体 IQCOT 路径、面积触发副本和解析脚本并不完全等价，因此不同模型之间只应比较物理方向和量级，不应把所有数值斜率强行视为同一参数集下的精确一致。

## 13. 结论

本文围绕四相数字 IQCOT Buck 变换器，形成了一个从面积事件小信号推导到切载仿真验证再到延迟感知 AI 参数调度的完整研究线。基础 IEK 通过移动事件边界线性化保留 off-time 积分区间内的状态记忆，避免 He-only 模型在频率选择性事件响应中的失效；PIS-IEK 进一步将 `phase_idx`、积分 reset、`Lambda_i/Ton_i` 执行量写成四相 event-to-event Jacobian，使小信号模型能够服务于执行量分类和数字预算。

最新 Simulink 验证表明，切载下参考瞬时更新虽然改善最终电压静差，却会显著放大欠压；参考斜率调度把这一二选一问题转化为可学习的低维连续动作。当前扫描中，`40 us` 参考斜率在三个切载深度下均取得最佳折中，并在严苛 `40A->near-0A` 工况中将欠压从近似 instant 的 `35.750 mV` 降至 `10.897 mV`。AI 延迟 surrogate 表明，当 FPGA AI 延迟达到 `5 us`、约跨越 `10` 个 IQCOT 事件时，零延迟训练策略出现显著 train-test mismatch，而延迟感知安全投影显著降低 violation、相位尾部误差和均流尾部误差。

因此，本文最稳妥的创新表述是：PIS-IEK 为四相数字 IQCOT 提供了一个事件域、模式感知、延迟感知且物理约束明确的小信号建模框架。它不替代 IQCOT 内环，也不承诺单独预测所有大信号瞬态；它的价值在于让工程调参和 AI 调度从黑箱搜索转化为有物理通道、有安全边界、有仿真证据支撑的参数优化问题。

## 数据与代码可用性

主要产物位于 `E:/Desktop/codex/output` 与 `E:/Desktop/codex/refine-logs`。

| 类别 | 文件 |
|---|---|
| 参考斜率扫描脚本 | `E:/Desktop/codex/output/iqcot_dynamic_ref_slew_sweep.m` |
| 参考斜率扫描模型 | `E:/Desktop/codex/output/simulink_iek/four_phase_iek_dynamic_load_refslew.slx` |
| 参考斜率汇总 | `E:/Desktop/codex/output/iqcot_dynamic_ref_slew_summary.csv` |
| 最佳折中点汇总 | `E:/Desktop/codex/output/iqcot_dynamic_ref_slew_best_summary.csv` |
| 动态负载验证脚本 | `E:/Desktop/codex/output/iqcot_dynamic_load_validation.m` |
| 动态负载汇总 | `E:/Desktop/codex/output/iqcot_dynamic_load_summary.csv` |
| AI 延迟 surrogate 脚本 | `E:/Desktop/codex/output/iqcot_ai_delay_event_surrogate.py` |
| AI 延迟汇总 | `E:/Desktop/codex/output/iqcot_ai_delay_event_surrogate_summary.csv` |
| 主要图 | `E:/Desktop/codex/output/figures/fig21_ai_delay_event_surrogate.svg`; `fig22_dynamic_load_validation.png`; `fig23_dynamic_ref_slew_sweep.png` |

## 参考文献线索

本草稿沿用前序 v7 文献边界，后续正式论文应在 Zotero/知网/IEEE 中再次核对 BibTeX。

[1] S. M. K. Bari, *A Novel Inverse Charge Constant On-Time Control for High Performance Voltage Regulators*, Ph.D. dissertation, Virginia Tech, 2018.

[2] S. M. K. Bari, Q. Li, and F. C. Lee, “High Frequency Small Signal Model for Inverse Charge Constant On-Time (IQCOT) Control,” ECCE, 2018.

[3] S. M. K. Bari, Q. Li, and F. C. Lee, “Inverse Charge Constant-On-Time Control With Ultrafast Transient Performance,” IEEE JESTPE, 2021.

[4] N. Yan, X. Ruan, and X. Li, “A general approach to sampled-data modeling for ripple-based control-Part I,” IEEE TPEL, 2022.

[5] F. Gabriele et al., “A Unified Sampled-Data Small-Signal Model for a Ripple-Based COT Buck Converter With Arbitrary Ripple Injection Network,” IEEE TCAS-I, 2025.

[6] Y. Li et al., “Multiphase digital integration constant on-time-controlled Buck converter with high-resolution current balance scheme for ultrafast load transient,” IJCTA, 2024.

[7] S. Sridhar and Q. Li, “Multiphase constant on-time control with phase overlapping-Part I: Small-signal model,” IEEE TPEL, 2024.

[8] S. Sridhar and Q. Li, “Multiphase constant on-time control with phase overlapping-Part II: Stability analysis,” IEEE TPEL, 2024.

[9] W.-C. Liu et al., “Small-Signal Analysis and Design of Constant On-Time Controlled Buck Converters With Duty-Cycle-Independent Quality Factors,” IEEE TPEL, 2023.
