# IEK-IQCOT 小信号创新点的实际价值评估

本文回答一个关键问题：IEK-IQCOT 动态事件核模型到底有没有实际价值？如果只是把已有 IQCOT 小信号模型换一种写法，它不够强；如果它能带来更准确的预测、更明确的参数设计规则和更可靠的数字实现约束，那么它才值得作为毕业设计创新点。

结论先说清楚：**这个创新点有实际价值，但它的价值不在于替代 Bari 的 IQCOT 描述函数模型，也不在于声称首次建立 IQCOT 小信号模型；它的价值在于把 IQCOT 积分事件、数字参数、延迟、噪声和功率级记忆统一到事件核 K(z) 中，使参数设计和数字实现约束可以被量化。**

## 1. 相比以前模型的核心差别

以前常见分析可以分成三类：

1. 描述函数/连续域小信号模型  
   重点是从控制信号到输出电压的频域关系，适合分析 Q 值、带宽和稳定性，但通常不会显式告诉你 CT、VTH、gm、Ri、检测延迟和面积噪声分别如何进入事件时刻和 duty jitter。

2. COT sampled-data 模型  
   能描述事件驱动和采样效应，但一般事件函数是比较器阈值交叉，例如 v_ramp = Vref，而不是 IQCOT 的积分面积事件 integral(vc - Ri*iL)dt = CT*VTH/gm。

3. 简单局部面积刚度模型  
   直接用 deltaT ~= deltaLambda/He 估计阈值扰动对触发时间的影响。这个模型直观，但忽略功率级状态记忆，所以只能做很局部、很低阶的估算。

IEK-IQCOT 的差别是：

~~~text
[He*z - Hs + K(z)] * Tau(z) = U_A(z)
Dhat/U_A = -D/Tsw * (z - 1) / [He*z - Hs + K(z)]
~~~

其中 K(z) 是由电感、电容、DCR、负载和外环状态共同形成的动态事件核。它不是一个经验补丁，而是可以从显式 IQCOT 面积事件模型中识别出来。

## 2. 最直接的实际价值：预测更准

我做了一个对比实验：

- 对象：显式 Buck-IQCOT 面积事件模型；
- 扰动：面积阈值 Lambda_k = Lambda0 + 2e-11*sin(omega*k)；
- 比较对象：
  - 传统静态 He-only 模型：deltaT = deltaLambda/He；
  - 动态 IEK 模型：G_T(z)=Ct*(zI-Ad)^-1*Bd+Dt；
  - 非线性逐周期面积事件仿真。

脚本：

~~~text
E:/Desktop/codex/output/iqcot_iek_practical_value_comparison.py
~~~

输出：

~~~text
E:/Desktop/codex/output/iqcot_iek_practical_value_summary.csv
E:/Desktop/codex/output/iqcot_iek_practical_value_static_vs_dynamic.csv
E:/Desktop/codex/output/iqcot_iek_practical_value_nonlinear_comparison.csv
~~~

关键结果：

~~~text
He = 6.0837 mV
Hs = 1.5000 mV

静态 He-only 模型预测周期幅值 = 3.2875 ns
动态 IEK 模型 DC 周期幅值     = 5.2672 ns
静态模型 DC 误差              = -37.58%

相对非线性事件仿真：
静态模型最大幅值误差          = 771.62%
动态 IEK 最大幅值误差          = 0.00018%

静态模型最大相位误差          = 77.18 deg
动态 IEK 最大相位误差          = 0.00004 deg
~~~

这说明 IEK 的价值不是“公式更复杂”，而是它真的能预测旧模型预测不了的频率相关效应。

## 3. 为什么静态模型会错这么多

静态模型只看事件终点面积刚度：

~~~text
deltaT ~= deltaLambda/He
~~~

它隐含假设是：off-time 起点状态不随过去周期扰动变化。但真实 Buck-IQCOT 中，电感电流和输出电容电压会把过去周期的扰动带入当前周期。

在当前模型中，线性化 Poincare 矩阵特征值为：

~~~text
eig(Ad) = 0.990890, 0.245125
~~~

0.990890 这个慢特征值说明输出电容状态有很强的低频记忆。这个记忆会改变阈值扰动到周期扰动的幅值和相位，所以单纯用 He 估计会错。

## 4. 对数字 IQCOT 参数设计的价值

IEK 模型能直接变成工程设计指标。

### 4.1 面积量化/阈值 DAC 分辨率预算

假设希望面积阈值扰动引起的周期扰动峰值小于 1 ns。

静态模型给出的面积预算为：

~~~text
sigma_A_allow_static = 6.084e-12
~~~

动态 IEK 在 DC/低频处给出的预算为：

~~~text
sigma_A_allow_dynamic = 3.797e-12
~~~

也就是说，静态模型会把允许的阈值/面积误差估得过宽，可能导致数字阈值 DAC、积分器量化或比较器噪声预算偏乐观。对于高性能 VRM，这类 1 ns 级 jitter 已经会影响等效频率、相位交错和输出纹波。

### 4.2 可识别敏感频段

动态 IEK 预测的周期响应不是平坦的：

~~~text
omega/pi = 0.00: period_amp = 5.2672 ns
omega/pi = 0.02: period_amp = 0.4932 ns
omega/pi = 0.05: period_amp = 0.3772 ns
omega/pi = 0.70: period_amp = 5.0132 ns
~~~

这说明 IQCOT 面积阈值扰动存在频率相关的敏感区和低敏感区。实际意义是：

- 如果做数字校准 dither，不应只看扰动幅值，还应看它落在哪个离散频率；
- 如果噪声可以被整形，应该避开周期响应高敏感频段；
- 如果检测延迟或计算延迟形成周期性扰动，IEK 可以预测它对 switching jitter 的放大程度。

静态 He-only 模型完全看不出这些频率选择性。

### 4.3 区分事件相位和 duty 扰动

IEK 强制满足：

~~~text
K(1) = Hs - He
~~~

这个条件来自自治开关系统的时间平移不变性。它提醒我们：绝对事件相位 tau 不是最终工程指标，真正进入平均模型和纹波的是：

~~~text
DeltaT_k = tau_{k+1} - tau_k
d_hat,k = -D/Tsw * DeltaT_k
~~~

这能避免一个常见错误：把事件相位漂移误判为系统不稳定，或者用不合适的相位变量设计数字补偿。

## 5. 相比以前更优秀的地方

更优秀的地方可以概括成四点：

1. 参数通道更清楚  
   rho = delta ln(CT*VTH/gm)、kappa = delta ln Ri、DeltaA_det、wA 都进入同一个面积域输入 U_A，不再分散在经验调参里。

2. 能处理数字实现问题  
   阈值 DAC 分辨率、积分器面积噪声、采样/检测延迟、周期 jitter 都能通过同一个 G_T(z) 或 Dhat/U_A 估计。

3. 能解释功率级记忆  
   K(z) 把电感、电容、DCR 和负载造成的状态记忆显式表示出来。当前例子中，慢特征值 0.990890 导致静态模型在低频误差达到 37.58%。

4. 能和非线性仿真闭合  
   动态 IEK 与非线性逐周期面积事件仿真的误差低到 0.00018%，说明它不是纯形式推导，而是可验证的小信号模型。

## 6. 还不够强的地方

这个创新点目前仍有边界：

- 现在验证的是单相 Buck-IQCOT，没有加入多相相位管理和均流环；
- VC 目前可以看成固定或简化处理，还没有把补偿器外环完整纳入 K(z)；
- 还没有在用户的 Simulink v0027 模型中实现严格的面积积分事件控制器；
- 目前 K(z) 是模型计算/识别得到，还需要总结成更适合设计人员使用的低阶近似形式。

所以它已经有实际价值，但还可以继续加强。

## 7. 下一步最值得继续研究的方向

下一步不应该泛泛地说“加 AI”，而是继续把 IEK 变成设计工具：

1. 外环补偿器纳入 IEK  
   把 VC 的 PI/Type-III 补偿动态加入状态 x，使 K(z) 同时包含功率级和控制器记忆。

2. 多相 IEK 分解  
   对四相 IQCOT 建立 common-mode 核和 differential/current-balance 核：

~~~text
K_cm(z): 影响输出电压和总周期 jitter
K_diff(z): 影响相间电流均衡和相位偏差
~~~

3. 设计指标化  
   从 K(z) 提取三类工程指标：

~~~text
S_A,max   = max |DeltaT/DeltaA|
S_d,max   = max |d_hat/DeltaA|
A_budget  = T_jitter_limit / S_A,max
~~~

4. Simulink 显式面积事件验证  
   搭建真正的 vc - Ri*iL 积分器、面积阈值比较器、fixed Ton 触发器，然后用仿真波形识别 K(z)，与理论脚本对照。

这会让创新点从“理论模型”进一步变成“参数设计和数字实现约束方法”。
