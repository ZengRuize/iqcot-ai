# IEK-IQCOT 小信号模型创新与仿真验证报告

本文当前不再把重点放在 AI 控制器，而是把研究收敛到 IQCOT 本体的小信号建模：从 IQCOT 的积分面积触发条件出发，建立一个可用于数字实现、延迟分析、噪声分析和多相扩展的 Integral-Event Kernel, IEK-IQCOT 模型。

## 1. 与已有文献的边界

已有工作已经覆盖了下列内容，不能作为本文原创点：

- Bari 系列工作已经提出 IQCOT 面积控制律，并给出高频小信号/描述函数模型和 Q tuning 思路。
- Yan/Ruan/Li、Gabriele 等已经把 COT/RBCOT 写成 sampled-data 或 event-driven 小信号模型。
- Liu 等已经给出 duty-cycle-independent Q 的设计方法，并扩展到 charge-based COT/IQCOT。
- Li 等已经研究多相数字积分 COT、相位管理和高分辨率均流。

因此本文的创新不应写成“首次提出 IQCOT 小信号模型”，而应写成：

> 在已有 IQCOT 面积控制律和 COT 采样数据模型基础上，本文将 IQCOT 的积分面积触发条件重写为可参数化的事件核模型，显式分离阈值参数、反馈电阻、检测延迟、面积噪声和功率级记忆核对触发时刻及 duty 扰动的贡献，并通过数值仿真验证这些通道的线性化公式。

这个表述更稳，也更适合毕业设计：它不是否定前人模型，而是把前人模型中较分散的 IQCOT 面积、事件时刻、数字延迟、噪声和 duty 映射统一到同一个小信号框架。

## 2. IQCOT 积分面积事件

单相 IQCOT 的理想触发事件可写为：

~~~text
F_k = integral_{a_k}^{t_{k+1}} h(t) dt - Lambda = 0
h(t) = vc(t) - Ri*iL(t)
Lambda = CT*VTH/gm
~~~

其中 a_k 是第 k 个 on-time 结束并经过 blanking 后的积分起点，t_{k+1} 是下一次触发时刻，vc 是输出/补偿相关电压信息，Ri*iL 是电流反馈注入项，Lambda 是由 CT、VTH、gm 共同决定的面积阈值。

设稳态轨道对应 a_k^0 和 t_{k+1}^0，定义事件时刻扰动：

~~~text
t_k = t_k^0 + tau_k
a_k = a_k^0 + tau_k + ton_hat,k + tbl_hat,k
~~~

在积分上下限都扰动时，对事件函数做一阶变分：

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

He 是事件终点的面积刚度。它越小，事件时刻对阈值、噪声和量化误差越敏感。这一点可以作为 IQCOT 数字实现中的“事件可观测性”指标。

## 3. 参数通道：rho 与 kappa

阈值通道使用对数参数：

~~~text
rho = delta ln(CT*VTH/gm)
delta Lambda = Lambda*rho
~~~

在忽略功率级记忆和其他扰动时：

~~~text
delta tau_{k+1,rho} = Lambda*rho / He
~~~

电流反馈参数写为：

~~~text
kappa = delta ln Ri
delta Ri = Ri0*kappa
~~~

由于：

~~~text
delta h_Ri(t) = -Ri0*kappa*iL0(t)
A_Ri,k = -Ri0*kappa * integral_{a_k}^{t_{k+1}} iL0(t) dt
~~~

所以：

~~~text
delta tau_{k+1,kappa}
= -A_Ri,k / He
= Ri0*kappa*integral iL0(t)dt / He
~~~

这给出一个很清晰的物理解释：增大 Ri 会使 vc - Ri*iL 的积分增长变慢，事件触发推迟；减小 Ri 则触发提前。

## 4. IEK 事件核模型

真实 IQCOT 不是孤立的代数事件，功率级状态会把过去若干次开关扰动带入当前周期。因此将 Astate,k 写成事件核：

~~~text
Astate,k = K0*tau_k + K1*tau_{k-1} + K2*tau_{k-2} + ...
~~~

则通用 IEK-IQCOT 小信号模型为：

~~~text
[He*z - Hs + K(z)] * Tau(z) = U_A(z)
~~~

其中面积域输入为：

~~~text
U_A,k =
Lambda*rho_k
- Aparam,k
+ Hs*(ton_hat,k + tbl_hat,k)
+ DeltaA_det,k
+ wA,k
~~~

这个式子是本文建模的核心。它把 IQCOT 小信号问题从“只看 vc 到 vo 的连续传函”转成“面积事件核到开关时刻，再到 duty 扰动”的离散模型。

对于自治 COT/IQCOT 系统，还必须满足时间平移不变性：

~~~text
He - Hs + K(1) = 0
~~~

这意味着不能简单地把事件相位 tau 当成普通稳定输出；整体相位平移本身是中性模态。真正进入功率级平均行为的是周期/duty 扰动。

## 5. 从事件时刻到 duty 扰动

fixed on-time COT 下，若 on-time 不变，单周期 duty 近似为：

~~~text
D_k = Ton / [Tsw + tau_{k+1} - tau_k]
~~~

一阶化得到：

~~~text
d_hat,k = -D/Tsw * (tau_{k+1} - tau_k)
~~~

因此 IEK 模型到 duty 的传函是：

~~~text
Dhat(z)/U_A(z)
= -D/Tsw * (z - 1) / [He*z - Hs + K(z)]
~~~

当完整自治模型满足 He - Hs + K(1)=0 时，分母在 z=1 有相位中性模态，而 duty 传函的 z-1 会与该模态发生抵消。这个结论很重要：分析 IQCOT 的数字小信号时，应优先识别 duty/周期扰动，而不是直接用绝对事件相位做稳定性判断。

## 6. 低阶近似模型

若暂时忽略功率级记忆核，得到一个用于解释局部参数灵敏度的低阶模型：

~~~text
tau_{k+1} = alpha*tau_k + U_A,k/He
alpha = Hs/He
~~~

其传函为：

~~~text
Tau(z)/U_A(z) = 1 / [He*(z - alpha)]
Dhat(z)/U_A(z) = -D/Tsw * (z - 1) / [He*(z - alpha)]
~~~

这个模型不是完整替代 sampled-data power-stage model，而是一个事件通道的最小可验证模型。它适合用于解释参数、噪声和检测延迟如何先进入事件时刻，再映射到 duty。

## 7. 延迟与噪声通道

若检测/采样链路在理想事件后继续积分，检测延迟可等效为面积 overshoot：

~~~text
DeltaA_det
= integral_0^Td h(t_event+s) ds
~= He*Td + 0.5*Sf*Td^2
~~~

其中 Sf = dh/dt。于是小延迟的一阶事件时刻偏移约为：

~~~text
delta tau_det ~= DeltaA_det/He ~= Td
~~~

需要注意：不是所有 delay 都能写成面积阈值增加。检测/采样延迟更像面积 overshoot；计算延迟和门极驱动延迟更接近 transport delay，主要表现为相位滞后和实际开关动作推迟。

若面积噪声 wA,k 为白噪声，低阶模型下：

~~~text
tau_{k+1} = alpha*tau_k + wA,k/He
~~~

则：

~~~text
sigma_tau^2 = (sigma_A/He)^2 / (1 - alpha^2)
sigma_d = D/Tsw * sqrt(2/(1 + alpha)) * sigma_A/He
~~~

这给出了 IQCOT 数字实现中面积量化、比较器噪声、ADC 噪声对周期 jitter 和 duty jitter 的直接估计公式。

## 8. 数值验证

验证脚本：

~~~text
E:/Desktop/codex/output/iqcot_iek_small_signal_validation.py
~~~

输出文件：

~~~text
E:/Desktop/codex/output/iqcot_iek_channel_validation.csv
E:/Desktop/codex/output/iqcot_iek_frequency_response_validation.csv
E:/Desktop/codex/output/iqcot_iek_memory_kernel_frequency_response_validation.csv
~~~

仿真参数：

~~~text
Lambda0 = 2.5e-9
Hs      = 1.8e-3
Sf      = 3.2e3
Toff0   = 808.232 ns
He      = 4.386342e-3
alpha   = 0.410365
D       = 0.1
Tsw     = 1 us
~~~

### 8.1 参数通道验证

rho 从 -5% 到 +5% 扫描，线性预测误差在约 ±1.5% 内；kappa 从 -5% 到 +5% 扫描，线性预测误差在约 ±1.7% 内。1% 到 2% 的小扰动误差低于 0.7%，说明一阶模型适合作为小信号模型。

典型结果：

~~~text
rho = +1%: exact 5.716 ns, predicted 5.700 ns, error -0.292%
rho = -1%: exact -5.683 ns, predicted -5.700 ns, error 0.293%
kappa = +2%: exact 18.304 ns, predicted 18.426 ns, error 0.668%
kappa = -2%: exact -18.552 ns, predicted -18.426 ns, error -0.677%
~~~

检测延迟通道用二次面积公式验证：

~~~text
Td = 10, 20, 40, 80 ns
predicted delta tau = exact delta tau
~~~

这说明 DeltaA_det ~= He*Td + 0.5*Sf*Td^2 与事件方程完全一致。

### 8.2 低阶事件到 duty 频响验证

脚本对下列频点验证：

~~~text
omega/pi = 0.02, 0.05, 0.10, 0.20, 0.35, 0.50, 0.70
~~~

仿真递推：

~~~text
tau_{k+1} = alpha*tau_k + u_k/He
d_hat,k = -D/Tsw*(tau_{k+1} - tau_k)
~~~

理论传函：

~~~text
Tau/U = 1/[He*(z-alpha)]
Dhat/U = -D/Tsw*(z-1)/[He*(z-alpha)]
~~~

所有频点的幅值和相位误差都达到数值舍入级别，约 1e-12% 到 1e-13 deg。验证了事件时刻到 duty 的离散映射公式。

### 8.3 带记忆核 IEK 频响验证

为了验证通用 IEK 结构，脚本构造一个一阶记忆核：

~~~text
He*z - Hs + k0 + k1*z^-1
~~~

并令：

~~~text
He - Hs + k0 + k1 = 0
~~~

从而满足自治开关系统的时间平移不变性。仿真递推和理论传函在所有频点同样吻合到数值舍入级别。

典型结果：

~~~text
omega/pi = 0.02:
tau_amp = 11.148 ns
duty_amp = 7.0033e-5
error ~ 1e-12

omega/pi = 0.70:
tau_amp = 0.2066 ns
duty_amp = 3.6815e-5
error ~ 1e-12
~~~

这个验证说明 IEK 不是只适用于无记忆近似；只要功率级记忆被识别为 K(z)，同样可以得到严格的事件相位和 duty 小信号传函。

### 8.4 面积噪声验证

面积噪声设置：

~~~text
sigma_A = 8e-12
~~~

仿真与理论：

~~~text
sigma_tau_sim    = 2.001468 ns
sigma_tau_theory = 2.000000 ns
error            = 0.0734%

sigma_duty_sim    = 2.170933e-4
sigma_duty_theory = 2.171885e-4
error             = -0.0438%
~~~

这验证了面积噪声到事件 jitter、duty jitter 的方差公式。

## 9. 可写入论文的创新表述

建议在论文中把创新点写为三条：

1. 提出 IQCOT 积分事件核小信号模型。以 integral(vc - Ri*iL)dt = CT*VTH/gm 为事件函数，利用移动边界线性化得到 He、Hs、K(z) 组成的事件核模型。

2. 建立参数、延迟和噪声的统一面积域通道。使用 rho = delta ln(CT*VTH/gm) 和 kappa = delta ln Ri 分离阈值参数和电流反馈参数，并给出检测延迟面积 DeltaA_det、面积噪声 wA 到事件 jitter/duty jitter 的解析公式。

3. 推导事件核到 duty 的离散小信号传函。给出 Dhat/U_A = -D/Tsw*(z-1)/[He*z - Hs + K(z)]，并指出自治 IQCOT 中事件相位存在时间平移中性模态，稳定性和功率级作用应通过周期/duty 扰动分析。

## 10. 后续仿真实践路线

下一步最有价值的验证不是继续只扫参数，而是在 Simulink 中搭建一个显式 IQCOT 面积事件控制器：

~~~text
vc - Ri*iL -> integrator -> compare with CT*VTH/gm -> trigger -> fixed Ton
~~~

然后做三类实验：

- 小扰动注入：分别注入 rho、kappa、DeltaA_det，测量事件时刻和 duty 响应；
- 核识别：给面积阈值注入多频小信号，拟合 K(z)，检查 He - Hs + K(1)=0；
- 工程对比：把显式面积 IQCOT 与现有 v0027 工程型 COT/IQCOT adapter 对比，区分“严格面积事件 IQCOT”和“数字 COT on-time trimming”两类模型。

这样论文的理论和仿真会形成闭环：先有积分面积事件推导，再有离散事件核传函，最后有显式面积事件仿真验证。
