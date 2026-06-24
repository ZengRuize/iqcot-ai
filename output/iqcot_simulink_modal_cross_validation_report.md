# Simulink 四相 IQCOT/COT 模态交叉验证

模型：`E:\Desktop\4cot\versions\v0027_20260611_135822_iqcot_optimized_final_cn_docs\four_phase.slx`。验证脚本未保存或修改 `.slx`，仅通过 `SimulationInput.setBlockParameter` 在仿真时临时钳位四相 `IQCOT_Ton_Adapter/Ton_Limit1..4`。

## 模型事实源

- 拓扑：12 V 到 1 V，40 A，四相交错同步 Buck。
- 当前初始化点：`Ton_cmd = 196.5 ns`，`Tblank = 480 ns`，`L = 200 nH`，`DCR_L1..4 = 10 mOhm`，`Cout = 7.26 mF`，`ESR_C = 90 uOhm`。
- 控制链：`Vout -> Relay hysteresis -> global blanking/trigger -> PhaseScheduler_4Phase -> COT_Cell_1Phase1..4 -> GateDriver -> MOSFET`。
- IQCOT 路径：`IL_sample_i -> leaky current-error integrator -> Kiqcot -> Ton_iqcot_i`。这不是本文 IEK 论文中完整的输出误差面积阈值 `Lambda` 触发器，但可以验证差模 `Ton` 执行量的均流作用。

## 基线结果

- `Vout_mean = 1.000015530 V`
- `Vout_ripple = 0.735095 mVpp`
- `IL_mean = [9.978771, 9.993619, 10.058002, 9.980875] A`
- `IL_phase_imbalance = 0.079230 A`
- `mean_phase_frequency = 499.579 kHz`
- 相位触发顺序错误率为 0，说明临时钳位 `Ton` 没有破坏四相轮转。

## 主要观察

1. Common-mode `Ton` 扰动主要由闭环 COT 转化为等效频率变化。以基线为参照，`Ton = Ton_cmd - 4 ns` 时平均相频率升至 `510.683 kHz`，`Ton = Ton_cmd + 4 ns` 时降至 `489.360 kHz`。在 `[-4 ns, +4 ns]` 扫描内，频率斜率约为 `-2.76 kHz/ns`。
2. m2 差模 `Ton` 扰动强烈放大相电流差模，而输出电压均值基本保持在 1 V 附近。`[+2, -2, +2, -2] ns` 时相电流不均衡为 `2.017 A`，m2 电流投影为 `0.997 A`；`[+4, -4, +4, -4] ns` 时相电流不均衡为 `3.928 A`，m2 投影为 `1.943 A`。
3. m2 投影在 `1 ns, 2 ns, 4 ns` 三个点上近似线性，斜率约 `0.482 A/ns`。这直接支持论文中的工程结论：`Ton_diff` 是有效 DC current-sharing 执行量。
4. `m13` 与 `m24` 成对差模对照也符合模态解释：`[+2, 0, -2, 0] ns` 主要激发相 1-3 电流差，`[0, +2, 0, -2] ns` 主要激发相 2-4 电流差。
5. Simulink 结果不能替代完整 IEK 面积阈值验证。它验证的是“差模 on-time 均流通道”和“模态执行量分类”的物理合理性；若要验证 `Lambda_diff` 与动态事件核 `K(z)`，需要在该模型中增加输出误差面积积分触发器或等效数字事件核。

## 输出文件

- `E:\Desktop\codex\output\iqcot_simulink_modal_cross_validation.m`
- `E:\Desktop\codex\output\iqcot_simulink_modal_cross_validation_summary.csv`
- `E:\Desktop\codex\output\iqcot_simulink_modal_cross_validation_detail.json`
- `E:\Desktop\codex\output\figures\fig11_simulink_modal_cross_validation.png`
