# v3 审稿式自查报告

对象：`iqcot_multiphase_iek_paper_v3_simulink_validated.md`

## 总体判断

v3 相比 v2 的主要进步是补上了外部模型交叉验证：使用用户已有 `four_phase.slx`，在不保存模型的前提下注入 common-mode 与差模 on-time 扰动，得到 14 点主扫描和 8 点 `MaxStep=2 ns` 精选复核。该证据显著增强了“`Ton_diff` 是主要 DC current-sharing 执行量”的可信度，也降低了“所有结果来自同一个解析脚本”的审稿风险。

## 主要优点

1. 创新边界更清楚：论文不再把 Simulink 结果说成完整 IEK 面积核验证，而明确说它验证的是差模 on-time 均流通道和模态执行量分类。
2. 数据点更充足：解析部分已有 24 点 common 扫频、54 点执行量扫描、140 点 DCR 失配网格；新增 Simulink 14 点主扫描与 8 点高分辨率复核。
3. 工程价值更明显：Simulink 中 `[+4,-4,+4,-4] ns` 导致约 `3.928 A` 相电流不均衡，m2 投影斜率约 `0.482 A/ns`，这是很直观的均流执行量证据。
4. 防守性增强：论文主动说明解析 IEK 与 Simulink 模型参数不同，且用户模型的 IQCOT 是电流误差泄放积分调 on-time，不是完整输出误差面积阈值触发。

## 仍然存在的主要风险

1. 完整 `Lambda` 面积事件核尚未在 Simulink/Simscape 中实现。当前最强证据支持 `Ton_diff` 通道，但 `Lambda_diff` 的电路级验证仍依赖解析 IEK 脚本。
2. 当前 Simulink 验证是稳态小扰动/准静态执行量验证，还没有负载阶跃瞬态、噪声、ADC 延迟、量化位宽和采样保持的系统验证。
3. 解析模型和 Simulink 模型参数不同，数值增益不能直接一一比较。论文已经说明这一点，但答辩时仍应强调“方向一致、通道一致”，不要把 `765.07 mA/(0.1 ns)` 与 `0.482 A/ns` 当成同一模型下的等价结果。
4. 0.25 ns 和 0.5 ns 的主扫描点接近数值事件分辨率，不能作为核心线性结论。v3 已用 `1/2/4 ns` 点和 2 ns 高分辨率复核支撑主要结论。

## 建议下一步

最值得继续做的是在 `four_phase.slx` 的副本中加入严格面积积分触发器：

```text
e_area_i = integral(Vref_or_Vc - Ri * IL_i)
trigger_i when e_area_i >= Lambda_i
reset area integrator at trigger
```

然后复跑 `Lambda_cm`、`Lambda_diff`、`Ton_diff` 和检测延迟差模的同一套模态实验。这样可以把论文从“解析 IEK + Simulink on-time 通道交叉验证”推进到“完整 IEK 控制器的电路级验证”。
