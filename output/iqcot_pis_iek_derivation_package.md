# Derivation Package

## Target

推导并组织四相数字 IQCOT Buck 的 PIS-IEK 小信号模型，使其能够解释：

1. IQCOT 面积事件如何由移动事件边界线性化得到动态积分事件核；
2. 四相 `phase_idx/reset` 如何进入 event-to-event Jacobian；
3. 切载下 `normal/skip/reentry/saturation` 模式如何扩展小信号模型边界；
4. FPGA AI 延迟和参考斜率如何作为事件域参数进入训练模型。

## Status

COHERENT AFTER REFRAMING / EXTRA ASSUMPTION

原始目标若表述为“一个小信号模型精确预测所有切载瞬态”，则不成立。经重构后，目标改为“一个 normal 区域局部小信号模型，加上 skip/reentry 混合事件扩展和大信号能量边界”。在这个目标下推导是自洽的。

## Invariant Object

不变量对象不是输出电压峰值，也不是某一个局部斜率，而是事件到事件映射：

```math
\mathcal P:\ (x_k,u_k,I_{o,k},m_k,p_k)\mapsto x_{k+1}.
```

所有推导都围绕该映射展开。输出电压、相位间隔、均流误差、事件等待时间和 skip 次数都作为该映射的观测量或模式结果，而不是替代顶层对象。

## Assumptions

- 研究对象限定为四相交错 Buck / 数字 IQCOT，不在本文推广任意 N 相。
- 在 normal 小扰动区域，事件之间的功率级可在工作点附近线性化。
- 面积事件面满足 `g_T != 0`，即事件边界横截；若 `g_T` 接近 0 或事件被 blanking/饱和约束主导，则应切换模式。
- PIS-IEK 的 Jacobian 描述局部事件扰动，不用于单独预测大切载第一峰。
- skip/reentry 作为离散模式变量处理，而不是强行纳入同一个线性矩阵。
- AI 不直接输出 gate command，而输出低维参数调度量。

## Notation

- `x_k`：第 `k` 个事件前后的事件域状态，可包含输出电压扰动、相电流扰动、积分器状态、相位间隔状态等。
- `p_k=k mod 4`：当前 on-time 相索引。
- `q_k=(p_k+1) mod 4`：下一触发相索引。
- `T_k`：第 `k` 个事件等待时间或 off-time 事件间隔。
- `Lambda_i`：第 `i` 相面积阈值。
- `Ton_i`：第 `i` 相 on-time 命令或 trim 后导通时间。
- `m_k`：事件模式，属于 `{normal, skip, reentry, saturation}`。
- `tau_AI`：AI 推理与参数提交总延迟。
- `T_e`：四相事件平均间隔，约为 `T_sw/4`。
- `d=ceil(tau_AI/T_e)`：AI 延迟对应的事件滞后。

## Derivation Strategy

推导采用四层结构：

1. 从单事件面积条件出发，得到移动边界线性化公式；
2. 将事件时间扰动代回功率级状态更新，得到 IEK 动态事件核；
3. 将单事件推广到四相 `p_k/q_k` 索引，得到 PIS-IEK saltation-corrected map；
4. 对切载和 AI 延迟引入模式变量与动作滞后，形成混合事件训练模型。

## Derivation Map

1. 面积事件条件 `F=0` 决定事件时间 `T_k`。
2. `delta F=0` 给出 `delta T_k` 与 `delta x_k, delta Lambda_k` 的关系。
3. 状态更新 `delta x_{k+1}=A_d delta x_k+B_T delta T_k+B_u delta u_k` 将事件时间扰动反馈到下一事件状态。
4. 四相系统中，事件面不是单一 `g`，而是 `g_{q_k}`；状态更新不是单一 `F`，而是 `F_{p_k}`。
5. `normal` 模式下可使用局部 Jacobian；切载导致 `skip/reentry` 时切换 `F_m`。
6. AI 动作进入模型时不是 `u_k`，而是 `u_{k-d}` 或保持后的 `u_k^a`。

## Main Derivation

### Step 1. 面积事件定义

第 `k` 次 IQCOT off-time 触发事件定义为：

```math
F_k(x_k,T_{off,k},\Lambda_k)
=\int_0^{T_{off,k}} h(x_k,\tau)d\tau-\Lambda_k=0.
```

典型 IQCOT 面积核为：

```math
h(t)=v_c(t)-R_i i_L(t).
```

该式是定义，不是近似。

### Step 2. off-time 状态演化

在工作点附近，off-time 内功率级采用线性化近似：

```math
\dot{x}=A_{off}x+B_{off}u,
\qquad
h(t)=C_h x(t)+D_hu(t).
```

由状态转移矩阵得到：

```math
x(\tau)=e^{A_{off}\tau}x_k
+\int_0^\tau e^{A_{off}(\tau-s)}B_{off}u(s)ds.
```

这是在小扰动工作点附近的近似，不是大信号全局模型。

### Step 3. 移动事件边界线性化

对 `F_k=0` 做一阶扰动：

```math
\delta F
=F_x\delta x_k+H_e\delta T_{off,k}-\delta\Lambda_k=0.
```

其中

```math
F_x=\int_0^{T_{off}} C_h e^{A_{off}\tau}d\tau,
\qquad
H_e=h(T_{off}^{-}).
```

解得：

```math
\delta T_{off,k}
=\frac{1}{H_e}(\delta\Lambda_k-F_x\delta x_k).
```

若忽略 `F_x delta x_k`，则退化为 He-only：

```math
\delta T_{off,k}\approx\frac{\delta\Lambda_k}{H_e}.
```

因此 He-only 的缺失项正是 off-time 面积积分期间积累的状态记忆。

### Step 4. IEK 状态更新

事件后的状态更新写成：

```math
\delta x_{k+1}=A_d\delta x_k+B_T\delta T_{off,k}+B_u\delta u_k.
```

代入 `delta T`：

```math
\delta x_{k+1}
=\left(A_d-\frac{B_TF_x}{H_e}\right)\delta x_k
+\frac{B_T}{H_e}\delta\Lambda_k+B_u\delta u_k.
```

定义：

```math
A_{IEK}=A_d-\frac{B_TF_x}{H_e}.
```

由此得到从面积阈值到事件等待时间的动态传递：

```math
G_{T\Lambda}(z)
=D_{T\Lambda}+C_T(zI-A_{IEK})^{-1}B_{IEK}
=\frac{1}{H_e+K(z)}.
```

其中 `K(z)` 是 IEK 的核心项，表示动态面积刚度修正。

### Step 5. 四相相索引推广

四相系统中，当前导通相和下一触发相为：

```math
p_k=k\bmod 4,\qquad q_k=(p_k+1)\bmod 4.
```

事件更新写为：

```math
x_{k+1}=F_{p_k}(x_k,u_k,T_k),
\qquad
g_{q_k}(x_k,u_k,T_k)=0.
```

其中：

```math
g_{q_k}
=\int_0^{T_k}
\left[v_c(t)-R_i i_{L,q_k}(t)\right]dt-\Lambda_{q_k}.
```

这一步将 `phase_idx` 变成事件面索引，而不是仿真程序的附属变量。

### Step 6. 相索引盐跃线性化

对事件面线性化：

```math
g_x\delta x_k+g_u\delta u_k+g_T\delta T_k=0.
```

若 `g_T != 0`，则

```math
\delta T_k=-g_T^{-1}(g_x\delta x_k+g_u\delta u_k).
```

状态更新的一阶扰动为：

```math
\delta x_{k+1}=F_x\delta x_k+F_u\delta u_k+F_T\delta T_k.
```

代入得：

```math
\delta x_{k+1}
=
\left(F_x-F_Tg_T^{-1}g_x\right)\delta x_k
+
\left(F_u-F_Tg_T^{-1}g_u\right)\delta u_k.
```

这就是 PIS-IEK 的 normal-mode Jacobian。

### Step 7. 执行量通道

将执行量分成 common-mode 与 differential-mode：

```math
\delta u_k=
\begin{bmatrix}
\delta\Lambda_{cm} &
\delta\Lambda_{diff} &
\delta Ton_{cm} &
\delta Ton_{diff}
\end{bmatrix}^{T}.
```

PIS-IEK 的输出矩阵可选择为：

```math
\delta y_k=
\begin{bmatrix}
\delta T_k &
\delta \phi_k &
\delta i_{m2,k} &
\delta v_{o,k}
\end{bmatrix}^{T}.
```

于是局部执行量矩阵为：

```math
\delta y_k=J_{IEK}\delta u_k.
```

该矩阵的物理解释是本文的核心工程价值：`Lambda_diff` 多对应相位/事件节奏，`Ton_diff` 多对应 DC 均流。

### Step 8. 切载混合事件扩展

切载时，负载扰动 `delta I_o<0` 可能使 normal-mode 事件等待时间变长：

```math
\delta T_k
=-g_T^{-1}
\left(
g_x\delta x_k
+g_I\delta I_{o,k}
+g_u\delta u_k
\right).
```

当等待时间超过 blanking、事件队列或调度约束时，系统进入 skip：

```math
m_k=\mathrm{skip}.
```

skip 模式下没有新的 on-time 能量注入，状态满足近似：

```math
L_i\frac{di_{Li}}{dt}=-v_o-r_{Li}i_{Li},
```

```math
C_o\frac{dv_o}{dt}=\sum_{i=1}^{4}i_{Li}-I_o.
```

当面积条件重新满足并恢复事件触发，进入：

```math
m_k=\mathrm{reentry}.
```

因此混合模型为：

```math
x_{k+1}=F_{m_k,p_k}(x_k,u_k,I_{o,k},T_k).
```

### Step 9. AI 延迟进入事件模型

FPGA AI 延迟写为事件滞后：

```math
d=\left\lceil\frac{\tau_{AI}}{T_e}\right\rceil.
```

实际动作不是 `u_k`，而是：

```math
u_k^a=u_{\kappa(k)},\qquad
\kappa(k)=\max\{jT_u+d\le k\}.
```

于是：

```math
x_{k+1}
=F_{m_k,p_k}(x_k,u_k^a,I_{o,k},T_k).
```

局部线性化为：

```math
\delta x_{k+1}
=A_{m_k,p_k}\delta x_k
+B_{m_k,p_k}\delta u_k^a
+E_{m_k,p_k}\delta I_{o,k}.
```

这就是 AI 训练中需要使用的延迟感知事件域模型。

### Step 10. 参考斜率作为动作

切载参考从 `Iph_0` 到 `Iph_1` 的斜率调度可写为：

```math
I_{\mathrm{ph,ref}}(t)=
\begin{cases}
I_{\mathrm{ph},0}, & t<t_s,\\
I_{\mathrm{ph},0}
+\frac{I_{\mathrm{ph},1}-I_{\mathrm{ph},0}}{T_{\mathrm{slew}}}(t-t_s),
& t_s\le t<t_s+T_{\mathrm{slew}},\\
I_{\mathrm{ph},1}, & t\ge t_s+T_{\mathrm{slew}}.
\end{cases}
```

因此 AI 动作可以扩展为：

```math
u_k=
\begin{bmatrix}
\Delta\Lambda_{\mathrm{diff}} &
\Delta T_{\mathrm{on,diff}} &
\Delta I_{\mathrm{ph,ref}} &
T_{\mathrm{slew}}
\end{bmatrix}^{T}.
```

该动作空间与 PIS-IEK 的事件域状态兼容，并已由 Simulink 参考斜率扫描给出开关级证据。

进一步的离线调度器策略验证表明，`T_slew` 不应作为单一固定常数进入 AI 训练，而应作为目标敏感调度量。基于 dense+long sweep 的后处理结果（`E:/Desktop/codex/output/iqcot_ref_slew_scheduler_policy_eval.csv`），base-score oracle 选择 `80/80/60 us`，平均 base score 为 `9.299`；`score+0.05T_settle` scheduler 选择 `30/50/60 us`，平均 score 为 `10.356`；`score+0.10T_settle` 下则退化为 `30/30/30 us`。因此，AI 的监督层训练目标可以写成

```text
pi_theta: z_k -> T_slew,k
```

其中 `z_k` 至少包含负载下降幅度、当前 phase-spacing 误差、skip/reentry 标志、最终静差权重和 settling 权重。PIS-IEK 的作用是把这些变量放进事件坐标，使 AI 学到的是参数轨迹调度，而不是替代 IQCOT 内环的逐开关动作。

为了把该表达转成可训练数据，当前已生成 `E:/Desktop/codex/output/iqcot_ai_supervisor_training_targets.csv`。该表把 `z_k` 的一部分显式化为

```text
z_label = [target_load_A, load_drop_norm, alpha_settle, tau_AI, delay_events],
delay_events = ceil(tau_AI / 0.5us),
```

并以开关级 Simulink sweep 的 oracle `T_slew` 作为标签。该表的作用是连接“参考斜率开关级证据”和“FPGA 延迟事件域建模”，使后续 AI-in-loop 验证能够先从表驱动监督层开始，而不是直接训练黑箱策略。

在此基础上，本文进一步加入了表驱动监督层的 `5 us` 参数提交延迟验证。验证脚本为
`E:/Desktop/codex/output/iqcot_table_supervisor_ref_slew_validation.m`，只使用派生模型
`E:/Desktop/codex/output/simulink_iek/four_phase_iek_dynamic_load_refslew.slx`，不保存或直接编辑
`.slx`。对于表驱动策略，参考轨迹写成

```math
I_{\mathrm{ph,ref}}(t;\tau_{AI})=
\begin{cases}
I_{\mathrm{ph},0}, & t<t_s+\tau_{AI},\\
I_{\mathrm{ph},0}
+\frac{I_{\mathrm{ph},1}-I_{\mathrm{ph},0}}{T_{\mathrm{slew}}}
(t-t_s-\tau_{AI}),
& t_s+\tau_{AI}\le t<t_s+\tau_{AI}+T_{\mathrm{slew}},\\
I_{\mathrm{ph},1}, & t\ge t_s+\tau_{AI}+T_{\mathrm{slew}}.
\end{cases}
```

该式是 `u_{k-d}` 在开关级参考通道中的等效实现，不是神经网络在线推理。`tau_AI=5 us`
时，表驱动验证覆盖 `15` 个工况，结果表明 `alpha=0.05` table 的 mean base score 和
mean `score+0.05T_settle` 分别为 `8.383` 和 `9.657`，`alpha=0.10` table 的
mean `score+0.10T_settle` 为 `10.785`。因此，PIS-IEK 对 AI 的价值可以更精确地表述为：
它把 `T_slew` 的选择、参数提交延迟和目标函数权重放到同一个事件坐标中，使监督层调度可以先用表驱动方式在开关级模型中验证。

随后补齐的 `tau_AI=0.5/1/2 us` 验证把正延迟开关级工况扩展到 `60` 个。合并零延迟参考排序后，best-by-tau 结果显示：base 目标在 `0/0.5/1 us` 下偏向 base-score table，在 `2/5 us` 下偏向 `alpha=0.05` table；`score+0.05T_settle` 在 `0/2/5 us` 下偏向 `alpha=0.05` table，在 `0.5/1 us` 下偏向 `alpha=0.10` table；`score+0.10T_settle` 也不是单调随延迟变化。这个现象反而强化了 PIS-IEK 的监督层意义：AI/table 不应学习一个固定 `T_slew` 常数，而应学习

```text
pi_theta: [Delta I_load, alpha_settle, tau_AI, delay_events, phase_state] -> T_slew.
```

最新 R022 后处理把这一步继续推进为 score-prediction supervisor。对 `60` 个正延迟 delayed-reference 开关级工况，按 `base`、`score+0.05T_settle` 和 `score+0.10T_settle` 三个目标函数展开，得到 `180` 行候选策略打分样本：

```text
s_phi:
[
Delta I_load,
alpha_settle,
tau_AI,
delay_events,
candidate_policy,
candidate_T_slew
]
-> objective_score.
```

监督层不直接回归门极，也不直接声称找到连续全局最优 `T_slew`，而是在候选策略集合中选择预测 objective score 最低的低维动作：

```text
pi_phi(z)=argmin_{a in A_table} s_phi(z,a).
```

其中 `A_table` 由已验证的固定斜率和表驱动策略组成。leave-one-tau-out 结果显示，延迟最近邻目标表的 mean regret 为 `0.304`，比固定 `40 us` 基线低约 `73.2%`，但仅比零延迟目标表低 `0.013`；leave-one-target-out 中，零延迟目标表仍是最强基线，ridge score supervisor 虽优于固定斜率但未超过该强基线。这说明 PIS-IEK 给出的事件延迟坐标可以组织监督层训练，但当前证据仍应写成“近似策略排序和优于固定斜率”，不能写成“AI 全面优于查表”。

R023 进一步把离散候选集合扩展为连续动作的前置分析。对已有 dense+long sweep，在每个目标函数的采样最优点附近做局部二次近似：

```text
s_phi(z,T_slew) ≈ a(z)T_slew^2 + b(z)T_slew + c(z),
```

并在 `20-120 us` 当前采样区间内计算 near-optimal band：

```text
B_epsilon(z)=
{T_slew: s_phi(z,T_slew) <= min_T s_phi(z,T)+epsilon}.
```

R023 的最大局部二次估计收益仅为 `0.239` 分，说明连续动作更适合用作平滑调度和安全投影变量，而不是宣称大幅优于离散查表。R024 随后用 `45` 个派生 Simulink 局部细扫工况检查这些候选。结果显示，`20A` 的 `35 us` 最近候选因 `skip_count=1` 反而劣于旧 `30 us`，但同一区间 `38 us` 和更宽网格中的 `66 us` 给出小幅改善；near0A 的 `score+0.10T_settle` 在 `38 us` 相对旧 `30 us` 改善约 `0.235` 分。这说明 `T_slew` 景观不是严格平滑二次曲线，而是受到模式边界、skip/reentry 和相位指标的非光滑影响。

工程上更合理的连续监督层应输出

```text
T_slew^plant =
clip(pi_phi(z), B_epsilon(z,m_k,tau_AI)) ,
```

并且仍通过 `tau_AI` 对应的延迟缓冲提交到参考通道。这里的 `B_epsilon` 不是硬件安全集合，只是从当前开关级 sweep 和局部细扫后处理得到的设计带；局部二次候选点必须由新的 Simulink 工况确认，且确认结果可以修正候选点位置。

R025 将该思想进一步组织成可解释 score surrogate。将监督层上下文写为

```text
z = [Delta I_load, alpha_settle, tau_AI, delay_events],
```

并把事件模式代理写为

```text
m_hat = [skip_count_est, phase_spacing_std_ns, settle_time_us].
```

则裸连续模型为

```text
s_smooth(z,T_slew) -> objective_score,
```

而 mode-aware 模型为

```text
s_mode(z,T_slew,m_hat) -> objective_score.
```

R025 的 dense+long+fine 后处理给出 `207` 行 objective-level 样本。只含 `z,T_slew` 的平滑模型 in-sample RMSE 为 `0.855`，加入 `m_hat` 后降至 `0.101`；策略层面，裸二次连续最小化平均 regret 为 `0.654`，`best+0.25` near-optimal band clipping 降至 `0.101`，mode-aware safety projection 降至 `0.064`。这些数字说明 `m_hat` 对 reward shaping 和 action clipping 有价值，但不能说明部署时这些模式变量已被准确预测。

R026 进一步把该后验形式改写为可部署 proxy 形式。在线监督层不直接读取 `skip_count_est/phase_std/settle_time`，而是使用目标负载、负载下降幅度、目标权重、候选 `T_slew` 与 AI 提交延迟：

```text
z_k = [Delta I_load, alpha_settle, tau_AI, delay_events],
```

并由离线校准表或短时事件预测器给出

```text
r_hat(z_k,T_slew) = [hat r_skip, hat r_phase, hat r_settle].
```

因此实际可提交的动作应写成

```text
T_slew^plant =
Proj_{B_epsilon(z_k,r_hat,tau_AI)}
  argmin_T s_smooth(z_k,T).
```

R026 离线重放显示，纯 `target/load/T_slew` 光滑参数 proxy 的平均 regret 为 `0.857`，甚至劣于裸连续策略，说明模式跳变不能被简单平滑回归消除；而将已完成细扫整理为可预存校准风险表后，`calibrated_risk_proxy_projection` 平均 regret 为 `0.119`，低于 dense-long 表 `0.163` 和裸连续 `0.654`，但仍弱于后验 mode-aware projection `0.064`。这说明 R026 的价值不是证明 AI 已经闭环最优，而是给出从 PIS-IEK 后验模式变量到可部署 `r_hat` 接口的严谨降级路径。

作为对照，R025 的后验上界形式可写为

```text
T_slew^plant =
clip(
  argmin_T s_mode(z,T,m_hat),
  B_epsilon(z,m_hat,tau_AI)
).
```

其中 `m_hat` 在真实 AI-in-loop 中必须由事件状态、PIS-IEK surrogate 或保守规则提前估计，不能由未来仿真指标直接提供。R026 的 `r_hat` 写法正是为了把这个后验上界降级为可部署接口。

R027 把上述可部署接口进一步落到开关级验证入口。离线计划写成

```text
case_j =
[
target_load_A,
alpha_settle,
tau_AI,
policy_j,
T_slew,j,
t_commit,j
],
```

其中固定斜率策略的 `t_commit=0`，表驱动、proxy projection 和后验对照的

```text
t_commit = tau_AI.
```

这相当于在派生 Simulink 参考通道中实现事件域延迟动作 `u_{k-d}`：

```text
Iph_ref(t;T_slew,t_commit)
= ramp(Iph_0 -> Iph_1, start=t_load+t_commit, duration=T_slew).
```

已生成完整 `315` 行验证计划与 `48` 行优先计划，并完成优先矩阵全部派生模型 switching 工况。合并后处理显示：dense-long table 与 posterior 上界 mean switching regret 均为 `0.025`，near-opt band 为 `0.257`，calibrated proxy 为 `0.283`；proxy 相对 dense-long 在 `0/8` 个压力上下文更优、`4/8` 个上下文并列、`4/8` 个上下文更差。因此 R027 对 PIS-IEK 推导的意义是双重的：第一，`r_hat` 监督层动作提交已经被转换为可执行开关级检验；第二，当前 `B_epsilon(z,r_hat,tau_AI)` 校准不足，不能声称 proxy 已经优于强查表基线。

R028 将 R027 的负面压力样本反向用于安全投影重标定。保守部署形式写为

```text
T_slew^plant =
Proj_{B_epsilon^sw(z_k,r_hat,tau_AI,T_dense)}
  T_slew^proxy ,
```

其中 `T_dense` 是 dense-long table 的强基线动作，`B_epsilon^sw` 是由派生开关级压力结果校准的上下文带。当前 R028 实现采用两层策略：

```text
T_slew^anchor =
  T_slew^proxy,  if |T_slew^proxy - T_dense| <= epsilon(z_k,tau_AI)
  T_dense,       otherwise
```

并对已知失败模式使用更紧的 `epsilon`。例如 R027 显示 `10A/score_settle005` 下旧 proxy 选择 `62 us` 会劣于 `50 us` dense-long table，因此 R028 在该上下文将 `epsilon` 收紧为 `0 us`，直接投影回 `50 us`。该保守规则在 R027 priority replay 中将 mean switching regret 从旧 proxy 的 `0.283` 降至 `0.025`，与 dense-long table 并列。

为了形成下一步验证假设，R028 还构造了 stress-calibrated guarded candidate：

```text
T_slew^guard =
  34 us, if target=10A, alpha_settle=0.05, tau_AI>=2 us
  35 us, if target=near0A, alpha_settle=0.10, tau_AI=0
  T_slew^anchor, otherwise.
```

该候选在同一 R027 priority replay 中为 `0.000` mean switching regret，但它由这些压力点校准得到，因此只能作为 R029 held-out 派生 Simulink 验证对象，不能视为已证明泛化的硬件安全规则。推导上的重要变化是：`B_epsilon` 不再只是离线 score/surrogate 的抽象可行域，而是可以被开关级负样本闭环修正的监督层投影接口。

R029 对该 guarded candidate 做了 held-out 派生 Simulink 检验。对 `10A/score_settle005`，验证矩阵为

```text
tau_AI in {1.5, 2.5, 3.0} us,
T_slew in {34, 40, 50, 62} us.
```

结果显示 `tau_AI=1.5us` 时 `40us` 最优，而 `tau_AI=2.5/3us` 时 `34us` 最优。这支持 R028 的 `tau_AI>=2us` 短斜率 guard 具有局部 held-out 支持，同时说明它不应向 `2us` 以下外推。旧 proxy 的 `62us` 在 10A held-out 中仍有较高 regret，说明 dense-anchor projection 排除该动作是合理的。

对 near0A 的 `score_settle010`，R029 检验

```text
tau_AI in {0, 0.25, 0.5} us,
T_slew in {30, 35, 38} us.
```

结果修正了 R028 的固定 `35us` guard：`tau_AI=0/0.25us` 下 `38us` 最优或近似最优，`tau_AI=0.5us` 下 `30us` 最优。因此 near0A 更合理的投影应写成局部带

```text
B_epsilon^near0A = {T_slew: 30us <= T_slew <= 38us}
```

并在该带内由 score/risk proxy 选择，而不是硬编码 `35us`。这一步强化了 PIS-IEK 的工程价值：它不是一次性给出某个斜率点，而是把开关级 held-out 样本转化为可迭代收缩的安全带。

R030 将上述 held-out 修正进一步写成 refined-band projection，而不是继续增加硬编码 guard：

```text
B_epsilon^R030(z,tau_AI) =
  {50us},       if target=10A, alpha=0.05, tau_AI <= 1us
  [34,50]us,    if target=10A, alpha=0.05, 1us < tau_AI < 2us
  [34,40]us,    if target=10A, alpha=0.05, tau_AI >= 2us
  [30,38]us,    if target=near0A, alpha=0.10
  B_anchor,     otherwise.
```

当前代表实现取 `10A/tau=1.5us -> 40us`，`10A/tau>=2us -> 34us`，near0A 在 `tau<0.5us` 取 `38us`、在 `tau>=0.5us` 取 `30us`。在 R027 priority replay 与 R029 held-out 的 `12` 个已知 guard-context 上，该代表规则选中行的 mean switching regret 为 `0.000`，而对应 dense-anchor 行为 `0.128`。这不是独立泛化证明，因为规则正是由这些局部证据合成；推导上的意义是，`B_epsilon^sw` 可以从“单个 guard 点”升级为“由开关级负样本和 held-out 样本迭代修正的局部安全带”。

R030 还给出识别 dense-anchor 保守性的挑战集合。从 R027 的 `315` 行完整计划中，筛出 calibrated proxy 与 dense table 不同且未进入 priority switching 的 `24` 个上下文，其中 `20` 个在离线 score 上 proxy 更好。随后已优先验证 `10A/score_settle010` 的 `30us` vs `32us`、`20A/base` 的 `80us` vs `86us`、以及 `20A/score_settle005` 的 `30us` vs `66us`。这些点说明 proxy 候选需要切换级再校准，不应写成 proxy 已经更优。

R031 将 R030 challenge 的负校准结果进一步写成 tightened switching projection。令 `T_dense(z,tau_AI)` 为 dense-long table 或 dense-anchor 基线动作，`T_proxy(z,tau_AI)` 为 calibrated risk proxy 候选。R031 不直接采用 `T_proxy`，而是构造

```text
T_slew,plant =
  Proj_{B_epsilon^sw(z_k, r_hat, tau_AI, T_dense)}
  (T_proxy).
```

其中 `B_epsilon^sw` 由开关级负样本和局部 held-out 证据迭代收紧。基于 R030 的 `15` 个成对上下文，R031 得到以下校准集排序：

```text
direct_proxy_override      mean regret = 0.574
dense_anchor_baseline      mean regret = 0.186
small_delta_only           mean regret = 0.189
r031_tightened_projection  mean regret = 0.132
pair_oracle_upper_bound    mean regret = 0.000  (non-deployable)
```

这里 `0.132` 只能解释为校准候选，因为 `10A/score_settle010` 的 proxy 子带来自已观测胜负；pair oracle 也只是 pairwise 后验上界。R031 真正改变推导接口的是三条风险分类：

```text
10A, alpha=0.10:
  local near-tie band [30,32] us; proxy requires held-out delay check.

20A, alpha=0:
  block 86us direct override until 82/84us intermediate slopes are checked.

20A, alpha=0.05:
  exclude 66us large-jump proxy unless short-horizon skip/settle predictor
  can certify low event risk.
```

这使 PIS-IEK 的 AI 接口从“回归一个 `T_slew` 点”进一步收缩为“候选 score/risk 生成 + `B_epsilon^sw` 投影”。下一轮 `22` 行最小验证矩阵应检验 `31/33us`、`82/84us`、`38/50/58us` 等中间点，以判断 R031 是否只是记忆 R030 challenge，还是能形成更稳健的局部安全带。

R031 最小 held-out 派生验证已进一步完成。`22` 行中间候选全部在派生 `four_phase_iek_dynamic_load_refslew.slx` 上运行成功，并与 R030 dense baseline、原 proxy 行合并。结果不是“中间候选全胜”，而是更适合写成延迟敏感安全带：

```text
10A, alpha=0.10:
  tau_AI=1us  -> keep dense 30us
  tau_AI=5us  -> 33us can improve over dense

20A, alpha=0:
  keep dense 80us as fallback;
  82/84us expose delay-sensitive local behavior but do not justify 86us override

20A, alpha=0.05:
  tau_AI=0.5/2us -> 50us candidate is useful
  tau_AI=1us     -> 38us candidate is useful
  tau_AI=5us     -> 58us candidate is useful
  66us original proxy remains blocked unless short-horizon risk is certified
```

上下文统计为：R031 best intermediate candidates 在 `3/9` 个上下文优于 dense baseline，在 `8/9` 个上下文优于原 R030 proxy；best-family counts 为 dense `6`、R031 intermediate `3`。因此 `B_epsilon^sw` 的形式应从静态半径进一步写成

```text
B_epsilon^sw(z_k, tau_AI, r_hat)
  = delay-aware local band with dense fallback.
```

其中 `r_hat` 需要预测 skip/settling/phase risk，而不是只根据 `|T_proxy-T_dense|` 或离线 score 排序放行候选。

## Remarks and Interpretation

- `K(z)` 的意义是动态事件记忆，而不是任意拟合项。
- PIS-IEK 的意义是把四相调度结构写入 Jacobian，而不是把所有模式硬塞进一个线性模型。
- `Lambda_diff` 和 `Ton_diff` 不应混用：前者主要调事件时序，后者主要调平均相电流。
- `T_slew` 是很适合 AI 的动作，因为它低维、物理可解释，并且直接影响切载安全。
- R024 细扫显示 `T_slew` 动作需要 mode-aware 约束：局部二次候选点附近可能因为 skip/reentry 跳变而非光滑，不能裸回归一个点。
- R025 后处理显示，忽略模式变量的平滑连续最小化可能产生较大 regret；`skip_count_est/phase_std/settle_time` 更适合进入 `B_epsilon` 和 reward shaping，而不是被当成硬件已知真值。
- R026 显示，部署时应使用离线校准 `r_hat(z,T_slew)` 或短时预测器代替后验模式标签；校准 proxy 有价值，但不能声称跨负载泛化或硬件安全已经解决。
- R027 已将 `r_hat` proxy 转换为派生 Simulink table-in-loop 计划和 MATLAB runner，并完成 48 行优先压力矩阵；结果证明接口可用，但当前 proxy 校准在压力上下文中不稳定优于 dense-long table。
- R028 将 R027 的失败样本用于重标定 `B_epsilon^sw`：保守 dense-anchor projection 修复了已知 `62 us` proxy 失败，stress-calibrated guarded candidate 只作为下一轮 held-out 验证假设。
- R029 held-out 验证支持 10A `tau_AI>=2us` 短斜率 guard 的局部边界，同时把 near0A 固定 `35us` guard 修正为 `30-38us` 局部安全带。
- R030 把 R029 的局部修正组织成 refined-band projection，并完成 dense/proxy 成对挑战点回放；结果支持收紧 proxy safety projection，不是硬件或独立泛化证明。
- R031 把 R030 challenge 的负样本转成 tightened `B_epsilon^sw` 原型和 `22` 行最小 held-out 验证计划；`0.132` mean regret 是校准集结果，不是最终部署 claim。
- R031 最小 held-out 验证已完成；结果支持 delay-aware local band with dense fallback，而不是单一 tightened radius 或 proxy direct override。
- AI 延迟必须以事件数表达。`5 us` 对四相 `500 kHz` IQCOT 是约 `10` 个事件，不是小到可以忽略的延迟。
- 表驱动 `0.5/1/2/5 us` delayed-reference 验证支持 `T_slew` 作为监督层动作，但不等于神经网络 AI-in-loop 或硬件验证。
- 可解释 score 回归器把表驱动验证推进到可训练监督层接口，但当前只证明能近似离散候选策略排序，并未证明连续动作或神经网络闭环优于查表。
- 连续 `T_slew` 景观后处理支持 near-optimal band 和细扫候选设计；它不是新的开关级仿真，也不证明连续动作全局最优。
- R030 dense-anchor challenge 已把 `30` 行 dense/proxy 成对计划接入派生 Simulink delayed-reference 回放。结果显示 proxy 与 dense-anchor 排序只在 `7/15` 个上下文中偏向 proxy，dense-anchor mean switching regret `0.186` 低于 proxy `0.574`；因此 PIS-IEK 对 AI 的支持应写成“候选生成 + 事件风险安全投影”，而不是“proxy 可直接覆盖 dense-anchor”。

## Boundaries and Non-Claims

- 不声称 PIS-IEK 单独精确预测大切载第一峰。
- 不声称 AI 替代 IQCOT 内环或比较器。
- 不声称 `30 us`、`60 us` 或 `80 us` 是参考斜率全局最优。
- 不声称离线 oracle scheduler 已经等价于真实 AI-in-the-loop 或硬件验证。
- 不声称 `iqcot_ai_supervisor_training_targets.csv` 已经证明 AI 闭环优于固定策略；它只是下一步训练和验证的标签表。
- 不声称 `iqcot_table_supervisor_validation_results.csv` 已经证明神经网络 AI 闭环；它证明的是表驱动低维参数调度可在派生开关级模型中进行延迟等效验证。
- 不声称 best-by-tau 排序是全局规律；它只覆盖当前四相派生模型、当前目标函数、当前离散标签集和 `0.5/1/2/5 us` 延迟上下文。
- 不声称 `iqcot_ai_supervisor_regressor_baseline.py` 已经证明 AI/回归器稳定优于零延迟目标表；R022 只支持可解释监督层显著优于固定斜率基线，并在 leave-one-tau-out 中给出边际延迟特征收益。
- 不声称 `iqcot_ref_slew_continuous_landscape.py` 的局部二次候选已经经过开关级验证；它只给出下一轮细扫建议和 near-optimal/safe band。
- 不声称 `iqcot_deployable_risk_proxy.py` 已经完成硬件安全验证；R026 是基于已完成网格的离线 proxy 设计与策略重放。
- 不声称 R028 的 guarded candidate 已经泛化；它是由 R027 priority 压力点重标定得到的下一轮验证候选。
- 不声称 R029 已经证明最终部署策略；R029 只给出 held-out 局部边界和 near0A guard 修正。
- 不声称 R030 的 `0.000` known-context regret 证明最终部署策略；它是 R027/R029 局部证据合成的一致性检查。
- 不声称 R030 dense-anchor challenge 证明 dense-anchor 全局最优或 proxy 已无价值；它只说明当前 proxy 在 `20A/score_settle005` 等分歧上下文中需要更强 `B_epsilon^sw` 约束。
- 不声称 R031 tightened projection 已经泛化；它是基于 R030 challenge 的校准候选，必须经过最小 held-out 派生 Simulink 矩阵检查。
- 不声称 delay-aware AI 在所有延迟下都更优。
- 不把 event-domain surrogate 当成开关级 Simulink 或硬件验证。

## Open Risks

- 需要把当前离散候选策略 score 回归器继续升级为连续 `T_slew` 动作或神经网络 AI-in-the-loop Simulink 验证，而不是停留在离散查表集合。
- 需要研究连续 `T_slew` 动作和安全投影，而不是只在 `30/50/60/80 us` 等标签之间选择。
- 需要将 R031 held-out 后的 delay-aware band 从规则表升级为短时事件 predictor 或轻量回归器输出的 score/risk 分布，再由更保守的 `B_epsilon^sw` 投影。
- 需要继续检验 `38-58us` 中间带在更宽目标函数和扰动条件下是否保持局部价值。
- 需要在硬件或 HIL 中验证检测延迟、量化和参数提交延迟。
- 需要将外环补偿器状态更完整地纳入 PIS-IEK 状态空间。
## R032 Addition: short-horizon risk interface

R032 把 R031 的 delay-aware local band 进一步写成 PIS-IEK 监督层接口，而不是新的内环控制律：

```text
q_phi(z_k, T_slew, tau_AI) -> candidate score/ranking
r_hat(z_k, T_slew, tau_AI, recent_phase_state)
  -> [skip risk, settling risk, phase-spacing risk]
T_slew,plant = Proj_{B_epsilon^sw}(T_slew,candidate)
```

这里 `z_k` 至少包含 target/load-drop、objective weight、`tau_AI`、候选 `T_slew`、dense fallback identity，以及可部署时能短时估计的 phase-spacing/skip 状态。R032 的后处理表明，已知上下文拟合投影可以把 R031 证据组织成 `30/33us`、`80us fallback`、`38/50/58us` 等局部带，但 leave-one-tau nearest-neighbor stress 的 mean regret 为 `0.589`，说明该接口仍需要真正的短时风险预测或后续派生 Simulink 验证，而不能退化为简单查表插值。
## R033 Addition: switching-calibrated delay-band refinement

R033 将 R032 的 `B_epsilon^sw` 规则放入 `31` 行派生 Simulink delayed-reference 验证中。新增信息是：安全投影边界并非只随 `tau_AI` 单调平移，而会在 skip/reentry 和 settling 模式边界处出现窄的过渡口袋。例如 `20A/score_settle005` 在 `tau_AI=1.5 us` 时支持 `50 us`，但在 `0.75 us` 和 `3 us` 时仍回到 `30 us` fallback。这说明 PIS-IEK 小信号模型用于 AI 监督层时，`r_hat` 至少要预测短时 skip/settling 风险，而不能只做 `tau_AI` 近邻插值。
## R034 Addition: deployable risk projection interface

R034 将 R033 的边界修正整理为可部署风格的
`q_phi/r_hat/B_epsilon^sw` 接口。其关键不是把 `T_slew` 当作随
`tau_AI` 平滑变化的回归量，而是在事件域小信号坐标中显式保留
skip、settling 和相位风险。`20A/score_settle005` 的 `50us`
transition pocket 被写成需要进一步验证的局部安全投影口袋；`66us`
仍为 blocked large-jump candidate。
## R034 Partial Validation Addition: moving transition ridge

R034 的 `tau_AI=1.25/1.75us` 派生 Simulink 细扫显示，`20A/score_settle005`
的过渡口袋不是固定 `50us`，而更像随延迟移动的局部 ridge：
`1.25us -> 46us`、`1.5us -> 50us`、`1.75us -> 54us`。这进一步说明
PIS-IEK 给 AI 监督层提供的是事件模式边界与风险投影结构，而不是一个可被简单
线性插值替代的光滑参数面。
## R034 Full Validation Addition: folded transition band

R034 完整 transition-pocket 验证显示，`20A/score_settle005` 的局部最优候选不是固定
`50us`，也不是单调随 `tau_AI` 增大的 ridge，而是 folded transition band：
`38 -> 46 -> 50 -> 54 -> 46us`。该现象对应 PIS-IEK 中的混合事件边界：
短延迟侧由 skip 风险限制长斜率，长延迟侧由 settling 风险限制长斜率。

## R035 Addition: dense-inclusive folded-band projection

R035 将上述 folded transition band 进一步降级为可部署监督层接口。严格说，`38 -> 46 -> 50 -> 54 -> 46us` 是 R034 transition-candidate set 内的最佳序列，而不是完整 plant commit 策略。部署时应使用

```text
q_phi(z_k,T_slew,tau_AI) -> candidate score/ranking
r_hat(z_k,T_slew,tau_AI,recent_event_state)
  -> [skip risk, settling risk, phase-spacing risk]
T_slew,plant = Proj_{B_epsilon^sw}(candidate; T_dense, r_hat, tau_AI)
```

其中 `T_dense` 是强基线 fallback。R035 的证据整合显示，`tau_AI=2us` 时 R034 transition probe 内部最佳为 `46us`，但 R031 dense-inclusive 比较仍支持 plant 侧回到 `30us` fallback。因此 PIS-IEK 对 AI 的建模价值应写成“候选生成和风险投影”，不是“直接回归一个最终最优 `T_slew`”。这也给小信号模型创新增加了更清晰的工程闭环：event-domain Jacobian 提供状态与风险坐标，短时 predictor 提供 `r_hat`，开关级负样本和 held-out 样本不断收紧 `B_epsilon^sw`。
<!-- R036_DENSE_PAIR_BOUNDARY -->

### R036 dense-paired boundary and `r_hat` labels

R036 adds two derived-Simulink dense fallback rows at `tau_AI=1.25/1.75us`.
They show that the folded probes `46/54us` outperform `30us` fallback in the
current `20A/score_settle005` objective, mainly by avoiding the dense fallback
skip event and reducing phase-spacing dispersion.  In the PIS-IEK interface,
this supports a short-horizon risk predictor view:

```text
r_hat(z_k,T_slew,tau_AI,recent_event_state)
  -> [skip_risk, settling_risk, phase_risk]
T_slew,plant = Proj_B(T_slew,candidate; r_hat, T_dense)
```

The labels in `iqcot_r036_short_horizon_rhat_training_view.csv` are derived
from switching replay and are not assumed to be directly available online.
<!-- R037_SHORT_HORIZON_RHAT -->

### R037 short-horizon `r_hat` predictor prototype

**Final R037 sync.** R037 further turns the posterior quantities
`skip_count_est`, `settle_time_us`, and phase-spacing dispersion into
short-horizon risk labels for a deployable-style supervisor interface.  The
predictor input is restricted to context and candidate features that can be
known before committing the plant-side reference slope:

```text
z_k = [target_load_A, load_drop_norm, alpha_settle, tau_AI, delay_events,
       T_slew, T_slew - T_dense, T_slew - T_qphi_center,
       recent skip/phase/settling proxies]
r_hat(z_k,T_slew,tau_AI) = [r_skip, r_settle, r_phase]
T_slew,plant = Proj_{B_epsilon^sw}(T_slew,candidate; r_hat,T_dense)
```

On the current `20A/score_settle005` local derived-model evidence, dense
fallback has mean regret `1.116`, the folded `q_phi` prior has `0.020`, and the
R037 representative projection has `0.000` after the dense-inclusive foldback
guard keeps `30us` at `tau_AI=2us`.  The posterior safe upper-bound under the
same risk gate is `0.054`, and the leave-one-delay gate still rejects the
observed oracle in `1` context.  Therefore R037 is an interface and calibration
prototype, not hardware validation, global `T_slew` optimality, or a
generalizable AI-controller proof.

R037将`skip_count_est/settle_time_us/phase_std`从后验评价量进一步降级为短时风险预测标签：

```text
z_k = [target_load_A, load_drop_norm, alpha_settle, tau_AI, delay_events,
       T_slew, T_slew - T_dense, T_slew - T_qphi_center]
r_hat(z_k,T_slew,tau_AI) = [r_skip, r_settle, r_phase]
T_slew,plant = Proj_{B_epsilon^sw}(T_slew,candidate; r_hat,T_dense)
```

该接口的价值不是替代IQCOT内环，而是把R036暴露的dense fallback skip风险和R034暴露的长斜率settling风险写成可校准、可继续验证的投影边界。

<!-- R038_MINIMAL_EXTRAPOLATION_VALIDATION -->

### R038 minimal extrapolation validation

R038 closes the first small validation loop around the R037 risk interface by
running all `9` planned derived-Simulink delayed-reference cases.  In PIS-IEK
terms, this is a local boundary perturbation test of
`Proj_{B_epsilon^sw}`:

```text
T_slew,candidate in {42,44,46,48,52,54,56} us
tau_AI in {1.25,1.5,1.75,2.0} us
```

The result keeps the already validated local anchors `46us@1.25us`,
`50us@1.5us`, and `54us@1.75us`.  At `tau_AI=2us`, however, the new `44/48us`
probes are near-tied with `30us`, and `48us` is lower by about `0.020` score.
The model implication is not a new point optimum; it is that the foldback rule
should be written as a local near-tie band:

```text
B_epsilon^sw(20A, score_settle005, tau_AI≈2us)
  = {30, 44, 48 us} with dense fallback retained.
```

This remains derived-Simulink evidence, not hardware validation or global
optimality.

## R039 Addition: PR-ECB large-signal boundary coupling

R039 adds the first executable coupling between the PIS-IEK branch and a large-signal first-peak boundary. The PR-ECB input is the load-step instant state, especially Vout, iL1..iL4, high-side gate state, remaining high-side on-time, L, Cout, and ESR. Its output is not a small-signal Jacobian term; it is a conservative first-peak risk feature r_E.

For the current 40A->20A derived-model sweep, the same load-step instant state appears in all five delayed-reference cases. PR-ECB estimates 4.350 mV from the energy bound and 3.903 mV from charge+ESR, while the derived Simulink first peak is 2.235 mV. This supports using PR-ECB as a safety-bound generator:

text form:
  r_E = Delta V_pk_pred / Delta V_allow
  supervisory action = projection(candidate T_slew, r_hat, r_E, dense fallback)

The important modeling separation is that PR-ECB gates first-peak risk before the delayed AI action can affect the plant, while PIS-IEK remains the event-to-event recovery model after the peak-forming interval.
