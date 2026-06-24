# IQCOT 补充文献精读札记与 PETS-IQCOT 修正

阅读对象：E:/Desktop/毕设调研/文献调研/iqcot/补充 下 8 篇 PDF。全文提取目录：E:/Desktop/codex/tmp/iqcot_supplement_extract。

## 1. Bari IQCOT 文献

Bari 的博士论文、JESTPE 期刊版和 ECCE 2018 小信号论文已经明确提出 IQCOT 的面积/电荷控制律：

    integral_0^Toff [VC - Ri*iL(t)] dt = CT*VTH/gm

并且已经用 describing function 推导了 IQCOT 的高频小信号模型，指出半开关频率附近 Q 值随 duty cycle 变化，还提出了通过 gm 或 VTH 调节 Q 的 auto-tuning 方法。

对 PETS-IQCOT 的影响：不能声称首次提出 IQCOT 面积控制律、首次发现 Q 随 duty 变化、首次提出 IQCOT Q auto-tuning、首次用扰动面积分析 IQCOT。可保留的空间是：Bari 主要给出连续域 vc-to-vo 描述函数模型，而 PETS-IQCOT 研究面向数字控制和 AI 参数整定的事件采样、参数灵敏度、延迟类型和安全坐标。

## 2. Liu 2023 constant-Q 文献

Liu 等给出 duty-cycle-independent Q 的系统方法，并明确扩展到 IQCOT。对 charge-based COT/IQCOT 类型，阈值可设计为：

    Vth = (alpha + beta*D)*Vo
    beta = gm*Ri*Tsw^2/(2*CT*L)

其中 beta 抵消 duty cycle 项，alpha 决定目标 Q 值。文献还做了 component tolerance 和 VQ tolerance 分析。

对 PETS-IQCOT 的影响：psi 或 Q2 = 1/[pi*(psi-D/2)] 只能作为 AI 友好的重参数化，不能作为原创 constant-Q 公式。PETS-IQCOT 的空间在于把 constant-Q 坐标用于 AI 约束调参，并把 tolerance、估计误差、数字延迟和多相均流代价统一进 psi_eff 或优化约束。

## 3. Yan/Ruan/Li 2022 COT sampled-data 文献

该文指出 COT/COFT 的 duty perturbation 在每个周期有两组 narrow pulse signals；ripple-based control 从小信号角度可以理解为 sampler；采样瞬间的斜率和 sideband effect 不能忽略；sampled-data 方法还能扩展到 digital control。

对 PETS-IQCOT 的影响：简单低频平均模型不足以支撑高带宽 VRM。原先的 tau_{k+1} = (Hs/He)*tau_k + ... 只能作为低阶近似，完整模型应包含由功率级状态记忆产生的 sideband/memory kernel。

## 4. Gabriele 2025 unified sampled-data RBCOT 文献

这篇是与 PETS-IQCOT 最接近的相邻工作。它从状态空间出发，把 COT converter 描述为由隐式开关条件决定的 event-driven system。文献给出开关时刻扰动 tk = kT + t_tilde_k，duty 扰动由一对间隔 Ton 的窄脉冲组成，并通过对隐式开关条件求导得到线性递推：

    alpha*xi_k + sum beta_{k-m}*xi_m = forcing_k

再用 z-transform 得到控制到 duty 的 sampled-data 小信号传函。

重大修正：不能把事件触发采样递推本身作为 PETS-IQCOT 独创点。PETS-IQCOT 必须收缩为：把 Gabriele 类事件采样思想专门用于 IQCOT 的积分面积事件，而不是 RBCOT 的瞬时阈值交叉事件；把事件函数从 y(tk)=Vref 改为 integral_{a_k}^{t_{k+1}} [vc(t)-Ri*iL(t)]dt = CT*VTH/gm；再推导 VTH/gm/CT/Ri 参数扰动、数字延迟和 AI 安全坐标。

因此 PETS-IQCOT 的严格形式应写为：

    He*tau_{k+1} - Hs*tau_k
    + sum_{m<=k} beta_{k-m}^{IQCOT} tau_m
    + A_ext,k - lambda_hat = 0

忽略功率级记忆时，才退化为：

    tau_{k+1} ~= (Hs/He)*tau_k - A_ext,k/He + lambda_hat/He

## 5. Yang control delay 文献

Yang 等提出 CM-COT Phase Lag model。主要结论是：控制延迟来自 comparator 有限带宽和功率器件驱动延迟；延迟会恶化 transient response 并限制 switching frequency；在其模型和 SIMPLIS 验证中，加入 delay 后传函幅值基本不变，主要变化是 phase lag。

对 PETS-IQCOT 的修正：不能把所有 delay 都粗暴等效为阈值面积增加。需要区分 detection/sampling delay、calculation delay、actuation/gate delay。只有检测、采样、积分复位滞后可能表现为面积 overshoot；纯门极执行延迟更接近 transport delay，主要表现为相位滞后。

## 6. Li 2024 DICOT 文献

Li 等提出多相 DICOT：数字 COT 的 A/D sample delay 和 digital calculation delay 会限制高开关频率；DICOT 用 signal accumulation 改善采样延迟和采样噪声问题；phase manager 使控制信号频率不随相数 N 增加；TON generator 由数字 counter 实现，current balance 通过修改 Ton threshold 实现；delay-line-based high-resolution 方案提升均流分辨率，文中给出约 6 mA 的电流调节分辨率；还给出适用于任意相数 N 的多相 COT current balance model。

对 PETS-IQCOT 的影响：多相数字控制难点不能泛泛说没人做。PETS-IQCOT 应聚焦 IQCOT 积分事件参数如何数字化，VTH/gm/Ri/CT 与 DICOT accumulated signal/threshold 如何对应，以及 AI 如何在不破坏 DICOT 相位管理和均流结构的前提下调节 psi_cm、Kcb、Ton_trim_limit 等安全参数。

## 7. 修正后的贡献表述

本文在已有 IQCOT 描述函数模型、COT sampled-data 模型和 DICOT 多相数字实现基础上，提出一种面向 AI 参数整定的 IQCOT 积分事件参数化模型。该模型将 IQCOT 的触发条件表示为积分面积事件，并对该事件进行采样数据线性化，显式给出阈值参数、电流反馈权重、数字采样/计算延迟和多相均流调节量进入事件时刻扰动的通道。进一步，本文将这些通道重参数化为 rho = delta ln(CT*VTH/gm)、kappa = delta ln Ri 和 psi_eff 等低维可辨识坐标，用于构造满足 Q 值、相位裕度、DPWM 分辨率和均流稳定性的 AI 约束调参器。

## 8. 下一步验证

验证 A：对 VTH、gm、CT、Ri 分别施加 1%-5% 小扰动，测量触发时刻变化，验证参数面积灵敏度。

验证 B：给 VTH 一个小阶跃，测量相邻周期事件时刻扰动。若功率级记忆弱，应近似满足 tau_{k+1}/tau_k ~= Hs/He；若偏差明显，应拟合完整 memory kernel。

验证 C：分别建模 sampling/detection delay、calculation delay、gate actuation delay，检查哪一类更像面积阈值偏移，哪一类更像 phase lag。

验证 D：AI 不直接输出 PWM，而输出 Delta rho、Delta kappa、Qstar、Kcb、Ton_trim_limit，并强制 Q、相位裕度、Ton 边界和 DPWM/Delay-line limit-cycle 约束。

