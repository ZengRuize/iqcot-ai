# 逐相 IEK 面积核静态负载扫点验证

模型副本：`E:/Desktop/codex/output/simulink_iek/four_phase_iek_perphase.slx`。该脚本不保存模型，仅通过 `SimulationInput` 设置 `Rload`、`Iout`、`Iph`、`Lambda_area`、`Lambda_m2`、`Varea_bias` 和 `Ri_area`。

固定面积核参数：`Lambda_area=6e-10 V*s`，`Varea_bias=2 mV`，`Ri_area=0.5 mOhm`。负载点为 20/30/40/50 A，且每个负载点比较 `Lambda_m2/Lambda_area=0` 与 `0.4`。

## 主要结果

- baseline `Lambda_m2=0` 下，最大输出均值误差出现在 50 A：`-0.617 mV`。
- baseline `Lambda_m2=0` 下，最大相电流不均衡出现在 30 A：`0.130635 A`。
- `Lambda_m2/Lambda_area=0.4` 跨负载最大 m2 电流投影为 `0.009382 A`，最大相电流不均衡为 `0.101793 A`，最大 phase-spacing std 为 `52.524405 ns`。

## 解释

该扫点不是负载阶跃瞬态验证，而是静态负载鲁棒性补充。结果用于检查 v5 的逐相面积核结论是否只在 40 A 单点成立。若 `Lambda_m2` 在 20--50 A 范围内仍只产生很小 m2 电流投影，则支持其主要是相位/事件间隔执行量，而非强 DC 均流执行量。
