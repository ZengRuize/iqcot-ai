# 四相数字 IQCOT 的 PIS-IEK 小信号模型详细推导

## 1. 建模对象与创新边界

本文的小信号模型不是重新提出 IQCOT 控制律，也不是重新提出 COT sampled-data 或 saltation/Poincare 数学工具。模型创新在于：面向四相数字 IQCOT Buck，将面积积分触发、相索引 `phase_idx`、积分器 reset、逐相面积阈值 `Lambda_i`、逐相导通时间修正 `Ton_i`、检测延迟和数字量化统一写入 event-to-event Jacobian。

为避免过度泛化，以下推导默认工作区为：

- 四相同步 Buck，`N=4`；
- 低占空比、非重叠工作点，即 `D < 1/4`；
- phase scheduler 固定轮转；
- 每次事件只允许一个相进入 on-time；
- 面积事件在当前 on-time 后的 off/wait 区间内触发；
- 功率级可先按分段仿射模型推导，MOSFET 非线性、dead-time、PCB 寄生作为后续高保真扩展。

四相调度定义为：

```math
p_k = k \bmod 4,\qquad q_k = (p_k+1)\bmod 4.
```

其中 `p_k` 是第 `k` 次事件后当前导通相，`q_k` 是下一次面积事件所对应的触发相。

## 2. 四相 Buck 分段状态方程

取一般状态向量

```math
x = [i_{L1},i_{L2},i_{L3},i_{L4},v_o,x_c,\eta_1,\eta_2,\eta_3,\eta_4]^T.
```

其中 `x_c` 可表示外环补偿器状态，`\eta_i` 可表示数字积分器或面积积分器状态。若只分析功率级和面积事件，可先用简化状态

```math
x = [i_{L1},i_{L2},i_{L3},i_{L4},v_o]^T.
```

对同步 Buck，第 `i` 相开关函数为 `s_i\in{0,1}`。忽略高阶非线性时：

```math
L_i \frac{di_{Li}}{dt}
= s_i V_{in}-v_o-r_{Li}i_{Li},
```

```math
C_o\frac{dv_o}{dt}
= \sum_{i=1}^4 i_{Li}-\frac{v_o}{R_{load}}.
```

写成分段仿射形式：

```math
\dot{x}=A_{\sigma}x+B_{\sigma}u+b_{\sigma},
```

其中开关状态 `\sigma` 由四维开关向量

```math
s=[s_1,s_2,s_3,s_4]^T
```

决定。对本文非重叠四相模型，每个事件包含两段：

1. 当前相 `p_k` 导通：

```math
s=e_{p_k},\qquad 0\le t<T_{on,p_k}.
```

2. 全部高边关闭的 wait/off 段：

```math
s=0,\qquad 0\le \tau<T_k.
```

这里 `T_k` 是第 `k` 个事件的等待时间，也是 IQCOT 面积事件线性化的核心未知量。

## 3. IQCOT 面积事件

Bari IQCOT 的核心事件量可写成：

```math
h_i(t)=v_c(t)-R_i i_{Li}(t).
```

对应面积事件为：

```math
\int_{0}^{T_k}h_{q_k}(x(\tau),u(\tau))\,d\tau-\Lambda_{q_k}=0.
```

本文 Simulink 逐相面积副本采用的工程近似为：

```math
h_i(t)=V_{area,bias}+e_v(t)+R_{i,area}(I_{ph}-i_{Li}(t)).
```

它与原式的局部等效关系是：

```math
v_c(t)\leftrightarrow V_{area,bias}+e_v(t)+R_{i,area}I_{ph},
\qquad
R_i\leftrightarrow R_{i,area}.
```

所以该副本不重新定义 IQCOT，而是在四相数字实现中给出可仿真的逐相面积事件核。

定义第 `k` 个事件面的隐函数：

```math
g_{q_k}(x_k,T_{on,p_k},T_k,\Lambda_{q_k})
=
\int_0^{T_k}
h_{q_k}\left(\phi_0(\tau,x_s),u\right)d\tau
-\Lambda_{q_k}=0.
```

其中 `x_k` 是第 `k` 次事件开始处状态，`x_s` 是当前相导通结束、wait 段开始时的状态：

```math
x_s=\phi_{on,p_k}(T_{on,p_k},x_k).
```

`phi_0` 是 off/wait 段状态流。

## 4. 事件映射

一次完整事件从 `x_k` 到 `x_{k+1}` 的映射为：

```math
x_{k+1}
=
F_{p_k}(x_k,T_{on,p_k},T_k,u_k)
=
\phi_0(T_k,\phi_{on,p_k}(T_{on,p_k},x_k)).
```

面积条件为：

```math
g_{q_k}(x_k,T_{on,p_k},T_k,\Lambda_{q_k},u_k)=0.
```

这就是 PIS-IEK 的最小形式：

```math
x_{k+1}=F_{p_k}(x_k,u_k,T_k),
\qquad
g_{q_k}(x_k,u_k,T_k)=0.
```

其中创新点不是 `F/g` 写法本身，而是 `p_k/q_k` 把四相 scheduler 显式嵌入事件面，使 `phase_idx` 不再是仿真实现细节，而是小信号模型索引。

## 5. 移动边界线性化

对面积事件做一阶扰动。设名义轨道满足：

```math
g_{q_k}(x_k^*,T_{on,p_k}^*,T_k^*,\Lambda_{q_k}^*)=0.
```

小扰动为：

```math
\delta x_k,\quad
\delta T_{on,p_k},\quad
\delta T_k,\quad
\delta \Lambda_{q_k},\quad
\delta u_k.
```

事件函数一阶展开：

```math
\delta g
=
g_x\delta x_k
 +g_{Ton}\delta T_{on,p_k}
 +g_T\delta T_k
 +g_{\Lambda}\delta \Lambda_{q_k}
 +g_u\delta u_k
=0.
```

因为

```math
g_{\Lambda}=-1,
```

并且由 Leibniz 积分上限求导，

```math
g_T
=
h_{q_k}(x_e,u)
\equiv H_{e,k},
```

其中 `x_e=phi_0(T_k,x_s)` 是事件发生时的终点状态。因此：

```math
\delta T_k
=
\frac{
\delta\Lambda_{q_k}
-g_x\delta x_k
-g_{Ton}\delta T_{on,p_k}
-g_u\delta u_k
}{H_{e,k}}.
```

更紧凑地写：

```math
\delta T_k
=
-g_T^{-1}
\left(
g_x\delta x_k
 +g_{Ton}\delta T_{on,p_k}
 +g_{\Lambda}\delta\Lambda_{q_k}
 +g_u\delta u_k
\right).
```

### 5.1 `g_x` 的物理意义

若 off 段线性化状态转移为

```math
\delta x(\tau)=\Phi_0(\tau)\delta x_s,
```

则面积对 wait 段初始状态的导数为：

```math
g_{x_s}
=
\int_0^{T_k}
h_x(\tau)\Phi_0(\tau)d\tau.
```

而

```math
\delta x_s
=
\Phi_{on,p_k}\delta x_k
 +f_{on,p_k}(x_s)\delta T_{on,p_k}.
```

所以：

```math
g_x=g_{x_s}\Phi_{on,p_k},
```

```math
g_{Ton}=g_{x_s}f_{on,p_k}(x_s).
```

这一步非常重要：`g_T=H_e` 只看事件终点，而 `g_x` 保留了整个 wait 积分窗口内的状态记忆。IEK/PIS-IEK 相比 He-only 的增量就在这里。

## 6. 状态更新线性化

对事件映射

```math
x_{k+1}=F_{p_k}(x_k,T_{on,p_k},T_k,u_k)
```

做一阶展开：

```math
\delta x_{k+1}
=
F_x\delta x_k
+F_{Ton}\delta T_{on,p_k}
+F_T\delta T_k
+F_u\delta u_k.
```

代入上一节的 `\delta T_k`：

```math
\delta x_{k+1}
=
\left(F_x-F_Tg_T^{-1}g_x\right)\delta x_k
+
\left(F_{Ton}-F_Tg_T^{-1}g_{Ton}\right)\delta T_{on,p_k}
+
\left(-F_Tg_T^{-1}g_{\Lambda}\right)\delta\Lambda_{q_k}
+
\left(F_u-F_Tg_T^{-1}g_u\right)\delta u_k.
```

由于 `g_\Lambda=-1`，面积阈值输入项为：

```math
B_{\Lambda,k}=F_Tg_T^{-1}.
```

于是第 `k` 个相索引事件的小信号模型可写为：

```math
\delta x_{k+1}
=
A_{p_k}\delta x_k
+B_{\Lambda,p_k}\delta\Lambda
+B_{T,p_k}\delta T_{on}
+B_{d,p_k}\delta d
+B_{u,p_k}\delta u.
```

其中：

```math
A_{p_k}=F_x-F_Tg_T^{-1}g_x,
```

```math
B_{T,p_k}=F_{Ton}-F_Tg_T^{-1}g_{Ton}.
```

检测延迟 `\delta d_{q_k}` 可视为事件 crossing 后额外 off-time：

```math
\delta T_{actual,k}=\delta T_{cross,k}+\delta d_{q_k}.
```

所以检测延迟进入 wait 输出是直接项，进入状态更新则通过 `F_T\delta d_{q_k}`。

## 7. 局部解耦命题

在固定 scheduler、非重叠四相工作点、事件排序不改变时，第 `k` 个事件面只选择 `q_k` 相面积阈值。因此：

```math
\frac{\partial T_k}{\partial \Lambda_j}=0,\qquad j\ne q_k.
```

并且当前事件的 on-time 只由当前导通相 `p_k` 直接改变，因此：

```math
\frac{\partial T_k}{\partial T_{on,j}}=0,\qquad j\ne p_k.
```

对目标相：

```math
\frac{\partial T_k}{\partial \Lambda_{q_k}}
=
\frac{1}{H_{e,k}},
```

```math
\frac{\partial T_k}{\partial T_{on,p_k}}
=
-\frac{g_{Ton}}{H_{e,k}}.
```

这就是 PIS-IEK 最清楚的相索引结果：`phase_idx` 决定当前 wait 直接看哪个 `Lambda_q`，而 `Ton_p` 通过当前 on-time 改变 wait 段初始状态。

注意：非目标相并不是永远没有影响，而是不出现在同一事件面的直接项中。它们会通过后续状态传播进入下一事件。

## 8. 从 He-only 到 `H_e+K(z)`

若只保留事件终点刚度，则：

```math
\delta T_k \approx \frac{1}{H_e}\delta\Lambda_k.
```

这就是 He-only 近似。它忽略了：

```math
-\frac{g_x}{H_e}\delta x_k.
```

而状态又由前面事件累积得到：

```math
\delta x_{k+1}=A_e\delta x_k+B_\Lambda\delta\Lambda_k.
```

做 z 域变换：

```math
\delta x(z)
=
(zI-A_e)^{-1}B_\Lambda\delta\Lambda(z).
```

代回 wait 方程：

```math
\delta T(z)
=
\frac{1}{H_e}\delta\Lambda(z)
-
\frac{g_x}{H_e}
(zI-A_e)^{-1}B_\Lambda\delta\Lambda(z).
```

定义从面积阈值到 wait 的等效灵敏度：

```math
S_{T\Lambda}(z)
=
\frac{\delta T(z)}{\delta\Lambda(z)}.
```

则可以定义动态面积刚度：

```math
H_{eff}(z)=S_{T\Lambda}^{-1}(z)=H_e+K(z).
```

其中 `K(z)` 就是 off-time 积分窗口和功率级状态传播造成的动态记忆项。He-only 不是完全错误，而是 `K(z)` 可忽略时的局部近似。

## 9. 四事件 lifted map

四相一整个轮转周期包含四个事件：

```math
p=0,1,2,3.
```

每个事件的小信号模型为：

```math
\delta x_{k+1}=A_{p_k}\delta x_k+B_{\Lambda,p_k}\delta\Lambda+B_{T,p_k}\delta T_{on}+B_{d,p_k}\delta d.
```

四事件提升后：

```math
\delta X_{m+1}
=
\Phi_4\delta X_m
+\Gamma_{\Lambda}\delta\Lambda_m
+\Gamma_T\delta T_{on,m}
+\Gamma_d\delta d_m.
```

其中：

```math
\Phi_4=A_3A_2A_1A_0.
```

若四个事件内输入保持为同一个逐相向量，则：

```math
\Gamma_{\Lambda}
=
A_3A_2A_1B_{\Lambda,0}
+A_3A_2B_{\Lambda,1}
+A_3B_{\Lambda,2}
+B_{\Lambda,3}.
```

`Ton` 和 delay 的提升矩阵同理：

```math
\Gamma_T
=
A_3A_2A_1B_{T,0}
+A_3A_2B_{T,1}
+A_3B_{T,2}
+B_{T,3}.
```

```math
\Gamma_d
=
A_3A_2A_1B_{d,0}
+A_3A_2B_{d,1}
+A_3B_{d,2}
+B_{d,3}.
```

如果四个事件内输入不保持常值，则可构造 block-lifted Toeplitz 矩阵。论文中若只讨论稳态逐相参数设计，常值逐相向量形式已经足够。

## 10. 模态分解

四相执行量可分解为 common 和 differential 模态。常用基向量为：

```math
m_{cm}=[1,1,1,1]^T,
```

```math
m_{1c}=[1,0,-1,0]^T,
```

```math
m_{1s}=[0,1,0,-1]^T,
```

```math
m_2=[1,-1,1,-1]^T.
```

也可加入 one-phase 零均值模式：

```math
m_{one}=[1,-1/3,-1/3,-1/3]^T.
```

令

```math
M=[m_{cm},m_{1c},m_{1s},m_2],
```

则逐相执行量和模态执行量满足：

```math
\delta\Lambda_{phase}=M\delta\Lambda_{modal},
```

```math
\delta T_{on,phase}=M\delta T_{modal}.
```

输出也可投影：

```math
\delta y_{modal}=M^{-1}\delta y_{phase}.
```

这里 `y` 可以是 wait vector、phase-spacing vector、平均相电流 vector 或相电流偏差 vector。

## 11. 为什么 `Lambda_diff` 与 `Ton_diff` 物理通道不同

### 11.1 `Lambda_diff` 的一阶主作用

面积阈值扰动首先改变事件触发等待时间：

```math
\delta T_k
\approx
\frac{1}{H_{e,k}}\delta\Lambda_{q_k}.
```

所以 `Lambda_diff` 的直接输出是：

```math
\delta T,\quad \delta phase\ spacing,\quad \delta event\ jitter.
```

但它不直接改变某一相高边导通时间，也就不直接改变该相每周期平均伏秒注入。因此对 DC current-sharing 的作用弱，主要通过状态传播和事件间隔变化间接出现。

### 11.2 `Ton_diff` 的一阶主作用

`Ton_i` 直接改变第 `i` 相高边导通时间。近似看单周期电感电流增量：

```math
\delta i_{Li}
\approx
\frac{V_{in}-v_o}{L_i}\delta T_{on,i}.
```

因此 `Ton_diff` 直接改变逐相伏秒平衡：

```math
\delta \bar{i}_{phase}
\approx
G_{IT}\delta T_{on,phase}.
```

这就是它成为强 DC current-sharing 执行量的原因。代价是 IQCOT 事件会通过 wait 段补偿，造成相位间隔和频率扩散：

```math
\delta T_k
=
-\frac{g_{Ton}}{H_e}\delta T_{on,p_k}.
```

所以 `Ton_diff` 是强均流执行量，但必须受 phase-spacing margin 约束。

### 11.3 delay_diff 的位置

检测延迟差模可写成：

```math
T_{actual,k}=T_{cross,k}+d_{q_k}.
```

因此 delay_diff 直接扰动事件时刻和相位间隔，但不直接改变 on-time 伏秒注入。它更像时序扰动源，而不是强 DC 均流旋钮。

## 12. 平均相电流输出方程

为了把模型用于均流设计，需要定义平均相电流输出：

```math
\bar{i}_{Li,k}
=
\frac{1}{T_{blk}}
\int_{t_m}^{t_m+T_{blk}}i_{Li}(t)dt.
```

四事件 lifted 后：

```math
\delta \bar{i}_{phase}
=
C_I\delta X_m
+D_{I\Lambda}\delta\Lambda
+D_{IT}\delta T_{on}
+D_{Id}\delta d.
```

理论上：

- `D_{I\Lambda}` 很小，主要来自事件间隔变化和状态传播；
- `D_{IT}` 较大，包含 on-time 伏秒注入的直接项；
- `D_{Id}` 一般也较小，除非延迟大到改变事件排序或有效频率。

因此可构造执行量矩阵：

```math
\begin{bmatrix}
\delta I_{modal}\\
\delta \phi_{modal}\\
\delta f_{modal}
\end{bmatrix}
=
\begin{bmatrix}
G_{I\Lambda} & G_{IT} & G_{Id}\\
G_{\phi\Lambda} & G_{\phi T} & G_{\phi d}\\
G_{f\Lambda} & G_{fT} & G_{fd}
\end{bmatrix}
\begin{bmatrix}
\delta\Lambda_{modal}\\
\delta T_{on,modal}\\
\delta d_{modal}
\end{bmatrix}.
```

本文的核心工程结论正是来自该矩阵：

```text
Lambda_diff -> phase-spacing / ripple-cancellation 主通道；
Ton_diff    -> DC current-sharing 主通道，但有 phase-spacing 代价；
delay_diff  -> timing jitter / phase-spacing 主通道。
```

## 13. 数字量化预算

数字实现中：

```math
\delta\Lambda_i\in[-q_\Lambda/2,q_\Lambda/2],
```

```math
\delta T_{on,i}\in[-q_T/2,q_T/2],
```

```math
\delta d_i\in[-T_{clk}/2,T_{clk}/2]+\mathcal{N}(0,\sigma_d^2).
```

令输出为：

```math
y=[wait,\ phase\ spacing,\ current\ sharing,\ v_o]^T.
```

由 PIS-IEK Jacobian：

```math
\delta y
=
J_\Lambda\delta\Lambda
+J_T\delta T_{on}
+J_d\delta d.
```

若量化误差近似独立，则协方差为：

```math
\Sigma_y
\approx
J_\Lambda\Sigma_\Lambda J_\Lambda^T
+J_T\Sigma_TJ_T^T
+J_d\Sigma_dJ_d^T.
```

其中：

```math
\sigma_\Lambda^2=\frac{q_\Lambda^2}{12},
\qquad
\sigma_T^2=\frac{q_T^2}{12},
\qquad
\sigma_{clk}^2=\frac{T_{clk}^2}{12}.
```

这一步把小信号模型转成数字实现预算：面积位宽、检测时钟、Ton 分辨率和比较器随机延迟都能映射成 wait jitter、phase-spacing jitter 和均流误差。

## 14. 最终可写入论文的模型总结

PIS-IEK 的完整小信号链条为：

```math
g_{q_k}(x_k,T_k,T_{on,p_k},\Lambda_{q_k})=0
```

给出：

```math
\delta T_k
=
-g_T^{-1}
\left(
g_x\delta x_k
+g_{Ton}\delta T_{on,p_k}
+g_\Lambda\delta\Lambda_{q_k}
+g_u\delta u_k
\right).
```

再代入：

```math
x_{k+1}=F_{p_k}(x_k,T_k,T_{on,p_k},u_k)
```

得到：

```math
\delta x_{k+1}
=
A_{p_k}\delta x_k
+B_{\Lambda,p_k}\delta\Lambda
+B_{T,p_k}\delta T_{on}
+B_{d,p_k}\delta d
+B_{u,p_k}\delta u.
```

四事件提升：

```math
\delta X_{m+1}
=
\Phi_4\delta X_m
+\Gamma_\Lambda\delta\Lambda_m
+\Gamma_T\delta T_{on,m}
+\Gamma_d\delta d_m.
```

模态投影：

```math
\delta y_{modal}
=
C_{modal}\delta X_m
+D_{\Lambda,modal}\delta\Lambda_{modal}
+D_{T,modal}\delta T_{on,modal}
+D_{d,modal}\delta d_{modal}.
```

这就是本文创新小信号模型的核心推导。它把传统“面积阈值影响频率”的经验认识，升级成一个能同时解释事件时刻、相位间隔、均流执行量和数字量化预算的四相相索引事件映射模型。

