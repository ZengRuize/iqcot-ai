# RSE-PETS-IQCOT：鲁棒随机事件核小信号模型详细推导草稿

本文继续推进 IQCOT 小信号建模创新。目标不是替代 Bari 的 IQCOT 描述函数模型，也不是重复 Gabriele 类 COT sampled-data 模型，而是在 IQCOT 积分事件方程上加入数字控制和 AI 调参真正需要的三类因素：

1. stochastic：采样噪声、阈值噪声、DPWM 时间量化、数字 accumulator 面积量化；
2. robust：L、C、ESR、DCR、Ron、Td、gm、VTH、CT、Ri 等参数漂移；
3. modal：多相 Buck 的共模电压动态和差模均流动态。

建议命名：

    RSE-PETS-IQCOT
    Robust Stochastic Event-kernel Parameterized Event-Triggered Sampled model for IQCOT

## 1. 建模对象与创新边界

已有文献边界：

1. IQCOT 控制律和描述函数模型：Bari 已覆盖。
2. duty-cycle-independent Q：Liu 已覆盖，并扩展到 IQCOT。
3. COT/RBCOT event-driven sampled-data：Yan/Ruan/Li 和 Gabriele 已覆盖。
4. 多相 DICOT 和 current balance model：Li 2024 已覆盖。
5. 数字 PWM 量化和 limit-cycle：Peterchev/Sanders、Peng/Maksimovic/Prodic 等已有经典工作。

本文可声明的创新：

    把 IQCOT 的积分面积事件写成随机-鲁棒事件核模型，
    明确建立从面积噪声/参数漂移到事件时刻扰动、duty jitter、
    输出电压噪声和多相差模均流振荡的传递关系，
    并把该模型转化为 AI 安全调参约束。

注意：创新点不是“首次分析 IQCOT 小信号”，而是“首次将 IQCOT 积分事件小信号模型扩展为面向数字 AI 调参的随机-鲁棒事件核框架”。如果后续检索发现已有完全相同工作，则应降级为“综合建模与验证框架”。

## 2. 理想 IQCOT 积分事件

令第 k 个开关事件时刻为：

    t_k = k*Tsw + tau_k

on-time 结束并经过 blanking 后，积分开始：

    a_k = t_k + Ton,k + Tbl,k

积分核：

    h(t) = vc(t) - Ri*iL(t)

理想 IQCOT 事件：

    F_k = integral_{a_k}^{t_{k+1}} h(t) dt - Lambda = 0

其中：

    Lambda = CT*VTH/gm

在稳态工作点附近，对积分边界线性化：

    He*tau_{k+1}
    - Hs*(tau_k + ton_hat,k + tbl_hat,k)
    + A_ext,k
    - lambda_hat,k
    = 0

    Hs = h(a_k^+)
    He = h(t_{k+1}^-)

    A_ext,k =
    integral_{a_k}^{t_{k+1}}
    [vc_hat(t) - Ri0*i_hat(t) - IL(t)*ri_hat,k] dt

考虑跨周期状态记忆后：

    He*tau_{k+1}
    - Hs*tau_k
    + sum_{n=0}^{M} beta_iq(n)*tau_{k-n}
    + A_u,k
    - lambda_hat,k
    = 0

定义事件核分母：

    Pi_iq(z) = He*z - Hs + B_iq(z)

其中：

    B_iq(z) = sum_{n=0}^{M} beta_iq(n)*z^{-n}

于是：

    Tau(z) = [Lambda_hat(z) - A_u(z)] / Pi_iq(z)

## 3. 随机检测事件：从理想事件到带噪声事件

数字 IQCOT 中，控制器检测的不是理想面积，而是：

    A_meas,k =
    integral_{a_k}^{t_{k+1}}
    [h(t) + n_v(t) - Ri0*n_i(t)] dt
    + q_A,k

阈值也不是理想 Lambda：

    Lambda_meas,k = Lambda + eta_Lambda,k

事件判定误差：

    A_meas,k - Lambda_meas,k = 0

代入并线性化，得到：

    He*tau_{k+1}
    - Hs*tau_k
    + sum beta_iq(n)*tau_{k-n}
    + A_u,k
    - lambda_hat,k
    = w_A,k

其中面积噪声项定义为：

    w_A,k =
      eta_Lambda,k
      - integral_{a_k}^{t_{k+1}} n_v(t) dt
      + Ri0*integral_{a_k}^{t_{k+1}} n_i(t) dt
      + He*q_t,k
      + q_A,k

这里：

    eta_Lambda,k = 阈值噪声或参考噪声
    n_v(t) = 电压检测噪声
    n_i(t) = 电流检测噪声
    q_t,k = DPWM/事件时间量化误差
    q_A,k = 数字面积 accumulator 量化误差

z 域表达：

    Tau(z)
    =
    [Lambda_hat(z) - A_u(z) + W_A(z)]
    /
    Pi_iq(z)

这给出随机小信号的核心传递链：

    W_A -> Tau -> D_hat -> Vout

## 4. 面积噪声方差

若噪声近似白噪声或在一个 off-time 内可用均方值表示，则：

    sigma_A^2
    ~= sigma_Lambda^2
    + Toff^2*sigma_v^2
    + Ri0^2*Toff^2*sigma_i^2
    + He^2*Tq^2/12
    + Delta_Aq^2/12

其中：

    Tq = 时间量化步长
    Delta_Aq = 数字 accumulator 面积量化步长

如果只用低阶事件极点：

    tau_{k+1} = alpha*tau_k + e_k
    alpha = Hs/He
    e_k = w_A,k/He

则：

    sigma_tau^2 = sigma_e^2/(1-alpha^2)
    sigma_e^2 = sigma_A^2/He^2

固定 on-time 的 duty 扰动：

    d_hat,k = -D/Tsw*(tau_{k+1}-tau_k)

因此：

    sigma_d^2
    =
    D^2/Tsw^2 * Var(tau_{k+1}-tau_k)

对 AR(1) 低阶模型：

    Var(tau_{k+1}-tau_k)
    =
    2*sigma_e^2/(1+alpha)

所以：

    sigma_d
    =
    D/Tsw * sqrt(2/(1+alpha)) * sigma_A/He

这是一个非常适合仿真验证的闭式公式。它把 ADC/DPWM/阈值噪声直接连接到 duty jitter。

## 5. duty jitter 到输出电压噪声

小信号功率级可写为：

    vout_hat(s)
    =
    Gvd(s)*d_hat(s)
    + Gvg(s)*vin_hat(s)
    - Zo(s)*i_load_hat(s)

其中 Buck CCM 近似：

    Gvd(s) =
    Vin*(1 + s*ESR*C)
    /
    (L*C*s^2 + (L/Rload + ESR*C)*s + 1)

事件域到 duty 的关系：

    D_hat(z)
    =
    -D/Tsw*(z-1)*Tau(z)

因此面积噪声到输出电压噪声可写成混合域近似：

    Vout_noise
    ~
    Gvd(s) * ZOH{ -D/Tsw*(z-1)/Pi_iq(z) } * W_A(z)

工程实现时可采用：

1. 低频段用等效 s 域近似；
2. 接近开关频率时用 sampled-data 或仿真提取频谱；
3. 最终用 Simulink/SIMPLIS 时域仿真验证 rms 和 PSD。

## 6. 参数不确定性：鲁棒事件核

定义参数不确定性向量：

    p =
    [
      delta_L,
      delta_C,
      delta_ESR,
      delta_DCR,
      delta_Ron,
      delta_Td_det,
      delta_Td_act,
      delta_gm,
      delta_VTH,
      delta_CT,
      delta_Ri
    ]

其中 IQCOT 阈值通道压缩为：

    rho = delta ln(CT*VTH/gm)

电流反馈通道压缩为：

    kappa = delta ln Ri

参数化事件核：

    Pi_iq(z,p)
    =
    He(p)*z - Hs(p) + B_iq(z,p)

一阶展开：

    Pi_iq(z,p)
    ~= Pi_0(z) + sum_i p_i*Pi_i(z)

鲁棒稳定性约束：

    max_{p in P} max_j |z_j(Pi_iq(z,p))| <= r_max

噪声约束：

    max_{p in P} sigma_d(p) <= sigma_d,max

输出噪声约束：

    max_{p in P} sigma_vo(p) <= sigma_vo,max

这能把 AI 调参从“追求最快 transient”变成“在参数漂移集合内保持稳定和低 jitter”。

## 7. detection delay 与 actuation delay 的分离

检测/采样/计算导致的面积超调：

    Delta_A_det
    ~= He*Td_det + 0.5*Sf*Td_det^2

进入等效阈值：

    Lambda_eff = Lambda + Delta_A_det

但门极执行延迟更接近传输延迟：

    G_act(s) = exp(-s*Td_act)

不能把所有 delay 合并进 Lambda_eff。RSE-PETS-IQCOT 中建议使用双通道：

    detection delay -> rho_eff or Lambda_eff
    actuation delay -> phase lag / duty path

AI 安全约束也分开：

    rho_min <= rho_eff <= rho_max
    PM(Td_act) >= PM_min

## 8. 多相共模/差模事件模态

对 N 相相电流扰动：

    delta_i = [delta_i_0, delta_i_1, ..., delta_i_{N-1}]^T

用 DFT 分解：

    delta_i_q =
    sum_{j=0}^{N-1}
    delta_i_j * exp(-j*2*pi*q*j/N)

其中：

    q=0 为共模，主要影响输出电压；
    q=1...N-1 为差模，主要影响相电流均流。

事件时刻也可模态分解：

    tau_q = DFT(tau_j)

每个模态：

    Pi_q(z)*Tau_q(z) = U_q(z) + W_q(z)

共模事件核：

    Pi_0(z)
    =
    He_0*z - Hs_0 + B_iq,0(z)

差模事件核：

    Pi_q(z)
    =
    He_q*z - Hs_q + B_iq,q(z)
    + H_cb,q(z,Kcb,Td_cb,Tq)

AI 约束：

    max_j |root(Pi_0)| <= r_cm
    max_{q=1...N-1} max_j |root(Pi_q)| <= r_dm
    rms(delta_i_q) <= Ishare_max
    abs(Ton_trim_j) <= Ton_trim_limit

这一步可用于解释：为什么多相数字控制里 Kcb 不能无限增大；过大的均流增益在 delay 和量化下会激发差模振荡。

## 9. AI 安全调参优化问题

建议 AI 不直接输出 PWM，而输出：

    u_ai =
    [
      Delta_rho_cm,
      Delta_kappa_cm,
      Qstar,
      Kcb,
      Ton_trim_limit
    ]

优化目标：

    minimize J =
      w1*undershoot
      + w2*overshoot
      + w3*settling_time
      + w4*sigma_vo
      + w5*sigma_d
      + w6*Ishare_rms
      + w7*switching_loss_penalty

约束：

    Qmin <= Q_eff(u_ai,p) <= Qmax
    PM_cm(u_ai,p) >= PM_min
    PM_dm(u_ai,p) >= PMdm_min
    max_j |z_j(Pi_q)| <= r_max
    sigma_d(u_ai,p) <= sigma_d,max
    Ton_min <= Ton_j <= Ton_max
    abs(Ton_trim_j) <= Ton_trim_limit

对所有：

    p in P

实际算法可选：

1. 离线 Bayesian optimization；
2. safe reinforcement learning；
3. constrained policy optimization；
4. 神经网络 surrogate + 显式约束投影。

毕业设计中最稳妥的是：

    离线仿真采样 + 代理模型 + 约束优化

而不是让 RL 在线直接控制功率开关。

## 10. memory-kernel 的辨识方法

如果不想完全手推 beta_iq(n)，可以从仿真辨识。

实验输入：

    rho_k 使用小幅 PRBS 或 swept-sine

记录：

    tau_k, vc_k, iL_k, vout_k

拟合模型：

    He*tau_{k+1}
    - Hs*tau_k
    + sum_{n=0}^{M} beta_iq(n)*tau_{k-n}
    =
    Lambda*rho_k - A_u,k + w_A,k

最小二乘形式：

    y_k = Phi_k * theta + epsilon_k

其中：

    y_k = He*tau_{k+1} - Hs*tau_k - Lambda*rho_k + A_u,k
    theta = [beta_iq(0), beta_iq(1), ..., beta_iq(M)]^T
    Phi_k = [-tau_k, -tau_{k-1}, ..., -tau_{k-M}]

得到 beta_iq 后，检查：

    预测 tau_k 的误差
    频域传函的幅相误差
    不同 Vin/Vo/Iout 下 beta_iq 的变化

## 11. 可写成论文贡献的版本

推荐最终贡献表述：

1. 本文建立了 IQCOT 积分事件随机小信号模型，将阈值噪声、电压/电流采样噪声、DPWM 时间量化和数字积分器面积量化统一为事件面积噪声，推导了面积噪声到触发时刻 jitter、duty jitter 和输出电压噪声的传递关系。
2. 本文提出参数化鲁棒事件核模型，将 IQCOT 的 VTH/gm/CT/Ri 压缩为 rho/kappa 安全坐标，并将 L/C/ESR/DCR/Ron/delay 等参数漂移纳入事件核 Pi_iq(z,p)，为 AI 调参提供 worst-case 稳定性与 jitter 约束。
3. 本文将多相 IQCOT 事件扰动分解为共模与差模事件模态，建立差模均流增益、delay、DPWM 分辨率和相电流振荡之间的约束关系，使 AI 能在电压动态和均流稳定之间进行安全折中。

## 12. 建议验证顺序

第一阶段：低阶随机模型

    验证 sigma_tau 和 sigma_d 闭式公式。

第二阶段：Simulink 单相 IQCOT

    注入 VTH/gm/CT/Ri 扰动、ADC 噪声、DPWM 量化，提取 tau/duty/vout jitter。

第三阶段：memory-kernel 辨识

    使用 PRBS rho 扰动拟合 beta_iq(n)，比较低阶模型与 kernel 模型。

第四阶段：多相差模

    扫描 Kcb、delay、Ton_trim_resolution，验证差模振荡边界。

第五阶段：AI constrained tuning

    比较固定参数、constant-Q、无约束 AI、RSE-PETS 约束 AI。

## 13. 结论

RSE-PETS-IQCOT 的价值在于：它把 IQCOT 小信号建模从“平均传递函数”推进到“数字控制可用的事件核模型”。这个模型能直接回答：

    噪声如何变成触发 jitter？
    量化如何变成 duty jitter？
    参数漂移下 AI 调参是否仍稳定？
    多相均流为什么可能出现差模振荡？
    AI 应该在哪些安全坐标和约束内调参？

这比单纯复现 Bari 的 describing function 更适合作为“AI 调节 IQCOT 参数优化性能”的研究创新点。
