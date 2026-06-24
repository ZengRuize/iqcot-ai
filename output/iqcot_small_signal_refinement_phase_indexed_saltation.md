# 四相 IQCOT 小信号模型精进：相索引盐跃 IEK

## 1. 为什么还需要精进

v5 稿件中的 IEK 已经完成了一个关键动作：把 IQCOT 面积事件写成

```math
G_{T\Lambda}(z)=\frac{1}{H_e+K(z)}
```

并用四相模态执行量矩阵证明 `Λ_diff` 与 `Ton_diff` 不是同一个物理通道。但这个写法仍有一个弱点：`K(z)` 是等效动态核，它解释了状态记忆，却没有把四相数字控制器中的 `phase_idx`、积分器 reset、当前导通相 `p_k`、下一触发相 `q_k` 和事件边界移动统一写成一个严格的 event-to-event 小信号映射。

因此，小信号模型还能继续精进。更严谨的版本可以命名为：

> 相索引盐跃积分事件核模型，Phase-Indexed Saltation IEK，简称 PIS-IEK。

需要谨慎强调：saltation matrix/盐跃矩阵是混杂系统线性化中的已有数学工具，不是本文原创。本文可辩护的创新是把它用于四相数字 IQCOT 的面积积分事件，形成可计算、可验证的四相周期小信号 Jacobian，并把 `Λ_cm/Λ_diff/Ton_diff` 的执行量分类从频域等效核推进到局部事件映射层面。

## 2. 模型形式

设第 `k` 个事件中当前 on-time 相为

```math
p_k=k \bmod 4,
```

下一触发相为

```math
q_k=(p_k+1)\bmod 4.
```

四相 IQCOT 的一次事件可以写成：

```math
x_{k+1}=F_{p_k}(x_k,u_k,T_k),
```

```math
g_{q_k}(x_k,u_k,T_k)=0.
```

其中 `x_k` 是事件边界处的功率级状态，`u_k` 包含 `Λ_i`、`Ton_i`、检测延迟或其他数字执行量，`T_k` 是由面积积分事件隐式决定的 wait time。事件面可以写为：

```math
g_{q_k}
=
\int_{0}^{T_k}
\left[v_c(t)-R_i i_{L,q_k}(t)\right]dt-\Lambda_{q_k}.
```

对事件面做隐函数线性化：

```math
\delta T_k=-g_T^{-1}\left(g_x\delta x_k+g_u\delta u_k\right).
```

代回状态更新式，得到盐跃式小信号更新：

```math
\delta x_{k+1}
=
\left(F_x-F_Tg_T^{-1}g_x\right)\delta x_k
+
\left(F_u-F_Tg_T^{-1}g_u\right)\delta u_k.
```

记为：

```math
\delta x_{k+1}=A_{p_k}^{s}\delta x_k+B_{p_k}^{s}\delta u_k,
```

```math
\delta T_k=C_{p_k}^{s}\delta x_k+D_{p_k}^{s}\delta u_k.
```

这里上标 `s` 表示 saltation-corrected。这个形式比 v5 的 scalar `H_e+K(z)` 更进一步，因为它明确区分了四个相位事件面：

```math
(A_0^s,B_0^s),\ (A_1^s,B_1^s),\ (A_2^s,B_2^s),\ (A_3^s,B_3^s).
```

四事件提升映射为：

```math
\delta x_{k+4}
=
A_3^sA_2^sA_1^sA_0^s\delta x_k
+
\sum_{r=0}^{3}
A_3^s\cdots A_{r+1}^sB_r^s\delta u_{k+r}.
```

这个提升映射就是四相 IQCOT 的周期小信号 Poincare 模型。后续若加入外环 PI/Type-III、ADC/ZOH、DPWM、检测延迟和 phase manager 寄存器，都可以扩展到 `x_k` 或 `u_k` 中。

## 3. 与 v5 IEK 的关系

PIS-IEK 不是推翻 v5，而是把 v5 的动态核展开。

v5 的模型回答：

```text
面积扰动经过 H_e+K(z) 后如何变成事件时刻扰动？
```

PIS-IEK 进一步回答：

```text
在第 p 相导通、下一 q 相触发时，哪个状态、哪个相的 Lambda、哪个相的 Ton，
通过哪个事件面改变 wait time 和下一事件状态？
```

这能直接补上 v5 的两个局限：

1. `phase_idx` 不再只是 Simulink 副本中的工程选择，而是小信号模型中的相索引事件面 `g_{q_k}`。
2. 积分器 reset 不再只是实现细节，而是事件后状态映射 `F_{p_k}` 的一部分。

## 4. 数值验证

新脚本：

```text
E:/Desktop/codex/output/iqcot_phase_indexed_saltation_iek.py
```

输出：

```text
E:/Desktop/codex/output/iqcot_phase_indexed_saltation_jacobians.csv
E:/Desktop/codex/output/iqcot_phase_indexed_saltation_validation.csv
E:/Desktop/codex/output/iqcot_phase_indexed_saltation_iek_report.md
```

在当前四相理想事件模型中，四事件闭合误差为 `0`。四个相的局部灵敏度高度一致：

| 指标 | 数值 |
|---|---:|
| `dT/dΛ_q` | `0.0428305 ns/(1e-13 V·s)` |
| 非目标相 `Λ` 串扰 | `0` |
| `dT/dTon_p` | `-0.357596 ns/ns` |
| 非当前相 `Ton` 串扰 | `0` |

多事件小扰动验证结果：

| 工况 | rms wait exact | rms wait error | rms 相对误差 | 最大 wait 误差 | 最大相电流误差 |
|---|---:|---:|---:|---:|---:|
| `lambda_m2_1e_13` | `0.061925 ns` | `0.000777 ps` | `0.00126%` | `0.00142 ps` | `0.000017 mA` |
| `lambda_one_phase_1e_13` | `0.035801 ns` | `0.000890 ps` | `0.00249%` | `0.00253 ps` | `0.000014 mA` |
| `ton_m2_0p02ns` | `6.11930 ns` | `45.4622 ps` | `0.74293%` | `90.1977 ps` | `1.28022 mA` |
| `mixed_lambda_ton_small` | `1.80051 ns` | `14.5634 ps` | `0.80885%` | `45.8701 ps` | `0.27358 mA` |

解释要点：

- `Λ` 通道的线性预测几乎达到数值精度极限，说明面积阈值事件面的盐跃线性化很干净。
- `Ton` 通道误差约为 1% 量级，主要因为 `Ton` 同时改变 on-time 伏秒、事件初始状态和后续周期相位；即便如此，模型仍能准确捕捉方向和数量级。
- 这比只用 `δT≈δΛ/H_e` 更强，因为它同时预测 `wait` 和下一事件状态，而不仅是局部事件时刻。

## 5. 可写成论文创新点的表述

建议把该创新写成：

> 本文进一步提出相索引盐跃 IEK 小信号模型，将四相 IQCOT 的面积积分事件、phase scheduler、积分 reset 与 on-time 伏秒扰动统一为周期 event-to-event Jacobian。该模型不是重新提出 saltation matrix，而是将混杂系统事件面线性化引入四相数字 IQCOT 的面积事件建模，使 `Λ_diff`、`Ton_diff` 和检测延迟差模的执行量分类可由局部事件映射直接计算。数值验证表明，`Λ` 差模通道的多事件 wait 预测误差低于 `0.003 ps`，`Ton` 差模通道的 rms 相对误差约 `0.74%`，从而为 v5 的 `H_e+K(z)` 等效核提供了更严格的状态空间解释。

## 6. 实际价值

PIS-IEK 的价值不是让公式更复杂，而是让后续研究更不容易“调错参数”。

1. 对数字实现：可以直接加入 ADC/ZOH、面积计数器、比较器时钟、phase manager 寄存器，把数字延迟从经验 jitter 项变成状态或输入。
2. 对 AI/优化调参：可以把 `B_\Lambda^s`、`B_{Ton}^s` 和 `C^s` 作为物理约束，限制 AI 只在可解释通道内搜索。
3. 对论文创新性：它把 v5 的“等效动态核”推进到“相索引周期盐跃 Jacobian”，理论上更严谨，也更容易回答审稿人关于 `phase_idx/reset` 的质疑。

## 7. 仍需注意的边界

- 当前验证基于理想四相事件模型，不是完整 Simscape MOSFET/驱动/采样链。
- Saltation/Poincare 方法本身已有文献基础，不能声称数学工具原创。
- 目前只验证了非 phase-overlap 的四相工作点。
- 若写入最终论文，最好再补一个 Simulink 副本中的小扰动 Jacobian 提取，作为电路级交叉验证。
