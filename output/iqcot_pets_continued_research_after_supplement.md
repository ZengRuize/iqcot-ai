# 补充文献学习后的 IQCOT-AI 调参继续研究

本文基于补充目录 8 篇论文的精读结果，继续收敛毕业设计的可行创新点。核心结论是：IQCOT 本身、小信号描述函数、constant-Q、COT sampled-data、多相 DICOT 都已有较强工作基础；更稳妥的创新应放在“面向 AI 安全调参的 IQCOT 积分事件参数化 sampled-data 模型”上。

## 1. 读完补充文献后的边界判断

不能再作为原创点的内容：

1. IQCOT 控制律不是本文原创。Bari 已提出并验证 IQCOT 的电荷/面积控制思想。
2. IQCOT 高频小信号模型不是本文原创。Bari 已用 describing function 推导 IQCOT 的小信号模型，并讨论 Q 值。
3. constant-Q 不是本文原创。Liu 2023 已给出 duty-cycle-independent Q 设计，并明确扩展到 IQCOT。
4. COT 的事件驱动 sampled-data 建模不是本文原创。Yan/Ruan/Li 和 Gabriele 已给出 COT/RBCOT 的采样数据建模方法。
5. 多相数字积分 COT 和均流实现不是本文原创。Li 2024 DICOT 已给出多相 digital integration COT、phase manager、current balance model 和 high-resolution TON generator。

仍然可以形成毕业设计创新的空间：

1. 把 Gabriele 类 event-driven sampled-data 方法专门改写到 IQCOT 的“积分面积事件”，而不是瞬时阈值交叉事件。
2. 把 IQCOT 的 VTH、gm、CT、Ri、Ton、blanking、delay 等工程参数统一放进事件方程，推导它们对触发时刻和等效 Q 的影响。
3. 把已有 constant-Q 公式转化为 AI 安全调参坐标，而不是让 AI 直接输出 PWM 或直接乱调 VTH/gm/CT。
4. 把多相数字控制拆成共模电压动态与差模均流动态，让 AI 分别调节 Q/psi 和 Kcb/Ton_trim_limit。
5. 用仿真或实验验证参数灵敏度、delay 分类、memory-kernel 和多相均流约束，使创新不止停留在公式替换。

## 2. 推荐最终题目方向

建议题目可写成：

**面向 AI 安全参数整定的多相 IQCOT Buck 变换器积分事件小信号建模与优化控制研究**

英文可写成：

**Parameterized Integral-Event Sampled-Data Modeling and AI-Constrained Tuning for Multiphase IQCOT Buck Converters**

这个题目避开“发明 IQCOT”或“首次小信号建模”的风险，而强调你真正可以做的部分：参数化、积分事件、sampled-data、AI constrained tuning、多相。

## 3. IQCOT 积分事件模型

以 TOFF 积分 IQCOT 为基础。令第 k 次高边导通开始时刻为：

    t_k = k*Tsw + tau_k

导通结束并经过 blanking 后，积分真正开始：

    a_k = t_k + Ton,k + Tbl,k

定义 IQCOT 积分核：

    h(t) = vc(t) - Ri*iL(t)

积分事件为：

    F_k = integral_{a_k}^{t_{k+1}} h(t) dt - Lambda = 0
    Lambda = CT*VTH/gm

这里的关键不是重新提出 IQCOT 控制律，而是把它作为隐式事件方程处理。RBCOT 的事件通常是瞬时阈值交叉，而 IQCOT 的事件是“面积达到阈值”，所以线性化结构不同。

## 4. 一阶边界线性化

设：

    Ton,k = Ton + ton_hat,k
    Tbl,k = Tbl + tbl_hat,k
    Lambda = Lambda0 + lambda_hat,k
    Ri = Ri0 + ri_hat,k
    vc = VC + vc_hat
    iL = IL + i_hat

对

    F_k = integral_{a_k}^{t_{k+1}} [vc(t)-Ri*iL(t)] dt - Lambda

使用 Leibniz 积分边界求导，得到：

    He*tau_{k+1}
    - Hs*(tau_k + ton_hat,k + tbl_hat,k)
    + A_ext,k
    - lambda_hat,k
    = 0

其中：

    Hs = h(a_k^+)
    He = h(t_{k+1}^-)

    A_ext,k =
    integral_{a_k}^{t_{k+1}}
    [vc_hat(t) - Ri0*i_hat(t) - IL(t)*ri_hat,k] dt

如果忽略功率级跨周期记忆，有低阶近似：

    tau_{k+1}
    = (Hs/He)*tau_k
    + (Hs/He)*(ton_hat,k + tbl_hat,k)
    - A_ext,k/He
    + lambda_hat,k/He

这个式子给出一个可实验验证的局部事件极点：

    alpha0 = Hs/He

但这只能叫“低阶局部事件极点”，不能叫完整 sampled-data 极点。

## 5. 更严谨的 memory-kernel 形式

补充文献中 Gabriele 2025 的启发很关键：COT 的开关时刻扰动会通过功率级状态、纹波注入网络和补偿网络影响未来多个周期。因此 IQCOT 也应写成带记忆核的形式：

    He*tau_{k+1}
    - Hs*tau_k
    + sum_{m<=k} beta_iq(k-m)*tau_m
    + A_u,k
    - lambda_hat,k
    = 0

其中：

    beta_iq(n) = IQCOT 积分事件的 sampled-data memory kernel
    A_u,k = 外部扰动、输入扰动、负载扰动、参数扰动造成的直接面积项

Z 域可写成：

    Tau(z) =
    [Lambda_hat(z) - A_u(z)]
    /
    [He*z - Hs + B_iq(z)]

这就是建议论文中最严谨的小信号建模主线。低阶模型用于解释和初始设计，memory-kernel 模型用于高带宽和接近开关频率时的校正。

## 6. 参数扰动压缩为 AI 可辨识坐标

IQCOT 阈值面积为：

    Lambda = CT*VTH/gm

小信号下：

    delta Lambda/Lambda
    = delta CT/CT + delta VTH/VTH - delta gm/gm

定义：

    rho = delta ln Lambda
        = delta ln CT + delta ln VTH - delta ln gm

则：

    lambda_hat = Lambda*rho

这个结论对 AI 很重要：VTH、gm、CT 在 IQCOT 事件层面高度耦合，AI 不应同时独立调这三个量。更合理的是让 AI 输出 rho 或 psi，然后再映射回可实现的 VTH 或 gm。

Ri 的扰动不在 Lambda 中，而在积分核中：

    delta h_Ri(t) = -IL(t)*ri_hat

定义：

    kappa = delta ln Ri

则：

    A_Ri,k = -Ri0*kappa*integral_{a_k}^{t_{k+1}} IL(t) dt

所以 AI 的核心低维调参坐标建议为：

    u_ai = {Delta_rho, Delta_kappa, Qstar, Kcb, Ton_trim_limit}

## 7. constant-Q 不是原创，但可以变成 AI 安全坐标

已有 constant-Q 思路可写为：

    psi = Lambda*L/(Ri*Vo*Tsw^2)
    Q2 = 1/[pi*(psi - D/2)]

因此目标 Q 可以转成：

    psi_cmd = D/2 + 1/(pi*Qstar) + Delta_psi_ai

这里的创新不是 Q 公式，而是把它作为 AI 的安全坐标。AI 只允许在约束内修正：

    Qmin <= Q2_eff <= Qmax
    PM_cm >= PM_min
    PM_dm >= PM_dm_min
    Ton_min <= Ton_j <= Ton_max
    abs(Ton_trim_j) <= Ton_trim_limit

这样 AI 的角色是“在线/离线安全整定器”，不是直接替代 IQCOT 内环。

## 8. delay 必须分类建模

不能把所有 delay 都等效为 Lambda 增加。建议分成四类：

1. detection/sampling delay：事件检测晚了，可能导致面积 overshoot。
2. calculation delay：数字计算晚了，若 accumulator 继续累加，也会形成面积 overshoot。
3. reset delay：积分电容或数字累加器复位滞后，也会影响下一周期面积。
4. actuation/gate delay：PWM 或功率开关执行晚了，更像 transport delay，主要贡献 phase lag。

前三类可写成：

    Lambda_eff = Lambda + Delta_A_det
    Delta_A_det ~= He*Td_det + 0.5*Sf*Td_det^2

但 gate delay 应写成：

    G_delay(s) = exp(-s*Td_act)

这部分可以成为论文里非常有价值的“数字 IQCOT 误差来源分类”。

## 9. 多相数字控制：共模/差模分解

对 N 相 Buck，定义：

    i_sum = sum_j i_j
    i_avg = i_sum/N
    delta_i_j = i_j - i_avg
    sum_j delta_i_j = 0

共模负责输出电压动态和 IQCOT 高频 Q：

    rho_cm, psi_cm, Qstar

差模负责相电流均衡：

    Kcb, omega_cb, Ton_trim_limit

差模电流近似模型：

    d(delta_i_j)/dt
    = -Req/L*delta_i_j
    + Vin/L*(d_hat_j - d_hat_avg)
    + disturbance_j

若均流通过 on-time trim 实现：

    ton_hat,dm,j = -Kcb(z)*delta_i_j

则更大的 Kcb 不一定更好，因为数字延迟、TON 分辨率、delay-line 量化会导致均流振荡或 limit cycle。AI 应学习的是在不同负载和相数下如何选择“足够快但不振荡”的 Kcb 和 trim 限幅。

## 10. 建议的仿真验证矩阵

### 验证 A：参数面积灵敏度

分别扰动：

    VTH, gm, CT, Ri

扰动幅度建议 1%、2%、5%。测量事件时刻变化：

    Delta tau_k

验证：

    Delta tau_theta
    ~= [Lambda*rho + Ri0*kappa*integral IL(t)dt]/He

### 验证 B：低阶事件极点

对 VTH 施加小阶跃，提取连续触发时刻：

    tau_1, tau_2, ..., tau_k

若低阶模型成立，应近似满足：

    tau_{k+1}/tau_k ~= Hs/He

若偏差明显，就说明 beta_iq memory kernel 不能忽略。

### 验证 C：memory-kernel 拟合

用 PRBS 或小幅扫频扰动 rho，记录 tau 序列，拟合：

    He*tau_{k+1}
    - Hs*tau_k
    + sum beta_iq(n)*tau_{k-n}
    = input_area

比较低阶模型和 memory-kernel 模型在高频段的预测误差。

### 验证 D：delay 分类

分别注入：

    Tsampling, Tcalc, Treset, Tgate

观察：

1. 事件面积是否增加。
2. Bode 幅值是否变化。
3. 相位裕度是否下降。
4. 负载阶跃恢复是否变慢。

目标是证明：sampling/calculation/reset 更像面积偏移，gate delay 更像 phase lag。

### 验证 E：constant-Q 与 AI 修正对照

三组对比：

1. 固定 VTH/IQCOT。
2. Liu constant-Q。
3. PETS-IQCOT + AI constrained Delta_psi。

扫描：

    Vin, Vo, Iout, L, Cout, ESR, Td

指标：

    Q_eff, phase margin, overshoot, undershoot, recovery time, switching jitter

### 验证 F：多相均流与分辨率

扫描：

    N, Kcb, Ton_trim_limit, DPWM step, delay-line step

指标：

    current sharing error
    limit-cycle amplitude
    phase-current oscillation frequency
    load-step settling time

证明 AI constrained tuning 能在“均流速度”和“量化振荡风险”之间自动折中。

## 11. 论文中可写的贡献点

建议最终贡献写成 3 点：

1. 提出 IQCOT 积分事件参数化 sampled-data 模型。该模型从 IQCOT 面积触发方程出发，对事件边界进行线性化，给出触发时刻扰动与阈值、电流反馈、blanking、on-time 和外部扰动之间的关系。
2. 提出面向 AI 调参的低维安全坐标。将 VTH/gm/CT 压缩为 rho，将 Ri 压缩为 kappa，将 constant-Q 约束表示为 psi_eff 和 Q_eff，使 AI 调参具备可辨识性和稳定性约束。
3. 提出多相数字 IQCOT 的共模/差模约束调参框架。共模调节 Q 和电压动态，差模调节均流参数，并显式考虑 delay、DPWM 分辨率和 current-balance limit cycle。

## 12. 后续还建议补充的文献

当前 8 篇已经足够支撑 IQCOT、constant-Q、sampled-data、delay、DICOT 主线。若要把 AI 和数字量化部分做得更扎实，建议再补充：

1. A. V. Peterchev and S. R. Sanders, Quantization Resolution and Limit Cycling in Digitally Controlled PWM Converters, IEEE TPEL, 2003。用于 DPWM 分辨率和 limit cycle 理论。
2. H. Peng, D. Maksimovic, A. Prodic, and E. Alarcon, Modeling of Quantization Effects in Digitally Controlled DC-DC Converters, IEEE TPEL, 2007。用于 ADC/DPWM 量化噪声建模。
3. B. J. Patella, A. Prodic, A. Zirger, and D. Maksimovic, High-Frequency Digital PWM Controller IC for DC-DC Converters, IEEE TPEL, 2003。用于数字控制实现背景。
4. D. Lee et al., Reinforcement Learning-Based Control of DC-DC Buck Converter Considering Controller Time Delay, IEEE Access, 2024。用于 AI/RL 与控制延迟结合的相邻工作。
5. 与 safe/constrained reinforcement learning 或 Bayesian optimization for controller tuning 相关的 1-2 篇综述或应用论文，用于说明本文为什么选择“AI 调参数”而不是“AI 直接输出 PWM”。

## 13. 最终建议

你的毕业设计不要把 AI 放在最底层直接控制 MOSFET，也不要把 AI 描述成替代 IQCOT。更有说服力的路线是：

    IQCOT 保留物理快速内环
    PETS-IQCOT 建立可解释小信号/事件模型
    AI 只在 rho、psi、kappa、Kcb、Ton_trim_limit 等安全坐标上调参
    仿真验证其在输入、负载、相数、delay 和参数误差变化下优于固定参数 IQCOT/constant-Q

这样选题既和已有 IQCOT 文献拉开距离，又不脱离电源电子控制理论的可验证性。
