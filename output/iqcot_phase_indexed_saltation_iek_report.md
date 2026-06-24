# 相索引盐跃 IEK 小信号模型精进报告

## 核心增量

v5 的 IEK 用 `H_e+K(z)` 表示面积事件的动态刚度，但 `K(z)` 仍是等效核。本报告把四相轮转显式写成 phase-indexed event map：

```math
x_{k+1}=F_{p_k}(x_k,u_k,T_k),\qquad g_{q_k}(x_k,u_k,T_k)=0.
```

对事件边界做隐函数线性化后得到盐跃式更新：

```math
\delta T_k=-g_T^{-1}(g_x\delta x_k+g_u\delta u_k),
```

```math
\delta x_{k+1}=(F_x-F_Tg_T^{-1}g_x)\delta x_k+(F_u-F_Tg_T^{-1}g_u)\delta u_k.
```

这里 `p_k` 是当前 on-time 相，`q_k=(p_k+1) mod 4` 是下一触发相。它把 `phase_idx`、面积积分 reset 和事件时刻移动统一进同一个小信号映射，比单纯的 scalar `H_e+K(z)` 更适合解释四相数字实现。

## 数值检查

- 四事件闭合误差 inf-norm：`0.000e+00`。
- 非目标相 `Lambda` 对当前 wait 的最大串扰：`0.000e+00 ns/(1e-13 V*s)`。
- 非当前相 `Ton` 对当前 wait 的最大串扰：`0.000e+00 ns/ns`。
- 小扰动多事件验证最大 wait 预测误差：`90.198 ps`；最大相对峰值误差：`1.132%`；最大相电流预测误差：`1.280223 mA`。

## 解释

该模型给出一个比 v5 更严谨的创新表述：IEK 不只是一个频域动态核，还可以被写成四相周期盐跃 Jacobian。这样能够直接回答三个以前较弱的问题：第一，`phase_idx` 选择的是哪个相的事件面；第二，积分器 reset 如何进入小信号状态更新；第三，`Lambda_diff` 与 `Ton_diff` 的执行量分类能否从局部 event map 推出。这仍不是完整硬件控制器模型，但已经把小信号建模从经验核推进到可验证的混杂系统线性化。
