# IQCOT PR-ECB + PIS-IEK Unified Theory Derivation

## Target

本文推导一个用于四相数字 IQCOT Buck / VRM 的大信号模型与小信号模型联合理论框架。

目标不是把大切载第一峰强行写进一个小信号 Jacobian，也不是让 PR-ECB 替代 PIS-IEK。更严谨的目标是：

1. 用 PR-ECB, Phase-Resolved Energy-Charge Boundary, 描述负载突降后第一电压峰的相分辨大信号风险边界。
2. 用 PIS-IEK, Phase-Indexed Saltation Integral Event Kernel, 描述第一峰之后 normal / quasi-normal 区域内的事件恢复、相位恢复、均流恢复和延迟监督层参数调度。
3. 用一个共同的混合映射把两者连接起来，使 AI 监督层只调度低维参数，例如 T_slew、Lambda_diff 限幅、Ton_diff 限幅，而不直接控制 gate。
4. 给出理论可行性条件、连接公式、可验证命题和边界声明。

输出文件定位：论文理论草稿 / 内部推导包，可继续拆成论文章节或附录。

## Status

COHERENT AFTER REFRAMING / EXTRA ASSUMPTION

原始问题如果理解为：

“能否用同一个小信号模型同时精确预测大切载第一峰和后续事件恢复？”

则答案是否定的。大切载第一峰由电感剩余能量、输出电容电荷、ESR、电感相位状态、剩余 on-time 和负载阶跃时刻共同决定，属于大信号瞬态边界问题。PIS-IEK 是事件域小信号 / 混合事件恢复模型，不应单独承担第一峰精确预测。

重构后的可行目标是：

“建立一个分段混合理论：PR-ECB 给出第一峰风险边界和安全特征 r_E；PIS-IEK 给出峰后事件恢复与执行量通道；监督层用 r_E 和 PIS-IEK 风险共同约束低维动作投影。”

在这个重构目标下，推导是自洽的。

## Invariant Object

顶层不变量对象不是某一个 T_slew，也不是单独的第一峰值，而是从负载阶跃时刻到恢复窗口末端的混合安全-性能映射：

$$
\mathcal H:
(x_0, I_{\mathrm{old}}, I_{\mathrm{new}}, \chi_0, a_{\le 0})
\mapsto
(r_E, x_{k_h}, m_{k_h}, y_{\mathrm{rec}})
$$

其中：

- x_0 是切载瞬间的连续状态。
- I_old 和 I_new 是负载阶跃前后电流。
- chi_0 是切载瞬间的相位 / gate / remaining on-time 离散状态。
- a_{\le 0} 是已经提交或延迟队列中的监督层动作。
- r_E 是 PR-ECB 给出的第一峰风险特征。
- x_{k_h} 是大信号第一峰结束或 reentry 后交给 PIS-IEK 的事件域状态。
- m_{k_h} 是交接时的模式，属于 normal, skip, reentry, saturation 等。
- y_rec 是峰后恢复性能观测，包括 settle time、phase spacing、current imbalance、skip count 等。

这个对象允许第一峰和峰后恢复使用不同模型，同时仍属于同一条理论线。

## Assumptions

### A1. 拓扑与控制结构

研究对象是四相交错同步 Buck / VRM，内环为数字 IQCOT：

$$
V_o / area\ event
\rightarrow comparator
\rightarrow phase\ scheduler
\rightarrow COT\ cells
\rightarrow gate\ drivers
\rightarrow power\ stage
$$

AI 只作为慢速监督层，输出低维参数：

$$
a_k =
[T_{\mathrm{slew}}, \Delta\Lambda_{\mathrm{diff}}^{\max},
 \Delta T_{\mathrm{on,diff}}^{\max}, \ldots]
$$

AI 不直接输出 MOSFET gate，不改变 phase scheduler 的基本轮转逻辑。

### A2. 时间分段

令负载阶跃发生在 t_0。理论上分成两个窗口：

1. 大信号第一峰窗口 E：

$$
\mathcal I_E=[t_0,t_h]
$$

t_h 可选为第一峰时刻 t_pk、第一次 reentry 后的事件时刻，或 t_pk 加一个短 guard window。

2. 峰后事件恢复窗口 S：

$$
\mathcal I_S=[t_h,t_f]
$$

在该窗口内，事件触发重新进入 normal / quasi-normal 区域时，可以使用 PIS-IEK 的局部线性化或分模式线性化。

### A3. PIS-IEK 横截条件

对于 normal-mode 事件面：

$$
g_{m,p}(x,u,I_o,T)=0
$$

需要：

$$
g_T = \frac{\partial g}{\partial T} \ne 0
$$

若 g_T 接近 0，或事件由 blanking、current limit、saturation、skip 逻辑主导，则不使用同一个 normal-mode Jacobian，而切换模式 m。

### A4. PR-ECB 不要求小扰动

PR-ECB 在第一峰窗口使用电荷守恒、能量边界和相分辨电感轨迹。它不是 PIS-IEK 的线性化结果。

### A5. 延迟监督层

AI 动作存在推理和提交延迟 tau_AI。若事件平均间隔为 T_e，则事件域延迟近似为：

$$
d=\left\lceil\frac{\tau_{AI}}{T_e}\right\rceil
$$

plant 实际看到的动作是已经提交的滞后动作：

$$
a_k^{plant}=a_{k-d}
$$

### A6. 安全投影

AI 候选动作必须经过安全投影：

$$
a_k^{safe} = \Pi_{\mathcal U(x_k,r_E,r_{IEK})}(a_k^{cand})
$$

其中约束集包含第一峰风险、phase spacing、current imbalance、skip risk 等。

## Notation

### Continuous variables

- v_o(t): 输出端口电压。
- v_C(t): 输出电容理想电压，不含 ESR 瞬时压降。
- i_{Li}(t): 第 i 相电感电流，i=1,2,3,4。
- I_o(t): 负载电流。
- C_o: 输出电容。
- R_C: 输出电容 ESR。
- L_i: 第 i 相电感。
- r_{Li}: 第 i 相 DCR。
- q_{Hi}(t): 第 i 相 high-side gate 状态。
- q_{Li}(t): 第 i 相 low-side gate 状态。

### Event-domain variables

- t_k: 第 k 个 IQCOT 事件时刻。
- x_k: 第 k 个事件处的事件域状态。
- p_k: 当前导通相索引。
- q_k: 下一触发相索引。
- T_k = t_{k+1}-t_k: 事件间隔或 off-time。
- Lambda_i: 第 i 相面积阈值。
- Ton_i: 第 i 相 on-time。
- m_k: 事件模式，normal、skip、reentry 或 saturation。
- u_k: 低维执行量向量。
- a_k: AI 监督层动作。

### Risk and performance variables

- Delta V_pk: 第一峰幅值。
- Delta V_allow: 允许的第一峰幅值。
- r_E = Delta V_pk_pred / Delta V_allow: 大信号第一峰风险。
- r_IEK: PIS-IEK 预测或后处理得到的峰后事件恢复风险。
- phi_std: 相位间隔标准差。
- i_m2: 相电流差模投影。
- S_skip: skip count 或 skip 风险指标。

## Derivation Strategy

推导采用 “大信号边界映射 -> 交接状态 -> 小信号事件映射 -> 安全投影” 的策略。

1. 从输出电容电荷守恒和电感能量出发，推导 PR-ECB 第一峰边界。
2. 把 PR-ECB 输出写成风险特征 r_E 和交接状态 x_{k_h}。
3. 从 IQCOT 面积事件出发，推导 PIS-IEK normal-mode 事件 Jacobian。
4. 把 skip / reentry 写成模式切换，而不是硬塞进同一个 Jacobian。
5. 把 AI 延迟写成事件域动作滞后。
6. 构造联合安全投影，使 r_E 约束第一峰，r_IEK 约束峰后恢复。
7. 给出可验证命题：何时两模型可以串联、何时不能串联、何时 T_slew 不影响第一峰。

## Derivation Map

1. PR-ECB target:
   - 输入：x_0、chi_0、I_old、I_new。
   - 输出：Delta V_pk_pred、t_pk_pred、r_E、x_h。
   - 使用：电荷守恒、相分辨电感轨迹、能量上界。
   - 近似进入点：piecewise-linear 电感轨迹、ESR 近似、remaining on-time 估计。

2. PIS-IEK target:
   - 输入：x_{k_h}、m_{k_h}、u_k^{plant}、I_o。
   - 输出：事件等待时间扰动、phase spacing、current imbalance、settling 风险。
   - 使用：面积事件面、移动边界线性化、saltation correction。
   - 近似进入点：normal / quasi-normal 工作点附近一阶线性化。

3. Coupling target:
   - PR-ECB 的 r_E 不进入 PIS-IEK 作为普通小信号状态，而进入安全投影约束集。
   - PR-ECB 的交接状态 x_h 是 PIS-IEK 的初始条件。
   - PIS-IEK 的 r_IEK 与 PR-ECB 的 r_E 共同决定 safe action。

4. Supervisor target:
   - AI candidate action 只给出候选。
   - plant action 是 delay buffer 后的已提交动作。
   - safe action 通过投影约束进入 IQCOT 参数通道。

## Main Derivation

### Step 1. 大信号连续状态与第一峰窗口

在切载瞬间 t_0，定义连续状态：

$$
x_0 =
[v_C(t_0), i_{L1}(t_0), i_{L2}(t_0), i_{L3}(t_0), i_{L4}(t_0), \eta_0]^T
$$

eta_0 表示必要的内部积分器、采样保持和控制器状态。相位 / gate 状态单独记为：

$$
\chi_0 =
[p_0, q_{H1}(t_0),...,q_{H4}(t_0),
q_{L1}(t_0),...,q_{L4}(t_0),
T_{\mathrm{rem},1},...,T_{\mathrm{rem},4}]
$$

其中 T_rem,i 是第 i 相切载瞬间仍可能剩余的 high-side on-time。

切载后负载从 I_old 变为 I_new，且 I_new < I_old。第一峰窗口定义为：

$$
\mathcal I_E = [t_0,t_h]
$$

t_h 可以取为电容电流第一次过零时刻或实际第一峰时刻附近：

$$
t_{pk}=\inf\{t>t_0: i_C(t)=0,\ \dot i_C(t)<0\}
$$

该定义忽略 ESR 动态时与 dv_C/dt=0 等价。

### Step 2. 输出电容电荷恒等式

输出电容电流定义为：

$$
i_C(t)=\sum_{i=1}^{4}i_{Li}(t)-I_o(t)
$$

理想电容电压满足精确恒等式：

$$
C_o[v_C(t)-v_C(t_0)]
=
\int_{t_0}^{t}i_C(\tau)d\tau
$$

若输出端口电压包含 ESR，则：

$$
v_o(t)=v_C(t)+R_C i_C(t)
$$

于是：

$$
\Delta v_o(t)
=
\frac{1}{C_o}\int_{t_0}^{t}i_C(\tau)d\tau
+
R_C[i_C(t)-i_C(t_0^-)]
$$

不同 Simscape / Simulink 测量点可能把 ESR 的瞬时项表示得略有差异，所以 R039 脚本采用了保守的 charge+ESR 近似：

$$
\Delta V_{pk}^{Q+ESR}
\approx
\frac{1}{C_o}\int_{t_0}^{t_{pk}}[i_C(\tau)]_+d\tau
+
R_C[i_C(t_0^+)]_+
$$

这是近似，不是精确等式。其作用是构造一个可校准的第一峰风险上界。

### Step 3. 相分辨电感轨迹

每相电感电流满足大信号分段方程：

$$
\frac{di_{Li}}{dt}=s_i(t)
$$

其中：

$$
s_i(t)=
\begin{cases}
\frac{V_{in}-v_o(t)-r_{Li}i_{Li}(t)}{L_i}, & q_{Hi}=1\\
-\frac{v_o(t)+r_{Li}i_{Li}(t)}{L_i}, & q_{Li}=1\\
0\ \mathrm{or\ DCM\ limited}, & DCM/zero\ current
\end{cases}
$$

因此：

$$
i_{Li}(t)=i_{Li}(t_0)+\int_{t_0}^{t}s_i(\tau)d\tau
$$

若在第一峰短窗口内近似 v_o 和 gate 状态分段常值，则：

$$
i_{Li}(t)
\approx
i_{Li,0}+\sum_{\ell} s_{i,\ell}\Delta t_{\ell}
$$

该近似保留相位状态、gate 状态和 remaining on-time，因此比只用总电流的模型更适合四相交错 Buck。

### Step 4. 第一峰时间的电荷条件

忽略 ESR 瞬时项对峰值时刻的位移，第一峰满足：

$$
\frac{dv_C}{dt}=0
$$

代入电容方程：

$$
\sum_{i=1}^{4}i_{Li}(t_{pk})=I_{\mathrm{new}}
$$

因此，PR-ECB 的电荷型第一峰估计为：

$$
\Delta V_{pk}^{Q}
=
\frac{1}{C_o}
\int_{t_0}^{t_{pk}}
\left[
\sum_{i=1}^{4}i_{Li}(\tau)-I_{\mathrm{new}}
\right]d\tau
$$

当积分被限制在正电容电流区间时：

$$
\Delta V_{pk}^{Q,+}
=
\frac{1}{C_o}
\int_{t_0}^{t_h}
\left[
\sum_{i=1}^{4}i_{Li}(\tau)-I_{\mathrm{new}}
\right]_+d\tau
$$

R039 的 charge+ESR 指标对应这个公式的离散波形实现。

### Step 5. 电感剩余能量上界

切载后，理想均流目标为：

$$
i_{Li,new}=\frac{I_{\mathrm{new}}}{4}
$$

每相多余电感能量定义为：

$$
\Delta E_{Li}^{+}
=
\frac{1}{2}L_i[i_{Li,0}^{2}-i_{Li,new}^{2}]_+
$$

总剩余能量为：

$$
\Delta E_L^{+}
=
\sum_{i=1}^{4}\Delta E_{Li}^{+}
$$

若忽略损耗、负载吸收和额外输入注入，则输出电容能量增长满足近似上界：

$$
\frac{1}{2}C_o[(v_C(t_{pk}))^2-(v_C(t_0))^2]
\le
\Delta E_L^{+}
$$

因此能量型电压边界为：

$$
\Delta V_{pk}^{E}
\le
\sqrt{
v_{C0}^{2}+\frac{2\Delta E_L^{+}}{C_o}
}
-v_{C0}
$$

这一步是边界近似。它不是精确峰值公式，因为真实系统还包含：

1. DCR 与 MOSFET 导通损耗。
2. 负载在第一峰窗口继续吸收能量。
3. active high-side remaining on-time 可能继续注入输入能量。
4. ESR 测量点可能改变端口峰值。
5. dead-time、body diode、Coss、采样和 blanking 影响短时轨迹。

为更保守的扩展，可加入 remaining on-time 输入能量项：

$$
E_{\mathrm{HS,rem}}^{+}
=
\sum_{i:q_{Hi}(t_0)=1}
\int_{t_0}^{t_0+T_{\mathrm{rem},i}}
[V_{in}-v_o(t)]i_{Li}(t)d t
$$

则：

$$
\Delta V_{pk}^{E,rem}
\le
\sqrt{
v_{C0}^{2}+
\frac{2(\Delta E_L^{+}+E_{\mathrm{HS,rem}}^{+})}{C_o}
}
-v_{C0}
$$

R039 当前实现采用未加 remaining-on 输入能量的第一版边界；后续 R040 应校准该项是否需要显式加入。

### Step 6. PR-ECB 风险特征

综合电荷边界和能量边界，定义第一峰预测边界：

$$
\Delta V_{pk}^{pred}
=
\max\{
\Delta V_{pk}^{E},
\Delta V_{pk}^{Q+ESR}
\}
$$

第一峰风险特征为：

$$
r_E=
\frac{\Delta V_{pk}^{pred}}{\Delta V_{allow}}
$$

含义：

- r_E < 1: 当前 PR-ECB 边界低于允许第一峰。
- r_E 接近 1: 第一峰风险接近约束边界，需要保守投影。
- r_E > 1: 候选动作或当前状态在 PR-ECB 边界下不安全，监督层必须降级。

该风险特征不是 T_slew 的全局排序分数。对于 R039 中 tau_AI >= 1.25 us 且第一峰约 0.534 us 的工况，T_slew 尚未影响 plant，所以 r_E 对 46/50/54/30/48 us 候选保持不变。

### Step 7. PR-ECB 到 PIS-IEK 的交接映射

定义 PR-ECB 大信号边界映射：

$$
\Psi_E:
(x_0,\chi_0,I_{\mathrm{old}},I_{\mathrm{new}})
\mapsto
(r_E,x_h,m_h,t_h)
$$

其中 x_h 是交接时刻 t_h 的事件域状态。该映射不要求小扰动。

交接时刻可以按验证目标选择：

1. t_h=t_pk: 第一峰结束即交接。
2. t_h=t_reentry: skip 后恢复连续事件触发时交接。
3. t_h=t_pk+T_guard: 给测量和模式判据留出短 guard window。

交接状态应包含：

$$
x_h =
[v_o(t_h), i_{L1}(t_h),...,i_{L4}(t_h),
\zeta(t_h), \phi(t_h), \xi(t_h)]^T
$$

其中 zeta 可表示面积积分器状态，phi 表示相位间隔状态，xi 表示其他控制器内部状态。

### Step 8. IQCOT 面积事件定义

在 PIS-IEK 窗口，IQCOT 第 k 个事件面定义为：

$$
g_{q_k}(x_k,u_k,I_{o,k},T_k)
=
\int_{0}^{T_k}
h_{q_k}(x_k,u_k,I_{o,k},\tau)d\tau
-
\Lambda_{q_k}
=0
$$

典型面积核为：

$$
h_{q_k}(\tau)=v_c(\tau)-R_i i_{L,q_k}(\tau)
$$

该式是事件定义，不是近似。近似从下一步线性化开始。

### Step 9. 单事件移动边界线性化

在 normal / quasi-normal 工作点附近，对 g=0 做一阶扰动：

$$
g_x\delta x_k+
g_u\delta u_k+
g_I\delta I_{o,k}+
g_T\delta T_k=0
$$

若 g_T 不为 0，则：

$$
\delta T_k
=
-g_T^{-1}
(g_x\delta x_k+g_u\delta u_k+g_I\delta I_{o,k})
$$

该式说明事件等待时间扰动由状态、执行量和负载扰动共同决定。

### Step 10. 状态更新和 saltation correction

事件间状态流写为：

$$
x_{k+1}=F_{p_k}(x_k,u_k,I_{o,k},T_k)
$$

一阶扰动为：

$$
\delta x_{k+1}
=
F_x\delta x_k+
F_u\delta u_k+
F_I\delta I_{o,k}+
F_T\delta T_k
$$

代入 delta T_k：

$$
\delta x_{k+1}
=
\left(F_x-F_Tg_T^{-1}g_x\right)\delta x_k
+
\left(F_u-F_Tg_T^{-1}g_u\right)\delta u_k
+
\left(F_I-F_Tg_T^{-1}g_I\right)\delta I_{o,k}
$$

定义：

$$
A_{p_k}=F_x-F_Tg_T^{-1}g_x
$$

$$
B_{p_k}=F_u-F_Tg_T^{-1}g_u
$$

$$
E_{p_k}=F_I-F_Tg_T^{-1}g_I
$$

得到 normal-mode PIS-IEK 事件模型：

$$
\delta x_{k+1}
=
A_{p_k}\delta x_k+
B_{p_k}\delta u_k+
E_{p_k}\delta I_{o,k}
$$

其中 p_k 使矩阵随四相索引周期变化。

### Step 11. 四相相索引结构

四相索引为：

$$
p_k=k\ \mathrm{mod}\ 4
$$

$$
q_k=(p_k+1)\ \mathrm{mod}\ 4
$$

因此完整周期映射为：

$$
\delta x_{k+4}
=
A_{p_{k+3}}A_{p_{k+2}}A_{p_{k+1}}A_{p_k}\delta x_k
+
\sum_{j=0}^{3}
\left(
\prod_{\ell=j+1}^{3}A_{p_{k+\ell}}
\right)
(B_{p_{k+j}}\delta u_{k+j}+E_{p_{k+j}}\delta I_{o,k+j})
$$

若定义周期 monodromy matrix：

$$
\mathcal A_4=
A_{p_{k+3}}A_{p_{k+2}}A_{p_{k+1}}A_{p_k}
$$

则 local event recovery 的稳定性条件可写为：

$$
\rho(\mathcal A_4)<1
$$

这不是全局稳定性证明，只是 normal-mode 周期工作点附近的局部条件。

### Step 12. 执行量通道分解

监督层不直接给每个 gate，而是约束低维执行量。把执行量分成：

$$
u_k=
[
\Lambda_{cm},
\Lambda_{diff},
Ton_{cm},
Ton_{diff},
I_{\mathrm{ph,ref}},
T_{\mathrm{slew}}
]^T
$$

线性化输出选择为：

$$
y_k=
[
T_k,
\phi_k,
i_{m2,k},
v_{o,k},
S_{skip,k}
]^T
$$

在 normal 区域，去掉离散 skip 计数后有：

$$
\delta y_k
=
C_y\delta x_k+D_y\delta u_k
$$

结合 PIS-IEK：

$$
\delta y_{k+1}
=
C_yA_{p_k}\delta x_k+
(C_yB_{p_k}+D_y)\delta u_k+
C_yE_{p_k}\delta I_{o,k}
$$

定义局部通道矩阵：

$$
J_{yu,p_k}=C_yB_{p_k}+D_y
$$

工程解释：

- Lambda_diff 主要改变事件面和相位节奏。
- Ton_diff 直接改变每相注入能量，主要影响均流和差模电流。
- T_slew 通过 Iph_ref 的时间轨迹影响切载后的恢复速度和 skip/reentry 风险。
- r_E 不应作为普通执行量，而应作为安全约束或风险特征。

### Step 13. skip / reentry 作为模式切换

当事件等待时间、blanking、current limit 或调度逻辑使 normal event map 失效时，引入模式变量：

$$
m_k\in\{normal,skip,reentry,saturation\}
$$

模式化映射为：

$$
x_{k+1}
=
F_{m_k,p_k}(x_k,u_k,I_{o,k},T_k)
$$

对应线性化为：

$$
\delta x_{k+1}
=
A_{m_k,p_k}\delta x_k+
B_{m_k,p_k}\delta u_k+
E_{m_k,p_k}\delta I_{o,k}
$$

但要注意：skip 不是一个普通小扰动增益。它是离散事件序列结构变化。因此：

- normal 模式可以用 PIS-IEK Jacobian。
- skip/reentry 应使用分段映射或样本化风险模型。
- 不能把 skip count 当成同一 normal Jacobian 的连续输出并宣称精确。

### Step 14. AI 延迟进入 PIS-IEK

令 AI 候选动作在监督层时间索引 n 生成：

$$
a_n^{cand}=\pi_{\theta}(z_n)
$$

经过安全投影：

$$
a_n^{safe}=\Pi_{\mathcal U}(a_n^{cand})
$$

经过延迟队列后，plant 在事件 k 看到：

$$
u_k^{plant}=a_{n-d}^{safe}
$$

或更一般地：

$$
u_k^{plant}=Q_{\tau}(a_{\le n}^{safe},t_k)
$$

其中 Q_tau 表示按实际提交时间和采样保持得到的动作序列。

于是 PIS-IEK 变成延迟感知形式：

$$
\delta x_{k+1}
=
A_{m_k,p_k}\delta x_k+
B_{m_k,p_k}\delta u_k^{plant}+
E_{m_k,p_k}\delta I_{o,k}
$$

### Step 15. 参考斜率 T_slew 的动作路径

对于负载从 I_old 到 I_new 的切载，per-phase reference 为：

$$
I_{\mathrm{ph},0}=\frac{I_{\mathrm{old}}}{4}
$$

$$
I_{\mathrm{ph},1}=\frac{I_{\mathrm{new}}}{4}
$$

若动作提交时刻为：

$$
t_s=t_0+\tau_{AI}
$$

则：

$$
I_{\mathrm{ph,ref}}(t)=
\begin{cases}
I_{\mathrm{ph},0}, & t<t_s\\
I_{\mathrm{ph},0}+
\frac{I_{\mathrm{ph},1}-I_{\mathrm{ph},0}}{T_{\mathrm{slew}}}(t-t_s),
& t_s\le t<t_s+T_{\mathrm{slew}}\\
I_{\mathrm{ph},1}, & t\ge t_s+T_{\mathrm{slew}}
\end{cases}
$$

如果：

$$
t_{pk}<t_s
$$

则第一峰窗口内：

$$
\frac{\partial \Delta V_{pk}}{\partial T_{\mathrm{slew}}}\approx 0
$$

这是 R039 中 46/50/54/30/48 us delayed-reference 工况第一峰完全相同的理论解释。

如果：

$$
t_s\le t_{pk}
$$

则 T_slew 会进入第一峰窗口的电感轨迹和控制器状态，PR-ECB 必须把 Iph_ref(t;T_slew) 或由它引起的 gate / event 变化纳入 chi(t)，不能仍假定第一峰与 T_slew 无关。

### Step 16. 联合安全约束集

定义 PR-ECB 风险：

$$
r_E=\frac{\Delta V_{pk}^{pred}}{\Delta V_{allow}}
$$

定义 PIS-IEK 峰后风险向量：

$$
r_{IEK}=
[
r_{\phi},
r_i,
r_{skip},
r_{settle}
]^T
$$

例如：

$$
r_{\phi}=\frac{\phi_{std}^{pred}}{\Phi_{max}}
$$

$$
r_i=\frac{|i_{m2}^{pred}|}{I_{m2,max}}
$$

$$
r_{skip}=\frac{S_{skip}^{pred}}{S_{max}}
$$

联合约束集：

$$
\mathcal U(x,r_E,r_{IEK})
=
\{
u:
r_E(u,x)\le 1,\ 
r_{\phi}(u,x)\le 1,\
r_i(u,x)\le 1,\
r_{skip}(u,x)\le 1
\}
$$

安全投影：

$$
u^{safe}
=
\arg\min_{\bar u\in\mathcal U(x,r_E,r_{IEK})}
\|\bar u-u^{cand}\|_W^2
$$

其中 W 是动作权重矩阵，用来表达 T_slew、Lambda_diff、Ton_diff 的不同优先级和动作代价。

### Step 17. 联合模型的整体表达

综合上述，完整模型可写为：

$$
(r_E,x_h,m_h,t_h)=
\Psi_E(x_0,\chi_0,I_{\mathrm{old}},I_{\mathrm{new}})
$$

$$
u_k^{safe}
=
\Pi_{\mathcal U(x_k,r_E,r_{IEK,k})}
(\pi_{\theta}(z_k))
$$

$$
u_k^{plant}=Q_{\tau}(u_{\le k}^{safe})
$$

$$
x_{k+1}
=
F_{m_k,p_k}(x_k,u_k^{plant},I_{o,k},T_k)
$$

其一阶 PIS-IEK 恢复模型为：

$$
\delta x_{k+1}
=
A_{m_k,p_k}\delta x_k+
B_{m_k,p_k}\delta u_k^{plant}+
E_{m_k,p_k}\delta I_{o,k}
$$

该组合表达给出了大信号与小信号模型的严格连接方式：PR-ECB 不是 A 矩阵的一项，而是交接映射和约束生成器；PIS-IEK 不是第一峰的万能预测器，而是交接之后的局部事件恢复模型。

## Propositions

### Proposition 1. 第一峰与 T_slew 的延迟不敏感条件

若在第一峰窗口内监督层参考动作尚未作用于 plant，即：

$$
t_{pk}<t_0+\tau_{AI}
$$

并且切载前状态 x_0、相位状态 chi_0 与候选 T_slew 无关，则：

$$
\Delta V_{pk}(T_{\mathrm{slew},1})
=
\Delta V_{pk}(T_{\mathrm{slew},2})
$$

在同一 PR-ECB 近似下也有：

$$
r_E(T_{\mathrm{slew},1})
=
r_E(T_{\mathrm{slew},2})
$$

证明思路：第一峰窗口内 Iph_ref(t) 对所有候选 T_slew 相同，且 gate / phase 状态由同一初始状态和同一内环演化决定。因此 i_Li(t)、i_C(t) 和 PR-ECB 积分项相同。R039 的 5 行结果正是该命题的派生 Simulink 实例。

限制：若 tau_AI 很小，或 T_slew 候选改变了切载前稳态状态，该命题不成立。

### Proposition 2. PR-ECB 与 PIS-IEK 的串联可行条件

若存在交接时刻 t_h，使得：

1. PR-ECB 能从 x_0、chi_0 得到有限的 r_E 和 x_h。
2. t_h 后事件面恢复横截，即 g_T 不接近 0。
3. t_h 后模式 m_k 可分为 normal / reentry / skip 等有限集合。
4. 对每个被使用的 normal / quasi-normal 模式，PIS-IEK 的局部线性化存在。

则联合模型：

$$
\mathcal H = \mathcal P_{IEK}\circ \Psi_E
$$

在局部意义下自洽。

证明思路：PR-ECB 负责连续大信号窗口到交接状态的映射，不要求小扰动；PIS-IEK 从交接事件状态开始，只在横截事件面附近线性化。因此两者的适用区域不重叠冲突，而是前后串联。

限制：如果系统长时间不 reentry，或 first peak 后仍处在强饱和 / current limit 主导区域，则不能立即使用 normal-mode PIS-IEK，需要保留 mode map 或仿真证据。

### Proposition 3. 安全性与局部恢复的分解证书

若：

$$
r_E \le 1-\epsilon_E
$$

并且对峰后 PIS-IEK 周期映射：

$$
\rho(\mathcal A_4)\le 1-\epsilon_S
$$

同时安全投影保证：

$$
u_k^{plant}\in \mathcal U(x_k,r_E,r_{IEK,k})
$$

则可得到一个分解式局部证书：

1. 第一峰满足 PR-ECB 边界下的安全裕度。
2. 峰后 normal / quasi-normal 事件恢复在局部线性化意义下收敛。
3. 监督层动作不会越过已建模的风险约束。

该命题不是硬件安全证明，因为 r_E 和 A_4 都来自模型与局部验证；它是可验证仿真 / 后处理证书的理论结构。

## Remarks and Interpretation

### 1. 为什么不能把大信号第一峰塞进 PIS-IEK Jacobian

PIS-IEK 的 Jacobian 来自事件面横截和局部一阶扰动：

$$
\delta x_{k+1}=A\delta x_k+B\delta u_k+E\delta I_o
$$

大切载第一峰通常发生在事件序列重排、skip 或 delayed action 生效之前，且幅值由能量和电荷积分主导。若用同一个 A 矩阵预测第一峰，会把大信号能量转移误写成局部事件恢复增益，理论对象发生切换。

### 2. PR-ECB 的创新位置

PR-ECB 的作用是把四相电感电流、相位状态和 remaining on-time 显式放进第一峰风险边界。相比只用总电流的估计，它能解释：同样的 I_old->I_new，因为切载相位不同，第一峰风险可能不同。

### 3. PIS-IEK 的创新位置

PIS-IEK 的作用是把 IQCOT 面积事件、phase index、saltation correction、Lambda/Ton 执行量通道和 AI 延迟放进同一个事件域恢复框架。它解释的是峰后事件节奏、phase spacing、current sharing 和 settling，而不是单独预测大切载第一峰。

### 4. AI 监督层的正确接口

AI 监督层输入应包含：

$$
z_k=
[\Delta I_{load}, \alpha_{settle}, \tau_{AI}, d,
\phi_{std}, i_{m2}, skip\ flag, reentry\ flag, r_E, r_{IEK}]
$$

输出是候选低维动作：

$$
a_k^{cand}=
[T_{\mathrm{slew}},
\Delta\Lambda_{diff}^{max},
\Delta Ton_{diff}^{max}]
$$

最终进入 plant 的是：

$$
a_k^{plant}=Q_{\tau}(\Pi_{\mathcal U}(a_k^{cand}))
$$

而不是 AI 直接输出 gate。

### 5. R039 对理论的支撑

R039 的结果：

- energy estimate: 4.349633 mV
- charge+ESR estimate: 3.903338 mV
- actual derived-Simulink first peak: 2.235008 mV
- r_E with 10 mV allowance: 0.434963
- first peak invariant across delayed T_slew candidates

这些结果支持 Proposition 1 的延迟不敏感解释，并支持把 PR-ECB 写成第一峰风险边界。但 R039 只覆盖一个负载幅度和一个切载相位附近，不能作为全局结论。

## Boundaries and Non-Claims

1. 不声称 PR-ECB 是精确第一峰公式。它是可校准的相分辨风险边界。
2. 不声称 PIS-IEK 精确预测所有大切载第一峰。PIS-IEK 负责峰后事件恢复。
3. 不声称任一 T_slew 是全局最优。T_slew 是目标敏感和上下文敏感调度变量。
4. 不声称 AI 替代 IQCOT 内环。AI 只调度低维监督参数。
5. 不声称 derived Simulink、dry-run、table-in-loop 或后处理等价于硬件验证。
6. 不把 skip/reentry 当成同一 normal Jacobian 的连续小扰动输出。
7. 不把 R039 的 0.435 风险数值推广到所有负载幅度、相位和硬件参数。

## Open Risks

1. PR-ECB energy bound 当前未显式加入 remaining high-side on-time 输入能量项。R040 应通过切载相位扫描判断是否需要加入 E_HS,rem。
2. charge+ESR 公式依赖测量点定义。若 Simulink 的 Vout 测量点已包含或不包含 ESR 瞬时压降，需校准对应项。
3. t_h 的交接定义会影响 PIS-IEK 初始状态。需要比较 t_pk、reentry event 和 t_pk+guard 三种定义。
4. PIS-IEK normal-mode 稳定性条件 rho(A_4)<1 需要用派生模型扰动验证，而不能只写理论。
5. r_IEK 风险预测目前来自局部后处理和有限样本，不是独立泛化证明。
6. 若 tau_AI 足够小，使监督层动作进入第一峰窗口，则 Proposition 1 不再成立，PR-ECB 必须显式包含动作轨迹。
7. 负载上跳和负载突降的第一峰机制不同，本文推导主要针对 cut-load, I_new<I_old。

## Verification Checklist

- Target explicit: yes, combine PR-ECB first-peak boundary with PIS-IEK post-peak recovery.
- Invariant object stable: yes, hybrid safety-performance mapping H.
- Assumptions stated: yes, topology, timing, transversality, delay, projection.
- Exact identities separated: capacitor charge identity and event surface definition.
- Approximations marked: energy bound, charge+ESR, piecewise-linear inductor trajectory, local Jacobian.
- Propositions bounded: yes, all propositions have conditions and limitations.
- Non-claims stated: yes.
- Next validation path identified: R040 phase and load-drop calibration.
