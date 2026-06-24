# IQCOT 小信号建模的额外创新方案

本文在 PETS-IQCOT 的基础上，继续提出一个更强但仍然可验证的建模创新：**RSE-PETS-IQCOT：鲁棒随机事件核小信号模型**。它不是重新发明 IQCOT，也不是重新发明 COT sampled-data，而是把 IQCOT 积分事件模型进一步扩展到数字控制中真正会遇到的参数不确定性、采样量化噪声、检测延迟、DPWM 分辨率、多相差模均流等问题。

## 1. 为什么还可以创新

已有文献覆盖了以下内容：

1. Bari 已提出 IQCOT 控制律、高频小信号描述函数模型、Q 值设计和 auto-tuning。
2. Liu 已提出 duty-cycle-independent Q，并扩展到 IQCOT。
3. Yan/Ruan/Li 和 Gabriele 已提出 COT/RBCOT 的 sampled-data 建模。
4. Li 2024 DICOT 已提出多相数字积分 COT、phase manager 和 current-balance model。

因此，新的创新不能写成“首次提出 IQCOT 小信号模型”。更合理的新增创新是：

> 建立面向数字多相 IQCOT 和 AI 安全调参的随机-鲁棒事件核小信号模型，将参数漂移、噪声、量化、检测延迟和相电流均流差模动态统一映射到 IQCOT 积分事件时刻扰动。

这比前面的 PETS-IQCOT 多了三层：

1. 从确定性模型扩展为随机模型：预测事件抖动、duty 抖动、输出噪声。
2. 从单工作点模型扩展为鲁棒/LPV 模型：处理 Vin、Vo、Iout、L、C、ESR、delay 漂移。
3. 从单相事件模型扩展为多相共模/差模模态模型：直接服务于多相数字均流。

## 2. 基础事件方程

IQCOT 积分事件仍从以下方程出发：

    F_k = integral_{a_k}^{t_{k+1}} h(t) dt - Lambda = 0

其中：

    h(t) = vc(t) - Ri*iL(t)
    Lambda = CT*VTH/gm
    a_k = t_k + Ton,k + Tbl,k

PETS-IQCOT 已给出确定性一阶线性化：

    He*tau_{k+1}
    - Hs*tau_k
    + sum beta_iq(k-m)*tau_m
    + A_u,k
    - lambda_hat,k
    = 0

新增创新是在这个式子里显式加入：

    参数不确定性 p
    量化噪声 q
    采样/检测噪声 n
    数字时钟相位 phi
    多相差模扰动 xi_q

## 3. 创新一：随机事件面积噪声模型

实际数字 IQCOT 中，事件不是在理想面积达到 Lambda 时被检测，而是在带噪声、带量化、带采样延迟的条件下被检测。

定义实际检测到的面积误差：

    w_A,k =
      eta_Lambda,k
      - integral_{a_k}^{t_{k+1}} n_v(t) dt
      + Ri0*integral_{a_k}^{t_{k+1}} n_i(t) dt
      + He*q_t,k
      + q_A,k

其中：

    eta_Lambda,k = 阈值/参考噪声
    n_v(t) = 电压检测噪声
    n_i(t) = 电流检测噪声
    q_t,k = DPWM 或事件时间量化误差
    q_A,k = 数字 accumulator 面积量化误差

则随机事件核模型为：

    He*tau_{k+1}
    - Hs*tau_k
    + sum beta_iq(k-m)*tau_m
    + A_u,k
    - lambda_hat,k
    = w_A,k

在 z 域中：

    Tau(z)
    =
    [Lambda_hat(z) - A_u(z) + W_A(z)]
    /
    [He*z - Hs + B_iq(z)]

这使 IQCOT 小信号模型不仅能预测平均动态，还能预测事件时刻抖动。

## 4. 事件噪声到 duty 抖动的传递

固定 on-time 下：

    d_hat,k = -D/Tsw * (tau_{k+1} - tau_k)

因此：

    D_hat(z)
    = -D/Tsw * (z - 1) * Tau(z)

若面积噪声近似白噪声，其方差可估计为：

    sigma_A^2
    ~= sigma_Lambda^2
    + Toff^2*sigma_v^2
    + Ri0^2*Toff^2*sigma_i^2
    + He^2*Tq^2/12
    + Delta_Aq^2/12

于是：

    S_tau(e^jw)
    =
    |1/[He*e^jw - Hs + B_iq(e^jw)]|^2 * S_A(e^jw)

    S_d(e^jw)
    =
    D^2/Tsw^2 * |e^jw - 1|^2 * S_tau(e^jw)

这个模型直接给出三个有用结论：

1. 事件面积噪声会被 IQCOT 事件核放大或抑制。
2. duty 抖动包含差分项，因此低频事件漂移不一定严重，但高频事件抖动会被放大。
3. DPWM/accumulator 分辨率可以通过 sigma_A 进入小信号模型，而不是只做经验讨论。

这部分可以成为一个清晰的新贡献：**IQCOT 积分事件噪声到 duty 抖动的随机小信号模型**。

## 5. 创新二：参数不确定性的鲁棒事件核模型

AI 调参真正危险的地方不只是 nominal 工作点，而是参数漂移。定义不确定参数：

    p =
    [
      delta_L,
      delta_C,
      delta_ESR,
      delta_DCR,
      delta_Ron,
      delta_Td,
      delta_gm,
      delta_VTH,
      delta_CT,
      delta_Ri
    ]

其中 IQCOT 参数可压缩为：

    rho = delta ln(CT*VTH/gm)
    kappa = delta ln Ri

事件核分母写为：

    Pi(z,p)
    =
    He(p)*z
    - Hs(p)
    + B_iq(z,p)

一阶展开：

    Pi(z,p)
    ~= Pi0(z) + sum_i p_i * Pi_i(z)

因此稳定性不再只是检查 nominal poles，而是检查：

    roots Pi(z,p) inside unit circle for all p in P

工程上可以定义 AI 的鲁棒安全约束：

    max_{p in P} max_j |z_j(p)| <= r_max
    min_{p in P} PM_cm(p) >= PM_min
    min_{p in P} PM_dm(p) >= PMdm_min
    max_{p in P} sigma_d(p) <= sigma_d,max

这给 AI 调参一个非常明确的边界：不是只优化 transient，而是在不确定参数集合 P 内保证小信号稳定、相位裕度和抖动限制。

## 6. 创新三：多速率数字 IQCOT lifting 模型

数字 IQCOT 至少有三种时间尺度：

    Tsw = 等效开关周期
    Tclk = 数字控制/DPWM 时钟
    Ts_adc = ADC 采样周期

COT/IQCOT 的事件时刻 t_k 又不是固定时钟点。因此单一离散周期模型会漏掉一个关键变量：事件相对数字时钟的相位。

定义：

    phi_k = mod(t_k, Tclk)/Tclk

把状态扩展为：

    X_k =
    [
      x_power,k
      x_comp,k
      x_acc,k
      tau_k
      phi_k
    ]

其中：

    x_power = 电感电流/输出电压等功率级状态
    x_comp = 补偿器或滤波器状态
    x_acc = 数字积分器/accumulator 状态
    tau_k = 事件时刻扰动
    phi_k = 事件相对时钟相位

线性化 lifted map：

    X_{k+1}
    =
    A_lift(D,phi0,p)*X_k
    + B_lift*u_k
    + G_lift*w_k

输出：

    y_k =
    C_lift*X_k

这个模型能描述：

1. ADC 采样和 IQCOT 事件不同步导致的周期性误差。
2. DPWM 边沿量化造成的相位相关抖动。
3. 低分辨率数字积分器导致的 limit cycle。
4. 为什么某些工作点虽然 nominal 稳定，但换一个 Vin/Vo 后出现高频抖动。

这是比简单 delay model 更精细的数字小信号模型。

## 7. 创新四：多相共模/差模事件模态模型

对 N 相 IQCOT，定义相电流扰动向量：

    delta_i =
    [delta_i_1, delta_i_2, ..., delta_i_N]^T

用离散傅里叶变换分解为模态：

    delta_i_q = sum_{j=0}^{N-1} delta_i_j * exp(-j*2*pi*q*j/N)

其中：

    q = 0 是共模，决定输出电压动态
    q = 1,...,N-1 是差模，决定相电流均流和环流

对应事件时刻扰动也分解为：

    tau_q = DFT(tau_j)

每个模态可写成：

    Pi_q(z)*Tau_q(z)
    =
    U_q(z) + W_q(z)

其中：

    Pi_q(z)
    =
    He_q*z
    - Hs_q
    + B_iq,q(z)
    + H_cb,q(z,Kcb,Td,Tq)

共模 q=0 主要包含：

    rho_cm, psi_cm, load transient, output voltage loop

差模 q>0 主要包含：

    Kcb, Ton_trim_limit, current-balance delay, DPWM resolution

AI 安全约束可以写成：

    max_j |root(Pi_0)| <= r_cm
    max_{q=1...N-1} max_j |root(Pi_q)| <= r_dm
    sigma_iq <= sigma_i,max
    abs(Ton_trim_j) <= Ton_trim_limit

这个模型比“只看总电流”更适合多相 VRM，因为实际风险常常出现在差模均流环路，而不是输出电压环路。

## 8. 建议最终采用的额外创新组合

为了毕业设计工作量可控，建议不要一次做四个大创新。推荐组合为：

### 主创新 A：随机事件面积噪声模型

最容易验证，也最适合解释数字控制问题。验证只需要给 IQCOT 模型加入 ADC/DPWM/accumulator 噪声，测事件时刻 jitter 和 duty jitter。

### 主创新 B：参数不确定性鲁棒安全约束

最适合连接 AI。AI 输出 rho、psi、Kcb 等参数，但必须满足 worst-case pole radius、相位裕度、duty jitter 上限。

### 可选创新 C：多相 DFT 差模模型

如果后续模型已经是多相 Buck，就加入这一部分。它能把“AI 怎么解决多相数字控制难点”说得非常具体。

不建议把多速率 lifting 作为主创新，除非你有足够时间做模型和仿真；它理论上最漂亮，但工作量也最大。

## 9. 可以写进论文的创新表述

推荐表述：

> 在已有 IQCOT 描述函数模型和 COT sampled-data 模型基础上，本文进一步提出一种面向数字控制和 AI 参数整定的鲁棒随机事件核小信号模型。该模型将 IQCOT 的积分触发条件线性化为事件时刻扰动方程，并显式引入阈值噪声、电压/电流采样噪声、DPWM 时间量化、数字 accumulator 量化和参数漂移，建立从面积噪声到事件时刻抖动、duty 抖动及输出电压噪声的传递关系。进一步，本文将模型分解为多相共模与差模事件模态，构造以极点半径、相位裕度、抖动方差和均流误差为约束的 AI 安全调参空间。

这个表述的关键是：你没有声称发明 IQCOT 或 constant-Q，而是提出了更适合数字 AI 调参的小信号建模层。

## 10. 仿真验证路径

### 验证 1：面积噪声到事件 jitter

注入不同噪声：

    sigma_v, sigma_i, sigma_Lambda, Tq, Delta_Aq

测量：

    rms(tau_k), rms(d_k), output noise

验证：

    sigma_tau^2 ~= sigma_A^2 / |He*z - Hs + B_iq(z)|^2

### 验证 2：DPWM 分辨率对高频 duty jitter 的影响

扫描：

    Tq = 50 ps, 100 ps, 200 ps, 500 ps, 1 ns

验证：

    S_d(e^jw)
    =
    D^2/Tsw^2 * |e^jw - 1|^2 * S_tau(e^jw)

### 验证 3：AI 安全调参约束

比较：

1. 固定参数 IQCOT。
2. constant-Q IQCOT。
3. 无约束 AI 调参。
4. 鲁棒随机事件核约束 AI 调参。

指标：

    overshoot
    undershoot
    settling time
    phase margin
    pole radius
    duty jitter
    current sharing error

预期结果：

    无约束 AI 可能 transient 更快，但在某些参数漂移或低分辨率下产生 jitter/均流振荡。
    约束 AI transient 略保守，但鲁棒性和抖动指标更好。

### 验证 4：多相差模稳定边界

扫描：

    Kcb, Td_cb, Ton_trim_resolution

验证：

    差模 pole radius 或差模振荡频率随 Kcb 增大而接近不稳定边界。

这可以支撑结论：AI 调 Kcb 需要小信号差模模型约束，不能只追求更小的均流误差。

## 11. 需要补充的文献

为了支撑这个额外创新，建议补充以下方向：

1. Digital PWM quantization and limit cycle in digitally controlled DC-DC converters。
2. Quantization noise modeling in digital DC-DC converters。
3. Sampled-data/Poincare map modeling for current-mode or ripple-based converters。
4. Robust or stochastic control-oriented modeling for digitally controlled switching converters。
5. Safe reinforcement learning or constrained Bayesian optimization for controller tuning。

这些文献不是为了替代 IQCOT 主线，而是为了支撑“随机-鲁棒-AI 安全调参”这一新增建模层。

## 12. 结论

我认为还可以创新，而且最好不要继续在“确定性 IQCOT 小信号传递函数”上硬挤，因为 Bari 已经很完整。更好的额外创新是：

    从确定性 IQCOT 小信号模型
    推进到
    鲁棒随机事件核 IQCOT 小信号模型

它能回答传统小信号模型难以回答的问题：

1. 数字采样噪声如何变成事件 jitter？
2. DPWM 分辨率如何影响 duty 抖动和输出噪声？
3. 参数漂移下 AI 调出来的 rho/psi/Kcb 是否仍稳定？
4. 多相均流差模为什么会在某些 Kcb 和 delay 下振荡？
5. AI 应该在什么安全边界内调参？

这条路线和“AI 调节 IQCOT 参数优化性能”的毕业设计主题最贴合，也比单纯复现 IQCOT describing function 更有研究辨识度。
