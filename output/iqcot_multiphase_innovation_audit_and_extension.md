# 多相 Buck 方向的 IEK-IQCOT 创新性审查与深化

本文目标不是继续堆公式，而是回答三个问题：

1. 把 IEK-IQCOT 推到多相 Buck 后，是否产生了新的研究价值？
2. 这个创新相比已有 IQCOT/COT/DICOT 文献是否真的有区别？
3. 当前佐证是否足够，不足之处如何继续增强？

结论：**单相 IEK 只能算中等强度的建模创新；多相模态 IEK 加上执行量分类后，创新程度明显增强，已经可以支撑硕士毕业设计的核心创新点。但如果要写成高水平论文，还需要进一步在 Simulink 严格面积事件模型和实际参数失配下验证。**

## 1. 文献边界再确认

已有文献覆盖了几个关键方向：

- Bari 的博士论文与后续 IQCOT 工作已经提出 IQCOT 控制思想和面积/电荷型控制基础，不能再声称“首次提出 IQCOT”。Virginia Tech 页面可查到 Bari 2018 博士论文 *A Novel Inverse Charge Constant On-Time Control for High Performance Voltage Regulators*。
- Bari、Li、Lee 在 ECCE 2018 的 *High Frequency Small Signal Model for Inverse Charge Constant On-Time (IQCOT) Control* 已经做过 IQCOT 高频小信号模型，不能再声称“首次建立 IQCOT 小信号模型”。
- Gabriele 等 2025 的 *A Unified Sampled-Data Small-Signal Model for a Ripple-Based COT Buck Converter With Arbitrary Ripple Injection Network* 已经把 ripple-based COT 写成通用 sampled-data 小信号模型，不能把“事件驱动 sampled-data”本身当原创。
- Li 等 2024 的 *Multiphase digital integration constant on-time-controlled Buck converter with high-resolution current balance scheme for ultrafast load transient* 已经做了多相 DICOT 和高分辨率均流，不能声称“首次提出多相数字积分 COT 均流”。

因此，本文真正能成立的创新边界应该收敛为：

> 面向多相 IQCOT 的积分面积事件，将阈值面积、检测延迟、面积噪声、相位间隔和 Ton-trim 均流执行量统一写入 common/differential modal IEK 事件核，用于预测多相数字 IQCOT 的共模周期扰动、差模 phase-spacing jitter 和相电流均衡灵敏度。

这个边界比“AI 调参”或“重新推导 IQCOT 小信号”更稳。

## 2. 多相 IEK 的理论深化

四相交错 Buck 中，事件按相序轮转：

~~~text
p_k = k mod N
q_k = (p_k + 1) mod N
~~~

每个事件间隔由下一相 q 的 IQCOT 面积事件决定：

~~~text
integral_{a_k}^{t_{k+1}} [VC - Ri_q*i_q(t)] dt = Lambda_q
~~~

对多相系统线性化后，事件扰动不再是单个标量，而是相位向量：

~~~text
tau_k = [tau_1, tau_2, ..., tau_N]^T
u_A,k = [u_A1, u_A2, ..., u_AN]^T
~~~

对于相参数匹配的 N 相系统，线性化模型具有循环对称性，因此可以用离散傅里叶模态分解：

~~~text
Tau_m(z) = DFT{tau_q}
U_m(z)   = DFT{u_Aq}

[He_m*z - Hs_m + K_m(z)] Tau_m(z) = U_m(z)
~~~

其中：

- m=0 是 common-mode，主要影响总输出电压、总周期 jitter、等效开关频率；
- m=1...N-1 是 differential modes，主要影响相位间隔、相间 ripple cancellation、均流误差和相间 limit cycle。

这就是多相版本比单相版本更有价值的地方：它不仅预测“触发早晚”，还可以把多相系统分解为共模和差模设计问题。

## 3. 多相仿真模型

新增脚本：

~~~text
E:/Desktop/codex/output/iqcot_multiphase_iek_modal_study.py
~~~

输出：

~~~text
E:/Desktop/codex/output/iqcot_multiphase_iek_modal_summary.csv
E:/Desktop/codex/output/iqcot_multiphase_iek_common_response.csv
E:/Desktop/codex/output/iqcot_multiphase_iek_differential_offsets.csv
E:/Desktop/codex/output/iqcot_multiphase_iek_ton_trim_offsets.csv
~~~

模型为四相交错 Buck：

~~~text
N          = 4
Vin        = 12 V
Vref       = 1 V
Iout       = 40 A
Iph        = 10 A
L          = 200 nH
C          = 7.2 mF
DCR        = 1.5 mOhm
Ri         = 0.5 mOhm
fsw_phase  = 500 kHz
Tglobal    = 500 ns
Ton        = 169.167 ns
Twait      = 330.833 ns
VC         = 5.0167 mV
Hs_mean    = 1.5000 mV
He_mean    = 2.3348 mV
~~~

该模型使用多相 Buck 的共模/差模解析状态更新，而不是固定步长粗积分。

## 4. 结果 A：共模下静态模型严重失效

对所有相施加相同面积阈值扰动，即 common-mode threshold perturbation。比较：

~~~text
静态模型：deltaT ~= deltaLambda / He
动态多相 IEK/非线性仿真：显式四相面积事件模型
~~~

结果：

~~~text
静态 He-only 共模误差范围：
best  = 0.66%
worst = 3512.46%
~~~

典型频点：

~~~text
omega/pi = 0.005:
sim_wait_amp = 0.01355 ns
static_amp   = 0.17132 ns
error        = 1164.04%

omega/pi = 0.01:
sim_wait_amp = 0.00474 ns
static_amp   = 0.17132 ns
error        = 3512.46%

omega/pi = 0.20:
sim_wait_amp = 0.17247 ns
static_amp   = 0.17132 ns
error        = -0.66%
~~~

这说明在多相交错系统中，阈值面积扰动到事件间隔的传递存在强烈频率选择性。静态 He-only 模型会在某些频段严重高估 jitter，在另一些频段又低估或错相。

实际意义：

- 面积阈值 DAC 分辨率不能只按 He 设计；
- 数字 dither/噪声整形需要考虑多相 common-mode IEK 的敏感频段；
- 多相相位管理器的 jitter budget 应使用 K_0(z)，而不是单周期 He。

## 5. 结果 B：差模阈值不是有效 DC 均流执行量

我对相阈值施加差模面积偏置：

~~~text
m1_cos:   [1, 0, -1, 0]
m2_alt:   [1, -1, 1, -1]
one_phase:[1, -1/3, -1/3, -1/3]
~~~

结果显示，面积阈值差模会显著改变 phase spacing：

~~~text
amp_area = 8e-13
m1_cos wait_pkpk = 1.0667 ns
m2_alt wait_pkpk = 1.0666 ns
~~~

但平均相电流几乎不变：

~~~text
phase_current_pkpk < 0.002 mA
~~~

这个结果非常重要，因为它推翻了一个容易犯的错误：**不能简单声称“差模 IQCOT 阈值调节就是均流控制”。**

在理想匹配、固定 Ton、轮转相位管理的四相 Buck 中，差模阈值更像 phase-spacing actuator，而不是 DC current-sharing actuator。

因此，多相 IEK 应该把执行量分清楚：

~~~text
Lambda_cm   -> 输出/总周期 jitter
Lambda_diff -> 相位间隔/差模 jitter/ripple cancellation
Ton_diff    -> 平均相电流/均流
~~~

这比泛泛地说“AI 调 IQCOT 参数均流”更严谨，也更容易答辩。

## 6. 结果 C：Ton-trim 是强均流执行量

进一步引入每相 Ton_trim 差模扰动。结果在小信号区间内近似线性：

~~~text
m2_alt Ton_trim = 0.02 ns:
I_pkpk = 159.92 mA
wait_pkpk = 17.57 ns

m2_alt Ton_trim = 0.05 ns:
I_pkpk = 398.82 mA
wait_pkpk = 44.07 ns

m2_alt Ton_trim = 0.10 ns:
I_pkpk = 790.81 mA
wait_pkpk = 88.89 ns
~~~

对于 one_phase 模态：

~~~text
Ton_trim = 0.10 ns:
I_pkpk = 530.95 mA
wait_pkpk = 66.72 ns
~~~

这说明多相数字 IQCOT 中，如果目标是均流，真正强有效的执行量是 Ton_trim 或等效 on-time threshold trim，而不是单纯面积阈值差模。

但 Ton_trim 也会通过 IQCOT 面积事件反过来扰动后续等待时间，产生 phase-spacing jitter。因此它不能独立设计，必须和事件核约束一起看：

~~~text
current balance benefit  vs.  phase-spacing jitter cost
~~~

这就是多相 IEK 模型的实际设计价值。

## 7. 创新程度评估

### 7.1 单相 IEK

创新程度：中等。

理由：

- 已有 IQCOT 小信号和 COT sampled-data 文献很多；
- 单相 IEK 的主要贡献是把面积参数、延迟、噪声和事件时刻统一起来；
- 适合作为论文方法基础，但单独作为核心创新略弱。

### 7.2 动态 K(z) 识别

创新程度：中等偏强。

理由：

- 它把 IQCOT 面积事件从 He-only 局部灵敏度提升为功率级状态相关的动态事件核；
- 已用非线性逐周期仿真验证，误差约 0.00018%；
- 但它仍然是单相模型，实际应用说服力还不够。

### 7.3 多相模态 IEK + 执行量分类

创新程度：较强，足够支撑硕士毕设核心创新。

理由：

- 它面向多相 Buck/IQCOT 的真实难点：相位交错、ripple cancellation、均流、数字延迟和阈值分辨率；
- 它给出 common/differential modal decomposition，不再只看单相平均模型；
- 它通过仿真证明：差模阈值主要影响 phase spacing，Ton_trim 才是强均流执行量；
- 这个结论能直接指导数字 IQCOT 控制器参数分配。

建议论文创新点最终写成：

> 本文提出一种面向多相数字 IQCOT Buck 的积分事件核模态建模方法，将 IQCOT 面积事件在线性化后分解为共模事件核和差模事件核，并区分面积阈值、检测延迟和 Ton-trim 在输出调节、相位间隔和均流中的作用。仿真表明，传统 He-only 面积刚度模型在多相共模扰动下最大误差可达 3512%，而差模阈值主要调节相位间隔而非 DC 均流，Ton-trim 则是强均流执行量但会引入显著 phase-spacing jitter。

这个表述比“AI 调参数优化 IQCOT”更有学术含量。

## 8. 佐证是否充足？

当前佐证对硕士毕设来说基本够，但对投稿论文还不够。

已经足够的部分：

- 有明确文献边界；
- 有单相 IEK 推导；
- 有动态 K(z) 识别；
- 有非线性逐周期验证；
- 有四相多相扩展；
- 有共模/差模执行量分类；
- 有静态模型失效的量化证据。

仍不足的部分：

- 多相模型还没有加入实际相参数失配，例如 L/DCR/Ri/driver delay mismatch；
- 还没有把 VC 外环补偿器状态纳入多相 K_m(z)；
- 还没有在 Simulink 中搭建严格面积积分 IQCOT 控制器；
- Ton_trim 大扰动下 wait_pkpk 很大，需要限制在线性小信号区间内讨论；
- 还没有用 v0027 工程模型验证 modal conclusions，只是独立理论模型验证。

## 9. 下一步优化方向

最有价值的继续研究路线是：

1. 在多相模型中加入 L/DCR/Ri/driver delay mismatch，验证 IEK modal model 能否预测失配下的 current-sharing sensitivity。

2. 把 VC 外环 PI/Type-III 补偿器加入状态空间，得到包含补偿器记忆的 K_0(z) 和 K_diff(z)。

3. 在 Simulink 中搭建显式面积积分 IQCOT：

~~~text
vc - Ri*iL_phase
-> per-phase/rotating integrator
-> area threshold Lambda_q
-> phase manager
-> fixed Ton / Ton_trim
~~~

4. 用多频注入识别 Simulink 波形中的 K_0(z)、K_diff(z)，并和理论脚本结果对比。

做到第 3 和第 4 步后，这个创新点会从“理论与脚本验证”升级为“模型、仿真和工程设计闭环”。

## 10. 最终判断

如果只停留在单相 IEK：创新偏弱，容易被认为是已有 sampled-data 方法的重新表达。

如果采用当前深化后的版本：

~~~text
多相 IQCOT 积分事件核模态建模
+ common/differential decomposition
+ 阈值/延迟/噪声/Ton_trim 执行量分类
+ phase-spacing jitter 与 current-sharing tradeoff
~~~

则创新程度足够作为硕士毕设核心内容。它有明确的新问题、新模型、新结论和数值佐证。
