# 论文方法章节草稿：RSE-PETS-IQCOT 鲁棒随机事件核小信号模型

## 1. 研究动机

已有 IQCOT 研究已经证明，积分电荷型 COT 控制能够缓解传统 ripple-based COT 在多相交错时的纹波抵消问题，并能获得很快的负载瞬态响应。然而，当 IQCOT 向数字控制和 AI 参数整定扩展时，传统小信号模型仍存在三个不足：

1. 传统描述函数模型主要描述平均控制到输出的传递关系，难以直接刻画采样噪声、DPWM 量化和数字 accumulator 量化造成的事件时刻抖动。
2. constant-Q 设计可以改善 duty-cycle 变化下的 Q 值漂移，但没有直接给出参数不确定性和延迟漂移下的 worst-case 安全边界。
3. 多相数字控制不仅有输出电压共模问题，还有相电流差模均流问题；AI 若只优化负载阶跃指标，可能提高均流增益过度而激发差模振荡。

因此，本文提出 RSE-PETS-IQCOT 模型，将 IQCOT 的积分触发条件扩展为鲁棒随机事件核小信号模型，为 AI 参数调节提供可解释、可约束、可验证的模型基础。

## 2. 积分事件方程

IQCOT 的积分核定义为：

    h(t)=v_c(t)-R_i i_L(t)

第 k 个事件满足：

    F_k =
    integral_{a_k}^{t_{k+1}} h(t)dt - Lambda = 0

其中：

    Lambda = C_T V_TH / g_m
    a_k = t_k + T_on,k + T_bl,k

令：

    t_k = kT_sw + tau_k

对事件边界进行小信号线性化，得到：

    H_e tau_{k+1}
    - H_s tau_k
    + sum beta_iq(n) tau_{k-n}
    + A_u,k
    - lambda_hat,k
    = 0

其中：

    H_s = h(a_k^+)
    H_e = h(t_{k+1}^-)
    beta_iq(n) = 功率级、补偿网络、电流检测网络、数字滤波器引入的事件记忆核
    A_u,k = 输入扰动、负载扰动和外部控制扰动带来的面积项

该式区别于传统瞬时阈值型 RBCOT 事件，因为 IQCOT 的开关事件由积分面积决定。

## 3. 随机事件面积噪声

数字实现中，控制器检测的是带噪声和量化误差的面积：

    A_meas,k =
    integral_{a_k}^{t_{k+1}}
    [h(t)+n_v(t)-R_i n_i(t)]dt
    + q_A,k

阈值也含有噪声：

    Lambda_meas,k = Lambda + eta_Lambda,k

因此事件方程变为：

    H_e tau_{k+1}
    - H_s tau_k
    + sum beta_iq(n) tau_{k-n}
    + A_u,k
    - lambda_hat,k
    = w_A,k

其中：

    w_A,k =
      eta_Lambda,k
      - integral n_v(t)dt
      + R_i integral n_i(t)dt
      + H_e q_t,k
      + q_A,k

该项把阈值噪声、采样噪声、时间量化和面积量化统一为等效面积噪声。

## 4. 面积噪声到 duty jitter

在低阶近似下：

    tau_{k+1}=alpha tau_k + e_k
    alpha=H_s/H_e
    e_k=w_A,k/H_e

面积噪声方差为：

    sigma_A^2
    ~= sigma_Lambda^2
    + T_off^2 sigma_v^2
    + R_i^2 T_off^2 sigma_i^2
    + H_e^2 T_q^2/12
    + Delta_Aq^2/12

则：

    sigma_tau^2 = sigma_A^2 / [H_e^2(1-alpha^2)]

固定 on-time 下：

    d_hat,k = -D/T_sw (tau_{k+1}-tau_k)

因此：

    sigma_d =
    D/T_sw * sqrt(2/(1+alpha)) * sigma_A/H_e

该公式可直接用于预测 DPWM 分辨率、ADC 噪声和阈值噪声对 duty jitter 的影响。

## 5. 鲁棒参数化事件核

定义不确定参数集合：

    p in P =
    {L,C,ESR,DCR,Ron,Td_det,Td_act,g_m,V_TH,C_T,R_i}

其中：

    rho = delta ln(C_T V_TH/g_m)
    kappa = delta ln R_i

事件核写为：

    Pi_iq(z,p)=H_e(p)z-H_s(p)+B_iq(z,p)

鲁棒稳定性条件为：

    max_{p in P} max_j |z_j(Pi_iq(z,p))| <= r_max

同时约束：

    max_{p in P} sigma_d(p) <= sigma_d,max
    min_{p in P} PM(p) >= PM_min

这使 AI 调参不再仅依赖 nominal 工作点，而是在参数漂移集合内保持稳定和低抖动。

## 6. 多相共模/差模模态

对 N 相 Buck，定义相电流扰动向量：

    delta_i=[delta_i_0,delta_i_1,...,delta_i_{N-1}]^T

通过 DFT 分解：

    delta_i_q=sum_j delta_i_j exp(-j2pi qj/N)

其中：

    q=0 为共模，主要影响输出电压；
    q=1...N-1 为差模，主要影响均流稳定。

对应事件扰动：

    Pi_q(z)Tau_q(z)=U_q(z)+W_q(z)

共模 AI 变量：

    rho_cm, psi_cm, Qstar

差模 AI 变量：

    K_cb, omega_cb, Ton_trim_limit

约束：

    max_j |root(Pi_0)| <= r_cm
    max_{q>0} max_j |root(Pi_q)| <= r_dm
    rms(delta_i_q) <= Ishare_max
    abs(Ton_trim_j) <= Ton_trim_limit

## 7. AI 安全调参形式

AI 输出：

    u_ai = {Delta_rho_cm, Delta_kappa_cm, Qstar, K_cb, Ton_trim_limit}

目标函数：

    J =
      w1 undershoot
    + w2 overshoot
    + w3 settling_time
    + w4 sigma_vo
    + w5 sigma_d
    + w6 Ishare_rms
    + w7 switching_loss

约束：

    Q_min <= Q_eff <= Q_max
    PM_cm >= PM_min
    PM_dm >= PMdm_min
    max |root(Pi_q)| <= r_max
    sigma_d <= sigma_d,max
    Ton_min <= Ton_j <= Ton_max

建议采用离线仿真数据训练代理模型，再进行 constrained Bayesian optimization 或 safe policy optimization。毕业设计阶段不建议让 AI 直接输出 PWM。

## 8. 仿真验证设计

### 验证一：低阶随机事件模型

用 AR(1) 事件模型验证：

    tau_{k+1}=alpha tau_k + w_A,k/H_e

比较理论和 Monte Carlo：

    sigma_tau
    sigma_d

### 验证二：IQCOT 参数扰动

分别扰动：

    V_TH, g_m, C_T, R_i

验证：

    rho = delta ln(C_T V_TH/g_m)
    kappa = delta ln R_i

是否能预测事件时刻偏移。

### 验证三：数字量化和噪声

扫描：

    ADC noise
    current sense noise
    DPWM time step
    accumulator area step

测量：

    tau jitter
    duty jitter
    output voltage noise

### 验证四：memory kernel 辨识

对 rho 注入 PRBS，拟合：

    beta_iq(n)

比较低阶模型和 kernel 模型的预测误差。

### 验证五：多相差模均流

扫描：

    K_cb
    T_d,cb
    Ton_trim_resolution

观察：

    current sharing error
    differential-mode oscillation
    limit-cycle amplitude

### 验证六：AI 调参对照

比较：

1. 固定参数 IQCOT；
2. constant-Q IQCOT；
3. 无约束 AI；
4. RSE-PETS 约束 AI。

预期结论：

    无约束 AI 可能在 nominal transient 上最好，
    但在参数漂移、低分辨率和延迟下更容易出现 jitter 或均流振荡；
    RSE-PETS 约束 AI 稍保守，但综合鲁棒性更好。

## 9. 章节贡献总结

本文提出的 RSE-PETS-IQCOT 模型具有以下贡献：

1. 建立了 IQCOT 积分事件的随机小信号模型，将噪声和量化误差统一为面积噪声。
2. 推导了面积噪声到事件时刻 jitter、duty jitter 和输出噪声的传递关系。
3. 构建了参数化鲁棒事件核，使 AI 调参能够考虑 worst-case 稳定性、相位裕度和 jitter。
4. 将多相 IQCOT 拆分为共模和差模事件模态，解释均流增益、延迟和量化分辨率之间的稳定性折中。
5. 给出面向 AI 的安全调参变量和约束，避免 AI 直接控制 PWM 所带来的不可解释和稳定性风险。

