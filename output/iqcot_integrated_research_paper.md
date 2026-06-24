# 四相数字 IQCOT Buck 变换器的 PIS-IEK 混合事件小信号模型、切载参考斜率调度与延迟感知 AI 参数优化

## 摘要

面向低压大电流 VRM 的四相交错 Buck 变换器中，COT/IQCOT 控制具有快速瞬态响应和数字实现紧凑的优势，但其触发事件、相序调度、积分复位、脉冲跳跃以及逐相均流执行量共同构成了一个典型的混合事件系统。传统的局部事件斜率模型能够给出直观解释，却容易忽略 off-time 积分区间内由功率级状态积累形成的事件记忆；另一方面，若直接把 AI 调参视为逐脉冲开关控制，则会与 FPGA 上微秒级推理延迟发生时间尺度冲突。本文在已有四相 IQCOT 文献和本地 Simulink/Simscape 开关级模型基础上，形成一个聚焦四相的相索引盐跃积分事件核模型（Phase-Indexed Saltation Integral-Event Kernel, PIS-IEK）。该模型将 IQCOT 面积事件写成移动边界线性化问题，并进一步把 `phase_idx`、积分 reset、`Lambda_i/Ton_i` 执行量和 `normal/skip/reentry/saturation` 模式切换统一到 event-to-event Jacobian 中。最新动态负载验证显示，参考瞬时下调可把最终电压静差压到约 `-0.43` 至 `-0.57 mV`，但会把切载欠压显著放大；进一步的参考斜率扫描表明，在 `20-120 us` 网格中，若不显式惩罚恢复时间，`40A->20A` 和 `40A->10A` 的最佳折中点为 `80 us`，`40A->near-0A` 为 `60 us`。在 near-0A 工况中，近似瞬时参考的欠压为 `35.750 mV`，而 `60 us` 参考斜率将欠压降至 `10.452 mV`，同时保持 `-0.543 mV` 的最终电压误差；若加入 `0.10*settle_time_us` 的恢复时间惩罚，三个切载工况的最佳斜率均移动到 `30 us`。R024 的 45 个局部细扫工况进一步表明，连续斜率的收益不是平滑二次插值可完全描述的：`20A` 的 `35 us` 最近候选因 skip 跳变反而变差，而 `38 us`、`66 us` 等细扫点在当前目标函数下给出小幅改善。R030 进一步把 R029 held-out 结果整理为局部安全带策略：`10A/score_settle005` 在 `tau_AI>=2us` 附近保留 `34us` 短斜率边界，但 `1.5us` 过渡区域采用 `40us`；near0A 强恢复目标使用 `30-38us` 局部带而不是固定 `35us`。事件域 AI 延迟 surrogate 进一步表明，当 `tau_AI=5 us`、约等于 `10` 个 IQCOT 事件时，零延迟训练策略在严苛切载下出现明显 train-test mismatch，平均 violation 从延迟感知安全投影策略的 `24.297` 增至 `147.875`。这些结果支持一个克制但有实际价值的结论：PIS-IEK 不应被表述为替代 IQCOT 内环或精确预测大切载第一峰值的工具，而应作为四相数字 IQCOT 的事件域小信号骨架，用于执行量分类、切载模式解释、参考斜率调度和 FPGA 延迟感知 AI 参数训练。

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

第一轮扫描使用 `T_slew=0,5,10,20,40 us`，其中 `0 us` 在实现上采用 `5 ns` 极快线性过渡，因此是近似 instant，而不是数学上绝对零时间。第二轮密集扫描围绕第一轮最佳区域扩展为 `T_slew=20,30,40,50,60,80 us`，第三轮进一步扫描 `T_slew=80,100,120 us`。三轮合计覆盖 27 个参考斜率开关级 Simulink 工况。基础 tradeoff score 定义为

```text
score = |final_vout_error_mV| + undershoot_mV + 0.02*phase_std_ns + 2*skip_count
```

合并第二、三轮扫描后，若不显式惩罚恢复时间，三个切载深度的最佳折中点如下。

| Target load | Best scanned slew | Undershoot | Final Vout error | Skip | Phase std | Score |
|---:|---:|---:|---:|---:|---:|---:|
| `20A` | `80 us` | `1.094 mV` | `-0.436 mV` | `0` | `37.140 ns` | `2.273` |
| `10A` | `80 us` | `4.631 mV` | `-0.551 mV` | `1` | `82.183 ns` | `8.825` |
| `near-0A` | `60 us` | `10.452 mV` | `-0.543 mV` | `2` | `90.263 ns` | `16.801` |

与近似 instant 相比，密集网格最佳斜率将三种切载的欠压分别降低约 `91.87%`、`80.57%` 和 `70.76%`，同时维持约 `-0.44` 至 `-0.55 mV` 的最终电压误差。相对于第一轮 `40 us` 结果，密集扫描的最佳 score 进一步改善约 `9.09%`、`5.97%` 和 `4.99%`。这说明参考斜率不是装饰性参数，而是可被 PIS-IEK 解释、可由 AI 学习的低维调度变量。

需要强调，`80 us` 或 `60 us` 仍只能被称为“当前扫描网格中的最佳折中点”，不能写成全局最优。更长斜率虽然可能继续降低欠压，但也会增加 settle time；例如 near-0A 的 `120 us` 欠压进一步降至 `9.892 mV`，但 settling time 增至 `71.408 us`，基础 score 仍略劣于 `60 us`。这说明参考斜率调度本质上是多目标问题。

为暴露这一点，本文进一步定义两个恢复时间敏感 score：

```text
score_0.05 = score + 0.05 * settle_time_us
score_0.10 = score + 0.10 * settle_time_us
```

| Target load | Base-score best | `score_0.05` best | `score_0.10` best |
|---:|---:|---:|---:|
| `20A` | `80 us` | `30 us` | `30 us` |
| `10A` | `80 us` | `50 us` | `30 us` |
| `near-0A` | `60 us` | `60 us` | `30 us` |

这组结果把论文主张从“找一个固定最佳斜率”推进为“学习一个目标权重相关的参考斜率调度器”。当设计目标偏向最小欠压时，较慢斜率更有吸引力；当恢复时间也进入惩罚项时，最佳斜率向更快过渡移动。这正是 AI 作为监督层参数调度器的合理切入点。

### 8.1 参考斜率调度器策略验证

为了进一步避免把某个 `T_slew` 误写成固定全局最优，本文将 dense+long sweep 后处理为离线调度器策略评估。比较对象包括固定 `30/40/60/80 us` 参考斜率，以及按负载目标分别最小化 base score、`score+0.05T_settle` 和 `score+0.10T_settle` 的 oracle scheduler。该步骤不新增开关级仿真，而是复用已经完成的 27 个四相 IQCOT Simulink 切载工况。

策略级汇总显示，固定 `80 us` 的平均 base score 为 `9.435`，而按 base score 逐负载选择的 oracle scheduler 采用 `80/80/60 us`，平均 base score 降至 `9.299`。若采用 `score+0.05T_settle` 作为目标，调度器选择 `30/50/60 us`，平均 score 降至 `10.356`，优于固定 `30 us` 的 `10.683` 和固定 `80 us` 的 `11.043`。当 settling penalty 提高到 `0.10` 时，固定 `30 us` 与对应 scheduler 都选择 `30/30/30 us`，平均 score 为 `11.115`。

这个结果的意义不是证明某个 oracle 已经可以直接部署，而是把 AI 的学习目标具体化：AI 监督层应根据负载下降幅度、相位同步状态、skip/reentry 风险和 settling 权重选择参考斜率，而不是寻找单一经验常数。换言之，`T_slew` 更适合被写成 objective-sensitive scheduling variable。

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

### 10.1 延迟感知 AI 监督层训练接口

参考斜率策略评估和 AI 延迟 surrogate 可以合并为一个监督层训练接口。AI 输入特征可写成

```text
z_k = [Delta I_load, alpha_settle, phase_std, skip_flag, current_imbalance, tau_AI],
```

输出动作限定为低维参数 `a_k=[T_slew, Delta Lambda_diff, Delta Ton_diff]`，再通过事件域延迟缓冲进入 PIS-IEK：

```text
a_k^plant = a_{k-d},  d = ceil(tau_AI / T_event).
```

基于 dense+long Simulink sweep，本文已生成 `iqcot_ai_supervisor_training_targets.csv`，将 `3` 个切载目标、`3` 个 settling 权重和 `5` 个 FPGA 延迟上下文组织成 `45` 行监督标签。标签显示，当目标函数从 base score 改为 `score+0.05T_settle` 和 `score+0.10T_settle` 时，`T_slew` 从 `80/80/60 us` 变为 `30/50/60 us` 与 `30/30/30 us`。`tau_AI` 在该表中是部署上下文特征，而不是已完成的开关级延迟仿真维度；其作用是让训练样本和事件域 surrogate 共享 `delay_events=ceil(tau_AI/0.5us)` 的坐标。

这一步把 AI 研究问题进一步收窄为可验证的工程任务：先用表驱动监督层逼近 oracle scheduler，再在 `four_phase_iek_dynamic_load_refslew.slx` 派生模型中加入参数提交延迟，比较固定斜率、表驱动策略和延迟感知安全投影策略的排序是否在开关级波形中保持。只有通过这一步后，才有充分理由训练更复杂的神经网络策略。

### 10.2 表驱动监督层的 `5 us` 参数提交延迟验证

为避免只停留在训练标签设计，本文进一步在派生模型 `four_phase_iek_dynamic_load_refslew.slx` 中执行了表驱动监督层的等效延迟验证。该实验不把神经网络接入开关节点，而是把 AI/table 输出等效为低维参数 `T_slew`，再通过 `Iph_ref_ts` 的起始时刻延迟模拟 FPGA 推理、同步和参数提交时间。固定斜率基线视为预提交策略，参考轨迹从切载时刻开始；表驱动策略在 `t_load_step+5 us` 后才提交参考斜率，相当于 `d=ceil(5us/0.5us)=10` 个四相 IQCOT 事件的动作滞后。

该验证覆盖 `3` 个切载深度和 `5` 类策略，共 `15` 个开关级工况。策略级结果如下：

| 策略 | 选择的 `T_slew` | 平均 base score | 平均 `score+0.05T_settle` | 平均 `score+0.10T_settle` | 平均欠压 | 平均恢复时间 |
|---|---|---:|---:|---:|---:|---:|
| fixed `40 us` | `40/40/40 us` | `9.856` | `10.528` | `11.199` | `5.702 mV` | `13.431 us` |
| fixed `80 us` | `80/80/80 us` | `9.435` | `11.043` | `12.651` | `5.292 mV` | `32.169 us` |
| base-score table | `80/80/60 us` | `8.960` | `10.598` | `12.237` | `4.912 mV` | `32.770 us` |
| `alpha=0.05` table | `30/50/60 us` | `8.383` | `9.657` | `10.931` | `4.925 mV` | `25.477 us` |
| `alpha=0.10` table | `30/30/30 us` | `9.079` | `9.932` | `10.785` | `4.925 mV` | `17.065 us` |

这组结果比零延迟离线排序更有力，但仍需谨慎解释。第一，它支持“表驱动监督层具有开关级可部署性”：在 `5 us` 提交延迟下，表驱动策略没有因动作滞后而劣化到固定斜率之后，`alpha=0.05` 表在 base 和 `0.05` 指标上均优于固定 `40/80 us` 与 base-score table；`alpha=0.10` 表在强恢复时间惩罚下最好。第二，它进一步说明 `T_slew` 的最优选择依赖目标函数，而不是存在单一固定常数。第三，它仍不是神经网络 AI-in-the-loop 或硬件验证，因为策略由查表给出，延迟由参考轨迹起点等效模拟；论文应写成“表驱动监督层延迟验证支持下一步 AI 训练”，而不能写成“AI 控制器已经在硬件中验证优于传统 IQCOT”。

为检查 `5 us` 结果是否只是单一大延迟切片，本文又补充了 `tau_AI=0.5/1/2 us` 的 `45` 个派生开关级 delayed-reference 工况，并与零延迟参考排序合并为延迟敏感性分析。结果显示，base score 的最佳策略随延迟移动：`0 us` 和 `0.5/1 us` 下为 base-score table，`2 us` 和 `5 us` 下为 `alpha=0.05` table；`score+0.05T_settle` 在 `0 us` 下为 `alpha=0.05` table，在 `0.5/1 us` 下转为更快的 `alpha=0.10` table，在 `2/5 us` 下又回到 `alpha=0.05` table；`score+0.10T_settle` 不呈简单单调规律，`0.5/1/5 us` 下偏向 `alpha=0.10` table，而 `2 us` 下 `alpha=0.05` table 的综合分数最低。这个结果把结论进一步收窄为：表驱动监督层的价值不是给出一个固定斜率，也不是给出一个只随延迟单调变化的经验规则，而是把目标函数权重和参数提交延迟同时纳入调度坐标。

### 10.3 可解释 score 回归监督层前置验证

在完成表驱动监督层的 `0.5/1/2/5 us` 参数提交延迟验证后，本文进一步将同一批派生开关级结果整理为一个可解释 AI/回归器前置验证问题。原始数据包含 `60` 个 delayed-reference 开关级工况；按 `base`、`score+0.05T_settle` 和 `score+0.10T_settle` 三个目标函数展开后，形成 `180` 行候选策略打分样本和 `36` 个监督上下文标签。监督层输入为切载幅度、目标函数权重、`tau_AI` 与事件延迟数，输出不直接作用于门极，而是在 `fixed 40us`、`fixed 80us`、base-score table、`alpha=0.05` table 和 `alpha=0.10` table 之间选择低维参考斜率策略。

评价采用 leave-one-tau-out 与 leave-one-target-out 交叉验证，并以 regret 衡量模型选择的策略与当前上下文 oracle 策略之间的差距。leave-one-tau-out 中，最佳基线 `trained_objective_nearest_tau_table` 的 mean regret 为 `0.304`；leave-one-target-out 中，最佳基线 `zero_delay_objective_table` 的 mean regret 为 `0.316`。这说明已有 PIS-IEK 坐标下的目标权重、负载下降幅度和参数提交延迟可以被组织成 score-prediction supervisor 的训练接口，而不必把 AI 直接接入 IQCOT 内环。

更重要的是，这个结果没有给出“AI 全面优于查表”的过强结论。leave-one-tau-out 中，延迟最近邻目标表相对零延迟目标表只降低 `0.013` 的 mean regret；leave-one-target-out 中，零延迟目标表仍是最强基线，ridge score supervisor 虽优于固定斜率，却没有超过该强基线。由于 `36` 个监督上下文里有 `11` 个 oracle 策略并列、`23` 个上下文的一二名差距不超过 `0.25` 分，本文更稳妥的表述应是：可解释监督层能够近似 delayed-reference 策略排序，并显著优于固定斜率基线，但当前数据尚不足以证明其稳定优于零延迟目标表。

该结果仍需谨慎解释。首先，候选动作仍来自离散表驱动策略，尚未证明连续 `T_slew` 回归或神经网络 AI-in-loop 优于表驱动策略。其次，交叉验证样本只有 `36` 个上下文标签，因此应把它写成“可解释监督层可近似已有 delayed-reference 策略排序”的前置证据，而不是“AI 已经完成开关级闭环验证”。它的实际价值在于把下一步 AI 训练目标从黑箱调参收窄为：学习候选低维参数策略的相对 objective score，并在 PIS-IEK 给出的事件延迟坐标中做安全选择。

### 10.4 连续 `T_slew` 动作的分数景观前置分析

R022 的可解释监督层仍在离散候选策略集合中选择动作。为判断连续 `T_slew` 回归是否值得进入下一轮仿真，本文进一步对 dense+long 参考斜率 sweep 做局部连续景观分析。输入数据覆盖 `20/30/40/50/60/80/100/120 us`、三个切载目标和三个目标函数；对每个目标函数，在采样最优点附近三点拟合局部二次曲线，并在 `20-120 us` 内用 `1 us` 网格计算 near-optimal 区间。

结果显示，局部二次插值的最大估计收益为 `0.239` 分，多数目标函数的潜在连续收益低于 `0.05` 或只适合小范围细扫。三个需要新开关级验证确认的候选集中在 `20A` 的 settling-aware 目标和 near-0A 的 `score+0.10T_settle` 目标；例如 `20A` 的 `score+0.05T_settle` 和 `score+0.10T_settle` 都给出约 `34.744 us` 的局部二次候选，near-0A 的 `score+0.10T_settle` 给出约 `34.633 us` 的候选。这些候选点不是新的仿真结果，只能作为下一轮更细 sweep 的建议。

这个结果把连续 AI 动作的定位进一步收窄。连续 `T_slew` 的价值不应被写成“必然大幅优于离散表”，而应写成两个更稳的结论：第一，当前离散网格已经给出较强基线；第二，连续 `T_slew` 更适合作为在 near-optimal 区间内进行平滑调度和安全投影的变量，而不是寻找一个尖锐全局最优点。若后续接入连续动作 AI，应先围绕局部二次候选和 near-optimal 区间追加少量开关级验证点，再训练 `s_phi(z,T_slew)->score` 或 `pi_phi(z)->T_slew`。

### 10.5 R024 局部参考斜率细扫验证

为检查 R023 的插值候选是否能转化为真实开关级证据，本文进一步在派生模型 `four_phase_iek_dynamic_load_refslew.slx` 中追加 `45` 个局部细扫工况。细扫点包括 `32/34/35/36/38 us`，用于验证 `20A` settling-aware 目标和 near-0A 强恢复时间惩罚目标的 `34-35 us` 候选；同时包括 `84/86/88/90/92 us` 和 `62/64/66/68/70 us`，用于检查两个 base-score 次优先候选区域。所有工况均使用同一派生模型、同一受控电流源动态负载、同一指标提取流程；原始 `.slx` 未被修改。

细扫结果给出一个比“验证插值点”更有价值的结论：`T_slew` 分数景观存在由 skip/reentry 和相位标准差造成的非光滑跳变。对于 `20A` 的 `score+0.05T_settle` 和 `score+0.10T_settle`，R023 候选最近点 `35 us` 的 score 分别为 `4.291` 和 `4.338`，明显劣于旧网格 `30 us` 的 `2.493` 和 `2.540`；原因是该点出现 `skip_count=1`。但同一局部带内 `38 us` 恢复为 `skip_count=0`，score 分别降至 `2.417` 和 `2.464`，相对旧网格改善约 `0.076` 分。更宽细扫还发现 `66 us` 在这两个 settling-aware 目标下分别达到 `2.398` 和 `2.445`，比旧网格再改善约 `0.095` 分。这个结果不能写成“34.744 us 被证实为最优”，而应写成“局部细扫支持连续/更细网格有价值，但最优点受事件模式跳变影响”。

near-0A 的强恢复时间惩罚目标更接近 R023 预期。旧网格 `30 us` 的 `score+0.10T_settle` 为 `19.784`；细扫中 `35 us` 为 `19.673`，`38 us` 进一步降至 `19.549`，相对旧网格改善约 `0.235` 分。base-score 次优先区域也显示小幅收益：`20A` base 在 `86 us` 降至 `2.133`，相对旧 `80 us` 改善约 `0.140`；near-0A base 在细扫全网格中 `92 us` 为 `16.581`，相对旧 `60 us` 改善约 `0.220`。这些改善幅度仍是小到中等的局部收益，不支持“连续动作显著碾压离散表”的强 claim。

R024 因此把连续 AI 的训练目标进一步改写为：学习 mode-aware near-optimal band，而不是裸回归一个局部二次最小点。对 AI 监督层而言，`T_slew` 应与 `skip_count_est`、相位间隔标准差、恢复时间权重和参数提交延迟一起进入安全投影：

```text
T_slew^plant = clip(pi_phi(z), B_epsilon(z, m_k, tau_AI)).
```

其中 `B_epsilon` 只能解释为当前模型和当前目标函数下的设计带，不能解释为硬件安全集合或全局最优集合。

### 10.6 R025 mode-aware 连续 `T_slew` score surrogate 与安全投影

R024 给出的最重要信息是：`T_slew` 分数景观不是单纯光滑曲线，局部二次插值会被 skip/reentry 和相位间隔跳变修正。为把这一点转化为 AI 监督层训练接口，本文进一步把 dense+long+fine 数据合并为 `69` 个目标/斜率 plant 行，并按 `base`、`score+0.05T_settle`、`score+0.10T_settle` 展开为 `207` 行 objective-level 样本。构造两个可解释 score surrogate：

```text
s_smooth(target, alpha, T_slew)
```

和

```text
s_mode(target, alpha, T_slew, skip_count_est, phase_std, settle_time).
```

前者故意忽略模式变量，用于模拟裸连续最小化；后者显式纳入 `skip_count_est`、`final_phase_spacing_std_ns` 与 `settle_time_us`，用于模拟 PIS-IEK 建议的 mode-aware 安全投影。当前数据上，平滑模型的 in-sample RMSE 为 `0.855`，mode-aware 模型降至 `0.101`。在 leave-one-target 检查中，两者误差都明显增大，分别为 `10.192` 和 `5.940`，这说明模型不能被写成可跨负载泛化的成熟 AI，只能作为当前四相模型数据上的解释性后处理。

策略层比较进一步说明模式约束的价值。以当前 dense+long+fine 已仿真网格的 oracle 为下界，`discrete_dense_long_table` 的平均 regret 为 `0.163`；裸二次连续最小化的平均 regret 升至 `0.654`，最大 regret 达 `2.429`，原因之一是它会在 `20A` settling-aware 目标中选到带 skip 的坏点。将裸候选裁剪到经验 `best+0.25` near-optimal band 后，平均 regret 降至 `0.101`；进一步在 `best+0.50` 带内加入 skip、phase std 和 settling 约束的 mode-aware safety projection，平均 regret 为 `0.064`，最大 regret 为 `0.235`。这些结果不说明安全投影已经是硬件安全证明，而是说明连续 AI 动作不应裸最小化平滑 surrogate，应通过

```text
T_slew^plant = clip(pi_phi(z), B_epsilon(z,m_k,tau_AI))
```

提交到 IQCOT 参数通道。

R025 的结论边界尤其重要。mode-aware 特征中的 `skip_count_est`、相位标准差和恢复时间目前来自已完成的开关级结果；真实部署中必须由事件状态估计器、快速 surrogate 或保守规则提前给出。因此，R025 支持的是“PIS-IEK 指导连续动作 AI 的 reward shaping 和安全投影设计”，不是“神经网络 AI 已在开关级或硬件中闭环优于查表”。

### 10.7 R026 可部署 risk proxy：从后验指标到监督层接口

R025 仍留下一个审稿人会追问的问题：如果 `skip_count_est`、相位间隔标准差和恢复时间都是仿真后的后验指标，那么它们如何在真实 AI 监督层中使用？为避免把评价量误写成输入量，本文进一步构造 R026 可部署 risk proxy。在线监督层只允许使用

```text
z_k = [target_load_A, load_drop_norm, alpha_settle, tau_AI, delay_events],
candidate T_slew,
```

以及离线校准或短时预测得到的风险 proxy

```text
r_hat(z_k,T_slew) -> [skip-risk, phase-risk, settle-risk].
```

因此提交到 IQCOT 参数通道的动作不再写成后验形式，而写成

```text
T_slew^plant =
Proj_{B_epsilon(z_k,r_hat,tau_AI)}
  argmin_T s_smooth(z_k,T).
```

R026 使用已完成的 dense+long+fine 数据做离线重放，不新增 `.slx` 仿真。它比较了两类 proxy。第一类 `parametric_proxy_only` 只用 `target/load/T_slew/tau_AI` 的光滑回归预测风险；该策略平均 regret 为 `0.857`，最大 regret 为 `2.406`，说明纯光滑 proxy 会重新踩到 R024 暴露的 skip/reentry 非光滑边界。第二类 `calibrated_risk_proxy_projection` 将已完成细扫中的 skip、phase 和 settling 风险整理为可预存的 `r_hat(z,T_slew)` 校准表，再与平滑 score surrogate 组合。该策略在 `9` 个目标/目标函数上下文和 `5` 个 `tau_AI` 设置的离线重放中平均 regret 为 `0.119`，低于旧 `discrete_dense_long_table` 的 `0.163` 和裸平滑连续策略的 `0.654`，但仍弱于后验 `mode_aware_safety_projection` 的 `0.064`。

这组结果给出一个更可落地的创新边界：PIS-IEK 不只是说明 mode-aware 特征有用，还说明这些后验特征应被转化为“可部署 risk proxy 或短时预测接口”。但 R026 仍不是硬件安全集合证明，也不是神经网络 AI-in-loop 结果；它的作用是把下一步派生 Simulink 验证收窄为：将 `r_hat` 表驱动投影接入 `four_phase_iek_dynamic_load_refslew.slx`，检查参数提交延迟下的策略排序是否保持。

### 10.8 R027 proxy table-in-loop：从离线接口到派生模型验证入口

R027 的目的不是再构造一个新的离线 score，而是把 R026 的 `r_hat(z,T_slew)` 接口转成可执行的派生 Simulink table-in-loop 验证矩阵。新增脚本 `iqcot_r027_proxy_table_in_loop_plan.py` 生成完整 `315` 行计划，覆盖 `9` 个目标/目标函数上下文、`5` 个 `tau_AI` 设置和 `7` 类策略：固定 `40us`、固定 `80us`、dense-long table、calibrated risk proxy、near-opt band、posterior mode-aware 上界和裸平滑连续负面对照。优先矩阵保留排序分歧和 proxy regret 较高的 `48` 行，用于先做小范围派生开关级验证。

离线预期排序仍保持 R026 的主要关系：posterior mode-aware projection mean regret 为 `0.064`，near-opt band 为 `0.101`，calibrated risk proxy 为 `0.119`，dense-long table 为 `0.163`，裸连续为 `0.654`。但 R027 明确把 posterior 和 near-opt band 标成不可部署对照，只把 calibrated risk proxy 与 dense-long table 作为部署候选比较。对应 MATLAB runner `iqcot_r027_proxy_table_in_loop_validation.m` 读取 CSV 后，在派生 `four_phase_iek_dynamic_load_refslew.slx` 中生成

```text
Iph_ref(t;T_slew,t_commit)
= ramp(Iph_0 -> Iph_1, start=t_load+t_commit, duration=T_slew),
```

其中固定斜率基线 `t_commit=0`，表驱动/proxy/后验对照使用 `t_commit=tau_AI`。这正是事件域 `u_{k-d}` 在开关级参考通道中的可执行等效形式。

目前已分段完成优先矩阵全部 `48` 个 switching 工况，所有工况均成功。合并后处理显示，dense-long table 与 posterior mode-aware projection 的 mean switching regret 均为 `0.025`，near-opt band 为 `0.257`，calibrated risk proxy 为 `0.283`；固定 `40us` 和 `80us` 分别为 `0.971` 与 `2.171`。按压力上下文统计，proxy 相对 dense-long table 在 `0/8` 个上下文更优、`4/8` 个上下文并列、`4/8` 个上下文更差；离线最佳策略排序只在 `4/8` 个上下文中保持。

这组开关级压力检验修正了 R026 的离线乐观结论：`r_hat` proxy 可以作为可执行监督层接口进入派生模型，但当前校准方式没有在排序分歧上下文中稳定超过 dense-long table。尤其在 `10A/score_settle005` 下，proxy 倾向选择 `62us`，而开关级结果显示 `50us` dense-long table 在 `tau_AI=0/0.5/1us` 下更稳，`tau_AI=2us` 下甚至由 near-opt band 的 `34us` 最优；在 near0A 强恢复时间目标下，proxy 的 `30us` 与 dense-long 多数并列。R027 因此应写成“完成 proxy 接口开关级压力检验，并暴露安全投影需要重标定”，而不是“proxy 已证明开关级优于查表”。

### 10.9 R028 开关级校准的 `B_epsilon` 安全投影

R028 直接回应 R027 暴露的负面边界：如果 `r_hat(z,T_slew)` proxy 离线看似优于查表，但在排序分歧的开关级压力上下文中失败，那么下一步不应扩大 AI claim，而应重标定安全投影集合

```text
B_epsilon(z,r_hat,tau_AI).
```

新增脚本 `iqcot_r028_switching_calibrated_proxy.py` 不运行新的 `.slx`，而是重用 R027 已完成的 `48` 行派生 Simulink priority switching 结果，构造两类 R028 策略。第一类 `r028_dense_anchor_proxy` 是保守可部署规则：若 proxy 候选偏离 dense-long table 超过上下文带宽，则投影回 dense-long 表动作；对于 R027 明确失败的 `10A/score_settle005` 场景，`62us` 被投影回 `50us`。第二类 `r028_switching_guarded_proxy` 是压力集校准候选：在 dense-anchor 基础上，对 `10A/score_settle005/tau_AI>=2us` 临时采用 R027 中表现最好的短斜率 `34us`，对 `near0A/score_settle010/tau_AI=0` 采用 `35us`。第二类规则只能作为 R029 held-out 验证假设，不能写成已泛化的部署策略。

R028 priority replay 的结果如下：旧 `calibrated_risk_proxy_projection` 的 mean switching regret 为 `0.283`，dense-long table 为 `0.025`；保守 `r028_dense_anchor_proxy` 降至 `0.025`，追平 dense-long table；压力校准的 `r028_switching_guarded_proxy` 在同一 `8` 个压力上下文中为 `0.000`。这个 `0.000` 并不是独立泛化证据，因为 guarded 规则正是由 R027 压力点拟合出来的。更稳妥的论文结论是：R028 将 R027 的负面结果转化为一个可部署的保守 safety projection，使 proxy 不再在已知压力上下文中劣于 dense-long 表；而更进取的 delay-guarded 规则需要下一轮未参与校准的派生 Simulink 点验证。

R028 也更新了 R026 的离线重放一致性检查。在 `45` 个 R026 目标/目标函数/延迟上下文上，`r028_dense_anchor_proxy` 的离线 mean regret 为 `0.099`，低于旧 proxy `0.119` 和 dense-long table `0.163`；`r028_switching_guarded_proxy` 为 `0.106`。由于 R027 已经证明离线排序会在 delayed-reference 开关级回放中失配，这个离线结果只能作为一致性检查，不能替代新的派生 Simulink 验证。

### 10.10 R029 held-out 验证：guarded proxy 的局部支持与修正

为避免把 R028 的 `0.000` priority regret 误写成泛化证明，R029 执行了 `21` 个未参与 R028 校准的派生 Simulink held-out 工况。验证矩阵分成两组：第一组针对 `10A/score_settle005`，在 `tau_AI=1.5/2.5/3us` 下比较 `T_slew=34/40/50/62us`；第二组针对 near0A 的 `score_settle010`，在 `tau_AI=0/0.25/0.5us` 下比较 `T_slew=30/35/38us`。所有工况仍使用派生 `four_phase_iek_dynamic_load_refslew.slx` 和延迟 `Iph_ref_ts` 通道，不修改原始模型。

R029 对 `10A/score_settle005` 给出较清晰的局部边界。`tau_AI=1.5us` 时，最佳点是 `40us`，不是 R028 guard 使用的 `34us`，因此短斜率 guard 不应外推到 `2us` 以下；而 `tau_AI=2.5us` 和 `3us` 时，`34us` 均为当前 held-out 候选中的最佳点，支持 R028 中“`tau_AI>=2us` 采用短斜率”的局部规则。旧 proxy 的 `62us` 在三个 10A held-out 上下文中仍然偏差明显，mean regret 达到 `0.806`，这进一步支持 dense-anchor 投影将其排除在可部署带外。

near0A 结果则修正了 R028 的零延迟 guard。R028 在 R027 priority 集合中只比较了 `30us` 与 `35us`，因此选择了 `35us` 作为零延迟恢复 guard；但 R029 加入 R024 细扫发现的 `38us` 后，`tau_AI=0` 和 `0.25us` 下 `38us` 分别为最佳或近似最佳，`tau_AI=0.5us` 下则回到 `30us` 最优。因此 near0A 不应写成固定 `35us` guard，更稳妥的表达是：在强恢复时间目标和很小提交延迟下，应使用 `30-38us` 局部安全带，由 score 或风险 proxy 在带内选择。

R029 的总体 policy-family 汇总也保持了边界意识：`guarded_candidate` 的 mean switching regret 为 `0.041`，`dense_anchor` 为 `0.242`，`old_proxy_failure_probe` 为 `0.806`。这些均为特定 held-out 候选集合上的派生模型结果，不是硬件结论；并且不同 family 出现在不同上下文子集中，不能把均值直接解读为完整部署策略的最终排序。

### 10.11 R030 refined band policy：从 guard 点到局部安全带

R030 不运行新的 `.slx`，而是把 R027 priority replay、R028 重标定、R029 held-out 和 R025/R026 离线网格组织成一个更克制的策略合成步骤。新的代表规则为：`10A/score_settle005` 在 `tau_AI<=1us` 继续采用 dense-anchor，`1.5us` 附近采用 R029 观测到的 `40us` 过渡点，`tau_AI>=2us` 时采用 `34us` 短斜率边界；`near0A/score_settle010` 则把 R028 的固定 `35us` 改写为 `30-38us` 局部安全带，当前代表点在 `tau_AI<0.5us` 取 `38us`，从 `0.5us` 起回到 `30us`。其他上下文仍回退到 R028 dense-anchor projection。

离线一致性重放覆盖 `45` 个目标/目标函数/延迟上下文。R030 refined-band 的 mean regret 为 `0.104`，略低于旧 R028 guarded candidate 的 `0.106`，略高于 R028 dense-anchor 的 `0.099`；这说明 R030 并不是为了在静态离线网格上刷分，而是为了把 R029 的 delayed-reference switching 证据纳入策略边界。更关键的是，在 R027/R029 已知 guard-context 的 `12` 个切换证据条目上，R030 选中行的 mean switching regret 为 `0.000`，对应 dense-anchor 行为 `0.128`。这个结果只能作为“与当前局部切换证据一致”的合成检查，不能写成独立泛化证明。

R030 还从 R027 完整 `315` 行计划中筛出 dense 与 calibrated proxy 不同、但未进入 `48` 行 priority switching 的上下文。共有 `24` 个非优先分歧上下文，其中 `20` 个在离线 score 中 proxy 优于 dense。由此形成的挑战矩阵包含 `30` 行 dense/proxy 成对工况，覆盖 `10A/score_settle010` 的 `30us` vs `32us`、`20A/base` 的 `80us` vs `86us`、以及 `20A/score_settle005` 的 `30us` vs `66us`。这些点的意义是检查 dense-anchor 是否过于保守；在 R030 合成阶段它们只是实验计划，下一小节给出已完成的派生 Simulink 回放结果。

### 10.12 R030 dense-anchor challenge：proxy override 的切换级负校准

为检验上述 `30` 行挑战计划是否真的说明 dense-anchor 过于保守，本文进一步在派生 `four_phase_iek_dynamic_load_refslew.slx` 上完成了全部 delayed-reference 回放，并用 `iqcot_r030_dense_anchor_challenge_postprocess.py` 将三段结果合并，按完整上下文 `(target_label, objective, tau_AI)` 重新计算 regret。该步骤仍不修改原始 `.slx`，也不等同于硬件验证。

结果并不支持“dense-anchor 普遍过保守”的强 claim。在 `15` 个 dense/proxy 成对上下文中，proxy 胜 `7` 个，dense-anchor 胜 `8` 个；dense-anchor 的 mean switching regret 为 `0.186`，proxy 为 `0.574`。离线 pair ranking 只在 `7/15` 个上下文中保持，这说明 event-domain 或离线 score proxy 可以提出候选，但当前排序不足以直接替代 dense-anchor safety projection。

分 motif 看，`10A/score_settle010` 的 `30us` 与 `32us` 更接近局部 near-tie：proxy 在 `tau_AI=0/0.5/2us` 胜出，dense-anchor 在 `1/5us` 胜出，平均 proxy-minus-dense score 仅 `0.009`。`20A/base` 中 `86us` proxy 在 `0/1us` 较好，但 `80us` dense-anchor 在 `0.5/2/5us` 较好，不能作为稳定替换依据。最关键的负样本来自 `20A/score_settle005`：虽然 `66us` proxy 在 `tau_AI=0/1us` 有优势，但在 `0.5/2/5us` 下会引入额外 skip 或更长 settling，平均比 `30us` dense-anchor 差 `1.073` 分。

因此 R030 challenge 的作用是收紧而不是放宽部署边界。它不证明 dense-anchor 是全局最优，但说明当前 `r_hat` proxy 不能在未验证局部带外直接 override dense-anchor。后续 AI 或短时事件 predictor 更合理的形式应是输出候选 score/risk 分布，再经过 `B_\epsilon^{sw}` 投影；尤其是 `20A/score_settle005` 中的大斜率 `66us`，必须先通过 skip/settling 风险预测才能进入可部署动作集。

### 10.13 R031 tightened `B_\epsilon^{sw}`：由负样本收紧的风险投影接口

R031 的目的不是继续扩大 proxy claim，而是把 R030 challenge 的负样本转化为更严格的监督层接口。新增脚本 `iqcot_r031_tightened_bepsilon_sw.py` 不运行新的 `.slx`，而是把 R030 的 `15` 个 dense/proxy 成对上下文整理为 pair-level risk features，并比较 direct proxy override、dense-anchor baseline、naive small-delta rule、R031 tightened projection 和 pair oracle 上界。

校准集重放显示，direct proxy override 的 mean regret 为 `0.574`，dense-anchor baseline 为 `0.186`，单纯允许 `<=2us` 小斜率差 proxy 的规则为 `0.189`，而 R031 tightened projection 为 `0.132`。pair oracle 的 `0.000` 只是非部署上界。这个排序说明：第一，直接 proxy override 在当前挑战集上仍不安全；第二，简单按斜率差距设带宽并不能处理延迟非单调；第三，利用开关级负样本收紧 `B_\epsilon^{sw}` 能形成更合理的下一轮候选，但不能视为独立泛化证明。

R031 的规则层面分成三类。对 `10A/score_settle010`，`30us` 与 `32us` 属于 near-tie delay-sensitive band，R031 只在 R030 已观测到 proxy 胜出的 `tau_AI=0/0.5/2us` 子带中保留候选，并要求下一轮在 `tau_AI=1/5us` 检验 `31/33us`。对 `20A/base`，`86us` proxy 只在部分延迟中优于 `80us` dense-anchor，因此暂阻止直接覆盖，并建议在 `tau_AI=0.5/2/5us` 检验 `82/84us`。对 `20A/score_settle005`，`66us` 被标为 large-jump settling-sensitive 负样本；除非短时事件 predictor 能提前识别低 skip 与低 settling 风险，否则不应重新放入可部署动作集，下一轮应先检验 `38/50/58us` 的中间安全带。

因此，R031 将 AI 监督层接口进一步收窄为

```text
T_slew,plant =
  Proj_{B_\epsilon^{sw}(z_k, r_hat, tau_AI, T_dense)}
  (T_slew,candidate),
```

其中 `T_slew,candidate` 可以由表、轻量回归器或神经网络生成，但最终提交到 IQCOT 参考通道前必须经过 `B_\epsilon^{sw}`。该投影不是硬件安全证书，只是由当前派生 Simulink 负样本校准出来的工程约束。R031 新生成的 `22` 行最小 held-out 验证计划，才是下一步判断 tightened projection 是否过拟合 R030 challenge 的关键。

为了让该矩阵可执行，本文进一步新增 `iqcot_r031_minimal_validation.m`。该 wrapper 复用 R027 delayed-reference runner，并在 `iqcot_r027_proxy_table_in_loop_validation.m` 中加入 `r031_minimal` plan adapter，将 R031 的紧凑验证计划转换成可仿真的 `Iph_ref_ts` 工况。已完成 dry-run：`22` 行计划均成功加载并写出 `iqcot_r027_proxy_table_in_loop_matlab_plan_r031_minimal.csv` 与 `iqcot_r027_proxy_table_in_loop_matlab_dryrun_r031_minimal.md`。该 dry-run 只验证执行接口和计划转换，不运行 Simulink，也不是新的性能证据。下一步应分块运行 `8/8/6` 个派生模型工况，并按相同 `(target_label, objective, tau_AI)` 重算 regret。

随后，R031 最小 held-out 矩阵已按 `8/8/6` 分块完成全部 `22` 行派生 Simulink 回放，并由 `iqcot_r031_minimal_validation_postprocess.py` 与 R030 中对应的 dense baseline 和原 proxy 行合并。上下文级结果显示，R031 best intermediate candidates 在 `3/9` 个上下文中优于 dense baseline，在 `8/9` 个上下文中优于原 R030 proxy；best-family counts 为 dense `6`、R031 intermediate `3`。这不是 R031 全面胜过 dense 的证据，反而说明 tightened `B_\epsilon^{sw}` 必须保持强基线回退。

分上下文看，`10A/score_settle010` 的 near-tie 带具有明显延迟依赖：`tau_AI=1us` 时 dense `30us` 仍优于 `31/33us`，而 `tau_AI=5us` 时 `33us` 优于 dense。`20A/base` 中，`82/84us` 没有实质超过 `80us` dense baseline，虽然中间候选内部呈现 `0.5us` 偏 `82us`、`2/5us` 偏 `84us` 的延迟分歧，因此仍不应直接放行 `86us` proxy。`20A/score_settle005` 则给出最有价值的局部修正：`50us` 在 `0.5/2us` 较好，`38us` 在 `1us` 较好，`58us` 在 `5us` 较好。这说明 `38-58us` 中间带可以成为短时 risk predictor 的候选动作集，但 R030 中的 `66us` proxy 仍不能无条件进入可部署集合。

## 11. 讨论：实际价值与相对优势

PIS-IEK 的实际价值体现在三个层次。

第一，它让小信号模型从“平均环路增益”扩展到“事件执行量分类”。对于多相数字 IQCOT，工程问题常常不是不知道如何闭环，而是不知道哪个参数应该调什么量。PIS-IEK 明确 `Lambda_diff` 更像相位/事件节奏执行量，`Ton_diff` 才是强均流执行量，检测延迟主要是时序扰动源，参考斜率是切载安全与最终静差之间的调度量。

第二，它能解释为什么 AI 需要物理约束。没有 PIS-IEK，AI 可能把瞬时降低参考当成“快速消除稳态误差”的好动作；动态 Simulink 结果显示，这种动作会显著放大切载欠压。加入 PIS-IEK 后，AI 可以把 `T_slew`、skip 风险、相位标准差和最终静差同时纳入 reward 或 safety projection。

第三，它能把 FPGA 延迟写进训练环境。微秒级 AI 推理延迟对于人类控制直觉可能不算大，但对于四相 IQCOT 事件链相当于数个到十个事件滞后。PIS-IEK 的事件域表达使这个延迟可以直接写成 `u_{k-d}`，而不是在部署阶段才暴露为不可解释的性能下降。

相比以前只用 He-only 或平均模型，本文模型更优秀的地方不是“能预测所有现象”，而是它更诚实地区分了适用范围：小扰动 normal 区域用 Jacobian；大切载第一峰用能量约束；skip/reentry 用模式切换；AI 延迟用事件滞后；参考更新用斜率调度。这种分层使模型更适合工程设计和论文论证。

## 12. 局限性

本文仍有明确局限。

第一，PIS-IEK 不能单独精确预测大切载第一峰值。第一峰主要由电感剩余能量和输出电容吸收决定，应与大信号能量模型联合使用。

第二，AI 延迟结果分为多层：事件域 surrogate 支持“延迟感知训练必要性”和“安全投影可能减少 violation”；`0.5/1/2/5 us` 表驱动监督层实验支持“延迟提交的低维参考斜率调度可以在派生开关级模型中运行，并且排序同时依赖目标函数与参数提交延迟”；可解释 score 回归器进一步支持“已有 delayed-reference 策略排序可被监督层近似学习”；连续 `T_slew` 景观后处理说明连续动作更适合作为安全区间内的平滑调度；R026/R027/R028/R029/R030/R031 则把 mode-aware 后验指标降级为可部署 `r_hat` proxy、完成 table-in-loop 压力验证，将失败模式反向用于 `B_epsilon` 重标定，用 held-out 派生工况检查 guard 是否过拟合，并进一步把 guard 点改写为可迭代的局部安全带。R027 的 `48` 行压力矩阵表明，旧 proxy 校准在排序分歧上下文中不稳定优于 dense-long table；R028 的保守 dense-anchor projection 只证明能修复已知压力失败；R029 进一步说明 10A delay guard 有局部支持但 near0A guard 需要改成安全带；R030 先将这些证据整理成 refined-band policy，再用 `30` 行 dense/proxy 成对派生回放检查 dense-anchor 是否过保守。结果显示 proxy 胜 `7/15`、dense-anchor 胜 `8/15`，proxy mean switching regret `0.574` 高于 dense-anchor 的 `0.186`；R031 随后将该负样本收紧为校准候选，并完成 `22` 行 held-out 派生验证。R031 intermediate 在 `3/9` 个上下文优于 dense、`8/9` 个上下文优于原 proxy，说明中间带有价值但仍必须保留 dense fallback。因此这些证据不等同于神经网络 AI-in-the-loop 或硬件验证，不能支持“AI 已在开关级模型或实物中全面优于基线”的强 claim。

第三，参考斜率扫描已经从 `0,5,10,20,40 us` 扩展到 `20,30,40,50,60,80,100,120 us`，并补充了离线调度器策略评估、连续景观后处理、`45` 个 R024 局部细扫工况、R025 mode-aware 后处理、R026 proxy 重放、R027 的 `48` 行优先派生开关级压力矩阵、R028 safety projection 重标定、R029 的 `21` 个 held-out 工况、R030 refined-band 策略合成、R030 `30` 行 dense-anchor challenge 和 R031 `22` 行最小验证矩阵。`80 us`、`60 us`、恢复时间惩罚下的 `30 us`、局部二次候选 `34-35 us`、细扫发现的 `38/66/86/92 us`、R025 的安全投影选择或 R026/R027/R028/R029/R030/R031 的 proxy/band 策略，都只能解释为当前目标函数和当前网格下的候选折中点，不是全局最优。

第四，当前研究聚焦四相，不展开任意 N 相推广。这是为了让推导、仿真和毕业设计工作量保持一致。

第五，用户模型中的具体 IQCOT 路径、面积触发副本和解析脚本并不完全等价，因此不同模型之间只应比较物理方向和量级，不应把所有数值斜率强行视为同一参数集下的精确一致。

## 13. 结论

本文围绕四相数字 IQCOT Buck 变换器，形成了一个从面积事件小信号推导到切载仿真验证再到延迟感知 AI 参数调度的完整研究线。基础 IEK 通过移动事件边界线性化保留 off-time 积分区间内的状态记忆，避免 He-only 模型在频率选择性事件响应中的失效；PIS-IEK 进一步将 `phase_idx`、积分 reset、`Lambda_i/Ton_i` 执行量写成四相 event-to-event Jacobian，使小信号模型能够服务于执行量分类和数字预算。

最新 Simulink 验证表明，切载下参考瞬时更新虽然改善最终电压静差，却会显著放大欠压；参考斜率调度把这一二选一问题转化为可学习的低维连续动作。合并扫描中，`40A->20A` 和 `40A->10A` 在基础 score 下的最佳折中点为 `80 us`，`40A->near-0A` 为 `60 us`；严苛 near-0A 工况的欠压从近似 instant 的 `35.750 mV` 降至 `10.452 mV`。恢复时间惩罚和离线调度器策略评估进一步说明，最优参考斜率随目标权重改变而移动：base-score oracle 采用 `80/80/60 us`，而 `score+0.05T_settle` scheduler 采用 `30/50/60 us`。进一步的 `0.5/1/2/5 us` 表驱动提交延迟开关级验证表明，base-score 最佳策略从小延迟下的 base-score table 转向 `2/5 us` 下的 `alpha=0.05` table；强恢复时间惩罚下则在 `alpha=0.05` 和 `alpha=0.10` table 之间切换。R022 可解释监督层评估又将 `60` 个正延迟工况展开为 `180` 行候选策略打分样本和 `36` 个上下文标签；leave-one-tau-out 下，延迟最近邻目标表的 mean regret 为 `0.304`，比固定 `40 us` 基线低约 `73.2%`，但只比零延迟目标表低 `0.013`。R023 连续 `T_slew` 景观分析显示，局部二次插值最大估计收益仅 `0.239` 分；R024 的 `45` 个局部细扫工况进一步说明，局部二次候选需要开关级验证，且 skip/reentry 离散跳变可能把实际较优点移到 `38 us`、`66 us` 或其他细扫点。R025 在 `207` 行 objective-level 样本上进一步显示，忽略模式变量的裸二次连续最小化平均 regret 为 `0.654`，而加入 near-optimal band 与 mode-aware safety projection 后平均 regret 可降至 `0.064`。因此，连续动作更适合用于 mode-aware near-optimal 区间内的平滑调度和安全投影，而不是作为大幅超越离散表或寻找全局最优点的证据。当前证据支持的是“可解释监督层可近似策略排序并指导连续动作候选”，不是“AI 已全面优于查表”。AI 延迟 surrogate 表明，当 FPGA AI 延迟达到 `5 us`、约跨越 `10` 个 IQCOT 事件时，零延迟训练策略出现显著 train-test mismatch，而延迟感知安全投影显著降低 violation、相位尾部误差和均流尾部误差。

R026 进一步把 R025 的后验 mode-aware 指标降级为可部署 risk proxy 接口：纯参数 proxy 平均 regret 为 `0.857`，说明光滑 `target/load/T_slew` 回归不足以跨越 skip/reentry 模式边界；校准风险表 proxy 离线平均 regret 为 `0.119`，低于旧 dense-long 表 `0.163` 和裸连续策略 `0.654`，但仍弱于后验 mode-aware 投影 `0.064`。R027 已将该 proxy 接口转成 `315` 行离线 table-in-loop 计划，并完成 `48` 行优先派生开关级压力矩阵。结果显示，dense-long table 与 posterior 上界 mean switching regret 均为 `0.025`，calibrated proxy 为 `0.283`，near-opt band 为 `0.257`；proxy 对 dense-long 为 `0` 个上下文更优、`4` 个并列、`4` 个更差。R028 随后将这一负面边界转化为开关级校准的安全投影：保守 `r028_dense_anchor_proxy` 在同一压力集上把 mean switching regret 降至 `0.025`，追平 dense-long table；压力拟合的 `r028_switching_guarded_proxy` 为 `0.000`，但只能作为 R029 held-out 验证候选。R029 已执行 `21` 个 held-out 工况：10A 的 `34us` delay guard 在 `tau_AI=2.5/3us` 下得到局部支持，而 `tau_AI=1.5us` 下 `40us` 更优；near0A 则显示固定 `35us` guard 过窄，应改为 `30-38us` 局部安全带。R030 将这些边界整理成 refined-band policy：在已知 guard-context 合成证据中 R030 选中行的 mean switching regret 为 `0.000`，dense-anchor 为 `0.128`，但该结果是由 R027/R029 证据合成得到，不能当作独立泛化证明。随后完成的 `30` 行 dense/proxy 成对挑战表明，当前 proxy 并没有稳定证明 dense-anchor 过保守；dense-anchor mean switching regret `0.186` 低于 proxy 的 `0.574`，其中 `20A/score_settle005` 的 `66us` proxy 是主要负样本。R031 将该负样本进一步收紧为 tightened `B_\epsilon^{sw}` 原型并完成最小 held-out 验证：`22` 行中间候选全部成功，R031 best intermediate 在 `3/9` 个上下文优于 dense、`8/9` 个上下文优于原 proxy。这进一步说明，本文支持“可部署风险投影接口具有工程可检验性，并可由开关级负面样本和 held-out 样本迭代重标定”，但不能支持“AI/proxy 已经开关级或硬件闭环优于查表”的强结论。

因此，本文最稳妥的创新表述是：PIS-IEK 为四相数字 IQCOT 提供了一个事件域、模式感知、延迟感知且物理约束明确的小信号建模框架。它不替代 IQCOT 内环，也不承诺单独预测所有大信号瞬态；它的价值在于让工程调参和 AI 调度从黑箱搜索转化为有物理通道、有安全边界、有仿真证据支撑的参数优化问题。

## 数据与代码可用性

主要产物位于 `E:/Desktop/codex/output` 与 `E:/Desktop/codex/refine-logs`。

| 类别 | 文件 |
|---|---|
| 参考斜率扫描脚本 | `E:/Desktop/codex/output/iqcot_dynamic_ref_slew_sweep.m` |
| 参考斜率扫描模型 | `E:/Desktop/codex/output/simulink_iek/four_phase_iek_dynamic_load_refslew.slx` |
| 参考斜率五点汇总 | `E:/Desktop/codex/output/iqcot_dynamic_ref_slew_summary.csv` |
| 参考斜率密集汇总 | `E:/Desktop/codex/output/iqcot_dynamic_ref_slew_dense_summary.csv` |
| 长斜率扫描汇总 | `E:/Desktop/codex/output/iqcot_dynamic_ref_slew_long_summary.csv` |
| 恢复时间惩罚分析 | `E:/Desktop/codex/output/iqcot_dynamic_ref_slew_settle_penalty_best.csv` |
| 参考斜率策略评估 | `E:/Desktop/codex/output/iqcot_ref_slew_scheduler_policy_eval.csv` |
| 参考斜率策略细节 | `E:/Desktop/codex/output/iqcot_ref_slew_scheduler_policy_eval_detail.csv` |
| AI 监督层训练标签 | `E:/Desktop/codex/output/iqcot_ai_supervisor_training_targets.csv` |
| AI 监督层验证设计 | `E:/Desktop/codex/output/iqcot_ai_supervisor_validation_design.md` |
| 表驱动监督层验证脚本 | `E:/Desktop/codex/output/iqcot_table_supervisor_ref_slew_validation.m` |
| 表驱动监督层验证计划 | `E:/Desktop/codex/output/iqcot_table_supervisor_validation_plan.csv`; `E:/Desktop/codex/output/iqcot_table_supervisor_validation_plan_matlab.csv` |
| `5 us` 延迟表驱动开关级结果 | `E:/Desktop/codex/output/iqcot_table_supervisor_validation_results.csv`; `E:/Desktop/codex/output/iqcot_table_supervisor_validation_policy_eval.csv` |
| `0.5/1/2 us` 延迟表驱动开关级结果 | `E:/Desktop/codex/output/iqcot_table_supervisor_validation_results_tau0p5_1_2us.csv`; `E:/Desktop/codex/output/iqcot_table_supervisor_validation_policy_eval_tau0p5_1_2us.csv` |
| 表驱动延迟敏感性汇总 | `E:/Desktop/codex/output/iqcot_table_supervisor_delay_sensitivity_by_tau.csv`; `E:/Desktop/codex/output/iqcot_table_supervisor_delay_sensitivity_best_by_tau.csv` |
| 可解释监督层回归器基线 | `E:/Desktop/codex/output/iqcot_ai_supervisor_regressor_baseline.py`; `E:/Desktop/codex/output/iqcot_ai_supervisor_regressor_report.md`; `E:/Desktop/codex/output/iqcot_ai_supervisor_regressor_summary.csv` |
| 可解释监督层数据与图 | `E:/Desktop/codex/output/iqcot_ai_supervisor_regressor_dataset.csv`; `E:/Desktop/codex/output/iqcot_ai_supervisor_regressor_context_labels.csv`; `E:/Desktop/codex/output/figures/fig29_ai_supervisor_regressor_regret.svg` |
| 连续参考斜率景观分析 | `E:/Desktop/codex/output/iqcot_ref_slew_continuous_landscape.py`; `E:/Desktop/codex/output/iqcot_ref_slew_continuous_landscape_report.md`; `E:/Desktop/codex/output/iqcot_ref_slew_continuous_landscape_summary.csv` |
| 连续参考斜率景观图与网格 | `E:/Desktop/codex/output/iqcot_ref_slew_continuous_landscape_grid.csv`; `E:/Desktop/codex/output/figures/fig30_ref_slew_continuous_landscape.svg` |
| R024 局部参考斜率细扫 | `E:/Desktop/codex/output/iqcot_dynamic_ref_slew_fine_sweep.m`; `E:/Desktop/codex/output/iqcot_dynamic_ref_slew_fine_summary.csv`; `E:/Desktop/codex/output/iqcot_ref_slew_fine_sweep_report.md` |
| R024 细扫对比与图 | `E:/Desktop/codex/output/iqcot_ref_slew_fine_best_by_objective.csv`; `E:/Desktop/codex/output/iqcot_ref_slew_fine_candidate_comparison.csv`; `E:/Desktop/codex/output/figures/fig31_ref_slew_fine_sweep.svg` |
| R025 mode-aware 连续斜率后处理 | `E:/Desktop/codex/output/iqcot_mode_aware_slew_surrogate.py`; `E:/Desktop/codex/output/iqcot_mode_aware_slew_surrogate_report.md`; `E:/Desktop/codex/output/iqcot_mode_aware_slew_policy_summary.csv` |
| R025 数据、策略和图 | `E:/Desktop/codex/output/iqcot_mode_aware_slew_dataset.csv`; `E:/Desktop/codex/output/iqcot_mode_aware_slew_policy_eval.csv`; `E:/Desktop/codex/output/figures/fig32_mode_aware_slew_surrogate.svg` |
| R026 可部署 risk proxy 后处理 | `E:/Desktop/codex/output/iqcot_deployable_risk_proxy.py`; `E:/Desktop/codex/output/iqcot_deployable_risk_proxy_report.md`; `E:/Desktop/codex/output/iqcot_deployable_risk_proxy_paper_section.md` |
| R026 proxy 数据、策略和图 | `E:/Desktop/codex/output/iqcot_deployable_risk_proxy_table.csv`; `E:/Desktop/codex/output/iqcot_deployable_proxy_policy_summary.csv`; `E:/Desktop/codex/output/figures/fig33_deployable_proxy_policy.svg` |
| R027 proxy table-in-loop 计划 | `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_plan.py`; `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_plan.csv`; `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_priority_plan.csv`; `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_plan_report.md` |
| R027 派生模型 runner 与分段结果 | `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_validation.m`; `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_results_priority.csv`; `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_results_priority_rows007_018.csv`; `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_results_priority_rows019_030.csv`; `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_results_priority_rows031_048.csv` |
| R027 优先矩阵合并后处理 | `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_postprocess.py`; `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_results_priority_combined.csv`; `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_policy_eval_priority_combined.csv`; `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_combined_report.md`; `E:/Desktop/codex/output/figures/fig35_r027_priority_combined_regret.svg` |
| R028 开关级校准 proxy 后处理 | `E:/Desktop/codex/output/iqcot_r028_switching_calibrated_proxy.py`; `E:/Desktop/codex/output/iqcot_r028_switching_calibrated_proxy_report.md`; `E:/Desktop/codex/output/iqcot_r028_switching_calibrated_proxy_paper_section.md`; `E:/Desktop/codex/output/figures/fig36_r028_switching_calibrated_proxy.svg` |
| R028 策略、失败分析和离线回放 | `E:/Desktop/codex/output/iqcot_r028_switching_calibrated_policy_eval_priority.csv`; `E:/Desktop/codex/output/iqcot_r028_switching_calibrated_policy_summary_priority.csv`; `E:/Desktop/codex/output/iqcot_r028_context_failure_analysis.csv`; `E:/Desktop/codex/output/iqcot_r028_offline_replay_all_contexts.csv` |
| R029 held-out guard 计划和 runner | `E:/Desktop/codex/output/iqcot_r029_heldout_guard_plan.py`; `E:/Desktop/codex/output/iqcot_r029_guarded_heldout_plan.csv`; `E:/Desktop/codex/output/iqcot_r029_heldout_guard_validation.m`; `E:/Desktop/codex/output/iqcot_r029_guarded_heldout_plan_report.md` |
| R029 held-out guard 结果 | `E:/Desktop/codex/output/iqcot_r029_heldout_guard_results_combined.csv`; `E:/Desktop/codex/output/iqcot_r029_heldout_guard_policy_summary_combined.csv`; `E:/Desktop/codex/output/iqcot_r029_heldout_guard_context_summary_combined.csv`; `E:/Desktop/codex/output/iqcot_r029_heldout_guard_combined_report.md`; `E:/Desktop/codex/output/figures/fig38_r029_heldout_guard_combined.svg` |
| R030 refined-band 策略合成 | `E:/Desktop/codex/output/iqcot_r030_refined_band_policy.py`; `E:/Desktop/codex/output/iqcot_r030_refined_band_policy_report.md`; `E:/Desktop/codex/output/iqcot_r030_refined_band_paper_section.md`; `E:/Desktop/codex/output/figures/fig39_r030_refined_band_policy.svg` |
| R030 策略表和挑战计划 | `E:/Desktop/codex/output/iqcot_r030_refined_band_policy_eval.csv`; `E:/Desktop/codex/output/iqcot_r030_refined_band_switching_evidence.csv`; `E:/Desktop/codex/output/iqcot_r030_dense_anchor_challenge_candidates.csv`; `E:/Desktop/codex/output/iqcot_r030_dense_anchor_challenge_plan.csv` |
| R030 挑战计划 runner 与结果 | `E:/Desktop/codex/output/iqcot_r030_dense_anchor_challenge_validation.m`; `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_validation.m` 的 `planMode="r030_challenge"`; `E:/Desktop/codex/output/iqcot_r030_dense_anchor_challenge_postprocess.py`; `E:/Desktop/codex/output/iqcot_r030_dense_anchor_challenge_results_combined.csv`; `E:/Desktop/codex/output/iqcot_r030_dense_anchor_challenge_report.md`; `E:/Desktop/codex/output/figures/fig40_r030_dense_anchor_challenge.svg` |
| R031 tightened `B_epsilon^sw` 后处理与验证计划 | `E:/Desktop/codex/output/iqcot_r031_tightened_bepsilon_sw.py`; `E:/Desktop/codex/output/iqcot_r031_pair_risk_features.csv`; `E:/Desktop/codex/output/iqcot_r031_tightened_bepsilon_policy_summary.csv`; `E:/Desktop/codex/output/iqcot_r031_tightened_bepsilon_rules.csv`; `E:/Desktop/codex/output/iqcot_r031_minimal_validation_plan.csv`; `E:/Desktop/codex/output/iqcot_r031_tightened_bepsilon_report.md`; `E:/Desktop/codex/output/figures/fig41_r031_tightened_bepsilon.svg` |
| R031 最小 held-out runner dry-run | `E:/Desktop/codex/output/iqcot_r031_minimal_validation.m`; `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_validation.m` 的 `planMode="r031_minimal"`; `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_matlab_plan_r031_minimal.csv`; `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_matlab_dryrun_r031_minimal.md` |
| R031 最小 held-out 派生验证结果 | `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_results_r031_minimal_rows001_008.csv`; `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_results_r031_minimal_rows009_016.csv`; `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_results_r031_minimal_rows017_022.csv`; `E:/Desktop/codex/output/iqcot_r031_minimal_validation_postprocess.py`; `E:/Desktop/codex/output/iqcot_r031_minimal_validation_context_summary.csv`; `E:/Desktop/codex/output/iqcot_r031_minimal_validation_report.md`; `E:/Desktop/codex/output/figures/fig42_r031_minimal_validation.svg` |
| 密集最佳折中点汇总 | `E:/Desktop/codex/output/iqcot_dynamic_ref_slew_dense_best_summary.csv` |
| 动态负载验证脚本 | `E:/Desktop/codex/output/iqcot_dynamic_load_validation.m` |
| 动态负载汇总 | `E:/Desktop/codex/output/iqcot_dynamic_load_summary.csv` |
| AI 延迟 surrogate 脚本 | `E:/Desktop/codex/output/iqcot_ai_delay_event_surrogate.py` |
| AI 延迟汇总 | `E:/Desktop/codex/output/iqcot_ai_delay_event_surrogate_summary.csv` |
| 主要图 | `E:/Desktop/codex/output/figures/fig21_ai_delay_event_surrogate.svg`; `fig22_dynamic_load_validation.png`; `fig23_dynamic_ref_slew_sweep.png`; `fig23_dynamic_ref_slew_dense_sweep.png`; `fig24_ref_slew_settle_penalty.png`; `fig25_ref_slew_scheduler_policy_eval.png` |

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
## R032：短时风险预测接口与延迟感知 `B_\epsilon^{sw}` 投影

基于 R031 的 `22` 行最小 held-out 派生 Simulink 结果，本文进一步将
`B_\epsilon^{sw}` 从人工规则表整理为短时风险预测接口。该接口不让 AI 直接提交
最终 `T_slew`，而是先给出候选分数或候选分布，再由
`r_hat(z_k,T_slew,tau_AI,recent_phase_state)` 估计 skip、settling 和
phase-spacing 风险，最后经过安全投影得到 plant 侧参数：

```text
T_slew,plant = Proj_B(T_slew,candidate; z_k, tau_AI, r_hat, T_dense)
```

在 R031 已知上下文上，R032 拟合投影的 mean regret 为
`0.000`，dense fallback 为 `0.337`，
direct proxy override 为 `1.107`。这个结果只能说明
R032 规则与 R031 局部证据一致，不能写成独立泛化证明。更有信息量的是
leave-one-tau nearest-neighbor stress policy 的 mean regret 为
`0.589`，说明仅按 `tau_AI` 近邻插值会在
`20A/score_settle005` 一类非光滑边界上失败；因此短时 predictor 需要显式处理
skip/reentry 和 settling 风险，而不是把 `T_slew` 当作平滑连续变量直接回归。

R032 的当前可部署边界为：`10A/score_settle010` 保留 `30/33us` 延迟敏感近似并列带；
`20A/base` 保持 `80us` dense fallback，`82/84us` 仅作为候选探针，继续阻止
`86us` direct override；`20A/score_settle005` 将 `38/50/58us` 作为中间候选带，
但继续阻止 `66us` 直接覆盖，除非未来短时风险预测器能在新的派生 Simulink 或
硬件/HIL 验证中证明低 skip/settling 风险。AI 在这里仍只是监督层参数调度器，
不替代 IQCOT 内环，也不构成硬件验证。
## R033 派生 Simulink 验证：delay-aware `B_epsilon^sw` 的边界修正

在 R032 将 R031 结果整理为 `q_phi/r_hat/B_epsilon^sw` 接口之后，本文进一步执行了 `31` 行派生 Simulink delayed-reference 验证。验证仍只使用 `output/simulink_iek` 下的派生模型，不修改原始 `.slx`，也不构成硬件验证。该轮实验的价值在于把 R032 的已知上下文拟合规则放到新的延迟边界点上检查，从而修正可部署安全投影的局部边界。

结果显示，非 dense 候选在 `4/7` 个上下文中成为当前候选集最优，但这种优势具有明显的目标函数和延迟依赖性。`10A/score_settle010` 形成 `30-34 us` 的 near-tie 候选带：`tau_AI=2 us` 时 `32 us` 最优，`tau_AI=3 us` 时 `33 us` 最优，但各候选差距较小且均出现一次 skip，因此不能写成尖锐点最优。`20A/base` 中，`86 us` 在 `tau_AI=1 us` 的 base score 下略优于 `80 us`，但在 `tau_AI=3 us` 下变差，且 settling 更长；因此它只能作为 objective-dependent probe，而不是被全局解除阻断。最关键的是 `20A/score_settle005`：`tau_AI=0.75 us` 时 `30 us` 最优且 `66 us` 触发 skip，`tau_AI=1.5 us` 时 `50 us` 最优且 `30 us` 触发 skip，`tau_AI=3 us` 时又回到 `30 us` 最优。这说明安全投影需要一个窄的延迟过渡口袋，而不是简单的 `tau_AI` 近邻插值或 proxy 直接覆盖。

因此，R033 对论文主张的强化不是“AI/proxy 已优于查表”，而是更谨慎地说明：PIS-IEK 可以把短时 skip、settling 与相位风险转化为监督层安全投影边界；AI 或表驱动监督层只产生候选 score/risk，最终提交给 IQCOT 内环的 `T_slew` 必须经过 delay-aware `B_epsilon^sw` 投影。`66 us` 负控在当前派生模型中仍不能作为直接覆盖动作，除非后续短时风险预测器或 HIL/硬件验证证明其风险可控。
## R034 可部署短时风险接口：由 R033 边界修正到 `q_phi/r_hat/B_epsilon^sw`

基于 R033 的 `31` 行派生 Simulink 边界验证，本文进一步将局部结论整理为可部署风格的短时风险接口。该接口由三部分组成：候选评分 `q_phi(z_k,T_slew,tau_AI)`、风险估计 `r_hat(z_k,T_slew,tau_AI)`，以及最终安全投影 `B_epsilon^sw`。需要强调的是，R034 不是新的硬件实验，也不是神经网络闭环控制；它是把已有派生模型证据转成监督层参数调度接口和下一轮验证矩阵。

R034 的核心修正是：`T_slew` 的可提交集合不能只随 `tau_AI` 平滑移动，而必须识别 skip/settling 模式边界。对于 `10A/score_settle010`，接口保留 `30-34 us` near-tie candidate band；对于 `20A/base`，`86 us` 只保留为 base objective 下的候选探针，plant 侧默认仍回到 `80 us` fallback；对于 `20A/score_settle005`，接口在 `tau_AI≈1.5 us` 附近形成 `50 us` transition pocket，但在口袋外回到 `30 us` fallback，并继续阻止 `66 us` 直接覆盖。

为了检验该 transition pocket 是否只是单点偶然，R034 生成了 `20` 行下一轮派生 Simulink 细扫计划，覆盖 `tau_AI=1.0/1.25/1.75/2.0 us` 与 `T_slew=38/46/50/54/58 us`。因此，R034 对论文主张的贡献是把 PIS-IEK 的事件域小信号思想落成“候选生成 + 风险预测 + 安全投影 + 最小验证矩阵”的闭环研究流程，而不是宣称 AI/proxy 已经全局优于查表或完成硬件验证。
## R034 部分派生验证：从固定 `50us` 口袋到移动 transition ridge

R034 原先基于 R033 的 `tau_AI=1.5us` 结果，将 `20A/score_settle005` 写成 `50us` transition pocket。为了检查该口袋是否只是单点现象，本文追加运行了两个最小派生 Simulink 边界块：`tau_AI=1.25us` 与 `tau_AI=1.75us`，每个延迟下比较 `38/46/50/54/58us`。结果显示固定 `50us` 假设需要修正：`tau_AI=1.25us` 时 `46us` 最优，而 `50us` 触发 skip 且 regret 达 `2.568`；`tau_AI=1.75us` 时 `54us` 最优，`46us` 反而触发 skip。结合 R033 的 `tau_AI=1.5us -> 50us` 锚点，局部最优候选更像一条随延迟移动的 transition ridge，而不是固定口袋。

因此，R034 对监督层接口的修正是：`q_phi` 可用局部斜脊近似生成候选，例如 `T_ridge(tau_AI)≈26+16 tau_AI us`，但 `r_hat` 必须继续检查 skip 与 settling 风险，最终仍经 `B_epsilon^sw` 投影和 dense fallback 提交。该公式目前只由三个派生模型点支撑，剩余 `tau_AI=1.0us` 与 `2.0us` 的细扫仍需完成；不能把它写成全局最优规律或硬件验证结论。
## R034 完整派生验证：`20A/score_settle005` 的 folded transition band

在 R034 的完整细扫中，本文完成了 `20A/score_settle005` 过渡口袋的全部 `20` 行派生 Simulink delayed-reference 验证，并与 R033 的 `tau_AI=1.5us` 锚点合并分析。结果否定了“固定 `50us` 口袋”作为一般局部规则：当前候选集中最优动作序列为 `tau_AI=1.0us -> 38us`、`1.25us -> 46us`、`1.5us -> 50us`、`1.75us -> 54us`、`2.0us -> 46us`。其中 `tau_AI=1.0us` 时 `46us` 以上候选均触发 skip；而 `tau_AI=2.0us` 时 `46us` 最优、`50us` 近似并列，但 `54/58us` 因 settling 变长而退化。

这说明过渡集合不是简单随 `tau_AI` 单调移动的 ridge，而是由 skip/reentry 与 settling 边界共同折叠出的局部安全带。对 AI 监督层而言，这个结果比单点最优更有价值：它要求 `q_phi` 输出候选带，`r_hat` 显式预测 skip/settling 风险，最终由 `B_epsilon^sw` 投影提交到 IQCOT 参数通道。该结论仍然只来自派生 Simulink，不应写成硬件验证或 `T_slew` 全局最优证明；它支持的是“PIS-IEK 能把非光滑事件风险转化为可验证的安全投影边界”。

## R035 folded-band 可部署投影：候选带与 plant commit 的分离

R035 对 R034 的结论做了审稿式收束。R034 的 `38/46/50/54/46us` 序列应被表述为 `20A/score_settle005` 在过渡候选集内的 folded transition candidate band，而不是完整可部署的 plant commit 序列。原因是 R034 细扫主要比较 `38/46/50/54/58us` 过渡候选，部分延迟点并未与 dense fallback `30us` 成对比较；而 R031/R033 的 dense-inclusive 证据显示，在 `tau_AI=2us` 等位置，保守 `30us` fallback 仍应优先于 transition probe。

因此，R035 将监督层接口写成三段式：`q_phi(z_k,T_slew,tau_AI)` 负责生成候选分数或候选带，`r_hat(z_k,T_slew,tau_AI,recent_event_state)` 负责预测 skip、settling 与 phase-spacing 风险，最终由 `B_\epsilon^{sw}` 结合 dense fallback 决定 plant 侧提交值。当前可部署写法为：`10A/score_settle010` 保留 `30-34us` near-tie 候选带；`20A/base` 继续以 `80us` 为 plant fallback，`86us` 只作为目标函数相关探针；`20A/score_settle005` 将 folded band 作为候选生成器，同时继续阻止 `66us` direct override，并在缺少 dense 成对证据的位置保持 candidate-only 状态。

这个修正降低了论文的过度表述风险，也提升了创新点质量：PIS-IEK 的价值不是给出一个万能斜率点，而是把非光滑事件风险转化为可验证、可迭代收紧的安全投影边界。R035 输出包括 `iqcot_r035_folded_band_policy_surface.csv`、`iqcot_r035_folded_band_rule_table.csv`、`iqcot_r035_reviewer_claim_audit.csv`、`iqcot_r035_folded_band_projection_report.md` 与 `fig48_r035_folded_band_projection.svg`。这些仍是后处理和派生 Simulink 证据整理，不构成硬件验证或全局最优证明。
<!-- R036_DENSE_PAIR_BOUNDARY -->

### R036 dense-paired boundary validation

R035 left two folded-band delays in a candidate-only state because the `30us`
dense fallback had not yet been co-tested at the same AI commit delay.  R036
therefore executed two additional derived-Simulink delayed-reference cases for
`20A/score+0.05T_settle`: `tau_AI=1.25us, T_slew=30us` and
`tau_AI=1.75us, T_slew=30us`.  In the paired comparison, the dense fallback
scores are `4.989` and
`4.317`, while the corresponding folded probes
`46us` and `54us` score `2.146` and
`2.142`.  The improvement is accompanied by
removing one estimated skip and reducing phase-spacing dispersion in both
contexts.

This result upgrades `46us` at `tau_AI=1.25us` and `54us` at
`tau_AI=1.75us` from pending folded probes to locally dense-paired candidates
for the current four-phase derived model and objective.  The claim remains
bounded: R036 is not hardware/HIL validation, does not imply a global
`T_slew` optimum, and does not make the AI supervisor a replacement for the
IQCOT inner event loop.  Its role is to calibrate the
`q_phi/r_hat/B_epsilon^sw` supervision path by showing where the dense fallback
is genuinely too conservative and where it must remain active.
<!-- R037_SHORT_HORIZON_RHAT -->

### R037 short-horizon `r_hat` predictor prototype

After R036 upgraded `46us@1.25us` and `54us@1.75us` to locally dense-paired
folded candidates, the remaining modeling question is how to express this
boundary in a deployable AI supervisor without using future simulation metrics
as inputs.  R037 therefore merges R031/R033/R034/R036 derived-Simulink rows for
`20A/score+0.05T_settle` into a short-horizon risk table.  The predictor input
contains only context and candidate quantities, plus a `q_phi` folded-band
prior; the labels are `skip`, `settling` and `phase` risks observed in the
switching replay.

The resulting local replay shows that a risk-gated projection can represent
the intended supervision path:

```text
q_phi(z_k,T_slew,tau_AI) -> candidate band
r_hat(z_k,T_slew,tau_AI,recent_event_state) -> risk vector
T_slew,plant = Proj_{B_epsilon^sw}(candidate; T_dense,r_hat)
```

Across the current local contexts, dense fallback mean regret is
`1.116`, the folded prior mean regret is `0.020`, and the final
R037 representative projection mean regret is `0.000` after applying the
dense-inclusive foldback guard around `tau_AI=2us`.  The posterior safe
upper-bound obtained with the same risk gate is `0.054`, and the leave-one-delay
risk gate rejects the observed oracle in `1` context.  These values should be
read as current local derived-model consistency checks, not as independent
generalization proof.  The important contribution is conceptual and
methodological: PIS-IEK turns non-smooth skip/settling/phase phenomena into
explicit risk labels and a minimal validation plan, so an AI supervisor can be
trained to propose candidates while a switching-calibrated projection layer
protects the IQCOT inner loop.

<!-- R038_MINIMAL_EXTRAPOLATION_VALIDATION -->

### R038 minimal extrapolation validation

To test whether the R037 short-horizon `r_hat` interface overfits the observed
folded-band anchors, R038 executes nine additional derived-Simulink
delayed-reference cases around the local boundaries. Around `tau_AI=1.25us`,
the `42/44us` left-neighbor probes remain worse than the previously validated
`46us` folded commit. Around `tau_AI=1.75us`, the `52/56us` probes remain worse
than `54us`. Around the center pocket, `46us@1.5us` triggers a skip event and
`54us@1.5us` has longer settling, so the existing `50us` anchor remains the
better local candidate.

The only boundary that changes is `tau_AI=2.0us`. The new `44/48us` probes are
near-tied with the old dense-inclusive `30us` fallback; `48us` is lower than
`30us` by approximately `0.020` score in the current objective. This does not
justify replacing the dense fallback globally. The safer wording is that R038
turns the `tau_AI=2us` rule from a hard `30us` fallback into a local
`30/44/48us` foldback near-tie band that still requires `B_epsilon^sw`
projection and further validation before deployment.

## R039 PR-ECB 大信号第一峰边界：与 PIS-IEK 的职责分离

R039 在 R038 小信号/恢复阶段验证之后，新增了相分辨能量-电荷边界模型 PR-ECB 的第一版派生 Simulink 验证。脚本 output/iqcot_r039_pr_ecb_large_signal_probe.m 只加载 output/simulink_iek/four_phase_iek_dynamic_load_refslew.slx，不保存模型，并导出第一峰附近的 Vout、IL1..IL4、QH1..QH4、Iload 和 Iph_ref 波形快照。

在 40A->20A、score_settle005 的 5 个 delayed-reference 工况中，包括 R038 的 46/50/54us 局部锚点以及 tau_AI=2us 的 30/48us foldback near-tie 对照，PR-ECB 得到相同的第一峰风险：能量边界约 4.350 mV，电荷+ESR 边界约 3.903 mV，派生 Simulink 第一峰约 2.235 mV；若 Delta V_allow=10 mV，则 r_E=0.435。结果相同是合理的：这些工况具有相同切载瞬间、相状态和电感电流，而第一峰约在切载后 0.534us 出现，早于 1.25us 以上的 AI 参考斜率提交动作。

因此，R039 的科研意义不是用 PR-ECB 对 T_slew 候选重新排序，而是把大切载第一峰风险从 PIS-IEK 的 normal/quasi-normal 事件恢复模型中分离出来。PR-ECB 提供第一峰风险特征 r_E 和安全边界，PIS-IEK、r_hat 与 B_epsilon^sw 继续负责 post-peak 的 skip/reentry、phase spacing、settling 和 T_slew 部署。该结果仍然只是派生 Simulink 与离线后处理证据，不是硬件验证，也不说明 PIS-IEK 能精确预测大切载第一峰。
