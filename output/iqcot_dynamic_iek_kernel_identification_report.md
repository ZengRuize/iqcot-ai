# 动态 IEK-IQCOT 事件核识别与非线性验证

本阶段把前一版 IEK-IQCOT 从“给定事件核再验证公式”推进到“从显式 IQCOT 面积事件开关系统中反向识别事件核”。这样更接近论文里的可验证创新：不是只写一个形式化小信号方程，而是说明这个方程如何由 Buck 功率级和 IQCOT 积分事件共同产生，并用非线性逐周期仿真验证。

## 1. 本阶段新增创新点

前一阶段的 IEK 模型为：

~~~text
[He*z - Hs + K(z)] * Tau(z) = U_A(z)
Dhat/U_A = -D/Tsw * (z - 1) / [He*z - Hs + K(z)]
~~~

这一次新增的是动态核识别方法：

1. 对显式 Buck-IQCOT 面积事件模型求稳态周期轨道；
2. 对固定 on-time 与变 off-time 面积事件做精确移动边界线性化；
3. 得到阈值面积扰动到周期扰动的 sampled-data 状态空间传函；
4. 由周期传函反推出等效 IEK 事件核 K(z)；
5. 用非线性逐周期事件求解验证该 K(z) 对周期和 duty 频响的预测。

这个创新点比“无记忆 alpha 模型”更强，因为它保留了功率级电感、电容、DCR 和负载引起的状态记忆。

## 2. 显式 Buck-IQCOT 面积事件模型

功率级状态取：

~~~text
x = [iL, vC]^T
~~~

on/off 两个区间的线性状态方程为：

~~~text
dx/dt = A*x + b_on   during on-time
dx/dt = A*x + b_off  during off-time
~~~

其中：

~~~text
A = [-DCR/L, -1/L
      1/C,     0 ]

b_on  = [Vin/L, -Iload/C]^T
b_off = [0,     -Iload/C]^T
~~~

IQCOT off-time 事件为：

~~~text
Aevent(T_off, x_a)
= integral_0^T_off [VC - Ri*iL(t)] dt
= Lambda
~~~

x_a 是 on-time 结束、off-time 开始时的状态。本文没有用固定步长积分近似，而是使用矩阵指数精确计算状态转移：

~~~text
x(t) = x_ss + exp(A*t)*(x0 - x_ss)
integral_0^t x(s)ds = t*x_ss + A^-1*(exp(A*t)-I)*(x0-x_ss)
~~~

因此面积事件和小信号导数都可以精确计算。

## 3. 稳态轨道与移动边界线性化

固定 on-time 为 Ton，稳态 off-time 为 Toff。状态转移写作：

~~~text
x_a,k = Phi_on*x_k + g_on
x_{k+1} = Phi_off(Toff)*x_a,k + g_off(Toff)
~~~

稳态周期轨道满足：

~~~text
x_0 = Phi_off*Phi_on*x_0 + Phi_off*g_on + g_off
~~~

对面积事件做一阶扰动：

~~~text
M*delta x_a,k + He*delta T_k - delta Lambda_k = 0
~~~

其中：

~~~text
M  = d Aevent / d x_a
He = h(t_event^-) = VC - Ri*iL(t_event^-)
~~~

所以：

~~~text
delta T_k
= (delta Lambda_k - M*Phi_on*delta x_k) / He
= Ct*delta x_k + Dt*delta Lambda_k

Ct = -M*Phi_on/He
Dt = 1/He
~~~

事件后的状态扰动为：

~~~text
delta x_{k+1}
= Phi_off*Phi_on*delta x_k + f_e*delta T_k
= Ad*delta x_k + Bd*delta Lambda_k

Ad = Phi_off*Phi_on + f_e*Ct
Bd = f_e*Dt
~~~

这里 f_e 是 off-time 终点的状态导数。这个式子就是显式 IQCOT 面积事件的 sampled-data 小信号模型。

## 4. 从状态空间传函反推出 IEK 核

由上式可得阈值面积扰动到周期扰动的传函：

~~~text
G_T(z) = DeltaT(z)/DeltaLambda(z)
       = Ct*(zI - Ad)^-1*Bd + Dt
~~~

IEK 模型中：

~~~text
DeltaT/U_A = (z - 1) / [He*z - Hs + K(z)]
~~~

因此可以反解：

~~~text
K(z) = (z - 1)/G_T(z) - (He*z - Hs)
~~~

这就是本阶段提出的“动态 IEK 核识别”方法。它把 IQCOT 的小信号模型从参数拟合推进到可由功率级状态方程直接计算。

## 5. 时间平移不变性

自治 COT/IQCOT 系统对整体时间平移不敏感，因此 IEK 核必须满足：

~~~text
He - Hs + K(1) = 0
K(1) = Hs - He
~~~

这不是一个可有可无的数学细节。它说明绝对事件相位 tau 不是普通稳定输出；真正作用到功率级平均行为的是：

~~~text
DeltaT_k = tau_{k+1} - tau_k
d_hat,k = -D/Tsw * DeltaT_k
~~~

所以后续论文里应避免直接用 tau 的绝对值判断稳定性，而应分析周期扰动、duty 扰动或相邻事件间隔。

## 6. 仿真脚本与参数

脚本：

~~~text
E:/Desktop/codex/output/iqcot_dynamic_iek_kernel_identification.py
~~~

输出：

~~~text
E:/Desktop/codex/output/iqcot_dynamic_iek_kernel_summary.csv
E:/Desktop/codex/output/iqcot_dynamic_iek_nonlinear_frequency_validation.csv
E:/Desktop/codex/output/iqcot_dynamic_iek_kernel_samples.csv
~~~

主要参数：

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

稳态轨道与事件参数：

~~~text
i_event       = 5.4259 A
v_event       = 0.984292 V
i_off_start   = 14.5932 A
v_off_start   = 0.984293 V
VC            = 8.7966 mV
Lambda        = 6.961313e-9
Hs            = 1.5000 mV
He            = 6.0837 mV
K(1)=Hs-He    = -4.5837 mV
~~~

线性化 Poincare 状态矩阵特征值：

~~~text
eig(Ad) = 0.990890, 0.245125
~~~

第一个特征值接近 1，说明输出电容和功率级低频状态带来了明显的慢记忆。这正是无记忆 alpha 模型无法覆盖的部分。

## 7. 非线性逐周期验证

验证方法：对面积阈值施加小正弦扰动：

~~~text
Lambda_k = Lambda0 + A_lambda*sin(omega*k)
A_lambda = 2.0e-11
~~~

每个周期用非线性面积方程精确求解 off-time：

~~~text
integral_0^T_off [VC - Ri*iL(t)]dt = Lambda_k
~~~

然后测量：

~~~text
DeltaT_k = T_off,k - Toff0
d_hat,k  = -D/Tsw*DeltaT_k
~~~

并与线性理论：

~~~text
G_T(z) = Ct*(zI - Ad)^-1*Bd + Dt
G_d(z) = -D/Tsw * G_T(z)
~~~

进行频响比较。

结果最大误差：

~~~text
period_amp_error_max  = 0.000157 %
period_phase_error_max = 4.07e-5 deg
duty_amp_error_max    = 0.000157 %
duty_phase_error_max  = 4.07e-5 deg
~~~

典型频点：

~~~text
omega/pi = 0.01:
period_amp = 1.34339 ns
period_err = 0.0002 %

omega/pi = 0.10:
period_amp = 1.18113 ns
period_err = 0.0000 %

omega/pi = 0.70:
period_amp = 5.01315 ns
period_err = 0.0001 %
~~~

这说明动态 IEK 线性化不仅在形式上成立，而且能准确预测非线性 IQCOT 面积事件系统的小信号周期和 duty 响应。

## 8. K(z) 核的低频极限验证

理论要求：

~~~text
K(1) = Hs - He = -4.5837 mV
~~~

数值识别得到：

~~~text
omega/pi = 0.001: K = -4.5877 - j0.0072 mV
omega/pi = 0.002: K = -4.6000 - j0.0143 mV
omega/pi = 0.005: K = -4.6875 - j0.0345 mV
~~~

可以看到，当 z -> 1 时，K(z) 确实逼近 Hs-He。频率升高后 K(z) 变成明显复数：

~~~text
omega/pi = 0.05: K = 3.3860 + j1.6765 mV
omega/pi = 0.20: K = 0.0851 + j0.1512 mV
omega/pi = 0.70: K = -0.0312 + j0.0239 mV
~~~

这说明功率级记忆不是一个常数修正项，而是频率相关的动态事件核。这个结论可以作为论文中区别于简单描述函数或低阶经验模型的重点。

## 9. 对 IQCOT 小信号建模的意义

本阶段得到三个重要结论：

1. IQCOT 面积事件可以从功率级状态方程严格线性化，得到阈值面积到周期扰动的 sampled-data 状态空间模型。

2. IEK 核 K(z) 可以从 G_T(z) 反推出，并且满足 K(1)=Hs-He 的自治系统时间平移约束。

3. 无记忆 alpha 模型只适合解释局部参数通道；真实 Buck-IQCOT 中的输出电容、电感和 DCR 会形成明显功率级记忆，表现为 K(z) 的复数频率响应和 Ad 的慢特征值。

因此，本文可以形成一个更严谨的研究链条：

~~~text
IQCOT 积分面积事件
-> 移动边界线性化
-> sampled-data 状态空间模型
-> 动态 IEK 核 K(z)
-> 周期/duty 小信号频响
-> 非线性逐周期仿真验证
~~~

## 10. 后续可扩展方向

接下来可以把该方法扩展到三类更接近毕业设计应用的模型：

- 加入 VC 外环动态，使 K(z) 同时包含功率级和补偿器记忆；
- 扩展到四相交错 IQCOT，分解 common-mode 事件核和 differential/current-balance 事件核；
- 在 Simulink 中实现显式面积积分 IQCOT 控制器，用仿真波形做数据驱动的 K(z) 识别，并与本文精确线性化结果对照。

这一阶段的结果已经足够支撑一节“动态事件核小信号建模与验证”，比只讨论 AI 调参更像扎实的控制建模创新。
