# IQCOT 小信号模型创新稿：PETS-IQCOT 参数化事件触发采样模型

本文给出一个相对严谨、可用于硕士毕业设计的 IQCOT 小信号模型创新方案。它不把“提出 IQCOT 控制律”“提出 IQCOT 高频小信号模型”“提出 constant-Q”作为创新点，因为这些已有文献覆盖。本文的创新定位是：

> 在已有 IQCOT 描述函数模型和 constant-Q 设计基础上，建立一种面向数字控制与 AI 参数整定的 PETS-IQCOT 模型，即 Parameterized Event-Triggered Sampled small-signal model。该模型从 IQCOT 积分事件方程出发，显式推导开关时刻扰动、参数扰动、数字延迟和多相均流扰动进入小信号模型的方式。

---

## 1. 与已有文献的边界

已有 Bari 的 IQCOT 研究给出了基本积分控制律：

    iramp = gm * [vc(t) - Ri*iL(t)]
    integral(iramp) dt = CT*VTH

等价为：

    integral [vc(t) - Ri*iL(t)] dt = Lambda
    Lambda = CT*VTH/gm

并已经用 describing function 推导了 IQCOT 的高频小信号模型，说明半开关频率附近双极点的 Q 值会随占空比变化，且可以通过 gm 或 VTH 自动调节。Liu 等 constant-Q 文献进一步给出了 duty-cycle-independent Q 的设计思想。因此，本文不能声称这些是原创。

本文真正新增的是：

1. 把 IQCOT 看成事件触发系统，而不只是连续等效传函。
2. 对积分触发事件做一阶移动边界线性化，得到开关时刻扰动递推方程。
3. 将 VTH/gm/CT/Ri/Td/Ton 的参数扰动统一为“等效面积扰动”。
4. 提出最小可辨识 AI 调参坐标，避免让 AI 分别学习高度耦合的 VTH、gm、CT。
5. 给出数字延迟修正后的 Q2_eff，使 delay、DPWM 量化和采样噪声可以进入稳定性约束。

---

## 2. 事件触发面积方程

以单相 TOFF 积分 IQCOT Buck 为例。令第 k 次高边导通开始时刻为：

    t_k

导通结束、积分开始时刻为：

    a_k = t_k + Ton,k + Tbl,k

其中 Tbl,k 可以表示 blanking、最小 off-time 或等效积分起点延迟。下一次触发时刻为 t_{k+1}。定义积分核：

    h(t) = vc(t) - Ri*iL(t)

IQCOT 事件触发条件为：

    F_k = integral_{a_k}^{t_{k+1}} h(t) dt - Lambda = 0
    Lambda = CT*VTH/gm

这个方程的关键含义是：系统不是在固定采样周期上更新，而是在“面积达到阈值”时更新。传统 describing function 模型把最终结果转化为 vc -> vo 传函，而 PETS-IQCOT 保留触发事件本身。

---

## 3. 稳态面积关系

在 CCM 且 off-time 内 vc 近似常值时，off-time 电感电流下降：

    diL/dt = -Vo/L

因此：

    dh/dt = -Ri*diL/dt = Ri*Vo/L = Sf

令稳态 off-time 为 Toff = Tsw - Ton，积分起点和终点处面积增长斜率为：

    Hs = h(a_k^+)
    He = h(t_{k+1}^-)

由于 off-time 内 h 近似线性上升：

    He = Hs + Sf*Toff
    Lambda = Hs*Toff + 0.5*Sf*Toff^2

所以：

    Hs = Lambda/Toff - 0.5*Sf*Toff
    He = Lambda/Toff + 0.5*Sf*Toff

这一步比只写 integral h dt = Lambda 更有用，因为 Hs/He 会成为开关时刻扰动的离散极点。

---

## 4. 一阶移动边界线性化

令：

    t_k = k*Tsw + tau_k
    Ton,k = Ton + ton_hat,k
    Tbl,k = Tbl + tbl_hat,k
    Ri = Ri0 + ri_hat
    Lambda = Lambda0 + lambda_hat
    vc = VC + vc_hat
    iL = IL(t) + i_hat

对：

    F_k = integral_{a_k}^{t_{k+1}} [vc(t)-Ri*iL(t)] dt - Lambda = 0

使用 Leibniz 积分求导公式，得到：

    He*tau_{k+1}
    - Hs*(tau_k + ton_hat,k + tbl_hat,k)
    + integral_{a_k}^{t_{k+1}} [vc_hat(t) - Ri0*i_hat(t) - IL(t)*ri_hat] dt
    - lambda_hat
    = 0

整理为开关时刻扰动递推：

    tau_{k+1}
    = alpha*tau_k
    + alpha*(ton_hat,k + tbl_hat,k)
    - A_x,k/He
    + lambda_hat/He

其中：

    alpha = Hs/He
    A_x,k = integral_{a_k}^{t_{k+1}} [vc_hat(t) - Ri0*i_hat(t) - IL(t)*ri_hat] dt

这是 PETS-IQCOT 的核心方程。

它揭示了一个传统连续传函不明显的结论：IQCOT 的触发时刻本身存在一个离散记忆极点：

    z = alpha = Hs/He

在设计良好的工作点，通常 0 < Hs < He，所以这个极点在单位圆内。若 Hs 接近 He，事件时刻记忆增强；若 Hs 很小，触发时刻主要由当周期面积扰动决定。若参数选择导致 Hs < 0，则 alpha 变为负值，时刻扰动会呈现交替周期衰减或放大趋势，这可作为接近亚谐波/量化振荡风险的早期判据。这个离散极点可以通过仿真提取相邻周期 tau_k 的衰减来验证。

---

## 5. 从时刻扰动到占空比扰动

第 k 个周期长度为：

    Tk = t_{k+1} - t_k

因此：

    T_hat,k = tau_{k+1} - tau_k

占空比：

    Dk = Ton,k / Tk

一阶线性化得：

    d_hat,k = ton_hat,k/Tsw - D/Tsw*(tau_{k+1}-tau_k)

对于固定 on-time IQCOT：

    d_hat,k = -D/Tsw*(tau_{k+1}-tau_k)

因此，面积扰动不是直接变成 duty，而是先经过事件时刻递推，再由相邻开关时刻差分生成 duty 扰动。这个结构可以解释为什么 COT/IQCOT 对边带、量化噪声和数字延迟特别敏感。

---

## 6. 参数扰动的等效面积通道

由于：

    Lambda = CT*VTH/gm

有：

    lambda_hat/Lambda
    = ct_hat/CT + vth_hat/VTH - gm_hat/gm

定义最小可辨识阈值坐标：

    rho = delta ln Lambda
        = delta ln CT + delta ln VTH - delta ln gm

则：

    lambda_hat = Lambda*rho

电流反馈权重 Ri 的扰动不是简单进入阈值，而是进入被积函数：

    delta h_Ri(t) = -IL(t)*ri_hat
                  = -Ri0*IL(t)*kappa

其中：

    kappa = delta ln Ri

代入开关时刻递推后，参数到触发时刻的通道为：

    tau_theta,k
    = [Lambda*rho + Ri0*integral_{a_k}^{t_{k+1}} IL(t)dt*kappa] / He

这给出一个很重要的 AI 建模结论：

> 从 IQCOT 事件角度看，VTH、gm、CT 在小信号上首先只通过 rho = ln(CT*VTH/gm) 这一组合被系统识别；让 AI 分别输出 VTH、gm、CT 会产生不可辨识和病态优化。更合理的 AI 输出是 rho 或 psi，再由物理约束映射回实际参数。

---

## 7. 数字延迟的面积修正

数字 IQCOT/DICOT 中，比较器、ADC、计算和 DPWM 会带来总延迟：

    Td = Tadc + Tcalc + Tdpwm

实际开关沿比理论面积达到阈值的时刻晚 Td。因此，在实际开关沿看来，系统多积了一块面积：

    Delta_A_delay
    = integral_{t_cross}^{t_cross+Td} h(t)dt

若 Td 不大，使用二阶近似：

    Delta_A_delay
    ≈ He*Td + 0.5*Sf*Td^2

于是实际等效阈值为：

    Lambda_eff = Lambda + He*Td + 0.5*Sf*Td^2

这一步是 PETS-IQCOT 相对已有 constant-Q 公式的一个可用扩展：延迟不再只是“相位滞后”，而是一个等效面积阈值偏移。

---

## 8. 延迟修正后的 Q 值模型

已有 IQCOT/constant-Q 模型可写成近似形式：

    Q2 = 1 / [pi*(psi - D/2)]

其中：

    psi = CT*L*VTH / (gm*Ri*Vo*Tsw^2)
        = Lambda*L / (Ri*Vo*Tsw^2)

考虑数字延迟后：

    psi_eff
    = Lambda_eff*L / (Ri*Vo*Tsw^2)
    = psi + L*(He*Td + 0.5*Sf*Td^2)/(Ri*Vo*Tsw^2)

于是：

    Q2_eff = 1 / [pi*(psi_eff - D/2)]

令：

    zeta = psi_eff - D/2

小信号灵敏度为：

    delta ln Q2 = -(delta psi_eff - 0.5*delta D)/zeta

这个式子可以直接变成 AI 安全约束：

    zeta_min <= psi_eff - D/2 <= zeta_max
    Qmin <= Q2_eff <= Qmax

这比让 AI 直接试探 VTH 或 gm 更稳，因为它把稳定裕度显式编码进状态变量。

---

## 9. 量化噪声的面积噪声模型

若 DPWM 或事件时间量化步长为 Tq，时间量化噪声近似为：

    sigma_t^2 = Tq^2/12

对应面积噪声：

    sigma_A^2 ≈ He^2*sigma_t^2 + sigma_Lambda^2 + sigma_sense^2*Toff^2

固定 on-time 时：

    d_hat,k = -D/Tsw*(tau_{k+1}-tau_k)

所以独立边沿量化噪声会以差分形式进入 duty：

    S_d(z) ∝ |1 - z^{-1}|^2 S_tau(z)

这说明：边沿量化在低频被抑制，但在接近 Nyquist 频率处会被放大。这个结论可用于解释数字 COT 中的 limit-cycle 和相电流均衡振荡，也可作为 AI reward 的惩罚项。

---

## 10. 多相共模/差模扩展

对 N 相 Buck，定义：

    i_sum = sum_{j=1}^{N} i_j
    i_avg = i_sum/N
    delta_i_j = i_j - i_avg
    sum(delta_i_j) = 0

如果 IQCOT 积分使用合成电流或平均电流，则共模事件方程为：

    F_cm,k =
    integral [vc(t) - Ri*i_sum(t)]dt - Lambda_cm = 0

或者使用平均电流归一化：

    F_cm,k =
    integral [vc(t) - Ri_eq*i_avg(t)]dt - Lambda_cm = 0

共模主要决定输出电压动态和总 duty 调制；差模主要决定相电流均衡。对第 j 相引入微小 on-time trim 或阈值 trim：

    ton_hat,j = ton_hat,cm + ton_hat,dm,j
    lambda_hat,j = lambda_hat,cm + lambda_hat,dm,j
    sum(ton_hat,dm,j) = 0
    sum(lambda_hat,dm,j) = 0

差模电流近似满足：

    d(delta_i_j)/dt
    = -Req/L*delta_i_j
    + Vin/L*(d_hat_j - d_hat_avg)
    + disturbance_j

若均流控制器输出：

    ton_hat,dm,j = -Kcb(z)*delta_i_j

则差模闭环近似为：

    Gdm(s,z) =
    (Vin/L)*Kcb(z)*e^{-sTd}
    /
    [s + Req/L + (Vin/L)*Kcb(z)*e^{-sTd}]

AI 不应只追求更大的 Kcb，因为数字延迟和 DPWM 分辨率会使差模环路振荡。PETS-IQCOT 的建议是让 AI 输出：

    u_ai = {Delta_psi_cm, Kcb, omega_cb, Delta_ton_dm_limit}

并强制：

    phase_margin_cm >= PMmin
    phase_margin_dm >= PMcb_min
    Qmin <= Q2_eff <= Qmax
    abs(ton_hat,dm,j) <= Ton_trim_max

---

## 11. 可验证预测

这个模型必须能被仿真或实验推翻，才算严谨。建议至少验证以下五项。

### 11.1 时刻扰动离散极点

在 Simulink/SIMPLIS 中对 VTH 加一个很小阶跃，记录连续多个触发沿：

    tau_1, tau_2, ..., tau_k

若外环扰动较慢，应能观察到主要衰减比例接近：

    tau_{k+1}/tau_k ≈ alpha = Hs/He

### 11.2 参数面积灵敏度

分别扰动 VTH、gm、CT、Ri，比较预测的 off-time 变化：

    Delta_t_theta
    ≈ [Lambda*rho + Ri*integral IL(t)dt*kappa]/He

其中：

    rho = delta ln CT + delta ln VTH - delta ln gm
    kappa = delta ln Ri

### 11.3 延迟修正 Q

扫描 Td，从 Bode 或注入测试中提取半开关频率附近 Q 值，比较：

    Q2_eff = 1/[pi*(psi_eff - D/2)]
    psi_eff = psi + L*(He*Td + 0.5*Sf*Td^2)/(Ri*Vo*Tsw^2)

如果 Td 增加导致等效 psi 变化，模型应能预测 Q 的偏移趋势。

### 11.4 DPWM 量化噪声谱

设置不同 Tq，测量 duty 或相电流中的高频噪声。模型预测：

    S_d(z) ∝ |1-z^{-1}|^2*S_tau(z)

即 duty 抖动更偏高频。

### 11.5 多相差模均流稳定性

扫描 Kcb 和 delay-line 分辨率，验证均流误差和振荡边界。模型预测：更大 Kcb 并不总是更好，存在由 Td 和量化共同决定的稳定上限。

---

## 12. 可以写成论文贡献的表述

建议论文中这样写：

> 本文提出一种面向数字多相 IQCOT Buck 变换器的参数化事件触发采样小信号模型 PETS-IQCOT。不同于已有 IQCOT 描述函数模型主要给出连续域控制到输出传递函数，本文直接从 IQCOT 积分触发事件出发，利用移动积分边界线性化推导开关时刻扰动递推关系，揭示 IQCOT 触发事件中存在由 Hs/He 决定的离散时刻极点。在此基础上，本文将阈值参数、跨导、电流反馈权重、数字延迟和 DPWM 量化统一为等效面积扰动，进一步提出延迟修正的 psi_eff-Q2_eff 稳定性坐标，为 AI 参数整定提供可辨识、可约束、可验证的低维输入输出接口。

---

## 13. 后续需要重点学习的文献

必须继续精读：

1. Bari 的 IQCOT 博士论文和 ECCE 2018 IQCOT 高频小信号模型。重点看 IQCOT 控制律、Q 表达式、Q auto-tuning、硬件验证参数。
2. Liu et al. 2023 duty-cycle-independent Q 相关论文。重点看 constant-Q 推导，避免把已有公式当作原创。
3. Yan/Ruan 或 Gabriele 2025 sampled-data COT 模型。重点看采样数据建模方法和开关边沿扰动处理。
4. Yang 2018 control delay on COT small-signal model。重点看 delay 如何进入传统 COT 模型。
5. Li et al. 2024 DICOT 多相数字积分 COT。重点看数字积分实现、sample delay、current balance 和 high-resolution TON generator。
6. Peterchev/Sanders 及 DPWM quantization/limit-cycle 经典文献。重点看数字 PWM 分辨率与 limit-cycle 的理论。

若要把本文创新做得更像论文，需要额外下载或查找：

    sampled-data modeling for event-triggered switching converters
    Poincare map modeling of current-mode control
    DPWM quantization limit cycling digital dc-dc converters
    reinforcement learning based loop compensation multiphase buck converters

---

## 14. 风险边界

1. 如果最终推导只停留在 Q2 = 1/[pi*(psi-D/2)]，创新性不足，因为它与已有 constant-Q 文献高度重合。
2. 必须保留事件时刻递推 tau_{k+1}=alpha*tau_k+...，这是与传统 IQCOT 描述函数模型拉开距离的关键。
3. 必须做 delay sweep 和参数扰动验证，否则“面积扰动模型”容易被认为只是换一种说法。
4. AI 部分必须强调 constrained tuning，而不是直接替代 IQCOT 内环。直接让 AI 输出 PWM 会削弱 IQCOT 本身的物理优势，也更难保证稳定性。
