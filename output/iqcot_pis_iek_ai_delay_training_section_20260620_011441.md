# PIS-IEK for Delay-Aware AI Parameter Tuning in Four-Phase Digital IQCOT

## 1. Motivation

FPGA 上的 AI 推理延迟通常处于微秒量级，而四相交错 IQCOT 的事件间隔约为

```math
T_e=\frac{T_s}{N}.
```

在本文的四相 `500 kHz` 等效设计中，`T_e≈0.5 us`。因此 `1-5 us` 的 AI 推理延迟并不是一个可以忽略的小延迟，而是跨越

```math
d=\left\lceil \frac{\tau_{AI}}{T_e}\right\rceil
```

个 IQCOT 触发事件。若 AI 控制器在训练时假设动作立即生效，但在 FPGA 部署时动作实际变为 `u_{k-d}`，则会形成明显的 train-test mismatch。PIS-IEK 小信号模型的价值正在这里：它把连续时间切换系统转写成事件域状态演化，使 AI 延迟可以被显式写入训练环境。

## 2. Delay-Aware Lifted Event Model

设事件域状态为

```math
x_k=
\begin{bmatrix}
\tilde v_o(k) & \tilde \phi(k) & \tilde i_{m2}(k)
\end{bmatrix}^{T},
```

其中 `\tilde v_o` 表示输出电压扰动，`\tilde \phi` 表示相位间隔扰动，`\tilde i_{m2}` 表示主要差模均流误差。AI 不直接输出开关指令，而输出低维参数偏置

```math
u_k=
\begin{bmatrix}
\Delta\Lambda_{\mathrm{diff}}(k) &
\Delta T_{\mathrm{on,diff}}(k)
\end{bmatrix}^{T}.
```

考虑 FPGA 推理延迟和参数保持，实际进入 IQCOT 事件核的动作是

```math
u_k^{a}=u_{\kappa(k)},\quad
\kappa(k)=\max\{jT_u+d\le k\},
```

其中 `T_u` 为 AI 参数更新周期对应的事件数，`d=ceil(tau_AI/T_e)`。于是可写为混合事件模型：

```math
x_{k+1}
=F_{m_k,p_k}\left(x_k,u_k^{a},I_{o,k},T_k\right),
```

其中 `m_k` 是事件模式：

```math
m_k\in
\{\mathrm{normal},\mathrm{skip},\mathrm{reentry},\mathrm{saturation}\},
```

`p_k` 是当前相位索引。围绕某一模式线性化得到

```math
\delta x_{k+1}
=A_{m_k,p_k}\delta x_k+B_{m_k,p_k}\delta u_k^{a}
+E_{m_k,p_k}\delta I_{o,k}.
```

这就是 AI 训练所需的最小状态接口：AI 不是学习完整开关波形，而是学习如何在事件延迟、模式切换和物理约束下调节 IQCOT 参数。

## 3. Why PIS-IEK Helps AI Training

PIS-IEK 对 AI 的帮助可以分成三层。

第一，它把延迟从连续时间量转为事件滞后阶数：

```math
\tau_{AI}=5us,\quad T_e=0.5us
\Rightarrow d=10.
```

这能避免训练时使用 `u_k`，部署时实际使用 `u_{k-10}` 的不一致。

第二，它提供动作通道灵敏度。已有仿真结果表明，`Ton_diff` 对差模均流有强作用，而 `Lambda_diff` 更适合微调事件时序和相位间隔。因此 AI 动作空间不应盲目高维化，而应保持为可解释的低维参数：

```math
u_k=[\Delta\Lambda_{\mathrm{diff}},\Delta T_{\mathrm{on,diff}}]^T.
```

第三，它允许安全投影。若候选动作 `u_k` 会导致预测状态越过电压、相位间隔或均流边界，则投影为

```math
\Pi_{\mathcal U(x)}(u_k)
=\arg\min_{\bar u\in\mathcal U(x)}\|\bar u-u_k\|_2^2,
```

其中

```math
\mathcal U(x)=
\{\bar u:\ |v_{k+1}|\le V_{\max},\
|\phi_{k+1}|\le \Phi_{\max},\
|i_{m2,k+1}|\le I_{\max}\}.
```

这个投影不是为了追求最优控制理论上的完美解，而是为了让 FPGA 上的 AI 调参不会输出破坏 COT 事件秩序的动作。

## 4. Experimental Evidence from Event-Domain Surrogate

我们构造了一个延迟感知事件域 surrogate，用已有 PIS-IEK 灵敏度和 Simulink 切载指标定标，扫描：

- 切载：`40A->20A`、`40A->10A`、`40A->near-0A`
- AI 延迟：`0, 0.5, 1, 2, 5 us`
- AI 更新周期：`2, 5, 10, 20 us`
- 策略：`no_ai`、`zero_delay_trained`、`delay_aware`、`delay_aware_projected`
- 总 episode：`15360`

在最严苛的 `40A->near-0A`、`T_update=5us` 条件下，结果显示：

| `tau_AI` | Strategy | Mean violations | Tail phase mean | Tail current mean | Reward |
|---:|---|---:|---:|---:|---:|
| `1us` | `zero_delay_trained` | `17.219` | `12.745 ns` | `430.978 mA` | `-637.369` |
| `1us` | `delay_aware` | `24.422` | `13.459 ns` | `491.844 mA` | `-772.161` |
| `5us` | `zero_delay_trained` | `147.875` | `60.276 ns` | `1095.563 mA` | `-2411.740` |
| `5us` | `delay_aware_projected` | `24.297` | `13.360 ns` | `513.768 mA` | `-802.252` |

这说明延迟感知模型并不是在所有延迟下都自动更优。当 `tau_AI=1us` 时，零延迟训练策略仍然具有竞争力，甚至可能因为动作更激进而获得更高 reward。但当 `tau_AI=5us`、即跨越约 `10` 个 IQCOT 事件时，零延迟训练策略明显失配，导致 violation、相位尾部误差和均流尾部误差显著增大。

## 5. Paper-Level Claim Boundary

基于当前证据，推荐论文中采用如下克制表述：

> PIS-IEK enables delay-aware AI parameter tuning by mapping FPGA inference latency into event-domain delay, separating phase-timing and current-sharing actuator channels, and supporting safety projection under cut-load recovery. The benefit is most evident when the AI latency spans multiple IQCOT events; for very small delays, zero-delay-trained tuners may remain competitive.

不建议表述为：

> AI 控制在所有延迟下都优于传统控制。

也不建议表述为：

> PIS-IEK 可以替代开关级 Simulink 仿真或直接预测大切载第一峰值。

更稳妥的创新主张是：PIS-IEK 给 AI 调参提供了一个事件域、延迟感知、物理约束一致的训练环境，从而降低 FPGA 部署时的模型失配风险。

