# PETS-IQCOT 修订版：基于补充文献精读后的模型创新定位

本文是对 iqcot_pets_model_innovation.md 的修订版。修订依据为补充目录中的 8 篇文献精读，尤其是 Bari 的 IQCOT 模型、Liu 2023 constant-Q、Yan/Ruan 2022 sampled-data、Gabriele 2025 unified sampled-data RBCOT、Yang control delay、Li 2024 DICOT。

## 1. 创新边界修正

补充文献读完后，PETS-IQCOT 的创新边界必须收缩并变得更精确。

不能声称的内容：

1. 不能声称首次提出 IQCOT 面积/电荷控制律。Bari 已有 integral [VC - Ri*iL] dt = CT*VTH/gm。
2. 不能声称首次提出 IQCOT 高频小信号模型。Bari 已用 describing function 得到 vc-to-vo 模型。
3. 不能声称首次提出 Q auto-tuning。Bari 已通过 gm/VTH 调 Q，Liu 已给出 duty-cycle-independent Q。
4. 不能声称首次提出 COT event-driven sampled-data 递推。Gabriele 2025 已对 RBCOT 给出严格 event-driven sampled-data 模型。
5. 不能泛泛说多相数字 COT/均流没人做。Li 2024 DICOT 已覆盖多相 digital integration COT、任意相数均流模型和 high-resolution TON generator。

保留并强化的创新点：

1. 将 Gabriele 类 event-driven sampled-data 思想专门改写到 IQCOT 的积分面积事件，而不是 RBCOT 的瞬时阈值交叉事件。
2. 将 IQCOT 参数 VTH、gm、CT、Ri 的小信号扰动显式转化为等效面积通道和可辨识低维坐标。
3. 将 constant-Q 的已知公式重参数化为 AI 安全调参变量，而不是让 AI 直接输出 PWM 或分别输出强耦合参数。
4. 区分 detection/sampling/calculation/actuation delay，避免把所有 delay 都粗暴写成阈值偏移。
5. 把多相 DICOT/current-balance 的数字实现难点接入 IQCOT 参数化模型，形成共模 Q 控制加差模均流调节的约束优化框架。

## 2. IQCOT 积分事件方程

定义积分核：

    h(t) = vc(t) - Ri*iL(t)

TOFF 积分 IQCOT 的事件条件写成：

    F_k = integral_{a_k}^{t_{k+1}} h(t) dt - Lambda = 0
    Lambda = CT*VTH/gm

其中 a_k 是第 k 次导通结束后、积分真正开始的时刻。若考虑 blanking 或数字采样起点，a_k 可写为：

    a_k = t_k + Ton,k + Tbl,k

这个事件函数和 Gabriele 2025 RBCOT 中的 y(t_k)=Vref 不同。RBCOT 是瞬时阈值交叉，IQCOT 是积分面积达到阈值。因此 PETS-IQCOT 的贡献是积分事件 sampled-data 化，而不是一般 COT 事件采样思想本身。

## 3. 一阶线性化：低阶局部模型

令：

    t_k = k*Tsw + tau_k
    Ton,k = Ton + ton_hat,k
    Tbl,k = Tbl + tbl_hat,k
    Lambda = Lambda0 + lambda_hat
    Ri = Ri0 + ri_hat

对 F_k 做 Leibniz 积分边界线性化，得到：

    He*tau_{k+1}
    - Hs*(tau_k + ton_hat,k + tbl_hat,k)
    + A_ext,k
    - lambda_hat
    = 0

其中：

    Hs = h(a_k^+)
    He = h(t_{k+1}^-)
    A_ext,k = integral_{a_k}^{t_{k+1}} [vc_hat(t) - Ri0*i_hat(t) - IL(t)*ri_hat] dt

若暂时忽略功率级和补偿网络的跨周期状态记忆，则：

    tau_{k+1} = (Hs/He)*tau_k
                  + (Hs/He)*(ton_hat,k + tbl_hat,k)
                  - A_ext,k/He
                  + lambda_hat/He

这个式子可作为低阶工程近似。它给出一个可测的局部事件极点：

    alpha0 = Hs/He

但注意：精读 Gabriele 2025 后，这个 alpha0 不能被称为完整 sampled-data 极点，只能称为忽略记忆项后的局部近似。

## 4. 更严格的 memory-kernel 形式

根据 Gabriele 2025 的启发，COT 事件扰动会通过功率级、补偿网络、纹波注入网络等状态影响未来多个开关时刻。对 IQCOT 也一样，A_ext,k 不是纯外部输入，它还包含由先前 tau_m 引起的状态扰动。

因此更严格的 PETS-IQCOT 应写为：

    He*tau_{k+1}
    - Hs*tau_k
    + sum_{m<=k} beta_iq(k-m)*tau_m
    + A_u,k
    - lambda_hat,k
    = 0

其中 beta_iq 是 IQCOT 积分事件的记忆核，来自 power stage、compensator、current sensing 和 digital filter 的状态响应。A_u,k 是外部控制扰动、输入扰动、负载扰动和参数扰动直接造成的面积项。

在 z 域中，可以写成：

    Tau(z) = [Lambda_hat(z) - A_u(z)] / [He*z - Hs + B_iq(z)]

或按不同索引约定写成等价形式。这个表达式才是与 sampled-data 文献一致的严谨版本。

## 5. 参数扰动通道

阈值面积：

    Lambda = CT*VTH/gm

因此：

    delta Lambda / Lambda = delta CT/CT + delta VTH/VTH - delta gm/gm

定义可辨识阈值坐标：

    rho = delta ln Lambda = delta ln CT + delta ln VTH - delta ln gm

则：

    lambda_hat = Lambda*rho

Ri 不在 Lambda 中，而在积分核中：

    delta h_Ri(t) = -IL(t)*ri_hat

定义：

    kappa = delta ln Ri

则 Ri 的面积扰动约为：

    A_Ri,k = -Ri0*kappa*integral_{a_k}^{t_{k+1}} IL(t) dt

这说明 AI 不应分别学习 VTH、gm、CT 三个强耦合量，而应优先输出 rho 或 psi 这样的组合坐标。Ri 则应作为另一个独立坐标 kappa 或 current-weight channel。

## 6. constant-Q 与 psi 坐标

Liu 2023 已经给出 IQCOT 可用的 constant-Q 设计：

    Vth = (alpha + beta*D)*Vo
    beta = gm*Ri*Tsw^2/(2*CT*L)

因此本文不能把 constant-Q 公式作为原创。本文只保留其 AI 友好的重参数化：

    psi = Lambda*L/(Ri*Vo*Tsw^2)
    Q2 = 1/[pi*(psi - D/2)]

AI 的作用不是发现该公式，而是在参数误差、延迟、负载动态、多相均流约束下调节：

    psi_cmd = D/2 + 1/(pi*Qstar) + Delta_psi_ai

并保证：

    Qmin <= Q2 <= Qmax

## 7. delay 模型必须分类

Yang control-delay 文献显示：纯控制延迟在 CM-COT 小信号模型中主要表现为 phase lag，幅值变化不明显。因此 PETS-IQCOT 不能把所有 delay 都写成 Lambda_eff。

修正后的 delay 分类：

1. Detection/sampling delay：数字采样晚看到事件，积分面积可能超过阈值。可等效为面积 overshoot。
2. Calculation delay：数字累计值超过阈值后还要计算若干时钟，若积分器继续累加，也可表现为面积 overshoot。
3. Reset delay：事件已判定但积分电容或数字 accumulator 未及时 reset，也可表现为面积 overshoot。
4. Actuation/gate delay：事件已判定，PWM/功率开关晚动作，更接近 transport delay，主要带来 phase lag。

因此只有前三类适合写成：

    Lambda_eff = Lambda + Delta_A_det

其中：

    Delta_A_det ~= He*Td_det + 0.5*Sf*Td_det^2

而 actuation delay 应进入 duty 或功率级路径：

    G_delay(s) = exp(-s*Td_act)

## 8. 多相数字控制接口

Li 2024 DICOT 已经给出多相 digital integration COT、任意相数 current-balance model 和 delay-line high-resolution TON generator。因此 PETS-IQCOT 的多相部分应作为接口创新，而不是重新发明 DICOT。

建议将多相变量分为共模与差模：

    psi_cm 或 rho_cm：调输出电压动态和 IQCOT 高频 Q
    Kcb、omega_cb、Ton_trim_limit：调差模相电流均衡

AI 输出建议：

    u_ai = {Delta_rho_cm, Delta_kappa_cm, Qstar, Kcb, Ton_trim_limit}

安全约束：

    Qmin <= Q_eff <= Qmax
    PM_cm >= PM_min
    PM_dm >= PM_dm_min
    Ton_min <= Ton_j <= Ton_max
    abs(Ton_trim_j) <= Ton_trim_limit
    no DPWM or delay-line limit cycle

## 9. 下一步仿真验证方案

1. 参数灵敏度：对 VTH、gm、CT、Ri 分别施加 1%-5% 小扰动，测量触发时刻变化，验证 rho/kappa 面积通道。
2. 低阶事件极点：对 VTH 加小阶跃，提取 tau_k。如果 tau_{k+1}/tau_k 接近 Hs/He，低阶模型成立；否则拟合 beta_iq memory kernel。
3. delay 分类：分别注入 sampling delay、calculation delay、reset delay、gate delay，区分面积偏移和 phase lag。
4. constant-Q 对照：比较固定 VTH、Liu constant-Q、PETS+AI Delta_psi 三组在 Vin/Vo/Iout 扫描下的 Q、相位裕度、瞬态指标。
5. 多相均流：在 DICOT/Digital IQCOT 模型中扫描 Kcb 和 Ton_trim_limit，验证 AI 约束是否能避免低分辨率均流振荡。

## 10. 推荐论文贡献表述

本文不是首次提出 IQCOT、小信号模型或 constant-Q 控制，而是在已有 IQCOT 描述函数模型、COT sampled-data 模型和 DICOT 多相数字实现基础上，提出一种面向 AI 安全调参的 IQCOT 积分事件参数化模型。该模型将 IQCOT 触发条件表示为积分面积事件，建立包含参数扰动、事件时刻扰动、数字延迟类型和多相均流调节量的 sampled-data 线性化框架，并进一步将其压缩为 rho、kappa、psi_eff 等可辨识安全坐标，为 AI 参数整定提供可解释的约束空间。

