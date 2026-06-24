# 四相数字 IQCOT 的延迟感知混合事件 PIS-IEK 扩展研究

## 1. 研究定位

本扩展不是替代 v7 中已经完成的 PIS-IEK 小信号模型，而是针对两个尚未被充分覆盖、但对“AI 调参”和“瞬态切载”非常关键的问题进行补强：

1. FPGA 上 AI 推理通常存在微秒级延迟，该延迟与四相 IQCOT 的事件间隔处于同一数量级，不能被忽略。
2. 大幅切载会触发 pulse skipping、事件饱和和重入稳态过程，不能简单用单一线性 Jacobian 描述。

因此，本扩展建议把原有 PIS-IEK 写成 **延迟感知混合事件模型**：

```math
x_{k+1}=F_{m_k,p_k}(x_k,u_{k-d_k},I_{o,k},T_k),
```

```math
g_{m_k,q_k}(x_k,u_{k-d_k},I_{o,k},T_k)=0,
```

其中：

```math
m_k\in\{\mathrm{normal},\mathrm{skip},\mathrm{reentry},\mathrm{saturation}\}.
```

这里 `m_k` 表示事件模式，`p_k`/`q_k` 保留四相相索引，`d_k` 表示 AI 或数字链路造成的事件索引延迟。

## 2. 为什么这个扩展是必要的

在四相 500 kHz 设计中，单相开关周期为：

```math
T_{sw}=2\ \mu s.
```

四相交错后，相邻事件间隔约为：

```math
T_e=\frac{T_{sw}}{4}=0.5\ \mu s.
```

如果 FPGA AI 推理延迟为：

```math
\tau_{AI}=1\sim5\ \mu s,
```

则对应的事件滞后为：

```math
d_k=\left\lceil\frac{\tau_{AI}}{T_e}\right\rceil
=2\sim10.
```

这说明 AI 不适合直接参与开关级事件触发。它更适合成为慢速或中速的参数调节器，调节：

```math
u_k=
[\Delta \Lambda_{cm},
\Delta \Lambda_{diff},
\Delta T_{on,diff},
\Delta d_{comp},
K_{share}]^T.
```

原有 PIS-IEK 的价值在于，它可以把这些参数映射到可解释性能指标：

```math
\delta y_k
=
J_{IEK}\delta u_{k-d_k},
```

```math
\delta y_k=
[\Delta I_{share},
\Delta \phi,
\Delta V_o,
\Delta f_{sw},
\Delta V_{ripple}]^T.
```

因此，AI 训练时不应学习“直接开哪个管子”，而应学习“在存在推理延迟、量化和安全约束时，如何调节 PIS-IEK 参数”。

## 3. 切载瞬态的分段解释

切载过程应拆成三段，而不是直接用一个小信号模型覆盖全部现象：

| 阶段 | 物理过程 | PIS-IEK 适用性 | 需要新增内容 |
|---|---|---|---|
| A. 瞬间过压段 | 负载下降，电感电流暂时大于负载电流，输出电容充电 | 只能给趋势，不能单独精确预测峰值 | 能量/电容大信号约束 |
| B. 脉冲抑制段 | 输出过压导致面积事件迟迟不满足，出现跳脉冲 | 原始 PIS-IEK 需切换到 skip 模式 | 模式变量 `m_k` |
| C. 重入稳态段 | 电压回落后事件重新触发，四相相序恢复 | PIS-IEK 最有解释力 | reentry Jacobian 与相位恢复指标 |

在大幅切载时，输出电压一阶上冲可由能量约束给出近似下界：

```math
\Delta E_L
\approx
\frac{1}{2}\sum_{i=1}^{4}L_i(i_{Li,0}^2-i_{Li,new}^2),
```

```math
\Delta V_{o,pk}
\approx
\sqrt{V_{o,0}^2+\frac{2\Delta E_L}{C_o}}-V_{o,0}.
```

这部分不是小信号 Jacobian 的强项。PIS-IEK 的强项在于描述后续事件恢复：

```math
\delta T_k
=
-g_T^{-1}
\left(
g_x\delta x_k
 +g_I\delta I_{o,k}
 +g_u\delta u_{k-d_k}
\right).
```

切载时：

```math
\delta I_o<0,
```

通常会导致事件等待时间变长：

```math
\delta T_k>0,
```

等效频率下降：

```math
\delta f_{sw}<0.
```

当等待时间超过数字或控制器允许上限时，进入 skip 模式：

```math
m_k=\mathrm{skip}.
```

此时状态更新不再包含新的 on-time 能量注入：

```math
x_{k+1}=F_{\mathrm{skip}}(x_k,I_{o,k},T_{skip}).
```

电感和电容满足：

```math
L_i\frac{di_{Li}}{dt}=-v_o-r_{Li}i_{Li},
```

```math
C_o\frac{dv_o}{dt}=\sum_{i=1}^{4}i_{Li}-I_o.
```

当面积条件重新可满足时，系统进入 reentry：

```math
m_k=\mathrm{reentry}.
```

重入阶段的关键指标不是单个 `Vout` 峰值，而是：

```math
\sigma_{\phi,reentry},\quad
\sigma_{I,reentry},\quad
N_{skip},\quad
t_{settle},\quad
V_{pk}.
```

其中 `N_skip` 是跳过的事件数，`\sigma_{\phi,reentry}` 是重入后相位间隔标准差，`\sigma_{I,reentry}` 是重入后相电流均流误差。

## 4. 对 AI 训练的直接帮助

### 4.1 把 AI 延迟写进环境

训练环境应使用：

```math
u_{eff,k}=Q(u_{AI,k-d_k})+\eta_q,
```

其中 `Q(.)` 表示数字量化，`\eta_q` 表示等效量化噪声或执行误差。事件延迟可写成：

```math
d_k=
\left\lceil
\frac{\tau_{ADC}+\tau_{infer}+\tau_{commit}}{T_e}
\right\rceil.
```

这会显著减少仿真训练到 FPGA 部署之间的偏差。

### 4.2 把动作空间限制到物理可解释参数

AI 动作不应直接是 gate command，而应是：

```math
a_k=
[\Delta\Lambda_{cm},
\Delta\Lambda_{m1},
\Delta\Lambda_{m2},
\Delta\Lambda_{m3},
\Delta T_{on,m1},
\Delta T_{on,m2},
\Delta T_{on,m3},
\Delta d_{comp}]^T.
```

PIS-IEK 已经说明：

- `Lambda_diff` 主要是相位/纹波执行量，不是强 DC 均流执行量。
- `Ton_diff` 是主要均流执行量，但会扰动相位间隔。
- delay 差模主要表现为 event jitter 和 phase-spacing jitter。

因此 AI 的训练不再需要在错误通道上反复试错。

### 4.3 使用安全投影避免危险动作

AI 输出先经过 PIS-IEK 安全投影：

```math
\delta u_{safe}
=
\arg\min_{\delta u'}
\|\delta u'-\delta u_{AI}\|^2,
```

```math
\mathrm{s.t.}\quad
A_cJ_{IEK}\delta u'\le b_c.
```

典型约束包括：

```math
\sigma_I<I_{share,max},
\quad
\sigma_\phi<\phi_{max},
\quad
V_o\in[V_{min},V_{max}],
\quad
f_{sw}\in[f_{min},f_{max}],
\quad
|\Delta T_{on,i}|<T_{on,lim}.
```

这样 AI 不是黑盒控制器，而是受物理模型约束的参数优化器。

## 5. 建议新增的论文贡献边界

可以增加一个“展望/扩展验证”型贡献，但不要抢原文主贡献：

> 在已有相索引积分事件小信号模型基础上，进一步给出面向 FPGA AI 调参和切载瞬态的延迟感知混合事件扩展。该扩展将 AI 推理延迟写作事件索引输入滞后，将大幅切载写作 normal/skip/reentry 分段事件过程，从而说明 PIS-IEK 不仅可解释稳态小信号执行量分类，也可作为 AI 参数训练环境和切载恢复分析的物理约束骨架。

注意边界：

- 不能声称 PIS-IEK 已经完整预测大幅切载第一峰值。
- 不能声称 AI 可以替代 IQCOT 内环。
- 可以声称 PIS-IEK 支撑 **延迟感知、物理约束、低维参数空间** 的 AI 调参训练。

## 6. 下一步必须验证的问题

最小验证集合：

1. `40 A -> 20 A`、`40 A -> 10 A`、`40 A -> 0 A` 切载仿真。
2. 对比无 AI、无延迟 AI、延迟感知 AI 三组策略。
3. 记录 `Vpk`、`undershoot/overshoot`、`N_skip`、`t_settle`、`\sigma_phi`、`\sigma_I`。
4. 扫描 AI 推理延迟 `0/0.5/1/2/5 us`。
5. 扫描动作更新周期 `2/5/10/20 us`。
6. 比较 `Lambda_diff`、`Ton_diff`、联合约束投影三种动作通道。

如果结果显示延迟感知训练在 `1-5 us` 延迟下比无延迟训练更稳，且不会显著牺牲切载恢复时间，则可支撑如下论文级结论：

> PIS-IEK 对 AI 控制的价值不是提高开关级速度，而是把 AI 训练从无约束黑盒搜索转化为延迟感知、模式感知和物理约束的参数优化问题。

