# Derivation Package

## Target

推导并组织四相数字 IQCOT Buck 的 PIS-IEK 小信号模型，使其能够解释：

1. IQCOT 面积事件如何由移动事件边界线性化得到动态积分事件核；
2. 四相 `phase_idx/reset` 如何进入 event-to-event Jacobian；
3. 切载下 `normal/skip/reentry/saturation` 模式如何扩展小信号模型边界；
4. FPGA AI 延迟和参考斜率如何作为事件域参数进入训练模型。

## Status

COHERENT AFTER REFRAMING / EXTRA ASSUMPTION

原始目标若表述为“一个小信号模型精确预测所有切载瞬态”，则不成立。经重构后，目标改为“一个 normal 区域局部小信号模型，加上 skip/reentry 混合事件扩展和大信号能量边界”。在这个目标下推导是自洽的。

## Invariant Object

不变量对象不是输出电压峰值，也不是某一个局部斜率，而是事件到事件映射：

```math
\mathcal P:\ (x_k,u_k,I_{o,k},m_k,p_k)\mapsto x_{k+1}.
```

所有推导都围绕该映射展开。输出电压、相位间隔、均流误差、事件等待时间和 skip 次数都作为该映射的观测量或模式结果，而不是替代顶层对象。

## Assumptions

- 研究对象限定为四相交错 Buck / 数字 IQCOT，不在本文推广任意 N 相。
- 在 normal 小扰动区域，事件之间的功率级可在工作点附近线性化。
- 面积事件面满足 `g_T != 0`，即事件边界横截；若 `g_T` 接近 0 或事件被 blanking/饱和约束主导，则应切换模式。
- PIS-IEK 的 Jacobian 描述局部事件扰动，不用于单独预测大切载第一峰。
- skip/reentry 作为离散模式变量处理，而不是强行纳入同一个线性矩阵。
- AI 不直接输出 gate command，而输出低维参数调度量。

## Notation

- `x_k`：第 `k` 个事件前后的事件域状态，可包含输出电压扰动、相电流扰动、积分器状态、相位间隔状态等。
- `p_k=k mod 4`：当前 on-time 相索引。
- `q_k=(p_k+1) mod 4`：下一触发相索引。
- `T_k`：第 `k` 个事件等待时间或 off-time 事件间隔。
- `Lambda_i`：第 `i` 相面积阈值。
- `Ton_i`：第 `i` 相 on-time 命令或 trim 后导通时间。
- `m_k`：事件模式，属于 `{normal, skip, reentry, saturation}`。
- `tau_AI`：AI 推理与参数提交总延迟。
- `T_e`：四相事件平均间隔，约为 `T_sw/4`。
- `d=ceil(tau_AI/T_e)`：AI 延迟对应的事件滞后。

## Derivation Strategy

推导采用四层结构：

1. 从单事件面积条件出发，得到移动边界线性化公式；
2. 将事件时间扰动代回功率级状态更新，得到 IEK 动态事件核；
3. 将单事件推广到四相 `p_k/q_k` 索引，得到 PIS-IEK saltation-corrected map；
4. 对切载和 AI 延迟引入模式变量与动作滞后，形成混合事件训练模型。

## Derivation Map

1. 面积事件条件 `F=0` 决定事件时间 `T_k`。
2. `delta F=0` 给出 `delta T_k` 与 `delta x_k, delta Lambda_k` 的关系。
3. 状态更新 `delta x_{k+1}=A_d delta x_k+B_T delta T_k+B_u delta u_k` 将事件时间扰动反馈到下一事件状态。
4. 四相系统中，事件面不是单一 `g`，而是 `g_{q_k}`；状态更新不是单一 `F`，而是 `F_{p_k}`。
5. `normal` 模式下可使用局部 Jacobian；切载导致 `skip/reentry` 时切换 `F_m`。
6. AI 动作进入模型时不是 `u_k`，而是 `u_{k-d}` 或保持后的 `u_k^a`。

## Main Derivation

### Step 1. 面积事件定义

第 `k` 次 IQCOT off-time 触发事件定义为：

```math
F_k(x_k,T_{off,k},\Lambda_k)
=\int_0^{T_{off,k}} h(x_k,\tau)d\tau-\Lambda_k=0.
```

典型 IQCOT 面积核为：

```math
h(t)=v_c(t)-R_i i_L(t).
```

该式是定义，不是近似。

### Step 2. off-time 状态演化

在工作点附近，off-time 内功率级采用线性化近似：

```math
\dot{x}=A_{off}x+B_{off}u,
\qquad
h(t)=C_h x(t)+D_hu(t).
```

由状态转移矩阵得到：

```math
x(\tau)=e^{A_{off}\tau}x_k
+\int_0^\tau e^{A_{off}(\tau-s)}B_{off}u(s)ds.
```

这是在小扰动工作点附近的近似，不是大信号全局模型。

### Step 3. 移动事件边界线性化

对 `F_k=0` 做一阶扰动：

```math
\delta F
=F_x\delta x_k+H_e\delta T_{off,k}-\delta\Lambda_k=0.
```

其中

```math
F_x=\int_0^{T_{off}} C_h e^{A_{off}\tau}d\tau,
\qquad
H_e=h(T_{off}^{-}).
```

解得：

```math
\delta T_{off,k}
=\frac{1}{H_e}(\delta\Lambda_k-F_x\delta x_k).
```

若忽略 `F_x delta x_k`，则退化为 He-only：

```math
\delta T_{off,k}\approx\frac{\delta\Lambda_k}{H_e}.
```

因此 He-only 的缺失项正是 off-time 面积积分期间积累的状态记忆。

### Step 4. IEK 状态更新

事件后的状态更新写成：

```math
\delta x_{k+1}=A_d\delta x_k+B_T\delta T_{off,k}+B_u\delta u_k.
```

代入 `delta T`：

```math
\delta x_{k+1}
=\left(A_d-\frac{B_TF_x}{H_e}\right)\delta x_k
+\frac{B_T}{H_e}\delta\Lambda_k+B_u\delta u_k.
```

定义：

```math
A_{IEK}=A_d-\frac{B_TF_x}{H_e}.
```

由此得到从面积阈值到事件等待时间的动态传递：

```math
G_{T\Lambda}(z)
=D_{T\Lambda}+C_T(zI-A_{IEK})^{-1}B_{IEK}
=\frac{1}{H_e+K(z)}.
```

其中 `K(z)` 是 IEK 的核心项，表示动态面积刚度修正。

### Step 5. 四相相索引推广

四相系统中，当前导通相和下一触发相为：

```math
p_k=k\bmod 4,\qquad q_k=(p_k+1)\bmod 4.
```

事件更新写为：

```math
x_{k+1}=F_{p_k}(x_k,u_k,T_k),
\qquad
g_{q_k}(x_k,u_k,T_k)=0.
```

其中：

```math
g_{q_k}
=\int_0^{T_k}
\left[v_c(t)-R_i i_{L,q_k}(t)\right]dt-\Lambda_{q_k}.
```

这一步将 `phase_idx` 变成事件面索引，而不是仿真程序的附属变量。

### Step 6. 相索引盐跃线性化

对事件面线性化：

```math
g_x\delta x_k+g_u\delta u_k+g_T\delta T_k=0.
```

若 `g_T != 0`，则

```math
\delta T_k=-g_T^{-1}(g_x\delta x_k+g_u\delta u_k).
```

状态更新的一阶扰动为：

```math
\delta x_{k+1}=F_x\delta x_k+F_u\delta u_k+F_T\delta T_k.
```

代入得：

```math
\delta x_{k+1}
=
\left(F_x-F_Tg_T^{-1}g_x\right)\delta x_k
+
\left(F_u-F_Tg_T^{-1}g_u\right)\delta u_k.
```

这就是 PIS-IEK 的 normal-mode Jacobian。

### Step 7. 执行量通道

将执行量分成 common-mode 与 differential-mode：

```math
\delta u_k=
\begin{bmatrix}
\delta\Lambda_{cm} &
\delta\Lambda_{diff} &
\delta Ton_{cm} &
\delta Ton_{diff}
\end{bmatrix}^{T}.
```

PIS-IEK 的输出矩阵可选择为：

```math
\delta y_k=
\begin{bmatrix}
\delta T_k &
\delta \phi_k &
\delta i_{m2,k} &
\delta v_{o,k}
\end{bmatrix}^{T}.
```

于是局部执行量矩阵为：

```math
\delta y_k=J_{IEK}\delta u_k.
```

该矩阵的物理解释是本文的核心工程价值：`Lambda_diff` 多对应相位/事件节奏，`Ton_diff` 多对应 DC 均流。

### Step 8. 切载混合事件扩展

切载时，负载扰动 `delta I_o<0` 可能使 normal-mode 事件等待时间变长：

```math
\delta T_k
=-g_T^{-1}
\left(
g_x\delta x_k
+g_I\delta I_{o,k}
+g_u\delta u_k
\right).
```

当等待时间超过 blanking、事件队列或调度约束时，系统进入 skip：

```math
m_k=\mathrm{skip}.
```

skip 模式下没有新的 on-time 能量注入，状态满足近似：

```math
L_i\frac{di_{Li}}{dt}=-v_o-r_{Li}i_{Li},
```

```math
C_o\frac{dv_o}{dt}=\sum_{i=1}^{4}i_{Li}-I_o.
```

当面积条件重新满足并恢复事件触发，进入：

```math
m_k=\mathrm{reentry}.
```

因此混合模型为：

```math
x_{k+1}=F_{m_k,p_k}(x_k,u_k,I_{o,k},T_k).
```

### Step 9. AI 延迟进入事件模型

FPGA AI 延迟写为事件滞后：

```math
d=\left\lceil\frac{\tau_{AI}}{T_e}\right\rceil.
```

实际动作不是 `u_k`，而是：

```math
u_k^a=u_{\kappa(k)},\qquad
\kappa(k)=\max\{jT_u+d\le k\}.
```

于是：

```math
x_{k+1}
=F_{m_k,p_k}(x_k,u_k^a,I_{o,k},T_k).
```

局部线性化为：

```math
\delta x_{k+1}
=A_{m_k,p_k}\delta x_k
+B_{m_k,p_k}\delta u_k^a
+E_{m_k,p_k}\delta I_{o,k}.
```

这就是 AI 训练中需要使用的延迟感知事件域模型。

### Step 10. 参考斜率作为动作

切载参考从 `Iph_0` 到 `Iph_1` 的斜率调度可写为：

```math
I_{\mathrm{ph,ref}}(t)=
\begin{cases}
I_{\mathrm{ph},0}, & t<t_s,\\
I_{\mathrm{ph},0}
+\frac{I_{\mathrm{ph},1}-I_{\mathrm{ph},0}}{T_{\mathrm{slew}}}(t-t_s),
& t_s\le t<t_s+T_{\mathrm{slew}},\\
I_{\mathrm{ph},1}, & t\ge t_s+T_{\mathrm{slew}}.
\end{cases}
```

因此 AI 动作可以扩展为：

```math
u_k=
\begin{bmatrix}
\Delta\Lambda_{\mathrm{diff}} &
\Delta T_{\mathrm{on,diff}} &
\Delta I_{\mathrm{ph,ref}} &
T_{\mathrm{slew}}
\end{bmatrix}^{T}.
```

该动作空间与 PIS-IEK 的事件域状态兼容，并已由 Simulink 参考斜率扫描给出开关级证据。

## Remarks and Interpretation

- `K(z)` 的意义是动态事件记忆，而不是任意拟合项。
- PIS-IEK 的意义是把四相调度结构写入 Jacobian，而不是把所有模式硬塞进一个线性模型。
- `Lambda_diff` 和 `Ton_diff` 不应混用：前者主要调事件时序，后者主要调平均相电流。
- `T_slew` 是很适合 AI 的动作，因为它低维、物理可解释，并且直接影响切载安全。
- AI 延迟必须以事件数表达。`5 us` 对四相 `500 kHz` IQCOT 是约 `10` 个事件，不是小到可以忽略的延迟。

## Boundaries and Non-Claims

- 不声称 PIS-IEK 单独精确预测大切载第一峰。
- 不声称 AI 替代 IQCOT 内环或比较器。
- 不声称 `60 us` 或 `80 us` 是参考斜率全局最优。
- 不声称 delay-aware AI 在所有延迟下都更优。
- 不把 event-domain surrogate 当成开关级 Simulink 或硬件验证。

## Open Risks

- 需要继续扫描 `80 us` 以上或使用连续动作优化来确认参考斜率最优区间。
- 需要把 AI 策略真正接入开关级 Simulink 副本，验证 surrogate 排序是否保持。
- 需要在硬件或 HIL 中验证检测延迟、量化和参数提交延迟。
- 需要将外环补偿器状态更完整地纳入 PIS-IEK 状态空间。
