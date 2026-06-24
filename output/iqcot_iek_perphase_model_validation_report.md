# 逐相 IEK 面积核 Simulink 副本验证

模型副本：`E:/Desktop/codex/output/simulink_iek/four_phase_iek_perphase.slx`。
面积核：`h_i = Varea_bias + e_v + Ri_area*(Iph - IL_i)`，并按 `phase_idx` 选择对应相的面积比较结果生成 `REQ`。

## 最佳候选

- `Lambda_area = 6e-10 V*s`
- `Varea_bias = 0.002 V`
- `Ri_area = 0.0005 ohm`
- `Vout_mean = 0.999548295 V`
- `Vout_ripple = 0.785960 mVpp`
- mean phase frequency = `502.097 kHz`
- phase-current imbalance = `0.023902 A`
- phase-spacing std = `21.112756 ns`

## Lambda_m2 扫描

最大扫描比值 `Lambda_m2/Lambda_area=0.400` 时，相电流不均衡 `0.039699 A`，m2 电流投影 `0.001163 A`，phase-spacing std `24.839189 ns`。

## 解释

该副本比 v4 的 `integral(max(e_v,0))` 更接近 IQCOT 小信号形式，因为它显式引入逐相电感电流项 `Ri_area*(Iph-IL_i)`。当前结果可用于检验 `Lambda_m2` 是否产生可观 DC 均流，以及它对 phase-spacing 的副作用。
