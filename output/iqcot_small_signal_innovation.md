# IQCOT 小信号模型创新分析与实践方案

本文给出一个可作为毕业设计创新点的 IQCOT 小信号建模方法。核心思想是：不只建立传统的 `vc -> vo` 传递函数，而是把 IQCOT 的积分触发机理、数字采样延迟、多相电流均衡和 AI 参数调度统一到一个“面积域采样数据模型”中。

## 1. 研究增量定位

已有文献已经给出三类结果：

1. IQCOT 基本控制律：

   ```text
   iramp = gm * (vc - Ri * iL)
   integral(iramp) dt = CT * VTH
   ```

   即：

   ```text
   integral(vc - Ri * iL) dt = CT * VTH / gm
   ```

2. IQCOT 高频小信号模型近似为：

   ```text
   vo/vc ~= Kc * (1 + s*Rc*Co)/(1 + s/wa)
            * 1/(1 + s/(Q1*w1) + (s/w1)^2)
            * 1/(1 + s/(Q2*w2) + (s/w2)^2)
   ```

   其中：

   ```text
   w1 = pi/Ton
   Q1 ~= 2/pi
   w2 = pi/Tsw
   Q2 与 D, VTH, gm, Ri, L, Vo, Tsw 有关
   ```

3. 常 Q 文献提出：

   ```text
   VTH = (alpha + beta*D) * Vo
   beta = gm * Ri * Tsw^2 / (2 * CT * L)
   ```

本文的创新不是重复这三个结论，而是进一步做三件事：

1. 将 IQCOT 的积分触发式写成“面积域采样数据模型”，显式描述开关时刻扰动。
2. 把 `VTH, gm, Ri, Ton` 当作可调参数的小信号输入，得到参数到 `Q2`、输出阻抗、瞬态指标的灵敏度。
3. 将单相模型扩展为多相的共模/差模模型，使 AI 可以分别调节电压动态和相电流均衡。

## 2. 面积域采样数据模型

### 2.1 积分触发方程

定义第 k 个脉冲开始时刻为 `t_k`。对于 TOFF 积分型 IQCOT，假设积分从上一周期导通结束时刻 `a_k = t_{k-1} + Ton` 开始，到下一次触发时刻 `t_k` 结束。触发条件写成：

```text
F_k = integral_{a_k}^{t_k} [vc(t) - Ri*iL(t)] dt - Lambda = 0
Lambda = CT*VTH/gm
```

这个式子比“瞬时比较器交点模型”更适合数字实现，因为 DICOT/数字 IQCOT 的本质就是对误差信号做累加，直到越过阈值。

### 2.2 稳态条件

稳态下：

```text
vc(t) = VC
iL(t) = IL_bar(t)
Tsw = Ton + Toff
D = Ton/Tsw
```

因此：

```text
integral_{Ton}^{Tsw} [VC - Ri*IL_bar(t)] dt = Lambda
```

这给出了稳态工作频率、阈值和电流反馈之间的约束。若采用 AOT，使 `Ton = D*Tsw`，则可以把占空比变化集中到 `D` 和 `Lambda` 的关系中。

### 2.3 一阶线性化

令：

```text
vc = VC + vc_hat
iL = IL_bar + i_hat
Ri = Ri0 + Ri_hat
Lambda = Lambda0 + Lambda_hat
t_k = k*Tsw + tau_k
```

对 `F_k = 0` 做一阶线性化：

```text
S_e * tau_k - S_s * tau_{k-1}
+ integral_{a_k}^{t_k} [vc_hat(t) - Ri0*i_hat(t) - IL_bar(t)*Ri_hat] dt
- Lambda_hat = 0
```

其中：

```text
S_e = VC - Ri0*IL_bar(t_k^-)
S_s = VC - Ri0*IL_bar(a_k^+)
```

`S_e` 是积分终点处的面积增长斜率，`S_s` 是积分起点扰动带来的边界项。这个式子是本文建模创新的关键，因为它把开关时刻扰动 `tau_k`、控制扰动 `vc_hat`、电流扰动 `i_hat`、参数扰动 `Ri_hat, Lambda_hat` 放在同一个方程中。

### 2.4 参数扰动等效面积输入

由于：

```text
Lambda = CT*VTH/gm
```

有：

```text
Lambda_hat/Lambda0 = CT_hat/CT0 + VTH_hat/VTH0 - gm_hat/gm0
```

所以：

```text
Lambda_hat = Lambda0*(CT_hat/CT0 + VTH_hat/VTH0 - gm_hat/gm0)
```

`Ri` 的扰动不在阈值项里，而在积分信号里：

```text
Delta_A_Ri = - integral IL_bar(t) dt * Ri_hat
```

因此，AI 调参实际是在调两个等效面积通道：

```text
threshold channel:  VTH_hat, gm_hat, CT_hat -> Lambda_hat
current-weight channel: Ri_hat -> integral current area
```

这比直接学习 PWM 更安全，因为所有动作都被 IQCOT 原始积分律约束。

## 3. Q 值归一化模型

从文献模型取半开关频率附近的 `Q2`：

```text
Q2 = Tsw/pi * 1 / ( CT*VTH*D/(gm*Ton*sf) - Ton/2 )
sf = Ri*Vo/L
```

若 AOT 保持固定频率，`Ton = D*Tsw`，代入得：

```text
Q2 = 1 / [ pi * ( psi - D/2 ) ]
```

其中定义无量纲控制量：

```text
psi = CT * L * VTH / (gm * Ri * Vo * Tsw^2)
```

这是一个非常适合 AI 的重参数化。因为 AI 不需要直接学 `VTH, gm, Ri` 的复杂耦合，而是学一个稳定性直接相关的无量纲变量 `psi`。

### 3.1 目标 Q 反解

若希望目标质量因子为 `Qstar`：

```text
psi_star = D/2 + 1/(pi*Qstar)
```

于是：

```text
VTH_star = gm * Ri * Vo * Tsw^2 / (CT * L) * ( D/2 + 1/(pi*Qstar) )
```

整理成文献的常 Q 形式：

```text
VTH_star = (alpha + beta*D) * Vo
alpha = gm * Ri * Tsw^2 / (pi * Qstar * CT * L)
beta  = gm * Ri * Tsw^2 / (2 * CT * L)
```

这说明 `alpha` 控制目标 Q，`beta` 抵消 duty cycle。

### 3.2 灵敏度分析

令：

```text
zeta = psi - D/2
Q2 = 1/(pi*zeta)
```

则：

```text
d ln(Q2) = - d zeta / zeta
```

在 `D` 独立扰动时：

```text
partial ln(Q2)/partial ln(VTH) = -psi/zeta
partial ln(Q2)/partial ln(gm)  = +psi/zeta
partial ln(Q2)/partial ln(Ri)  = +psi/zeta
partial ln(Q2)/partial ln(L)   = -psi/zeta
partial ln(Q2)/partial D       = 1/(2*zeta)
```

含义：

1. 当 `zeta` 接近 0 时，系统靠近稳定边界，所有参数误差都会被放大。
2. `VTH` 增大使 Q 降低，`gm` 或 `Ri` 增大使 Q 升高。
3. AI 调参必须远离 `zeta = 0`，可以设置安全约束：

```text
zeta_min <= psi - D/2 <= zeta_max
Qmin <= Q2 <= Qmax
```

例如：

```text
0.45 <= Q2 <= 1.0
```

## 4. 数字延迟等效阈值模型

数字 IQCOT/DICOT 不可避免有采样延迟和计算延迟。设总延迟：

```text
Td = Tadc + Tcalc + Tdpwm
```

积分触发本应在 `F_k=0` 时发生，但数字控制在 `Td` 后才发出 turn-on pulse。因此多积分了一块面积：

```text
Delta_A_delay ~= S_e * Td
```

等效到阈值：

```text
Lambda_eff = Lambda + Delta_A_delay
```

等效到 `VTH`：

```text
VTH_eff = VTH + gm/CT * S_e * Td
```

所以数字延迟可以进入 Q 模型：

```text
psi_eff = CT*L*VTH_eff/(gm*Ri*Vo*Tsw^2)
Q2_eff = 1/[pi*(psi_eff - D_eff/2)]
```

进一步，若考虑 DPWM 分辨率导致的时刻量化 `Delta_tq`：

```text
sigma_A_quant ~= |S_e| * Delta_tq/sqrt(12)
sigma_VTH_quant ~= gm/CT * sigma_A_quant
```

这可以作为 AI 训练中的噪声鲁棒性指标。

## 5. 多相共模/差模扩展

对 N 相 Buck，令：

```text
i_avg = (1/N) * sum(i_j)
delta_i_j = i_j - i_avg
sum(delta_i_j) = 0
```

共模决定输出电压，差模决定相电流均衡。

### 5.1 共模 IQCOT 面积律

如果控制器使用平均电流或合成电流：

```text
integral [vc - Ri*i_avg] dt = Lambda_cm
```

共模模型仍使用上面的 `Q2_eff`：

```text
Q2_cm = 1/[pi*(psi_cm_eff - D_eff/2)]
```

AI 的共模动作：

```text
theta_cm = {VTH_cm, gm_cm, Ri_cm, Qstar}
```

目标是稳定输出阻抗、减小过冲/欠冲和恢复时间。

### 5.2 差模电流均衡模型

第 j 相电流差模近似为：

```text
d(delta_i_j)/dt = -(Req/L)*delta_i_j + (Vin/L)*(delta_d_j - delta_d_avg)
```

电流均衡环调节该相 on-time 或阈值：

```text
delta_d_j = -Kcb(s) * delta_i_j * e^(-s*Td)
```

于是差模闭环近似：

```text
Gcb_j(s) = [(Vin/L)*Kcb(s)*e^(-s*Td)]
           / [s + Req/L + (Vin/L)*Kcb(s)*e^(-s*Td)]
```

这说明电流均衡并非增益越大越好。增益过小，均流慢；增益过大，在数字延迟下容易振荡。AI 的差模动作应调：

```text
theta_dm = {Kcb, LPF pole, per-phase VTH offset, per-phase Ton trim}
```

目标：

```text
min current_error_rms
subject to phase_margin_cb > margin_min
           no DPWM limit-cycle
           no current-limit false trigger
```

## 6. AI 调参不应直接学习原始参数

推荐 AI 输出以下安全参数：

```text
u_ai = {Qstar, Delta_psi, Kcb, Delta_Ton_cm, Delta_Ton_dm}
```

然后由物理模型映射到真实电路参数：

```text
psi_cmd = D_eff/2 + 1/(pi*Qstar) + Delta_psi
VTH_cmd = gm*Ri*Vo*Tsw^2/(CT*L) * psi_cmd
```

这样 AI 即使有误差，也更容易被限幅：

```text
Qmin <= 1/[pi*(psi_cmd - D_eff/2)] <= Qmax
VTH_min <= VTH_cmd <= VTH_max
Iphase_pk <= Ilimit
Ton_min <= Ton_cmd <= Ton_max
Toff_min <= Toff_cmd
```

## 7. 可执行实践流程

### Step 1：建立基准模型

输入参数：

```text
Vin, Vo, fsw, L, Co, ESR, DCR, Nphase
Ri, gm, CT, VTH, Ton, Tadc, Tcalc, Tdpwm
```

计算：

```text
D_ideal = Vo/Vin
Iph = Iout/Nphase
Req_ph = Ron_HS*D + Ron_LS*(1-D) + DCR
D_eff = (Vo + Iph*Req_ph)/Vin
Ton = D_eff/fsw
Tsw = 1/fsw
Td = Tadc + Tcalc + Tdpwm
```

### Step 2：计算 Q 预测值

```text
S_e ~= VC - Ri*Ivalley
VTH_eff = VTH + gm/CT*S_e*Td
psi_eff = CT*L*VTH_eff/(gm*Ri*Vo*Tsw^2)
Q2_eff = 1/[pi*(psi_eff - D_eff/2)]
```

### Step 3：构建 AI 训练标签

仿真扫描：

```text
Vin: 5 V to 20 V
Vo: 0.6 V to 1.8 V
Iout: light to full load
dI/dt: 50 A/us to 1000 A/us
L/C/ESR/DCR: +/- tolerance
Nphase: 1, 2, 4, 6
Td: ADC/calculation/DPWM delay sweep
```

记录指标：

```text
undershoot
overshoot
settling_time
ripple_pp
phase_current_error
Q2_measured_from_bode
subharmonic_flag
current_limit_flag
efficiency
```

### Step 4：训练目标函数

```text
Reward = -w1*undershoot
         -w2*overshoot
         -w3*settling_time
         -w4*ripple_pp
         -w5*phase_current_error
         -w6*abs(Q2 - Qtarget)
         -w7*loss
         -Penalty
```

硬惩罚：

```text
Penalty = large, if subharmonic_flag = 1
Penalty = large, if Iphase_pk > Ilimit
Penalty = large, if Q2 outside [Qmin, Qmax]
Penalty = large, if Ton/Toff violates timing limits
```

### Step 5：论文中的实验对照组

建议至少做四组：

1. 固定 `VTH` 的 IQCOT。
2. 文献方法：`VTH = K*Vo`。
3. 解析常 Q：`VTH = (alpha + beta*D)*Vo`。
4. 本文方法：`VTH = physical_constant_Q + AI correction`。

本文方法写成：

```text
VTH = gm*Ri*Vo*Tsw^2/(CT*L)
      * [D_eff/2 + 1/(pi*Qstar) + Delta_psi_ai]
```

其中：

```text
Delta_psi_ai = NN(Vin, Vo, Iout, dI/dt, Nphase, Td, T, estimated parasitics)
```

## 8. 可写进论文的创新点表述

可以这样写：

本文提出一种面向数字多相 IQCOT Buck 变换器的面积域参数化小信号模型。不同于传统 IQCOT 小信号模型仅研究控制到输出传递函数，本文从 IQCOT 的积分触发方程出发，将开关时刻扰动、积分阈值扰动、电流反馈权重扰动和数字采样延迟统一为等效面积扰动。在此基础上，提出无量纲 Q 控制变量 psi，将半开关频率处的高频极点质量因子表示为 Q2 = 1/[pi(psi-D/2)]，从而建立 AI 调参变量与稳定裕度之间的显式关系。进一步，通过共模/差模分解，将多相输出电压动态和相电流均衡动态解耦，为 AI 参数调度器提供可解释、安全约束的训练目标。

## 9. 本方法的边界

1. 该模型仍需由 SIMPLIS/Simulink 或硬件 Bode 测量校准，因为 `S_e`、延迟、DCR sensing、DPWM 量化会引入实际偏差。
2. AI 只应调慢变量或中速参数，不能无约束地逐周期替代 IQCOT 内环。
3. 若进入 DCM、强非线性限流、burst mode，需切换模型或单独建模。

