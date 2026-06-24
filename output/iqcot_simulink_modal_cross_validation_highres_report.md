# Simulink 四相 IQCOT/COT 模态交叉验证（精选高分辨率）

模型：`E:\Desktop\4cot\versions\v0027_20260611_135822_iqcot_optimized_final_cn_docs`。本脚本未保存或修改 `.slx`，仅通过 `SimulationInput.setBlockParameter` 临时钳位四相 `Ton_Limit`。

## 基线

- Vout mean: 1.000015530 V
- Vout ripple: 0.735095 mVpp
- IL mean: [9.978771, 9.993619, 10.058002, 9.980875] A
- Phase-current imbalance: 0.079230 A
- Mean phase frequency: 499.579 kHz

## 主要观察

1. Common-mode `Ton` 扰动主要改变输出工作点与等效频率。最大 common 扰动样本 `common_m4ns` 相对基线的 Vout 均值变化为 -2.69123e-05 V，频率变化为 11.1039 kHz。
2. m2 差模 `Ton` 扰动主要放大相电流不均衡。最大 m2 样本 `m2_p4ns` 的相电流不均衡为 3.927572 A，m2 电流投影为 1.943020 A；基线分别为 0.079230 A 与 0.015570 A。
3. 该模型验证的是论文创新中的“模态执行量分类/差模 on-time 均流通道”，不是面积阈值 `Lambda` 触发的完整 IEK 结构。要验证 `Lambda` 通道，需要在模型中加入输出误差面积积分触发器或等效数字事件核。

## 文件

- `iqcot_simulink_modal_cross_validation_highres_summary.csv`
- `iqcot_simulink_modal_cross_validation_highres_detail.json`
- `figures/fig12_simulink_modal_cross_validation_highres.png`
