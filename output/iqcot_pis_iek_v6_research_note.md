# v6 研究推进：PIS-IEK 相索引盐跃小信号模型与大样本验证

## 1. 本轮研究目标

本轮不再只增加单点仿真，而是把 v5 的 IEK 小信号模型升级为一套更完整的数据化验证体系。目标有三个：

1. 将 `H_e+K(z)` 等效动态核进一步展开为四相周期 event-to-event Jacobian。
2. 明确 `phase_idx`、积分 reset、`Λ_i`、`Ton_i` 在小信号模型中的位置。
3. 用足够数量的幅值扫描和频率响应实验给出模型适用范围，而不是只报告一个漂亮案例。

本轮提出的模型命名为：

```text
PIS-IEK = Phase-Indexed Saltation Integral-Event Kernel
```

中文可写为：

```text
相索引盐跃积分事件核模型
```

需要注意：saltation/Poincare 线性化方法本身不是原创。本文可主张的创新是把该方法具体嵌入四相数字 IQCOT 的面积事件、相序调度、积分 reset 和执行量分类中。

## 2. 模型精进点

v5 的 IEK 写成：

```math
G_{T\Lambda}(z)=\frac{1}{H_e+K(z)}.
```

这个形式已经说明 He-only 模型为什么不够，但 `K(z)` 仍是等效核。PIS-IEK 把每个事件显式写成：

```math
x_{k+1}=F_{p_k}(x_k,u_k,T_k),
```

```math
g_{q_k}(x_k,u_k,T_k)=0,
```

其中

```math
p_k=k\bmod4,\qquad q_k=(p_k+1)\bmod4.
```

事件面为：

```math
g_{q_k}
=
\int_0^{T_k}
\left[v_c(t)-R_i i_{L,q_k}(t)\right]dt-\Lambda_{q_k}.
```

隐函数线性化得到：

```math
\delta T_k=-g_T^{-1}(g_x\delta x_k+g_u\delta u_k).
```

代回状态更新：

```math
\delta x_{k+1}
=
\left(F_x-F_Tg_T^{-1}g_x\right)\delta x_k
+
\left(F_u-F_Tg_T^{-1}g_u\right)\delta u_k.
```

这个形式的价值是：`phase_idx` 不再只是 Simulink 中的工程变量，而是事件面 `g_{q_k}` 的索引；积分 reset 也不再是实现细节，而是包含在 `F_{p_k}` 中的状态跳变。

## 3. 数据结构

本轮生成了 5 个核心数据文件：

| 数据集 | 文件 | 行数 | 用途 |
|---|---|---:|---|
| 局部灵敏度矩阵 | `iqcot_pis_iek_sensitivity_matrix.csv` | 32 | 每个事件相对 `Λ_i`、`Ton_i` 的局部 wait 灵敏度 |
| 模态投影矩阵 | `iqcot_pis_iek_modal_projection_matrix.csv` | 10 | 将局部 wait 灵敏度投影到 common、m1、m2、one-phase 模式 |
| 幅值线性扫描 | `iqcot_pis_iek_amplitude_sweep.csv` | 77 | 验证不同扰动幅值下的线性适用范围 |
| 四事件提升频响 | `iqcot_pis_iek_frequency_response.csv` | 80 | 验证 lifted block 域中 exact/pred 频率响应 |
| 数据索引 | `iqcot_pis_iek_dataset_manifest.csv` | 5 | 统一记录路径、行数和用途 |

配套脚本：

```text
E:/Desktop/codex/output/iqcot_pis_iek_comprehensive_validation.py
E:/Desktop/codex/output/iqcot_pis_iek_generate_figures.py
```

配套图表：

```text
E:/Desktop/codex/output/figures/fig16_pis_iek_amplitude_error.svg
E:/Desktop/codex/output/figures/fig17_pis_iek_lifted_frequency_response.svg
```

## 4. 实验规模

模型工作点：

| 参数 | 数值 |
|---|---:|
| 相数 | `4` |
| `Vin` | `12 V` |
| `Vo` | `1 V` |
| `Iout` | `40 A` |
| 每相频率 | `500 kHz` |
| `Ton` | `169.166667 ns` |
| `Twait` | `330.833333 ns` |
| 四事件闭合误差 | `0` |

实验矩阵：

| 实验 | 工况数 | 说明 |
|---|---:|---|
| 局部 Jacobian | 32 | 4 个事件相 × 4 个 `Λ_i` + 4 个 `Ton_i` |
| 模态投影 | 10 | 5 种空间模式 × 2 种输入类型 |
| 幅值扫描 | 77 | `Λ` 35、`Ton` 24、Mixed 18 |
| 四事件提升频响 | 80 | `Λ` 40、`Ton` 30、Mixed 10 |

这比 v5 的单点或少量扫描更适合支撑论文创新，因为它同时回答“局部机制”“小信号范围”和“频域动态”。

## 5. 关键结果

局部灵敏度高度对称：

| 指标 | 数值 |
|---|---:|
| `dT/dΛ_q` | `0.0428305 ns/(1e-13 V·s)` |
| 非目标相 `Λ` 串扰 | `0` |
| `dT/dTon_p` | `-0.357596 ns/ns` |
| 非当前相 `Ton` 串扰 | `0` |

这说明当前 wait 的局部事件面只直接受下一触发相的 `Λ_q` 和当前导通相的 `Ton_p` 影响。这个结果非常适合回应 `phase_idx` 的理论解释：`phase_idx` 实际上选择的是哪一个相的面积事件面。

幅值扫描结果：

| 扫描集合 | 工况数 | 最大 rms wait 误差 | 平均 rms wait 误差 | 最大相电流误差 |
|---|---:|---:|---:|---:|
| `Λ` 全范围 | 35 | `0.05025%` | `0.01189%` | `0.00914 mA` |
| `Ton <= 0.02 ns` | 16 | `1.83345%` | `0.51047%` | `1.28022 mA` |
| `Ton <= 0.05 ns` | 20 | `4.57963%` | `0.95984%` | `8.13116 mA` |
| Mixed 全范围 | 18 | `1.71860%` | `0.75130%` | `1.30087 mA` |

频率响应结果采用四事件提升块域，而不是逐事件直接拟合。这样可以避免空间模态与时间频率混叠。可观测 wait 幅值工况统计如下：

| 输入类型 | 可观测工况数 | 最大 wait 幅值误差 | 最大 wait 绝对误差 | 最大 wait rms 误差 |
|---|---:|---:|---:|---:|
| `Λ` | 40 | `0.000138%` | `2.60e-08 ns` | `0.00427%` |
| `Ton` | 30 | `0.003712%` | `9.64e-05 ns` | `0.01056%` |
| Mixed | 10 | `0.003874%` | `1.16e-05 ns` | `0.24971%` |

结论很清楚：

- `Λ` 通道在线性区内极其干净，几乎达到数值误差级。
- `Ton` 通道仍能被 PIS-IEK 准确预测，但大幅度 `Ton` 扰动会更早进入非线性区。
- 四事件提升频响比逐事件频响更合理，因为四相空间模态会带来频率搬移/混叠。

## 6. 图表

![Fig16](E:/Desktop/codex/output/figures/fig16_pis_iek_amplitude_error.svg)

![Fig17](E:/Desktop/codex/output/figures/fig17_pis_iek_lifted_frequency_response.svg)

## 7. 可写入论文的核心表述

建议写成：

> 为进一步解释四相数字 IQCOT 中 `phase_idx`、积分 reset 与执行量分类的关系，本文在 IEK 等效动态核基础上提出相索引盐跃 IEK 模型。该模型将每个事件写成 `x_{k+1}=F_{p_k}(x_k,u_k,T_k)` 与 `g_{q_k}(x_k,u_k,T_k)=0`，并通过隐函数线性化得到四相周期 event-to-event Jacobian。结构化仿真包含 32 行局部灵敏度、10 行模态投影、77 个幅值扫描工况和 80 个四事件提升频响工况。结果表明，`Λ` 通道最大 rms wait 误差仅 `0.05025%`，`Ton<=0.02 ns` 时最大 rms wait 误差为 `1.83345%`；四事件提升频响中可观测工况的 wait 幅值误差低于 `0.004%`。因此，PIS-IEK 为 v5 中 `H_e+K(z)` 的等效核提供了更严格的相索引状态空间解释。

## 8. 现在的创新强度判断

这个创新比 v5 更强，原因有三点：

1. 它把 `phase_idx/reset` 从实现描述提升为模型结构。
2. 它给出了周期 Jacobian，而不仅是等效频域核。
3. 它有较大规模的数据支撑：77 个幅值工况和 80 个频响工况，不再依赖单点验证。

但边界也必须保留：

- 当前仍是理想四相面积事件模型，不是完整 MOSFET/驱动/ADC/DPWM 硬件链。
- saltation/Poincare 是已有数学工具，不能声称数学方法原创。
- 还需要在 Simulink 副本中做电路级小扰动 Jacobian 交叉验证，才能进一步提升说服力。
