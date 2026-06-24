# 多相数字 IQCOT Buck 变换器的积分事件核模态建模与均流执行量分析

## 摘要

多相交错 Buck 变换器广泛用于低压大电流电压调节模块，其中 constant on-time（COT）及 inverse charge constant on-time（IQCOT）控制因瞬态响应快、结构紧凑而受到关注。然而，在数字多相 IQCOT 中，面积阈值、检测延迟、量化噪声、相位间隔和相电流均衡往往被混合为经验调参问题，导致模型难以同时解释周期 jitter、phase-spacing jitter 和 current-sharing tradeoff。本文提出一种面向多相数字 IQCOT Buck 的积分事件核（Integral-Event Kernel, IEK）模态建模方法。该方法从 IQCOT 面积事件

~~~text
integral [vc(t) - Ri*iL(t)] dt = CT*VTH/gm
~~~

出发，通过移动边界线性化建立事件时刻、面积阈值和功率级状态记忆之间的 sampled-data 关系，并进一步将多相事件扰动分解为 common-mode 和 differential-mode 事件核。单相验证表明，动态 IEK 对非线性逐周期面积事件仿真的周期响应预测误差低于 0.00018%，而传统 He-only 面积刚度模型相对非线性仿真的最大幅值误差达到 771.62%。在四相交错 Buck 模型中，common-mode 面积阈值扰动下 He-only 模型最大误差达到 3512.46%，说明多相 IQCOT 的面积阈值和 jitter 预算不能仅由局部事件终点刚度决定。进一步的 differential-mode 仿真表明，相阈值差模偏置主要改变 phase spacing，而非 DC 均流；在理想匹配固定 Ton 条件下，8e-13 的差模面积偏置产生约 1.0667 ns 的 wait-time pk-pk 偏差，但平均相电流 pk-pk 小于 0.002 mA。相反，Ton-trim 是强均流执行量，但会引入显著 phase-spacing cost。DCR 失配设计链显示，20% 单调 DCR 失配可造成 4.072 A pk-pk 电流不均；0.1 ns 限幅 Ton-trim 平均降低电流 pk-pk 约 31.98%，但最大 wait-time 代价约 108.07 ns。本文结果表明，多相数字 IQCOT 的参数设计应区分 Lambda_cm、Lambda_diff 和 Ton_diff 的作用，并以事件核约束统一评估输出调节、相位间隔和均流代价。

**关键词**：IQCOT；constant on-time；多相 Buck；小信号模型；sampled-data；事件驱动控制；均流；phase-spacing jitter

## 1. 引言

低压大电流处理器供电对电压调节模块提出了高带宽、低纹波和高电流密度的要求。多相交错 Buck 通过相位错开降低输入和输出纹波，并通过相电流分担降低器件热应力，是高性能 VRM 的常见拓扑。COT 控制因无需固定频率时钟、负载瞬态响应快而常用于这类应用；IQCOT 进一步将 off-time 触发条件写为电压和电流信息的积分面积事件，使控制律具有更快的瞬态响应和更丰富的调参自由度。

已有研究已经奠定了 IQCOT 和 COT 小信号分析的基础。Bari 的博士论文系统提出 inverse charge COT 控制思想，后续工作给出了 IQCOT 高频小信号模型和瞬态性能分析。针对 ripple-based COT，sampled-data 建模已经能够描述事件驱动开关系统中的采样效应、边带效应和高频动态。针对数字多相实现，DICOT 与高分辨率均流方案也已经展示了多相相位管理和 current balance 的工程可行性。因此，本文不声称首次提出 IQCOT，也不声称首次建立 COT sampled-data 模型。

本文关注一个更具体的问题：在多相数字 IQCOT 中，面积阈值、检测延迟、噪声、相位间隔和 Ton-trim 均流执行量如何进入同一个小信号设计框架？如果只使用局部面积刚度

~~~text
deltaT ~= deltaLambda/He
~~~

设计阈值分辨率和 jitter 预算，则隐含假设 off-time 起点状态不受过去事件扰动影响。对于含输出电容、电感 DCR、多相相位管理和 current-sharing 执行量的系统，这个假设通常不成立。本文提出 IEK-IQCOT 模型，用动态事件核 K(z) 表示功率级和控制链路的记忆效应，并将多相事件扰动分解为 common-mode 与 differential-mode。

本文贡献如下：

1. 从 IQCOT 积分面积事件出发，推导事件时刻扰动、面积阈值扰动和功率级状态记忆之间的 IEK sampled-data 模型。
2. 给出由阈值面积到周期扰动传函反推出动态事件核 K(z) 的方法，并验证时间平移不变性条件 K(1)=Hs-He。
3. 将 IEK 扩展到四相交错 Buck，提出 common/differential modal decomposition，用于区分输出调节、相位间隔扰动和均流执行量。
4. 通过多相仿真证明：Lambda_diff 主要是 phase-spacing actuator，而 Ton_diff 才是强 current-sharing actuator；但 Ton-trim 的均流收益伴随显著 phase-spacing jitter cost。

## 2. 相关工作与研究边界

### 2.1 IQCOT 与高频小信号模型

IQCOT 的基本思想是将 COT 的触发条件从瞬时比较扩展为积分面积事件。Bari 的相关工作已经提出 IQCOT 控制律及其高频小信号模型，并讨论了瞬态性能和 Q tuning。因此，本文的创新不在于重新定义 IQCOT 控制律，而在于将面积事件重新组织成适合数字多相实现的参数化事件核模型。

### 2.2 COT sampled-data 与事件驱动模型

COT 与 ripple-based control 的 sampled-data 建模已有较充分基础。已有模型能够处理事件触发、narrow pulse perturbation、sideband effect 和 ripple injection network。本文借鉴 sampled-data 思想，但事件函数不同：本文以 IQCOT 的积分面积条件为对象，而非一般 ripple comparator 的瞬时阈值交叉。

### 2.3 多相数字积分 COT 与 current balance

多相 DICOT 研究已经展示了 signal accumulation、phase manager、delay-line high-resolution current balance 等数字实现方案。本文不声称首次提出多相数字 COT 均流，而是进一步区分多相 IQCOT 中不同执行量的物理作用：面积阈值差模主要影响 phase spacing，Ton-trim 主要影响平均相电流。

## 3. 单相 IQCOT 积分事件核模型

单相 IQCOT 的 off-time 面积事件写为：

~~~text
F_k = integral_{a_k}^{t_{k+1}} h(t) dt - Lambda = 0
h(t) = vc(t) - Ri*iL(t)
Lambda = CT*VTH/gm
~~~

其中 a_k 是积分起点，t_{k+1} 是下一次触发时刻。对稳态周期轨道进行移动边界线性化，定义事件时刻扰动 tau_k，有：

~~~text
He*tau_{k+1}
- Hs*(tau_k + ton_hat,k + tbl_hat,k)
+ Astate,k
+ Aparam,k
- Lambda*rho_k
- DeltaA_det,k
= 0
~~~

其中：

~~~text
He = h0(t_{k+1}^-)
Hs = h0(a_k^+)
rho = delta ln Lambda
    = delta ln CT + delta ln VTH - delta ln gm
~~~

真实 Buck-IQCOT 中，Astate,k 由功率级状态记忆决定，可写为事件核：

~~~text
Astate,k = K0*tau_k + K1*tau_{k-1} + K2*tau_{k-2} + ...
~~~

于是得到 IEK 表达式：

~~~text
[He*z - Hs + K(z)] Tau(z) = U_A(z)
~~~

面积域输入 U_A,k 汇总阈值、参数、延迟和噪声：

~~~text
U_A,k =
Lambda*rho_k
- Aparam,k
+ Hs*(ton_hat,k + tbl_hat,k)
+ DeltaA_det,k
+ wA,k
~~~

fixed on-time 下，周期扰动和 duty 扰动满足：

~~~text
DeltaT_k = tau_{k+1} - tau_k
d_hat,k = -D/Tsw * DeltaT_k
~~~

因此：

~~~text
Dhat(z)/U_A(z)
= -D/Tsw * (z - 1) / [He*z - Hs + K(z)]
~~~

自治开关系统对整体时间平移不敏感，因此：

~~~text
He - Hs + K(1) = 0
K(1) = Hs - He
~~~

该条件说明绝对事件相位 tau 不是最终工程指标；周期扰动 DeltaT 和 duty 扰动才直接影响频率、纹波和平均模型。

## 4. 动态 K(z) 识别方法

为避免将 K(z) 作为经验拟合项，本文从显式 Buck-IQCOT 面积事件模型推导 K(z)。取状态：

~~~text
x = [iL, vC]^T
~~~

on/off 区间为：

~~~text
dx/dt = A*x + b_on
dx/dt = A*x + b_off
~~~

状态转移用矩阵指数精确计算：

~~~text
x(t) = x_ss + exp(A*t)*(x0 - x_ss)
integral_0^t x(s)ds = t*x_ss + A^-1*(exp(A*t)-I)*(x0-x_ss)
~~~

固定 Ton、变 off-time 的面积事件线性化为：

~~~text
M*delta x_a,k + He*delta T_k - delta Lambda_k = 0
~~~

因此：

~~~text
delta T_k = Ct*delta x_k + Dt*delta Lambda_k
Ct = -M*Phi_on/He
Dt = 1/He
~~~

事件后的状态扰动为：

~~~text
delta x_{k+1} = Ad*delta x_k + Bd*delta Lambda_k
Ad = Phi_off*Phi_on + f_e*Ct
Bd = f_e*Dt
~~~

阈值面积到周期扰动传函：

~~~text
G_T(z) = DeltaT(z)/DeltaLambda(z)
       = Ct*(zI - Ad)^-1*Bd + Dt
~~~

由 IEK 定义反解：

~~~text
K(z) = (z - 1)/G_T(z) - (He*z - Hs)
~~~

## 5. 多相模态 IEK

四相交错 Buck 中，事件按相序轮转。设 p_k 为当前 on-time 相，q_k 为下一触发相：

~~~text
p_k = k mod N
q_k = (p_k + 1) mod N
~~~

下一相 IQCOT 面积事件为：

~~~text
integral_{a_k}^{t_{k+1}} [VC - Ri_q*i_q(t)]dt = Lambda_q
~~~

对相参数匹配的 N 相系统，线性化模型具有循环对称性，可使用离散傅里叶模态分解：

~~~text
Tau_m(z) = DFT{tau_q}
U_m(z)   = DFT{u_Aq}

[He_m*z - Hs_m + K_m(z)] Tau_m(z) = U_m(z)
~~~

m=0 为 common-mode，主要影响总周期 jitter、输出电压和等效开关频率；m=1...N-1 为 differential modes，主要影响相位间隔、相间 ripple cancellation、limit cycle 和均流相关动态。

这一分解引出本文的执行量分类：

~~~text
Lambda_cm   -> 输出调节 / 总周期 jitter
Lambda_diff -> 相位间隔 / 差模 jitter / ripple cancellation
Ton_diff    -> 平均相电流 / current sharing
~~~

## 6. 仿真设置

本文使用独立脚本进行理论验证，脚本路径如下：

~~~text
E:/Desktop/codex/output/iqcot_dynamic_iek_kernel_identification.py
E:/Desktop/codex/output/iqcot_multiphase_iek_modal_study.py
E:/Desktop/codex/output/iqcot_multiphase_current_balance_design.py
~~~

单相动态 IEK 验证参数：

~~~text
Vin   = 12 V
Iload = 10 A
L     = 200 nH
C     = 1.8 mF
DCR   = 1.5 mOhm
Ri    = 0.5 mOhm
fsw   = 500 kHz
Ton   = 166.667 ns
Toff  = 1833.333 ns
D     = 0.083333
~~~

四相模型参数：

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

## 7. 结果

### 7.1 动态 IEK 准确预测单相非线性面积事件响应

在单相模型中，对面积阈值施加小正弦扰动：

~~~text
Lambda_k = Lambda0 + 2e-11*sin(omega*k)
~~~

动态 IEK 预测与非线性逐周期面积事件求解高度一致：

~~~text
period_amp_error_max   = 0.000157 %
period_phase_error_max = 4.07e-5 deg
duty_amp_error_max     = 0.000157 %
duty_phase_error_max   = 4.07e-5 deg
~~~

低频核极限也满足时间平移不变性：

~~~text
K(1) = Hs - He = -4.5837 mV
omega/pi = 0.001: K = -4.5877 - j0.0072 mV
~~~

这说明 K(z) 不是任意拟合项，而是与自治事件系统的结构约束一致。

### 7.2 He-only 静态模型无法可靠预测面积阈值扰动

相对非线性仿真，单相 He-only 模型最大幅值误差为 771.62%，最大相位误差为 77.18 deg。对于 2e-11 面积扰动：

~~~text
He-only 周期幅值预测 = 3.2875 ns
动态 IEK DC 周期幅值 = 5.2672 ns
DC 误差              = -37.58%
~~~

在四相 common-mode 面积阈值扰动下，He-only 模型误差更加显著：

~~~text
best error  = 0.66%
worst error = 3512.46%
~~~

典型频点如下：

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

这表明多相 IQCOT 的阈值分辨率、噪声和 dither 设计不能只依据局部 He。

### 7.3 差模面积阈值主要影响 phase spacing，而非 DC 均流

对四相模型施加差模面积阈值偏置：

~~~text
m1_cos    = [1, 0, -1, 0]
m2_alt    = [1, -1, 1, -1]
one_phase = [1, -1/3, -1/3, -1/3]
~~~

当 amp_area=8e-13 时，差模阈值产生约 1 ns 量级的相位间隔扰动：

~~~text
m1_cos wait_pkpk = 1.0667 ns
m2_alt wait_pkpk = 1.0666 ns
~~~

但平均相电流变化极小：

~~~text
phase_current_pkpk < 0.002 mA
~~~

因此，Lambda_diff 不应被解释为 DC current-sharing actuator。它主要是 phase-spacing actuator，可能用于相位间隔修正或 ripple cancellation 优化。

### 7.4 Ton-trim 是强均流执行量，但有相位代价

每相 Ton_trim 对平均相电流具有强作用。在小信号区间内：

~~~text
m2_alt Ton_trim = 0.02 ns:
I_pkpk    = 159.92 mA
wait_pkpk = 17.57 ns

m2_alt Ton_trim = 0.05 ns:
I_pkpk    = 398.82 mA
wait_pkpk = 44.07 ns

m2_alt Ton_trim = 0.10 ns:
I_pkpk    = 790.81 mA
wait_pkpk = 88.89 ns
~~~

这说明 Ton_diff 是有效均流执行量，但其副作用是显著 phase-spacing jitter。多相数字 IQCOT 的均流设计必须同时约束 current-sharing error 和 phase-spacing cost。

### 7.5 DCR 失配下的受限 Ton-trim 设计链

为连接实际均流问题，本文建立 DCR 失配下的 DC current-sharing algebra。等 Ton 条件下：

~~~text
I_j = (D*Vin - Vo)/R_j
sum_j I_j = Iout
~~~

若使用 zero-mean Ton_trim 补偿，则可得到解析补偿量：

~~~text
deltaTon_j = Tsw * Iref * (R_j - mean(R))/Vin
~~~

20% 单调 DCR 失配时：

~~~text
DCR scale = [0.80, 0.93, 1.07, 1.20]
no-trim current pk-pk = 4.072 A
full equalizing Ton_trim pk-pk = 1.000 ns
~~~

全补偿可在 DC algebra 中消除电流不均，但事件模型显示相位代价可能过大。因此进一步评估受限 Ton_trim：

~~~text
0.10 ns trim limit:
average current pk-pk reduction = 31.98%
maximum wait-time cost          = 108.07 ns

0.20 ns trim limit:
average current pk-pk reduction = 61.97%
maximum wait-time cost          = 252.03 ns
~~~

典型场景如下：

| DCR 失配场景 | Ton 限幅 | 无补偿 Ipkpk | 限幅补偿后 Ipkpk | Ipkpk 降低 | wait pk-pk 代价 |
|---|---:|---:|---:|---:|---:|
| mild monotonic ±10% | 0.1 ns | 2.009 A | 1.206 A | 39.97% | 89.48 ns |
| strong monotonic ±20% | 0.1 ns | 4.072 A | 3.261 A | 19.91% | 89.05 ns |
| alternating ±10% | 0.1 ns | 2.000 A | 1.200 A | 40.00% | 88.89 ns |
| one-phase high 20% | 0.1 ns | 2.353 A | 1.647 A | 30.00% | 108.07 ns |
| one-phase low 20% | 0.1 ns | 3.077 A | 2.154 A | 30.00% | 76.05 ns |

该结果说明，均流补偿不能只按电流误差闭环设计，还必须加入 IEK phase-spacing 约束。

## 8. 讨论

本文结果支持一个比传统 IQCOT 调参更细的设计观点：多相数字 IQCOT 中的参数不是单一“性能旋钮”。Lambda_cm、Lambda_diff 和 Ton_diff 对应不同物理通道。Lambda_cm 主要影响总周期和输出调节；Lambda_diff 主要影响相位间隔与纹波抵消；Ton_diff 主要影响平均相电流。若不区分这些通道，优化器或人工调参可能通过牺牲 phase spacing 来换取均流，或误用差模阈值调节无法有效改善 DC current sharing。

与已有 IQCOT 描述函数模型相比，IEK 不是替代连续域环路分析，而是补充数字实现中的事件通道分析。与一般 COT sampled-data 模型相比，本文将事件函数具体化为 IQCOT 积分面积，并显式引入 CT、VTH、gm、Ri、检测延迟和面积噪声等参数通道。与多相 DICOT 均流工作相比，本文不提出新的硬件 current balance 电路，而是给出执行量分类和相位代价评估框架。

本文仍有局限。第一，多相仿真模型尚未包含完整 VC 外环补偿器状态；因此 K_m(z) 目前主要反映功率级和事件链路记忆。第二，DCR 失配均流补偿使用 DC algebra 与匹配事件模型 timing cost 的组合验证，尚不是完整失配动态闭环仿真。第三，本文尚未在 Simulink 或硬件中实现严格 IQCOT 面积积分控制器。第四，较大 Ton_trim 下 wait perturbation 可能接近或超过小信号范围，因此论文中应将 Ton-trim 结论限定在受限调节和约束设计语境下。

## 9. 结论

本文提出一种面向多相数字 IQCOT Buck 的积分事件核模态建模方法。该方法从 IQCOT 面积事件出发，将阈值、延迟、噪声和功率级状态记忆统一表示为事件核 K(z)，并进一步分解为 common-mode 与 differential-mode 通道。单相非线性逐周期仿真验证了动态 IEK 的准确性；四相仿真表明，传统 He-only 模型在 common-mode 面积扰动下可能严重失效，差模面积阈值主要影响 phase spacing 而非 DC 均流，Ton-trim 则是强均流执行量但伴随 phase-spacing jitter cost。DCR 失配设计链进一步显示，受限 Ton-trim 可降低 current-sharing error，但必须与事件间隔约束共同设计。该框架为多相数字 IQCOT 的阈值分辨率、延迟预算、相位管理和均流调参提供了统一的小信号分析基础。

## 数据与代码可用性

本文数值结果由以下本地脚本生成：

~~~text
E:/Desktop/codex/output/iqcot_iek_small_signal_validation.py
E:/Desktop/codex/output/iqcot_dynamic_iek_kernel_identification.py
E:/Desktop/codex/output/iqcot_multiphase_iek_modal_study.py
E:/Desktop/codex/output/iqcot_multiphase_current_balance_design.py
~~~

主要 CSV 输出位于：

~~~text
E:/Desktop/codex/output/iqcot_dynamic_iek_nonlinear_frequency_validation.csv
E:/Desktop/codex/output/iqcot_multiphase_iek_common_response.csv
E:/Desktop/codex/output/iqcot_multiphase_iek_differential_offsets.csv
E:/Desktop/codex/output/iqcot_multiphase_iek_ton_trim_offsets.csv
E:/Desktop/codex/output/iqcot_multiphase_current_balance_design.csv
E:/Desktop/codex/output/iqcot_multiphase_current_balance_limited_trim.csv
~~~

## 参考文献

1. M. Bari, *A Novel Inverse Charge Constant On-Time Control for High Performance Voltage Regulators*, Ph.D. dissertation, Virginia Tech, 2018. https://vtechworks.lib.vt.edu/items/cae05986-a69e-4642-875a-71b230bee9cc
2. M. Bari, Q. Li, and F. C. Lee, “High Frequency Small Signal Model for Inverse Charge Constant On-Time (IQCOT) Control,” IEEE ECCE, 2018. https://doi.org/10.1109/ECCE.2018.8557464
3. M. Bari, Q. Li, and F. C. Lee, “Inverse Charge Constant On-Time Control With Ultrafast Transient Performance,” IEEE Journal of Emerging and Selected Topics in Power Electronics, 2021.
4. G. Gabriele et al., “A Unified Sampled-Data Small-Signal Model for a Ripple-Based COT Buck Converter With Arbitrary Ripple Injection Network,” IEEE Transactions on Circuits and Systems I, 2025. https://doi.org/10.1109/TCSI.2025.3557278
5. Y. Li et al., “Multiphase Digital Integration Constant On-Time-Controlled Buck Converter With High-Resolution Current Balance Scheme for Ultrafast Load Transient,” International Journal of Circuit Theory and Applications, 2024. https://doi.org/10.1002/cta.3924
6. Liu et al., “Small-Signal Analysis and Design of Constant On-Time Controlled Buck Converters With Duty-Cycle-Independent Quality Factors,” 2023. [本地已下载文献，正式投稿前需补全卷期页码和 DOI]

## 附录 A：术语表

| 术语 | 定义 |
|---|---|
| IQCOT | Inverse charge constant on-time control |
| IEK | Integral-Event Kernel，积分事件核 |
| Lambda | IQCOT 面积阈值 CT*VTH/gm |
| He | 事件终点面积刚度 h(t_event^-) |
| Hs | 积分起点面积函数值 h(a_k^+) |
| K(z) | 功率级和控制链路状态记忆形成的动态事件核 |
| Lambda_cm | 多相面积阈值共模分量 |
| Lambda_diff | 多相面积阈值差模分量 |
| Ton_diff | 每相 on-time trim 的差模分量 |
| phase-spacing jitter | 相邻相触发间隔扰动 |
| current-sharing error | 平均相电流不均衡 |
